This is the file that gets called by [this block of the `rbenv` file](https://github.com/rbenv/rbenv/blob/0767d64344d0c52282125e2e25aa03f4d7a80698/libexec/rbenv#L103-L104){:target="_blank" rel="noopener"} when the user types either `rbenv -v` or `rbenv --version` in their terminal.

As we've done before, we'll start with the tests first:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/--version.bats){:target="_blank" rel="noopener"}

The first two lines are:

```
#!/usr/bin/env bats

load test_helper
```

We've seen these two lines before- the `bats` shebang and the loading of the `test_helper` file.  We'll see these in every test file we read, so this will be the last time we include them in the read-through of a set of tests.

### Setting `GIT_DIR`

After these two lines, the first line of code is:

```
export GIT_DIR="${RBENV_TEST_DIR}/.git"
```

Here we set an environment variable named `GIT_DIR` to equal a ".git" hidden directory inside our test dir.  I don't see any other references to `GIT_DIR` in the RBENV codebase, so I Google it and find that it's mentioned [here](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables){:target="_blank" rel="noopener"} in the Git docs:

> ### Repository Locations
>
> Git uses several environment variables to determine how it interfaces with the current repository.
>
> GIT_DIR is the location of the .git folder. If this isn't specified, Git walks up the directory tree until it gets to ~ or /, looking for a .git directory at every step.

It appears that we use `git` commands several times throughout the tests for `rbenv --version`, so setting this env var is part of the overall setup we need for our tests to pass.

### Test Setup

Next block of code:

```
setup() {
  mkdir -p "$HOME"
  git config --global user.name  "Tester"
  git config --global user.email "tester@test.local"
  cd "$RBENV_TEST_DIR"
}
```

This is our `setup` hook function which gets called [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L87){:target="_blank" rel="noopener"}, before the tests are run.

Inside the test, we first create the `$HOME` directory.  [According to test_helper.bash](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L19){:target="_blank" rel="noopener"}, this env var resolves to `"${RBENV_TEST_DIR}/home"`.

Next, we set two of git's config values- the git user's name and email address.  Lastly, we navigate into our `RBENV_TEST_DIR`.

### Defining the `git_commit()` helper function

Next block of code:

```
git_commit() {
  git commit --quiet --allow-empty -m "empty"
}
```

This is a helper function to make an empty git commit.

Skipping ahead to the command file itself, part of its code uses git commands to pull RBENV's version number using metadata from git.  So that we have some fake git metadata to work with, we'll occasionally call this `git_commit` helper function in our tests.

### Fetching the default version

First test:

```
@test "default version" {
  assert [ ! -e "$RBENV_ROOT" ]
  run rbenv---version
  assert_success
  [[ $output == "rbenv "?.?.? ]]
}
```

