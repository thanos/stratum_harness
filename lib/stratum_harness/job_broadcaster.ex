defmodule StratumHarness.JobBroadcaster do
  @moduledoc """
  GenServer that periodically broadcasts new jobs to all connected sessions.
  Can be triggered manually or runs on a timer based on profile config.
  """
  use GenServer
  require Logger

  alias StratumHarness.Config
  alias StratumHarness.JobEngine

  @type state :: %{
          timer_ref: reference() | nil,
          last_job: JobEngine.job() | nil,
          job_count: non_neg_integer()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger a job broadcast.
  """
  @spec broadcast_job(keyword()) :: :ok
  def broadcast_job(opts \\ []) do
    GenServer.cast(__MODULE__, {:broadcast_job, opts})
  end

  @doc """
  Get the current job.
  """
  @spec get_current_job() :: JobEngine.job() | nil
  def get_current_job do
    GenServer.call(__MODULE__, :get_current_job)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      timer_ref: nil,
      last_job: nil,
      job_count: 0
    }

    # Schedule first job
    send(self(), :schedule_next)

    {:ok, state}
  end

  @impl true
  def handle_info(:schedule_next, state) do
    # Cancel existing timer if any
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Broadcast a new job
    state = do_broadcast_job(state, [])

    # Schedule next broadcast
    profile = Config.current_profile()
    interval = profile.behavior.job_interval_ms

    timer_ref = Process.send_after(self(), :schedule_next, interval)

    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_cast({:broadcast_job, opts}, state) do
    state = do_broadcast_job(state, opts)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_current_job, _from, state) do
    {:reply, state.last_job, state}
  end

  # Private helpers

  defp do_broadcast_job(state, opts) do
    profile = Config.current_profile()
    difficulty = Keyword.get(opts, :difficulty, profile.stratum.initial_difficulty)
    clean_jobs = Keyword.get(opts, :clean_jobs, profile.behavior.clean_jobs)

    job = JobEngine.build_job(difficulty: difficulty, clean_jobs: clean_jobs)

    Logger.info("Broadcasting job #{job.job_id} (clean_jobs: #{job.clean_jobs})")

    Phoenix.PubSub.broadcast(StratumHarness.PubSub, "job_broadcasts", {:job_broadcast, job})

    StratumHarness.Trace.add(%{
      direction: :event,
      method: "job.broadcast",
      parsed: %{job_id: job.job_id, clean_jobs: job.clean_jobs},
      metadata: %{job_count: state.job_count + 1}
    })

    %{state | last_job: job, job_count: state.job_count + 1}
  end
end
