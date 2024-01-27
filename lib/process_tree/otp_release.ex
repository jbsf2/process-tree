defmodule ProcessTree.OtpRelease do
  @moduledoc false

  def major_version() do
    System.otp_release() |> String.to_integer()
  end

  def process_info_tracks_parent?() do
    major_version() >= 25
  end

end
