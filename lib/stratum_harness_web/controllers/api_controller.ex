defmodule StratumHarnessWeb.ApiController do
  use StratumHarnessWeb, :controller

  alias StratumHarness.ChainSim
  alias StratumHarness.Config
  alias StratumHarness.JobBroadcaster
  alias StratumHarness.Stats
  alias StratumHarness.Trace

  @doc """
  GET /api/state
  Returns overall system state.
  """
  def state(conn, _params) do
    chain_state = ChainSim.get_state()
    current_job = JobBroadcaster.get_current_job()
    global_stats = Stats.get_global_stats()
    profile = Config.current_profile()

    json(conn, %{
      profile: profile.name,
      chain: %{
        height: chain_state.height,
        prevhash: chain_state.prevhash,
        nbits: chain_state.nbits,
        ntime: chain_state.ntime
      },
      current_job:
        if current_job do
          %{
            job_id: current_job.job_id,
            clean_jobs: current_job.clean_jobs,
            created_at: current_job.created_at
          }
        else
          nil
        end,
      stats: global_stats,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  GET /api/sessions
  Returns list of active sessions.
  """
  def sessions(conn, _params) do
    # TODO: Implement session registry/tracking
    json(conn, %{
      sessions: [],
      count: 0
    })
  end

  @doc """
  GET /api/traces
  Returns recent trace events.
  """
  def traces(conn, params) do
    limit = Map.get(params, "limit", "100") |> String.to_integer()
    session_id = Map.get(params, "session_id")

    traces = Trace.query(limit: limit, session_id: session_id)

    json(conn, %{
      traces: traces,
      count: length(traces)
    })
  end

  @doc """
  POST /api/control/profile
  Switch active profile.
  """
  def switch_profile(conn, %{"profile" => profile_name}) do
    case Config.switch_profile(profile_name) do
      :ok ->
        json(conn, %{success: true, profile: profile_name})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Profile not found"})
    end
  end

  @doc """
  POST /api/control/rotate_job
  Trigger immediate job broadcast.
  """
  def rotate_job(conn, params) do
    clean_jobs = Map.get(params, "clean_jobs", false)
    JobBroadcaster.broadcast_job(clean_jobs: clean_jobs)

    json(conn, %{success: true, message: "Job rotated"})
  end

  @doc """
  POST /api/control/advance_tip
  Advance the simulated chain tip.
  """
  def advance_tip(conn, _params) do
    :ok = ChainSim.advance()
    chain_state = ChainSim.get_state()

    json(conn, %{
      success: true,
      height: chain_state.height,
      prevhash: chain_state.prevhash
    })
  end

  @doc """
  POST /api/control/set_difficulty
  Set difficulty for new jobs (not implemented yet - needs per-session tracking).
  """
  def set_difficulty(conn, %{"difficulty" => difficulty}) when is_number(difficulty) do
    json(conn, %{
      success: true,
      message: "Difficulty adjustment not yet implemented per-session"
    })
  end

  def set_difficulty(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "Invalid difficulty parameter"})
  end

  @doc """
  GET /api/debug/bundle/:session_id
  Returns a debug bundle for a session.
  """
  def debug_bundle(conn, %{"session_id" => session_id}) do
    traces = Trace.query(limit: 100, session_id: session_id)
    session_stats = Stats.get_session_stats(session_id)

    json(conn, %{
      session_id: session_id,
      traces: traces,
      stats: session_stats,
      generated_at: System.system_time(:millisecond)
    })
  end
end
