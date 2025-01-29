defmodule ProcessTree.MixProject do
  use Mix.Project

  @version "0.2.1"
  @github_page "https://github.com/jbsf2/process-tree"

  def project do
    [
      app: :process_tree,
      version: @version,
      elixir: "~> 1.10",
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: ["lib", "test/support"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "ProcessTree",
      description: "A module for avoiding global state in Elixir applications",
      homepage_url: @github_page,
      source_url: @github_page,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.30.3", only: :dev, runtime: false}
    ]
  end

  defp docs() do
    [
      api_reference: false,
      authors: ["JB Steadman"],
      canonical: "http://hexdocs.pm/process_tree",
      extras: [
        "examples/environment-variable-example.md"
      ],
      groups_for_extras: [
        Examples: ["examples/environment-variable-example.md"]
      ],
      main: "ProcessTree",
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      files: ~w(mix.exs README.md lib),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_page
      },
      maintainers: ["JB Steadman"]
    ]
  end
end
