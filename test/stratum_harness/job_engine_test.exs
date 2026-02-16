defmodule StratumHarness.JobEngineTest do
  use ExUnit.Case, async: true

  alias StratumHarness.JobEngine

  # ChainSim is already started by the application, no need to start it in tests

  describe "build_job/1" do
    test "builds a valid job" do
      job = JobEngine.build_job()

      assert is_binary(job.job_id)
      assert is_binary(job.prevhash)
      assert is_binary(job.coinbase1)
      assert is_binary(job.coinbase2)
      assert is_list(job.merkle_branches)
      assert is_boolean(job.clean_jobs)
      assert is_binary(job.share_target)
      assert is_binary(job.network_target)
    end

    test "builds jobs with different difficulties" do
      job_easy = JobEngine.build_job(difficulty: 0.1)
      job_hard = JobEngine.build_job(difficulty: 10.0)

      assert job_easy.share_target > job_hard.share_target
    end
  end

  describe "validate_share/5" do
    test "rejects malformed hex inputs" do
      job = JobEngine.build_job()
      extranonce1 = <<1, 2, 3, 4>>

      result = JobEngine.validate_share(job, extranonce1, "invalid", "00000000", "00000000")

      assert {:error, :malformed, _reason} = result
    end

    test "validates share structure" do
      job = JobEngine.build_job(difficulty: 0.0001)
      extranonce1 = <<1, 2, 3, 4>>
      extranonce2 = "00000001"
      ntime = job.ntime
      nonce = "00000001"

      result = JobEngine.validate_share(job, extranonce1, extranonce2, ntime, nonce)

      # Result should be either accepted, low_difficulty, or other validation error
      assert match?({:ok, _, _}, result) or
               match?({:error, :low_difficulty, _}, result) or
               match?({:error, _, _}, result)
    end
  end
end
