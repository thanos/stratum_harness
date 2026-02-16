defmodule StratumHarness.Stratum.Session do
  @moduledoc """
  Per-connection GenServer that manages a Stratum session.
  Handles protocol messages, state machine, and share validation.
  """
  use GenServer, restart: :temporary
  require Logger

  alias StratumHarness.Config
  alias StratumHarness.JobEngine
  alias StratumHarness.Stats
  alias StratumHarness.Stratum.Protocol
  alias StratumHarness.Trace

  @type state :: %{
          session_id: String.t(),
          socket: :gen_tcp.socket(),
          remote_ip: tuple(),
          remote_port: integer(),
          subscribed?: boolean(),
          authorized?: boolean(),
          username: String.t() | nil,
          worker_name: String.t() | nil,
          extranonce1: binary(),
          extranonce2_size: pos_integer(),
          difficulty: float(),
          current_job: JobEngine.job() | nil,
          job_history: [String.t()],
          vardiff: map(),
          submitted_shares: MapSet.t(),
          connected_at: integer(),
          last_activity: integer()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Send a job notification to the session.
  """
  def notify_job(pid, job) do
    GenServer.cast(pid, {:notify_job, job})
  end

  @doc """
  Update the difficulty for the session.
  """
  def set_difficulty(pid, difficulty) do
    GenServer.cast(pid, {:set_difficulty, difficulty})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    socket = Keyword.fetch!(opts, :socket)
    remote_ip = Keyword.fetch!(opts, :remote_ip)
    remote_port = Keyword.fetch!(opts, :remote_port)

    session_id = generate_session_id()
    profile = Config.current_profile()

    extranonce1 = :crypto.strong_rand_bytes(profile.stratum.extranonce1_size)

    state = %{
      session_id: session_id,
      socket: socket,
      remote_ip: remote_ip,
      remote_port: remote_port,
      subscribed?: false,
      authorized?: false,
      username: nil,
      worker_name: nil,
      extranonce1: extranonce1,
      extranonce2_size: profile.stratum.extranonce2_size,
      difficulty: profile.stratum.initial_difficulty,
      current_job: nil,
      job_history: [],
      vardiff: init_vardiff(),
      submitted_shares: MapSet.new(),
      connected_at: System.system_time(:millisecond),
      last_activity: System.system_time(:millisecond)
    }

    # Initialize stats
    Stats.init_session(session_id)
    Stats.increment({:global, :connections_total})
    Stats.increment({:global, :connections_current})

    # Log connection
    Trace.add(%{
      session_id: session_id,
      direction: :event,
      method: "connection.opened",
      metadata: %{
        remote_ip: format_ip(remote_ip),
        remote_port: remote_port
      }
    })

    # Subscribe to chain updates
    Phoenix.PubSub.subscribe(StratumHarness.PubSub, "chain_updates")
    Phoenix.PubSub.subscribe(StratumHarness.PubSub, "job_broadcasts")

    # Start reading from socket
    :inet.setopts(socket, active: :once)

    Logger.info("Session #{session_id} started for #{format_ip(remote_ip)}:#{remote_port}")

    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    state = update_last_activity(state)

    # Parse and handle message
    case Protocol.decode(data) do
      {:ok, message} ->
        Trace.add(%{
          session_id: state.session_id,
          direction: :in,
          method: message["method"],
          raw: String.trim(data),
          parsed: message
        })

        state = handle_stratum_message(message, state)
        :inet.setopts(socket, active: :once)
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Session #{state.session_id}: Failed to decode message: #{reason}")

        Trace.add(%{
          session_id: state.session_id,
          direction: :in,
          method: "parse_error",
          raw: String.trim(data),
          metadata: %{error: reason}
        })

        :inet.setopts(socket, active: :once)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.info("Session #{state.session_id} closed by client")

    Trace.add(%{
      session_id: state.session_id,
      direction: :event,
      method: "connection.closed",
      metadata: %{reason: "client_closed"}
    })

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.warning("Session #{state.session_id} error: #{inspect(reason)}")

    Trace.add(%{
      session_id: state.session_id,
      direction: :event,
      method: "connection.error",
      metadata: %{reason: inspect(reason)}
    })

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:chain_advanced, _chain_state}, state) do
    # Chain advanced, might trigger new job
    {:noreply, state}
  end

  @impl true
  def handle_info({:job_broadcast, job}, state) do
    # New job broadcast, send to miner if authorized
    state =
      if state.authorized? do
        send_job_notification(job, state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:record_share, share_key}, state) do
    {:noreply, %{state | submitted_shares: MapSet.put(state.submitted_shares, share_key)}}
  end

  @impl true
  def handle_cast({:notify_job, job}, state) do
    state = send_job_notification(job, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_difficulty, difficulty}, state) do
    state = %{state | difficulty: difficulty}
    send_set_difficulty(difficulty, state)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Stats.increment({:global, :connections_current}, -1)
    :gen_tcp.close(state.socket)
    :ok
  end

  # Protocol Handlers

  defp handle_stratum_message(%{"method" => "mining.subscribe"} = msg, state) do
    handle_subscribe(msg, state)
  end

  defp handle_stratum_message(%{"method" => "mining.authorize"} = msg, state) do
    handle_authorize(msg, state)
  end

  defp handle_stratum_message(%{"method" => "mining.submit"} = msg, state) do
    handle_submit(msg, state)
  end

  defp handle_stratum_message(%{"method" => "mining.extranonce.subscribe"}, state) do
    # Acknowledge extranonce subscription
    send_response(%{id: 1, result: true, error: nil}, state)
    state
  end

  defp handle_stratum_message(msg, state) do
    Logger.warning("Session #{state.session_id}: Unknown method: #{inspect(msg)}")
    state
  end

  defp handle_subscribe(msg, state) do
    id = msg["id"]
    # params = msg["params"] || []

    # Build subscription response
    result = [
      [["mining.notify", generate_subscription_id()], ["mining.set_difficulty", generate_subscription_id()]],
      Base.encode16(state.extranonce1, case: :lower),
      state.extranonce2_size
    ]

    response = %{
      id: id,
      result: result,
      error: nil
    }

    send_response(response, state)

    %{state | subscribed?: true}
  end

  defp handle_authorize(msg, state) do
    id = msg["id"]
    params = msg["params"] || []

    [username | _] = params ++ [nil, nil]

    # Parse username.worker
    {user, worker} = parse_username(username)

    # Check authorization
    profile = Config.current_profile()

    authorized? =
      case profile.behavior.auth_mode do
        :open ->
          true

        :strict ->
          token = profile.behavior.auth_token
          user == token || username == token
      end

    response = %{
      id: id,
      result: authorized?,
      error: if(authorized?, do: nil, else: [21, "Unauthorized worker", nil])
    }

    send_response(response, state)

    state = %{state | authorized?: authorized?, username: user, worker_name: worker}

    if authorized? do
      # Send initial difficulty
      send_set_difficulty(state.difficulty, state)

      # Send initial job
      job = JobEngine.build_job(difficulty: state.difficulty)
      send_job_notification(job, state)
    else
      state
    end
  end

  defp handle_submit(msg, state) do
    id = msg["id"]
    params = msg["params"] || []

    if not state.authorized? do
      response = %{
        id: id,
        result: false,
        error: [24, "Unauthorized worker", nil]
      }

      send_response(response, state)
      Stats.record_share(state.session_id, :malformed)
      state
    else
      [_worker_name, job_id, extranonce2, ntime, nonce | _] = params ++ [nil, nil, nil, nil, nil]

      # Validate submit
      result = validate_and_record_share(state, job_id, extranonce2, ntime, nonce)

      {accepted?, error, new_state} =
        case result do
          {:ok, :accepted, details} ->
            Stats.record_share(state.session_id, :accepted)
            log_share_result(state, :accepted, details)
            {true, nil, state}

          {:ok, :block_candidate, details} ->
            Stats.record_share(state.session_id, :block_candidate)
            log_share_result(state, :block_candidate, details)
            Logger.info("Session #{state.session_id} found BLOCK CANDIDATE! Hash: #{details.hash}")
            {true, nil, state}

          {:error, :stale, details} ->
            Stats.record_share(state.session_id, :stale)
            log_share_result(state, :stale, details)
            {false, [21, "Stale share", nil], state}

          {:error, :low_difficulty, details} ->
            Stats.record_share(state.session_id, :low_difficulty)
            log_share_result(state, :low_difficulty, details)
            {false, [23, "Low difficulty share", nil], state}

          {:error, :duplicate, details} ->
            Stats.record_share(state.session_id, :duplicate)
            log_share_result(state, :duplicate, details)
            {false, [22, "Duplicate share", nil], state}

          {:error, :malformed, reason} ->
            Stats.record_share(state.session_id, :malformed)
            {false, [20, "Malformed share: #{reason}", nil], state}
        end

      response = %{
        id: id,
        result: accepted?,
        error: error
      }

      send_response(response, new_state)
      new_state
    end
  end

  defp validate_and_record_share(state, job_id, extranonce2, ntime, nonce) do
    # Check if job is current or in history
    current_job = state.current_job

    cond do
      is_nil(current_job) ->
        {:error, :malformed, "No active job"}

      current_job.job_id != job_id and job_id not in state.job_history ->
        {:error, :stale, %{job_id: job_id, current_job_id: current_job.job_id}}

      true ->
        # Build share key for duplicate detection
        share_key = {job_id, extranonce2, ntime, nonce}

        if MapSet.member?(state.submitted_shares, share_key) do
          {:error, :duplicate, %{share_key: share_key}}
        else
          # Validate the share
          result =
            JobEngine.validate_share(current_job, state.extranonce1, extranonce2, ntime, nonce)

          # Add to submitted shares
          send(
            self(),
            {:record_share, share_key}
          )

          result
        end
    end
  end

  defp send_job_notification(job, state) do
    notification = %{
      id: nil,
      method: "mining.notify",
      params: [
        job.job_id,
        job.prevhash,
        job.coinbase1,
        job.coinbase2,
        job.merkle_branches,
        job.version,
        job.nbits,
        job.ntime,
        job.clean_jobs
      ]
    }

    send_response(notification, state)

    # Update job history
    job_history =
      [job.job_id | state.job_history]
      |> Enum.take(Config.current_profile().behavior.stale_job_window)

    %{state | current_job: job, job_history: job_history}
  end

  defp send_set_difficulty(difficulty, state) do
    notification = %{
      id: nil,
      method: "mining.set_difficulty",
      params: [difficulty]
    }

    send_response(notification, state)
  end

  defp send_response(response, state) do
    json = Protocol.encode(response)

    Trace.add(%{
      session_id: state.session_id,
      direction: :out,
      method: response[:method],
      raw: String.trim(json),
      parsed: response
    })

    :gen_tcp.send(state.socket, json <> "\n")
  end

  defp log_share_result(state, result, details) do
    Trace.add(%{
      session_id: state.session_id,
      direction: :event,
      method: "share.#{result}",
      parsed: details,
      metadata: %{result: result, worker: state.worker_name}
    })
  end

  # Helpers

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_subscription_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp parse_username(nil), do: {nil, nil}

  defp parse_username(username) do
    case String.split(username, ".", parts: 2) do
      [user, worker] -> {user, worker}
      [user] -> {user, nil}
    end
  end

  defp format_ip({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp init_vardiff do
    %{
      last_adjustment: System.system_time(:millisecond),
      shares_in_window: 0
    }
  end

  defp update_last_activity(state) do
    %{state | last_activity: System.system_time(:millisecond)}
  end
end
