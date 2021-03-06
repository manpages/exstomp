defmodule ExStomp do
  use GenServer.Behaviour

  defrecordp :opts, host: "127.0.0.1", 
                    port: 61613, 
                    user: "admin", 
                    pass: "password",
                    from: nil,
                    exec: nil

  defrecordp :state, sock: nil, 
                     next: :command, 
                     frame: nil,
                     exec: nil,
                     broadcast: [] 

  defrecordp :frame, command: nil,
                     headers: [],
                     body:    ""

  @emptybody ["\n\n", <<0>>]
  @eop       [<<0>>]

  @spec start(Keyword.t) :: pid
  def start(kwopts) do
    opts = opts( host: kwopts[:host] || opts(opts(), :host),
                 port: kwopts[:port] || opts(opts(), :port),
                 user: kwopts[:user] || opts(opts(), :user),
                 pass: kwopts[:pass] || opts(opts(), :pass),
                 exec: kwopts[:exec] || opts(opts(), :exec),
                 from: kwopts[:from] || opts(opts(), :from) )
    :gen_server.start_link({:local, __MODULE__}, __MODULE__, [opts], [])
  end

  def subscribe(pid) do
    :gen_server.cast(__MODULE__, {:subscribe, pid})
  end

  def set_exec(fun) do
    :gen_server.cast(__MODULE__, {:set_exec, fun})
  end

  def run(command, header_proplist, body) do
    run([ command, "\n", 
          (lc {k,v} inlist header_proplist, do: [k, ":", v, "\n"]), "\n", 
          body, "\n" ])
  end
  def run(frame) do
    :gen_server.cast(__MODULE__, {:run, frame}) 
  end

  @spec init([{:opts, binary, non_neg_integer, binary, binary, pid | nil}]) :: 
        {:ok, {:state, port | nil, atom, list, [pid]}}
  def init([opts]) do
    broadcast = (opts(opts, :from)) && [(opts(opts, :from))] || []
    exec = opts(opts, :exec)
    sock = Socket.TCP.connect!(opts(opts, :host), opts(opts, :port), packet: :line, mode: :active)

    pack = [ "CONNECT", "\nlogin: ",     opts(opts, :user),
                        "\npasscode: ",  opts(opts, :pass),
                        "\nclient-id: ", "exstomp-#{:base64.encode(:crypto.rand_bytes(32))}",
             @emptybody ]

    sock.send! pack

    {:ok, state(sock: sock, frame: frame(), broadcast: broadcast, exec: exec)}
  end

  ## handles

  def handle_call(:subscribe, from, state) do
    broadcast = state(state, :broadcast)
    {:reply, {:ok, from}, state(state, broadcast: [from|broadcast])}
  end
  def handle_cast({:subscribe, pid}, state) do
    broadcast = state(state, :broadcast)
    {:noreply, state(state, broadcast: [pid|broadcast])}
  end

  def handle_cast({:run, frame}, state) do
    state(state, :sock).send! [frame, @eop]
    {:noreply, state}
  end

  def handle_cast({:set_exec, fun}, state) do
    {:noreply, state(state, exec: fun)}
  end

  def handle_info({:tcp_closed, _}, state) do
    state(state, :sock).close
    {:stop, :normal, state}
  end

  ####################### ABNF for STOMP ##############################
  #
  # LF                  = <US-ASCII new line (line feed) (octet 10)>
  # OCTET               = <any 8-bit sequence of data>
  # NULL                = <octet 0>
  # 
  # frame-stream        = 1*frame
  # 
  # frame               = command LF
  #                       *( header LF )
  #                       LF
  #                       *OCTET
  #                       NULL
  #                       *( LF )
  # 
  # command             = client-command | server-command
  # 
  # client-command      = "SEND"
  #                       | "SUBSCRIBE"
  #                       | "UNSUBSCRIBE"
  #                       | "BEGIN"
  #                       | "COMMIT"
  #                       | "ABORT"
  #                       | "ACK"
  #                       | "NACK"
  #                       | "DISCONNECT"
  #                       | "CONNECT"
  #                       | "STOMP"
  # 
  # server-command      = "CONNECTED"
  #                       | "MESSAGE"
  #                       | "RECEIPT"
  #                       | "ERROR"
  # 
  # header              = header-name ":" header-value
  # header-name         = 1*<any OCTET except LF or ":">
  # header-value        = *<any OCTET except LF or ":">
  #
  #####################################################################

  def handle_info(response, state) do
    frame = state(state, :frame)
    headers = frame(frame, :headers)
    body = frame(frame, :body)
    {_,_,data} = response

    case data do
      {:error, error} -> 
        {:stop, {:error, error}, state}
      <<0,10>> ->
        frame = frame(frame, headers: Enum.reverse(headers))
        broadcast(state)
        {:noreply, state(state, next: :command, frame: frame())}
      "\n" ->
        frame = if state(state, :next) == :body do 
          frame(frame, body: <<body :: binary, "\n">>) 
        else 
          frame
        end
        {:noreply, state(state, next: :body, frame: frame)}
      _ ->
        data1 = String.strip(data)
        case state(state, :next) do
          :command ->
            {:noreply, state(state, next: :header, 
                                    frame: frame(frame, command: data1) )}
          :header ->
            {:noreply, state(state, next: :header, 
                                    frame: frame(frame, headers: [header_to_property(data1)|headers]) )}
          :body   ->
            {:noreply, state(state, next: :body, 
                                    frame: frame(frame, body: <<body :: binary, data :: binary>>) )}
        end
    end
  end

  defp header_to_property(header) do
    [key, value] = String.split(header, ":", global: false)
    [key, value]
  end

  defp broadcast(state) do
    Enum.each(state(state, :broadcast), fn(x) -> x <- {__MODULE__, state(state, :frame)} end)
    if state(state, :exec), do: state(state, :exec).(state(state, :frame))
  end
end
