defmodule Logit.Processors.Influx.Vm do
  @moduledoc false

  alias Logit.Processors.Influx

  def attach(config \\ nil) do
    events = [
      [:vm, :memory],
      [:vm, :total_run_queue_lengths],
      [:vm, :system_counts]
    ]

    :telemetry.attach_many("influx-vm-metrics", events, &__MODULE__.handle_event/4, config)
  end

  def handle_event([:vm, key], measurements, _, _config) do
    Influx.report("vm." <> to_string(key), Enum.into(measurements, []))
  end
end
