defmodule Logit.Processors.Influx.Phoenix do
  @moduledoc false

  require Logger

  alias Logit.Processors.WebHelpers

  def attach(config \\ nil) do
    Logger.debug("#{__MODULE__} Starting telemetry handler")

    events = [
      [:phoenix, :endpoint, :stop],
      [:phoenix, :endpoint, :exception]
    ]

    :telemetry.attach_many(
      "phoenix-influx-metrics",
      events,
      &__MODULE__.handle_event/4,
      config
    )
  end

  def handle_event([:phoenix, :endpoint, event], measurements, %{conn: conn}, _config) do
    {tags, values} = WebHelpers.phoenix_report(event, conn, measurements)

    Logit.Processors.Influx.report("phoenix.inbound", tags, values)
  end
end
