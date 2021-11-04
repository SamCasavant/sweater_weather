defmodule SweaterWeather do
  @moduledoc """
  Provides a get_advice function to recommend attire choices based on today's weather forecast.
  """
  @doc """
  Takes a decoded json response from OpenWeatherMap.org, returns data trimmed to specified time range.

  Parameters:
    day: 0 = today, 1 = tomorrow .. 4 = four days from now
    start_time, end_time: The endpoints of a range in local, military time hours. start_time is inclusive, end_time is exclusive.
  Issues:
    This will not account for times outside of the data on a given date, ie. if the date provided is today and the start_time has already passed,
    the resulting issues are considered out of scope for this prototype and aren't handled.
  """

  def reduce_timespan(weather_list, first_unix, last_unix) do
    Enum.reduce_while(weather_list, [], fn map, acc ->
      case map["dt"] do
        time when time < first_unix -> {:cont, acc}
        time when time >= last_unix -> {:halt, acc}
        _time -> {:cont, [map | acc]}
      end
    end)
  end

  def future_to_unix_time(local_time, day, hour) do
    {:ok, date} = DateTime.from_unix(local_time + day * 86_400)
    {:ok, datetime} = DateTime.new(DateTime.to_date(date), Time.new!(hour, 0, 0))
    DateTime.to_unix(datetime)
  end

  @doc """
  ## Parameters
  - city: full name of user's city
  - state: ISO 3166-2 State Code
  - api-key: API key for OpenWeatherMap.org

  ## Examples
  iex> SweaterWeather.get_advice("columbus", "OH", :test)

  """
  def get_advice(city, state_code, api_key, day \\ 1, first_hour \\ 9, last_hour \\ 17) do
    {:ok, config_map} =
      try do
        {:ok, config} = File.read("config.json")
        JSON.decode(config)
      rescue
        e in RuntimeError ->
          reraise("Invalid or missing config.json. Error: #{e}", __STACKTRACE__)
      end

    {:ok, full_weather} = get_weather(city, state_code, api_key)

    timezone = Kernel.get_in(full_weather, ["city,", "timezone"])
    {first_unix, last_unix} = prepare_times(timezone, day, first_hour, last_hour)

    {high, low, conditions} = eval_weather(full_weather["list"], first_unix, last_unix)

    recommendation_list = advise(config_map, high, low, conditions)
    {recommendation_list, high, low, first_unix, last_unix}
  end

  def eval_weather(weather_list, first_unix, last_unix) do
    shortened_list = reduce_timespan(weather_list, first_unix, last_unix)
    parse_weather(shortened_list)
  end

  def prepare_times(timezone, day, first_hour, last_hour) do
    # +/-seconds from UTC:
    local_time = :os.system_time(:second) + timezone
    first_unix = future_to_unix_time(local_time, day, first_hour)
    last_unix = future_to_unix_time(local_time, day, last_hour)
    {first_unix, last_unix}
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
    iex> output = File.read!('sample_data/sample_weather_query.json') |> JSON.decode!() |> SweaterWeather.reduce_timespan() |> SweaterWeather.parse_weather()
    {42.58, 35.67, ["Clear", "Clear", "Clear"]}
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

    {high, low, conditions}
  end

  def advise(config, high, low, conditions) do
    available_recommendations = config["available_recommendations"]
    wet = Enum.any?(conditions, fn condition -> condition in ["rain", "snow"] end)

    Enum.reduce(available_recommendations, [], fn recommendation, acc ->
      if recommendation["waterproof"] != wet && recommendation["max_temp"] > low &&
           recommendation["min_temp"] < high do
        [recommendation["name"] | acc]
      else
        acc
      end
    end)
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
      IO.puts(
        "sweater_weather is a command line tool that provides the user with attire advice based on weather conditions."
      )

      IO.puts(
        "If run with no arguments, or with some missing arguments, sweater_weather will prompt the user during execution."
      )

      IO.puts("Args:")
      IO.puts("\t --city/-c={city}: City to forecast")
      IO.puts("\t --state/-s={state}: City's state")
      IO.puts("\t --api-key/-k={api-key}: API key for OpenWeatherMap.org")
      IO.puts("\t --help/-h: Display this help message and exit.")
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
        raise("Error: #{reason}")

      data ->
        {arg, String.trim(data, "\n")}
    end
  end

  defp parse_args(args) do
    {options, _, _} =
      OptionParser.parse(args,
        switches: [city: :string, state: :string, "api-key": :string, help: :boolean],
        aliases: [c: :city, s: :state, k: :"api-key", h: :help]
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
