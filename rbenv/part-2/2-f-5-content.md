TODO: add a section on why someone would choose `fish` over `zsh` or Bash.

Next line of code is:

```
mkdir -p "${RBENV_ROOT}/"{shims,versions}
```

Here we make two sub-directories inside "$RBENV_ROOT"- one named "shims" and one named "versions".

## Brace Expansion

The curly-brace syntax around `{shims,versions}` deserves special mention.  This is called ["brace expansion"](https://web.archive.org/web/20230312015457/https://www.gnu.org/software/bash/manual/html_node/Brace-Expansion.html){:target="_blank" rel="noopener"}.  It's useful when the strings that you want to create share similarities, and differ only in one or a few respects.

Here, we're using it to create the two directories in a single line of code, rather than two separate lines, like so:

```
mkdir -p "${RBENV_ROOT}/"shims
mkdir -p "${RBENV_ROOT}/"versions
```

The more strings you want to create, the more useful this is.  To illustrate this, let's try an experiment.

### Experiment- brace expansion

I want to create 6 new directories, with the following names:

```
~/Workspace/OpenSource/foo/bar
~/Workspace/OpenSource/foo/baz
~/Workspace/OpenSource/foo/buzz
~/Workspace/OpenSource/quox/bar
~/Workspace/OpenSource/quox/baz
~/Workspace/OpenSource/quox/buzz
```

I don't want to have to write these all out by hand.  So instead, I do the following:

```
mkdir -p ~/Workspace/OpenSource/{foo,quox}/{bar,baz,buzz}
```

Now, I want to add a `.ruby-version` file in each directory, with the string `3.0.0` inside each one:

```
echo "3.0.0" > ~/Workspace/OpenSource/{foo,quox}/{bar,baz,buzz}/.ruby-version
```

Next, I want to list the contents of my new directories:

```
$ ls -la ~/Workspace/OpenSource/{foo,quox}/{bar,baz,buzz}/

/Users/myusername/Workspace/OpenSource/foo/bar/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version

/Users/myusername/Workspace/OpenSource/foo/baz/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version

/Users/myusername/Workspace/OpenSource/foo/buzz/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version

/Users/myusername/Workspace/OpenSource/quox/bar/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version

/Users/myusername/Workspace/OpenSource/quox/baz/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version

/Users/myusername/Workspace/OpenSource/quox/buzz/:
total 8
drwxr-xr-x  3 myusername  staff   96 May  7 11:23 .
drwxr-xr-x  5 myusername  staff  160 May  7 11:22 ..
-rw-r--r--  1 myusername  staff    6 May  7 11:23 .ruby-version
```

Now, I want to `cat` each of the files, to make sure the previous command succeeded and my new Ruby version file contains the correct info:

```
$ cat ~/Workspace/OpenSource/{foo,quox}/{bar,baz,buzz}/.ruby-version

3.0.0
3.0.0
3.0.0
3.0.0
3.0.0
3.0.0
```

[That's pretty neat!](https://www.youtube.com/watch?v=OXZt4-LTtHw){:target="_blank" rel="noopener"}

Note that the comma-separated values must not include any spaces:

```
$ touch ~/Workspace/OpenSource/{foo, quox}/{bar, baz, buzz}/new-file

touch: quox}/{bar,: No such file or directory
touch: buzz}/new-file: No such file or directory
```

You'll get an error if you try to include spaces in a brace expansion, like we see above.  The specific error you get will depend on the command you tried to use brace expansion with.

## Setting the `PATH` and `RBENV_SHELL` env vars

Next line of code:

```
case "$shell" in
  fish )
    echo "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
    echo "set -gx RBENV_SHELL $shell"
  ;;
  ...
esac
```

Here we have a simple case statement, which branches based on the value of our "$shell" string, along with our first case branch.

If the value of `"$shell"` is `fish`, we `echo` a few commands to `stdout`.  These commands are then run inside the command substitution that we add to our shell configuration file.  We learned when we set the value of the `profile` variable that, if our shell is `fish`, this config file lives in `~/.config/fish/config.fish`.  If our shell was `fish`, the code we added to that file is `status --is-interactive; and rbenv init - fish | source`.

Both these commands use the `fish` shell's `set` command to set shell variables.  The "-g" flag makes the variable global, and the `-x` flag makes the variable available to child processes.  We're creating one environment variable (`RBENV_SHELL`), and modifying another (`PATH`) to pre-pend it with `${RBENV_ROOT}/shims'` so that the shims which RBENV creates will be findable by our terminal.  More info [here](https://fishshell.com/docs/current/cmds/set.html){:target="_blank" rel="noopener"}.

<center>
  <a target="_blank" href="/assets/images/screenshot-13mar2023-806am.png">
    <img src="/assets/images/screenshot-13mar2023-806am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next block of code:

```
* )
  echo 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
  echo "export RBENV_SHELL=$shell"

  ...
```

This code will be executed if our `"$shell"` variable contains any value other than `fish`.

Just as it was with the `fish` script, our goal here is to set the `PATH` and `RBENV_SHELL` env vars.  But since our shell is not `fish`, we use regular Bash syntax instead of `fish` syntax.  For example, instead of `set -gx`, we use `export` statements.

## Importing completion files

Next block of code:

```
  ...

  completion="${root}/completions/rbenv.${shell}"
  if [ -r "$completion" ]; then
    echo "source '$completion'"
  fi
;;
```

After the two `export` statements, the next block of code in the default `case` branch creates a file path where the user's completion file should live.  After the filepath is created, the `[ -r "$completion" ]` test checks whether that file actually exists and is readable.  If it does exist, we run `source` on that file in order to run its contents.  If not, nothing will happen.

The `${root}/completions` folder only includes two such files for now- `rbenv.bash` and `rbenv.zsh`.  So the `if` logic will only be executed if the user's shell is either Bash or `zsh`.  If the shell is something like `ksh`, we would reach the `[ -r "$completion" ]` check, but that check would be falsy.

### Why do we add completions for Bash and `zsh`, but not `fish`?

I was wondering why we include completion scripts for Bash and `zsh`, but not `fish`, so I did some digging in the Github history.  I found [this issue](https://github.com/rbenv/rbenv/issues/1212){:target="_blank" rel="noopener"} which indicates that [`fish` supports RBENV completions natively](https://github.com/fish-shell/fish-shell/blob/1aa0dfe91bc5382220ba2f170bff525501d13908/share/completions/rbenv.fish){:target="_blank" rel="noopener"}.

Because of that, the `rbenv.fish` shell was redundant and was removed as part of [this PR](https://github.com/rbenv/rbenv/commit/143b2c9c02dbacbbb40592ef4fee5bb5f7f106a5){:target="_blank" rel="noopener"}.  The code to `source` the completion file was then moved into the default branch of the `case` statement [here](https://github.com/gioele/rbenv/commit/9fbbfd268dcbedf0d99f8d14946023e3242feff3){:target="_blank" rel="noopener"}.

## The `source` command

We saw that, if the filepath for our completions file actually mapped to a real file, then we call the following code:

```
echo "source '$completion'"
```

The code that we `echo` is `source '$completion'`.  This code will then be executed inside the command substitution that we add to our shell's config file.

The `source` command is one of the more commonly-used commands I have in my shell scripting toolbox.  The command takes the name of a file, and runs that file.  I find this useful when I edit my shell configuration file (i.e. `~/.zshrc`) and I don't want to have to open a new terminal tab in order to activate the changes I've made.

Typing `help source` in my Bash shell returns the following:

```
bash-3.2$ help source
source: source filename [arguments]
    Read and execute commands from FILENAME and return.  The pathnames
    in $PATH are used to find the directory containing FILENAME.  If any
    ARGUMENTS are supplied, they become the positional parameters when
    FILENAME is executed.
```

Let's try this out with an experiment.

### Experiment- the `source` command

I write a script called `./foo`, which includes the following:

```
#!/usr/bin/env bash

echo "Hello world"
```

In my terminal, I `chmod +x` my new `foo` script, then I run the following:

```
$ source ./foo

Hello world
```

My script ran, as expected.  OK, but how is this different from just running the script directly, like this?

```
$ ./foo

Hello world
```

The difference is that `./foo` by itself will run the script in a **subshell**, meaning that the code will be executed inside a child process, and the effects of running the shell (such as any newly-declared shell functions or environment variable updates) will not be available to the parent process once the child is finished executing.

Let's see this for ourselves.  I update the `foo` script to the following:

```
#!/usr/bin/env bash

export FOO="foo bar baz"
```

When I run it, I see:

```
$ ./foo
```

If I then run `echo "$FOO"`, will the env var's value print to the terminal?

```
$ echo "$FOO"


$
```

Nothing was `echo`ed, even though my script contained an `export` statement.  That's because `export` only makes an environment variable to a script and its children, **not** to any parent script(s).  And when we run `./foo` by itself, we create a [subshell](https://web.archive.org/web/20230320235827/https://tldp.org/LDP/abs/html/subshells.html){:target="_blank" rel="noopener"}, which uses a child process.

Sometimes we want to isolate those environment variables from our parent, in which case running `./foo` in a subshell is the right call.  But what if that's not what we want?  What if we really do want `FOO` to be set in our parent script?  Well, we have to use `source` instead:

```
$ source ./foo
```

Now, when we try to `echo "$FOO"`, we see that env var has a value set in our terminal:

```
$ echo "$FOO"

foo bar baz
```

That's the difference between using `source` and just calling a script directly.

## Rehashing our shims

Next lines of code:

```
if [ -z "$no_rehash" ]; then
  echo 'command rbenv rehash 2>/dev/null'
fi
```

If `$no_rehash` was not set (i.e. if the user did NOT pass `--no-rehash` as an argument), then we run `rbenv command rehash` and send any errors to `/dev/null`.  We'll examine the `rbenv rehash` command more fully when we get to the `libexec/rbenv-rehash` file.  But in brief, this command generates the shim files for any Ruby dependencies we've installed.

Why would someone pass the `--no-rehash` flag?  According to [the `How RBENV Hooks Into Your Shell` section of the `README` file](https://github.com/rbenv/rbenv#how-rbenv-hooks-into-your-shell){:target="_blank" rel="noopener"}, rehashing gems can add latency to your shell startup.  If you want to avoid this latency and think rehashing every time you open a new terminal tab is overkill, pass the `--no-rehash` flag.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

In the next section, we'll declare and implement the `rbenv` shell function.
