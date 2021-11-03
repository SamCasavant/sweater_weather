# SweaterWeather

This is my submission for the code challenge. Look upon my works, ye mighty, and let me know what you think.

## Experience

I worked in elixir for the first time a couple weeks before starting this project. I had about 10 hours of experience going into this, and I had never worked with a functional language before. I suspect there are some anti-patterns and non-idiomatic code. In particular, I hit a mental block working with recursion and having multiple function definitions for different inputs. I am also concerned that my code is littered with :oks and calls to Enum, but I don't have enough experience to determine if that is normal.

I had some issues writing tests for functions that require an API key. I was able to request the api key from the user in my test script, but had no luck doing so with doctests. I rewrote the relevant functions with a :test option for API key and added some sample query data. I didn't write tests for the escript binary, and I didn't research whether that was a possibility.

The prompt doesn't mention a time range, so I am assuming tomorrow's 9-5 weather is the pertinent measurement. I am loosely implementing time and date options because I expect that they would be needed to make the program useful, but there are no tests or CLI implementations and the resolution is in hours.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sweater_weather` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sweater_weather, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sweater_weather](https://hexdocs.pm/sweater_weather).
