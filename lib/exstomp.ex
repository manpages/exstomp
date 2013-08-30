defmodule ExStomp do
  use GenServer.Behaviour

  defrecordp :creds, host: "127.0.0.1", 
                     port: 61613, 
                     user: "admin", 
                     pass: "password"

  defrecordp :state, sock: nil

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
    {:ok, state()}
  end
end
