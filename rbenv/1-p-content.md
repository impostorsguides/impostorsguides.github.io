From the README.md file, we see a description for this command:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-904am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

First up- the test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rehash.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_executable() {
  local bin="${RBENV_ROOT}/versions/${1}/bin"
  mkdir -p "$bin"
  touch "${bin}/$2"
  chmod +x "${bin}/$2"
}
```

Here we define a helper function named `create_executable`.  This function gets called in tests further below.  An example of a call to this function is:

```
create_executable "1.8" "ruby"
```

This function creates a local variable named `bin`, and sets it equal to a directory path constructed with the value of `RBENV_ROOT` plus the first argument.  For example, if the value of this env var on my machine is `/Users/richiethomas/.rbenv` and the first argument I supply to the function is `1.8` (as it is above), then `bin` resolves to `/Users/richiethomas/.rbenv/versions/1.8/bin`.  We then make a directory with this name, and make any sub-directories too if they don't already exist.  We then create an empty file in this directory using the 2nd argument to the function (in the case above, the file is named `/Users/richiethomas/.rbenv/versions/1.8/bin/ruby`).  We then modify this new file to make it executable, hence the function name `create_executable`.

(stopping here for the day; 54037 words)

First test in this file:

```
@test "empty rehash" {
  assert [ ! -d "${RBENV_ROOT}/shims" ]
  run rbenv-rehash
  assert_success ""
  assert [ -d "${RBENV_ROOT}/shims" ]
  rmdir "${RBENV_ROOT}/shims"
}
```

As a sanity check, we first assert that the `$RBENV_ROOT/shims` directory does not currently exist.  We then run the `rbenv rehash` command, and assert that it succeeded without any printed output lines.  We also assert that the `$RBENV_ROOT/shims` does now exist, implying that it's the job of `rbenv rehash` to create this dir.  Lastly, as a cleanup step, we remove the newly-created dir.

Next test:

```
@test "non-writable shims directory" {
  mkdir -p "${RBENV_ROOT}/shims"
  chmod -w "${RBENV_ROOT}/shims"
  run rbenv-rehash
  assert_failure "rbenv: cannot rehash: ${RBENV_ROOT}/shims isn't writable"
}
```

Here we again make the same directory, but then change its permissions via `chmod -w`.  The `w` symbol means we're changing the "write" permissions, and the "-" means we're preventing the user from doing the thing that comes after "-".  So we're preventing users (including the programs they execute, such as `rbenv rehash`) from being able to write to this new directory.  After we run `rbenv rehash`, we assert that the program failed and that a specific error message is output which tells the user that the directory is non-writable.

Next test:

```
@test "rehash in progress" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/.rbenv-shim"
  run rbenv-rehash
  assert_failure "rbenv: cannot rehash: ${RBENV_ROOT}/shims/.rbenv-shim exists"
}
```

We start by making the same `/shims` directory that we made in the last 2 tests.  We then create an empty file called `.rbenv-shim`, run `rbenv rehash`, and assert that the program failed and that the error message tells the user that the `.rbenv-shim` file already exists.  Judging by the test description ("rehash in progress"), we can likely deduce that this file is created when the rehash process starts, and is deleted when the process is finished.

Next test:

```
@test "creates shims" {
  create_executable "1.8" "ruby"
  create_executable "1.8" "rake"
  create_executable "2.0" "ruby"
  create_executable "2.0" "rspec"

  assert [ ! -e "${RBENV_ROOT}/shims/ruby" ]
  assert [ ! -e "${RBENV_ROOT}/shims/rake" ]
  assert [ ! -e "${RBENV_ROOT}/shims/rspec" ]

  run rbenv-rehash
  assert_success ""

  run ls "${RBENV_ROOT}/shims"
  assert_success
  assert_output <<OUT
rake
rspec
ruby
OUT
}
```

Here we see the use of the `create_executable` helper function we analyzed at the start of this file.  We create 4 executable files, 2 in the "1.8/" version directory (one file named "ruby" and one named "rake") and 2 in the "2.0/" version directory (one also named "ruby" and one named "rspec").  We then, as a sanity check, assert that there are no existing files within `$RBENV_ROOT/shims` named "ruby", "rake", or "rspec".  We then run the "rehash" command, assert that it was successful.  Lastly, we assert that listing the contents of the `shims/` sub-directory is successful, and that its output includes "rake", "rspec", and "ruby".

Judging by the sanity check and final assertions in this spec, we can deduce that we created the "ruby" file twice (once in each directory) because we wanted to specifically assert that the final output would not include "ruby" twice.

Next test:

```
@test "removes outdated shims" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/oldshim1"
  chmod +x "${RBENV_ROOT}/shims/oldshim1"

  create_executable "2.0" "rake"
  create_executable "2.0" "ruby"

  run rbenv-rehash
  assert_success ""

  assert [ ! -e "${RBENV_ROOT}/shims/oldshim1" ]
}
```

As setup, we make our `shims/` directory and add a file named "oldshim1" to it, which we make executable.  We then create two new executable files in a new directory named "versions/2.0/bin"- one executable named "rake" and the other named "ruby".  When we run `rbenv rehash`, we assert that the command was successful, and that the "oldshim1" file no longer exists.

Next spec:

```
@test "do exact matches when removing stale shims" {
  create_executable "2.0" "unicorn_rails"
  create_executable "2.0" "rspec-core"

  rbenv-rehash

  cp "$RBENV_ROOT"/shims/{rspec-core,rspec}
  cp "$RBENV_ROOT"/shims/{rspec-core,rails}
  cp "$RBENV_ROOT"/shims/{rspec-core,uni}
  chmod +x "$RBENV_ROOT"/shims/{rspec,rails,uni}

  run rbenv-rehash
  assert_success ""

  assert [ ! -e "${RBENV_ROOT}/shims/rails" ]
  assert [ ! -e "${RBENV_ROOT}/shims/rake" ]
  assert [ ! -e "${RBENV_ROOT}/shims/uni" ]
}
```

We create a "versions/2.0/" directory with two executable files, one named "unicorn_rails" and one named "rspec-core".  Next we run the "rehash" command.  We then copy the contents of the "rspec-core" file into three identical files, one named "rspec", one named "rails", and one named "uni".  We update the permissions on all 3 cloned files to make them executable.  We then re-run the "rehash" command and assert it was successful.  Lastly, we assert that the 3 cloned files no longer exist.

I'm actually not sure what the purpose of this spec is.  It doesn't seem to be doing anything different from what the previous spec did.  Perhaps we'll figure it out when we move on to analyzing the command code itself.

Next test:

```
@test "binary install locations containing spaces" {
  create_executable "dirname1 p247" "ruby"
  create_executable "dirname2 preview1" "rspec"

  assert [ ! -e "${RBENV_ROOT}/shims/ruby" ]
  assert [ ! -e "${RBENV_ROOT}/shims/rspec" ]

  run rbenv-rehash
  assert_success ""

  run ls "${RBENV_ROOT}/shims"
  assert_success
  assert_output <<OUT
rspec
ruby
OUT
}
```

As setup, we create two new sub-directories of the "versions" folder, both containing spaces.  We also create one executable file in each new sub-directory.  As a sanity check, we first assert that there are no shims in our `$RBENV_ROOT` folder associated with these new executables.  We then run the "rehash" command and assert it was successful.  Lastly, we run "ls" on our "shims/" folder and assert that a new shim was created for each of the executable files we created in our setup.  This test ensures that even binaries whose parent folder contains spaces can be shim'ed.

Next test:

```
@test "carries original IFS within hooks" {
  create_hook rehash hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
exit
SH

  IFS=$' \t\n' run rbenv-rehash
  assert_success
  assert_output "HELLO=:hello:ugly:world:again"
}
```

I think I'm starting to see what the concept of "hooks" means with respect to RBENV.  When I first encountered this spec, I took the liberty of skipping ahead and looking at the code for the `rehash` command itself, and searching for "hooks" in the code.  I found this:

```
# Allow plugins to register shims.
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks rehash`)
IFS="$OLDIFS"

for script in "${scripts[@]}"; do
  source "$script"
done
```

