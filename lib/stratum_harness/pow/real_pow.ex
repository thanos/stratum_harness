defmodule StratumHarness.Pow.RealPow do
  @moduledoc """
  Real Verus PoW implementation.
  This is a placeholder for integration with actual Verus hashing (via NIF/Port).
  
  To integrate real PoW:
  1. Add a Rust/Zig NIF that exposes verus_hash(header) -> hash
  2. Call the NIF from this module
  3. Handle errors gracefully
  """

  @behaviour StratumHarness.Pow

  @impl true
  def hash(_header) do
    # TODO: Integrate with actual Verus PoW NIF
    # For now, raise an error to prevent silent failures
    raise """
    Real Verus PoW not implemented yet.
    Please either:
    1. Use fakepow mode in your profile
    2. Implement a NIF for Verus hashing
    3. Use a Port to call an external hasher
    """
  end
end
