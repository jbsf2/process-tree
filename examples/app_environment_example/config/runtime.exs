import Config

# Hard coding the cutoff_date to yesterday. This value will be used in
# dev/prod. Tests will override the value using ProcessTree.
today = Date.utc_today()
config :application_environment, cutoff_date: Date.add(today, -1)
