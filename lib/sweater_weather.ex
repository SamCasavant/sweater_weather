defmodule SweaterWeather do
  @moduledoc """
  Provides a get_advice function to recommend attire choices based on today's weather forecast.
  Also provides an executable interface for interacting with the get_advice function.
  """

  @doc """
  escript executable function for interfacing with this module.

  ## Arguments
    Arguments can be passed in with flags or during program execution.
    - city: full name of user's city
    - state: user's state formatted as "ohio", "OH", or "US-OH"
    - api-key: API key for OpenWeatherMaps.org

  ## Examples

      [user@computer]> ./sweater_weather --city=columbus --state=ohio --api-key=1234567890

      [user@computer]> ./sweater_weather
          Enter city: Columbus
          Enter state: OH
          Enter api_key: 1234567890


  """
  def main(args \\ []) do
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

  defp request_arg(arg) do
    IO.write("Enter #{Atom.to_string(arg)}: ")

    case IO.read(:stdio, :line) do
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        Process.exit(self(), :normal)

      data ->
        {arg, String.trim(data, "\n")}
    end
  end

  @doc """
    ## Parameters
      - city: full name of user's city
      - state: full name of user's state or postal abbreviation
      - api-key: API key for OpenWeatherMaps.org

    ## Examples
      iex> SweaterWeather.get_advice("columbus", "ohio", "1234567890")

  """
  def get_advice(city, state, api_key) do
    # Todo: Handle errors
    {:ok, config} = File.read("config.json")
    {:ok, config_map} = JSON.decode(config)

    state_code =
      case get_state_code(state) do
        {:ok, code} -> code
        {:error, reason} -> raise reason
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

  @doc """
  Takes a US state, district, or outlying area by name and returns an ISO 3166-2 format code.
  ## Examples
    iex> SweaterWeather.get_state_code("puerto Rico")
    {:ok, "US-PR"}
    iex> SweaterWeather.get_state_code("oh")
    {:ok, "US-OH"}
    iex> SweaterWeather.get_state_code("us-nv")
    {:ok, "US-NV"}
  """
  def get_state_code(state) do
    # Handle us-xy format and capitalize
    state =
      String.upcase(state)
      |> String.split(["US-", "US"])
      |> Enum.at(-1)

    {:ok, state_codes} = File.read("data/state_code_map.json")
    {:ok, state_code_map} = JSON.decode(state_codes)

    state_map_match =
      case String.length(state) do
        2 ->
          # Assume input is abbreviation and validate
          state_map_match =
            Enum.find(state_code_map, fn pair ->
              code = pair["abbreviation"]
              match?(^code, state)
            end)

        _ ->
          Enum.find(state_code_map, fn pair ->
            name = String.upcase(pair["name"])
            match?(^name, state)
          end)
      end

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
