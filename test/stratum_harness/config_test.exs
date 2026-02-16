defmodule StratumHarness.ConfigTest do
  use ExUnit.Case, async: true

  alias StratumHarness.Config

  describe "profiles" do
    test "get_profile/1 returns a profile by name" do
      profile = Config.get_profile("easy_local")
      assert profile.name == "easy_local"
      assert profile.chain.height == 1_000_000
      assert is_binary(profile.chain.target)
    end

    test "get_profile/1 returns default for unknown profile" do
      profile = Config.get_profile("nonexistent")
      assert profile.name == "easy_local"
    end

    test "list_profiles/0 returns all profile names" do
      profiles = Config.list_profiles()
      assert "easy_local" in profiles
      assert "realistic_pool" in profiles
      assert "chaos" in profiles
    end
  end

  describe "nbits_to_target/1" do
    test "converts nbits to target correctly" do
      # nbits 0x1f00ffff should give a very high target (low difficulty)
      target = Config.nbits_to_target("1f00ffff")
      assert byte_size(target) == 32
      assert target > <<0::256>>
    end

    test "handles different nbits values" do
      target1 = Config.nbits_to_target("1d00ffff")
      target2 = Config.nbits_to_target("1f00ffff")

      # Higher nbits should give higher target (lower difficulty)
      assert target2 > target1
    end
  end

  describe "difficulty_to_target/1" do
    test "converts difficulty to target" do
      target = Config.difficulty_to_target(1.0)
      assert byte_size(target) == 32
    end

    test "higher difficulty gives lower target" do
      target_easy = Config.difficulty_to_target(0.1)
      target_hard = Config.difficulty_to_target(10.0)

      assert target_easy > target_hard
    end
  end
end
