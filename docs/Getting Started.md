# Getting Started

## How to get up and running with releases

This project's goal is to make releases with Elixir projects a breeze. It is composed of a mix task, and build files required to successfully take your Elixir project and perform a release build, and a [simplified configuration mechanism](https://github.com/bitwalker/conform) which integrates with your current configuration and makes it easy for your operations group to configure the release once deployed. All you have to do to get started is the following:

Start by adding exrm as a dependency to your project:

```elixir
defp deps do
  [{:exrm, "~> 0.18.1"}]
end
```

### Usage

You can build a release with the `release` task:

```
$ mix release
```

This task constructs the complete release for you. The output is sent to `rel/<project>`. To see what flags you can pass to this task, use `mix help release`.

You can start a console connected to the release build of your application with:

```
$ rel/<project>/bin/<project> console
```

### Testing a release during development

Rather than having to build a release, deploy, then test, you can actually test your release during development by using `mix release --dev`.

This symlinks your application's code into the release, allowing you to make code changes, then recompile and restart your release to see the changes. Being able to rapidly test and tweak your release like this goes a long way to making the release process less tedious!

### Cleanup

You can clean up release artifacts produced by exrm with:

```
$ mix release.clean
```

This will clean up any temporary artifacts related to the current version, and allow you to effectively start a release build from scratch.

By passing the `--implode` flag, you can further extend the clean up to *all* release related artifacts, effectively resetting yourself to a pre-exrm state. This should be done carefully, as anything related to releases will be removed!

You can pass the `--no-confirm` flag in addition to `--implode` if you want to bypass exrm's warning about removing all artifacts (this is primarily for automated tasks, but might come in useful during testing scenarios)

### **IMPORTANT**

It is currently not supported to perform hot upgrades/downgrades from the `rel` directory. This is because the upgrade/downgrade process deletes files from the release when it is installed, which will cause issues when you are attempting to build a release of the next version of your app. It is important that you do actual deployments of your app outside of the build directory!
