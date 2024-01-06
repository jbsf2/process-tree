defmodule AppEnvironmentExample do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()
end