The above code is executed just before the meat of the `rehash` command, at the very end of the file:

```
install_registered_shims
remove_stale_shims
```

I've seen code like this before, in other files which accept hooks, but I don't think I understood its full purpose until now.  The job of this code is to run any hook code that's registered for the "rehash" command *just before* running the code for "rehash" itself.  That means the job of a hook in RBENV is to let you modify the environment in which a hook is run, i.e. by changing values of environment variables, therefore potentially affecting the way that the command you hook into is run.

If the above is true, that would explain why the current test is written the way that it is.  We first create a hook for the "rehash" command named "hello.bash", which contains the following executable logic:

```
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
exit
```

This hook creates a variable named "hellos" and sets it equal to "hello\tugly world\nagain".  This represents the words "hello", "ugly", "world", and "again", separated by (respectively) a tab character, a space character, and a newline character.  The hook then `echo`s an assignment to a variable called `HELLO`.  This assignment statement sets `HELLO` equal to the above string, however it first splits that string based on whatever the current value of the IFS is, and then prefix each newly-split word with the ":" character before printing it.

[Remember](https://web.archive.org/web/20220814065502/https://unix.stackexchange.com/questions/184863/what-is-the-meaning-of-ifs-n-in-bash-scripting), IFS stands for "internal field separator" and determines which character(s) the shell will use to perform word splitting.

We then run the "rehash" command, ensuring that we set `IFS` equal to the 3 characters we intend to split on (again, the tab char, the space char, and the newline char).  Lastly, we assert that the command ran successfully and that the word-splitting had the intended effect of replacing the single string "hello\tugly world\nagain" with the array of words (hello ugly world again), and prefixing each string in this array with a ":", before joining these words together and printing out a statement which assigns the variable `HELLO` to this newly-joined string.

Next test:

```
@test "sh-rehash in bash" {
  create_executable "2.0" "ruby"
  RBENV_SHELL=bash run rbenv-sh-rehash
  assert_success "hash -r 2>/dev/null || true"
  assert [ -x "${RBENV_ROOT}/shims/ruby" ]
}
```

This test creates a file under "versions/2.0" named "ruby", and then runs "rbenv sh-rehash".  We then assert that the command ran successfully, and that the printed output contained the string:

```
"hash -r 2>/dev/null || true"
```

Lastly, we assert that a shim for our "ruby" executable file was created.

Side note- the "rbenv sh-rehash" command is one we haven't seen before, to my knowledge.  Looks like it has its own file, separate from the "rbenv-rehash" file.  It appears that the only specs for this command are inside the specs for "rbenv-rehash", so we will likely have to analyze the "rbenv-sh-rehash" and "rbenv-rehash" command files together.

Last spec:

```
@test "sh-rehash in fish" {
  create_executable "2.0" "ruby"
  RBENV_SHELL=fish run rbenv-sh-rehash
  assert_success ""
  assert [ -x "${RBENV_ROOT}/shims/ruby" ]
}
```

This spec performs the same set of assertions as our previous test, but with the RBENV shell set to "fish" instead of "bash".

Side note- I notice that we have "rbenv-sh-rehash" specs for "bash" and "fish", but not for "zsh".  zsh is now the default shell for new Macbooks going forward, so perhaps it makes sense to write a spec for zsh as well?

TODO- new PR to write a spec for zsh.

(stopping here for the day; 55662 words)

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash)

The files "rbenv-sh-rehash" and "rbenv-rehash" are related to each other.  Let's analyze #1 first, and then move on to #2.  First lines of code are familiar:

```
#!/usr/bin/env bash
set -e
[ -n "$RBENV_DEBUG" ] && set -x

# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  exec rbenv-rehash --complete
fi
```

The `bash` shebang.
Note- no "Usage" or "Summary" instructions here.  This file is likely meant to be for internal use only.
Setting verbose mode if `RBENV_DEBUG` is set.
Tab completion instructions.

Next line of code:

