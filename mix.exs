defmodule MyPackage.MixProject do
  use Mix.Project

  @app :babel
  @name "Babel"
  @description "A cool description"
  @repo "https://github.com/sascha-wolf/#{@app}"

  def project do
    [
      app: @app,
      elixir: ">= 1.7.4 and < 2.0.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Deps
      dialyzer: dialyzer(),

      # Docs
      name: @name,
      source_url: @repo,
      homepage_url: @repo,

      # Hex
      description: @description,
      docs: docs(),
      package: package(),
      version: version()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "check.all": ["format --check-formatted", "credo", "dialyzer"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.4", optional: true},

      # No Runtime
      {:credo, ">= 1.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 1.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},

      # Test
      {:excoveralls, "~> 0.16", only: :test},
      {:mox, "~> 1.0", only: :test},

      # Docs
      {:inch_ex, ">= 0.0.0", only: :docs}
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [],
      plt_file: {:no_warn, ".dialyzer/dialyzer.plt"}
    ]
  end

  #######
  # Hex #
  #######

  @extras Path.wildcard("pages/**/*.md")
  def docs do
    [
      main: @name,
      source_ref: "v#{version()}",
      source_url: @repo,
      extras: @extras,
      groups_for_modules: []
    ]
  end

  def package do
    [
      files: ["lib", "mix.exs", "CHANGELOG*", "LICENSE*", "README*", "version"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo},
      maintainers: ["Sascha Wolf <swolf.dev@gmail.com>"]
    ]
  end

  @version_file "version"
  def version do
    cond do
      File.exists?(@version_file) ->
        @version_file
        |> File.read!()
        |> String.trim()

      System.get_env("REQUIRE_VERSION_FILE") == "true" ->
        exit("Version file (`#{@version_file}`) doesn't exist but is required!")

      true ->
        "0.0.0-dev"
    end
  end
end
