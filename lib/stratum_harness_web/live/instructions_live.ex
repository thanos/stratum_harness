defmodule StratumHarnessWeb.InstructionsLive do
  use StratumHarnessWeb, :live_view

  alias StratumHarness.Config

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Miner Instructions")
      |> assign(:stratum_port, Config.stratum_port())
      |> assign(:profile, Config.current_profile())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
      <div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-slate-900">Connect Your Verus Miner</h1>
          <p class="mt-2 text-lg text-slate-600">
            Step-by-step guide to connect and test your miner with this Stratum harness
          </p>
        </div>

        <%!-- Quick Start --%>
        <div class="mb-8 rounded-lg bg-blue-50 p-6">
          <h2 class="mb-4 text-xl font-semibold text-blue-900">Quick Start</h2>
          <div class="space-y-4">
            <div class="flex items-start gap-3">
              <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-blue-600 text-white font-semibold">
                1
              </div>
              <div>
                <p class="font-medium text-blue-900">Verify the Stratum server is running</p>
                <p class="mt-1 text-sm text-blue-800">
                  Server listening on: <code class="rounded bg-blue-100 px-2 py-1 font-mono">localhost:{@stratum_port}</code>
                </p>
              </div>
            </div>

            <div class="flex items-start gap-3">
              <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-blue-600 text-white font-semibold">
                2
              </div>
              <div>
                <p class="font-medium text-blue-900">Configure your miner</p>
                <p class="mt-1 text-sm text-blue-800">
                  Point your miner to the Stratum URL below
                </p>
              </div>
            </div>

            <div class="flex items-start gap-3">
              <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-blue-600 text-white font-semibold">
                3
              </div>
              <div>
                <p class="font-medium text-blue-900">Monitor the dashboard</p>
                <p class="mt-1 text-sm text-blue-800">
                  Watch real-time connections and share submissions
                </p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Connection Details --%>
        <div class="mb-8 rounded-lg bg-white p-6 shadow">
          <h2 class="mb-4 text-xl font-semibold text-slate-900">Connection Details</h2>

          <div class="space-y-4">
            <div>
              <label class="text-sm font-medium text-slate-700">Stratum URL</label>
              <div class="mt-1 flex items-center gap-2">
                <code class="flex-1 rounded-md bg-slate-100 px-4 py-2 font-mono text-sm">
                  stratum+tcp://localhost:{@stratum_port}
                </code>
                <button
                  class="rounded-md bg-slate-200 px-3 py-2 text-sm hover:bg-slate-300"
                  onclick={"navigator.clipboard.writeText('stratum+tcp://localhost:#{@stratum_port}')"}
                >
                  Copy
                </button>
              </div>
            </div>

            <div>
              <label class="text-sm font-medium text-slate-700">Username</label>
              <p class="mt-1 text-sm text-slate-600">
                Any username is accepted (e.g., <code class="rounded bg-slate-100 px-2 py-1 font-mono">testuser</code>)
              </p>
            </div>

            <div>
              <label class="text-sm font-medium text-slate-700">Password</label>
              <p class="mt-1 text-sm text-slate-600">
                Any password is accepted (e.g., <code class="rounded bg-slate-100 px-2 py-1 font-mono">x</code>)
              </p>
            </div>

            <div>
              <label class="text-sm font-medium text-slate-700">Worker Name</label>
              <p class="mt-1 text-sm text-slate-600">
                Optional. Use format: <code class="rounded bg-slate-100 px-2 py-1 font-mono">username.worker1</code>
              </p>
            </div>
          </div>
        </div>

        <%!-- Example Commands --%>
        <div class="mb-8 rounded-lg bg-white p-6 shadow">
          <h2 class="mb-4 text-xl font-semibold text-slate-900">Example Miner Commands</h2>

          <div class="space-y-6">
            <%!-- cpuminer-like --%>
            <div>
              <h3 class="mb-2 font-medium text-slate-800">Generic CPU Miner</h3>
              <pre class="overflow-x-auto rounded-md bg-slate-900 p-4 text-sm text-slate-100">./cpuminer \
    --url stratum+tcp://localhost:{@stratum_port} \
    --user testuser.worker1 \
    --pass x</pre>
            </div>

            <%!-- Custom Zig Miner --%>
            <div>
              <h3 class="mb-2 font-medium text-slate-800">Custom Zig/C Miner</h3>
              <pre class="overflow-x-auto rounded-md bg-slate-900 p-4 text-sm text-slate-100">./your-miner \
    --server localhost \
    --port {@stratum_port} \
    --user testuser \
    --password x</pre>
            </div>

            <%!-- JSON Config --%>
            <div>
              <h3 class="mb-2 font-medium text-slate-800">JSON Configuration</h3>
              <pre class="overflow-x-auto rounded-md bg-slate-900 p-4 text-sm text-slate-100" phx-no-format><%= Jason.encode!(%{
  "pools" => [
    %{
      "url" => "stratum+tcp://localhost:#{@stratum_port}",
      "user" => "testuser.worker1",
      "pass" => "x"
    }
  ]
}, pretty: true) %></pre>
            </div>
          </div>
        </div>

        <%!-- Current Profile Info --%>
        <div class="mb-8 rounded-lg bg-white p-6 shadow">
          <h2 class="mb-4 text-xl font-semibold text-slate-900">Current Profile: {@profile.name}</h2>
          <p class="mb-4 text-sm text-slate-600">{@profile.description}</p>

          <dl class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <dt class="text-sm font-medium text-slate-700">Initial Difficulty</dt>
              <dd class="mt-1 text-lg font-semibold text-slate-900">
                {@profile.stratum.initial_difficulty}
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-slate-700">Job Interval</dt>
              <dd class="mt-1 text-lg font-semibold text-slate-900">
                {div(@profile.behavior.job_interval_ms, 1000)}s
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-slate-700">Extranonce Sizes</dt>
              <dd class="mt-1 text-lg font-semibold text-slate-900">
                {@profile.stratum.extranonce1_size} + {@profile.stratum.extranonce2_size} bytes
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-slate-700">Clean Jobs</dt>
              <dd class="mt-1 text-lg font-semibold text-slate-900">
                {if @profile.behavior.clean_jobs, do: "Enabled", else: "Disabled"}
              </dd>
            </div>
          </dl>
        </div>

        <%!-- Testing Tips --%>
        <div class="mb-8 rounded-lg bg-green-50 p-6">
          <h2 class="mb-4 text-xl font-semibold text-green-900">Testing Tips</h2>
          <ul class="list-disc space-y-2 pl-5 text-sm text-green-800">
            <li>
              Start with <strong>easy_local</strong> profile for ultra-low difficulty (quick testing)
            </li>
            <li>
              Check the <strong>Dashboard</strong> to see your miner connect and submit shares
            </li>
            <li>
              Use <strong>Message Trace</strong> to inspect protocol messages in real-time
            </li>
            <li>
              If shares are rejected, check the rejection reason and computed hash details
            </li>
            <li>
              Export debug bundles via API: <code class="rounded bg-green-100 px-2 py-1 font-mono">
                /api/debug/bundle/SESSION_ID
              </code>
            </li>
          </ul>
        </div>

        <%!-- Common Issues --%>
        <div class="mb-8 rounded-lg bg-white p-6 shadow">
          <h2 class="mb-4 text-xl font-semibold text-slate-900">Common Issues</h2>

          <div class="space-y-4">
            <div>
              <h3 class="font-medium text-slate-800">Connection refused</h3>
              <p class="mt-1 text-sm text-slate-600">
                → Verify the Stratum server is running. Check terminal for "Stratum server listening on port {@stratum_port}"
              </p>
            </div>

            <div>
              <h3 class="font-medium text-slate-800">All shares rejected (low difficulty)</h3>
              <p class="mt-1 text-sm text-slate-600">
                → Switch to <strong>easy_local</strong> profile with ultra-low difficulty
              </p>
              <pre class="mt-2 overflow-x-auto rounded-md bg-slate-100 p-2 text-xs" phx-no-curly-interpolation>curl -X POST http://localhost:4000/api/control/profile -d '{"profile":"easy_local"}'</pre>
            </div>

            <div>
              <h3 class="font-medium text-slate-800">Stale shares</h3>
              <p class="mt-1 text-sm text-slate-600">
                → Ensure your miner handles <code class="rounded bg-slate-100 px-1 py-0.5 font-mono text-xs">
                  clean_jobs
                </code> flag correctly
              </p>
            </div>

            <div>
              <h3 class="font-medium text-slate-800">Duplicate shares</h3>
              <p class="mt-1 text-sm text-slate-600">
                → Check that your miner increments nonce correctly and doesn't resubmit the same work
              </p>
            </div>

            <div>
              <h3 class="font-medium text-slate-800">Wrong hash / endianness issues</h3>
              <p class="mt-1 text-sm text-slate-600">
                → See <code class="rounded bg-slate-100 px-1 py-0.5 font-mono text-xs">DEBUG_COOKBOOK.md</code>
                for detailed endianness guide
              </p>
            </div>
          </div>
        </div>

        <%!-- API Reference --%>
        <div class="rounded-lg bg-white p-6 shadow">
          <h2 class="mb-4 text-xl font-semibold text-slate-900">API Reference</h2>

          <div class="space-y-3">
            <div>
              <code class="text-sm font-medium text-slate-800">GET /api/state</code>
              <p class="mt-1 text-sm text-slate-600">Get system state and statistics</p>
            </div>

            <div>
              <code class="text-sm font-medium text-slate-800">GET /api/traces?session_id=XXX</code>
              <p class="mt-1 text-sm text-slate-600">Query message traces</p>
            </div>

            <div>
              <code class="text-sm font-medium text-slate-800">POST /api/control/rotate_job</code>
              <p class="mt-1 text-sm text-slate-600">Trigger immediate job broadcast</p>
            </div>

            <div>
              <code class="text-sm font-medium text-slate-800">POST /api/control/advance_tip</code>
              <p class="mt-1 text-sm text-slate-600">Advance simulated blockchain</p>
            </div>

            <div>
              <code class="text-sm font-medium text-slate-800">GET /api/debug/bundle/:session_id</code>
              <p class="mt-1 text-sm text-slate-600">Export debug bundle for session</p>
            </div>
          </div>
        </div>

        <%!-- Navigation --%>
        <div class="mt-8 flex justify-center gap-4">
          <.link
            navigate="/dashboard"
            class="rounded-md bg-blue-600 px-6 py-3 text-white hover:bg-blue-700"
          >
            Go to Dashboard
          </.link>
          <a
            href="https://github.com/VerusCoin/VerusCoin"
            target="_blank"
            class="rounded-md bg-slate-200 px-6 py-3 text-slate-700 hover:bg-slate-300"
          >
            Verus Documentation
          </a>
        </div>
      </div>
    </div>
    """
  end
end
