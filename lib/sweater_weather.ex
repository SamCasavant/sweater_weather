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
    if length(args) <= 1 do
      IO.puts("Please provide city and state with --city={city} --state={state}")
      Process.exit(self(), :normal)
    end

    options = parse_args(args)
    Enum.each(options, fn option -> IO.puts(elem(option, 1)) end)
  end

  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args, switches: [city: :string, state: :string])
    options
  end
end
