

Next few lines of code are:

```
shopt -s nullglob

bin_path="$(abs_dirname "$0")"
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
export PATH="${bin_path}:${PATH}"
```

Let's address these two lines first:

```
bin_path="$(abs_dirname "$0")"
...
export PATH="${bin_path}:${PATH}"
```

On my machine, `bin_path` resolves to `/Users/myusername/.rbenv/libexec` when I `echo` it to the screen.  By adding this path to our `PATH` variable, we're implying that one or more files inside `/libexec` should be executable, since (I believe) that's what the `PATH` directory is for.

The `libexec/` folder contains both the file we're looking at now (`rbenv`) and the other rbenv command files (`libexec/rbenv-version`, `libexec/rbenv-help`, etc.).  Skipping ahead to the end of the file, I suspect the reason we're adding `libexec/` to `PATH` is because, later on, we call [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L127){:target="_blank" rel="noopener"}:

```
exec "$command_path" "$@"
```

I added an `echo` statement to this line of code, so I can tell you that `$command_path` resolves to the filename of the command you pass to `rbenv`.  For example, if you run `rbenv help` in your terminal, then `$command_path` resolves to `rbenv-help`.  And when we `exec rbenv-help`, we're able to run that file, since `libexec/` is now in our `PATH`.

Now onto the middle part of the above code, the `for` loop:

```
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
```

