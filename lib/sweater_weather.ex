defmodule SweaterWeather do
  @moduledoc """
  Provides a get_advice function to recommend attire choices based on today's weather forecast.
  """

  @doc """
    ## Parameters
      - city: full name of user's city
      - state: ISO 3166-2 State Code
      - api-key: API key for OpenWeatherMap.org

    ## Examples
      iex> SweaterWeather.get_advice("columbus", "US-OH", :test)
      TODO
  """
  def get_advice(city, state_code, api_key) do
    # Todo: Handle errors
    {:ok, config} = File.read("config.json")
    {:ok, config_map} = JSON.decode(config)

    {:ok, weather} = get_weather(city, state_code, api_key)

    # advise(config_map, weather)
  end

  def get_weather(city, state_code, api_key) do
    Application.ensure_all_started(:inets)
    city_url = String.split(city, " ") |> Enum.join("%20")

    query_url =
      'http://api.openweathermap.org/data/2.5/forecast?q=#{city_url},#{state_code}&units=imperial&appid=#{api_key}'

    case api_key do
      :test ->
        IO.puts(query_url)
        JSON.decode(File.read!('sample_data/sample_weather_query.json'))

      _ ->
        {:ok, {{_, 200, 'OK'}, _headers, weather_json}} =
          :httpc.request(:get, {query_url, []}, [], body_format: :string)

        JSON.decode(weather_json)
    end
  end

  @doc """
  Takes weather decoded JSON data and returns high, low, and weather conditions.


  Examples:

  iex> output = File.read!('sample_data/sample_weather_query.json') |> JSON.decode() |> restrict_weather_range() |> parse_weather()
    {:ok, high, low, [conditions]}
  """
  def parse_weather(weather_map) do
  end

  @doc """
  Takes a decoded json response from OpenWeatherMap.org, returns data trimmed to specified time range.

  Parameters:
    date: 0 = today, 1 = tomorrow .. 4 = four days from now
    start_time, end_time: The endpoints of a range in local, military time hours. start_time is inclusive, end_time is exclusive.
  Issues:
    This will not account for times outside of the data on a given date, ie. if the date provided is today and the start_time has already passed,
    the resulting issues are considered out of scope for this prototype and aren't handled."""
  def restrict_weather_range(weather_map, date \\ 1, start_time \\ 9, end_time \\ 17) do
    current_date_utc = DateTime.utc_now
    current_date_local = DateTime.shift_zone!(current_date_utc, local_time_zone)
  end
  end

  defmodule CLI do
  @doc """
  escript executable function for interfacing with this module.

  ## Arguments
    Arguments can be passed in with flags or during program execution.
    - city: full name of user's city
    - state: user's state formatted as "ohio", "OH", or "US-OH"
    - api-key: API key for OpenWeatherMap.org

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

    state_code = get_state_code(options[:state])
    SweaterWeather.get_advice(options[:city], state_code, options[:api_key])
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

  defp parse_args(args) do
    {options, _, _} =
      OptionParser.parse(args,
        switches: [city: :string, state: :string, "api-key": :string]
      )

    options
  end

  @doc """
  Takes a US state, district, or outlying area by name and returns an ISO 3166-2 format code.
  ## Examples
    iex> CLI.get_state_code("puerto Rico")
    {:ok, "US-PR"}

    iex> CLI.get_state_code("oh")
    {:ok, "US-OH"}

    iex> CLI.get_state_code("us-nv")
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
end
