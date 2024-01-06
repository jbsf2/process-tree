defmodule ProcessTree.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_page "https://github.com/jbsf2/processtree"

  def project do
    [
      app: :process_tree,
      version: @version,
      elixir: "~> 1.14",
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: ["lib", "test/support"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "ProcessTree",
      description: "A module for avoiding global variables & gloabal references in Elixir applications",
      homepage_url: @github_page,
      source_url: @github_page,
      docs: docs(),
      package: package()
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
      {:dialyxir, "~> 1.4", runtime: false},
      {:ex_doc, "~> 0.30.3", only: :dev, runtime: false}
    ]
  end

  defp docs() do
    [
      api_reference: false,
      authors: ["JB Steadman"],
      canonical: "http://hexdocs.pm/processtree",
      extras: [
        "README.md",
        "examples/app_environment_example/README.md"
      ],
      groups_for_extras: [
        "Examples": ["examples/app_environment_example/README.md"]
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
