ExUnit.start()

{:ok, _} = Logit.Processors.Influx.start_link(Application.fetch_env!(:logit, :influxdb))
