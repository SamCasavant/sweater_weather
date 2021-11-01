defmodule SweaterWeatherTest do
  use ExUnit.Case
  doctest SweaterWeather
  doctest CLI

  test "gets state code" do
    assert CLI.get_state_code("ohio") == {:ok, "US-OH"}
    assert CLI.get_state_code("DISTRICT OF COLUMBIA") == {:ok, "US-DC"}
    assert CLI.get_state_code("Northern Mariana Islands") == {:ok, "US-MP"}
    assert CLI.get_state_code("al") == {:ok, "US-AL"}
  end

  test "requests weather" do
    # get_weather will send url to stdout for manual review
    assert {:ok, _data} = SweaterWeather.get_weather("cleveland", "US-OH", :test)
    assert {:ok, _data} = SweaterWeather.get_weather("LOS ANGELES", "US-CA", :test)
  end
end
