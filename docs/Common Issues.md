# Common Issues

## Problems often encountered by new users

I'm starting this list to begin collating the various caveats around
building releases. As soon as I feel like I have a firm grasp of all the
edge cases, I'll formalize this in a better format perhaps as a
"Preparing for Release" document.

- Ensure all dependencies for your application are defined in either the
  `:applications` or `:included_applications` block of your `mix.exs` file. This is how the build
  process knows that those dependencies need to be bundled in to the
  release. **This includes dependencies of your dependencies, if they were
  not properly configured**. For instance, if you depend on `mongoex`, and
  `mongoex` depends on `erlang-mongodb`, but `mongoex` doesn't have `erlang-mongodb`
  in it's applications list, your app will fail in it's release form,
  because `erlang-mongodb` won't be loaded.
- If you are running into issues with your dependencies missing their
  dependencies, it's likely that the author did not put the dependencies in
  the `:application` block of *their* `mix.exs`. You may have to fork, or
  issue a pull request in order to resolve this issue. Alternatively, if
  you know what the dependency is, you can put it in your own `mix.exs`, and
  the release process will ensure that it is loaded with everything else.
- Due to the way `config.exs` is converted to the `sys.config` file used by
  Erlang releases, it is important to make sure all of your config values are
  namespaced by application, i.e. `config :myapp, foo: bar` instead of `config foo: bar`,
  and access your config via `Application.get_env(:myapp, :foo)`. If you do not
  do this, you will likely run into issues at runtime complaining that you are attempting
  to access configuration for an application that is not loaded.

If you run into problems, please create an issue, and I'll address ASAP.
