defmodule Logit.Processors.WebHelpers do
  @moduledoc false

  require Logger

  @secure_atom_keys [:token, :password, :secret]
  @secure_string_keys Enum.map(@secure_atom_keys, &Atom.to_string/1)
  @secure_keys @secure_atom_keys ++ @secure_string_keys
  @custom_internal_forwarding_ip_key "x-forwarded-from-ip"

  def phoenix_report(event, conn, measurements, _opts \\ []) do
    {path, params} = _parse_url_path(conn.request_path, conn.path_params)

    values =
      [
        duration: measurements[:duration],
        request_id: conn.assigns[:request_id] || "",
        remote_ip: conn.assigns[:remote_ip],
        params: params |> _drop_secure_keys() |> _encode_params(),
        client_id: conn.assigns[:client_id] || ""
      ]

    tags = [
      event: event,
      method: conn.method,
      request_path: path || "/",
      status: conn.status
    ]

    Logger.debug("""
    #{__MODULE__} building phoenix report
    Tags: #{inspect(tags)}
    Values: #{inspect(values)}˝
    """)

    {tags, values}
  end

  @ws :erlang.system_info(:wordsize)

  def live_view_report(event, meta, measurements, opts \\ []) do
    headers = opts[:headers] || []
    view = meta.socket.view |> to_string()
    assigns_size = :erts_debug.flat_size(meta.socket.assigns) * @ws

    values =
      [
        lv_event: Map.get(meta, :event, ""),
        duration: measurements.duration,
        assigns_size_bytes: assigns_size,
        remote_ip: meta.socket.assigns[:remote_ip],
        params: meta.params |> _drop_secure_keys |> _encode_params(),
        error: _get_error_reason(meta),
        client_id: meta.socket.assigns[:client_id] || ""
      ]

    tags = [
      event: event,
      view: view
    ]

    Logger.debug("""
    #{__MODULE__} building live view report
    Tags: #{inspect(tags)}
    Values: #{inspect(values)}˝
    """)

    {tags, values}
  end

  def forwarding_headers(socket) do
    ip =
      socket
      |> headers_from_socket()
      |> RemoteIp.from(headers: custom_internal_forwarding_ip_keys())
      |> _parse_ip()

    [{@custom_internal_forwarding_ip_key, ip}]
  end

  def custom_internal_forwarding_ip_keys,
    do: [@custom_internal_forwarding_ip_key] ++ RemoteIp.Options.default(:headers)

  def headers_from_socket(%{private: %{connect_info: connect_info}} = _socket) do
    _header_from_connect_info(connect_info)
  end

  def headers_from_socket(socket) do
    case :sys.get_state(socket.transport_pid) do
      {_,
       %{
         connection: %{
           websock_state: {_, %{assigns: _assigns, private: %{connect_info: connect_info}}}
         }
       }} ->
        _header_from_connect_info(connect_info)

      _ ->
        []
    end
  end

  defp _drop_secure_keys(map) when is_map(map) do
    Map.drop(map, @secure_keys)
  end

  defp _parse_ip({_, _, _, _} = ip), do: ip |> :inet.ntoa() |> to_string()
  defp _parse_ip(_), do: ""
  defp _parse_ip({_, _, _, _} = ip, _socket), do: _parse_ip(ip)
  defp _parse_ip(_, socket), do: socket.assigns[:remote_ip] || ""

  defp _parse_url_path(path, params) do
    params_inversed = Map.new(params, fn {k, v} -> {to_string(v), k} end)

    path
    |> String.split("/", trim: true)
    |> Enum.reduce({"", %{}}, fn part, {path_acc, params_acc} ->
      decoded_part = URI.decode(part)

      case Map.get(params_inversed, decoded_part) do
        nil ->
          {path_acc <> "/" <> part, params_acc}

        param_key ->
          param_value = Map.get(params, param_key)
          {path_acc <> "/:" <> to_string(param_key), Map.put(params_acc, param_key, param_value)}
      end
    end)
  end

  defp _encode_params(%{} = params) when map_size(params) >= 1 do
    Plug.Conn.Query.encode(params)
  end

  defp _encode_params(_), do: ""

  defp _header_from_connect_info(connect_info) do
    Map.get(connect_info, :x_headers, []) ++ Map.get(connect_info, :trace_context_headers, [])
  end

  defp _get_error_reason(%{reason: reason}), do: inspect(reason)
  defp _get_error_reason(_), do: ""
end
