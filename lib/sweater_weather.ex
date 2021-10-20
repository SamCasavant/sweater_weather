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
    Enum.each(options, fn option -> IO.puts(elem(option, 1)) end)
  end

  def get_advice(city, state, api_key) do
    # Todo: Handle errors
    {:ok, config} = File.read("config.json")
    {:ok, config_map} = JSON.parse(config)
    # Todo: implement get_state_code
    {:ok, state_code} = get_state_code(state)
    {:ok, weather} = get_weather(city, state_code, api_key)
  end

  def get_weather(city, state_code, api_key) do
    Application.ensure_all_started(:inets)

    query_url =
      "api.openweathermap.org/data/2.5/forecast?q=#{city},#{state_code}&appid=#{api_key}"

    {:ok, resp} = :httpc.request(:get, {query_url})
  end

  defp parse_args(args) do
    {options, _, _} =
      OptionParser.parse(args, switches: [city: :string, state: :string, "api-key": :string])

    options
  end
end
