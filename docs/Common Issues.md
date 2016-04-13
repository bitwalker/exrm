# Common Issues

## Problems often encountered by new users

I'm starting this list to begin collating the various caveats around
building releases. As soon as I feel like I have a firm grasp of all the
edge cases, I'll formalize this in a better format perhaps as a
"Preparing for Release" document.


## Dependency issues

Ensure all dependencies for your application are defined in either the
`:applications` or `:included_applications` block of your `mix.exs` file. This is how the build
process knows that those dependencies need to be bundled in to the
release. **This includes dependencies of your dependencies, if they were
not properly configured**. For instance, if you depend on `mongoex`, and
`mongoex` depends on `erlang-mongodb`, but `mongoex` doesn't have `erlang-mongodb`
in it's applications list, your app will fail in it's release form,
because `erlang-mongodb` won't be loaded.

If you are running into issues with your dependencies missing their
dependencies, it's likely that the author did not put the dependencies in
the `:application` block of *their* `mix.exs`. You may have to fork, or
issue a pull request in order to resolve this issue. Alternatively, if
you know what the dependency is, you can put it in your own `mix.exs`, and
the release process will ensure that it is loaded with everything else.


## Configuration not working as expected

Due to the way `config.exs` is converted to the `sys.config` file used by
Erlang releases, it is important to make sure all of your config values are
namespaced by application, i.e. `config :myapp, foo: bar` instead of `config foo: bar`,
and access your config via `Application.get_env(:myapp, :foo)`. If you do not
do this, you will likely run into issues at runtime complaining that you are attempting
to access configuration for an application that is not loaded.

## Packaging fails with errors related to `erl_tar`

If your project has files or modules names which exceed the file name length limit of `erl_tar`,
you will see an error like the following:

```
Building release with MIX_ENV=dev.
{{case_clause,
     {'EXIT',
         {function_clause,
             [{filename,join,[[]],[{file,"filename.erl"},{line,393}]},
              {erl_tar,split_filename,4,[{file,"erl_tar.erl"},{line,471}]},
              {erl_tar,create_header,3,[{file,"erl_tar.erl"},{line,400}]},
              {erl_tar,add1,4,[{file,"erl_tar.erl"},{line,323}]},
              {systools_make,add_to_tar,3,
                  [{file,"systools_make.erl"},{line,1879}]},
              {lists,foreach,2,[{file,"lists.erl"},{line,1337}]},
              {systools_make,'-add_applications/5-fun-0-',6,
                  [{file,"systools_make.erl"},{line,1569}]},
              {lists,foldl,3,[{file,"lists.erl"},{line,1262}]}]}}},
 [{systools_make,'-add_applications/5-fun-0-',6,
      [{file,"systools_make.erl"},{line,1569}]},
  {lists,foldl,3,[{file,"lists.erl"},{line,1262}]},
  {systools_make,add_applications,5,[{file,"systools_make.erl"},{line,1568}]},
  {systools_make,mk_tar,6,[{file,"systools_make.erl"},{line,1562}]},
  {systools_make,mk_tar,5,[{file,"systools_make.erl"},{line,1538}]},
  {systools_make,make_tar,2,[{file,"systools_make.erl"},{line,336}]},
  {rlx_prv_archive,make_tar,3,[{file,"src/rlx_prv_archive.erl"},{line,83}]},
  {relx,run_provider,2,[{file,"src/relx.erl"},{line,308}]}]}
==> ERROR: "Failed to build release. Please fix any errors and try again."
```

## Release not starting correctly due to Joken version < 1.2.0

Joken < 1.2.0 causes a deadlock during application load, this affects `start`, `console`
and other commands.

## Release not starting on Vagrant's `/vagrant` mountpoint

When running in Vagrant with source and release dirs under the `/vagrant` directory, you might eed to set RELEASE_MUTABLE_DIR envar to a local path that is not under `/vagrant`

## Release not starting for other reasons - diagnosis

exrm 1.0.4 and later - set `ERL_OPTS="-init_debug"` envvar when running your app.
You can tweak the `myapp.sh` script found inside the versioned directory.

For older versions, edit the startup script (`rel/myapp/releases/1.0.0/myapp.sh`) and edit the ERL_OPTS line to say `ERL_OPTS="-init_debug"`.

## Others

If you run into problems, please create an issue, and I'll address ASAP.
