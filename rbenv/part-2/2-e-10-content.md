Next line of code is:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

According to the README, `RBENV_HOOK_PATH` is a:

```
Colon-separated list of paths searched for rbenv hooks.
```

This code adds `${RBENV_ROOT}/rbenv.d` to the end of the current value of `RBENV_HOOK_PATH`, if any.  According to [the README file](https://github.com/rbenv/rbenv#environment-variables){:target="_blank" rel="noopener"}, `RBENV_HOOK_PATH` is the environment variable which controls where RBENV searches for [hooks](https://github.com/rbenv/rbenv/wiki/Authoring-plugins#rbenv-hooks){:target="_blank" rel="noopener"}.  Hooks are similar to plugins, in that they both update functionality within RBENV.  But they differ in that:

- Plugins expose entirely new RBENV commands (i.e. `rbenv foo`).
- Hooks modify existing commands.

But what is `"${RBENV_ROOT}/rbenv.d"`?

## Telling RubyGems to automatically generate shims

I `cd` into my `~/.rbenv` directory and run `find . -name rbenv.d`.  I see the following:

```
$ cd ~/.rbenv

$ find . -name rbenv.d

./rbenv.d
```

I inspect it, and see that it's a directory, containing a directory named `exec`:

```
$ ls -la rbenv.d
total 0
drwxr-xr-x   3 myusername  staff   96 Sep  5 15:47 .
drwxr-xr-x  15 myusername  staff  480 Sep  5 09:13 ..
drwxr-xr-x   4 myusername  staff  128 Sep  4 10:13 exec
```

The `exec` directory, in turn contains the following:

```
$ ls -la rbenv.d/exec
total 8
drwxr-xr-x  4 myusername  staff  128 Sep  4 10:13 .
drwxr-xr-x  3 myusername  staff   96 Sep  5 15:47 ..
drwxr-xr-x  3 myusername  staff   96 Sep  4 10:13 gem-rehash
-rw-r--r--  1 myusername  staff   47 Sep  4 10:13 gem-rehash.bash
```
And the `gem-rehash` directory contains the following:

```
$ ls -la rbenv.d/exec/gem-rehash
total 8
drwxr-xr-x  3 myusername  staff    96 Sep  4 10:13 .
drwxr-xr-x  4 myusername  staff   128 Sep  4 10:13 ..
-rw-r--r--  1 myusername  staff  1427 Sep  4 10:13 rubygems_plugin.rb
```

I Google "gem-rehash", and the first thing I find is [this deprecated Github repo](https://github.com/rbenv/rbenv-gem-rehash){:target="_blank" rel="noopener"}.  The description says:

> Never run rbenv rehash again. This rbenv plugin automatically runs rbenv rehash every time you install or uninstall a gem.
>
> This plugin is deprecated since its behavior is now included in rbenv core.

I notice that the deprecated repo contains:

 - a file named `rubygems_plugin.rb`, just like our RBENV repo does.
 - a file named `etc/rbenv.d/exec/~gem-rehash.bash`, which is very similar (but not identical) to the file that we saw in the RBENV repo above.

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

We want RBENV to automatically re-run the `rbenv rehash` command every time we install a new Ruby gem.  The way we achieve this is by updating `RBENV_HOOK_PATH`, thereby hooking into the Rubygems `gem install` and `gem uninstall` commands.  RubyGems will then call [the `rubygems_plugin.rb` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash/rubygems_plugin.rb){:target="_blank" rel="noopener"}, which runs `rbenv rehash` for us.

### The `.d` extension in `rbenv.d`

The `.d` in `rbenv.d` looked funny to me.  It appears to be a file extension, but it's being used on a directory.  I Google `what does ".d" stand for bash`, and the first result I see is [this StackOverflow post](https://web.archive.org/web/20220619172419/https://unix.stackexchange.com/questions/4029/what-does-the-d-stand-for-in-directory-names){:target="_blank" rel="noopener"}:

> The .d suffix here means directory. Of course, this would be unnecessary as Unix doesn't require a suffix to denote a file type but in that specific case, something was necessary to disambiguate the commands (/etc/init, /etc/rc0, /etc/rc1 and so on) and the directories they use (/etc/init.d, /etc/rc0.d, /etc/rc1.d, ...)
>
> This convention was introduced at least with Unix System V but possibly earlier.

Another answer from that same post:

> Generally when you see that *.d convention, it means "this is a directory holding a bunch of configuration fragments which will be merged together into configuration for some service."

So the `.d` suffix means:

- This is a directory containing configuration files.
- These files are meant to be bundled up together into a single aggregate configuration file.
- This file likely has the same name as the directory.

Does this fit with what we see in the RBENV folders?  Let's check each of these points one-by-one.

#### 1. Do the files within these directories count as configuration files?

Recalling what we read in the README of the deprecated `rbenv-gem-rehash` package:

> The RubyGems plugin hooks into the gem install and gem uninstall commands to run rbenv rehash afterwards, ensuring newly installed gem executables are visible to rbenv.
>
> The rbenv plugin is responsible for making the RubyGems plugin visible to RubyGems.

In other words, the files inside `rbenv.d` help ensure that we can automatically run `rbenv rehash` whenever we install or uninstall Ruby gems.  That sounds more like configuration logic to me, rather than application logic.

#### 2. Are the files in these directories being merged together somehow?

Well, neither the RBENV nor the `rbenv-gem-rehash` READMEs mention any "merging of configuration files".  But our `for`-loop does add them to our `PATH` variable, which makes them available to be called later as commands.  This seems just as good as merging, since it achieves the same effect.

#### 3. Is there a file with the same name as the `rbenv.d` directory?

As a matter of fact, yes- it's the one we're currently reading!  One caveat, though- this file isn't located in the same directory as `rbenv.d`, so there's no risk of a naming collision.  My guess is that the `.d` suffix was added more out of convention than necessity.

## Adding Hooks to RBENV

Next block of code is:

```
if [ "${bin_path%/*}" != "$RBENV_ROOT" ]; then
  # Add rbenv's own `rbenv.d` unless rbenv was cloned to RBENV_ROOT
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${bin_path%/*}/rbenv.d"
fi
```

We see we're adding another `rbenv.d` file to `RBENV_HOOK_PATH`.  But we only do this **if** `"${bin_path%/*}"` is not equal to `"$RBENV_ROOT"`.  We do this check because we just finished adding `${RBENV_ROOT}/rbenv.d` to `RBENV_HOOK_PATH` in the previous line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

If `"${bin_path%/*}"` was equal to `"$RBENV_ROOT"`, we'd be adding the same path to `RBENV_HOOK_PATH` twice.  This could cause unexpected behavior later, when we actually execute the hook code.  We can prove this with an experiment.

### Experiment- breaking hook imports

I make a file called `rbenv.d/exec/foobar.bash`, which will serve as our dummy hook for this experiment. It contains the following:

```
#!/usr/bin/env bash

echo "Hello world"
```

Since our dummy hook is located in `rbenv.d/exec`, I need to run a command in my terminal which starts with `rbenv exec`.  I do the following:

```
$ rbenv exec ruby -e 'puts 5+5'

Hello world
10
```

So far, so good.  Our hook is getting registered by [this block of code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-exec#L36){:target="_blank" rel="noopener"}, and the call to `source "$script"` is what causes our `foobar.bash` script to execute. This happens one time, because the parent directory of `foobar.bash` is only added to `RBENV_HOOK_PATH` once.

Now, I comment out the `if` check:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
# if [ "${bin_path%/*}" != "$RBENV_ROOT" ]; then
  # Add rbenv's own `rbenv.d` unless rbenv was cloned to RBENV_ROOT
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${bin_path%/*}/rbenv.d"
# fi
```

When I re-run the same command, this time I see the following:

```
$ rbenv exec ruby -e 'puts 5+5'

Hello world
Hello world
10
```

Now we see that our hook is being run twice.

With a relatively benign hook that just calls `echo`, this is no big deal. But if the logic were more substantial, this could lead to significant problems.

## The Filesystem Hierarchy Standard

Moving on to the next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
```
This just means we're further updating RBENV_HOOK_PATH to include more `rbenv.d` directories, including those inside `/usr/local/etc`, `/etc`, and `/usr/lib/`.  These directories may or may not even exist on the user's machine (for example, I don't currently have a `/usr/local/etc/rbenv.d` directory on mine).  They're just directories where the user *might* have installed additional hooks.

Why these specific directories?  They appear to be a part of a convention known as the [Filesystem Hierarchy Standard](https://web.archive.org/web/20230326013203/https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard){:target="_blank" rel="noopener"}, or the conventional layout of directories on a UNIX system.  Using this convention means that developers on UNIX machines can trust that the files they're looking for are likely to live in certain places.

For example, the two main directories we're using in this line of code are `/usr/` and `/etc/`.  The FHS describes these directories as follows:

 - `/etc/`- "Host-specific system-wide configuration files."
 - `/usr/`- "Secondary hierarchy for read-only user data; contains the majority of (multi-)user utilities and applications. Should be shareable and read-only."
    - `/usr/local/`- "Tertiary hierarchy for local data, specific to this host. Typically has further subdirectories (e.g., bin, lib, share)."
    - `/usr/lib/`- "Libraries for the binaries in /usr/bin and /usr/sbin."

[This link here](https://archive.is/hXKpL){:target="_blank" rel="noopener"} contains more concrete examples.  It mentions that it refers to the FHS for Linux, not for UNIX, but [this StackOverflow post](https://web.archive.org/web/20150928165243/http://unix.stackexchange.com/questions/98751/is-the-filesystem-hierarchy-standard-a-unix-standard-or-a-gnu-linux-standard/){:target="_blank" rel="noopener"} says that both Linux and UNIX follow the same FHS, so I think we're OK.  The site says these directories might contain the following types of files:

#### /etc

 - the name of your device
 - password files
 - network configuration
 - DNS configuration
 - crontab configuration
 - date and time configuration

It also notes that `/etc` should only contain static files; no executable / binary files allowed.

#### /usr

> Over time, this directory has been fashioned to store the binaries and libraries for the applications that are installed by the user. So for example, while bash is in /bin (since it can be used by all users) and fdisk is in /sbin (since it should only be used by administrators), user-installed applications like vlc are in /usr/bin.

##### /usr/lib

> This contains the essential libraries for packages in /usr/bin and /usr/sbin just like /lib.

##### /usr/local

> This is used for all packages which are compiled manually from the source by the system administrator.
This directory has its own hierarchy with all the bin, sbin and lib folders which contain the binaries and applications of the compiled software.

In summary, though I can't yet quote chapter-and-verse of what each folder's purpose is on a UNIX machine, for now it's enough to know that there's a concept called the Filesystem Hierarchy Standard, and that it specifies the purposes of the different folders in your UNIX system.  I can always refer to the official docs if I need to look up this information.  The homepage of the standard is [here](https://www.pathname.com/fhs/){:target="_blank" rel="noopener"}, and the document containing the standard is [here](https://www.pathname.com/fhs/pub/fhs-2.3.pdf){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
for plugin_hook in "${RBENV_ROOT}/plugins/"*/etc/rbenv.d; do
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${plugin_hook}"
done
```

Here, we appear to be telling RBENV which hooks the user has installed.  This is not so that we can run that hook's commands, but so that a hook's logic will be executed when we run certain *RBENV* commands.

We're skipping ahead a bit, but [here is an example](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L12){:target="_blank" rel="noopener"} of that process in action.  The `version-name` command calls `rbenv-hooks version-name`, which internally relies on the `RBENV_HOOKS_PATH` variable to print out a list of hooks for (in this case) the `version-name` command.

For each of those paths, we look for any `.bash` scripts, and then we run `source` on each of those scripts, so that those scripts are executed in our current shell environment.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH#:}"
export RBENV_HOOK_PATH
```

This syntax is definitely parameter expansion, but I haven't seen the `#:` syntax before.

I search [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"} for `#:`, since it looks like a specific kind of expansion pattern, but I don't see those two characters used together anywhere in the docs.  This is definitely parameter expansion, though.

Maybe this is just another example of the `#` pattern that we've already seen before, for instance when we saw `parameter#/*`?  In that case, we were removing any leading `/` character from the start of the parameter.  Maybe here we're doing the same, but with the `:` character instead?

As an experiment, I update my test script to read as follows:

```
#!/usr/bin/env bash

FOO='foo:bar/baz/buzz:quox'

echo "${FOO#:}"
```

When I run it, I see:

```
$ ./bar
foo:bar/baz/buzz:quox
```

Nothing has changed- the output is the same as the input.

When I update FOO to add a `:` at the beginning (i.e. ':foo:bar/baz/buzz:quox'), and I re-run the script, I see:

```
$ ./bar
foo:bar/baz/buzz:quox
```

The leading `:` character has been removed.  So yes, it looks like our hypothesis was correct, and that the parameter expansion is just removing any leading `:` symbol from `RBENV_HOOK_PATH`.

The last line of code in this block is just us `export`ing the `RBENV_HOOK_PATH` variable, so that it can be used by child processes.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
shopt -u nullglob
```

This just turns off the `nullglob` option in our shell that we turned on before we started adding plugin configurations.  This is a cleanup step, not too surprising to see it here.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So that's how we add hooks to RBENV.  Let's move on.
