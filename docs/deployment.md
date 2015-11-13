# Deployment

## How to deploy your release

A quick word of warning: It is currently not supported to perform hot upgrades/downgrades from the `rel` directory. This is because the upgrade/downgrade process deletes files from the release when it is installed, which will cause issues when you are attempting to build a release of the next version of your app. It is important that you do actual deployments of your app outside of the build directory if you plan on using this feature of releases!

First lets talk about how you can run your release after executing `mix release`. The following example code is based on the [exrm-test project](https://github.com/bitwalker/exrm-test):

```
> rel/test/bin/test console
Erlang/OTP 17 [erts-6.0] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.0.5) - press Ctrl+C to exit (type h() ENTER for help)
iex(test@127.0.0.1)1> :gen_server.call(:test, :ping)
:v1
iex(test@127.0.0.1)2>
```

As you can see from the above example, running the `console` command allows you to boot your release with an `iex` console just like if you had run `iex -S mix`. This allows you to quickly test and play around with your running release build!


### Deployment

Now that you've generated your first release, it's time to deploy it! Let's walk through a simulated deployment to the `/tmp` directory on your machine:

1. `mix release`
2. `mkdir -p /tmp/test`
3. `cp rel/test/releases/0.0.1/test.tar.gz /tmp/`
4. `cd /tmp/test`
5. `tar -xf /tmp/test.tar.gz`

Now to start your app:

```
$ bin/test start
```

You can test if your app is alive and running with:

```
$ bin/test ping
``` 

If you want to connect a remote shell to your now running app:

```
$ bin/test remote_console
```

Ok, you should be staring at a standard `iex` prompt, but slightly different, something like:

```
iex(test@localhost)1>
```

The prompt shows us that we are currently connected to `test@localhost`, which is the value of `name` in our `vm.args` file. Feel free to ping the app using `:gen_server.call(:test, :ping)` to make sure it works (just to recap, this is based on the example app described above, your own application will not have this function available).

At this point, you can't just abort from the prompt like usual and make the node shut down (which is what occurs when you are doing this from the `console` command). This would be an obviously bad thing in a production environment. Instead, you can execute `:init.stop` from the `iex` prompt, and this will shut down the node. You will still be connected to the shell, but once you quit the shell, the node is gone.

### Executing code against a running release

If you want to execute a command against your running node without
attaching a shell you can do something like the following:

```
$ bin/test rpc erlang now
```

or

```
$ bin/test rpc calendar valid_date "{2014,3,14}."
```

Notice that the arguments required are in module, function, argument
format. The argument parameter will be evaluated as an Erlang term,
and applied to the module/function. Multiple args should be formatted as
a list, i.e. `[arg1, arg2, arg3].`.
