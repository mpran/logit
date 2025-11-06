defmodule Logit.Processors.Influx.LiveView do
  @moduledoc false

  require Logger

  alias Logit.Processors.Influx
  alias Logit.Processors.WebHelpers

  def attach(config \\ nil) do
    events = [
      [:phoenix, :live_view, :mount, :stop],
      [:phoenix, :live_view, :mount, :exception],
      [:phoenix, :live_view, :handle_event, :stop],
      [:phoenix, :live_view, :handle_event, :exception]
    ]

    :telemetry.attach_many(
      "live-view-influx-metrics",
      events,
      &__MODULE__.handle_event/4,
      config
    )
  end

  def handle_event(
        [:phoenix, :live_view, :mount, event],
        measurements,
        %{socket: %{connect_info: %Plug.Conn{} = conn}},
        _config
      ) do
    {tags, values} = WebHelpers.phoenix_report(event, conn, measurements)

    Influx.report("live_view.mount", tags, values)
  end

  def handle_event(
        [:phoenix, :live_view, :mount, event],
        measurements,
        meta,
        _config
      ) do
    headers = WebHelpers.headers_from_socket(meta.socket)

    {tags, values} = WebHelpers.live_view_report(event, meta, measurements, headers: headers)

    Influx.report("live_view.mount", tags, values)
  end

  def handle_event(
        [:phoenix, :live_view, :handle_event, event],
        measurements,
        meta,
        _config
      ) do
    headers = WebHelpers.headers_from_socket(meta.socket)

    {tags, values} = WebHelpers.live_view_report(event, meta, measurements, headers: headers)

    Influx.report("live_view.handle_event", tags, values)
  end

  def handle_event(_, _, _, _) do
    :ok
  end
end
