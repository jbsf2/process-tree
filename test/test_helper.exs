case ProcessTree.OtpRelease.major_version() < 25 do
  true ->
    ExUnit.configure(exclude: [otp25_or_later: true])

  false ->
    ExUnit.configure(exclude: [pre_otp25: true])
end

ExUnit.start()
