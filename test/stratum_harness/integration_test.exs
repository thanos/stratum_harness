defmodule StratumHarness.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias StratumHarness.Config

  setup do
    # Application is already started in test environment
    port = Config.stratum_port()
    {:ok, port: port}
  end

  describe "Stratum protocol flow" do
    test "full mining session", %{port: port} do
      # Connect
      {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, packet: :line, active: false])

      # Subscribe
      subscribe_msg = Jason.encode!(%{id: 1, method: "mining.subscribe", params: []})
      :ok = :gen_tcp.send(socket, subscribe_msg <> "\n")

      {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
      subscribe_result = Jason.decode!(response)

      assert subscribe_result["id"] == 1
      assert is_list(subscribe_result["result"])
      [_subscriptions, extranonce1, extranonce2_size] = subscribe_result["result"]
      assert is_binary(extranonce1)
      assert is_integer(extranonce2_size)

      # Authorize
      auth_msg = Jason.encode!(%{id: 2, method: "mining.authorize", params: ["testuser", "x"]})
      :ok = :gen_tcp.send(socket, auth_msg <> "\n")

      {:ok, auth_response} = :gen_tcp.recv(socket, 0, 5000)
      auth_result = Jason.decode!(auth_response)

      assert auth_result["id"] == 2
      assert auth_result["result"] == true

      # Receive set_difficulty notification
      {:ok, diff_response} = :gen_tcp.recv(socket, 0, 5000)
      diff_notification = Jason.decode!(diff_response)

      assert diff_notification["method"] == "mining.set_difficulty"
      assert is_list(diff_notification["params"])

      # Receive job notification
      {:ok, job_response} = :gen_tcp.recv(socket, 0, 5000)
      job_notification = Jason.decode!(job_response)

      assert job_notification["method"] == "mining.notify"
      assert is_list(job_notification["params"])
      assert length(job_notification["params"]) == 9

      [job_id, _prevhash, _coinbase1, _coinbase2, _merkle, _version, _nbits, _ntime, _clean] =
        job_notification["params"]

      # Submit a share (will likely be rejected for low difficulty, but tests the flow)
      submit_msg =
        Jason.encode!(%{
          id: 3,
          method: "mining.submit",
          params: ["testuser.worker1", job_id, "00000001", "00000000", "00000001"]
        })

      :ok = :gen_tcp.send(socket, submit_msg <> "\n")

      {:ok, submit_response} = :gen_tcp.recv(socket, 0, 5000)
      submit_result = Jason.decode!(submit_response)

      assert submit_result["id"] == 3
      # Result can be true or false depending on whether the share meets difficulty
      assert is_boolean(submit_result["result"]) or not is_nil(submit_result["error"])

      # Close connection
      :gen_tcp.close(socket)
    end

    test "rejects unauthorized worker", %{port: port} do
      # Connect
      {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, packet: :line, active: false])

      # Subscribe
      subscribe_msg = Jason.encode!(%{id: 1, method: "mining.subscribe", params: []})
      :ok = :gen_tcp.send(socket, subscribe_msg <> "\n")
      {:ok, _response} = :gen_tcp.recv(socket, 0, 5000)

      # Try to submit without authorizing
      submit_msg =
        Jason.encode!(%{
          id: 2,
          method: "mining.submit",
          params: ["testuser.worker1", "fakejob", "00000001", "00000000", "00000001"]
        })

      :ok = :gen_tcp.send(socket, submit_msg <> "\n")

      {:ok, submit_response} = :gen_tcp.recv(socket, 0, 5000)
      submit_result = Jason.decode!(submit_response)

      assert submit_result["result"] == false
      assert submit_result["error"] != nil

      :gen_tcp.close(socket)
    end
  end
end
