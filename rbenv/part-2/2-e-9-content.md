Next line of code is:

```
shopt -s nullglob
```

## Pattern-matching on filepaths

In my Bash shell, I type `help shopt`, and get the following:

```
$ help shopt
shopt: shopt [-pqsu] [-o long-option] optname [optname...]
    Toggle the values of variables controlling optional behavior.
    The -s flag means to enable (set) each OPTNAME; the -u flag
    unsets each OPTNAME...

    With no options, or with the -p option, a list of all
    settable options is displayed, with an indication of whether or
    not each is set.
```

So we're enabling some optional behavior here.  That behavior is controlled by the `nullglob` option.  I Google "shopt nullglob", and find [the GNU documentation page for `shopt`](https://web.archive.org/web/20230323025605/https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html){:target="_blank" rel="noopener" }.

```
nullglob

If set, Bash allows filename patterns which match no files to expand to a
null string, rather than themselves.
```

Lastly, [StackExchange](https://unix.stackexchange.com/a/504591/142469){:target="_blank" rel="noopener" } has an example of what would happen before and after `nullglob` is set:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.
>
> ```
> $ echo my*file
> my*file
> $ shopt -s nullglob
> $ echo my*file
>
> $
> ```

This code sets a shell option so that we can change the way we pattern-match when we're iterating over a list of filepaths.  If a pattern doesn't match any files in the directory we're searching, the pattern will expand to the empty string.  This will prevent us from trying to access a file which doesn't exist, potentially raising an error and causing our script to terminate.

### Experiment- testing the behavior of `nullglob`

I write a script to try and emulate what we see in the `for` loop above:

```
#!/usr/bin/env bash

for plugin_dir in "$PWD"/foo/*; do
  echo "plugin_dir: $plugin_dir"
done
```

When I create a directory with a few subdirectories and run this test script, I get:

```
$ mkdir foo
$ mkdir foo/bar
$ mkdir foo/baz
$ mkdir foo/buzz
$ ./script
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/bar
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/baz
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/buzz
```

So far, that's what I expected.  But what if there are no directories?  I delete the three sub-directories and re-run it:

```
$ rm -r foo/bar
$ rm -r foo/baz
$ rm -r foo/buzz
$ ./script
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/*
```

OK, this makes sense, given that I didn't run that `shopt` line first.  If I add that to my script:

```
#!/usr/bin/env bash

shopt -s nullglob

for plugin_dir in "$PWD"/foo/*; do
  echo "plugin_dir: $plugin_dir"
done
```

...and re-run it, I get:

```
$ ./script

```

No output when `shopt -s nullglob` is set.  So setting `shopt -s nullglob` means that, if there are no filepaths or directory paths which match the given pattern, we make zero iterations in our `for` loop.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>


I'm curious whether there's any explanation for this block of code in the Github history, so I dig into the git history using my `git blame / git checkout` dance again.  There's only one issue and one commit.  [Here's the issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener" } with its description:

> The purpose of this branch is to provide a way to install self-contained plugin bundles into the $RBENV_ROOT/plugins directory without any additional configuration. These plugin bundles make use of existing conventions for providing rbenv commands and hooking into core commands.
>
> ...
>
> Say you have a plugin named foo. It provides an `rbenv foo` command and hooks into the `rbenv exec` and `rbenv which` core commands. Its plugin bundle directory structure would be as follows:
>
>```
>foo/
>  bin/
>    rbenv-foo
>  etc/
>    rbenv.d/
>      exec/
>        foo.bash
>      which/
>        foo.bash
>```
>
> When the plugin bundle directory is installed into `~/.rbenv/plugins`, the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH` and `~/.rbenv/plugins/foo/etc/rbenv.d/exec:~/.rbenv/plugins/foo/etc/rbenv.d/which` to `$RBENV_HOOK_PATH`.

This explains not only the `shopt` line, but the next few lines after that.

## Checking for plugins

Next few lines of code are:

```
bin_path="$(abs_dirname "$0")"
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
export PATH="${bin_path}:${PATH}"
```

It's a bit harder to read when written this way, since `bin_path` is not used inside the subsequent `for` loop.  Let's re-arrange it to make things easier:

```
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done

bin_path="$(abs_dirname "$0")"
export PATH="${bin_path}:${PATH}"
```

### Adding plugins to `PATH`

Looking at the code for the `for` loop:

```
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
```

[The above Github issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener" } posited a world where we have an RBENV plugin named `foo`.  It exposes a command named `rbenv foo`.  When the GH issues says:

```
...the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH`...
```

...it's telling us that we'll be able to call `rbenv-foo`, because the `rbenv-foo` file is located in `~/.rbenv/plugins/foo/bin`, a folder which is now being added to `PATH`.

Since this takes place inside a `for` loop which iterates over the contents of `"${RBENV_ROOT}/plugins/"*/bin;`, this is true not only for `foo`, but for any plugins which are installed within `"${RBENV_ROOT}/plugins/"`.

Referring back to this code:

```
shopt -s nullglob
```

The StackExchange post from earlier said:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.

I suspect that, with the `nullglob` option turned on, the pattern `"${RBENV_ROOT}/plugins/"*/bin;` expands to nothing **if no plugins are installed**.  So turning this option on means our `for` loop will iterate 0 times if the `plugins/` directory is empty.

### Adding `libexec/` to `PATH`

Next let's address these two lines:

```
bin_path="$(abs_dirname "$0")"
export PATH="${bin_path}:${PATH}"
```

Here we're finally calling the `abs_dirname` function we defined in the `if/else` block earlier.

On my machine, `bin_path` resolves to `/Users/myusername/.rbenv/libexec` when I `echo` it to the screen.  By adding this path to our `PATH` variable, we're implying that one or more files inside `/libexec` should be executable, since [the purpose of the `PATH` env var](https://web.archive.org/web/20230321223814/https://en.wikipedia.org/wiki/PATH_(variable)){:target="_blank" rel="noopener" } is to:

> ...specify a set of directories where executable programs are located.

The `libexec/` folder contains both the file we're looking at now (`rbenv`) and the other rbenv command files (`libexec/rbenv-version`, `libexec/rbenv-help`, etc.).  So by adding `libexec/` to `PATH`, we're indicating that one or more of the commands in `libexec/` are meant to be executable.

Let's move onto the next block of code.
