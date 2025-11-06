defmodule Logit.Processors.Influx.Producer do
  @moduledoc false

  use GenStage
  require Logger

  def emit_metric(event) do
    GenStage.cast(__MODULE__, {:push_event, event})
  end

  # GenStage Callbacks

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      queue: :queue.new(),
      demand: 0,
      max_queue_size: Keyword.get(opts, :max_queue_size, 10_000)
    }

    {:producer, state}
  end

  @impl true
  def handle_cast({:push_event, event}, state) do
    Logger.debug(
      "#{__MODULE__} Received event, queue: #{:queue.len(state.queue)}, demand: #{state.demand}"
    )

    new_queue = :queue.in(event, state.queue)
    new_state = %{state | queue: new_queue}
    {events_to_send, final_state} = _dispatch_events(new_state)

    Logger.debug(
      "#{__MODULE__} Sending #{length(events_to_send)} events, remaining demand: #{final_state.demand}"
    )

    {:noreply, events_to_send, final_state}
  end

  @impl true
  def handle_demand(incoming_demand, state) do
    Logger.debug(
      "#{__MODULE__} Incoming demand: #{incoming_demand}, current: #{state.demand}, queue: #{:queue.len(state.queue)}"
    )

    new_state = %{state | demand: state.demand + incoming_demand}
    {events_to_send, final_state} = _dispatch_events(new_state)

    {:noreply, events_to_send, final_state}
  end

  defp _dispatch_events(%{demand: 0} = state) do
    {[], state}
  end

  defp _dispatch_events(%{queue: queue, demand: demand} = state) do
    _dequeue(queue, demand, [])
    |> case do
      {events, new_queue, used_demand} ->
        new_state = %{
          state
          | queue: new_queue,
            demand: demand - used_demand
        }

        {events, new_state}
    end
  end

  defp _dequeue(queue, 0, acc) do
    {Enum.reverse(acc), queue, length(acc)}
  end

  defp _dequeue(queue, demand, acc) do
    case :queue.out(queue) do
      {{:value, event}, new_queue} ->
        _dequeue(new_queue, demand - 1, [event | acc])

      {:empty, queue} ->
        {Enum.reverse(acc), queue, length(acc)}
    end
  end

  def ack(_ack_ref, _successful, _failed), do: :ok
end
