defmodule StratumHarness.Stats do
  @moduledoc """
  Statistics tracking using ETS and Telemetry.
  Tracks per-session and global counters for shares, connections, etc.
  """

  @table_name :stratum_stats

  @type stat_key ::
          {:global, atom()}
          | {:session, String.t(), atom()}

  @doc """
  Initialize the stats store.
  """
  def init do
    :ets.new(@table_name, [:named_table, :set, :public, write_concurrency: true])
    reset_global_stats()
    :ok
  end

  @doc """
  Increment a counter.
  """
  @spec increment(stat_key(), integer()) :: :ok
  def increment(key, amount \\ 1) do
    :ets.update_counter(@table_name, key, {2, amount}, {key, 0})
    :ok
  end

  @doc """
  Get a counter value.
  """
  @spec get(stat_key()) :: integer()
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  @doc """
  Get all global stats.
  """
  @spec get_global_stats() :: map()
  def get_global_stats do
    @table_name
    |> :ets.match({{:global, :"$1"}, :"$2"})
    |> Enum.into(%{}, fn [key, value] -> {key, value} end)
  end

  @doc """
  Get all stats for a session.
  """
  @spec get_session_stats(String.t()) :: map()
  def get_session_stats(session_id) do
    @table_name
    |> :ets.match({{:session, session_id, :"$1"}, :"$2"})
    |> Enum.into(%{}, fn [key, value] -> {key, value} end)
  end

  @doc """
  Reset global stats.
  """
  def reset_global_stats do
    global_keys = [
      :connections_total,
      :connections_current,
      :shares_accepted,
      :shares_rejected_stale,
      :shares_rejected_low_diff,
      :shares_rejected_duplicate,
      :shares_rejected_malformed,
      :block_candidates
    ]

    Enum.each(global_keys, fn key ->
      :ets.insert(@table_name, {{:global, key}, 0})
    end)
  end

  @doc """
  Initialize stats for a new session.
  """
  @spec init_session(String.t()) :: :ok
  def init_session(session_id) do
    session_keys = [
      :shares_accepted,
      :shares_rejected_stale,
      :shares_rejected_low_diff,
      :shares_rejected_duplicate,
      :shares_rejected_malformed,
      :block_candidates
    ]

    Enum.each(session_keys, fn key ->
      :ets.insert(@table_name, {{:session, session_id, key}, 0})
    end)

    :ok
  end

  @doc """
  Clear stats for a session.
  """
  @spec clear_session(String.t()) :: :ok
  def clear_session(session_id) do
    @table_name
    |> :ets.match({{:session, session_id, :_}, :_})
    |> Enum.each(fn [key] ->
      :ets.delete(@table_name, {:session, session_id, key})
    end)

    :ok
  end

  @doc """
  Record a share result.
  """
  @spec record_share(String.t(), :accepted | :block_candidate | atom()) :: :ok
  def record_share(session_id, result) do
    case result do
      :accepted ->
        increment({:global, :shares_accepted})
        increment({:session, session_id, :shares_accepted})

      :block_candidate ->
        increment({:global, :shares_accepted})
        increment({:session, session_id, :shares_accepted})
        increment({:global, :block_candidates})
        increment({:session, session_id, :block_candidates})

      :stale ->
        increment({:global, :shares_rejected_stale})
        increment({:session, session_id, :shares_rejected_stale})

      :low_difficulty ->
        increment({:global, :shares_rejected_low_diff})
        increment({:session, session_id, :shares_rejected_low_diff})

      :duplicate ->
        increment({:global, :shares_rejected_duplicate})
        increment({:session, session_id, :shares_rejected_duplicate})

      :malformed ->
        increment({:global, :shares_rejected_malformed})
        increment({:session, session_id, :shares_rejected_malformed})
    end

    :ok
  end
end
