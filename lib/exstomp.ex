defmodule ExStomp do
  use GenServer.Behaviour

  defrecordp :creds, host: "127.0.0.1", 
                     port: 61613, 
                     user: "admin", 
                     pass: "password"

  defrecordp :state, sock: nil

  @eop ["\n\n", <<0>>]

  @spec start(Keyword.t) :: pid
  def start(kwopts) do
    opts = creds( host: kwopts[:host] || creds(creds(), :host),
                  port: kwopts[:port] || creds(creds(), :port),
                  user: kwopts[:user] || creds(creds(), :user),
                  pass: kwopts[:pass] || creds(creds(), :pass) )
    :gen_server.start_link(__MODULE__, [opts], [])
  end

  def init([opts]) do
    IO.puts "#{__MODULE__}: init(#{inspect opts})"
    sock = Socket.TCP.connect!(creds(opts, :host), creds(opts, :port), packet: :line, mode: :passive)

    pack = [ "CONNECT", "\nlogin: ",     creds(opts, :user),
                        "\npasscode: ",  creds(opts, :pass),
                        "\nclient-id: ", "fuckoff",
             @eop ]
                        
    sock.send! pack
    "CONNECTED\n" = sock.recv!

    {:ok, state(sock: sock)}
  end
end
