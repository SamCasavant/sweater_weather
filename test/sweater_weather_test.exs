defmodule SweaterWeatherTest do
  use ExUnit.Case
  doctest SweaterWeather
  doctest CLI

  test "gets state code" do
    assert CLI.get_state_code("ohio") == {:ok, "OH,US"}
    assert CLI.get_state_code("DISTRICT OF COLUMBIA") == {:ok, "DC,US"}
    assert CLI.get_state_code("Northern Mariana Islands") == {:ok, "MP,US"}
    assert CLI.get_state_code("al") == {:ok, "AL,US"}
  end

  test "requests weather" do
    # get_weather will send url to stdout for manual review
    assert {:ok, _data} = SweaterWeather.get_weather("cleveland", "OH,US", :test)
    assert {:ok, _data} = SweaterWeather.get_weather("LOS ANGELES", "CA,US", :test)
  end
end
