This is the file that gets called by [this line of the `rbenv` file](https://github.com/rbenv/rbenv/blob/0767d64344d0c52282125e2e25aa03f4d7a80698/libexec/rbenv#L103){:target="_blank" rel="noopener"} when the user types either `rbenv -v` or `rbenv --version` in their terminal.

As usual, let's look at the tests first:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/--version.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the loading of `test_helper`, the first line of code is:

```
export GIT_DIR="${RBENV_TEST_DIR}/.git"
```

Here we set an environment variable named `GIT_DIR` to equal a “.git” hidden directory inside our test dir.  I don't see any other references to `GIT_DIR` in the RBENV codebase, so I Google it and find that it's mentioned [here](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables){:target="_blank" rel="noopener"} in the Git docs:

> ### Repository Locations
>
> Git uses several environment variables to determine how it interfaces with the current repository.
>
> GIT_DIR is the location of the .git folder. If this isn't specified, Git walks up the directory tree until it gets to ~ or /, looking for a .git directory at every step.

It appears that we use `git` commands several times throughout the tests for `rbenv --version`, so setting this env var is part of the overall setup we need for our tests to pass.

Next block of code:

```
setup() {
  mkdir -p "$HOME"
  git config --global user.name  "Tester"
  git config --global user.email "tester@test.local"
  cd "$RBENV_TEST_DIR"
}
```

This is our `setup` hook function which gets called before the tests are run.  We first create the `$HOME` directory; [according to test_helper.bash](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L19){:target="_blank" rel="noopener"}, this env var resolves to `"${RBENV_TEST_DIR}/home"`.  Next we set two of git's config values- the git user's name and email address.  Lastly, we navigate into our `RBENV_TEST_DIR` as we normally would in the `setup` function.

(stopping here for the day; 93767 words)

Next block of code:

```
git_commit() {
  git commit --quiet --allow-empty -m "empty"
}
```

This is a helper function to make an empty git commit.  Skipping ahead to the command file itself, part of its code uses git commands to pull RBENV's version number using metadata from git, and we'll need this `git_commit` helper function to generate a new git SHA as part of the test setup process.

First test:

```
@test "default version" {
  assert [ ! -e "$RBENV_ROOT" ]
  run rbenv---version
  assert_success
  [[ $output == "rbenv "?.?.? ]]
}
```

We start by asserting that `$RBENV_ROOT` does not exist on our machine.  I'm actually not sure why this check is necessary, since `RBENV_ROOT` does not appear [in the command file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version){:target="_blank" rel="noopener"}.  At first I thought it was a copy/paste mistake, but that seems unlikely because there are no other instances of `assert [ ! -e "$RBENV_ROOT" ]` in this test file, which is where I would expect the copy/paste job to have been taken from.  There's no explanation in [the PR which introduced this test](https://github.com/rbenv/rbenv/commit/ab9ebb9d0ddb440e5546e2eb1d1bf3e483f8b017){:target="_blank" rel="noopener"}, either.  I hate that I have to leave this as an open question, but the only other way I can think of to answer it is by filing an issue on the RBENV repo, and I don't want to waste the core team's time with such a trivial question.

The rest of the test is pretty straight-forward.  We run the `--version` command, assert that it completed successfully, and assert that the value stored in the `$output` variable from `bats` matches the pattern “rbenv ?.?.?”.  Each question mark corresponds to a single character, so we're checking that the printed output starts with “rbenv “ followed by a single character, a period, a single character, another period, and a final single character.  For example, “1.2.0”.  In other words, the typical format of a version number (major, minor, and patch numbers).

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

This test appears to cover [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L18){:target="_blank" rel="noopener"}.  We create a git repo and set its remote equal to the remote git repo of a non-RBENV project (specifically, the Homebrew project).  We make an empty git commit and we tag it with the tag “v1.0”.  When we run the `--version` command, we expect it to finish successfully and for the output to match the same pattern as the last test.

From reading this test, the intent seems to be that we want to run `git remote -v` and expect something like the following to show up:

```
origin	git@github.com:myusername/homebrew.git (fetch)
origin	git@github.com:myusername/homebrew.git (push)
```

Then we want to filter out these two lines, since they show `homebrew.git` as the remote, *not* `rbenv.git`.

To test this, I update the command code from this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-809am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

To this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-810am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

There are 3 sections of the `if` statement on line 18:

`cd "${BASH_SOURCE%/*}" 2>/dev/null`,
`git remote -v 2>/dev/null`, and
`grep -q rbenv;`

The goal with the above code change is to add logging lines after each section, to inspect the result of each section and see whether they do what we think they do.

When I run the current test and `cat` the “result.txt” file, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-811am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

We can see the loglines from inside the first `if` block (loglines 1 and 2) as well as the 2nd `if` block (loglines 3 through 5), but not those from the 3rd `if` block (loglines 6 and 7).  This proves that it is indeed the `| grep -q rbenv;` clause which this test is designed to cover.  Since this clause is falsy, we never reach inside the overall `if` block, we never set the `git_revision` variable, and [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L23){:target="_blank" rel="noopener"} causes the `echo`'ed value to default to the value of the `version` variable, since the `git_revision` variable is empty.  This explains why we match on the pattern `?.?.?`, since that pattern fits the value of `version`.

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

This test is a bit similar to the last one, except this time our remote origin *does* contain “rbenv.git”, so we *will* reach the inside of the `if` conditional and set + use the `git_revision` variable.  In addition to the commit which we tag with “v0.4.1”, we make two more git commits, so that the expected value of `git_revision` will contain both the version number and the number of commits that have happened since the version number was tagged.  We then run the `--version` command and assert that a) it completes successfully, and b) that the printed output contains:

