Before we start diving into the code for this file, let's look at its Github history.

## [Github History](https://github.com/rbenv/rbenv/pull/528){:target="_blank" rel="noopener"}

According to the PR which introduced this file (link above):

> The most time spent in rbenv execution is resolving paths to their absolute representations without symlinks. Manually doing this in bash is slow.
>
> By dynamically loading a compiled bash builtin, we can access the `realpath` POSIX C function which does exactly what we need and is fast.
>
> If dynamic loading fails, rbenv will still continue working as before (will fall back to shell implementation).

And if we look at some of the commit names in this PR, we the following:

> Speed up realpath() with dynamically loaded C extension

So the goal here is to replace the pre-installed `realpath` command on our machine with one which is potentially faster.  If we recall, the job of the `realpath` command is to continuously follow any symlinks of a filename until we have the canonical filepath.

Let's now move on to the code.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/src/configure){:target="_blank" rel="noopener"}

We've seen the `bash` shebang and the setting of "exit-on-first-error" mode before, so we won't dwell on those two lines of code.

### Storing the current directory

the first line of code is:

```
src_dir="${0%/*}"
```

Here we're creating a variable named `src_dir`, and setting it equal to the directory containing the current `configure` file.

### Detecting the user's C compiler

Next block of code:

```
if [ -z "$CC" ]; then
  if type -p gcc >/dev/null; then
    CC=gcc
  else
    echo "warning: gcc not found; using CC=cc" >&2
    CC=cc
  fi
fi
```

If the value of the `CC` environment variable is empty, then we execute the code inside the block.

The first thing inside that block is another `if` check, this time to see whether `type -p gcc` succeeds (i.e. returns a 0 exit code).  We recognize `type -p` as a way to check whether a path to the named program exists, which by implication tells us whether that program is installed on the machine.  So we check whether `gcc` is installed on the machine.  If it is, we do one thing.  If it's not, we do another.

FYI, when I run `type -p gcc` in my terminal, I see:

```
$ type -p gcc

gcc is /usr/bin/gcc
```

Your output may be different, depending on the machine you run this command on.

Since `gcc` is installed on my machine, we can expect the `CC` variable to equal the string "gcc" when I run the `configure` script.

#### What is GCC?

