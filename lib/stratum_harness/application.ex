defmodule StratumHarness.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS tables
    StratumHarness.Trace.init()
    StratumHarness.Stats.init()

    children = [
      StratumHarnessWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:stratum_harness, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StratumHarness.PubSub},
      # Stratum infrastructure
      StratumHarness.ChainSim,
      StratumHarness.JobBroadcaster,
      {DynamicSupervisor, name: StratumHarness.SessionSupervisor, strategy: :one_for_one},
      StratumHarness.Stratum.Server,
      # Phoenix endpoint
      StratumHarnessWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StratumHarness.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StratumHarnessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
