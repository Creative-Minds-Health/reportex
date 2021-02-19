# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config
config :xlsx,
  mongodb: File.read!("./config/secrets/mongodb.js"),
  srs_gcs: File.read!("./config/secrets/srs_gcs.json"),
  report: [
    progress_timeout: 2_000,
    #maximum number of reports to attend in parallel per node
    size: 5
  ],
  #node type :master | :slave
  node: :slave,
  master: :"enrique@"

config  :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
