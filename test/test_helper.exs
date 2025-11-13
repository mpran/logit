ExUnit.start()

{:ok, _} =
  Logit.Processors.Influx.start_link(url: "http://localhost:8186/write", flush_interval: 200)
