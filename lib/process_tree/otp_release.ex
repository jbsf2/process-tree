defmodule ProcessTree.OtpRelease do
  @moduledoc false

  def major_version() do
    System.otp_release() |> String.to_integer()
  end

  def process_info_tracks_parent?() do
    major_version() >= 25
  end

  def optimized_dictionary_access?() do
    # optimized dictionary access released in 26.2: https://www.erlang.org/news/166
    cond do
      major_version() < 26 ->
        false

      major_version() > 26 ->
        true

      major_version() == 26 ->
        try do
          # just see if it works
          Process.info(self(), {:dictionary, :foo})
          true
        rescue
          _  -> false
        end
    end
  end
end
