defmodule StratumHarnessWeb.LandingLive do
  use StratumHarnessWeb, :live_view

  alias StratumHarness.Config

  @impl true
  def mount(params, session, socket) do
    authenticated = session["authenticated"] || false
    show_login = params["show_login"] == "true" || params["error"] == "invalid_credentials"
    login_error = params["error"] == "invalid_credentials"

    socket =
      socket
      |> assign(:page_title, "Stratum Harness - Testing Pool for Verus Miners")
      |> assign(:authenticated, authenticated)
      |> assign(:show_login, show_login)
      |> assign(:login_error, login_error)
      |> assign(:stratum_port, Config.stratum_port())
      |> assign(:profile, Config.current_profile())
      |> assign(:redirect_to, params["redirect_to"])

    {:ok, socket}
  end

  @impl true
  def handle_event("show_login", _params, socket) do
    {:noreply, assign(socket, :show_login, true)}
  end

  @impl true
  def handle_event("hide_login", _params, socket) do
    {:noreply, assign(socket, show_login: false, login_error: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      <%!-- Header --%>
      <header class="border-b border-slate-200 bg-white/80 backdrop-blur-sm">
        <div class="mx-auto max-w-7xl px-4 py-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-gradient-to-br from-blue-600 to-blue-700 text-white font-bold text-xl shadow-lg">
                SH
              </div>
              <div>
                <h1 class="text-xl font-bold text-slate-900">Stratum Harness</h1>
                <p class="text-xs text-slate-600">Testing Pool for Verus Miners</p>
              </div>
            </div>

            <div class="flex items-center gap-4">
              <%= if @authenticated do %>
                <.link navigate="/dashboard" class="text-sm font-medium text-slate-700 hover:text-blue-600">
                  Dashboard
                </.link>
                <.link navigate="/instructions" class="text-sm font-medium text-slate-700 hover:text-blue-600">
                  Instructions
                </.link>
                <a href="/auth/logout" class="rounded-lg bg-slate-200 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-300">
                  Logout
                </a>
              <% else %>
                <button
                  phx-click="show_login"
                  class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 shadow-sm"
                >
                  Login
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <%!-- Login Modal --%>
      <%= if @show_login and not @authenticated do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" phx-click="hide_login">
          <div class="mx-4 w-full max-w-md rounded-xl bg-white p-8 shadow-2xl" phx-click="stop_propagation">
            <div class="mb-6 flex items-center justify-between">
              <h2 class="text-2xl font-bold text-slate-900">Login</h2>
              <button phx-click="hide_login" class="text-slate-400 hover:text-slate-600">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <%= if @login_error do %>
              <div class="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-800">
                Invalid username or password. Please try again.
              </div>
            <% end %>

            <form action="/auth/login" method="post">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <%= if @redirect_to do %>
                <input type="hidden" name="redirect_to" value={@redirect_to} />
              <% end %>

              <div class="mb-4">
                <label class="mb-2 block text-sm font-medium text-slate-700">Username</label>
                <input
                  type="text"
                  name="username"
                  required
                  class="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
                  placeholder="admin"
                />
              </div>

              <div class="mb-6">
                <label class="mb-2 block text-sm font-medium text-slate-700">Password</label>
                <input
                  type="password"
                  name="password"
                  required
                  class="w-full rounded-lg border border-slate-300 px-4 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
                  placeholder="Enter password"
                />
              </div>

              <button
                type="submit"
                class="w-full rounded-lg bg-blue-600 px-4 py-3 font-medium text-white hover:bg-blue-700 shadow-sm"
              >
                Login
              </button>
            </form>

            <p class="mt-4 text-center text-xs text-slate-500">
              Default: admin / admin (configure via env vars)
            </p>
          </div>
        </div>
      <% end %>

      <%!-- Hero Section --%>
      <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        <div class="text-center">
          <h2 class="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl md:text-6xl">
            Test Your <span class="text-blue-600">Verus Miner</span>
            <br />
            Locally and Safely
          </h2>
          <p class="mx-auto mt-6 max-w-2xl text-lg text-slate-600">
            A complete Stratum V1 pool simulator for debugging and testing your Verus mining implementation without connecting to real pools or running verusd.
          </p>
          <div class="mt-10 flex justify-center gap-4">
            <.link
              navigate="/instructions"
              class="rounded-lg bg-blue-600 px-8 py-3 text-lg font-medium text-white hover:bg-blue-700 shadow-lg"
            >
              Get Started
            </.link>
            <%= if not @authenticated do %>
              <button
                phx-click="show_login"
                class="rounded-lg border-2 border-slate-300 px-8 py-3 text-lg font-medium text-slate-700 hover:border-slate-400 hover:bg-slate-50"
              >
                Login to Dashboard
              </button>
            <% else %>
              <.link
                navigate="/dashboard"
                class="rounded-lg border-2 border-slate-300 px-8 py-3 text-lg font-medium text-slate-700 hover:border-slate-400 hover:bg-slate-50"
              >
                Go to Dashboard
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Features Grid --%>
        <div class="mt-20 grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-blue-100 text-blue-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">Real-Time Monitoring</h3>
            <p class="text-slate-600">
              Watch connections, shares, and protocol messages in real-time with our LiveView dashboard.
            </p>
          </div>

          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-green-100 text-green-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">Full Share Validation</h3>
            <p class="text-slate-600">
              Complete validation with detailed diagnostics for stale, duplicate, and low-difficulty shares.
            </p>
          </div>

          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-purple-100 text-purple-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">Configurable Profiles</h3>
            <p class="text-slate-600">
              Switch between easy, realistic, and chaos modes to test different pool behaviors.
            </p>
          </div>

          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-orange-100 text-orange-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">Message Tracing</h3>
            <p class="text-slate-600">
              Capture and inspect every protocol message with filters and detailed diagnostics.
            </p>
          </div>

          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-red-100 text-red-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">HTTP API</h3>
            <p class="text-slate-600">
              Automate testing with JSON endpoints for state, controls, and debug bundles.
            </p>
          </div>

          <div class="rounded-xl bg-white p-6 shadow-lg">
            <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-indigo-100 text-indigo-600">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h3 class="mb-2 text-xl font-bold text-slate-900">Rich Documentation</h3>
            <p class="text-slate-600">
              Comprehensive guides, debug cookbook, and architecture documentation included.
            </p>
          </div>
        </div>

        <%!-- Quick Connect Section --%>
        <div class="mt-20 rounded-2xl bg-white p-8 shadow-xl">
          <h3 class="mb-6 text-center text-2xl font-bold text-slate-900">Quick Connect</h3>
          <div class="grid gap-6 md:grid-cols-2">
            <div>
              <label class="mb-2 block text-sm font-medium text-slate-700">Stratum URL</label>
              <div class="flex items-center gap-2">
                <code class="flex-1 rounded-lg bg-slate-100 px-4 py-3 font-mono text-sm">
                  stratum+tcp://localhost:{@stratum_port}
                </code>
                <button
                  onclick={"navigator.clipboard.writeText('stratum+tcp://localhost:#{@stratum_port}')"}
                  class="rounded-lg bg-blue-100 px-3 py-3 text-blue-600 hover:bg-blue-200"
                  title="Copy to clipboard"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </button>
              </div>
            </div>

            <div>
              <label class="mb-2 block text-sm font-medium text-slate-700">Credentials</label>
              <div class="rounded-lg bg-slate-100 px-4 py-3 text-sm">
                Username: <code class="font-mono font-semibold">any</code> | Password: <code class="font-mono font-semibold">any</code>
              </div>
            </div>
          </div>

          <div class="mt-6">
            <label class="mb-2 block text-sm font-medium text-slate-700">Example Command</label>
            <pre class="overflow-x-auto rounded-lg bg-slate-900 p-4 text-sm text-slate-100">./your-miner --url stratum+tcp://localhost:{@stratum_port} --user testuser --pass x</pre>
          </div>

          <div class="mt-6 flex justify-center">
            <.link
              navigate="/instructions"
              class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-700 font-medium"
            >
              View detailed instructions
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </.link>
          </div>
        </div>

        <%!-- Current Profile --%>
        <div class="mt-12 rounded-xl bg-blue-50 p-6">
          <div class="flex items-center justify-between">
            <div>
              <h4 class="font-medium text-blue-900">Active Profile: {@profile.name}</h4>
              <p class="mt-1 text-sm text-blue-700">{@profile.description}</p>
            </div>
            <div class="text-right">
              <div class="text-sm text-blue-700">Difficulty: <span class="font-bold">{@profile.stratum.initial_difficulty}</span></div>
              <div class="text-sm text-blue-700">Job Interval: <span class="font-bold">{div(@profile.behavior.job_interval_ms, 1000)}s</span></div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Footer --%>
      <footer class="border-t border-slate-200 bg-white py-8">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex flex-col items-center justify-between gap-4 md:flex-row">
            <p class="text-sm text-slate-600">
              Stratum Harness - Developer Tool for Verus Miners
            </p>
            <div class="flex gap-4">
              <a href="https://github.com/VerusCoin/VerusCoin" target="_blank" class="text-sm text-slate-600 hover:text-blue-600">
                Verus Documentation
              </a>
              <.link navigate="/instructions" class="text-sm text-slate-600 hover:text-blue-600">
                Instructions
              </.link>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end
