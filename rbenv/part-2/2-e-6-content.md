
We're now in a position to move on to the logic inside the `if` clause.  Here we define a function called `abs_dirname`, whose implementation contains just 3 lines of code:

```
  abs_dirname() {
    local path
    path="$(realpath "$1")"
    echo "${path%/*}"
  }
```

TODO: add section on the `local` keyword

TODO: add section on command substitution (used in `"$(realpath "$1")"`)

Those 3 lines of code are:

 - We create a local variable named `path`.
 - We call our (possibly) monkey-patched `realpath` builtin, passing it the first argument given to the `abs_dirname` function.
 - We set the local variable equal to the return value of the above.
 - We `echo` the contents of the local variable.

By `echo`'ing the value of our `path` local variable at the end of the `abs_dirname` function, we make the value of `path` into the return value of `abs_dirname`.  This means the caller of `abs_dirname` can do whatever it wants with that resolved path.

TODO: I think this is the first time we've seen the use of `local`, as well as the use of `echo` to return something from a function.  Should I do an experiment to demonstrate these techniques further?

The "%/*" after `path` inside the parameter expansion just deletes off any trailing "/" character, as well as anything after it.  We can reproduce that in the terminal:

```
$ path="/foo/bar/baz/"
$ echo ${path%/*}
/foo/bar/baz

$ path="/foo/bar/baz"
$ echo ${path%/*}
/foo/bar
```

### Aside- nested double-quotes

Let's briefly return to line 2 of the body of `abs_dirname`:

```
path="$(realpath "$1")"
```

I see two sets of double-quotes, one nested inside the other, wrapping both "$(...)" and "$1".

This is unexpected to me.  I would have thought that:

 - The 2nd `"` character would close out the 1st `"`, meaning `"$(realpath "` would be wrapped in one set of double-quotes, and
 - The 4th `"` would close out the 3rd one, meaning `")"` would be wrapped in a separate set of quotes.
 - Therefore, the `$1` in the middle would then be completely unwrapped.

