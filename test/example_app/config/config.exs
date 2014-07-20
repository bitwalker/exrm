use Mix.Config

config :test,
  foo: "nope",
  env: :wat,
  "debug_level": {:on, [:passive]}

import_config "config.#{Mix.env}.exs"
