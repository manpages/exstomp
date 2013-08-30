defmodule ExStomp.Mixfile do
  use Mix.Project

  def project do
    [ app: :exstomp,
      version: "0.0.1",
      elixir: "~> 0.10.2-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:socket],
      mod: [] ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "~> 0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [ {:socket, github: "meh/elixir-socket" } ]
  end
end