According to [GNU's homepage](https://web.archive.org/web/20221119003936/https://gcc.gnu.org/){:target="_blank" rel="noopener"}, GCC stands for "GNU Compiler Collection":

> GCC was originally written as the compiler for the GNU operating system.

In other words, it takes a program written in C (or C++, or Objective-C, etc.) and translates it into a binary file that your computer can execute.

### Aborting if no C compiler is found

Next block of code:

```
if ! type -p "$CC" >/dev/null; then
  echo "aborted: compiler not found: $CC" >&2
  exit 1
fi
```

Here we check if our `$CC` variable corresponds to a program that's installed on our machine.  The value will either be `gcc`, `cc`, or whatever value the user passed into the `configure` script themselves.

If no compiler program is found, we print an error message to STDERR and exit.

### Detecting the host operating system

Next block of code:

```
case "$(uname -s)" in
Darwin* )
  host_os="darwin$(uname -r)"
  ;;
FreeBSD* )
  host_os="freebsd$(uname -r)"
  ;;
OpenBSD* )
  host_os="openbsd$(uname -r)"
  ;;
* )
  host_os="linux-gnu"
esac
```

We perform a case statement based on the output of a command named `uname`.  Here's its `man` entry:

```
UNAME(1)                                                                     General Commands Manual                                                                    UNAME(1)

NAME
     uname – display information about the system

SYNOPSIS
     uname [-amnoprsv]

DESCRIPTION
     The uname command writes the name of the operating system implementation to standard output.  When options are specified, strings representing one or more system
     characteristics are written to standard output.

     The options are as follows:

     -a      Behave as though the options -m, -n, -r, -s, and -v were specified.

     -m      Write the type of the current hardware platform to standard output.  (make(1) uses it to set the MACHINE variable.)

     -n      Write the name of the system to standard output.

     -o      This is a synonym for the -s option, for compatibility with other systems.

     -p      Write the type of the machine processor architecture to standard output.  (make(1) uses it to set the MACHINE_ARCH variable.)

     -r      Write the current release level of the operating system to standard output.

     -s      Write the name of the operating system implementation to standard output.

     -v      Write the version level of this release of the operating system to standard output.

     If the -a flag is specified, or multiple flags are specified, all output is written on a single line, separated by spaces.

...
```

We see that `uname` prints some operating system info.  I try `uname -s` in my terminal, and get the following:

```
$ uname -s

Darwin
```

OK cool, pretty simple.  So our `case` statement switches depending on the name of the user's OS.

If the os name starts with "Darwin" (as it does in my case), then we run the command `host_os="darwin$(uname -r)"`.  This creates a variable named `host_os` and sets it equal to `darwin$(uname -r)`, which in my case resolves to `darwin21.6.0`.  So just concatenating the OS name to its version number.

The other two non-default branches of the case statement look almost identical, except for the name of the OS that we prepend to the version number:

 - If the user's OS is "FreeBSD", we prepend "freebsd".
 - If it's "OpenBSD", we prepend "openbsd".

The default behavior in the catch-all case at the end is to set `host_os` to a hard-coded value, `"linux-gnu"`.

### Populating more variables

Next line of code:

```
eval "$("$src_dir"/shobj-conf -C "$CC" -o "$host_os")"
```

On my machine, this will translate to:

```
eval "$(./src/shobj-conf -C gcc -o darwin21.6.0)"
```

So we're running the script `./src/shobj-conf` via command substitution, passing it some flags (i.e. `-C gcc` and `-o darwin21.6.0`), and running `eval` on whatever comes back from running that script.

What is `shobj-conf`?  If we open it up, at the top we see:

```
# shobj-conf -- output a series of variable assignments to be substituted
#		into a Makefile by configure which specify system-dependent
#		information for creating shared objects that may be loaded
#		into bash with `enable -f'
```

So it prints out a bunch of variable assignments, which are then plugged into our `Makefile.in` file to produce a file named `Makefile`.  Then later (specifically [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23){:target="_blank" rel="noopener"}), we'll use the `enable -f` command to load the result of the `Makefile` (i.e. a file named `libexec/rbenv-realpath.dylib`) into our code.

Reading the above description at the top of `shobj-conf` is enough for now.  We see just below the above description that the author of this file is Chet Ramey, so I'm reasonably sure that RBENV's copy of this file was borrowed wholesale from another source.  Reading it line-by-line would require a lot of time and effort, so let's skip that script for now.

But what does that script actually print out when we run it?  What is it that we're `eval`ing inside the parentheses?  To find out, let's actually run `./src/shobj-conf -C gcc -o darwin21.6.0`:

```
$ ./src/shobj-conf -C gcc -o darwin21.6.0
SHOBJ_CC='gcc'
SHOBJ_CFLAGS='-fno-common'
SHOBJ_LD='${CC}'
SHOBJ_LDFLAGS='-dynamiclib -dynamic -undefined dynamic_lookup '
SHOBJ_XLDFLAGS=''
SHOBJ_LIBS=''
SHLIB_XLDFLAGS='-dynamiclib  -install_name $(libdir)/`echo $@ | sed "s:\..*::"`.$(SHLIB_MAJOR).$(SHLIB_LIBSUFF) -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
SHLIB_LIBS='-lncurses'
SHLIB_DOT='.'
SHLIB_LIBPREF='lib'
SHLIB_LIBSUFF='dylib'
SHLIB_LIBVERSION='$(SHLIB_MAJOR)$(SHLIB_MINOR).$(SHLIB_LIBSUFF)'
SHLIB_DLLVERSION='$(SHLIB_MAJOR)'
SHOBJ_STATUS='supported'
SHLIB_STATUS='supported'
```

So the above output is what we pass to `eval`.  It sets a bunch of variables, which (if we skip ahead a bit) we see are referenced in the subsequent `sed` command (see below), as well as in `Makefile.in`.  We'll find out later that the purpose of the `sed` command is to insert the above variable values into `Makefile.in`, and then use that updated `Makefile.in` to generate a file named `Makefile`.  From there, we can run the `make` command and build our faster `realpath` function.

We're also going to skip the discussion of what each variable is responsible for in the Makefile.  If you're curious about that, check out [this link](https://web.archive.org/web/20220716090040/https://tiswww.case.edu/php/chet/readline/README){:target="_blank" rel="noopener"}, which defines what most of the variables do.

### Generating the Makefile

The last block of code in `configure` is that `sed` command we mentioned earlier:

```
sed "
  s#@CC@#${CC}#
  s#@CFLAGS@#${CFLAGS}#
  s#@LOCAL_CFLAGS@#${LOCAL_CFLAGS}#
  s#@DEFS@#${DEFS}#
  s#@LOCAL_DEFS@#${LOCAL_DEFS}#
  s#@SHOBJ_CC@#${SHOBJ_CC}#
  s#@SHOBJ_CFLAGS@#${SHOBJ_CFLAGS}#
  s#@SHOBJ_LD@#${SHOBJ_LD}#
  s#@SHOBJ_LDFLAGS@#${SHOBJ_LDFLAGS}#
  s#@SHOBJ_XLDFLAGS@#${SHOBJ_XLDFLAGS}#
  s#@SHOBJ_LIBS@#${SHOBJ_LIBS}#
  s#@SHOBJ_STATUS@#${SHOBJ_STATUS}#
" "$src_dir"/Makefile.in > "$src_dir"/Makefile
```

It looks intimidating, but it's actually pretty straightforward:

 - The `sed` command, which we talked about before.  It's a command to read in a certain file, perform actions on each line of that file, and output the results to a new file.
 - A single (although rather long) string with a bunch of nearly-identical commands in it.  These commands are called ["scripts"](https://web.archive.org/web/20220611195519/https://www.gnu.org/software/sed/manual/html_node/sed-script-overview.html){:target="_blank" rel="noopener"}.
 - A filename representing the input to run these commands against.  In this case, the filename is `Makefile.in`.
 - The `>` symbol to redirect the output from `STDOUT` to another destination
 - A 2nd filename to act as the destination which the output gets redirected to.  In this case, that's a file named `Makefile`.

What does each of those `sed` scripts do?  One clue is that they all share nearly the exact same format:

 - an `s#` at the beginning.
 - a reference to a variable, surrounded by ampersands on each side.
 - another `#`.
 - a parameter expansion operation (ex.- `${CC}` or `${CFLAGS}`)
 - a final `#`.

Each command is a search-and-replace operation, except instead of using `/` syntax (ex.- `s/@CC@/${CC}/`), we use `#` as a delimiter (ex.- `s#@CC@#${CC}#`).  Using a non-slash character as a delimiter is permitted, according to [the docs for `sed`](https://web.archive.org/web/20230714142751/http://www.gnu.org/software/sed/manual/sed.html){:target="_blank" rel="noopener"}:

> `\%regexp%`
>
> (The % may be replaced by any other single character.)
>
> This also matches the regular expression regexp, but allows one to use a different delimiter than `/`. This is particularly useful if the regexp itself contains a lot of slashes, since it avoids the tedious escaping of every `/`.

Additionally, the `man` page for `sed` adds the following examples:

```
EXAMPLES
     Replace 'bar' with 'baz' when piped from another command:

           echo "An alternate word, like bar, is sometimes used in examples." | sed 's/bar/baz/'

     Using backlashes can sometimes be hard to read and follow:

           echo "/home/example" | sed  's/\/home\/example/\/usr\/local\/example/'

     Using a different separator can be handy when working with paths:

           echo "/home/example" | sed 's#/home/example#/usr/local/example#'

     Replace all occurances of 'foo' with 'bar' in the file test.txt, without creating a backup of the file:

           sed -i '' -e 's/foo/bar/g' test.txt
```

The above implies that we expect that our variables may contain the `/` character, and are therefore using `#` as a delimiter to avoid any conflicts.

Let's quickly test out with an experiment.

#### Experiment- non-traditional delimiters in `sed`

I have a string:

```
Hello/world
```

I want to replace it with:

```
Hola/mundo
```

In my terminal, I try the following:

```
bash-3.2$ echo "Hello/world" | sed "s/Hello/world/Hola/mundo/"

sed: 1: "s/Hello/world/Hola/mundo/": bad flag in substitute command: 'H'
```

Here, `sed` can't tell the difference between the use of `/` as a delimiter, vs. the use of the literal `/` character in my string.

If I tell `sed` to use `#` as a delimiter instead, I get the following:

```
bash-3.2$ echo "Hello/world" | sed "s#Hello/world#Hola/mundo#"

Hola/mundo
```

This time, it works correctly.

Will this replace **all** instances of `Hello/world`, or just the first one it finds?  I run the following to find out:

```
bash-3.2$ echo "Hello/world Hello/world" | sed "s#Hello/world#Hola/mundo#"

Hola/mundo Hello/world
```

Looks like it just replaces the first example it finds.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's take the first of the `sed` scripts as an example:

```
s#@CC@#${CC}#
```
Here we're replacing the first instance of `@CC@` that we find with the value that `$CC` resolves to.  If we look at `Makefile.in`, the first line we see is:

```
CC = @CC@
```

Given we already know that `$CC` variable evaluates to `"gcc"` on my machine, we can expect the first line of our real `Makefile` to be:

```
CC = gcc
```

And in fact, that's what we see when we run the `./src/configure` script.

The `$CC` variable was instantiated by us, at the beginning of the `configure` script.  But many of the variables in the `sed` search-and-replace scripts will be instantiated by the `eval` line we ran just prior to `sed`:

```
eval "$("$src_dir"/shobj-conf -C "$CC" -o "$host_os")"
```

Any variable which is not populated by either us or by `shobj-conf` will be blank.

If we look at the first 16 lines of `Makefile.in`, it looks like this:

```
CC = @CC@

CFLAGS = @CFLAGS@
LOCAL_CFLAGS = @LOCAL_CFLAGS@
DEFS = @DEFS@
LOCAL_DEFS = @LOCAL_DEFS@

CCFLAGS = $(DEFS) $(LOCAL_DEFS) $(LOCAL_CFLAGS) $(CFLAGS)

SHOBJ_CC = @SHOBJ_CC@
SHOBJ_CFLAGS = @SHOBJ_CFLAGS@
SHOBJ_LD = @SHOBJ_LD@
SHOBJ_LDFLAGS = @SHOBJ_LDFLAGS@
SHOBJ_XLDFLAGS = @SHOBJ_XLDFLAGS@
SHOBJ_LIBS = @SHOBJ_LIBS@
SHOBJ_STATUS = @SHOBJ_STATUS@
```

And when we run `configure` and inspect the resulting `Makefile`, we see we've transformed these lines into this:

```
CC = gcc

CFLAGS =
LOCAL_CFLAGS =
DEFS =
LOCAL_DEFS =

CCFLAGS = $(DEFS) $(LOCAL_DEFS) $(LOCAL_CFLAGS) $(CFLAGS)

SHOBJ_CC = gcc
SHOBJ_CFLAGS = -fno-common
SHOBJ_LD = ${CC}
SHOBJ_LDFLAGS = -dynamiclib -dynamic -undefined dynamic_lookup
SHOBJ_XLDFLAGS =
SHOBJ_LIBS =
SHOBJ_STATUS = supported
```

Again, your results may look different if you run the script on a machine with different architecture from mine.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on to the next file.
