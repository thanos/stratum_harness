defmodule StratumHarness.JobEngine do
  @moduledoc """
  Pure module for building mining jobs, computing coinbase transactions,
  merkle roots, block headers, and validating shares.
  
  This is the core of the harness - all share validation logic lives here.
  """

  alias StratumHarness.ChainSim
  alias StratumHarness.Config
  alias StratumHarness.Pow

  @type job_id :: String.t()
  @type extranonce1 :: binary()
  @type extranonce2 :: binary()
  @type nonce :: binary()

  @type job :: %{
          job_id: job_id(),
          prevhash: String.t(),
          coinbase1: String.t(),
          coinbase2: String.t(),
          merkle_branches: [String.t()],
          version: String.t(),
          nbits: String.t(),
          ntime: String.t(),
          clean_jobs: boolean(),
          created_at: integer(),
          share_target: binary(),
          network_target: binary()
        }

  @type share_result ::
          {:ok, :accepted, map()}
          | {:ok, :block_candidate, map()}
          | {:error, :stale, map()}
          | {:error, :low_difficulty, map()}
          | {:error, :duplicate, map()}
          | {:error, :malformed, String.t()}

  @doc """
  Build a new job from the current chain state and profile.
  """
  @spec build_job(keyword()) :: job()
  def build_job(opts \\ []) do
    chain_state = ChainSim.get_state()
    profile = Config.current_profile()

    job_id = generate_job_id()
    difficulty = Keyword.get(opts, :difficulty, profile.stratum.initial_difficulty)
    clean_jobs = Keyword.get(opts, :clean_jobs, profile.behavior.clean_jobs)

    share_target = Config.difficulty_to_target(difficulty)

    # Build coinbase transaction parts
    {coinbase1, coinbase2} = build_coinbase_parts(chain_state, profile)

    %{
      job_id: job_id,
      prevhash: reverse_bytes_hex(chain_state.prevhash),
      coinbase1: coinbase1,
      coinbase2: coinbase2,
      merkle_branches: [],
      version: int_to_hex_le(chain_state.version, 4),
      nbits: chain_state.nbits,
      ntime: int_to_hex_le(chain_state.ntime, 4),
      clean_jobs: clean_jobs,
      created_at: System.system_time(:millisecond),
      share_target: share_target,
      network_target: chain_state.target
    }
  end

  @doc """
  Validate a submitted share.
  Returns {:ok, :accepted | :block_candidate, details} or {:error, reason, details}.
  """
  @spec validate_share(job(), extranonce1(), extranonce2(), String.t(), String.t()) ::
          share_result()
  def validate_share(job, extranonce1, extranonce2_hex, ntime_hex, nonce_hex) do
    with {:ok, extranonce2} <- decode_hex(extranonce2_hex),
         {:ok, ntime_bytes} <- decode_hex(ntime_hex),
         {:ok, nonce_bytes} <- decode_hex(nonce_hex),
         {:ok, header} <- build_header(job, extranonce1, extranonce2, ntime_bytes, nonce_bytes) do
      validate_header(job, header, extranonce2_hex, ntime_hex, nonce_hex)
    else
      {:error, reason} ->
        {:error, :malformed, reason}
    end
  end

  # Build the full block header from job and submit parameters
  defp build_header(job, extranonce1, extranonce2, ntime_bytes, nonce_bytes) do
    with {:ok, coinbase1} <- decode_hex(job.coinbase1),
         {:ok, coinbase2} <- decode_hex(job.coinbase2) do
      # Build full coinbase: coinbase1 + extranonce1 + extranonce2 + coinbase2
      coinbase_tx = coinbase1 <> extranonce1 <> extranonce2 <> coinbase2

      # Compute coinbase txid (double SHA256)
      coinbase_txid =
        coinbase_tx
        |> hash_sha256()
        |> hash_sha256()

      # Compute merkle root (just coinbase for now, no other transactions)
      merkle_root = compute_merkle_root(coinbase_txid, [])

      # Build header
      with {:ok, version} <- decode_hex(job.version),
           {:ok, prevhash} <- decode_hex(job.prevhash),
           {:ok, nbits} <- decode_hex(job.nbits) do
        header =
          version <>
            prevhash <>
            merkle_root <>
            ntime_bytes <>
            nbits <>
            nonce_bytes

        {:ok, header}
      else
        error -> error
      end
    else
      error -> error
    end
  end

  defp validate_header(job, header, extranonce2_hex, ntime_hex, nonce_hex) do
    # Hash the header
    hash = Pow.hash(header)

    # Reverse for difficulty comparison (little-endian hash)
    hash_reversed = reverse_bytes(hash)
    hash_hex = Base.encode16(hash_reversed, case: :lower)

    # Check against share target
    share_meets_target = compare_hash_target(hash_reversed, job.share_target)
    block_meets_target = compare_hash_target(hash_reversed, job.network_target)

    details = %{
      hash: hash_hex,
      header: Base.encode16(header, case: :lower),
      coinbase_info: build_coinbase_debug_info(job, extranonce2_hex),
      share_target: Base.encode16(job.share_target, case: :lower),
      network_target: Base.encode16(job.network_target, case: :lower),
      extranonce2: extranonce2_hex,
      ntime: ntime_hex,
      nonce: nonce_hex,
      job_id: job.job_id
    }

    cond do
      not share_meets_target ->
        {:error, :low_difficulty, details}

      block_meets_target ->
        {:ok, :block_candidate, details}

      true ->
        {:ok, :accepted, details}
    end
  end

  # Compare hash to target (both little-endian)
  defp compare_hash_target(hash, target) do
    hash <= target
  end

  # Build coinbase transaction parts
  # Format: version | inputs | outputs | locktime
  # We place extranonce in the coinbase script
  defp build_coinbase_parts(chain_state, _profile) do
    # Version (4 bytes, little-endian)
    version = <<2::little-32>>

    # Input count
    input_count = <<1>>

    # Input: null txid (coinbase)
    null_txid = :binary.copy(<<0>>, 32)

    # Output index (0xFFFFFFFF for coinbase)
    output_index = <<0xFFFFFFFF::little-32>>

    # Coinbase script: height + arbitrary data + extranonce placeholder
    height_bytes = encode_height(chain_state.height)
    arbitrary = "StratumHarness/v0.1.0/"

    # Script: <height> <arbitrary> <extranonce1+extranonce2 goes here>
    script_before = height_bytes <> arbitrary
    script_after = "/VERUS/"

    script_len_before = byte_size(script_before)

    # We'll insert extranonce between before and after
    # Coinbase1 ends right before extranonce
    # Coinbase2 starts right after extranonce

    # For now, we need to know extranonce sizes
    # We'll construct coinbase1 up to extranonce, and coinbase2 from after extranonce

    # Total script length will be: script_before + extranonce1_size + extranonce2_size + script_after
    profile = Config.current_profile()
    extranonce_total_size = profile.stratum.extranonce1_size + profile.stratum.extranonce2_size
    script_len_total = script_len_before + extranonce_total_size + byte_size(script_after)

    script_len_varint = encode_varint(script_len_total)

    # Sequence
    sequence = <<0xFFFFFFFF::little-32>>

    # Output count (1 output)
    output_count = <<1>>

    # Output value (50 VERUS in satoshis, arbitrary for simulation)
    output_value = <<50_00000000::little-64>>

    # Output script (P2PKH to a dummy address)
    # For simulation, just use a standard P2PKH script
    output_script = build_dummy_output_script()
    output_script_len = encode_varint(byte_size(output_script))

    # Locktime
    locktime = <<0::little-32>>

    # Coinbase1: everything before extranonce
    coinbase1 =
      version <>
        input_count <>
        null_txid <>
        output_index <>
        script_len_varint <>
        script_before

    # Coinbase2: everything after extranonce
    coinbase2 =
      script_after <>
        sequence <>
        output_count <>
        output_value <>
        output_script_len <>
        output_script <>
        locktime

    {Base.encode16(coinbase1, case: :lower), Base.encode16(coinbase2, case: :lower)}
  end

  defp encode_height(height) do
    # CScript::EncodeOP_N for height
    # For simplicity, just push height as varint
    <<height::little-24>>
  end

  defp encode_varint(n) when n < 0xFD, do: <<n>>
  defp encode_varint(n) when n <= 0xFFFF, do: <<0xFD, n::little-16>>
  defp encode_varint(n) when n <= 0xFFFFFFFF, do: <<0xFE, n::little-32>>
  defp encode_varint(n), do: <<0xFF, n::little-64>>

  defp build_dummy_output_script do
    # OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
    dummy_pubkey_hash = :binary.copy(<<0>>, 20)
    <<0x76, 0xA9, 0x14>> <> dummy_pubkey_hash <> <<0x88, 0xAC>>
  end

  defp compute_merkle_root(coinbase_txid, _other_txids) do
    # For now, only coinbase, so merkle root = coinbase txid
    coinbase_txid
  end

  defp hash_sha256(data) do
    :crypto.hash(:sha256, data)
  end

  defp generate_job_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp int_to_hex_le(int, bytes) do
    <<int::little-size(bytes)-unit(8)>> |> Base.encode16(case: :lower)
  end

  defp decode_hex(hex_string) do
    case Base.decode16(hex_string, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, "invalid hex: #{hex_string}"}
    end
  end

  defp reverse_bytes(binary) do
    binary |> :binary.bin_to_list() |> Enum.reverse() |> :binary.list_to_bin()
  end

  defp reverse_bytes_hex(hex_string) do
    hex_string
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.reverse()
    |> List.flatten()
    |> List.to_string()
  end

  defp build_coinbase_debug_info(job, extranonce2) do
    %{
      coinbase1: job.coinbase1,
      coinbase2: job.coinbase2,
      extranonce2: extranonce2,
      hint: "Verify extranonce placement and byte order"
    }
  end
end
