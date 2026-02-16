defmodule StratumHarness.Pow do
  @moduledoc """
  Behavior for PoW hash implementations.
  Allows pluggable hash algorithms (fakepow for testing, real Verus PoW for production).
  """

  @type header :: binary()
  @type hash :: binary()

  @callback hash(header) :: hash

  @doc """
  Hash a block header using the configured PoW implementation.
  """
  @spec hash(header) :: hash
  def hash(header) do
    impl = get_impl()
    impl.hash(header)
  end

  defp get_impl do
    profile = StratumHarness.Config.current_profile()

    if profile.behavior.fakepow do
      StratumHarness.Pow.FakePow
    else
      StratumHarness.Pow.RealPow
    end
  end
end
