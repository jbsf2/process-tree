
test "before cutoff date" do
  now = DateTime.now()
  Process.put(:cutoff_date, DateTime.add(now, -1))


end
