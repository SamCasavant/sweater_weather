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

  test "parses weather" do
    weather_data =
      File.read!('sample_data/sample_weather_query.json')
      |> JSON.decode!()
      |> Map.get("list")

    # Across several measurements
    assert {52.12, 42.98, ["Clouds", "Clouds", "Clouds", "Clouds", "Clouds"]} ==
             SweaterWeather.eval_weather(weather_data, 1_635_800_400, 1_635_843_600)

    # Within a single measurement
    assert {52.12, 52.12, ["Clouds"]} ==
             SweaterWeather.eval_weather(weather_data, 1_635_800_400, 1_635_800_500)
  end

  test "advises appropriate attire" do
    config = JSON.decode!(File.read!("config.json"))
    # On a hot day:
    assert ["Comfortable Shoes", "Rain Jacket", "Sunglasses"] =
             SweaterWeather.advise(config, 120, 70, ["Clouds"])

    assert ["Rain Jacket"] == SweaterWeather.advise(config, 120, 70, ["Rain"])
    # On a comfortable day:
    assert ["Comfortable Shoes", "Sweater", "Rain Jacket"] =
             SweaterWeather.advise(config, 75, 65, ["Sunny"])

    assert ["Rain Jacket"] == SweaterWeather.advise(config, 75, 65, ["Rain"])
    # On a cold day:
    assert ["Snow Boots", "Heavy Coat", "Comfortable Shoes", "Light Coat"] =
             SweaterWeather.advise(config, 40, 20, ["Clouds"])

    assert ["Snow Boots", "Heavy Coat", "Light Coat"] =
             SweaterWeather.advise(config, 40, 20, ["Snow"])
  end
end
