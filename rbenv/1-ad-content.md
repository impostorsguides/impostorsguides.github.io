Now we move on to the `rbenv.d/` directory.  The first file we'll look at is inside `rbenv.d/exec/`, a `bash` script called `gem-rehash.bash`.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash.bash)

Since I notice that this is file ends in the ".bash" extension, I'm curious where and how the file gets executed.  So the first thing I do is search for the filename "gem-rehash" in the codebase, however I don't see any hard-coded references to this file anywhere in RBENV.

My next step is to Google "gem-rehash.bash", thinking that maybe this filename is part of some Rubygems standard and that there are other libraries with similarly-named files.  But no such luck- the only search results that appear are related to the RBENV library.

One of the search results does catch my eye, however:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-923am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

I decide to open that up.  Inside I look for where "gem-rehash.bash" is referenced:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-924am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

I scan this a bit more closely, and I see "Auditing installed plugins" in the logs that the question references.  This reminds me that we're currently in a directory named "rbenv.d/exec/gem-rehash/", and that "rbenv.d" is one of the directories that is checked for plugins by… which file was it again?

I search for "rbenv.d" in the code, and I find:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-925am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

2 files are ".bats" test files, 1 file is the "test_helper.bash" file, and the last result is the "libexec/rbenv" file.  That's the file which [adds the "rbenv.d" directory](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81) to the "RBENV_HOOK_PATH" environment variable.  Then later, the `rbenv-hooks` file uses `RBENV_HOOK_PATH` to [generate a list of hook files](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks#L55), and then `rbenv-hooks` is subsequently called by multiple other commands ([`rbenv-exec`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L37), [`rbenv-rehash`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash#L159), and others) to actually invoke / source those hook files.

OK, so now that we know how this file is invoked, what does it do?

```
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

This is the only line of code in the file.  Looks like it just:

Accesses a single environment variable named `RUBYLIB`,
Prepends the value of `${BASH_SOURCE%.bash}` to the previous value of `RUBYLIB`, and
Exports the new `RUBYLIB` value.

What is the value of `$BASH_SOURCE` that gets prepended to `RUBYLIB`?  To find out, I update `gem-rehash.bash` to the following:

```
echo "BASH_SOURCE: $BASH_SOURCE"
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

I then open a new terminal tab and run a simple `rbenv exec` command:

```
$ rbenv exec ruby -e '1+1'
BASH_SOURCE: /Users/myusername/.rbenv/rbenv.d/exec/gem-rehash.bash
```

So `BASH_SOURCE` is the name of the file we're running.  As a refresher on what the "%.bash" syntax is, I look up [the docs for bash parameter expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html):

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-930am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

Right, it has to do with trimming off certain patterns.  As an experiment, I try the following in my terminal:

```
bash-3.2$ foo="foobarbaz.bash"

bash-3.2$ echo "${foo%.bash}"

foobarbaz

bash-3.2$ foo="foobarbaz.bash.bash.bash"

bash-3.2$ echo "${foo%.bash}"

foobarbaz.bash.bash

bash-3.2$ foo="foobarbaz.bash.bash.bash.buz"

bash-3.2$ echo "${foo%.bash}"

foobarbaz.bash.bash.bash.buz

bash-3.2$
```

So "${foo%bar}" will trim "bar" from the value of a variable named "foo".  Or in our case, we trim ".bash" off the end of our variable named "BASH_SOURCE".  Since "BASH_SOURCE" equals "/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash.bash", that means we're left with the filename without its extension, or "/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash".

To test this, I update `gem-rehash.bash` to equal the following:

```
echo "RUBYLIB before: $RUBYLIB"
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
echo "RUBYLIB after: $RUBYLIB"
```

When I do the same dummy `rbenv exec` command, I now get:

```
$ rbenv exec ruby -e '1+1'

RUBYLIB before:
RUBYLIB after: /Users/myusername/.rbenv/rbenv.d/exec/gem_rehash:
```

So before, the value of `RUBYLIB` was empty.  Afterwards, it's equal to `/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash:`.  Which makes sense, given that we prepend the modified value of `BASH_SOURCE` to the existing value (i.e. ""), and separate the two with the ":" symbol.

So that's it for this file.  Before closing the `gem-rehash.bash` file, I be sure to remove the two `echo` statements I added.

The only other file in the `rbenv.d` directory is [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash/rubygems_plugin.rb).
