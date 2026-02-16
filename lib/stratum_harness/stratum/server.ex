defmodule StratumHarness.Stratum.Server do
  @moduledoc """
  TCP acceptor for Stratum connections.
  Listens on configured port and spawns a Session process for each connection.
  """
  use GenServer
  require Logger

  alias StratumHarness.Config
  alias StratumHarness.Stratum.Session

  @type state :: %{
          port: :inet.port_number(),
          listen_socket: :gen_tcp.socket(),
          acceptor_ref: reference()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    port = Config.stratum_port()

    case :gen_tcp.listen(port, [
           :binary,
           packet: :line,
           active: false,
           reuseaddr: true,
           nodelay: true
         ]) do
      {:ok, listen_socket} ->
        Logger.info("Stratum server listening on port #{port}")
        # Start accepting connections
        send(self(), :accept)

        {:ok,
         %{
           port: port,
           listen_socket: listen_socket,
           acceptor_ref: nil
         }}

      {:error, reason} ->
        Logger.error("Failed to start Stratum server on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, client_socket} ->
        # Get peer info
        {:ok, {remote_ip, remote_port}} = :inet.peername(client_socket)

        # Start a session process under the dynamic supervisor
        {:ok, session_pid} =
          DynamicSupervisor.start_child(
            StratumHarness.SessionSupervisor,
            {Session,
             socket: client_socket,
             remote_ip: remote_ip,
             remote_port: remote_port}
          )

        # Transfer socket control to session
        :ok = :gen_tcp.controlling_process(client_socket, session_pid)

        Logger.info("Accepted connection from #{format_ip(remote_ip)}:#{remote_port}")

        # Continue accepting
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Accept failed: #{inspect(reason)}")
        # Retry after a delay
        Process.send_after(self(), :accept, 1000)
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Stratum server stopping: #{inspect(reason)}")
    :gen_tcp.close(state.listen_socket)
    :ok
  end

  # Private helpers

  defp format_ip({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp format_ip({a, b, c, d, e, f, g, h}) do
    "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"
  end
end
