# Elixir Release Manager

[![Build
Status](https://travis-ci.org/bitwalker/exrm.svg?branch=master)](https://travis-ci.org/bitwalker/exrm)
[![Hex.pm Version](http://img.shields.io/hexpm/v/exrm.svg?style=flat)](https://hex.pm/packages/exrm) [![Coverage Status](https://coveralls.io/repos/bitwalker/exrm/badge.svg?branch=master&service=github)](https://coveralls.io/github/bitwalker/exrm?branch=master)

The full documentation for Exrm is located [here](https://hexdocs.pm/exrm).

Thanks to @tylerflint for the original Makefile, rel.config, and runner script which inspired this project!

## Usage

You can build a release with the `release` task:

- `mix release`

This task constructs the complete release for you. The output is sent to `rel/<project>`. To see what flags you can pass to this task, use `mix help release`.

One really cool thing you can do is `mix release --dev`. This will symlink your application's code into the release, allowing you to make code changes, recompile with `MIX_ENV=prod mix compile`, and rerun your release with `rel/<project>/bin/<project> console` to see the changes. Being able to rapidly test and tweak your release like this goes a long way to making the release process less tedious!

- `mix release.clean [--implode]`

Without args, this will clean up the release corresponding to the
current project version.

With `--implode`, all releases, configuration, generated tools, etc.,
will be cleaned up, leaving your project directory the same as if exrm
had never been run. This is a destructive operation, as you can't get
your releases back unless they were source-controlled, so exrm will ask
you for confirmation before proceeding with the cleanup.

NOTE: Umbrella projects work a little differently. Each sub-project is
built into it's own release, but contains all of it's dependencies

## Getting Started

This project's goal is to make releases with Elixir projects a breeze. It is composed of a mix task, and build files required to successfully take your Elixir project and perform a release build, and a [simplified configuration mechanism](https://github.com/bitwalker/conform) which integrates with your current configuration and makes it easy for your operations group to configure the release once deployed. All you have to do to get started is the following:

#### Add exrm as a dependency to your project

```elixir
  defp deps do
    [{:exrm, "~> x.x.x"}]
  end
```

## License

This project is MIT licensed. Please see the `LICENSE.md` file for more details.
