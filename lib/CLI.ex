defmodule CLI do
  @moduledoc """
  Module to interface between command-line and SweaterWeather. Should be built as an escript with mix escript.build."""
  @doc """
  escript executable

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

    state_code =
      case get_state_code(options[:state]) do
        {:ok, state_code} -> state_code
        {:error, message} -> raise(message)
      end

    {recommendations, high, low, first_unix, last_unix, cityname} =
      SweaterWeather.get_advice(options[:city], state_code, options[:api_key])

    {:ok, first_datetime} = DateTime.from_unix(first_unix)
    {:ok, last_datetime} = DateTime.from_unix(last_unix)

    IO.puts(
      "Tomorrow in #{cityname}, expect a high of #{high} and a low of #{low} between #{first_datetime} and #{last_datetime}."
    )

    Enum.each(recommendations, fn rec ->
      IO.puts("SweaterWeather thinks you should bring a #{rec}")
    end)
  end

  defp request_arg(arg) do
    IO.write("Enter #{Atom.to_string(arg)}: ")

    case IO.read(:stdio, :line) do
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        request_arg(arg)

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
  """
  def get_state_code(state) do
    # Handle us-xy / usxy format and capitalize
    state =
      String.upcase(state)
      |> String.split(["US-", "US"])
      |> Enum.at(-1)

    state_code_map =
      try do
        JSON.decode!(File.read!("data/state_code_map.json"))
      rescue
        e in RuntimeError ->
          IO.puts("Missing or invalid file at data/state_code_map.json. Error: " <> e.message)
      end

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