We start by asserting that `$RBENV_ROOT` does not exist on our machine.  Since `RBENV_ROOT` does not appear [in the command file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version){:target="_blank" rel="noopener"}, it's not immediately apparent why we do this.  There's no explanation in [the PR which introduced this test](https://github.com/rbenv/rbenv/commit/ab9ebb9d0ddb440e5546e2eb1d1bf3e483f8b017){:target="_blank" rel="noopener"}, either.

I suspect this is happening because part of running `rbenv --version` is running the `rbenv` file, which includes [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54-L59) here.  We likely assert that `RBENV_ROOT` is empty because, if it weren't, the non-default version of RBENV that `RBENV_ROOT` pointed to could be using an unexpected version number, and therefore our test would have unexpected output.  We want `RBENV_ROOT` to be set to the default value by the `rbenv` command, thereby making our version number easy to predict.

The rest of the test is pretty straight-forward.  We run the `--version` command, assert that:

 - the command completed successfully, and
 - the value stored in the `$output` variable from `bats` matches the pattern `rbenv ?.?.?`.

Each question mark in the pattern corresponds to a single character, so we're checking that the printed output starts with "rbenv " followed by a single character, a period, a single character, another period, and a final single character.  For example, `1.2.0`.  In other words, the typical format of a version number (major, minor, and patch numbers).

### Reading the correct version number, regardless of current git directory

Next test:

```
@test "doesn't read version from non-rbenv repo" {
  git init
  git remote add origin https://github.com/homebrew/homebrew.git
  git_commit
  git tag v1.0

  run rbenv---version
  assert_success
  [[ $output == "rbenv "?.?.? ]]
}
```

This test appears to cover [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L18){:target="_blank" rel="noopener"}.  The code does the following:

 - We `cd` into `${BASH_SOURCE%/*}`, which on my machine resolves to `/Users/myusername/.rbenv/test/../libexec` or simply `/Users/myusername/.rbenv/libexec`.
 - We run `git remote -v`, which (in the above directory on my machine) returns:

```
origin	https://github.com/rbenv/rbenv.git (fetch)
origin	https://github.com/rbenv/rbenv.git (push)
```

 - We pipe the results of the `git remote` command to `grep -q rbenv` (note that the `-q` flag stands for "quiet mode", according to `man grep`, which causes the terminal to suppress normal output).

If the exit codes for each of those commands is `0`, then we reach the inside of the `if` block.  Otherwise, the block is skipped.

In our test, we do the following:

 - We create a git repo and set its remote equal to the remote git repo of a non-RBENV project (specifically, the Homebrew project),
 - We make an empty git commit and we tag it with the tag "v1.0".

When we run the `--version` command, we expect it to finish successfully and for the output to match the same pattern as the last test, i.e. the format `?.?.?` (NOT the `v1.0` that we tagged our git repo with).

If we look up [the git history of this test](https://github.com/rbenv/rbenv/commit/dcca61c0bc9747a8886bf7a1d790d902c2426ed0){:target="_blank" rel="noopener"}, we see it was introduced to avoid pulling the viersion number directly from the git repo if the RBENV installation came from an installation source such as Homebrew (i.e., if it wasn't installed by pulling down the Github repo).

### Reading the version number from the git repo

Next test:

```
@test "reads version from git repo" {
  git init
  git remote add origin https://github.com/rbenv/rbenv.git
  git_commit
  git tag v0.4.1
  git_commit
  git_commit

  run rbenv---version
  assert_success "rbenv 0.4.1-2-g$(git rev-parse --short HEAD)"
}
```

This test is a bit similar to the last one, except this time our `remote origin` output *does* contain `rbenv.git`, so we *will* reach the inside of the `if` conditional, and therefore set the `git_revision` variable.

In addition to the commit which we tag with "v0.4.1", we make two more git commits, so that the expected value of `git_revision` will contain both the version number and the number of commits that have happened since the version number was tagged.

We then run the `--version` command and assert that:

 - it completes successfully, and
 - that the printed output contains:
    - the string "rbenv"
    - the version number (aka `0.4.1`)
    - the # of commits since the version number (aka `2`), and
    - the shortened version of the most recent commit SHA (aka the output of `git rev-parse --short HEAD`)

Together, these 4 pieces of information constitute the output of the `git describe --tags HEAD` command that we see in [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L19){:target="_blank" rel="noopener"}.  Note that the "v" from "v0.4.1" is removed by the `#v` syntax from [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L20){:target="_blank" rel="noopener"}.

### Printing the default version if no git tags are found

Last test:

```
@test "prints default version if no tags in git repo" {
  git init
  git remote add origin https://github.com/rbenv/rbenv.git
  git_commit

  run rbenv---version
  [[ $output == "rbenv "?.?.? ]]
}
```

This test is similar to the previous test, except this time we don't tag the repo with a version number.

We'll still reach the inside of [this `if` statement](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L18){:target="_blank" rel="noopener"}, because the output of `git remote -v` contains the string `rbenv`.  But because there are no tags, the command `git describe --tags HEAD` will be empty, so the `git_revision` variable will be empty as well.

Because of this, the `:-$version` syntax on [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L23){:target="_blank" rel="noopener"} causes the parameter expansion to default to the value of the `version` variable, meaning `version`'s value is what gets printed by the `echo` command.  This is why the value of `$output` is expected to match the "?.?.?" pattern.

With the tests wrapped up, let's look at the code next.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version){:target="_blank" rel="noopener"}

The first block of "code" is just the shebang (which we've already seen by now) followed by some comments:

```
#!/usr/bin/env bash
# Summary: Display the version of rbenv
#
# Displays the version number of this rbenv release, including the
# current revision from git, if available.
#
# The format of the git revision is:
#   <version>-<num_commits>-<git_sha>
# where `num_commits` is the number of commits since `version` was
# tagged.
```

The comments tell the user that the intent is of this script file is to display `the version number of this rbenv release, including the current revision from git, if available.`

### Exiting upon first error, and setting debug mode

Next few lines of code:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

Again, this is code that we've seen elsewhere.  The first line tells bash to exit immediately if an error occurs, and the 2nd line tells bash to read the `$RBENV_DEBUG` environment variable, and to output verbose debugging information if that env var has been set previously.

### Setting the default version number

Next few lines of code:

```
version="1.2.0"
git_revision=""
```

The first line sets a variable named "version" equal to the string "1.2.0", and sets the variable "git_revision" equal to the empty string.  These variables will be used below.

### Checking if RBENV has a `git remote` value

Next few lines of code:

```
if cd "${BASH_SOURCE%/*}" 2>/dev/null && git remote -v 2>/dev/null | grep -q rbenv; then
  ...
fi
```

Here we do the following:

 - We attempt to cd into a directory specified by the value of the `$BASH_SOURCE` env var (piping any errors to `/dev/null`).
 - We try to run `git remote -v` inside that directory (again, piping any errors to `/dev/null`).
 - We pipe the results of the previous `git remote` command to the `grep` command and `grep`ping for the string "rbenv" in quiet mode (i.e. passing the `-q` flag).

 After Googling "grep quiet mode", [the first result I see](https://web.archive.org/web/20230221153703/https://www.oreilly.com/library/view/linux-shell-scripting/9781785881985/3340428d-7fb5-40cb-a044-9fa404916aa5.xhtml){:target="_blank" rel="noopener"} says that the purpose of quiet mode is:

> Sometimes, instead of examining at the matched strings, we are only interested in whether there was a match or not. The quiet option (-q), causes grep to run silently and not generate any output. Instead, it runs the command and returns an exit status based on success or failure. The return status is 0 for success and nonzero for failure.

So this implies that we don't actually care *what* the match for `grep rbenv` is, only whether there *was* a match.  If there wasn't, then the `if` condition returns false, so we don't execute the code inside said condition.

### Setting a non-default RBENV version if a tag was found

However, if our directory *does* have a git remote which matches `rbenv`, we execute the following code:

```
  git_revision="$(git describe --tags HEAD 2>/dev/null || true)"
  git_revision="${git_revision#v}"
```

Here we set the `git_revision` string to the either:

 - the result of `git describe --tags HEAD 2>/dev/null` as the happy path, or (if this happy path has no result),
 - to the boolean `true`.  We've seen this trick before, and last time we did, the trick was used to ensure that any error raised by the code before `||` didn't trigger an exit of the process, due to the `set -e` at the top of the file.

The 2nd line simply deletes any `v` character at the beginning of the version value.  For example, if the previous command set `git_revision` equal to `v1.2.0`, then this 2nd line of code just trims the `v` off the front, leaving us with `1.2.0`.

I've never used the command `git describe --tags HEAD` before, but I know I'll only be able to use it if I'm inside a `git` repo.  Since I installed my RBENV code from source for the purposes of these posts, I know I can simply navigate to `cd ~/.rbenv` and run the above command:

```
$ cd ~/.rbenv

$ git describe --tags HEAD

v1.2.0-16-gc4395e5
```

I get `v1.2.0-16-gc4395e5` as my version number.  Which, by the way, is the same output I get if I simply run `rbenv --version`:

```
$ rbenv --version

rbenv 1.2.0-16-gc4395e5
```

Note that, if I had installed RBENV via Homebrew or another source, `git_revision` would have retained its original value of `""`, and (as we'll see on the next line of code) we would have fallen back to the default value stored in `$version`.

### Printing the RBENV version

Next line of code:

```
echo "rbenv ${git_revision:-$version}"
```

Here is where the `rbenv` prefix before the version number comes from.

After the `rbenv` prefix, we `echo` the value of `git_revision` if it was populated from the insides of that `if` block we just looked at.  If we never reached the insides of that block, then our value of `git_revision` should still be the empty string that it was initialized to, in which case we use the value of our other variable, `version`, which was initialized to `1.2.0`.

And that's what our `rbenv---version` file does!
