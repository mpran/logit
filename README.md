# Logit

Telemetry event shipping library

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `logit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logit, "~> 0.1.0"}
  ]
end
```

## Usage

- Add `Logit.Processors.<...>` to your apps sup tree. You can also specify which processors to attach, by default it will attach to all processors in that group.
To specify processors add `{Logit.Processors.<...>, [processors: [...]]}` to supervision tree