“rbenv”
the version number
the # of commits since the version number, and
the shortened version of the most recent commit SHA

Together, these 4 pieces of information constitute the output of the `git describe --tags HEAD` command that we see in [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L19){:target="_blank" rel="noopener"}.  Note that the “v” from “v0.4.1” is removed by the `#v` syntax from [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L20){:target="_blank" rel="noopener"}.

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

This test is similar to the previous test, except this time we don't tag the repo with a version number.  We'll still reach the inside of [this `if` statement](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L18){:target="_blank" rel="noopener"}, but because there are no tags, the command `git describe --tags HEAD` will be empty, so the `git_revision` variable will be empty as well.  Because of this, the `:-$version` syntax on [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version#L23){:target="_blank" rel="noopener"} causes the parameter expansion to default to the value of the `version` variable, meaning `version`'s value is what gets printed by the `echo` command.  This is why the value of `$output` is expected to match the “?.?.?” pattern.

(stopping here for the day; 94773 words)

With the tests wrapped up, let's look at the code next:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv---version){:target="_blank" rel="noopener"}

The first block of “code” is just the shebang (which we've already seen by now) followed by some comments:

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

The comments tell the user what the intent is of this script file, and how the output is displayed to the user.

Next few lines of code:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

Again, this is code that we've seen elsewhere.  The first line tells bash to exit immediately if an error occurs, and the 2nd line tells bash to read the `$RBENV_DEBUG` environment variable, and to output verbose debugging information if that env var has been set previously.

Next few lines of code:

```
version="1.2.0"
git_revision=""
```

The first line sets a variable named “version” equal to the string “1.2.0”, and sets the variable “git_revision” equal to the empty string.  These variables will be used below.

Next few lines of code:

```
if cd "${BASH_SOURCE%/*}" 2>/dev/null && git remote -v 2>/dev/null | grep -q rbenv; then
  ...
fi
```
Here we attempt to cd into a directory specified by the value of the `$BASH_SOURCE` env var (piping any errors to `/dev/null`), then we try to run `git remote -v` inside that directory (again, piping any errors to `/dev/null`), and then piping the results of the previous `git remote` command to the `grep` command and `grep`ping for the string “rbenv”.  We run “grep” in “quiet” mode for performance reasons (hence the `-q` flag).  After Googling “grep quiet mode”, [the first result I see](https://web.archive.org/web/20230221153703/https://www.oreilly.com/library/view/linux-shell-scripting/9781785881985/3340428d-7fb5-40cb-a044-9fa404916aa5.xhtml){:target="_blank" rel="noopener"} says that the purpose of quiet mode is:

> Sometimes, instead of examining at the matched strings, we are only interested in whether there was a match or not. The quiet option (-q), causes grep to run silently and not generate any output. Instead, it runs the command and returns an exit status based on success or failure. The return status is 0 for success and nonzero for failure.

So this implies that we don't actually care *what* the match for `grep rbenv` is, only whether there *was* a match.  If there wasn't, then the `if` condition returns false, so we don't execute the code inside said condition.

Speaking of which, that code is:

```
  git_revision="$(git describe --tags HEAD 2>/dev/null || true)"
  git_revision="${git_revision#v}"
```

Here we re-initialize the `git_revision` string to the result of either `git describe --tags HEAD 2>/dev/null` as the happy path.  If this happy path has no result, we set “git_revision” equal to the boolean `true`.  We've seen this trick before, and last time we did, the trick was used to ensure that any subsequent length checks return `0` if the happy path code returned empty.

The 2nd line checks whether `git_revision` starts with the letter “v”, and if it does, deletes that “v”.  For example, if the previous command set `git_revision` equal to `v1.2.0`, then this 2nd line of code just trims the `v` off the front, leaving us with `1.2.0`.

I've never used the command `git describe --tags HEAD` before, but I suspect that its job is to pull a tag name (for example, “v1.2.0” from [here](https://github.com/rbenv/rbenv/releases/tag/v1.2.0){:target="_blank" rel="noopener"}), so that on the next line we can trim the “v” from it and be left with “1.2.0” to store in the “git_revision” variable.  I tried to verify that this is what happens by running `git describe –tags HEAD` on the master branch, but that failed:

```
$ git describe --tags HEAD

fatal: No names found, cannot describe anything.
```

I thought maybe I am supposed to checkout a specific tag, so I looked up how to do that [here](https://web.archive.org/web/20220627235231/https://devconnected.com/how-to-checkout-git-tags/){:target="_blank" rel="noopener"}:

> ### Checkout Git Tag
>
> In order to checkout a Git tag, use the “git checkout” command and specify the tagname as well as the branch to be checked out.
>
> `$ git checkout tags/<tag> -b <branch>`
>

I tried just `git checkout tags/v1.2.0` by itself, without the branch name, but that didn't work:

```
$ git checkout tags/v1.2.0

error: pathspec 'tags/v1.2.0' did not match any file(s) known to git
```

Looks like I'll probably need the branch name.  Or, maybe I can just put some tracer statements inside my `rbenv---version` file and see what the branch name is.

Here's how I update that file on my local machine:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-814am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I've added the tracers on lines 18 and 20.  When I `eval` and run `rbenv -v`, I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-815am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I see my first tracer's output, but not my 2nd.  Which means the `if` condition isn't returning true.  I wonder which of the inner conditions is causing the overall `if` condition to be falsy.  I try commenting out the 2nd condition and just checking the first:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-816am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

No change in the tracer output, unfortunately:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-817am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try adding another tracer to just `echo` the value of `$BASH_SOURCE`, and I get `BASH_SOURCE: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv---version`.

So the `git remote -v | grep -q rbenv` line must be returning zero results, which is why we don't enter the `if` block.  And the purpose of `git remote -v` is to show what the remote git server's address is, this line would only return zero results if there was no remote git server, meaning the directory we're in when we run this code is not a git repository.  So then how do we fetch a specific rbenv version to show the user?

The answer is given in the very last line of code in this file:

```
echo "rbenv ${git_revision:-$version}"
```

Here is that `:-` syntax again.  We `echo` the value of `git_revision` if it was populated from the insides of that `if` block we just looked at.  If we never reached the insides of that block, then our value of `git_revision` should still be the empty string that it was initialized to, in which case we use the value of our other variable, `version`, which was initialized to `1.2.0`.

And that's what our `rbenv---version` file does!
