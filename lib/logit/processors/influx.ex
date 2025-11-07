defmodule Logit.Processors.Influx do
  @moduledoc false

  require Logger

  use Supervisor

  defstruct [
    :name,
    :tags,
    :fields
  ]

  @app_processors [Logit.Processors.Influx.Vm]
  @web_app_processors [Logit.Processors.Influx.Phoenix, Logit.Processors.Influx.LiveView] ++
                        @app_processors

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

  def report(event, tags \\ [], fields) do
    event = %__MODULE__{name: "app_metrics.#{event}", tags: _with_meta_tags(tags), fields: fields}

    Logit.Processors.Influx.Producer.emit_metric(event)
  end

  def default_processors, do: @app_processors

  def app_processors, do: @app_processors

  def web_app_processors, do: @web_app_processors

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
      Enum.each(default_processors(), & &1.attach())
    end
  end

  defp _with_meta_tags(%{} = tags) do
    tags
    |> Enum.into([])
    |> _with_meta_tags()
  end

  defp _with_meta_tags(tags) do
    [
      hostname: _hostname(),
      app_name: _app_name(),
      app_version: _app_version()
    ]
    |> Keyword.merge(tags)
  end

  defp _app_version do
    {_, ver} = :init.script_id()

    to_string(ver)
  end

  defp _app_name do
    {app, _} = :init.script_id()

    System.get_env("APP_NAME", to_string(app))
  end

  defp _hostname do
    {:ok, hostname} = :inet.gethostname()

    to_string(hostname)
  end
end
