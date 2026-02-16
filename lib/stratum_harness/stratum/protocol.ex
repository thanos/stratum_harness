defmodule StratumHarness.Stratum.Protocol do
  @moduledoc """
  JSON-RPC protocol encoding/decoding for Stratum V1.
  Handles message parsing and validation.
  """

  @doc """
  Decode a JSON line into a message map.
  """
  @spec decode(String.t()) :: {:ok, map()} | {:error, String.t()}
  def decode(line) when is_binary(line) do
    case Jason.decode(line) do
      {:ok, message} when is_map(message) ->
        {:ok, message}

      {:ok, _} ->
        {:error, "invalid message format: not a JSON object"}

      {:error, error} ->
        {:error, "JSON parse error: #{inspect(error)}"}
    end
  end

  @doc """
  Encode a message map to JSON.
  """
  @spec encode(map()) :: String.t()
  def encode(message) when is_map(message) do
    Jason.encode!(message)
  end

  @doc """
  Validate a Stratum method call.
  """
  @spec validate_method(String.t(), list()) :: :ok | {:error, String.t()}
  def validate_method("mining.subscribe", params) when is_list(params) do
    :ok
  end

  def validate_method("mining.authorize", params) when is_list(params) and length(params) >= 2 do
    :ok
  end

  def validate_method("mining.submit", params) when is_list(params) and length(params) >= 5 do
    :ok
  end

  def validate_method("mining.extranonce.subscribe", _params) do
    :ok
  end

  def validate_method(method, _params) do
    {:error, "unknown method: #{method}"}
  end
end
