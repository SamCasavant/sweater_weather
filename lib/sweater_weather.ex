defmodule SweaterWeather do
  @moduledoc """
  Documentation for `SweaterWeather`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SweaterWeather.hello()
      :world

  """
  def main(args \\ []) do
    # CLI wrapper to parse arguments and send output to stdout.
    options = parse_args(args)

    with true <- options[:help] do
      IO.puts("Help text")
      Process.exit(self(), :normal)
    end

    # Handle missed arguments
    options =
      for arg <- [:city, :state, :api_key] do
        case options[arg] do
          nil -> request_arg(arg)
          _ -> {arg, options[arg]}
        end
      end

    get_advice(options[:city], options[:state], options[:api_key])
  end

  def request_arg(arg) do
    IO.write("Enter #{Atom.to_string(arg)}: ")

    case IO.read(:stdio, :line) do
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        Process.exit(self(), :normal)

      data ->
        {arg, String.trim(data, "\n")}
    end
  end

  def get_advice(city, state, api_key) do
    # Todo: Handle errors
    {:ok, config} = File.read("config.json")
    {:ok, config_map} = JSON.decode(config)

    {:ok, state_code} =
      case String.length(state) do
        2 -> {:ok, "US-" <> state}
        x when x > 3 -> get_state_code(state)
      end

    {:ok, weather} = get_weather(city, state_code, api_key)
    # advise(config_map, weather)
  end

  def get_weather(city, state_code, api_key) do
    Application.ensure_all_started(:inets)

    query_url =
      'http://api.openweathermap.org/data/2.5/forecast?q=#{city},#{state_code}&appid=#{api_key}'

    {:ok, {{_, 200, 'OK'}, _headers, weather_json}} =
      :httpc.request(:get, {query_url, []}, [], body_format: :string)

    JSON.decode(weather_json)
  end

  def get_state_code(state) do
    # todo handle errors
    {:ok, state_codes} = File.read("data/state_code_map.json")
    {:ok, state_code_map} = JSON.decode(state_codes)

    state_map_match =
      Enum.find(state_code_map, fn pair ->
        name = String.downcase(pair["name"])
        match?(^name, String.downcase(state))
      end)

    case state_map_match do
      nil -> {:error, "State not found: #{state}"}
      %{"abbreviation" => code, "name" => _} -> {:ok, "US-" <> code}
    end
  end

  defp parse_args(args) do
    {options, _, _} =
      OptionParser.parse(args,
        switches: [city: :string, state: :string, "api-key": :string]
      )

    options
  end
end
