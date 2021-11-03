defmodule SweaterWeather do
  @moduledoc """
  Provides a get_advice function to recommend attire choices based on today's weather forecast.
  """
  @doc """
  Takes a decoded json response from OpenWeatherMap.org, returns data trimmed to specified time range.

  Parameters:
    date: 0 = today, 1 = tomorrow .. 4 = four days from now
    start_time, end_time: The endpoints of a range in local, military time hours. start_time is inclusive, end_time is exclusive.
  Issues:
    This will not account for times outside of the data on a given date, ie. if the date provided is today and the start_time has already passed,
    the resulting issues are considered out of scope for this prototype and aren't handled.
  """

  def restrict_weather_range(weather_map, date \\ 1, start_time \\ 9, end_time \\ 17) do
    # TODO: The amount of code here is not proportional to the work done. Refactor
    current_datetime_utc = DateTime.utc_now()
    {:ok, city} = Map.fetch(weather_map, "city")
    {:ok, timezoneshift} = Map.fetch(city, "timezone")
    current_datetime_local = DateTime.add(current_datetime_utc, timezoneshift, :second)

    target_datetime_local = DateTime.add(current_datetime_local, date * 86400, :second)
    target_date = DateTime.to_date(target_datetime_local)

    {:ok, start_time} = Time.new(start_time, 0, 0)
    {:ok, end_time} = Time.new(end_time, 0, 0)

    {:ok, start_datetime} = DateTime.new(target_date, start_time)
    {:ok, end_datetime} = DateTime.new(target_date, end_time)

    start_unix = DateTime.to_unix(start_datetime)
    end_unix = DateTime.to_unix(end_datetime)

    {:ok, weather_list} = Map.fetch(weather_map, "list")

    Enum.reduce_while(weather_list, [], fn map, acc ->
      case map["dt"] do
        time when time < start_unix -> {:cont, acc}
        time when time >= end_unix -> {:halt, acc}
        _time -> {:cont, [map | acc]}
      end
    end)
  end

  @doc """
    ## Parameters
      - city: full name of user's city
      - state: ISO 3166-2 State Code
      - api-key: API key for OpenWeatherMap.org

    ## Examples
      iex> SweaterWeather.get_advice("columbus", "OH,US", :test)
      TODO
  """
  def get_advice(city, state_code, api_key) do
    # Todo: Handle errors
    {:ok, config} = File.read("config.json")
    {:ok, config_map} = JSON.decode(config)

    {:ok, five_day_forecast} = get_weather(city, state_code, api_key)
    weather = restrict_weather_range(five_day_forecast, 1, 9, 17)
    {:ok, high, low, conditions} = parse_weather(weather)
    advise(config_map, high, low, conditions)
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
  Takes decoded JSON weather data and returns high, low, and weather conditions.


  Examples:

  iex> output = File.read!('sample_data/sample_weather_query.json') |> JSON.decode() |> restrict_weather_range() |> parse_weather()
  {:ok, 10, 20, ["clouds"]]}
  """
  def parse_weather(weather_list) do
    # Note: temp_max = temp_min = temp for the 5 day forecast queries being used. Revise to consider all three if query type changes.
    temps =
      Enum.reduce(weather_list, [], fn forecast, acc -> [forecast["main"]["temp"] | acc] end)

    high = Enum.max(temps)
    low = Enum.min(temps)
    # TODO: forecast["weather"] is a list. This is probably for a good reason, but I haven't
    # encountered an instance with multiple elements, so I'm just taking the first element for now.
    # Next step in addressing this is catching when we have multiple "weather" elements.
    conditions =
      Enum.reduce(weather_list, [], fn forecast, acc ->
        [List.first(forecast["weather"], 0)["main"] | acc]
      end)

    {:ok, high, low, conditions}
  end

  def advise(config, high, low, conditions) do
    available_recommendations = config["available_recommendations"]
    wet = Enum.any?(conditions, fn condition -> condition in ["rain", "snow"] end)

    recommendations =
      Enum.reduce(available_recommendations, [], fn recommendation, acc ->
        if recommendation["waterproof"] != wet && recommendation["max_temp"] > low &&
             recommendation["min_temp"] < high do
          [recommendation["name"] | acc]
        else
          acc
        end
      end)

    IO.inspect(high)
    IO.inspect(low)
    IO.inspect(conditions)
    IO.inspect(recommendations)
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

    {:ok, state_code} = get_state_code(options[:state])
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
    {:ok, "PR,US"}

    iex> CLI.get_state_code("oh")
    {:ok, "OH,US"}

    iex> CLI.get_state_code("us-nv")
    {:ok, "NV,US"}
  """
  def get_state_code(state) do
    # Handle us-xy / usxy format and capitalize
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
      %{"abbreviation" => code, "name" => _} -> {:ok, code <> ",US"}
    end
  end
end
