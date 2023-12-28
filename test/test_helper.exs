if ProcessTree.otp_release() < 25 do
  ExUnit.configure(exclude: [otp25_or_later: true])
end

ExUnit.start()
