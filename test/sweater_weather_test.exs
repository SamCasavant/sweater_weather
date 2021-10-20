defmodule SweaterWeatherTest do
  use ExUnit.Case
  doctest SweaterWeather

  test "gets state code" do
    assert SweaterWeather.get_state_code("ohio") == "US-OH"
    assert SweaterWeather.get_state_code("DISTRICT OF COLUMBIA") == "US-DC"
    assert SweaterWeather.get_state_code("Northern Mariana Islands") == "US-MP"
  end
end
