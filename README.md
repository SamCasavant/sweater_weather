# SweaterWeather

This is my submission for the code challenge. Look upon my works, ye mighty, and let me know what you think.

## Installation

```
git clone https://github.com/SamCasavant/sweater_weather.git
cd sweater_weather
mix deps.get
mix escript.build

```

## Usage

```
./sweater_weather
```

or

```
./sweater_weather --city={city} --state={state} --api-key={API key}
```

## Development Notes

Assumptions:

- Weather is for 9-5 on the following day. I did a little groundwork on generalizing this, but it's not fully implemented. Weather outside of this range is considered out-of-scope because the prompt didn't mention getting time from the user (and I can't think of a convenient way to do so), but it's the biggest weakness of this program.
- I'm querying the 5-day forecast API referenced in the prompt. An hourly forecast would probably be a better source, and would probably work as a drop-in replacement.
- If there is any overlap between tomorrow's temperature and a suggested range configuration, and if , the item is suggested.
- There is only one config.json file allowed. In practice, it may be useful to be able to specify a config file at runtime.
- Weather conditions may have an associated likelihood (ie. 15% chance of rain), and whether a condition is listed is up to OpenWeatherMaps discretion.
- CLI module can be run with flags or with prompts at runtime.

Known Issues:

- If weather conditions list rain or snow, only waterproof elements can be listed, otherwise non-waterproof elements can be listed. Raincoats will be suggested even if it's not going to rain. This is necessary because the config doesn't specify whether an article is preferred in a particular type of weather.
- There is not a lot of validation that the user entered the correct location. This caused issues in development when a bug with state codes had me getting weather for Montgomery County, Maryland instead of Montgomery, Alabama. My hacky solution is to give the city name element from the API response back to the user, but it can't handle all possible mistakes.
- Recommendations don't handle plurality or correct for capitalization; output may be "SweaterWeather thinks you should bring a Snow Shoes".
- I haven't checked whether Rain and Snow are the only possible types of precipitation that can be returned from the API.
- There is no check on whether the same type of clothing is being advised in two forms, both "Light Coat" and "Heavy Coat" can be recommended at once.
- Escript prints out times as though they were UTC even though they are localized to the city's time zone.
- The escript doesn't have any tests. I haven't taken the time to figure out how to write them, if it is possible.
- Other test issues exist. A lot is dependent on current time and an API key. Rather than implement a :test version for each function, I left a few functions untested.

I'm still new to elixir, so there are probably structural issues. I preferred using the Enum module for recursive function calls, and always wrote the functions inside of those calls rather than assigning it to a variable. I made functions whenever they reduced the total length of the program, which may be too often or not often enough. I may have over-relied on case statements for program flow and error handling; there is one use of 'with' and two 'try's, but eight cases. This may all be :ok, I haven't read enough elixir to see how things normally work.

I never used @spec, which I believe is for typing. I've really grown to like typed variables while working in Rust, but I don't know how common they are in Elixir. In the interest of saving time, I elected to skip it.

I'm not thrilled with how I handled time, it seems like a lot of extra steps switching between DateTimes and unix times. If I had another go, I would probably just make everything into DateTimes so I could forget about them.

I wrote this sporadically over a couple weeks. That came with some advantages but it resulted in some inconsistent variable and function names.

I'm suspicious that naming my CLI module 'CLI' is a mistake because it's excessively generic. I haven't changed it because I prefer it this way if it's not an issue.

I am aware that the repeated calls to IO.puts in the help text could be a single call, but I find it easier to edit as-is.
