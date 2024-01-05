import Config

# Hard coding the cutoff date to yesterday. In real-life, we might normally
# read the cutoff date from System.get_env(), for example.
today = Date.utc_today()
config :application_environment, cutoff_date: Date.add(today, -1)
