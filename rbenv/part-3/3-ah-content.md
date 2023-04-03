

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/src/configure)

First block of code:

```
#!/usr/bin/env bash
set -e
```

We're already familiar with this syntax.  It's the `bash` shebang, followed by `set -e` to tell the shell to exit immediately upon the first error it encounters.

Next block:

```
src_dir="${0%/*}"
```

Here we're creating a variable named `src_dir`, and setting it equal to (I think) the directory containing the current `configure` file.  I think I recognize the syntax to shave off the last "/" character and everything after it from previous `bash` scripts I've inspected, but I want to verify this hypothesis, so I add a log line and re-run the file:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-121pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

When I run the file, I get:

```
$ ./src/configure

0: ./src/configure
src_dir: ./src
```

Yep, so we take `${0}` and add parameter expansion syntax (i.e. `%/*`) to it, which shaves off the last "/" character and everything after it.

I remove the `echo` statements I added, and continue on.  Next block of code:

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

If the value of the `CC` environment variable is empty, then we execute the code inside the block.  The first thing inside that block is another `if` check, this time to see whether `type -p gcc` returns anything.  We recognize `type -p` as a way to check whether a path to the named program exists, which by implication tells us whether that program is installed on the machine.  So we check whether `gcc` is installed on the machine.  If it is, we do one thing.  If it's not, we do another.

