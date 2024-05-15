# coveralls-ignore-start
defmodule Babel.EnforceVersion do
  @moduledoc false

  defmacro __using__(version_requirements) do
    otp_version_requirement = Keyword.fetch!(version_requirements, :otp)
    elixir_version_requirement = Keyword.fetch!(version_requirements, :elixir)

    otp_major_version = System.otp_release()
    # Good enough for our use
    otp_version = Version.parse!("#{otp_major_version}.0.0")
    elixir_version = Version.parse!(System.version())

    unless Version.match?(otp_version, otp_version_requirement) do
      incompatible!(__CALLER__, "OTP", otp_major_version, otp_version_requirement)
    end

    unless Version.match?(elixir_version, elixir_version_requirement) do
      incompatible!(__CALLER__, "Elixir", System.version(), elixir_version_requirement)
    end

    :ok
  end

  defp incompatible!(env, software, actual_version, requirement) do
    raise CompileError,
      file: env.file,
      line: env.line,
      description:
        "Cannot compile #{inspect(env.module)} as it requires a #{software} version matching '#{requirement}' but the current version is '#{actual_version}'"
  end
end