[The above Github issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener"} posited a world where we have an RBENV plugin named `foo`.  It exposes a command named `rbenv foo`.  When the GH issues says:

```
...the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH`...
```

...it's telling us that this process (and any child processes) will be able to call `rbenv-foo`, because the `rbenv-foo` file is located in `~/.rbenv/plugins/foo/bin`, a folder which is now being added to `PATH`.

Since this takes place inside a `for` loop which iterates over the contents of `"${RBENV_ROOT}/plugins/"*/bin;`, this is true for any plugins which are installed within `"${RBENV_ROOT}/plugins/"`.

And the reason for `shopt -s nullglob`?  Remember what the StackExchange post said:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.

I suspect that, with the `nullglob` option turned on, the pattern `"${RBENV_ROOT}/plugins/"*/bin;` expands to nothing **if no plugins are installed**.  So turning this option on means our `for` loop will iterate 0 times if the `plugins/` directory is empty.

I decide to do an experiment to see if I'm right.

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

No output when `shopt -s nullglob` is set.  Based on this experiment, I think we can safely say that our hypothesis is correct.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

This appears to add `${RBENV_ROOT}/rbenv.d` to the end of the current value of `RBENV_HOOK_PATH`.  But what is "${RBENV_ROOT}/rbenv.d"?  I run `find . -name rbenv.d` and get:

```
$ find . -name rbenv.d
./rbenv/rbenv.d
```

I inspect it, and see that it's a directory, containing a directory named `exec`:

```
$ ls -la rbenv/rbenv.d
total 0
drwxr-xr-x   3 myusername  staff   96 Sep  5 15:47 .
drwxr-xr-x  15 myusername  staff  480 Sep  5 09:13 ..
drwxr-xr-x   4 myusername  staff  128 Sep  4 10:13 exec
```

The `exec` directory, in turn contains the following:

```
$ ls -la rbenv/rbenv.d/exec
total 8
drwxr-xr-x  4 myusername  staff  128 Sep  4 10:13 .
drwxr-xr-x  3 myusername  staff   96 Sep  5 15:47 ..
drwxr-xr-x  3 myusername  staff   96 Sep  4 10:13 gem-rehash
-rw-r--r--  1 myusername  staff   47 Sep  4 10:13 gem-rehash.bash
```
And the `gem-rehash` directory contains the following:

```
$ ls -la rbenv/rbenv.d/exec/gem-rehash
total 8
drwxr-xr-x  3 myusername  staff    96 Sep  4 10:13 .
drwxr-xr-x  4 myusername  staff   128 Sep  4 10:13 ..
-rw-r--r--  1 myusername  staff  1427 Sep  4 10:13 rubygems_plugin.rb
```

I Google "gem-rehash", and the first thing I find is [this deprecated Github repo](https://github.com/rbenv/rbenv-gem-rehash){:target="_blank" rel="noopener"}.  The description says:

> Never run rbenv rehash again. This rbenv plugin automatically runs rbenv rehash every time you install or uninstall a gem.
>
> This plugin is deprecated since its behavior is now included in rbenv core.

I notice that:

 - The deprecated repo contains a file named `rubygems_plugin.rb`, just like our `rbenv/rbenv.d/exec/gem-rehash` directory does.
 - The deprecated repo contains a file named `etc/rbenv.d/exec/~gem-rehash.bash`, which is very similar (but not identical) to the `rbenv.d/exec/gem-rehash.bash` file that we saw in the RBENV repo above.

In the `rbenv-gem-rehash` README file, I also see the following:

> rbenv-gem-rehash consists of two parts: a RubyGems plugin and an rbenv plugin.
>
> The RubyGems plugin hooks into the gem install and gem uninstall commands to run rbenv rehash afterwards, ensuring newly installed gem executables are visible to rbenv.
>
> The rbenv plugin is responsible for making the RubyGems plugin visible to RubyGems. It hooks into the rbenv exec command that rbenv's shims use to invoke Ruby programs and configures the environment so that RubyGems can discover the plugin.

Based on this, I think we can now determine the reason for this line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

The reason is that we don't want to re-run the `rbenv rehash` command every time we install a new Ruby gem.  We want RBENV to do that for us, automatically.  The way it does that is by hooking into the Rubygems `gem install` and `gem uninstall` commands.  And the way it hooks in is by updating `RBENV_HOOK_PATH`.

### The `.d` extension

We've seen `rbenv.d` a few times now, and I thought the `.d` looked funny.  It looks like a file extension, but it's being used on a directory.  Furthermore, I don't know what I'm supposed to infer from that `.d`.

I Google 'what does ".d" stand for bash', and the first result I see is ([this](https://web.archive.org/web/20220619172419/https://unix.stackexchange.com/questions/4029/what-does-the-d-stand-for-in-directory-names){:target="_blank" rel="noopener"}:

> The .d suffix here means directory. Of course, this would be unnecessary as Unix doesn't require a suffix to denote a file type but in that specific case, something was necessary to disambiguate the commands (/etc/init, /etc/rc0, /etc/rc1 and so on) and the directories they use (/etc/init.d, /etc/rc0.d, /etc/rc1.d, ...)
>
> This convention was introduced at least with Unix System V but possibly earlier.

Another answer from that same post:

> Generally when you see that *.d convention, it means "this is a directory holding a bunch of configuration fragments which will be merged together into configuration for some service."

OK, I think I see now.  So the `.d` suffix means:

- This is a directory containing configuration files.
- These files are meant to be bundled up together into a single aggregate configuration file.
- This file likely has the same name as the directory.

Does this jive with what we see in the RBENV folders?

### Do the files within these directories count as configuration files?

If we refer back to what we read in the "How It Works" section of the `rbenv-gem-rehash` readme, we saw that "rbenv-gem-rehash consists of two parts: a RubyGems plugin and an rbenv plugin."  It seems like a safe bet that the "RubyGems plugin" part corresponds to the file `rubygems_plugin.rb`, and I would bet money that the `rbenv plugin` part corresponds to the `rbenv-gem-rehash/etc/rbenv.d/exec/~gem-rehash.bash` part.

If we look at that file, it's pretty short, containing only the following:

```
# Remember the current directory, then change to the plugin's root.
cwd="$PWD"
cd "${BASH_SOURCE%/*}/../../.."

# Make sure `rubygems_plugin.rb` is discovered by RubyGems by adding
# its directory to Ruby's load path.
export RUBYLIB="$PWD:$RUBYLIB"

cd "$cwd"
```

It looks like all this file does is prepend the root `rbenv-gem-rehash` folder to the `RUBYLIB` environment variable and export it.  And judging by the comments above the `export` statement, `RUBYLIB` sounds a Ruby-specific equivalent to `PATH`, which we've already learned about.

Googling `RUBYLIB`, I find [an excerpt of a book](https://web.archive.org/web/20220831132623/https://www.oreilly.com/library/view/ruby-in-a/0596002149/ch02s02.html){:target="_blank" rel="noopener"} written by Yukihiro Matsumoto (aka Matz), the creator of Ruby:

> In addition to using arguments and options on the command line, the Ruby interpreter uses the following environment variables to control its behavior.  The ENV object contains a list of current environment variables.
>
> ...
>
> RUBYLIB
>
> Search path for libraries. Separate each path with a colon (semicolon in DOS and Windows).

So `RUBYLIB` helps Ruby search for libraries.  Sounds like we were right about that.

To summarize, the files inside `rbenv.d` help ensure that we can automatically run `rbenv rehash` whenever we install or uninstall Ruby gems.  That sounds more like configuration logic to me, rather than application logic (which I would define as logic which a user would invoke directly, like a command such as `rbenv version`).

### Are the files in these directories being merged together somehow?

Well, neither the RBENV nor the `rbenv-gem-rehash` READMEs mention any "merging of configuration files".  And so far, we've only seen these directories being added to `PATH` or the `RBENV_HOOK_PATH` env vars.  Perhaps we will see these files being merged later, but also, perhaps not.

### Is there a file with the same name as the `rbenv.d` directory?

As a matter of fact, yes- it's the one we're currently reading!

Having thoroughly examined this block of code, let's mode onto the next one.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
