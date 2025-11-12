defmodule Logit.MixProject do
  use Mix.Project

  def project do
    [
      app: :logit,
      version: "0.1.0",
      elixir: "~> 1.19",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, ">= 0.0.0"},
      {:plug, ">= 0.0.0"},
      {:remote_ip, ">= 0.0.0"},
      {:req, ">= 0.0.0"},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
