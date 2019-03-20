defmodule FontMetrics.MixProject do
  use Mix.Project

  @app_name :font_metrics

  @version "0.3.1"

  @elixir_version "~> 1.7"
  @github "https://github.com/boydm/font_metrics"

  def project do
    [
      app: @app_name,
      version: @version,
      elixir: @elixir_version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env()
    ]
  end

  defp cli_env do
    [
      coveralls: :test,
      "coveralls.html": :test,
      "coveralls.json": :test
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
      {:msgpax, "~> 2.2"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:excoveralls, ">= 0.0.0", only: :test, runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:inch_ex, "~> 2.0", only: [:dev, :docs], runtime: false}
    ]
  end

  defp package do
    [
      name: @app_name,
      contributors: ["Boyd Multerer"],
      maintainers: ["Boyd Multerer"],
      licenses: ["Apache 2"],
      links: %{Github: @github}
    ]
  end

  defp description do
    """
    FontMetrics -- Work with font meta-data and text measurements
    """
  end

  defp docs do
    [
      main: "FontMetrics",
      source_ref: "v#{@version}",
      source_url: "https://github.com/boydm/font_metrics"
    ]
  end
end
