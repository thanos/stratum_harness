defmodule StratumHarness.ChainSim do
  @moduledoc """
  GenServer that simulates a blockchain tip.
  Maintains current height, prevhash, nbits, ntime, and can advance the chain.
  """
  use GenServer
  require Logger

  alias StratumHarness.Config

  @type state :: %{
          height: non_neg_integer(),
          prevhash: String.t(),
          nbits: String.t(),
          version: non_neg_integer(),
          ntime: non_neg_integer(),
          target: binary(),
          deterministic: boolean(),
          ntime_base: non_neg_integer()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current chain state.
  """
  @spec get_state() :: state()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Advance the chain tip to the next block.
  """
  @spec advance() :: :ok
  def advance do
    GenServer.call(__MODULE__, :advance)
  end

  @doc """
  Reset the chain to a specific state.
  """
  @spec reset(state()) :: :ok
  def reset(new_state) do
    GenServer.call(__MODULE__, {:reset, new_state})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    profile = Config.current_profile()
    chain_config = profile.chain

    state = %{
      height: chain_config.height,
      prevhash: chain_config.prevhash_seed,
      nbits: chain_config.nbits,
      version: chain_config.version,
      ntime: get_ntime(chain_config.ntime_base, profile.behavior.deterministic),
      target: chain_config.target,
      deterministic: profile.behavior.deterministic,
      ntime_base: chain_config.ntime_base
    }

    Logger.info("ChainSim initialized at height #{state.height}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:advance, _from, state) do
    new_state = %{
      state
      | height: state.height + 1,
        prevhash: generate_next_prevhash(state.prevhash),
        ntime: get_ntime(state.ntime_base, state.deterministic)
    }

    Logger.info("ChainSim advanced to height #{new_state.height}")
    Phoenix.PubSub.broadcast(StratumHarness.PubSub, "chain_updates", {:chain_advanced, new_state})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:reset, new_state}, _from, _state) do
    Logger.info("ChainSim reset to height #{new_state.height}")
    Phoenix.PubSub.broadcast(StratumHarness.PubSub, "chain_updates", {:chain_reset, new_state})
    {:reply, :ok, new_state}
  end

  # Private Helpers

  defp get_ntime(base, deterministic) do
    if deterministic do
      base
    else
      System.system_time(:second)
    end
  end

  defp generate_next_prevhash(current_prevhash) do
    # Simple hash generation for simulation
    :crypto.hash(:sha256, current_prevhash)
    |> Base.encode16(case: :lower)
    |> String.slice(0..63)
    |> String.pad_leading(64, "0")
  end
end