```
shell="$(basename "${RBENV_SHELL:-$SHELL}")"
```
Here we set the variable `shell` equal to the filename (excluding the bath) of either the value of `RBENV_SHELL`, or (if that doesn't exist) the value of `SHELL` as a default.  The `basename` command takes a string like `/path/to/filename.txt` and returns everything after the last `/` character:

```
$ mkdir -p foo/bar/baz
$ touch foo/bar/baz/buzz
$ basename foo/bar/baz/buzz

buzz
```

Here's the `man` page for more info:

```
BASENAME(1)                                                                  General Commands Manual                                                                 BASENAME(1)

NAME
     basename, dirname – return filename or directory portion of pathname

SYNOPSIS
     basename string [suffix]
     basename [-a] [-s suffix] string [...]
     dirname string [...]

DESCRIPTION
     The basename utility deletes any prefix ending with the last slash '/' character present in string (after first stripping trailing slashes), and a suffix, if given.  The
     suffix is not stripped if it is identical to the remaining characters in string.  The resulting filename is written to the standard output.  A non-existent suffix is
     ignored.  If -a is specified, then every argument is treated as a string as if basename were invoked with just one argument.  If -s is specified, then the suffix is taken
     as its argument, and all other arguments are treated as a string.

     The dirname utility deletes the filename portion, beginning with the last slash '/' character to the end of string (after first stripping trailing slashes), and writes the
     result to the standard output.

...
```

Next lines:

```
# When rbenv shell integration is enabled, delegate to rbenv-rehash,
# then tell the shell to empty its command lookup cache.

rbenv-rehash
```

The first question I have is, what is "rbenv shell integration"?  The first line of the comment says "When rbenv shell integration is enabled,...".  To me, this implies that it's possible that sometimes, shell integration is *not* enabled.  Otherwise, the phrase "when shell integration is enabled" translates to "all the time", in which case it's a superfluous statement.  If that were the case, you could drop that clause entirely and just say "Delegate to rbenv-rehash..." etc.  Therefore, my brain tells me to operate under the assumption that it's possible to either enable or disable shell integration depending on the user's preference.

I `grep` for the string "integration" and I see that it occurs in the `README.md` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-909am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so this confirms my suspicion that the user *does* have the option of not using shell integration.  It also tells us that step 3 of the install process contains more info on shell integration:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-910am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

So since opening a new terminal causes `.zshrc` to be executed (and therefore `eval "$(rbenv init - zsh )" ` to be executed and the `rbenv` shell function to be implemented), the "shell integration" to which the README refers must be a reference to the creation and usage of the `rbenv` shell function.  Perhaps it even refers to all the shell commands (like `rbenv local`, `rbenv global`, etc.) that it exposes.

But how would one use RBENV *without* that function?  I was under the impression that one *had* to use that function; it's part of the install instructions, after all.

The instructions for the `rbenv shell` command say that, if we don't want to use shell integration, we can just set the `RBENV_VERSION` env var ourselves.  But how would that env var be used, if not from the `rbenv` shell function defined in `rbenv-init`?  I thought that function was the gateway to using all of RBENV's Ruby versions, shims, etc.  How would RBENV even read the value of `RBENV_VERSION`, if not from the shell function?

My best guess is that the only remaining value if one *doesn't* install and use the RBENV shell function is that RBENV will still intercept calls that you make to your gem executables, and delegate those calls to the executable for the version of Ruby that you've specified via manually setting `RBENV_VERSION`.  If that's not the case, then there must be something fundamental I'm missing about how RBENV works.  And even if that is the case, I'm still not sure why someone would want to go through all this trouble to avoid using the RBENV shell function and its terminal commands, which seems pretty benign (and even helpful in most cases).

I decide to [search](https://github.com/rbenv/rbenv/search?q=%22shell+integration%22&type=issues) the Github repo's "Commit" and "Issue" histories for "shell integration".  I find [this issue](https://github.com/rbenv/rbenv/issues/1409) containing some additional useful context.  I think it's a pretty good summary of the differences between using RBENV with vs. without shell integration:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-911am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

A couple of the highlights:

> ...shims require no rbenv shell integrations to work—they just want to be present in PATH.
>
> ...it's absolutely possible to use most rbenv functionality without ever enabling its shell integration. This is all that's needed:
>
> `export PATH=~/.rbenv/bin:~/.rbenv/shims:"$PATH"`
>
> Calling most rbenv commands, switching between versions, and executing shims will all work with this approach. Rbenv was intentionally designed to not need shell integrations (unlike RVM).

I feel like this basically confirms my hypothesis that "...RBENV will still intercept calls that you make to your gem executables, and delegate those calls to the executable for the version of Ruby that you've specified via manually setting `RBENV_VERSION`."

But still, why was "RBENV... intentionally designed to not need shell integrations"?  What's so bad about shell integrations that RBENV would intentionally be designed not to need them?

I Google "rbenv vs rvm" and one of the first results I see is [a Reddit thread](https://www.reddit.com/r/rails/comments/f009mb/there_are_two_ruby_version_manager_rvm_vs_rbenv/) comparing the two.  Again, a few highlights:

> I used to use RVM but got bit one too many times by the amount of crap they do to your shell env. Overriding cd is just insane.
>
> They've also been sloppy with escaping shell arguments. Years ago it took out half of my system directory running some command because it didn't escape the shell arguments and I (stupidly, upon reflection and with the benefit of experience) put my home directory on a partition that had a space in the name and it decided to wipe /Volumes/OSX when my home directory was on /Volumes/OSX Users. Apparently not escaping the space and doing rm -fr /Volumes/OSX Users/jay/.rvm/whatever/the/path/was was not a good idea. From then on I learned not to use spaces in paths of important directory structures.
>
> (rvm) always overrides cd, as soon as you source it in. That's how it can automatically switch versions when you cd into a directory with a .ruby-version file.
>
> ...rvm redefines cd into its own function. That's what people mean by being intrusive, it takes over a bunch of core functions
>
> Rvm was created before bundles so it has a bunch of clever hacks that just aren't needed any more. I think it is better to use something designed around modern ruby, like chruby. You don't need to do much more than mess around with PATH and various GEM environment variables these days, chruby does just that and nothing more.
>
> RVM was the cat's meow back in the Ruby 1.8/1.9 days (ca. 2003-2007). A decade or so on (2013-2014), rbenv and ruby-install came out, with far less reliance on antique shell or Ruby versions.

FWIW, that same Reddit thread also has a bunch of interesting info about other manager programs, such as `chruby` and `asdf`:

> `chruby` is the least invasive and most well-designed of the bunch.

> We use asdf. https://asdf-vm.com/#/ You can use it to manage loads of languages. We like it because we use the same tool and file to maintain versions for ruby, node, terraform, python.

> Switched to asdf recently and it really is an incredible tool to manage multiple languages.

> Came here to say the same. I'm a polyglot developer and using a single tool for python, ruby, elixir, and erlang (so far) is extremely convenient.

> I've used RVM for ages. As for why, RVM lets you have multiple gem sets with multiple projects on the same version of ruby. That in itself should be a reason to use it.

OK, so this seems to clear up some of my confusion around why the core team would want to give the user an option to avoid shell shenanigans.

One last thing I'd like to do is run an experiment, where I comment out the `eval "$(rbenv init -)"` from my `.zshrc` beforehand, open up a new shell, and try to do a few different things with gems from different Ruby versions.  This might give me a better feel for how people use RBENV without shell integrations turned on.

First I want to check which file contains the RubyGems executable (aka the `gem` command) when RBENV shell integrations are turned on.  I run `type rbenv` followed by `type gem` in an existing terminal and get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-916am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

So in the already-open shell, `rbenv` is the shell function, `gem` is executed by the RBENV shim, and shell integrations are enabled.

Then I comment out the `eval` line in my `.zshrc`, open up a new terminal tab, and re-run the above commands:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-917am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

In the new shell, with the `eval` line commented-out of `.zshrc`, the `rbenv` executable comes from the file that we analyzed earlier, and shell integrations are not enabled, but the `gem` executable is *still* controlled by the RBENV shim.

Based on this, I think it's safe to say that we've confirmed that the baseline value of installing RBENV is that it can control your gem executables based on your Ruby version, and that the `rbenv` shell function is just the cherry on top of the sundae.

(stopping here for the day; 56804 words)

—------------—------------—------------—------------—------------—------------—------------—------------—----

So `rbenv-sh-rehash` simply delegates to `rbenv-rehash`, but it also clears out the shell's command lookup cache (see below):

```
case "$shell" in
fish )
  # no rehash support
  ;;
* )
  echo "hash -r 2>/dev/null || true"
  ;;
esac
```

Here we inspect the value that we stored in `shell` earlier.  If it's `fish`, we execute a no-op.  Looks like we can't rehash if the user's shell is fish.  If the user's shell is anything else, we `echo` a command that (presumably) the caller of `rbenv-sh-rehash` will execute via `exec`.  This command includes the `hash` builtin, which (per [this page](https://web.archive.org/web/20221004024822/https://www.computerhope.com/unix/bash/hash.htm)) maintains a hash lookup of commands:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-918am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

One question I have is: where is `rbenv-sh-rehash` called from?  I searched the Github repo for the string `sh-rehash`, but I only found the following code (from the test file we previously examined):

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-919am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I search for the earliest commit to this file, and I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-920am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

There's not much of a description for this PR, but I do see there's [a linked issue](https://github.com/rbenv/rbenv/issues/119) included.

As a last-ditch effort, I try searching the codebase for "sh-", and I find the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-921am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

That's right- there was some "sh-" code in `rbenv-init`!  Refreshing my memory via a look into that file, I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-922am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Right, so here is where `rbenv sh-rehash` gets called.  If we remember, we check whether the command that the user passed to `rbenv` is one of the two commands inside the `commands` array (i.e. `rehash` or `shell`).  If it is, we execute the code on line 170.  If it's not, we execute line 172.

I'm still confused why we need to call `eval` in one case and `command` in another.  Maybe on line 170 it's somehow necessary to replace the current process with the new process the way `eval` is known to do?  Regardless, this makes me think I've now answered a question I asked awhile ago, i.e. why it was necessary to prefix the `rehash` and `shell` commands with `sh`.  And I *suspect* the answer is because the way those scripts are executed depends on which shell the user is using.  If we're writing a script whose behavior depends on shell commands that vary from one shell to another, we can prefix the filename containing that conditional logic with `sh-` so that current and future devs know that.

To confirm this theory, I hypothesize that any RBENV command which needed to suss out the user's shell would need to store that shell name in a variable assignment before it could execute `if/else` logic on that shell name.  So I search for the string "shell=" in the RBENV codebase.  The Github search function doesn't distinguish between searching for "shell=" and searching for the word "shell" by itself, so I get a bunch of false positives.  The only files which actually contain "shell=" and are *not* BATS (aka test) files are `rbenv-sh-rehash`, `rbenv-sh-shell`, and `rbenv-init`.  Coincidentally, those are also the only 3 files which contain the string `case "$shell"`.  I think I finally solved the mystery of the `sh-` filename prefix!

Question: why can't we support fish for rehashing?

OK, moving on to "rbenv-rehash".  First lines of code:

```
#!/usr/bin/env bash
# Summary: Rehash rbenv shims (run this after installing executables)

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

`bash` shebang
"Summary" remarks
`set -e` tells `bash` to exit immediately on first error
`set -x` tells `bash` to print more verbose output, in this case only if the `RBENV_DEBUG` environment variable was set.

Next block of code:

```
SHIM_PATH="${RBENV_ROOT}/shims"
PROTOTYPE_SHIM_PATH="${SHIM_PATH}/.rbenv-shim"

# Create the shims directory if it doesn't already exist.
mkdir -p "$SHIM_PATH"
```

Here we create two new string variables, and use the first of them to make a new directory if it doesn't already exist.  This new directory will hold RBENV's shims.

Next block of code:

```
# Ensure only one instance of rbenv-rehash is running at a time by
# setting the shell's `noclobber` option and attempting to write to
# the prototype shim file. If the file already exists, print a warning
# to stderr and exit with a non-zero status.
set -o noclobber
{ echo > "$PROTOTYPE_SHIM_PATH"
} 2>| /dev/null ||
{ if [ -w "$SHIM_PATH" ]; then
    echo "rbenv: cannot rehash: $PROTOTYPE_SHIM_PATH exists"
  else
    echo "rbenv: cannot rehash: $SHIM_PATH isn't writable"
  fi
  exit 1
} >&2
set +o noclobber
```

(stopping here for the day; 57862 words)

Luckily there's a detailed comment which explains the purpose of the code below.  That said, I still want to look up some of the syntax being used here.

First off:

```
set -o noclobber
```

This turns on the bash `noclobber` option.  According to [this link](https://web.archive.org/web/20210615041918/https://howto.lintel.in/protect-files-overwriting-noclobber-bash/), `noclobber` option "prevents you from overwriting existing files with the > operator.  If the redirection operator is `>`, and the noclobber option to the set builtin has been enabled, the redirection will fail if the file whose name results from the expansion of word exists and is a regular file. If the redirection operator is `>|`, or the redirection operator is `>` and the noclobber option is not enabled, the redirection is attempted even if the file named by word exists."

OK, that's pretty clear.  Setting `noclobber` implies that we'll be attempting to write to a new file, but we don't want to do that if this file already exists.  We'll find out which file that is on the next line of code, which is:

```
{ echo > "$PROTOTYPE_SHIM_PATH"
} 2>| /dev/null ||
```

First off, the curly brace groups (i.e. `{ ....} ... { ... }`.  This is apparently called "output grouping", [according to Linux.com](https://web.archive.org/web/20220606055633/https://www.linux.com/topic/desktop/all-about-curly-braces-bash/).  According to them, "...you can also use `{ ... }` to group the output from several commands into one big blob."  An example here:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-923am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

So we're just grouping the output of the commands inside the curly braces, and redirecting *all* their output to the destination immediately following the closing curly braces (i.e. `2>| /dev/null` and `>&2` respectively; more on that later).

Inside the first set of braces, we create a new file with the name "$PROTOTYPE_SHIM_PATH", which on my machine resolves to `/Users/richiethomas/.rbenv/shims/.rbenv-shim`.  If that command produces any error output, we redirect it to `/dev/null`.  And if that command fails, we use the `||` syntax to do what follows on the subsequent lines of code (see below).

I noticed the use of `echo > <filename>` here, rather than `touch <filename>`, which I thought was the canonical command that is used to create a new, empty file.

From [this StackExchange link](https://web.archive.org/web/20210817014146/https://unix.stackexchange.com/questions/530555/creating-a-file-in-linux-touch-vs-echo), I see that the difference between "echo >" vs. "touch" is that "touch" will create the file if it doesn't already exist, or update the file's "created_at" and "updated_at" timestamps if it does exist.  In contrast, both "echo >" and "echo >>" will create a file if it doesn't exist.  "echo >" will overwrite the file if it does exist, while "echo >>" will append to the file if it exists.

Based on this info, I think what's happening here is that, with the `noclobber` option set, `echo >` will throw an error if the file exists.  That's what we want to happen, because we're using the file as an indicator that the `rehash` action is in-progress.  The combination of `set -e`, `set -o noclobber`, and `echo > <filename>` means that the script will attempt to create a new file, but if the file already exists, the script will throw an error and then exit.  That achieves the behavior of preventing more than one `rehash` from being performed at once, since presumably we'll delete the file when we're done.

The `2>| /dev/null` code just sends any error output to `/dev/null`.  I search [this link](https://web.archive.org/web/20221005093039/https://www.gnu.org/software/bash/manual/html_node/Redirections.html) for the string `>|`, and I find the following info:

> If the redirection operator is `>`, and the noclobber option to the set builtin has been enabled, the redirection will fail if the file whose name results from the expansion of word exists and is a regular file. If the redirection operator is `>|`, or the redirection operator is `>` and the noclobber option is not enabled, the redirection is attempted even if the file named by word exists.

So the `|` character at the end has the effect of forcing the overwrite to go through, even if `noclobber` is set.  I initially thought the reason for `2>|` here was because we previously set `noclobber` would mean that we wouldn't be able to redirect error output to `/dev/null`, since that file already exists.  However, I try sending output to `/dev/null` with `noclobber` turned on, and I am successful in doing so:

```
$ set -o noclobber

$ echo "foo" > /dev/null

$
```

I see the expected error when I try to overwrite a regular, non `/dev/null` file:

```
$ set -o noclobber

$ echo "foo" > /dev/null

$ touch bar.txt

$ echo "foo" > bar.txt

zsh: file exists: bar.txt

$
```

So I'm a bit stumped on why I'm able to overwrite `/dev/null` even with `noclobber` turned on.  I get why `/dev/null` would be treated differently (because the purpose of `/dev/null` is to allow shell programmers to get rid of unneeded output by redirecting it to a "black hole"), but I didn't see that mentioned in the `noclobber` section of [this docs page](https://web.archive.org/web/20221005093039/https://www.gnu.org/software/bash/manual/html_node/Redirections.html) (section 3.6.2), so I assumed it was undocumented.  [I post a StackExchange question](https://unix.stackexchange.com/questions/720024/is-dev-null-treated-differently-from-other-files-when-the-noclobber-option), and eventually the answer comes back that yes, in fact, `/dev/null` is treated differently by `noclobber`.

Moving on to the next block of code (i.e. what happens after the `||` characters):

```
{ if [ -w "$SHIM_PATH" ]; then
    echo "rbenv: cannot rehash: $PROTOTYPE_SHIM_PATH exists"
  else
    echo "rbenv: cannot rehash: $SHIM_PATH isn't writable"
  fi
  exit 1
} >&2
```

If the previous attempt at creating the new file fails, we check whether the `SHIM_PATH` directory is writable.  If it is, we assume that the failure resulted because the file already exists.  If it's not writable, we echo a different error message to that effect.  Either way, we exit with a non-zero return status.  Whichever error message we `echo`, we redirect that message to STDERR via `>&2`.

Next line of code:

```
set +o noclobber
```

Here we just turn off the `noclobber` option that we turned on before we attempted to create the `PROTOTYPE_SHIM_PATH` file.

Next block of code:

```
# If we were able to obtain a lock, register a trap to clean up the
# prototype shim when the process exits.
trap remove_prototype_shim EXIT

remove_prototype_shim() {
  rm -f "$PROTOTYPE_SHIM_PATH"
}
```
Here we invoke the `trap` command, which I'm unfamiliar with.  After reading [the docs](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_12_02.html), it appears that `trap` lets the user execute arbitrary code when the shell receives one or more specified signals.  In this case, we're telling the shell to call the `remove_prototype_shim` function whenever it receives an EXIT signal (i.e. whenever the process exits, [whether normally or abnormally](https://web.archive.org/web/20220621051014/https://www.putorius.net/using-trap-to-exit-bash-scripts-cleanly.html)).  That function is defined on the next few lines of code, and it force-deletes the temporary `.rbenv-shim` file that's created.  So this is the clean-up functionality we hypothesized about before, where the file is deleted so that subsequent calls to `rbenv rehash` can once again be made.

Next block of code:

```
# Locates rbenv as found in the user's PATH. Otherwise, returns an
# absolute path to the rbenv executable itself.
rbenv_path() {
  local found
  found="$(PATH="$RBENV_ORIG_PATH" command -v rbenv)"
  if [[ $found == /* ]]; then
    echo "$found"
  elif [[ -n "$found" ]]; then
    echo "$PWD/${found#./}"
  else
    # Assume rbenv isn't in PATH.
    local here="${BASH_SOURCE%/*}"
    echo "${here%/*}/bin/rbenv"
  fi
}
```

(stopping here for the day; 58997 words)

This block creates a function named `rbenv_path`.  Inside that function body, we create a local variable named `found`.  We then tell the shell to search `$RBENV_ORIG_PATH` (not `$PATH`) for the filepath of the command `rbenv`, and we set the `found` variable equal to the filepath that is returned.  On my machine, this resolves to `/usr/local/bin/rbenv`.

If this `found` value starts with `/` (i.e. if the found path is an absolute path starting from the machine's root directory), then the return value of the `rbenv_path` function is the value of `found`.

If that condition doesn't pass, we next check whether `found` was set to any non-empty value.  If it was, then we make an assumption that the executable was found in the current directory, so we shave any "./" off the beginning of `found`, and prepend it with the full path to the current directory (via the `$PWD` variable).  We then make that newly-constructed path the return value for this function.

Lastly, if that 2nd condition also fails, we fall back to looking in RBENV's `BASH_SOURCE` directory, or rather that directory's `/bin/rbenv` sub-directory.  On my machine, the returned value in this case would be `/usr/local/Cellar/rbenv/1.2.0/bin/rbenv`, which is actually quite close to what it would have been before this `rbenv_path` function was added to the codebase (see below).

### Tangent- Why `$RBENV_ORIG_PATH` and not `$PATH`?

I was confused about why this `$RBENV_ORIG_PATH` variable was needed, when it seemed like `$PATH` would be the less-surprising choice.  I pulled up [the PR](https://github.com/rbenv/rbenv/pull/1350) which introduced this line of code to find the answer.  If I'm correct in interpreting that PR's description, it looks like the previous way of creating RBENV gem shims included a reference to the `rbenv` executable.  But if that executable was installed by the dependency management tool Homebrew, then the path to that `rbenv` executable would include Homebrew's version #, i.e. `/usr/local/Cellar/rbenv/<HOMEBREW VERSION>/bin/rbenv`.  That hard-coded path in the shim file would work fine as long as the user didn't upgrade their Homebrew version.  But as soon as they *did* upgrade, Homebrew would apparently delete the old directory (that's how I interpret the reference to "Homebrew's auto-cleanup functionality" in the PR description), and that shim would break along with any others with that hard-coded path.

This PR was introduced to fix that problem.  Previously, `rbenv rehash` would cause the shim to run:

```
exec "/usr/local/Cellar/rbenv/<HOMEBREW VERSION>/libexec/rbenv" exec "$program" "$@"
```

I know this because I changed the code in `rbenv-rehash` from [this PR](https://github.com/rbenv/rbenv/pull/1350/files) back to its original version, and re-ran `rbenv rehash` to see what shim would be generated.  After this PR's change, the new line of code (at least, in my case) becomes:

```
exec "/usr/local/bin/rbenv" exec "$program" "$@"
```

This `/usr/local/bin/rbenv` file is a symlink to the `..Cellar/rbenv/<HOMEBREW VERSION>/bin/rbenv` file, but pointing to a symlink is fine since Homebrew will (I'm hoping?) update that symlink as part of its version update process.

But the question remains- why did we need to change `PATH` as part of this code:

```
found="$(PATH="$RBENV_ORIG_PATH" command -v rbenv)"
```

To find out, I added the following log statements to `rbenv-rehash`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1035am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we print out what the value of `$PATH` is under the new system (aka `found`), and what it would have been under the old system (aka `found2`).  I also printed what the old path would have been (aka `PATH: $found2`), and what the new path is (aka `PATH2: $RBENV_ORIG_PATH`).  I did this so we could see which directories `command -v` will search in order to find the `rbenv` executable.

When I ran `rbenv rehash` in a new terminal, I saw the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1036am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

With the new value of `PATH`, the first executable `rbenv` file that `command -v` finds is in `/usr/local/bin` (highlighted below):

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1037am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

So that's the path to the `rbenv` executable that it uses inside the shim logic.  However, with the old `PATH`, the first executable it finds is in `/usr/local/Cellar/rbenv/1.2.0/libexec/`, which it finds here:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1038am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Even though `/usr/local/bin` exists in the old `PATH` value, `/usr/local/Cellar/rbenv/1.2.0/libexec/` comes before it in the search of folders, so that's what `command -v` finds first, and that's what ends up getting used.

<div style="border-bottom: 1px solid grey; margin: 3em;"></div>

Next block of code:

```
# The prototype shim file is a script that re-execs itself, passing
# its filename and any arguments to `rbenv exec`. This file is
# hard-linked for every executable and then removed. The linking
# technique is fast, uses less disk space than unique files, and also
# serves as a locking mechanism.
create_prototype_shim() {
  cat > "$PROTOTYPE_SHIM_PATH" <<SH
#!/usr/bin/env bash
set -e
[ -n "\$RBENV_DEBUG" ] && set -x
program="\${0##*/}"
if [ "\$program" = "ruby" ]; then
  for arg; do
    case "\$arg" in
    -e* | -- ) break ;;
    */* )
      if [ -f "\$arg" ]; then
        export RBENV_DIR="\${arg%/*}"
        break
      fi
      ;;
    esac
  done
fi
export RBENV_ROOT="$RBENV_ROOT"
exec "$(rbenv_path)" exec "\$program" "\$@"
SH
  chmod +x "$PROTOTYPE_SHIM_PATH"
}
```

This block of code creates a shell function which, when called, `cat`s a multi-line string to the temporary `.rbenv-shim` file, and makes that file executable.  That multi-line string consists of the commands that we analyzed in [this document](https://docs.google.com/document/d/1xG_UdRde-lPnQI7ETjOHPwN1hGu0KqtBRrdCLBGJoU8/edit?usp=sharing), so we won't rehash that analysis here.  Suffice to say that the shim calls `rbenv exec <program>`, passing any arguments.  This ensures that we're running the version of that program, given our current Ruby version.

Next block of code:

```
# If the contents of the prototype shim file differ from the contents
# of the first shim in the shims directory, assume rbenv has been
# upgraded and the existing shims need to be removed.
remove_outdated_shims() {
  local shim
  for shim in "$SHIM_PATH"/*; do
    if ! diff "$PROTOTYPE_SHIM_PATH" "$shim" >/dev/null 2>&1; then
      rm -f "$SHIM_PATH"/*
    fi
    break
  done
}
```

(stopping here for the day; 60016 words)

The comments here give us a great idea of what's going on.  In this function definition, we compare each file in `SHIM_PATH` with the prototype shim.  The `diff` shell command will output any difference between two files, as we can see here:

```
$ echo a > foo.txt

$ echo a > bar.txt

$ diff foo.txt bar.txt

$ echo b > bar.txt

$ diff foo.txt bar.txt

1c1
< a
---
> b

```

In our function, we check the following condition:

```
! diff "$PROTOTYPE_SHIM_PATH" "$shim" >/dev/null 2>&1;
```

There are 3 things going on inside this `if` check:

 - We run `diff "$PROTOTYPE_SHIM_PATH" "$shim"` to check the diff between two files.  If there is no diff, then the command's exit code will be 0.  If there is a diff, the command's exit status is 1.  We can see an example of that here, where ["$?" is shorthand for the return value of the most recently-executed command](https://web.archive.org/web/20220923100726/https://linuxhint.com/bash-exit-code-of-last-command/):

```
$ echo a > foo.txt

$ echo b > bar.txt

$ echo a > baz.txt

$ diff foo.txt baz.txt

$ echo "$?"

0

$ diff foo.txt bar.txt

1c1
< a
---
> b

$ echo "$?"

1

```

 - We add a `!` in front of this check to negate the result.  So if there is no diff, the "truthy" 0 return code becomes "falsy", and a "falsy" 1 return code becomes "truthy".  More info on how `bash` responds to exit codes in `if` statements can be found [here](https://web.archive.org/web/20220922164846/https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html).
We send any regular STDOUT output to /dev/null via `>/dev/null`, and we send any STDERR output to STDOUT via `2>&1`.

 - If we reach the code inside the `if` check, we know that the shell has found a shim file which doesn't match our prototype.  Since the prototype represents the latest version of the shim file, we can conclude that the shim we've found is an older version of the prototype shim, meaning it is out-of-date and can be deleted.  We further assume that if one shim in the `SHIM_PATH` is out of date, they all are.  It's not like the shim we've found could possibly be *more* recent than our prototype, so there's no harm in deleting them all and rebuilding them using the prototype file.  So that's what we do, via the `rm -f "$SHIM_PATH"/*` command.

The last line of code in this `for` loop is a `break` statement.  Something's confusing here- the `break` statement is *outside* the `for`-loop.  My expectation is that, as soon as we find a shim that differs from the prototype, we `rm -f` the entire `SHIM_PATH` directory and then immediately `break` out of the for-loop.  But we should *only* break out of the `for`-loop *if* we find a mismatch between files.  The way the code is currently written, it appears that we `break` out of the loop *even if we don't* find a mismatch, since the break is outside the `if` check.  Am I reading that right?  Is that what's actually happening here?

To test this, I do an experiment.

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1053am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Here I do the following:

 - I create a prototype file containing the character "a",
 - I make a directory named `shims` with 4 text files, 3 of which match the prototype and one of which does not.
 - I then paste an identical `remove_outdated_shims` function into the shell, with only some extra loglines and a counter variable added.
 - I increment the counter before every run and log the count # to the screen.  To perform this increment, I use the "let" syntax, described more [here](https://web.archive.org/web/20220930062328/https://linuxize.com/post/bash-increment-decrement-variable/).
 - Lastly, I call the function in the terminal with the appropriate env var values set for `$SHIM_PATH` and `PROTOTYPE_SHIM_PATH`.

As I thought, the counter only outputs once, and we never see the `about to delete all shims` logline, meaning we didn't reach the shim whose contents differ from the prototype.  Unless I'm completely missing something, this *might* be a bug in the code.

I create [a PR for this issue](https://github.com/rbenv/rbenv/pull/1452) and after awhile I get the response that (as I suspected) the placement of the `break` is a performance optimization.  It turns out that it is in fact safe to assume that if the first shim is the same as the prototype, then all of them are.  Furthermore, the functions which appeared to be unused were in fact kept in place for reasons of backwards compatibility with 3rd-party plugins.

In retrospect, I feel kind of bad about the length of the description I wrote in this PR.  It's... admittedly very long.  RBENV is a major open-source project, and it's maintained by a handful of people, only one of whom seems to be responding to most of the pull requests.  My process is pretty methodical and detail-oriented, and at the time I felt like I had to walk through that thought process in similar detail, in order to communicate how I reached my conclusions.  But I need to remember that when I write a long description like this, I'm placing a non-trivial burden on the core team to read and grok what I'm saying.  Their mental bandwidth is likely already taxed by the burdens of maintaining the project plus their work and life obligations.  Part of the obligation of submitting a PR is boiling down the proposal to as small of a description as possible, so as to minimize the extra work the core team has to do in order to give it a thumbs-up or -down.

OK, lesson learned.

Next block of code:

```
# List basenames of executables for every Ruby version
list_executable_names() {
  local version file
  rbenv-versions --bare --skip-aliases | \
  while read -r version; do
    for file in "${RBENV_ROOT}/versions/${version}/bin/"*; do
      echo "${file##*/}"
    done
  done
}
```

This block implements a function called `list_executable_names`.  Its body creates two local variables, called `version` and `file`.  We then call `rbenv-versions –bare –skip-aliases` and pipe the results to the next line of code.  The `--bare` flag strips out the `system` version and the extra information (such as the source file of the Ruby version setting) which is normally displayed when the flag is not passed.  And the `--skip-aliases` flag ensures that the folders that we use to derive our Ruby versions don't contain any aliases.  We then pipe the list of versions from that output to the `read` command, create a `while` loop with a local variable called `version` for each version output by `rbenv-versions`, iterate over each of the shim files in that version directory, and print out just the filename of the shim.  This "for loop inside a while loop" effectively prints out every shim in every Ruby version that RBENV knows about.  We can prove this by adding some `echo` statements to this function and running `rbenv rehash`.

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1054am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

The results when we run the command are too long to embed in this page, but can be found [here](/assets/images/screenshot-16mar2023-1056am.png){:target="_blank" rel="noopener"}.

TODO- get a larger, higher-res image for the above.

As you can see, we have 3 sets of gems for the 3 versions of Ruby installed on my machine:

```
$ rbenv versions --bare --skip-aliases

2.7.5
3.0.0
3.1.0
```

Next block of code:

```
# The basename of each argument passed to `make_shims` will be
# registered for installation as a shim. In this way, plugins may call
# `make_shims` with a glob to register many shims at once.
make_shims() {
  local file shim
  for file; do
    shim="${file##*/}"
    registered_shims+=("$shim")
  done
}
```

I noticed that this function is actually something which was added back in 2011, but whose function call was subsequently removed.  So initially I thought this was an orphan function that doesn't get used at all.  However, I subsequently learned from the PR I linked above that these functions are kept in place for backwards compatibility reasons with plugins.

This function makes two local variables, one named `file` and one named `shim`.  It then iterates over each of the arguments provided to the function (remember, `for file; do` is short for `for file in "$@"; do`).  For each argument (which seems to correspond to a filepath), we shave off everything except the filename itself, to get the name of the shim.  We then add that shim name to an array of other shim names.

One new thing that we might be able to learn from this is the `registered_shims+=("$shim")`.  `registered_shims` is an array of strings, and here we're adding a new item to that array.  This is something we've never needed to do until now.  Here's a stripped-down example in my terminal:

```
bash-3.2$ foo=(1 2 3 4 5)

bash-3.2$ echo "${foo[@]}"

1 2 3 4 5

bash-3.2$ foo+=(6)

bash-3.2$ echo "${foo[@]}"

1 2 3 4 5 6
```

So to create an array, you wrap the items with parentheses and separate them with spaces.  To concatenate something to the end of that array, you do a simple `+=` operation and pass the new value, which is also wrapped in parens.

Next block of code:

```
# Registers the name of a shim to be generated.
register_shim() {
  registered_shims+=("$1")
}
```

This appeared to be another orphan function, which does the exact same thing we just discussed in the previous block of code.

Next block of code:

```
# Install all the shims registered via `make_shims` or `register_shim` directly.
install_registered_shims() {
  local shim file
  for shim in "${registered_shims[@]}"; do
    file="${SHIM_PATH}/${shim}"
    [ -e "$file" ] || cp "$PROTOTYPE_SHIM_PATH" "$file"
  done
}
```

(stopping here for the day; 61035 words)

This new function has a similar setup to the `make_shims` function above, but there is a difference.  It creates two local variables, but then instead of iterating over the arguments to the function, it iterates over the array of previously-registered shims.  Here, "registered" appears to mean any shim whose name has been added to the `registered_shims` array.  That can happen via either the `register_shim` or the `make_shims` functions, or (further down) [line 155](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash#L155), which sets the list of shims based on the return value of the `list_executable_names` function.

For each of these registered shims, we create a filepath for that shim in the correct directory (`SHIM_PATH`), and then we check if that file exists.  If it doesn't, we create it by duplicating the prototype file and giving the duplicate the name of our new filepath.

Next block of code:

```
# Once the registered shims have been installed, we make a second pass
# over the contents of the shims directory. Any file that is present
# in the directory but has not been registered as a shim should be
# removed.
remove_stale_shims() {
  local shim
  local known_shims=" ${registered_shims[*]} "
  for shim in "$SHIM_PATH"/*; do
    if [[ "$known_shims" != *" ${shim##*/} "* ]]; then
      rm -f "$shim"
    fi
  done
}
```

The goal of this function is to remove files which point to un-registered shims from `SHIM_PATH`.  This is a clean-up step after the installation process has finished.  We create two local variables, one named `shim` and one named `known_shims`.  We set `known_shims` equal to the return value of the `list_executable_names` function, which we discovered was the stringified name of each shim in each of RBENV's version directories.  Then for each shim in `SHIM_PATH`, we see if that shim's name is included in the list of known shims.  If it's not, we delete it from the filesystem.

Next line of code:

```
shopt -s nullglob
```

As we've seen before, this line sets the `nullglob` option, so that a pattern which doesn't match any files to expand to an empty string, rather than itself.  This is useful when iterating over any and all files in a directory, as we've done in some of the functions we've looked at in this file.

Next block of code:

```
# Create the prototype shim, then register shims for all known
# executables.
create_prototype_shim
remove_outdated_shims
```

Here's where we call the function that creates and populates the contents of the `.rbenv-shim` file, the prototype which is then used to create all the actual shims.  We also call the function which checks whether the shims are out-of-date (via the `diff` command), and removes them if they are.

Next block of code:

```
# shellcheck disable=SC2207
registered_shims=( $(list_executable_names | sort -u) )
```

Here we populate the `registered_shims` list based on the executable contents of each of RBENV's version directories, and sorts the results.  We also remove any duplicate entries, so that if a shim appears in more than one version directory, we remove the duplicate(s).  This saves us time when checking the existing shim files against known shims.

If a gem exists in one of these directories, it's considered "registered".

We also disable [this shellcheck rule here](https://www.shellcheck.net/wiki/SC2207).  This shellcheck rule is designed to This prevents the shell "...from doing unwanted splitting and glob expansion, and therefore avoid(s) problems with output containing spaces or special characters."  It looks like there are two reasons why someone might do this (according to the exceptions listed [here](https://www.shellcheck.net/wiki/SC2207#exceptions)).  The first exception is for when you as the programmer have explicitly set up word splitting according to your requirements, which we don't appear to have done in this file.  Therefore I'm guessing our reason for disabling shellcheck here is related to exception #2, which mentions error handling.  It appears that the `mapfile` utility which shellcheck wants you to use would not raise the needed error if it failed, but we might need an error to be explicitly raised so the user could be alerted that something has gone wrong.

Next block of code:

```
# Allow plugins to register shims.
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks rehash`)
IFS="$OLDIFS"

for script in "${scripts[@]}"; do
  source "$script"
done
```

We've seen this pattern before.  We pull any hook files for the `rehash` command using `rbenv-hooks rehash`, taking care to split the output of that command correctly based on the anticipated `\n` delimiter, and then re-set IFS back to its original value afterward.  We then iterate over this array of hook filepaths, and source each one.

Last block of code for this file:

```
install_registered_shims
remove_stale_shims
```

Here we call the function which creates a new shim file for each registered shim (if one doesn't already exist), and the function which removes any file in `SHIM_PATH` if it doesn't correspond to one of our registered shims.  And that's the end of the file!

After the failure of my last PR and the feedback I received (that the supposedly "disused" functions are kept in place to be backwards-compatible with hooks and plugins), I finally feel motivated enough to try and build a hook of my own, as well as a plugin of my own.  And since we're wrapping up this file, now might be a good time to do it.  I think I can do so by:

Creating a source-able file in each of the directories that the `rbenv` main file checks for hooks, and
Running `rbenv env` every time to see which env vars are available.

(stopping here for the day; 62056 words)

The first thing I do is go into [the `rbenv` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv) to refresh my memory of how the hook paths are loaded into the shell.  [Here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L86) we see that we construct `RBENV_HOOK_PATH` by concatenating several directories into a single, colon-delimited string.  And [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks#L55) we see `RBENV_HOOK_PATH` being used to populate the `hook_paths` variable in `rbenv-hooks`.  That new variable, in turn, is searched for files that match the pattern `"$path/$RBENV_COMMAND"/*.bash`.  Those bash script filepaths are then `echo`'ed to STDOUT.  For example, if one of the paths in our `RBENV_HOOK_PATHS` env var is `/usr/local/etc/rbenv.d/`, and we're searching for `rehash`-related hooks, then we echo the filepaths of all files ending in ".bash" inside the directory `/usr/local/etc/rbenv.d/rehash/`.   Lastly, [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash#L159) we see that the `echo`'ed filepaths are stored in a variable, which is then iterated over, and each filepath is `source`ed into the shell.

I check whether the `/usr/local/etc/rbenv.d/` directory currently exists.  It does not, so I create it as well as the `rehash` subdirectory inside it.  Then I create a bash script named `hello.bash`, and inside it I add the following code;

```
>&2 echo "Hello world!"
```

Then, I open a new terminal window and type `rbenv rehash`.  I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1103am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so this is a working proof-of-concept on how to get `rbenv rehash` to execute hook-related code.  Now I'm wondering what the possibilities are.  What does this power enable us to do?

One thing we could do is print out all the env vars and functions available to us from within our hook.  I delete the "Hello world!" line and replace it with:

```
>&2 rbenv env
>&2 echo "---------------------------------------------"
>&2 declare -F
```

The `rbenv env` command comes from [this plugin](https://github.com/ianheggie/rbenv-env/), which I believe we examined in an earlier section.  According to [TLDP](https://web.archive.org/web/20220824230731/https://tldp.org/LDP/abs/html/declareref.html), the `declare -f` command is the `bash` way of listing all the functions we have available to us:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1105am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

When I re-run `rbenv rehash`, I now see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1106am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we see all the RBENV-specific environment variables available to us, as well as all the functions that we saw defined in the `rbenv-rehash` file.

As a test, I tried copying the `rehash` directory that we created into a new folder, named after a different command which also exposes itself to hooks.  That command is `which`.  I found this command by searching for `rbenv-hooks` in the Github repo.

I had expected to see a similar result, albeit with different `declare -f` functions (and perhaps even different environment variables, if `which` declares any such env vars in its script).  But that's not exactly what happened.  Instead, I see an invite loop occur, where opening up a new terminal tab causes the tab to hang without showing an input prompt.  Eventually I discover that commenting out the first line of `which/hello.bash` stops the infinite loop from occurring:

```
# >&2 rbenv env
>&2 echo "---------------------------------------------"
>&2 declare -F
```

As we know, the `rbenv` command gets called by `rbenv init` in my `.zshrc` file, which is initialized by zsh when I open a new tab.  That `rbenv` file, in turn, sources all the plugins, including my `rbenv-env` plugin.  That plugin, in turn, calls `rbenv-which` [here](https://github.com/ianheggie/rbenv-env/blob/042e9ff/bin/rbenv-env#L21).  Finally, `rbenv-which` calls the `rbenv` shell function, which calls the `rbenv` file, which creates the infinite loop.

OK, so if I uninstall `rbenv env`, then we likely won't have this infinite loop problem anymore.  But if I uninstall that plugin, I will no longer have access to the RBENV-specific env vars that we might need to build some actual functionality into our hook.

But do I really need `rbenv-env` to get those RBENV-specific env vars?  I see [this line here](https://github.com/ianheggie/rbenv-env/blob/042e9ff/bin/rbenv-env#L28) which looks like it does what we want:

```
/usr/bin/env | egrep '^GEM|^RBENV|^RUBY|^RAILS|^PATH=|^NODE_|^NODENV_|^NPM_'
```

But why is everything before that needed?  Can we just copy/paste that one line of code into our hook, instead of using the `rbenv-env` hook?  Let's try it.  I update `hello.bash` to include the above line of code:

```
>&2 echo $(/usr/bin/env | egrep '^GEM|^RBENV|^RUBY|^RAILS|^PATH=|^NODE_|^NODENV_|^NPM_')
>&2 echo "---------------------------------------------"
>&2 declare -F
```

I initially did not wrap the `/usr/bin/env |...` command with `echo $(...)`, but I noticed that my `declare -F` functions weren't being printed out, nor was the `-------` line.  I guessed that this was because running the `egrep` command directly causes the shell to exit immediately when the command is finished, similar to how `exec` works.

I change my code slightly:

```
>&2 IFS=" " foo=$(echo $( /usr/bin/env | egrep '^GEM|^RBENV|^RUBY|^RAILS|^PATH=|^NODE_|^NODENV_|^NPM_' ) )
for envvar in "${foo[@]}"; do
  >&2 echo "$envvar"
done
>&2 echo "---------------------------------------------"
>&2 declare -F
```

I store the results of the `echo | egrep` operation in an array, making sure to set `IFS` to the space character (since I noticed that the env vars on my last attempt were separated by a single space).  Then I iterate over the array and print out each env var separately.  I then get the following for `rbenv rehash`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1107am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Is this the same thing I got with `rbenv env` instead of the script from my last attempt?

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1108am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

No, it's not.  There are env vars in the `rbenv env` output which don't appear in my attempted script.  And this is actually expected, because one of the things that the `rbenv env` script does is *set env vars directly*, for example [here](https://github.com/ianheggie/rbenv-env/blob/042e9ff/bin/rbenv-env#L13) and [here](https://github.com/ianheggie/rbenv-env/blob/042e9ff/bin/rbenv-env#L25).  That explains why the `PATH` variable is different, and why `RBENV_VERSION` appears in `rbenv-env`'s output, but not in mine.

OK, so now that we know what data and functions are available to us, what can we do with this knowledge?  Can we, for example, alter the behavior of a gem's shim in a meaningful way?

(stopping here for the day; 63063 words)

The code that executes the `rehash` hooks runs just before the `install_registered_shims` and `remove_stale_shims` functions.  So those hooks have the power to influence what happens inside those two functions, by altering the env vars (such as `SHIM_PATH` and `PROTOTYPE_SHIM_PATH`) and variables (such as `registered_shims`) that those functions depend on.

Since `PROTOTYPE_SHIM_PATH` is what's used to create a shim, one thing I could presumably do is reset `PROTOTYPE_SHIM_PATH` to an entirely new shim path, dump an entirely new shim script there, and cause all shims to be created in the image of my new hotness instead of the old and busted.

I re-write the entire `hello.bash` hook so it looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1109am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

I added line 22 as an example of arbitrary code that we could execute inside the updated shim.  It just `echo`s a statement to the terminal before running the invoked gem.  But if I can get this to happen, then I could potentially do much more.  For example, I could do what lines 8-20 do, which is check whether a specific program is being run.  If it is, I execute code to log the user's keystrokes going forward, before allowing the original program to continue.

The only other line I added was line 29, to remove the outdated shims.  This function was already called once, but now that I've updated the contents of `PROTOTYPE_SHIM_PATH`, I want to run it again so as to update *all* the shims to execute this new code.  This way I won't have to manually delete a specific gem's shim in order to trigger the update.

I happen to know from my earlier explorations that one of the gems installed on my machine is called `bluepill`.  I'm guessing it's either a direct or indirect dependency of the Rails app that my employer's web application is built on, but it doesn't really matter how it got here.  What matters is whether our new code works!

I type "vim `which bluepill`", and I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1110am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Yep, there's my new code on line 19!

And when I run `bluepill --help`, I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-1111am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

You can see on the first line, right after the command I typed, is the text output from our updated shim!

Cool, so now we've made a hook which successfully interacts with our gems!

From here, the possibilities are really endless.  As we discussed, you could update the shims in a gem-specific manner, checking whether a specific gem is being run before executing code.  Or you could do what we did, and execute that code every time, for every gem.  It's up to you- get creative!

I'm feeling a lot better about hooks and plugins now, certainly much better than before we started looking at this file.  Before we move on, I make sure to delete the directory I created, including the `hello.bash` hook.

What's next?
