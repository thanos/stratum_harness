defmodule StratumHarness.Config do
  @moduledoc """
  Configuration and profile management for the Stratum harness.
  Loads profiles, merges with runtime config, and provides access to settings.
  """

  @type profile_name :: String.t()
  @type profile :: %{
          name: String.t(),
          description: String.t(),
          chain: chain_config(),
          stratum: stratum_config(),
          behavior: behavior_config()
        }

  @type chain_config :: %{
          height: non_neg_integer(),
          prevhash_seed: String.t(),
          nbits: String.t(),
          version: non_neg_integer(),
          ntime_base: non_neg_integer(),
          target: binary()
        }

  @type stratum_config :: %{
          port: :inet.port_number(),
          extranonce1_size: pos_integer(),
          extranonce2_size: pos_integer(),
          initial_difficulty: float()
        }

  @type behavior_config :: %{
          job_interval_ms: pos_integer(),
          clean_jobs: boolean(),
          vardiff_enabled: boolean(),
          vardiff_target_shares_per_min: pos_integer(),
          vardiff_window_ms: pos_integer(),
          stale_job_window: pos_integer(),
          auth_mode: :open | :strict,
          auth_token: String.t() | nil,
          deterministic: boolean(),
          fakepow: boolean()
        }

  @profiles %{
    "easy_local" => %{
      name: "easy_local",
      description: "Ultra-low difficulty for local testing with frequent block candidates",
      chain: %{
        height: 1_000_000,
        prevhash_seed: "0000000000000000000000000000000000000000000000000000000000000001",
        nbits: "1f00ffff",
        version: 5,
        ntime_base: 1_700_000_000,
        target: nil
      },
      stratum: %{
        port: 9999,
        extranonce1_size: 4,
        extranonce2_size: 4,
        initial_difficulty: 0.0001
      },
      behavior: %{
        job_interval_ms: 5000,
        clean_jobs: false,
        vardiff_enabled: false,
        vardiff_target_shares_per_min: 60,
        vardiff_window_ms: 60_000,
        stale_job_window: 5,
        auth_mode: :open,
        auth_token: nil,
        deterministic: true,
        fakepow: true
      }
    },
    "realistic_pool" => %{
      name: "realistic_pool",
      description: "Simulates realistic pool behavior with vardiff",
      chain: %{
        height: 1_000_000,
        prevhash_seed: "0000000000000000000000000000000000000000000000000000000000000001",
        nbits: "1d00ffff",
        version: 5,
        ntime_base: 1_700_000_000,
        target: nil
      },
      stratum: %{
        port: 9999,
        extranonce1_size: 4,
        extranonce2_size: 4,
        initial_difficulty: 1.0
      },
      behavior: %{
        job_interval_ms: 30_000,
        clean_jobs: true,
        vardiff_enabled: true,
        vardiff_target_shares_per_min: 60,
        vardiff_window_ms: 60_000,
        stale_job_window: 10,
        auth_mode: :open,
        auth_token: nil,
        deterministic: false,
        fakepow: false
      }
    },
    "chaos" => %{
      name: "chaos",
      description: "Chaotic environment for stress testing",
      chain: %{
        height: 1_000_000,
        prevhash_seed: "0000000000000000000000000000000000000000000000000000000000000001",
        nbits: "1d00ffff",
        version: 5,
        ntime_base: 1_700_000_000,
        target: nil
      },
      stratum: %{
        port: 9999,
        extranonce1_size: 4,
        extranonce2_size: 4,
        initial_difficulty: 1.0
      },
      behavior: %{
        job_interval_ms: 2000,
        clean_jobs: true,
        vardiff_enabled: true,
        vardiff_target_shares_per_min: 120,
        vardiff_window_ms: 30_000,
        stale_job_window: 3,
        auth_mode: :open,
        auth_token: nil,
        deterministic: false,
        fakepow: false
      }
    }
  }

  @doc """
  Get a profile by name. Returns the default profile if not found.
  """
  @spec get_profile(profile_name()) :: profile()
  def get_profile(name) when is_binary(name) do
    profile = Map.get(@profiles, name, @profiles["easy_local"])
    compute_target(profile)
  end

  @doc """
  Get the current active profile name from application config.
  """
  @spec current_profile_name() :: profile_name()
  def current_profile_name do
    Application.get_env(:stratum_harness, :profile, "easy_local")
  end

  @doc """
  Get the current active profile.
  """
  @spec current_profile() :: profile()
  def current_profile do
    get_profile(current_profile_name())
  end

  @doc """
  List all available profile names.
  """
  @spec list_profiles() :: [profile_name()]
  def list_profiles do
    Map.keys(@profiles)
  end

  @doc """
  Switch to a different profile at runtime.
  """
  @spec switch_profile(profile_name()) :: :ok | {:error, :not_found}
  def switch_profile(name) when is_binary(name) do
    if Map.has_key?(@profiles, name) do
      Application.put_env(:stratum_harness, :profile, name)
      :ok
    else
      {:error, :not_found}
    end
  end

  # Compute target from nbits
  defp compute_target(profile) do
    nbits = profile.chain.nbits
    target = nbits_to_target(nbits)
    put_in(profile, [:chain, :target], target)
  end

  @doc """
  Convert nbits (compact format) to 256-bit target.
  """
  @spec nbits_to_target(String.t()) :: binary()
  def nbits_to_target(nbits_hex) when is_binary(nbits_hex) do
    nbits =
      nbits_hex
      |> String.trim_leading("0x")
      |> String.upcase()
      |> String.pad_leading(8, "0")
      |> Base.decode16!()

    <<exponent::8, coefficient::24>> = nbits

    # Target = coefficient * 2^(8 * (exponent - 3))
    shift_bytes = max(exponent - 3, 0)
    target_int = coefficient * :math.pow(2, 8 * shift_bytes) |> trunc()

    # Convert to 32-byte binary (256 bits), big-endian
    <<target_int::256>>
  end

  @doc """
  Convert difficulty to target.
  Difficulty 1.0 corresponds to a specific maximum target.
  """
  @spec difficulty_to_target(float()) :: binary()
  def difficulty_to_target(difficulty) when is_float(difficulty) and difficulty > 0 do
    # Difficulty 1.0 target (Bitcoin's original)
    max_target =
      0x00000000FFFF0000000000000000000000000000000000000000000000000000

    target_int = (max_target / difficulty) |> trunc()
    <<target_int::256>>
  end

  @doc """
  Get Stratum server port from config or profile.
  """
  @spec stratum_port() :: :inet.port_number()
  def stratum_port do
    Application.get_env(:stratum_harness, :stratum_port) || current_profile().stratum.port
  end
end
