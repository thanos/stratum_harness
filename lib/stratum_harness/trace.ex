defmodule StratumHarness.Trace do
  @moduledoc """
  ETS-backed ring buffer for storing message traces and events.
  Provides efficient storage and querying for the UI and API.
  """

  @table_name :stratum_trace
  @max_global_entries 10_000

  @type trace_event :: %{
          id: String.t(),
          timestamp: integer(),
          session_id: String.t() | nil,
          direction: :in | :out | :event,
          method: String.t() | nil,
          raw: String.t() | nil,
          parsed: map() | nil,
          metadata: map()
        }

  @doc """
  Initialize the trace store.
  """
  def init do
    :ets.new(@table_name, [:named_table, :ordered_set, :public, read_concurrency: true])
    :ok
  end

  @doc """
  Add a trace event.
  """
  @spec add(trace_event()) :: :ok
  def add(event) do
    id = event[:id] || generate_id()
    timestamp = event[:timestamp] || System.system_time(:microsecond)

    entry = %{
      id: id,
      timestamp: timestamp,
      session_id: event[:session_id],
      direction: event[:direction],
      method: event[:method],
      raw: event[:raw],
      parsed: event[:parsed],
      metadata: event[:metadata] || %{}
    }

    :ets.insert(@table_name, {{timestamp, id}, entry})

    # Trim old entries
    trim_old_entries()

    # Broadcast to LiveView
    Phoenix.PubSub.broadcast(StratumHarness.PubSub, "trace_updates", {:trace_added, entry})

    :ok
  end

  @doc """
  Query traces with filters.
  """
  @spec query(keyword()) :: [trace_event()]
  def query(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    session_id = Keyword.get(opts, :session_id)
    method = Keyword.get(opts, :method)
    direction = Keyword.get(opts, :direction)

    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_key, event} -> event end)
    |> filter_by_session(session_id)
    |> filter_by_method(method)
    |> filter_by_direction(direction)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get the count of traces.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Clear all traces.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # Private helpers

  defp filter_by_session(events, nil), do: events

  defp filter_by_session(events, session_id) do
    Enum.filter(events, &(&1.session_id == session_id))
  end

  defp filter_by_method(events, nil), do: events

  defp filter_by_method(events, method) do
    Enum.filter(events, &(&1.method == method))
  end

  defp filter_by_direction(events, nil), do: events

  defp filter_by_direction(events, direction) do
    Enum.filter(events, &(&1.direction == direction))
  end

  defp trim_old_entries do
    size = :ets.info(@table_name, :size)

    if size > @max_global_entries do
      # Delete oldest entries
      to_delete = size - @max_global_entries

      @table_name
      |> :ets.first()
      |> delete_n_entries(to_delete)
    end
  end

  defp delete_n_entries(:"$end_of_table", _n), do: :ok
  defp delete_n_entries(_key, 0), do: :ok

  defp delete_n_entries(key, n) do
    next_key = :ets.next(@table_name, key)
    :ets.delete(@table_name, key)
    delete_n_entries(next_key, n - 1)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
