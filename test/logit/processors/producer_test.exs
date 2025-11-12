defmodule Logit.Processors.InfluxTest do
  use ExUnit.Case

  alias Logit.Processors.Influx

  setup do
    bypass = Bypass.open(port: 8186)

    [bypass: bypass]
  end

  test "events are sent to influxdb", c do
    Bypass.expect_once(c.bypass, "POST", "/write", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "app_metrics.test.event"
      Plug.Conn.resp(conn, 204, "")
    end)

    :ok = Influx.report("test.event", %{test: "test"})

    :timer.sleep(500)
  end
end
