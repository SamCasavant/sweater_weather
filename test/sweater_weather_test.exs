defmodule SweaterWeatherTest do
  use ExUnit.Case
  doctest SweaterWeather

  test "gets state code" do
    assert SweaterWeather.get_state_code("ohio") == {:ok, "US-OH"}
    assert SweaterWeather.get_state_code("DISTRICT OF COLUMBIA") == {:ok, "US-DC"}
    assert SweaterWeather.get_state_code("Northern Mariana Islands") == {:ok, "US-MP"}
    assert SweaterWeather.get_state_code("al") == {:ok, "US-AL"}
  end

  test "requests weather" do
    IO.puts("Please enter your API key:")
    api_key = IO.read(:stdio, :line)
    assert {:ok, data} = SweaterWeather.get_weather("cleveland", "US-OH", api_key)
    assert {:ok, data} = SweaterWeather.get_weather("LOS ANGELES", "US-CA", api_key)
  end
end
