defmodule StratumHarness.Stratum.ProtocolTest do
  use ExUnit.Case, async: true

  alias StratumHarness.Stratum.Protocol

  describe "decode/1" do
    test "decodes valid JSON-RPC message" do
      json = ~s({"id": 1, "method": "mining.subscribe", "params": []})
      assert {:ok, message} = Protocol.decode(json)
      assert message["id"] == 1
      assert message["method"] == "mining.subscribe"
      assert message["params"] == []
    end

    test "returns error for invalid JSON" do
      assert {:error, _reason} = Protocol.decode("not json")
    end

    test "returns error for non-object JSON" do
      assert {:error, _reason} = Protocol.decode("[1, 2, 3]")
    end
  end

  describe "encode/1" do
    test "encodes message to JSON string" do
      message = %{"id" => 1, "result" => true, "error" => nil}
      json = Protocol.encode(message)
      assert is_binary(json)
      assert Jason.decode!(json) == %{"id" => 1, "result" => true, "error" => nil}
    end
  end

  describe "validate_method/2" do
    test "validates mining.subscribe" do
      assert :ok = Protocol.validate_method("mining.subscribe", [])
    end

    test "validates mining.authorize" do
      assert :ok = Protocol.validate_method("mining.authorize", ["user", "pass"])
    end

    test "validates mining.submit" do
      assert :ok =
               Protocol.validate_method("mining.submit", [
                 "worker",
                 "jobid",
                 "extranonce2",
                 "ntime",
                 "nonce"
               ])
    end

    test "rejects unknown method" do
      assert {:error, _} = Protocol.validate_method("unknown.method", [])
    end
  end
end
