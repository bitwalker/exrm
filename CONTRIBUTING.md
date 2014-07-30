# Contributing To Exrm

I've thrown together the guidelines around how to contribute exrm so it's smooth
sailing for everyone. Please take some time and read through this before creating
a pull request. Your contributions are hugely important to the success of exrm, 
and I appreciate all your help!

- [Issues Tracker](#issues-tracker)
- [Bug Reports](#bug-reports)
- [Feature Requests](#feature-requests)
- [Contributing](#contributing)
- [Pull Requests](#pull-requests)

## Issues Tracker

I use the issues tracker to do the following things:

* **requests for consideration (RFC)** - These are things which I, or you perhaps, am
  soliciting feedback on, in order to flesh out ideas, potential features, or big
  changes. If you have an idea, or a feature you'd like to implement, feel free to
  create issues that fit that definition, and I'll give them the RFC label.
* **[bug reports](#bug-reports)** - Anything you encounter with exrm that is broken or
  is generally bad behavior, create an issue for it, and I'll label it appropriately.
* **[submitting pull requests](#pull-requests)** - If you found and fixed a bug in exrm,
  please submit a PR with your changes! See the link for guidelines on PRs.

All bug reports are given a difficulty classification between `starter` and `advanced`.
This is so anyone can hop in and start pulling bugs off the stack if they wish to get
involved. If you are new to the project, please start with one of the `starter` or
`intermediate` bugs, as most of the stuff classified as `advanced` require intimate
knowledge of exrm's internals. Regardless of level, if it's something you feel you want
to tackle, leave a comment and let me know, and we can discuss it in more detail.

## Bug Reports

A bug is a _demonstrable problem_ that is caused by the code in the repository.

Guidelines for bug reports:

1. **Use the GitHub issue search** &mdash; check if the issue has already been
   reported.

2. **Check if the issue has been fixed** &mdash; try to reproduce it using the
   `master` branch in the repository.

3. **Isolate and report the problem** &mdash; ideally create a reduced test
   case. There are two test projects that are good starting points for this,
   [exrm-test](https://github.com/bitwalker/exrm-test) and 
   [exrm-umbrella-test](https://github.com/bitwalker/exrm-umbrella-test)

Please try to be as detailed as possible in your report. Include information about
your operating system, your Erlang and Elixir versions (i.e. 17.1.2, or 0.14.3).
Provide steps to reproduce the issue as well as the outcome you were expecting. All 
these details will help other developers to find and fix the bug.

Example:

> Short and descriptive example bug report title
>
> A summary of the issue and the environment in which it occurs. If suitable,
> include the steps required to reproduce the bug.
>
> 1. This is the first step
> 2. This is the second step
> 3. Further steps, etc.
>
> `<url>` - a link to the reduced test case (e.g. a GitHub Gist or project repo)
>
> Any other information you want to share that is relevant to the issue being
> reported. This might include the lines of code that you have identified as
> causing the bug, and potential solutions (and your opinions on their
> merits).

## Feature Requests

Feature requests are absolutely welcome, but before you dive in to implementing
an idea, please open up an issue on the tracker as a request for consideration by
creating the title of your issue prefixed with RFC.

Example:

> RFC: Some feature that would be super awesome
>
> A description of the new feature and why it's needed. This should open
> up discussion and provide a starting point for other participants
> to give their thoughts on whether the feature makes sense, what the best
> path to implementation is, etc. If you made code changes to validate your
> idea, link the url so others can look at the work you've done.

Feature requests will be discussed by users of exrm, and the final vote will be made
by me on whether or not it fits within the goals of the project. If there is
strong merit for a feature to be implemented, you can be assured I will be interested
in making it happen.

## Contributing

Exrm is divided into a few major components within the `lib` folder:

- `mix/tasks/release.ex` - This defines the primary release generation task for mix
- `mix/tasks/release.clean.ex` - This defines the cleanup task for mix
- `mix/tasks/release.plugins.ex` - This task allows users to see what active exrm plugins are loaded
- `exrm/plugins/conform.ex` - This exrm plugin handles generating a `sys.config` for a release using conform
- `exrm/plugins/consolidation.ex` - This exrm plugin handles performing protocol consolidation for a release
- `exrm/appups.ex` - This module handles generating `.appup` files for release upgrades.
- `exrm/config.ex` - This module contains the configuration struct containing the state and configuration of the release.
- `exrm/plugin.ex` - This module defines the plugin behavior used by exrm plugins
- `exrm/utils.ex`  - This module provides core utilities for exrm

After your changes are done, please remember to run the full test suite with
`mix test`.

With tests running and passing, and your [documentation](#contributing-documentation) done, your ready to send a PR!

## Contributing Documentation

Please make sure all modules are well documented with a `@moduledoc`, any relevant
`@typedoc`s and all public functions documented with `@doc` and `@spec`. Use examples
where possible (especially in doctest format if it's possible). There may be legacy 
code still in there without these, so if you see them, feel free to make a pull request 
to add more docs!

Example:

```elixir
@doc """
Return only those elements for which `fun` is true.

## Examples

    iex> Enum.filter([1, 2, 3], fn(x) -> rem(x, 2) == 0 end)
    [2]

"""
def filter(collection, fun) ...
```

## Pull requests

Good pull requests - patches, improvements, new features - are a fantastic
help. They should remain focused in scope and avoid containing unrelated
commits.

**IMPORTANT**: By submitting a patch, you agree that your work will be
licensed under the license used by the project.

If you have any large pull request in mind (e.g. implementing features,
refactoring code, etc), **please ask first** otherwise you risk spending
a lot of time working on something that the project's developers might
not want to merge into the project.

Please adhere to the coding conventions in the project (indentation,
accurate comments, etc.) and don't forget to add your own tests and
documentation. When working with git, we recommend the following process
in order to craft an excellent pull request:

1. [Fork](http://help.github.com/fork-a-repo/) the project, clone your fork,
   and configure the remotes:

   ```bash
   # Clone your fork of the repo into the current directory
   git clone https://github.com/<your-username>/exrm
   # Navigate to the newly cloned directory
   cd exrm
   # Assign the original repo to a remote called "upstream"
   git remote add upstream https://github.com/bitwalker/exrm
   ```

2. If you cloned a while ago, get the latest changes from upstream:

   ```bash
   git checkout master
   git pull upstream master
   ```

3. Create a new topic branch (off of `master`) to contain your feature, change,
   or fix.

   **IMPORTANT**: Making changes in `master` is discouraged. You should always
   keep your local `master` in sync with upstream `master` and make your
   changes in topic branches.

   ```bash
   git checkout -b <topic-branch-name>
   ```

4. Commit your changes in logical chunks. Keep your commit messages organized,
   with a short description in the first line and more detailed information on
   the following lines. Feel free to use Git's
   [interactive rebase](https://help.github.com/articles/interactive-rebase)
   feature to tidy up your commits before making them public.

5. Make sure all the tests are still passing.

   ```bash
   mix test
   ```

6. Push your topic branch up to your fork:

   ```bash
   git push origin <topic-branch-name>
   ```

7. [Open a Pull Request](https://help.github.com/articles/using-pull-requests/)
    with a clear title and description.

8. If you haven't updated your pull request for a while, you should consider
   rebasing on master and resolving any conflicts.

   **IMPORTANT**: _Never ever_ merge upstream `master` into your branches. You
   should always `git rebase` on `master` to bring your changes up to date when
   necessary.

   ```bash
   git checkout master
   git pull upstream master
   git checkout <your-topic-branch>
   git rebase master
   ```

Thank you for your contributions!
