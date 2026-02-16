defmodule StratumHarnessWeb.DashboardLive do
  use StratumHarnessWeb, :live_view

  alias StratumHarness.ChainSim
  alias StratumHarness.Config
  alias StratumHarness.JobBroadcaster
  alias StratumHarness.Stats
  alias StratumHarness.Trace

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates
      Phoenix.PubSub.subscribe(StratumHarness.PubSub, "chain_updates")
      Phoenix.PubSub.subscribe(StratumHarness.PubSub, "job_broadcasts")
      Phoenix.PubSub.subscribe(StratumHarness.PubSub, "trace_updates")

      # Schedule periodic refresh
      :timer.send_interval(1000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:page_title, "Stratum Harness Dashboard")
      |> assign(:profile, Config.current_profile())
      |> assign(:chain_state, ChainSim.get_state())
      |> assign(:current_job, JobBroadcaster.get_current_job())
      |> assign(:global_stats, Stats.get_global_stats())
      |> assign(:traces, Trace.query(limit: 50))
      |> assign(:trace_filter_session, nil)
      |> assign(:trace_filter_method, nil)
      |> assign(:show_controls, false)

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> assign(:chain_state, ChainSim.get_state())
      |> assign(:current_job, JobBroadcaster.get_current_job())
      |> assign(:global_stats, Stats.get_global_stats())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chain_advanced, chain_state}, socket) do
    {:noreply, assign(socket, :chain_state, chain_state)}
  end

  @impl true
  def handle_info({:job_broadcast, job}, socket) do
    {:noreply, assign(socket, :current_job, job)}
  end

  @impl true
  def handle_info({:trace_added, _trace}, socket) do
    traces = Trace.query(limit: 50, session_id: socket.assigns.trace_filter_session)
    {:noreply, assign(socket, :traces, traces)}
  end

  @impl true
  def handle_event("toggle_controls", _params, socket) do
    {:noreply, assign(socket, :show_controls, not socket.assigns.show_controls)}
  end

  @impl true
  def handle_event("advance_chain", _params, socket) do
    ChainSim.advance()
    {:noreply, socket}
  end

  @impl true
  def handle_event("rotate_job", _params, socket) do
    JobBroadcaster.broadcast_job()
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_clean_jobs", _params, socket) do
    current_job = socket.assigns.current_job
    clean_jobs = if current_job, do: not current_job.clean_jobs, else: true
    JobBroadcaster.broadcast_job(clean_jobs: clean_jobs)
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_profile", %{"profile" => profile_name}, socket) do
    case Config.switch_profile(profile_name) do
      :ok ->
        socket =
          socket
          |> assign(:profile, Config.current_profile())
          |> put_flash(:info, "Switched to profile: #{profile_name}")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Profile not found: #{profile_name}")}
    end
  end

  @impl true
  def handle_event("filter_traces", %{"session_id" => session_id}, socket) do
    session_id = if session_id == "", do: nil, else: session_id
    traces = Trace.query(limit: 50, session_id: session_id)

    socket =
      socket
      |> assign(:trace_filter_session, session_id)
      |> assign(:traces, traces)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_traces", _params, socket) do
    Trace.clear()
    {:noreply, assign(socket, :traces, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <%!-- Header --%>
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-slate-900">Stratum Harness</h1>
            <p class="mt-2 text-sm text-slate-600">
              Developer tool for testing Stratum V1 mining protocol
            </p>
          </div>

          <%!-- Profile Info --%>
          <div class="mb-6 rounded-lg bg-white p-4 shadow">
            <div class="flex items-center justify-between">
              <div>
                <span class="text-sm font-medium text-slate-700">Active Profile:</span>
                <span class="ml-2 rounded-full bg-blue-100 px-3 py-1 text-sm font-semibold text-blue-800">
                  {@profile.name}
                </span>
                <span class="ml-2 text-sm text-slate-500">{@profile.description}</span>
              </div>
              <button
                phx-click="toggle_controls"
                class="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
              >
                {if @show_controls, do: "Hide Controls", else: "Show Controls"}
              </button>
            </div>
          </div>

          <%!-- Controls Panel --%>
          <%= if @show_controls do %>
            <div class="mb-6 rounded-lg bg-white p-6 shadow">
              <h2 class="mb-4 text-lg font-semibold text-slate-900">Controls</h2>
              <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                <button
                  phx-click="rotate_job"
                  class="rounded-md bg-green-600 px-4 py-2 text-white hover:bg-green-700"
                >
                  Rotate Job Now
                </button>
                <button
                  phx-click="advance_chain"
                  class="rounded-md bg-purple-600 px-4 py-2 text-white hover:bg-purple-700"
                >
                  Advance Chain Tip
                </button>
                <button
                  phx-click="toggle_clean_jobs"
                  class="rounded-md bg-orange-600 px-4 py-2 text-white hover:bg-orange-700"
                >
                  Toggle Clean Jobs
                </button>
                <.form for={%{}} phx-submit="switch_profile">
                  <select
                    name="profile"
                    class="block w-full rounded-md border-slate-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option :for={profile <- Config.list_profiles()} value={profile}>
                      {profile}
                    </option>
                  </select>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Stats Grid --%>
          <div class="mb-6 grid gap-6 md:grid-cols-2 lg:grid-cols-4">
            <.stat_card
              title="Connections"
              value={@global_stats[:connections_current] || 0}
              subtitle="Active sessions"
              color="blue"
            />
            <.stat_card
              title="Shares Accepted"
              value={@global_stats[:shares_accepted] || 0}
              subtitle="Valid submissions"
              color="green"
            />
            <.stat_card
              title="Shares Rejected"
              value={
                (@global_stats[:shares_rejected_stale] || 0) +
                  (@global_stats[:shares_rejected_low_diff] || 0) +
                  (@global_stats[:shares_rejected_duplicate] || 0)
              }
              subtitle="All rejection reasons"
              color="red"
            />
            <.stat_card
              title="Block Candidates"
              value={@global_stats[:block_candidates] || 0}
              subtitle="Found by miners"
              color="purple"
            />
          </div>

          <%!-- Chain State --%>
          <div class="mb-6 rounded-lg bg-white p-6 shadow">
            <h2 class="mb-4 text-lg font-semibold text-slate-900">Chain State</h2>
            <dl class="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div>
                <dt class="text-sm font-medium text-slate-500">Height</dt>
                <dd class="mt-1 text-lg font-semibold text-slate-900">{@chain_state.height}</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-slate-500">Previous Hash</dt>
                <dd class="mt-1 font-mono text-xs text-slate-700">
                  {String.slice(@chain_state.prevhash, 0..31)}...
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-slate-500">nBits</dt>
                <dd class="mt-1 font-mono text-sm text-slate-900">{@chain_state.nbits}</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-slate-500">nTime</dt>
                <dd class="mt-1 font-mono text-sm text-slate-900">{@chain_state.ntime}</dd>
              </div>
            </dl>
          </div>

          <%!-- Current Job --%>
          <%= if @current_job do %>
            <div class="mb-6 rounded-lg bg-white p-6 shadow">
              <h2 class="mb-4 text-lg font-semibold text-slate-900">Current Job</h2>
              <dl class="grid grid-cols-1 gap-4 md:grid-cols-2">
                <div>
                  <dt class="text-sm font-medium text-slate-500">Job ID</dt>
                  <dd class="mt-1 font-mono text-sm text-slate-900">{@current_job.job_id}</dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-slate-500">Clean Jobs</dt>
                  <dd class="mt-1">
                    <span class={[
                      "rounded-full px-2 py-1 text-xs font-semibold",
                      if(@current_job.clean_jobs,
                        do: "bg-orange-100 text-orange-800",
                        else: "bg-slate-100 text-slate-800"
                      )
                    ]}>
                      {if @current_job.clean_jobs, do: "TRUE", else: "FALSE"}
                    </span>
                  </dd>
                </div>
                <div class="md:col-span-2">
                  <dt class="text-sm font-medium text-slate-500">Age</dt>
                  <dd class="mt-1 text-sm text-slate-900">
                    {format_age(@current_job.created_at)}
                  </dd>
                </div>
              </dl>
            </div>
          <% end %>

          <%!-- Message Trace --%>
          <div class="rounded-lg bg-white p-6 shadow">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-lg font-semibold text-slate-900">Message Trace</h2>
              <button
                phx-click="clear_traces"
                class="text-sm text-red-600 hover:text-red-800"
              >
                Clear All
              </button>
            </div>

            <div class="mb-4">
              <.form for={%{}} phx-change="filter_traces">
                <input
                  type="text"
                  name="session_id"
                  placeholder="Filter by session ID..."
                  value={@trace_filter_session || ""}
                  class="block w-full rounded-md border-slate-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </.form>
            </div>

            <div class="space-y-2 overflow-y-auto" style="max-height: 500px;">
              <div :for={trace <- @traces} class={[
                "rounded-md border p-3 text-sm",
                trace_border_color(trace.direction)
              ]}>
                <div class="mb-1 flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <span class={[
                      "rounded px-2 py-0.5 text-xs font-semibold",
                      trace_badge_color(trace.direction)
                    ]}>
                      {trace.direction |> to_string() |> String.upcase()}
                    </span>
                    <%= if trace.method do %>
                      <span class="font-mono text-xs text-slate-700">{trace.method}</span>
                    <% end %>
                    <%= if trace.session_id do %>
                      <span class="font-mono text-xs text-slate-500">
                        session: {String.slice(trace.session_id, 0..7)}
                      </span>
                    <% end %>
                  </div>
                  <span class="text-xs text-slate-500">
                    {format_timestamp(trace.timestamp)}
                  </span>
                </div>
                <%= if trace.raw do %>
                  <pre class="mt-2 overflow-x-auto rounded bg-slate-50 p-2 font-mono text-xs text-slate-700">{trace.raw}</pre>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg bg-white p-6 shadow">
      <dt class="text-sm font-medium text-slate-500">{@title}</dt>
      <dd class={[
        "mt-2 text-3xl font-bold",
        case @color do
          "blue" -> "text-blue-600"
          "green" -> "text-green-600"
          "red" -> "text-red-600"
          "purple" -> "text-purple-600"
          _ -> "text-slate-900"
        end
      ]}>
        {@value}
      </dd>
      <p class="mt-1 text-xs text-slate-500">{@subtitle}</p>
    </div>
    """
  end

  defp trace_border_color(:in), do: "border-blue-200 bg-blue-50"
  defp trace_border_color(:out), do: "border-green-200 bg-green-50"
  defp trace_border_color(:event), do: "border-slate-200 bg-slate-50"

  defp trace_badge_color(:in), do: "bg-blue-600 text-white"
  defp trace_badge_color(:out), do: "bg-green-600 text-white"
  defp trace_badge_color(:event), do: "bg-slate-600 text-white"

  defp format_timestamp(microseconds) do
    datetime = DateTime.from_unix!(microseconds, :microsecond)
    Calendar.strftime(datetime, "%H:%M:%S.%f")
  end

  defp format_age(created_at_ms) do
    now = System.system_time(:millisecond)
    age_ms = now - created_at_ms
    age_sec = div(age_ms, 1000)

    cond do
      age_sec < 60 -> "#{age_sec}s ago"
      age_sec < 3600 -> "#{div(age_sec, 60)}m ago"
      true -> "#{div(age_sec, 3600)}h ago"
    end
  end
end
