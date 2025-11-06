defmodule Logit.Processors.Influx.Consumer do
  @moduledoc false

  use GenStage
  require Logger

  alias Logit.Processors.Influx.Producer

  defstruct [
    :url,
    :timer_ref,
    headers: [],
    min_demand: 50,
    max_demand: 200,
    batch_size: 100,
    flush_interval: 1_000,
    buffer: []
  ]

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:consumer, _schedule_flush(opts),
     subscribe_to: [{Producer, max_demand: opts.max_demand, min_demand: opts.min_demand}]}
  end

  @impl true
  def handle_events(events, _from, state) do
    buffer = state.buffer ++ events

    state =
      if length(buffer) >= state.batch_size do
        _do_flush(%{state | buffer: buffer})
      else
        %{state | buffer: buffer}
      end

    {:noreply, [], state}
  end

  @impl true
  def handle_info(:flush, state) do
    {:noreply, [], _do_flush(state) |> _schedule_flush()}
  end

  defp _do_flush(%{buffer: []} = state), do: state

  defp _do_flush(state) do
    Task.start(fn ->
      case _send_to_influx(state) do
        :ok ->
          Logger.debug("Flushed #{length(state.buffer)} events to InfluxDB")

        {:error, reason} ->
          Logger.error("Failed to flush: #{inspect(reason)}")
      end
    end)

    %{state | buffer: []}
  end

  defp _schedule_flush(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    timer_ref = Process.send_after(self(), :flush, state.flush_interval)
    %{state | timer_ref: timer_ref}
  end

  defp _send_to_influx(state) do
    line_protocol = Enum.map_join(state.buffer, "\n", &_build_line_protocol/1)

    case Req.post(state.url, body: line_protocol, headers: state.headers, retry: false) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        Logger.debug(
          "#{__MODULE__} Sent #{length(state.buffer)} metrics to influxdb body: #{inspect(response_body)}"
        )

        :ok

      {:ok, %{status: status, body: response_body}} ->
        Logger.warning(
          "influxdb returned HTTP #{status}: #{inspect(response_body)} body: #{inspect(response_body)}"
        )

        {:error, "HTTP #{status}: #{inspect(response_body)}"}

      {:error, reason} ->
        Logger.error("Failed to send metrics to influxdb: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp _build_line_protocol(%{name: measurement, tags: tags, fields: fields}) do
    tags_part = _build_tags(tags)
    field_str = _build_fields(fields)
    timestamp = System.system_time(:nanosecond)

    "#{measurement}#{tags_part} #{field_str} #{timestamp}"
  end

  defp _build_tags([]), do: ""

  defp _build_tags(tags) do
    tags
    |> Enum.map_join(",", fn {k, v} -> "#{k}=#{_escape_tag(v)}" end)
    |> then(&",#{&1}")
  end

  defp _build_fields(fields) do
    Enum.map_join(fields, ",", fn {k, v} ->
      "#{k}=#{_format_field_value(v)}"
    end)
  end

  defp _format_field_value(v) when is_binary(v), do: ~s("#{_escape_field(v)}")
  defp _format_field_value(v) when is_integer(v), do: "#{v}i"
  defp _format_field_value(v) when is_float(v), do: to_string(v)
  defp _format_field_value(true), do: "true"
  defp _format_field_value(false), do: "false"
  defp _format_field_value(nil), do: ~s("")
  defp _format_field_value(v), do: ~s("#{_escape_field(inspect(v))}")

  defp _escape_tag(value) do
    value
    |> to_string()
    |> String.replace(~r/[ ,=]/, fn
      " " -> "\\ "
      "," -> "\\,"
      "=" -> "\\="
    end)
  end

  defp _escape_field(value) do
    value
    |> to_string()
    |> String.replace(~r/["\n]/, fn
      "\"" -> "\\\""
      "\n" -> "\\n"
    end)
  end
end
