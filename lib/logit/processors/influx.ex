defmodule Logit.Processors.Influx do
  @moduledoc false

  require Logger

  use Supervisor

  defstruct [
    :name,
    :tags,
    :fields
  ]

  @default_processors [
    Logit.Processors.Influx.Phoenix,
    Logit.Processors.Influx.LiveView,
    Logit.Processors.Influx.Vm
  ]

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(args) do
    consumer_config = struct(Logit.Processors.Influx.Consumer, Enum.into(args, %{}))

    children = [
      # Logit.Processors.Influx.Producer,
      {Logit.Processors.Influx.Producer, []},
      {Logit.Processors.Influx.Consumer, consumer_config}
    ]

    _start_processors_or_default(args)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def _start_processors_or_default(args) do
    if args[:processors] do
      Enum.each(
        args[:processors],
        fn
          {module, opts} ->
            module.attach(opts)

          module ->
            module.attach()
        end
      )
    else
      Enum.each(@default_processors, & &1.attach())
    end
  end

  def report(event, tags \\ [], fields) do
    event = %__MODULE__{name: "app_metrics.#{event}", tags: tags, fields: fields}

    Logit.Processors.Influx.Producer.emit_metric(event)
  end
end
