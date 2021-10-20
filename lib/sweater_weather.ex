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
    # CLI function to parse arguments and send output to stdout
    if length(args) <= 1 do
      IO.puts(
        "Please provide city, state, and api key with --city={city} --state={state} --api-key={key}"
      )

      # Todo: This can be an interactive prompt
      Process.exit(self(), :normal)
    end

    options = parse_args(args)
    # Todo: handle errors
    get_advice(options[:city], options[:state], options[:"api-key"])
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
      "api.openweathermap.org/data/2.5/forecast?q=#{city},#{state_code}&appid=#{api_key}"

    {:ok, resp} = :httpc.request(:get, {query_url})
    resp
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
      OptionParser.parse(args, switches: [city: :string, state: :string, "api-key": :string])

    options
  end
end
