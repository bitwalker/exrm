# Elixir Release Manager

Thanks to @tylerflint for the original Makefile, rel.config, and runner script which inspired this project!

## Usage

NOTE: Due to a bug in Elixir's compilation process (fixed in v0.13), the v0.12.x versions of Elixir will require you to add `:kernel`, `:stdlib`, and `:elixir` to your projects application dependencies array in order for releases to work for you. If you encounter issues, please let me know and I will work with you to make sure you are able to use exrm with your project.

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

## Getting Started

This project's goal is to make releases with Elixir projects a breeze. It is composed of a mix task, and build files required to successfully take your Elixir project and perform a release build, and a [simplified configuration mechanism](https://github.com/bitwalker/conform) which integrates with your current configuration and makes it easy for your operations group to configure the release once deployed. All you have to do to get started is the following:

#### Add exrm as a dependency to your project

```elixir
  defp deps do
    [{:exrm, "~> 0.6.5"}]
  end
```

#### Fetch and Compile

- `mix deps.get`
- `mix deps.compile`

#### Perform a release

- `mix release`

### Configuration

I'm going to go in to more detail on how configuration works later on,
for now just know that when you run `mix release` for the first time,
exrm will warn you that it couldn't find a `yourapp.conf` and
`yourapp.schema.exs` file, and generates them for you based on your
current configuration which is defined in `config/config.exs`. The
`.conf` is where you will configure your app, and the `.schema.exs` is
where you define the configuration available in the `.conf`.

#### Run your app! (my example is based on a simple ping server, see the appendix for more info)

```
> rel/test/bin/test console
Erlang/OTP 17 [RELEASE CANDIDATE 1] [erts-6.0] [source-fdcdaca] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false]

Interactive Elixir (0.12.5) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> :gen_server.call(:test, :ping)
:v1
iex(2)>
```

See the next few sections for information on how to deploy, run, upgrade/downgrade, and remotely connect to your release!

## Release Configuration