When I Google "nested double-quotes bash", the first result I get is [this StackOverflow post](https://web.archive.org/web/20220526033039/https://unix.stackexchange.com/questions/289574/nested-double-quotes-in-assignment-with-command-substitution){:target="_blank" rel="noopener"}:

> Once one is inside `$(...)`, quoting starts all over from scratch.

OK, simple enough!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on to the `else` block:

```
[ -z "$RBENV_NATIVE_EXT" ] || abort "failed to load \`realpath' builtin"

READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"

resolve_link() {
  $READLINK "$1"
}

abs_dirname() {
  local cwd="$PWD"
  local path="$1"

  while [ -n "$path" ]; do
    cd "${path%/*}"
    local name="${path##*/}"
    path="$(resolve_link "$name" || true)"
  done

  pwd
  cd "$cwd"
}
```

This is a lot.  We'll process it in steps, but it looks like we're doing something similar here (defining a function named `abs_dirname`), albeit this time with a bit of setup beforehand.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

First line of this block of code is:

```
[ -z "$RBENV_NATIVE_EXT" ] || abort "failed to load \`realpath' builtin"
```

Judging by the `||` symbol, we know that if the test inside the single square brackets is falsy, then we `abort` with the quoted error message.

But what is that test?  To find out, we run `help test` in our terminal again, and search for `-z` using the forward-slash syntax.  We get:

>  -z string     True if the length of string is zero.

OK, so if the `$RBENV_NATIVE_EXT` environment variable is empty, then the test is truthy.  If that env var has already been set, then the test is falsy, and we would abort using our previously-defined function, which triggers a non-zero exit.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
  READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

So we're setting a variable called `READLINK` equal to...something.

I decide to look up the commit which introduced this line of code.  I do my `git blame / git checkout` dance until [I find it in Github](https://github.com/rbenv/rbenv/commit/81bb14e181c556e599e20ca6fdc86fdb690b8995){:target="_blank" rel="noopener"}.  The commit message reads:

> `readlink` comes from GNU coreutils.  On systems without it, rbenv used to spin out of control when it didn't have `readlink` or `greadlink` available because it would re-exec the frontend script over and over instead of the worker script in libexec.

That's somewhat helpful.  Although I don't yet know which `worker script` they're referring to, it's not crazy that RBENV might want to exit with a warning that a dependency is missing, rather than silently suffer from performance issues.

Back to the main question: what value are we assigning to the `READLINK` variable?

I start with that `type -p` command.  I try `help type` in the terminal, and because I'm using the `zsh` shell (and my `help` command is aliased to `run-help`), I get the following:

```
whence [ -vcwfpamsS ] [ -x num ] name ...
       For each name, indicate how it would be interpreted if used as a
       command name.

       If  name  is  not  an alias, built-in command, external command,
       shell function, hashed command, or a  reserved  word,  the  exit
       status  shall be non-zero, and -- if -v, -c, or -w was passed --
       a message will be written to standard output.  (This is  differ-
       ent  from  other  shells that write that message to standard er-
       ror.)

       whence is most useful when name is only the last path  component
       of  a  command, i.e. does not include a `/'; in particular, pat-
       tern matching only succeeds if just the non-directory  component
       of the command is passed.

       ...

       -p     Do a path search for name even if it  is  an  alias,  re-
              served word, shell function or builtin.
```

Looks like `type` and `whence` share the same documentation in `zsh`.  They might be aliases of each other.  I'm not sure, but I trust the authors of my shell's docs so I let it go.

These docs are a bit confusing, however.  I'm not sure what `indicate how it would be interpreted` means.  I decide to do an experiment with the `type` command and its `-p` flag.

### Experiment- the `type -p` command

I see that `name` is the first argument of the `type` command, but I'm not sure what kind of `name` the command expects.  From the above docs, I see `If  name  is  not  an alias, built-in command, external command, shell function, hashed command, or a  reserved  word,  the  exit status  shall be non-zero,...`.  I interpret this to mean that `name` refers to the name of a command, alias, reserved word, etc.

I make a `foo` script, which looks like so and uses `ls` as the value of `name`:

```
#!/usr/bin/env bash

echo $(type -p ls)
```

When I run it, I get:

```
$ ./foo

/bin/ls
```

When I change `ls` in the script to `chmod` and re-run it, I see:

```
$ ./foo

/bin/chmod
```
As a final experiment, I create a directory named `~/foo`, containing a script named `bar`, and make it executable:

```
$ mkdir ~/foo
$ touch ~/foo/bar
$ chmod +x ~/foo/bar
$ touch ~/foo/baz
$ chmod +x ~/foo/baz
```
I then try the `type -p` command on my new script, from within my `foo` bash script:
```
#!/usr/bin/env bash

echo $(type -p ~/foo/bar ~/foo/baz ls)
```

When I run it, I get:

```
$ ./foo

/Users/myusername/foo/bar /Users/myusername/foo/baz /bin/ls
```

I see the 3 paths I expected.  Great, I think this all makes sense.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on, we already know what `2>/dev/null` is from earlier- here we redirect any error output from `type -p` to `/dev/null`, aka [the black hole of the console](https://web.archive.org/web/20230116003037/https://linuxhint.com/what_is_dev_null/){:target="_blank" rel="noopener"}.

TODO: experiment w/ `/dev/null`?

But what do we do with any non-error output?  That's answered by the last bit of code from this line: `| head -n1`.  Running `man head` gives us:

```
head – display first lines of a file
...-n count, --lines=count
             Print count lines of each of the specified files.
```
So it seems like `| head -n1` means that we just want the first line of the input that we're piping in from `type -p`?  Let's test this hypothesis.

### Experiment- the `head` command

I make a simple script that looks like so:

```
#!/usr/bin/env bash

echo "Hello"
echo "World"
```

When I run it by itself, I get:

```
$ ./foo

Hello
World
```

Next, I run it a 2nd time, but this time with `| head -n1` at the end:

```
$ ./foo | head -n1

Hello
```

This time I only see 1 of the 2 lines I previously saw.  Looks like our hypothesis is correct!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So to sum up this line of code:

```
READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

 - We print out the paths to two commands, one named `greadlink` and one named `readlink`, in that order.
 - We take the first value we find, preferring `greadlink` since it comes first in the argument order.
 - Finally, we store that value in a variable named `READLINK` (likely capitalized to avoid a name collision with the `readlink` command).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