What is `gcc`?  According to [GNU's homepage](https://web.archive.org/web/20221119003936/https://gcc.gnu.org/), GCC stands for "GNU Compiler Collection".  The page goes on to say that "GCC was originally written as the compiler for the GNU operating system."  It doesn't say that original mission has changed, so I'm guessing this is still true.

So if the GNU compiler exists on the user's machine, then we set the `CC` variable equal to the string "gcc".  Otherwise, we echo a warning string to STDERR, and we set `CC` equal to the string "cc".  I'm a bit curious where "gcc" is not used, and I know I'll have to Google for this if I want an answer to this question.  But I suspect it'll be easier to ask Google where "gcc" *is* used, rather than where it's *not* used.  So I Google "where is gcc used", and I see the following without even clicking through to the result:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-124pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

So `gcc` is used to compile C programs on a Linux machine (such as my UNIX Macbook).  That explains why I see output on the screen when I run the aforementioned `type -p` command:

```
$ type -p gcc

gcc is /usr/bin/gcc
```

Therefore we can expect the `CC` variable to equal the string "gcc" when we run our `configure` script.  To check this, I add more loglines...

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-126pm.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</center>

... and re-run it:

```
$ ./src/configure

CC: gcc
```

Just as we suspected- our compiler is "gcc".  I remove the loglines and continue on.

Next block of code:

```
if ! type -p "$CC" >/dev/null; then
  echo "aborted: compiler not found: $CC" >&2
  exit 1
fi
```

Here we check if we've successfully managed to set the `CC` variable (or if it was already previously set).  If we still don't have a C compiler, we print an error message to STDERR and exit.

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

We perform a case statement based on the output of a command named `uname`, which I'm not familiar with.  Here's its `man` entry:

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

So `uname` prints some operating system info.  I try both `uname` and `uname -s` in my terminal, and they print the same thing:

```
$ uname

Darwin

$ uname -s

Darwin
```

I then try a few of the other flags, and I see different info:

```
$ uname -a

Darwin myusername-16mbpr19.local 22.3.0 Darwin Kernel Version 22.3.0: Mon Jan 30 20:42:11 PST 2023; root:xnu-8792.81.3~2/RELEASE_X86_64 x86_64

$ uname -m

x86_64

$ uname -n

myusername-16mbpr19.local

$ uname -p

i386

$ uname -r

22.3.0

$ uname -v

Darwin Kernel Version 22.3.0: Mon Jan 30 20:42:11 PST 2023; root:xnu-8792.81.3~2/RELEASE_X86_64
```

OK cool, pretty simple.  So our `case` statement switches depending on the name of the user's OS.

If the value is "Darwin" (as it is in my case), then we run the command `host_os="darwin$(uname -r)"`.  This creates a variable named `host_os` and sets it equal to "darwin$(uname -r)", which in my case resolves to `darwin21.6.0`.  So just prepending the lower-cased version of the OS name to the OS release / version number.  The other two non-default branches of the case statement look similar.  If the user's OS is "FreeBSD", we prepend "freebsd", and if it's "OpenBSD", we prepend "openbsd".  The default behavior in the catch-all case at the end is to set `host_os` to a hard-coded value, "linux-gnu".

(stopping here; 1287 words)

Next line of code:

```
eval "$("$src_dir"/shobj-conf -C "$CC" -o "$host_os")"
```

I *think* that, on my machine, this will translate to:

```
eval "$(./src/shobj-conf -C gcc -o darwin21.6.0)"
```

I add some loglines to the `configure` file to see if I'm right:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-143pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

When I run the file, I get:

```
$ ./src/configure

command to eval:
./src/shobj-conf -C gcc -o darwin21.6.0
```

So what actually got printed was:

```
./src/shobj-conf -C gcc -o darwin21.6.0
```

Meaning the thing being `eval`'ed is:

```
eval "$(./src/shobj-conf -C gcc -o darwin21.6.0)"
```

I was right!

OK, but what does that command actually print out when it runs?  What is it that we're `eval`ing inside the parentheses?  To find out, I have to actually run `./src/shobj-conf -C gcc -o darwin21.6.0` on my machine.

When I do so, I get:

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

So the above output is what we're `eval`ing.  It looks like a bunch of environment variables are getting set, so that looks like the `eval` line is what actually sets these env vars in our shell.

I notice that a greater-than-zero number of the env vars referenced in the above output are also referenced in the subsequent `sed` command (see below), as well as in `Makefile.in`.  And we already know that the output of the `configure` script is an actual `Makefile`.  So I'm guessing the purpose of the `sed` command is to search `Makefile.in` for references with the same name as the env vars, and replace those references with the actual values stored in the env vars.  And those values come from `eval`ing the printed env var definitions that we see above.

(stopping here; 1557 words)

But back to the `shobj-conf` command.  Since it's prepended with the `src_dir` variable, I'm assuming that it corresponds to a filepath inside that directory.  And I do in fact find a script named `shobj-conf` in that directory, so I feel safe in assuming that we're not running (for example) a shell builtin.  The bad news is, the `shobj-conf` script is almost 600 lines of code long.  The good news is, it appears to mostly contain a single huge case statement.  Which means that we can tell in broad strokes what it does, based on what the case statement matches against.

More good news- the beginning of the file is a comments section describing what it does:

```
#! /bin/sh
#
# shobj-conf -- output a series of variable assignments to be substituted
#		into a Makefile by configure which specify system-dependent
#		information for creating shared objects that may be loaded
#		into bash with `enable -f'
#
# usage: shobj-conf [-C compiler] -c host_cpu -o host_os -v host_vendor
#
# Chet Ramey
# chet@po.cwru.edu

#   Copyright (C) 1996-2014 Free Software Foundation, Inc.
#
#   This file is part of GNU Bash, the Bourne Again SHell.
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
```

In addition to the description of what this file does, I see it's also authored by someone named Chet Ramey, and is part of the Free Software foundation.  There's also the comment that "This file is part of GNU Bash, the Bourne Again Shell".  All this makes me wonder whether this script was copied from somewhere else, and included here.

I search for the commit which introduced this file, and I find it [here](https://github.com/rbenv/rbenv/pull/528/commits/8facb3b3a790fd275a4e8d5f4de474bbd837c040), along with this description:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-147pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Looks like the file was borrowed from the bash source code.  I was actually curious about whether these files were different, so I found [the location of the source code](https://ftp.gnu.org/gnu/bash/) on GNU's website, searched for "bash-3.2.48", and downloaded the ".tar.gz" compressed file.  I unzipped it and found the "shobj-conf" file, and ran `sha256sum <path/to/file>` on it.  I then did the same with the file inside RBENV, to see if the two files generated the same checksum.  Turns out they don't, however I suspect it's because one of the files has some indentation that the other does not.  I can't prove this without diffing each file line-by-line, and that seems like overkill for this question.

One of the things I was wondering is what each of these environment variables does, what each one is responsible for.  While Googling for "shopj-conf", I came across [this link](https://web.archive.org/web/20220716090040/https://tiswww.case.edu/php/chet/readline/README), which references some (but not all) of the names used for our env vars:

```
In the stanza for your operating system-compiler pair, you will need to
define several variables.  They are:

SHOBJ_CC	The C compiler used to compile source files into shareable
		object files.  This is normally set to the value of ${CC}
		by configure, and should not need to be changed.

SHOBJ_CFLAGS	Flags to pass to the C compiler ($SHOBJ_CC) to create
		position-independent code.  If you are using gcc, this
		should probably be set to `-fpic'.

SHOBJ_LD	The link editor to be used to create the shared library from
		the object files created by $SHOBJ_CC.  If you are using
		gcc, a value of `gcc' will probably work.

SHOBJ_LDFLAGS	Flags to pass to SHOBJ_LD to enable shared object creation.
		If you are using gcc, `-shared' may be all that is necessary.
		These should be the flags needed for generic shared object
		creation.

SHLIB_XLDFLAGS	Additional flags to pass to SHOBJ_LD for shared library
		creation.  Many systems use the -R option to the link
		editor to embed a path within the library for run-time
		library searches.  A reasonable value for such systems would
		be `-R$(libdir)'.

SHLIB_LIBS	Any additional libraries that shared libraries should be
		linked against when they are created.

SHLIB_LIBPREF	The prefix to use when generating the filename of the shared
		library.  The default is `lib'; Cygwin uses `cyg'.

SHLIB_LIBSUFF	The suffix to add to `libreadline' and `libhistory' when
		generating the filename of the shared library.  Many systems
		use `so'; HP-UX uses `sl'.

SHLIB_LIBVERSION The string to append to the filename to indicate the version
		of the shared library.  It should begin with $(SHLIB_LIBSUFF),
		and possibly include version information that allows the
		run-time loader to load the version of the shared library
		appropriate for a particular program.  Systems using shared
		libraries similar to SunOS 4.x use major and minor library
		version numbers; for those systems a value of
		`$(SHLIB_LIBSUFF).$(SHLIB_MAJOR)$(SHLIB_MINOR)' is appropriate.
		Systems based on System V Release 4 don't use minor version
		numbers; use `$(SHLIB_LIBSUFF).$(SHLIB_MAJOR)' on those systems.
		Other Unix versions use different schemes.

SHLIB_DLLVERSION The version number for shared libraries that determines API
		compatibility between readline versions and the underlying
		system.  Used only on Cygwin.  Defaults to $SHLIB_MAJOR, but
		can be overridden at configuration time by defining DLLVERSION
		in the environment.

SHLIB_DOT	The character used to separate the name of the shared library
		from the suffix and version information.  The default is `.';
		systems like Cygwin which don't separate version information
		from the library name should set this to the empty string.

SHLIB_STATUS	Set this to `supported' when you have defined the other
		necessary variables.  Make uses this to determine whether
		or not shared library creation should be attempted.
```

The variables whose names match (along with their definitions from the above link) are:

 - `SHLIB_STATUS`: Set this to `supported' when you have defined the other necessary variables.  `make` uses this to determine whether or not shared library creation should be attempted.

 - `SHOBJ_CFLAGS`: Flags to pass to the C compiler ($SHOBJ_CC) to create position-independent code.  If you are using gcc, this should probably be set to `-fpic'.

 - `SHOBJ_LD`: The link editor to be used to create the shared library from the object files created by $SHOBJ_CC.  If you are using gcc, a value of `gcc' will probably work.

 - `SHOBJ_LDFLAGS`: Flags to pass to SHOBJ_LD to enable shared object creation.  If you are using gcc, `-shared' may be all that is necessary.  These should be the flags needed for generic shared object creation.

 - `SHLIB_XLDFLAGS`: Additional flags to pass to SHOBJ_LD for shared library creation.  Many systems use the -R option to the link editor to embed a path within the library for run-time library searches.  A reasonable value for such systems would be `-R$(libdir)'.

 - `SHLIB_LIBS`: Any additional libraries that shared libraries should be linked against when they are created.

 - `SHLIB_DOT`: The character used to separate the name of the shared library from the suffix and version information.  The default is `.'; systems like Cygwin which don't separate version information from the library name should set this to the empty string.

 - `SHLIB_LIBPREF`: The prefix to use when generating the filename of the shared library.  The default is `lib'; Cygwin uses `cyg'.

 - `SHLIB_LIBSUFF`: The suffix to add to `libreadline' and `libhistory' when generating the filename of the shared library.  Many systems use `so'; HP-UX uses `sl'.

 - `SHLIB_LIBVERSION`: The string to append to the filename to indicate the version of the shared library.  It should begin with $(SHLIB_LIBSUFF), and possibly include version information that allows the run-time loader to load the version of the shared library appropriate for a particular program.  Systems using shared libraries similar to SunOS 4.x use major and minor library version numbers; for those systems a value of `$(SHLIB_LIBSUFF).$(SHLIB_MAJOR)$(SHLIB_MINOR)' is appropriate.  Systems based on System V Release 4 don't use minor version numbers; use `$(SHLIB_LIBSUFF).$(SHLIB_MAJOR)' on those systems.  Other Unix versions use different schemes.

 - `SHLIB_DLLVERSION`: The version number for shared libraries that determines API compatibility between readline versions and the underlying system.  Used only on Cygwin.  Defaults to $SHLIB_MAJOR, but can be overridden at configuration time by defining DLLVERSION in the environment.
```


So the RBENV version mentions every variable which [the README file](https://tiswww.case.edu/php/chet/readline/README) mentions, but it also mentions some variables which aren't in the README:

 - SHOBJ_XLDFLAGS
 - SHOBJ_LIBS
 - SHOBJ_STATUS

The README isn't the source of the RBENV script- it's mostly valuable (at least to my beginner eyes) because it has these definitions next to the env var names.  Nevertheless, since the original source code doesn't have those same definitions, we're dependent on the README for quick and (probably) accurate definitions for what these do.

OK, I don't understand the definitions of any of the env vars, probably because I don't understand very much about C compilation.  Oh well, it was worth a try.

The last block of code in `configure` is that `sed` command we touched on earlier:

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

It looks like a beast, but it's actually pretty straightforward:

`sed`
A single big-long string with a bunch of nearly-identical commands in it
The input to run these commands against (in this case, an input file named "Makefile.in"
The ">" symbol to redirect the output from STDOUT to another destination
A 2nd filename to act as the destination which the output gets redirected to (in this case, a file named "Makefile")

Now the only thing left is to analyze what each of those nearly-identical `sed` commands is doing.

(stopping here; 2578 words)

Let's take the first of the `sed` commands as an example:

```
  s#@CC@#${CC}#
```

By the way- I think each of these lines (which I've been referring to as "commands" until now) are actually called "scripts" [by those who know](https://web.archive.org/web/20220611195519/https://www.gnu.org/software/sed/manual/html_node/sed-script-overview.html).  To optimize for correctness, I'll switch to using this same terminology from now on.

This first script looks to me like a search-and-replace operation.  It starts with the "s" character, and contains a snippet of syntax which I know exists in "Makefile.in" (i.e. `@CC@`), followed by what looks like parameter expansion in bash (i.e. `${CC}`).  However, I would expect a search-and-replace `sed` operation to use the forward-slash character to delimit the "s", input line, and output line, as follows:

```
  s/@CC@/${CC}/
```

Is the "#" character just syntactic sugar for "/"?  Or is there a semantic difference between how the two characters work in `sed`?  Or am I totally wrong about the intent of the script, i.e. it's not doing search-and-replace at all?

To try and answer this question, I construct a [minimum-viable example](https://stackoverflow.com/help/minimal-reproducible-example) as follows:

 - I create a simple textfile named "foo.txt", which looks as follows:

```
foo
bar
baz
```

 - As a sanity check, I run the following command in the same directory as my "foo.txt" file:

```
$ sed 's/foo/bar/' foo.txt

bar
bar
baz
```

Great, the command works as expected so far.  This is our baseline.

 - Lastly, I replace the "/" characters in the above with "#" characters.  My hypothesis is that I'll see the same result:

```
$ sed 's#foo#bar#' foo.txt

bar
bar
baz
```

Yep, same result!  It's always possible that there are other effects taking place under-the-hood, which are not observable in this simple example.  But it looks like, whatever else may be happening, we've proved that the result to STDOUT is the same for both commands.  At least in this case.


Prior to trying this experiment, I looked for documentation to answer this question, but didn't find any.  I looked [here](https://web.archive.org/web/20221117074804/https://www.gnu.org/software/sed/manual/sed.html) (in GNU's main `sed` reference), and also [here](https://web.archive.org/web/20220912050851/https://www.gnu.org/software/sed/manual/html_node/The-_0022s_0022-Command.html) (in the specific section on the "s" command in `sed`).  In both cases, all results when `grep`'ing for the "#" character resulted in either a line of comment, a shebang, or some other irrelevant result.  I was unable to find any content related specifically to the replacement of "/" with "#" in a `sed` command.  Unfortunate!

However, I do find [this StackOverflow post](https://web.archive.org/web/20230319165757/https://unix.stackexchange.com/questions/389537/how-to-use-a-hash-as-a-delimiter-for-sed), and one of its answers refers to an entry in `sed`'s `man` page.  I look up that `man` page and search for "#", and find the following:

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

OK, cool!  So now we know a) that it is true that non-forward-slash separators can be used for `sed`, and also b) why a person might want to do so.  I'm not sure whether any of our env vars actually contain filepaths with "/" chars in them, but it seems entirely plausible that this would be the case.

So to wrap up our first command script:

```
  s#@CC@#${CC}#
```

Yes, we are in fact just replacing all instances of `@CC@` with the value that `$CC` resolves to.

Next script:

```
  s#@CFLAGS@#${CFLAGS}#
```

Here we're replacing the string `@CFLAGS@` with the value stored in the `$CFLAGS` env var.

Next script:

```
  s#@LOCAL_CFLAGS@#${LOCAL_CFLAGS}#
```

Again, here we're replacing the string `@LOCAL_CFLAGS@` with the value stored in the `$LOCAL_CFLAGS` env var.

To save time and avoid repetition, I scan ahead to see whether any of these scripts are doing something *other than* replacing text in the manner above.  I don't see anything to indicate a deviation from the pattern, so I think we can skip the rest of the `sed` scripts.

Next file.
