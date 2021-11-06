defmodule SweaterWeather do
  @moduledoc """
  Provides a get_advice function to recommend attire choices based on today's weather forecast.
  """
  @doc """
  get_advice takes a location and API key and returns advice
  ## Parameters
  - city: full name of user's city
  - state: ISO 3166-2 State Code
  - api-key: API key for OpenWeatherMap.org

  """
  def get_advice(city, state_code, api_key, day \\ 1, first_hour \\ 9, last_hour \\ 17) do
    config_map =
      try do
        JSON.decode!(File.read!("config.json"))
      rescue
        e in RuntimeError ->
          reraise("Invalid or missing config.json. Error: " <> e.message, __STACKTRACE__)
      end

    {:ok, full_weather} = get_weather(city, state_code, api_key)

    timezone = get_in(full_weather, ["city", "timezone"])
    {first_unix, last_unix} = prepare_times(timezone, day, first_hour, last_hour)

    {high, low, conditions} = eval_weather(full_weather["list"], first_unix, last_unix)

    recommendation_list = advise(config_map, high, low, conditions)

    # Only the recommendation list needs to be returned, but the other data allows the CLI utility to be more verbose.
    {recommendation_list, high, low, first_unix, last_unix,
     get_in(full_weather, ["city", "name"])}
  end

  def advise(config, high, low, conditions) do
    available_recommendations = config["available_recommendations"]
    wet = Enum.any?(conditions, fn condition -> condition in ["Rain", "Snow"] end)

    Enum.reduce(available_recommendations, [], fn recommendation, acc ->
      if (!wet || recommendation["waterproof"]) &&
           recommendation["max_temp"] > low &&
           recommendation["min_temp"] < high do
        [recommendation["name"] | acc]
      else
        acc
      end
    end)
  end

  @doc """
  Requests a five-day forecast from OpenWeatherMap.org for given city. Decodes the resulting json data.
  """
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
        case :httpc.request(:get, {query_url, []}, [], body_format: :string) do
          {:ok, {{_, 200, 'OK'}, _headers, weather_json}} ->
            JSON.decode(weather_json)

          {:ok, {{_, 401, 'Unauthorized'}, _headers, _message}} ->
            raise("Invalid API key: #{api_key}.")

          {:ok, {{_, 404, 'Not Found'}, _headers, message}} ->
            # This should only happen if the city name is invalid
            raise("#{message["message"]} \n For #{city_url}, #{state_code}.")

          {:error, {:failed_connect, _}} ->
            raise("Unable to connect to OpenWeatherMap.org.")
        end
    end
  end

  @doc """
  Function to prepare decoded json weather data and parse it for high, low, and weather conditions.
  Example:
    iex> File.read!('sample_data/sample_weather_query.json') |> JSON.decode!() |> Map.get("list") |> SweaterWeather.eval_weather(1_635_800_400, 1_635_843_600)
    {52.12, 42.98, ["Clouds", "Clouds", "Clouds", "Clouds", "Clouds"]}
  """
  def eval_weather(weather_list, first_unix, last_unix) do
    shortened_list = reduce_timespan(weather_list, first_unix, last_unix)
    parse_weather(shortened_list)
  end

  # Takes a decoded json response from OpenWeatherMap.org, returns data trimmed to specified time range.
  # This is not written to account for times outside of the data on a given date, ie. if the date provided is today and the start_time has already passed

  defp reduce_timespan(weather_list, first_unix, last_unix) do
    Enum.reduce_while(weather_list, [], fn map, acc ->
      case map["dt"] do
        time when time < first_unix -> {:cont, acc}
        time when time > last_unix -> {:halt, acc}
        _time -> {:cont, [map | acc]}
      end
    end)
  end

  # Takes decoded JSON weather data and returns high, low, and weather conditions.
  defp parse_weather(weather_list) do
    # Note: Apparently temp_max = temp_min = temp for the 5 day forecast queries being used. Revise to consider all three if query type changes.
    temps =
      Enum.reduce(weather_list, [], fn forecast, acc -> [forecast["main"]["temp"] | acc] end)

    high = Enum.max(temps)
    low = Enum.min(temps)

    conditions =
      Enum.reduce(weather_list, [], fn forecast, acc ->
        # List.first here is hacky, I never encountered more than one element, but it's a list for some reason, right?
        [List.first(forecast["weather"], 0)["main"] | acc]
      end)

    {high, low, conditions}
  end

  # Takes all time parameters and returns unix times relative to today. timezone is provided as seconds away from UTC.
  defp prepare_times(timezone, day, first_hour, last_hour) do
    local_time = :os.system_time(:second) + timezone
    first_unix = future_to_unix_time(local_time, day, first_hour)
    last_unix = future_to_unix_time(local_time, day, last_hour)
    {first_unix, last_unix}
  end

  # Produces the number of seconds since the epoch for a date [day] days in the future at [hour] o'clock.
  defp future_to_unix_time(local_time, day, hour) do
    {:ok, date} = DateTime.from_unix(local_time + day * 86_400)
    {:ok, datetime} = DateTime.new(DateTime.to_date(date), Time.new!(hour, 0, 0))
    DateTime.to_unix(datetime)
  end
end
