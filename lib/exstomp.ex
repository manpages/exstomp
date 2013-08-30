defmodule ExStomp do
  use GenServer.Behaviour

  defrecordp :creds, host: "127.0.0.1", 
                     port: 61613, 
                     user: "admin", 
                     pass: "password"

  defrecordp :state, sock: nil

  @emptybody ["\n\n", <<0>>]
  @eop       [<<0>>]

  @spec start(Keyword.t) :: pid
  def start(kwopts) do
    opts = creds( host: kwopts[:host] || creds(creds(), :host),
                  port: kwopts[:port] || creds(creds(), :port),
                  user: kwopts[:user] || creds(creds(), :user),
                  pass: kwopts[:pass] || creds(creds(), :pass) )
    :gen_server.start_link({:local, __MODULE__}, __MODULE__, [opts], [])
  end

  def exec(query), do: :gen_server.call(__MODULE__, {:exec, query})

  @spec init([{:creds, binary, non_neg_integer, binary, binary}]) :: {:ok, {:state, any}}
  def init([opts]) do
    IO.puts "#{__MODULE__}: init(#{inspect opts})"
    sock = Socket.TCP.connect!(creds(opts, :host), creds(opts, :port), packet: :line, mode: :active)

    pack = [ "CONNECT", "\nlogin: ",     creds(opts, :user),
                        "\npasscode: ",  creds(opts, :pass),
                        "\nclient-id: ", "exstomp-#{:base64.encode(:crypto.rand_bytes(32))}",
             @emptybody ]
    ts(pack)

    sock.send! pack

    {:ok, state(sock: sock)}
  end

  def handle_info({:tcp_closed, _}, state) do
    IO.puts "bye"
    state(state, :sock).close
    {:stop, :normal, state}
  end

  def handle_info(response, state) do
    IO.puts "fyi: #{inspect response}"

    {_,_,data} = response

    framer = 
    case data do
      {:error, error} -> 
        IO.puts ":("
        :notok
      _ ->
        :ok
    end
    
    {:noreply, state}
  end

  defp ts(x), do: IO.puts "#{:io_lib.format('~ts', [x])}"
end
