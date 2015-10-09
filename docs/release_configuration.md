# Release Configuration

## How to configure your release

There are two forms of configuration I will deal with here. One is
configuration for the release process itself, the latter is handling
application configuration for your release. The following custom release
configuration is supported:

- `rel/sys.config` - This is the configuration file the release will use in production. I would use `config/config.exs` or `config/myapp.conf` (if using conform) instead of this, but it's there if you want it.
- `rel/vm.args` - This file contains line-separated arguments that the Erlang VM will use when booting up. Provide your own here and it will be used instead of the default one. Make sure you provide values for `sname` and `cookie` though, or you won't be able to connect to your release!
- `rel/relx.config` - This file is used to provide configuration to exrm's underyling relx dependency. See the documentation at [relx's GitHub page](https://github.com/erlware/relx) for more information on what you can provide here. The default one should cover 99% of cases, but if you need to tweak values, you can provide your own relx configuration, and setting the config values you care about. You do not need to provide the entire configuration, as your customizations will be merged with the defaults exrm uses.

Elixir has support for providing configuration using Elixir terms in a
`config/config.exs` file. While this is perfectly usable, it's not very
simple for your operations group to work with, and generally contains no
useful documentation on what each setting is for or what they do. To
help make configuration much more easy and maintainable, exrm bundles a
dependency called [conform](https://github.com/bitwalker/conform). It is optional to use, but is there if you desire to use it.

### Using Conform with Exrm

Conform relies primarily on two files: a `<project>.schema.exs` file, and
a `<project>.conf` file. The .conf file is where you will configure your
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
located in `$DEPLOY_DIR/releases/$RELEASE_VER/myapp.conf` per default 
(also it could be moved, using `RELEASE_CONFIG_FILE` or `RELEASE_CONFIG_DIR` environment variables). 
Your ops group can then do all their configuration in production via that file.

If you are wondering how that .conf file is usable by the VM, it's very
simple. When you run `<deploy dir>/bin/<project> start`, or any other command which boots
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

You can also change the directory of all your configuration files `sys.config`, 
`vm.args` and `<project>.conf` using `RELEASE_CONFIG_DIR` or only for conform 
config `<project>.conf` using `RELEASE_CONFIG_FILE` system environments like this:

`RELEASE_CONFIG_DIR=/some_path_to_configs bin/<project> start`

or

`RELEASE_CONFIG_FILE=/some_path_to_configs/<project>.conf bin/<project> start`

So you can have persistent configuration for your application.

The configs placed in `$DEPLOY_DIR/releases/$RELEASE_VER` will be used 
as persistent default configs. They will be used by first release start and placed in 
`$DEPLOY_DIR/releases/$RELEASE_VER/running-config` if no
`RELEASE_MUTABLE_DIR` defined. It is also possible to move the running-config, logs
and erl_pipes using `RELEASE_MUTABLE_DIR` system environment. The idea is to 
hold persistent and non-persistent data separately.

**NOTE**: If not using conform, and relying on `config.exs`, you cannot use dynamic code which relies on the runtime environment, i.e:

```
config :myapp,
  foo: System.get_env("FOOBAR")
```

The reason for this is that the Erlang VM uses `sys.config` for configuration, and `sys.config` can only contain static terms, not function calls or other dynamic code. When your `config.exs` is evaluated and converted to `sys.config`, the dynamic code in `config.exs` is executed, evaluated, and the result is persisted in `sys.config`. If you are relying on such things as environment variables in `config.exs`, the value stored in `sys.config` will be the value of those variables when the build was produced, not their values when the release is booted, which is almost certainly not what you intended. When running your app with `iex -S mix` or `mix run --no-halt`, the way configuration is evaluated is different, as Mix will load the config from `config.exs`, and overwrite whatever is in the default configuration. As neither Mix, nor your `config.exs` is present in a release, this is not possible. If you need to load configuration from the environment at runtime, you will need to do something like the following:

```
my_setting = Application.get_env(:myapp, :setting) || System.get_env("MY_SETTING") || default_val
```
