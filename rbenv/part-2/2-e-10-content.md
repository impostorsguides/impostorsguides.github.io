
Next block of code is:

```
if [ "${bin_path%/*}" != "$RBENV_ROOT" ]; then
  # Add rbenv's own `rbenv.d` unless rbenv was cloned to RBENV_ROOT
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${bin_path%/*}/rbenv.d"
fi
```

Based on the comment and the logic of the test in the `if` statement, we can conclude that `"${bin_path%/*}"` would equal `"$RBENV_ROOT"` if "rbenv was cloned to `RBENV_ROOT`".  But I'm not sure under what circumstances rbenv would be "cloned to `RBENV_ROOT`".

As you may recall, `bin_path` resolves to `/Users/myusername/.rbenv/libexec` on my machine, so `"${bin_path%/*}"` will resolve to `/Users/myusername/.rbenv` when the `%/*` bit of the parameter expansion does its job and removes the final `/` and anything after it.  When I add another `echo` statement here, I see that `RBENV_ROOT` resolves to the same path- `/Users/myusername/.rbenv`.  So these two paths are equal for me, and I won't reach the code inside the `if` check.

When *would* someone reach that code?  Apparently, when "rbenv was cloned to RBENV_ROOT".  I'm not sure what that means, but I know that `[ "${bin_path%/*}" != "$RBENV_ROOT" ]` would have to be false in order for us to reach that code.  And this test would be false if we passed in a different value for `RBENV_ROOT` when running our code, i.e. `RBENV_ROOT="~/my/other/directory/rbenv" rbenv version`.  You might do this if, for example, you pulled down the RBENV code from Github into a project directory, and wanted to run a command with `RBENV_ROOT` set to that directory.  But then why wouldn't `bin_path` *also* get updated?

Taking a step back, I know that this `if` block was added as part of [this PR](https://github.com/rbenv/rbenv/pull/638){:target="_blank" rel="noopener"}, which was the PR responsible for bringing in the `gem-rehash` logic into RBENV core.  Therefore, we can probably assume that this logic was part of that effort.  So how does this `if` block fit into the effort to bring `gem-rehash` into core?

I don't see it.  I may have to punt on this question until later.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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

Honestly, the above is a bit too abstract for me.  I did find [this link](https://archive.is/hXKpL){:target="_blank" rel="noopener"} which has more concrete examples.  It mentions that it refers to the FHS for Linux, not for UNIX, but [this StackOverflow post](https://web.archive.org/web/20150928165243/http://unix.stackexchange.com/questions/98751/is-the-filesystem-hierarchy-standard-a-unix-standard-or-a-gnu-linux-standard/){:target="_blank" rel="noopener"} says that both Linux and UNIX follow the same FHS, so I think we're OK.  The site says these directories might contain the following types of files:

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

In an earlier `for` loop, we updated the `PATH` variable to include any executables which were provided by any RBENV hooks that we've installed.  This was so that we could run that hook's commands from our terminal.

Here, we appear to be telling RBENV which hooks the user has installed.  This is not so that we can run that hook's commands, but so that a hook's logic will be executed when we run an *RBENV* command.  By adding a path to `RBENV_HOOK_PATHS`, we give an RBENV command another directory to search through when that command executes its hooks.

We're skipping ahead a bit, but [here is an example](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L12){:target="_blank" rel="noopener"} of that process in action.  The `version-name` command calls `rbenv-hooks version-name`, which internally relies on the `RBENV_HOOKS_PATH` variable to print out a list of hooks for (in this case) the `version-name` command.  For each of those paths, we look for any `.bash` scripts, and then we run `source` on each of those scripts, so that those scripts are executed in our current shell environment.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH#:}"
export RBENV_HOOK_PATH
```

This syntax is definitely parameter expansion, but I haven't seen the `#:` syntax before.  I don't know if `#:` is a specific command in parameter expansion (like `:+` or similar), or if `:` is a character that we're performing the `#` operation on.

I search [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"} for `#:`, since it looks like a specific kind of expansion pattern, but I don't see those two characters used together anywhere in the docs.  Maybe it's just the `#` pattern we've seen before, for instance when we saw `parameter#/*`?  In that case, we were removing any leading `/` character from the start of the parameter.  Maybe here we're doing the same, but with the `:` character instead?

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
