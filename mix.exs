defmodule Thumbhash.MixProject do
  use Mix.Project

  @version "0.1.0-alpha.0"
  @description "ThumbHash implemented purely in Elixir"

  def project do
    [
      app: :thumbhash,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Thumbhash",
      description: @description,
      package: package(),
      source_url: "https://github.com/Hentioe/thumbhash-ex",
      homepage_url: "https://github.com/Hentioe/thumbhash-ex",
      docs: [
        # The main page in the docs
        main: "Thumbhash",
        extras: ["README.md"]
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Hentioe/thumbhash-ex"}
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34.2", only: [:dev], runtime: false},
      {:benchee, "~> 1.3", only: [:dev]},
      {:image, "~> 0.54.3", only: [:dev, :test]}
    ]
  end
end
