# Upgrades/Downgrades

## How to perform hot upgrades and downgrades!

Note: This documentation assumes you've done an initial deployment to `/tmp` per the Deployment docs. I would suggest starting there just to make sure you understand the prerequisites.

**Important**: In order to build upgradable releases, you need to have the previous release available in `rel`. Without it, the appup script can not be generated.
There are various approaches to storing the contents of `rel` (git, use a single build server, S3, etc.), but the important part is that you pick one. 
When you are about to build a new release, make sure the previous release is available to the build (under `rel`), and you'll be good to go!

So you've made some changes to your app, and you want to generate a new release and perform a hot upgrade. I'm here to tell you that this is going to be a breeze, so I hope you're ready (I'm using my test app as an example here again):

1. `mix release`
2. `mkdir -p /tmp/test/releases/0.0.2`
3. `cp rel/test/releases/0.0.2/test.tar.gz /tmp/test/releases/0.0.2/`
4. `cd /tmp/test`
5. `bin/test upgrade "0.0.2"`

Annnnd we're done. Your app was upgraded in place with no downtime, and is now running your modified code. You can use `bin/test remote_console` to connect and test to be sure your changes worked as expected.

You can also provide your own .appup file, by writing one and placing it in
`rel/<app>.appup`. This location is checked before generating a new
release, and will be used instead of autogenerating an appup file for
you. If you don't know what an appup file is, it is effectively the file which describes how the upgrade will be performed. To learn more about what goes in this file and how appups work, please consult the Erlang documentation for appups, which is located [here](http://www.erlang.org/doc/design_principles/appup_cookbook.html).

## Downgrading Releases

This is even easier! Using the example from before:

1. `cd /tmp/test`
2. `bin/test downgrade "0.0.1"`

All done!
