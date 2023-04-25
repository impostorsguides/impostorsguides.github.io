We're now in a position to move on to the logic inside the `if` clause.  Here we define a function called `abs_dirname`, whose implementation contains just 3 lines of code:

```
  abs_dirname() {
    local path
    path="$(realpath "$1")"
    echo "${path%/*}"
  }
```

## Defining `abs_dirname` with a *more*-performant `realpath`

The above function does the following:

 - It creates a local variable named `path`.
 - It calls `realpath` via command substitution, passing it the first argument given to the `abs_dirname` function.
 - It sets the local variable equal to the return value of the above call to `realpath`.
 - It `echo`s the contents of the local variable.

A reminder that, if we've reached the inside of this `if`-block, we can be confident that the version of `realpath` that we're calling is our newly-redefined version (remember `enable -f`), **not** the version that ships with our shell.

### The `local` keyword

By default, variables declared inside a function are available outside that function.  To prevent that from happening, we use the `local` keyword to ensure their scope is limited to the body of the function.  Note- this keyword [is **not** POSIX-compliant](https://web.archive.org/web/20221114113625/https://stackoverflow.com/questions/18597697/posix-compliant-way-to-scope-variables-to-a-function-in-a-shell-script){:target="_blank" rel="noopener"}.

We can see how `local` works with an experiment.

#### Experiment- keeping a local variable local

We create a function named `foo`, which creates and calls a function:

```
#!/usr/bin/env bash

function foo() {
  bar="Hello world"
  echo "bar inside the 'foo' function: $bar"
}

foo

echo "bar outside the 'foo' function: $bar"
```

We call the function to make sure that `bar` is initialized inside the `foo` function, and then we attempt to echo `bar` to see if it has a value outside of `foo`.  Sure enough, we see that it does:

```
$ ./foo

bar inside the 'foo' function: Hello world
bar outside the 'foo' function: Hello world
```

Now we prepend the declaration of `bar` with the `local` keyword:

```
#!/usr/bin/env bash

function foo() {
  local bar="Hello world"
  echo "bar inside the 'foo' function: $bar"
}

foo

echo "bar outside the 'foo' function: $bar"
```

When we re-run the script, we see:

```
$ ./foo

bar inside the 'foo' function: Hello world
bar outside the 'foo' function:
```

This time, `bar` has no value outside the `foo` function.

### `echo`ing from inside a function

By `echo`'ing the value of our `path` local variable, we make the value of `path` available for callers of `abs_dirname` to store in a variable, using command substitution.  To replicate this, let's do an experiment.

#### Experiment- capturing the result of command substitution

I update my `foo` script to read as follows:

```
#!/usr/bin/env bash

foo() {
  echo "Hello world"
  exit 0
}

result_of_foo="$(foo)"

echo "$result_of_foo"
```

When I run this script, I see the following:

```
$ ./foo

Hello world
```

We can see that we initialized `result_of_foo` to equal the result of the command substitution, and from there we were able to print out its value to `stdout`.

Note that I'm careful not to say "The return value of the foo function is 'Hello world'."  That would be inaccurate.  Functions in `bash` don't work the same way that they do in Ruby, where the return value is the last expression executed in the function's body.  The closest thing a `bash` function has to a return value is the exit code.  However, you can `echo` anything you want from inside the function, and store that result via command substitution, as we've done above.

Recall that the `%/*` after `path` inside the parameter expansion just shaves off any trailing `/` character, as well as anything after it.  We can reproduce that in the terminal:

```
$ path="/foo/bar/baz/"
$ echo ${path%/*}
/foo/bar/baz

$ path="/foo/bar/baz"
$ echo ${path%/*}
/foo/bar
```

So in our case, what we're "returning" from the `abs_dirname` function is the directory name of the argument (a filepath) which we pass to the function.

### Nested double-quotes

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

So double-quotes **inside** of a command substitution do not close out any existing double-quotes **outside** the substitution.  Simple enough!

## Defining `abs_dirname` with a *less*-performant `realpath`

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

So if the `$RBENV_NATIVE_EXT` environment variable is empty, then the test is truthy.  If that env var has already been set, then the test is falsy, and we would abort.

What does the `RBENV_NATIVE_EXT` env var do?  I don't see anything mentioned in [the env vars section of the README](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/README.md#environment-variables){:target="_blank" rel="noopener"}, so I search the Github repo and find [this PR](https://github.com/rbenv/rbenv/pull/528){:target="_blank" rel="noopener"}, which includes the following comment:

> If RBENV_NATIVE_EXT environment variable is set, rbenv will abort if it didn't manage to load the builtin. This is primarily useful for testing.

So we would set `RBENV_NATIVE_EXT` to a non-empty value if we want to make sure that we successfully import the native extension for `realpath` in the `if`-block.  If we set this env var and the `if enable -f ...` operation fails, we abort the entire script.

### Native Extensions

The `NATIVE_EXT` in the name `RBENV_NATIVE_EXT` refers to the concept of ["native extensions"](https://web.archive.org/web/20180912035230/https://stackoverflow.com/questions/31202707/what-exactly-is-a-gem-native-extension){:target="_blank" rel="noopener"}.  A native extension is a library written in one language, which can be used by a program written in another language.  In this case, RBENV is written in `bash`, but we're relying on an implementation of `realpath` which is [written in C](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/src/realpath.c){:target="_blank" rel="noopener"}.

Ruby does a lot of things well, but it's not the right tool for every job.  If a Ruby developer needs to use certain APIs which are very close to the operating system, or are unavoidably slow in Ruby, a native extension might be the right tool to use.  [For example](https://web.archive.org/web/20230409112559/https://guides.rubygems.org/gems-with-extensions/){:target="_blank" rel="noopener"}:

 - the `nokogiri` gem uses a native extension to parse XML.
 - the `mysql2` gem uses a native extension to communicate with the MySQL database.

[This article](https://web.archive.org/web/20230223203806/https://patshaughnessy.net/2011/10/31/dont-be-terrified-of-building-native-extensions){:target="_blank" rel="noopener"} goes into some depth about how to use native extensions in Ruby, as well as what to do when the installation of a Ruby native extension goes wrong.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
  READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

Here we again use command substitution to set a variable called `READLINK`.  What value are we storing?  Whatever is returned by `type -p greadlink readlink 2>/dev/null | head -n1`.

To start, I decide to look up the commit which introduced this line of code.  I do my `git blame / git checkout` dance until [I find it in Github](https://github.com/rbenv/rbenv/commit/81bb14e181c556e599e20ca6fdc86fdb690b8995){:target="_blank" rel="noopener"}.  The commit message reads:

> `readlink` comes from GNU coreutils.  On systems without it, rbenv used to spin out of control when it didn't have `readlink` or `greadlink` available because it would re-exec the frontend script over and over instead of the worker script in libexec.

That's somewhat helpful.  Although I don't yet know which "worker script" they're referring to, it's not crazy to think that RBENV might want to exit with a warning if that a dependency is missing, rather than silently suffer from performance issues.

I get confirmation that `greadlink` comes from GNU coreutils [here](https://github.com/common-workflow-language/common-workflow-language/issues/316){:target="_blank" rel="noopener"}.

Back to the main question: what value are we assigning to the `READLINK` variable?

It looks like we're taking the results of `type -p greadlink readlink 2>/dev/null`, and piping them to the `head -n1` command.  I start with that `type -p` command.  In a `bash` terminal, I try `help type` in the terminal, and I get the following:

```
$ bash

bash-3.2$ help type

type: type [-afptP] name [name ...]
    For each NAME, indicate how it would be interpreted if used as a
    command name.

    ...

    If the -p flag is used, `type' either returns the name of the disk
    file that would be executed, or nothing if `type -t NAME' would not
    return `file'.
```

To me, that's pretty clear- it returns the command's filename, or nothing, depending on whether the file exists.

I decide to do an experiment with the `type` command and its `-p` flag.

### Experiment- the `type -p` command

I interpret `name` to mean the name of a command, alias, reserved word, etc.

I make a `foo` script, which looks like so and uses `ls` as the value of `name`:

```
#!/usr/bin/env bash

type -p ls
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
As a final experiment, I create a directory named `~/foo`, containing executable scripts named `bar` and `baz`:

```
$ mkdir ~/foo
$ touch ~/foo/bar
$ chmod +x ~/foo/bar
$ touch ~/foo/baz
$ chmod +x ~/foo/baz
```

I then try the `type -p` command on my 2 new scripts as well as the `ls` command, from within my `foo` bash script:

```
#!/usr/bin/env bash

type -p ~/foo/bar ~/foo/baz ls
```

When I run it, I get:

```
bash-3.2$ ./foo

/Users/myusername/foo/bar
/Users/myusername/foo/baz
/bin/ls
```

I see the 3 paths I expected, each one on a separate line.  Great, I think this all makes sense.

### The `head` command

Moving on, we already know what `2>/dev/null` is from earlier- here we redirect any error output from `type -p` to `/dev/null`, aka [the black hole of the console](https://web.archive.org/web/20230116003037/https://linuxhint.com/what_is_dev_null/){:target="_blank" rel="noopener"}.

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
 - We take the first value we find, preferring `greadlink` since it comes first in the argument order to `type`.
 - Finally, we store that value in a variable named `READLINK` (likely capitalized to avoid a name collision with the `readlink` command).

### `readlink` and `greadlink`

Since `greadlink` is preferred over `readlink` in the order of precedence, I type `man greadlink`, but I actually end up getting the `man` page for `readlink`:

```
READLINK(1)                                                               User Commands                                                              READLINK(1)

NAME
       readlink - print resolved symbolic links or canonical file names

SYNOPSIS
       readlink [OPTION]... FILE...

DESCRIPTION
       Note realpath(1) is the preferred command to use for canonicalization functionality.

       Print value of a symbolic link or canonical file name
```

Looks like these two programs are used to resolve a symlink to its canonical link.

I Google "greadlink vs readlink", and am unable to find any explanation of why someone would use one over the other.  I search the Github repo for the commit which introduced the `greadlink readlink` combination, and after some digging, I find [this PR](https://github.com/rbenv/rbenv/pull/43){:target="_blank" rel="noopener"} which mentions that Solaris (a UNIX operating system originally developed by Sun Microsystems) doesn't support `readlink`, so `greadlink` is called first and `readlink` is used as the fallback.

### Symlinks

I like to think of a symbolic link, or a symlink for short, as a signpost to a file.  As [this link](https://web.archive.org/web/20221126123116/https://devdojo.com/devdojo/what-is-a-symlink){:target="_blank" rel="noopener"} says, "it is a file that points to another file".  If you type `open` plus the name of the symlink in your terminal, you're actually opening the canonical file, not the symlink file.

### Experiment- creating symlinks

I create and `chmod +x` a file named `./foo`, containing the string "Hello world":

```
#!/usr/bin/env bash

echo "Hello world"
```

I then create a directory called `bar_dir/`, and inside of that directory, a symlink to my `foo` file:

```
$ mkdir bar_dir
$ cd bar_dir
$ ln -s ../foo bar
```

Then I run the symlink file as a test:

```
$ ./bar

Hello world
```

I then edit `foo` to print out a different string:

```
#!/usr/bin/env bash

echo "Hello globe"
```

I then re-run my symlink:

```
$ ./bar

Hello globe
```

I then **move** the symlink file up one directory, and try to re-run it:

```
$ mv bar ..

$ ../bar
zsh: no such file or directory: ../bar
```

But when I move the symlink file back to `bar_dir/`, it works again:

```
$ mv ../bar .

$ ./bar

Hello globe
```

When I run `ls -la` in `bar_dir/`, I see the following:

```
bash-3.2$ ls -la

total 0
drwxr-xr-x   3 richiethomas  staff   96 Apr 22 20:03 .
drwxr-xr-x  22 richiethomas  staff  704 Apr 22 20:03 ..
lrwxr-xr-x   1 richiethomas  staff    6 Apr 22 20:00 bar -> ../foo
```

We see `bar -> ../foo`.  The `->` indicates that `bar` is a symlink to `../foo`.

If we move `bar` back up one directory, we see the following:

```
$ mv bar ..

$ ls -la ..

total 0
drwxr-xr-x   3 richiethomas  staff   96 Apr 22 20:03 .
drwxr-xr-x  22 richiethomas  staff  704 Apr 22 20:03 ..
lrwxr-xr-x   1 richiethomas  staff      6 Apr 22 20:00 bar -> ../foo
-rwxr-xr-x   1 richiethomas  staff     40 Apr 22 20:01 foo
```

Here we can see the problem- the symlink is still pointing to `../foo`, even though we're now in the directory where `foo` is located.  I surmise that the error `no such file or directory: ../bar` happens because `../bar` is pointing to a file that doesn't exist, relative to its current location.

### Experiment- resolving symlinks

I delete the previous symlink that I created, and create a new symlink to my `foo` script in the same directory in which `foo` exists:

```
$ ln -s foo foobarbaz
```

I then create a chain of additional symlinks, with each new symlink pointing to the last one I created:

```
$ ln -s foobarbaz quox
$ ln -s quox buzzzzz
```

I then run `readlink` on each of the symlinks, starting with `buzzzzz` (the start of the chain of symlinks):

```
$ readlink buzzzzz

quox

$ readlink quox

foobarbaz

$ readlink foobarbaz

foo

$ readlink foo

$
```

I notice that, when I get to the regular, non-symlink file, `readlink` has no output.  I also notice that, without any flags, `readlink` just resolves the symlink 1 level deep.

### Hard links vs. soft links

The `-s` in `ln -s` means `symbolic`.  Symbolic links are also called "soft links".  In contrast, [a "hard link"](https://web.archive.org/web/20230319045725/https://www.javatpoint.com/hard-link-vs-soft-links){:target="_blank" rel="noopener"} is created by using the `ln` command **without** the `-s` flag.  A hard link is a copy of the original file, but it's also a pointer to that file.  So if you change the original file, your hard link file will change as well.

### Experiment- difference between hard and soft links

I create a hard link to my `foo` file:

```
$ ln foo hardfoo

$ ls -la

-rwxr-xr-x   2 richiethomas  staff     47 Apr 22 20:16 foo
lrwxr-xr-x   1 richiethomas  staff      3 Apr 22 20:09 foobarbaz -> foo
-rwxr-xr-x   2 richiethomas  staff     47 Apr 22 20:16 hardfoo
```

Notice the relative filesizes:

 - The original `foo` file has 47 bytes.
 - The hard link file `hardfoo` also has 47 bytes.
 - The symlink `foobarbaz` file only has 3 bytes (one for each character in the filename `foo`).

A call to `cat hardfoo` results in the following:

```
$ cat hardfoo
#!/usr/bin/env bash

echo "Hello globe"
```

This is the same as the current contents of `foo`.

I then update `foo`:

```
#!/usr/bin/env bash

echo "Hello globetrotter"
```

When I run `cat hardfoo` again, I see its contents have also updated:

```
$ cat hardfoo
#!/usr/bin/env bash

echo "Hello globetrotter"
```

[Here](https://web.archive.org/web/20230412072332/https://www.freecodecamp.org/news/symlink-tutorial-in-linux-how-to-create-and-remove-a-symbolic-link/){:target="_blank" rel="noopener"} is another link on more operations you can do with symlinks, including:

 - creating symlinks for folders
 - removing a symlink with the `-l` flag
 - using the `unlink` command to remove a symlink
 - using `rm` to remove a symlink
 - finding and deleting broken symlinks

### Ensuring we have a value for `READLINK`

The next line of code is:

```
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"
```

We already learned what `[ -n ...]` does from reading about `$RBENV_DEBUG`.  Here, it returns true if the length of (in this case) `$READLINK` is non-zero.  So if the length of `$READLINK` *is* zero, then we `abort` with the specified error message.

### Using `READLINK` to define a function

Let's look at the next 3 lines of code together, since it's just a simple function declaration:

```
  resolve_link() {
    $READLINK "$1"
  }
```

When we call this `resolve_link` function, we invoke either the `greadlink` command or (if that doesn't exist) the `readlink` command.  When we do this, we pass any arguments which were passed to `resolve_link`.

### Defining our non-native-extension `abs_dirname` function

Next block of code:

```
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

So here's where we're declaring the version of `abs_dirname` from the `else` block (as an alternative to the `abs_dirname` function in our `if` block above).

The first two lines of code in our function body are:

```
local cwd="$PWD"
local path="$1"
```

We declare two local variables:

 - A var named `cwd`.
    - This likely stands for "current working directory".
    - Here we store the absolute directory of whichever directory we're currently in when we run the `rbenv` command.
 - A var named `path`, which contains the first argument we pass to `abs_dirname`.

We can prove that `"$PWD"` resolves to the directory from which we run `rbenv`, **not** the directory containing the `libexec/rbenv` file, by running another experiment.

### Experiment- which directory does `"$PWD"` resolve to?

I update my `foo` script to be the following:

```
#!/usr/bin/env bash

echo "$PWD"
```

I then run it from its home directory:

```
$ ./foo

/Users/myusername/Workspace/OpenSource
```

Then, I `cd` up one directory and re-run the same script:

```
$ cd ..

$ ./OpenSource/foo

/Users/richiethomas/Workspace
```

After we `cd ..`, we no longer see `/OpenSource` at the end of the `echo`'ed output.  This means that the value of `"$PWD"` depends on where the env var is printed from, **not** the location of the script that invokes it.

### Resolving the canonical filepath

```
while [ -n "$path" ]; do
...
done
```

In other words, while the length of our `path` local variable is greater than zero, we do...something.

That something is contained in the next block of code:

```
cd "${path%/*}"
local name="${path##*/}"
path="$(resolve_link "$name" || true)"
```

From [DevHints.io's guide to `bash`](https://web.archive.org/web/20230423012642/https://devhints.io/bash){:target="_blank" rel="noopener"}, we see that `%/*` in parameter expansion is often used to get the directory in which a file lives.  Example:

```
str="/path/to/foo.cpp"
echo "${str%/*}"            # /path/to
```

So we take the value of `path` (which is initialized to the first argument given to `abs_dirname`, presumably a `path/to/file`), and we `cd` into its directory (i.e. `path/to/`).

In the same DevHints.io link, we see that `##*/` is often used on a filepath to get **just** the filename itself, shaving off the directory in which it lives:

```
str="/path/to/foo.cpp"
echo "${str##*/}"           # foo.cpp
```

So on the 2nd line of the `while` loop, we create a local variable called `name`.

Lastly, we call `resolve_link "$name"` to see whether the filename stored in `"$name"` is a symlink or not.  Now we see our `resolve_link` function in-use.

If the file represented by `"$name"` is a symlink, then we store the name of the file it points to in `path` and perform another iteration of the `while` loop (since `[ -n "$path" ]` is still true as long as `path` is non-empty).  If it's not a symlink, `resolve_link "$name"` will return an empty string, the `while` condition will become falsy, and we will exit out of the loop.


At this point, we can conclude that the `abs_dirname` function declared in the `else` block is functionally equivalent to the same function declared in the `if` block, in which case the goal is to resolve any symlinks to their canonical, non-symlink file.

### Why the need for `|| true`?

I'm confused why the `|| true` is necessary. If I pass a non-symlink file to `resolve_link`, the result will have a length of 0, as we saw in our symlink experiment above.  If that is the case, I'm not sure why we need to replace that result with a different result whose length is also 0.  Why can't we just do the following?

```
while [ -n "$path" ]; do
  cd "${path%/*}"
  local name="${path##*/}"
  path="$(resolve_link "$name")"
done
```

I Google `bash "|| true"`, and I see a StackOverflow post with [this answer](https://unix.stackexchange.com/a/325727/142469){:target="_blank" rel="noopener"}:

> The reason for this pattern is that maintainer scripts in Debian packages tend to start with `set -e`, which causes the shell to exit as soon as any command (strictly speaking, pipeline, list or compound command) exits with a non-zero status. This ensures that errors don't accumulate: as soon as something goes wrong, the script aborts.
>
> In cases where a command in the script is allowed to fail, adding `|| true` ensures that the resulting compound command always exits with status zero, so the script doesn't abort. For example, removing a directory shouldn't be a fatal error (preventing a package from being removed); so we'd use
>
> `rmdir ... || true`
>
> since `rmdir` doesn't have an option to tell it to ignore errors.

So even though `$path` resolves to an empty value, the `resolve_link` function could still end up triggering an error, which would cause the script to exit due to our use of `set -e` at the beginning of the script.  We don't want that, so we gracefully handle any potential error with `|| true`.

### Wrapping up the `abs_dirname` function

So we were right- the purpose of the `while` link is to allow us to keep `cd`ing until we've arrived at the real, non-symlink home of the command represented by the `$name` variable (in our case, `rbenv`).  When that happens, we exit the `while` loop and run the last two lines in the function:

```
pwd
cd "$cwd"
```

`pwd` stands for `print working directory`, which means we `echo` the directory we're currently in, after having `cd`'ed into the canonical .  After we `echo` that, we `cd` back into the directory we were in before we started the `while` loop.

The purpose here is to `echo` the current directory, so that this can be captured by command substitution, without moving the user to a new directory as a side effect of calling the function.

### "Return values" from `bash` functions

Remember, the return value of a `bash` function is **not** the result of the last line of code in the function.  Technically, it's the exit code of the function.  The *output* of a function (i.e. what you can capture via command substitution) is whatever is `echo`'ed while inside the function.

When I Google "bash return value of a function", the first result I see is [a blog post in LinuxJournal.com](https://web.archive.org/web/20220718223538/https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.  Among other things, it tells me:

- "Bash functions, unlike functions in most programming languages do not allow you to return a value to the caller.  When a bash function ends its return value is its status: zero for success, non-zero for failure."
- "To return values, you can:
  - set a global variable with the result, or
  - use command substitution, or
  - pass in the name of a variable to use as the result variable."

Let's try each of these out:

### Experiment- setting a global variable inside a function

I create a script with the following contents:

```
#!/usr/bin/env bash

foo() {
  myVarName="Hey there"
}

echo "value before: $myVarName"     # should be empty

foo

echo "value after: $myVarName"      # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before:
value after: Hey there
```

So it looks like, when we don't make a variable local inside a function, its scope does indeed become global, and we can access it outside the function.

### Experiment- using command substitution to return a value from a function

I update my script to read as follows:

```
#!/usr/bin/env bash

foo() {
  echo "Hey there"
}

echo "value before function call: $myVarName" # should be empty

myVarName=$(foo)

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

So by using command substitution (aka the `"$( ... )"` syntax), we can capture anything `echo`'ed from within the function.

### Experiment- passing in the name of a variable to use

I update the script one last time to read as follows:

```
#!/usr/bin/env bash

foo() {
  local varName="$1"
  local result="Hey there"
  eval $varName="'$result'"
}

echo "value before function call: $myVarName" # should be empty

foo myVarName

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

Credit for these experiments goes to [the LinuxJournal link from earlier](https://web.archive.org/web/20230326152537/https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That was a lot of analysis.  In the end, the giant `if/else` block we looked at is nothing more than a way to define the `abs_dirname` function.  There were two ways we could have defined it:

 - One more performant way, using `readlink` or `greadlink` (depending on whether the user had already installed GNU coreutils on their machine), or:
 - One less performant way, where we iteratively `cd` into the directory of the given filename and resolved its filepath to account for a possible symlink.

 Let's move on.
