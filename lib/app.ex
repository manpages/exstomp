defmodule ExStomp.App do
  use Application.Behaviour

  def start(_,_) do
    {:ok, self()}
  end
end