Elixir has support for providing configuration using Elixir terms in a
`config/config.exs` file. While this is perfectly usable, it's not very
simple for your operations group to work with, and generally contains no
useful documentation on what each setting is for or what they do. To
help make configuration much more easy and maintainable, exrm bundles a
dependency called [conform](https://github.com/bitwalker/conform).

Conform relies primarily on two files: a `yourapp.schema.exs` file, and
a `yourapp.conf` file. The .conf file is where you will configure your
app, and the .schema.exs file is where you define what configuration is
available in the .conf, and how it is translated to the final
`sys.config` that your release loads up at runtime.

Conform itself has the best documentation on how to work with these files,
and to see an example app which makes use of this, check out the
[exrm-test project](https://github.com/bitwalker/exrm-test).

Here's a quick rundown on how it works. You probably already have a `config.exs` file, and if
you don't that's fine, it's not required. If you do have one already,
you can compile your project and run `mix conform.new` to generate the
conform schema from your current configuration. If you don't have one,
check out the conform README on how to create one. Once you have the
schema file in your `config` directory, you can work off the
definitions generated from your current config, and/or start adding
definitions for config settings you wish to add.

Once your schema is all set, you can generate the default .conf file for
your app using `mix conform.configure`. This will output a .conf file to
`config/yourapp.conf`. This will be bundled with your release, and
located in `$DEPLOY_DIR/releases/$RELEASE_VER/myapp.conf`. Your ops
group can then do all their configuration in production via that file.

If you are wondering how that .conf file is usable by the VM, it's very
simple. When you run `bin/test start`, or any other command which boots
your app, a conform escript is run which translates the .conf via the
schema (also bundled with the release) to Elixir terms, that is then
merged over the top of the sys.config which is also bundled with the
release, and then saved over the top of the existing sys.config. Once
the escript has finished executing, your app is booted using that
sys.config file, and everything carries on like normal.

NOTE: Your `config/config.exs` file is still converted to the
`sys.config` which is bundled with the release. If you wish to hide
settings from your end users, put them in there, and remove the
definitions for them from your schema file. The `sys.config` is merged
with the configuration which is defined in the .conf, so your settings
will still be applied, they just won't be exposed for end users.

## Deployment

Now that you've generated your first release, it's time to deploy it! Let's walk through a simulated deployment to the `/tmp` directory on your machine, using the example app from the Appendix.

1. `mix release`
2. `mkdir -p /tmp/test`
3. `cp rel/test/test-0.0.1.tar.gz /tmp/`
4. `cd /tmp/test`
5. `tar -xf /tmp/test-0.0.1.tar.gz`

Now to start your app:

`bin/test start`

You can test if your app is alive and running with `bin/test ping`. 

If you want to connect a remote shell to your now running app:

`bin/test remote_console`

Ok, you should be staring at a standard `iex` prompt, but slightly different: `iex(test@localhost)1>`. The prompt shows us that we are currently connected to `test@localhost`, which is the value of `name` in our `vm.args` file. Feel free to ping the app using `:gen_server.call(:test, :ping)` to make sure it works.

At this point, you can't just abort from the prompt like usual and make the node shut down. This would be an obviously bad thing in a production environment. Instead, you can issue `:init.stop` from the `iex` prompt, and this will shut down the node. You will still be connected to the shell, but once you quit the shell, the node is gone.

If you want to execute a command against your running node without
attaching a shell:

`bin/test rpc erlang now`

or

`bin/test rpc calendar valid_date "{2014,3,14}."`

Notice that the arguments required are in module, function, argument
format. The argument parameter will be evaluated as an Erlang term,
and applied to the module/function. Multiple args should be formatted as
a list, i.e. `[arg1, arg2, arg3].`.

## Upgrading Releases

So you've made some changes to your app, and you want to generate a new relase and perform a no-downtime upgrade. I'm here to tell you that this is going to be a breeze, so I hope you're ready (I'm using my test app as an example here again):

1. `mix release`
2. `mkdir -p /tmp/test/releases/0.0.2`
3. `cp rel/test/test-0.0.2.tar.gz /tmp/test/releases/0.0.2/test.tar.gz`
4. `cd /tmp/test`
5. `bin/test upgrade "0.0.2"`

Annnnd we're done. Your app was upgraded in place with no downtime, and is now running your modified code. You can use `bin/test remote_console` to connect and test to be sure your changes worked as expected.

You can also provide your own .appup file, by writing one and placing it in
`rel/<app>.appup`. This location is checked before generating a new
release, and will be used instead of autogenerating an appup file for
you.

## Downgrading Releases

This is even easier! Using the example from before:

1. `cd /tmp/test`
2. `bin/test downgrade "0.0.1"`

All done!

## Common Issues

I'm starting this list to begin collating the various caveats around
building releases. As soon as I feel like I have a firm grasp of all the
edge cases, I'll formalize this in a better format perhaps as a
"Preparing for Release" document.

- Ensure all dependencies for your application are defined in the
  `:applications` block of your `mix.exs` file. This is how the build
  process knows that those dependencies need to be bundled in to the
  release. **This includes dependencies of your dependencies, if they were
  not properly configured**. For instance, if you depend on `mongoex`, and
  `mongoex` depends on `erlang-mongodb`, but `mongoex` doesn't have `erlang-mongodb`
  in it's applications section, your app will fail in it's release form,
  because `erlang-mongodb` won't be loaded.
- If you are running into issues with your dependencies missing their
  dependencies, it's likely that the author did not put the dependencies in
  the `:application` block of *their* `mix.exs`. You may have to fork, or
  issue a pull request in order to resolve this issue. Alternatively, if
  you know what the dependency is, you can put it in your own `mix.exs`, and
  the release process will ensure that it is loaded with everything else.

If you run into problems, this is still early in the project's development, so please create an issue, and I'll address ASAP.

## Appendix

The example server I setup was as simple as this:

1. `mix new test`
2. `cd test && touch lib/test/server.ex`

Then put the following in `lib/test/server.ex`

```elixir
defmodule Test.Server do
  use GenServer.Behaviour

  def start_link() do
    :gen_server.start_link({:local, :test}, __MODULE__, [], [])
  end

  def init([]) do
    { :ok, [] }
  end
  
  def handle_call(:ping, _from, state) do
    { :reply, :pong, state }
  end

end
```

You can find the source code for my example application [here](https://github.com/bitwalker/exrm-test). You should be able to replicate my example using these steps. If you can't, please let me know.
