import Config

# Hard coding the cutoff_date to yesterday. This value will be used in
# dev/prod. Tests will override the value using ProcessTree.
config :environment_variable_example, cutoff_date: ~D[2024-01-01]
