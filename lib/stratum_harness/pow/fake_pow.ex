defmodule StratumHarness.Pow.FakePow do
  @moduledoc """
  Fake PoW implementation for testing.
  Uses double SHA256 for deterministic, fast hashing.
  """

  @behaviour StratumHarness.Pow

  @impl true
  def hash(header) when is_binary(header) do
    # Double SHA256 (Bitcoin-style, but not Verus PoW)
    :crypto.hash(:sha256, header)
    |> then(&:crypto.hash(:sha256, &1))
  end
end
