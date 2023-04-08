Again, let's start with the test file, `help.bats`.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/help.bats){:target="_blank" rel="noopener"}

After the shebang and the `test_helper` load, the first spec is:

```
@test "without args shows summary of common commands" {
  run rbenv-help
  assert_success
  assert_line "Usage: rbenv <command> [<args>]"
  assert_line "Some useful rbenv commands are:"
}
```

This is the happy-path test.  We run the command file, assert that the exit code is 0, and assert that the "Usage:" and "Some useful rbenv commands" lines both appear in STDOUT.

This is what appears when I type `rbenv help` in my console, a-la this first test case:

```
$ git push

Enumerating objects: 99, done.
Counting objects: 100% (99/99), done.
Delta compression using up to 12 threads
Compressing objects: 100% (94/94), done.
Writing objects: 100% (94/94), 9.73 MiB | 4.39 MiB/s, done.
Total 94 (delta 4), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (4/4), completed with 4 local objects.
To https://github.com/impostorsguides/impostorsguides.github.io.git
   312678c..afa5595  main -> main
~/Workspace/OpenSource/impostorsguides.github.io (main)  $ rbenv help
Usage: rbenv <command> [<args>]

Some useful rbenv commands are:
   commands    List all available rbenv commands
   local       Set or show the local application-specific Ruby version
   global      Set or show the global Ruby version
   shell       Set or show the shell-specific Ruby version
   install     Install a Ruby version using ruby-build
   uninstall   Uninstall a specific Ruby version
   rehash      Rehash rbenv shims (run this after installing executables)
   version     Show the current Ruby version and its origin
   versions    List installed Ruby versions
   which       Display the full path to an executable
   whence      List all Ruby versions that contain the given executable

See `rbenv help <command>' for information on a specific command.
For full documentation, see: https://github.com/rbenv/rbenv#readme
```

Next test case:

```
@test "invalid command" {
  run rbenv-help hello
  assert_failure "rbenv: no such command \`hello'"
}
```

This is a sad path case, for when the user types in an argument for a command that doesn't exist.  We assert that the exit code is non-zero, and that the feedback "rbenv: no such command..." appears in STDOUT.  I get this same result:

```
$ rbenv help foobar
rbenv: no such command `foobar'
```

Next test case:

```
@test "shows help for a specific command" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
# Summary: Says "hello" to you, from rbenv
# This command is useful for saying hello.
echo hello
SH

  run rbenv-help hello
  assert_success
  assert_output <<SH
Usage: rbenv hello <world>
This command is useful for saying hello.
SH
}
```

This is a pretty big test.  Let's break it up into pieces:

```
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
# Summary: Says "hello" to you, from rbenv
# This command is useful for saying hello.
echo hello
SH
```

Here we make a directory especially for this test that we're running, and then create a new executable command called `rbenv-hello`.  We add a fake shebang and some usage comments to the file, followed by a command to just echo 'hello'.  Basically just enough fake file content to mimic a real rbenv command file.

Next half of the test is:

```
  run rbenv-help hello
  assert_success
  assert_output <<SH
Usage: rbenv hello <world>
This command is useful for saying hello.
SH
```

We then run `rbenv help` plus the name of our fake command, assert that the exit code is 0, and that the output contains just the usage and summary comments from the file, without the shebang and without the executable logic of the command itself.

One interesting thing I notice is that the line starting with `# Summary:` is *not* part of the expected output.  Does this mean `rbenv help` strips that out?  That seems unexpected to me; I would think that a summary line would be useful context that someone running this command would want.  If we notice that is indeed happening during our perusal of the code, I might end up diving into the git history to find out why this was needed.

Next test:

```
@test "replaces missing extended help with summary text" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
# Summary: Says "hello" to you, from rbenv
echo hello
SH

  run rbenv-help hello
  assert_success
  assert_output <<SH
Usage: rbenv hello <world>
Says "hello" to you, from rbenv
SH
}
```

These tests are beefier than those of previous commands we've examined.  That's mostly because of the large multi-line heredoc strings which are necessary to test the output of a `help` command.

This test does something similar to (but not identical to) the previous test.  The difference is, this time the command includes the `# Summary:` comments, since it looks like this file's comments do not contain any extended explanation below the summary line.  So that summary is only included if no detailed explanation is given.  I guess that answers our question from the last spec!

Next spec:

```
@test "extracts only usage" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
# Summary: Says "hello" to you, from rbenv
# This extended help won't be shown.
echo hello
SH

  run rbenv-help --usage hello
  assert_success "Usage: rbenv hello <world>"
}
```

This test creates a test command with usage, summary, and extended description info.  It then runs `rbenv help` for this test command, but this time it also passes the `--usage` flag.  It then asserts that the output only contains the `usage` info.

I wanted to test this out, so I ran `rbenv help --usage rehash`, assuming that the `rehash` command would contain usage info.  However, it appears that it does not:

```
$ rbenv help --usage rehash

$
```

I tried another command (`global`), and this time it worked:

```
$ rbenv help --usage global

Usage: rbenv global <version>
```

TODO: make a PR for the `rehash` command which adds "Usage" comments?

Next test:

```
@test "multiline usage section" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
#        rbenv hi [everybody]
#        rbenv hola --translate
# Summary: Says "hello" to you, from rbenv
# Help text.
echo hello
SH

  run rbenv-help hello
  assert_success
  assert_output <<SH
Usage: rbenv hello <world>
       rbenv hi [everybody]
       rbenv hola --translate
Help text.
SH
}
```

This test makes another test command, this time with a multi-line "Usage" comment (as stated in the test description).  It then asserts that the `help` output includes both the entire "Usage" comment, and the description text, but not the "Summary" text.

Last spec is:

```
@test "multiline extended help section" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  cat > "${RBENV_TEST_DIR}/bin/rbenv-hello" <<SH
#!shebang
# Usage: rbenv hello <world>
# Summary: Says "hello" to you, from rbenv
# This is extended help text.
# It can contain multiple lines.
#
# And paragraphs.
echo hello
SH

  run rbenv-help hello
  assert_success
  assert_output <<SH
Usage: rbenv hello <world>
This is extended help text.
It can contain multiple lines.
And paragraphs.
SH
}
```

This spec does the same as the previous spec, but with a multi-line extended description instead of a multi-line usage comment.

Now onto the command file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help){:target="_blank" rel="noopener"}

First few lines of code are almost too obvious to repeat at this point:

```
#!/usr/bin/env bash
#
# Summary: Display help for a command
#
# Usage: rbenv help [--usage] COMMAND
#
# Parses and displays help contents from a command's source file.
#
# A command is considered documented if it starts with a comment block
# that has a `Summary:' or `Usage:' section. Usage instructions can
# span multiple lines as long as subsequent lines are indented.
# The remainder of the comment block is displayed as extended
# documentation.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

As usual, we have:

The bash shebang
The usage summary and description
The "exit on first error" setting
The "set verbose mode when RBENV_DEBUG is passed" setting

Next few lines of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --usage
  exec rbenv-commands
fi
```

Here again is our list of completions.  We have a bespoke completion (aka "--usage") specific to the "help" command, and then we print out all possible rbenv commands via the `rbenv-commands` command, because any rbenv command is also a valid argument to "rbenv help".

Next few lines of code:

```
command_path() {
  local command="$1"
  command -v rbenv-"$command" || command -v rbenv-sh-"$command" || true
}
```

Here we define a function named "command_path".  It sets a variable named "command", which is scoped locally to the function, and is set to the value "$1".  I'm pretty sure we've covered this before, but I'm actually not sure whether "$1" here resolves to the first argument provided to the "command_path" function, or to the "rbenv help" command itself.  I write a test script to find out:

```
#!/usr/bin/env bash

echo "arg 1 before function call: $1"

function foo() {
  local command="$1"
  echo "command: $command"
}

foo bar

echo "arg 1 after function call: $1"
```

The test script prints out the value of "$1" both inside the function and outside the function (before and after the function call).  Inside the script I call the function with the argument "bar", and outside the script I call the script itself with the argument "baz".  When I do so, I get the following:

```
~/Workspace/OpenSource (master)  $ ./foo/bar baz

arg 1 before function call: baz
command: bar
arg 1 after function call: baz
```
So "$1" inside the function is defined as the first argument provided to the function, but outside the function it's defined as the first arg provided to the script itself.

OK, so our `command_path` function takes the first arg it receives, and stores it as the variable "command".  Then we do the following:

```
  command -v rbenv-"$command" || command -v rbenv-sh-"$command" || true
```

We've seen this before- we first use `command -v` to find the path of a command named `rbenv-$command`, and send that to STDOUT.  For example, if we call `command_path foo`, we'd first check for the path of a command named `rbenv-foo`.  If there's no command by that name, we try to find the path of a command named `rbenv-sh-foo`.  If that's not found either, we simply send `true` to STDOUT (which has a length of zero).

Next block of code:

```
extract_initial_comment_block() {
  sed -ne "
    /^#/ !{
      q
    }
    s/^#$/# /
    /^# / {
      s/^# //
      p
    }
  "
}
```
Another function definition here, this time it's called `extract_initial_comment_block.  This function calls `sed` with the `-ne` flag, and passes a multi-line string.

I don't know anything about the `sed` command, so I do a bit of searching, starting with the `man` entry:

> The `sed` utility reads the specified files, or the standard input if no files are specified, modifying the input as specified by a list of commands.  The input is then written to the standard output.

The phrase "modifying the input as specified by a list of commands" is too abstract for me to really grok how this is used or why it's useful.  Luckily, further towards the bottom of the `man` entry is a list of examples of how the command can be used:

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

That's a bit better.  I try my own example in the terminal and verify it works as expected:

```
$ echo "foo bar baz" | sed "s/foo/quox/"

quox bar baz
```

I continue Googling to get a bit more context.  My previous experience with bash tells me that `sed` is one of the most commonly-used utilities in shell scripting, so I think it'll pay to become a bit more familiar with it.

The site HowToGeek [says the following](https://www.howtogeek.com/666395/how-to-use-the-sed-command-on-linux/){:target="_blank" rel="noopener"}:

> The `sed` command is a bit like chess: it takes an hour to learn the basics and a lifetime to master them (or, at least a lot of practice)...
>
> `sed` is a stream editor that works on piped input or files of text. It doesn't have an interactive text editor interface, however. Rather, you provide instructions for it to follow as it works through the text.
>
> With sed you can do all of the following:
>
>  - Select text
>  - Substitute text
>  - Add lines to text
>  - Delete lines from text
>  - Modify (or preserve) an original file
>
> ...
>
> Substitutions are probably the most common use of `sed`.

HowToGeek clarifies what the `-n` flag does:

> By default, sed prints all lines. We'd see all the text in the file with the matching lines printed twice. To prevent this, we'll use the -n (quiet) option to suppress the unmatched text.

ComputerHope, which I've often found to be another good resource during this project, adds [the following](https://www.computerhope.com/unix/used.htm){:target="_blank" rel="noopener"}:

> The sed stream editor performs basic text transformations on an input stream (a file, or input from a pipeline). While in some ways similar to an editor which permits scripted edits (such as ed), sed works by making only one pass over the input(s), and is consequently more efficient. But it is sed's ability to filter text in a pipeline which particularly distinguishes it from other types of editors.

I'm still a bit unclear on the `-e` flag, however.  When I Google 'what does the "-e" flag do sed', the first result I see is [a StackExchange post](https://unix.stackexchange.com/questions/33157/what-is-the-purpose-of-e-in-sed-command){:target="_blank" rel="noopener"} which proves helpful:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-123pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

From this and other answers in the post, I can see that `-e` tells `sed` to use the subsequent argument as a script to run against the input that it receives.  I search the file to see where this function is called, and I see [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L100){:target="_blank" rel="noopener"} that we send the text of a yet-to-be-specified file to `sed`, which means we run the script that was passed to `-e` against the text from the filename.  However, I'm not clear on what this script is.  It appears to be 3 scripts in one, separated by newlines.  [I ask StackExchange for help](https://unix.stackexchange.com/questions/717738/what-is-the-function-of-this-script-passed-to-sed-e){:target="_blank" rel="noopener"} and am waiting for an answer.

(stopping here for the day; 36997 words)

The next day, I have [my answer](https://unix.stackexchange.com/a/717747/142469){:target="_blank" rel="noopener"}.  The TL;DR is that I was right in thinking that the code inside the quotes represents 3 commands passed to `sed`, executed one-after-another.  When you pass "-e" to `sed`, you can then pass it commands which are chained in this style.  In our case, the 1st command says that if a line is encountered which does *not* start with a `#` symbol, quit the `sed` command entirely.  The 2nd command says that if a line is encountered which starts and ends with the same `#` symbol (i.e. it's just a one-character line containing `#`), to replace that lone character with a `# ` (i.e. `#` plus a space).  The 3rd command says that, if a line is encountered starting with `#` plus a space, to print that line (not including the `#-space` characters).

(stopping here for the day; 38048 words, mostly at the start of this file)

Next few lines of code:

```
collect_documentation() {
  local awk
  awk="$(type -p gawk awk 2>/dev/null | head -n1)"
  if [ -z "$awk" ]; then
    echo "rbenv: cannot find awk" >&2
    return 1
  fi
...
```

Here we open (but don't yet close) a declaration for a function called `collect_documentation`.  Inside we declare a local variable named `awk`, which I happen to know shares the same name as a shell utility.  GNU has [a user's guide](https://web.archive.org/web/20220915174506/https://www.gnu.org/software/gawk/manual/gawk.html){:target="_blank" rel="noopener"} on the `awk` utility, which says that it's "a program that you can use to select particular records in a file and perform operations upon them."  [The Linux man page](https://web.archive.org/web/20220707035408/https://man7.org/linux/man-pages/man1/awk.1p.html){:target="_blank" rel="noopener"} for `awk` has more details:

> The awk utility shall execute programs written in the awk programming language, which is specialized for textual data manipulation. An awk program is a sequence of patterns and corresponding actions. When input is read that matches a pattern, the action associated with that pattern is carried out.
>
> Input shall be interpreted as a sequence of records. By default, a record is a line, less its terminating <newline>, but this can be changed by using the `RS` built-in variable. Each record of input shall be matched in turn against each pattern in the program. For each pattern matched, the associated action shall be executed.

This actually sounds really similar to the "pattern-matching + command" language we saw inside the `extract_initial_comment_block` function.  But I don't want to get ahead of ourselves with the details of the command; let's come back to it when we see the command syntax, further down the code.

We assign a value to our local variable `awk`, and that value is `$(type -p gawk awk 2>/dev/null | head -n1)`.  We've seen `type -p` before- in `bash`, it returns the path to a command, but *only* if that command lives in a disk file somewhere.  If the command is (for example) a shell function, `type -p` will return nothing.

In the case of setting our local `awk` variable, `type -p gawk awk` searches the disk for the files associated with 2 commands, `gawk` and `awk`.  It pipes the results to `head -n1`, which means it takes the first filepath it finds from those 2 commands, and it pipes any errors to `/dev/null`.  So the value of the `awk` local variable is either the filepath for the `gawk` command or that of the `awk` command (if no filepath was found for `gawk`).

I was curious why the value of the local variable was set using the `type` command, and not `which`, a command that I'm more familiar with.  I Google "type vs which bash" and get [this very authoritative-looking StackExchange post](https://unix.stackexchange.com/questions/85249/why-not-use-which-what-to-use-then){:target="_blank" rel="noopener"}.  The question itself says "We often hear that which should be avoided", and this is new information to me.  This seems important, because `which` is one of the first shell commands I learned and is something I rely on not-infrequently, so I decide to read up on this a bit.  Here are some snippets of information that I was able to pick up from the top-rated answer:

> The `which` command is a broken heritage from the C-Shell and is better left alone in Bourne-like shells.
>
> There's a distinction between looking for that information as part of a script or interactively at the shell prompt.
>
> At the shell prompt, the typical use case is: this command behaves weirdly, am I using the right one? What exactly happened when I typed mycmd? Can I look further at what it is?
>
> In that case, you want to know what your shell does when you invoke the command without actually invoking the command.
>
> In shell scripts, it tends to be quite different. In a shell script there's no reason why you'd want to know where or what a command is if all you want to do is run it. Generally, what you want to know is the path of the executable, so you can get more information out of it (like the path to another file relative to that, or read information from the content of the executable file at that path).
>
> ...
>
> ...to get the pathname of an executable in a script, there are a few caveats:
>
> `ls=$(command -v ls)`
>
> ...would be the standard way to do it.
>
> There are a few issues though:
>
> It is not possible to know the path of the executable without executing it. All the `type`, `which`, `command -v`... all use heuristics to find out the path. They loop through the `$PATH` components and find the first non-directory file for which you have execute permission.
>
> ...if foo is a builtin or function or alias, command -v foo returns foo.
>
> ...
>
> Most answers and reasons against `which` deal with aliases, builtins and functions...
>
> ...
>
> ...`which`... aims to give you the aliases, because it's meant as a tool for (interactive) users of csh. POSIX shells users have `command -v`.
>
> ...
>
> Now, on the standard front, POSIX specifies the `command -v` and `-V` commands (which used to be optional until POSIX.2008). UNIX specifies the `type` command (no option). That's all (`where`, `which`, `whence` are not specified in any standard).

Another good StackOverflow question [here](https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script){:target="_blank" rel="noopener"} ("How would I validate that a program exists, in a way that will either return an error and exit, or continue with the script?"), with answer [here](https://stackoverflow.com/a/677212/2143275){:target="_blank" rel="noopener"}.  An excerpt:

> ### POSIX compatible:
>
> `command -v <the_command>`
>
> Avoid `which`. Not only is it an external process you're launching for doing very little (meaning builtins like `hash`, `type` or `command` are way cheaper), you can also rely on the builtins to actually do what you want, while the effects of external commands can easily vary from system to system.
>
> Why care?
>
> - Many operating systems have a `which` that doesn't even set an exit status, meaning the `if which foo` won't even work there and will always report that `foo` exists, even if it doesn't (note that some POSIX shells appear to do this for `hash` too).
> - Many operating systems make `which` do custom and evil stuff like change the output or even hook into the package manager.
>
> So, don't use which. Instead use one of these:
>
> - `command -v foo >/dev/null 2>&1 || { echo >&2 "I require foo but it's not installed.  Aborting."; exit 1; }`
> - `type foo >/dev/null 2>&1 || { echo >&2 "I require foo but it's not installed.  Aborting."; exit 1; }`
> - `hash foo 2>/dev/null || { echo >&2 "I require foo but it's not installed.  Aborting."; exit 1; }`

Oof, that's a lot of info.  But what I gather from all the above is that the output `which` prints to STDOUT isn't necessarily a filepath, since (as a feature) it also includes commands defined via shell functions, aliases, etc.  This can be dangerous from our perspective- in RBENV, we want *just* original, non-overridden commands from the shell, and the way we try to achieve this is by avoiding `which` in favor of `type -p` or `command -v`, both of which are used in the RBENV codebase.

Continuing on with the `collect_documentation` function:

```
  if [ -z "$awk" ]; then
    echo "rbenv: cannot find awk" >&2
    return 1
  fi
```

If neither `gawk` nor `awk` is installed on the user's system, we echo an error message to STDERR and return a non-zero exit code.  But why wouldn't `awk` be installed on the user's system?  We have a `bash` shebang in this file; isn't `awk` part of every `bash` installation?

And what is the difference between `awk` and `gawk`?  I ask a StackExchange question [here](https://unix.stackexchange.com/questions/717991/why-is-it-necessary-to-check-for-awk-in-this-bash-script){:target="_blank" rel="noopener"}, and eventually I get the answer that `awk` is part of the POSIX standard, but that the RBENV authors probably couldn't assume that the user would be running in a POSIX-compliant environment.

Another question: I see both `type -p` and `command -v` being used for the same purpose in this file ([here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L26){:target="_blank" rel="noopener"} and [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L46){:target="_blank" rel="noopener"}).  Is there any difference between these?  From [shell-tips.com](https://web.archive.org/web/20220705053124/https://www.shell-tips.com/bash/type-command/#gsc.tab=0){:target="_blank" rel="noopener"}, I see the following:

> You can use the bash specific syntax `type -p` to find the actual path to an external shell command. It is similar to using `command -v` which is POSIX compliant. Both methods should be preferred in bash to the legacy `which` command.
>
> You can easily test with a bash if statementicon mdi-link-variant whether a command exists or not and get the path for it.
>
> ```
> [me@linux ~]$ type -p date
> /bin/date
> [me@linux ~]$ type -p python
> /usr/local/bin/python
> [me@linux ~]$ command -v python
> /usr/local/bin/python
> [me@linux ~]$ if ! command -v python &>/dev/null; then echo "Python not installed"; fi
> Python not installed
> ```

So based on the description and terminal examples, it seems like the two methods are equivalent.

(stopping here for the day; 39509 words)

Next line of code:

```
# shellcheck disable=SC2016
```

I haven't seen code like this before, so I Google "shellcheck disable".  [The first result](https://web.archive.org/web/20220626113148/https://www.bashsupport.com/manual/editor/shellcheck/){:target="_blank" rel="noopener"} refers to a program called ShellCheck.  I Google "what is ShellCheck", and [the first result](https://web.archive.org/web/20220915000849/https://www.shellcheck.net/){:target="_blank" rel="noopener"} of *this* search describes it as "ShellCheck is an open source static analysis tool that automatically finds bugs in your shell scripts."  Back to the line of code, it appears that `shellcheck disable=SC2016` disables [rule number 2016](https://www.shellcheck.net/wiki/SC2016){:target="_blank" rel="noopener"}:

> Expressions don't expand in single quotes, use double quotes for that.
>
> Problematic code:
> ```
> name=World
> echo 'Hello $name'   # Outputs Hello $name
> ```
>
> Correct code:
> ```
> name=World
> echo "Hello $name"   # Outputs Hello World
> ```
>
> Rationale:
> ShellCheck found an expansion like $var, $(cmd), or `cmd` in single quotes.
>
> Single quotes express all such expansions. If you want the expression to expand, use double quotes instead.

It appears that, normally, running ShellCheck against the subsequent code would trigger rule # 2016.  The authors didn't want that to happen, so they added an annotation to disable that for the following line of code.  That line of code includes the beginning of a single-quoted, multi-line string containing a series of commands passed to `awk`.  Let's look at the next line of code, and the few lines of code after that (which contain the first of the commands that `awk` receives):

```
"$awk" '
    /^Summary:/ {
      summary = substr($0, 10)
      next
    }
```
We first see `"$awk" ` followed by the opening single-quote.  `"$awk"` is the expansion of the variable we stored a few lines of code earlier, the result of our `type -p` command.  It will expand to either `gawk` or `awk`, whichever the user has installed.  We then call that command, and pass it the multi-line string of `awk` commands, beginning with a regex that searches for the string "Summary:" including the colon.  If we find it, we create a variable named "summary" and set its value to... I'm not sure?  I mean it's clearly the return value of "substr)($0, 10)", but since "$0" is wrapped in single-quotes here, it won't expand to the zeroth argument like it normally would, right?

As an experiment, I decide to store this single-quoted string in a variable first, and then pass that variable to the "$awk" command.  This will allow me to print out the string and see what it resolves to, and in particular whether the "$0" is expanded (and if so, what the expanded value is):

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-133pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

In a new terminal, this results in output of:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-134pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So the "$0" symbol is not expanded here.  And I think I know why.

When I was `echo`ing the `myStr` variable that I created, I initially did not send the `echo` to STDERR via the `>&2` command that you now see in the first screenshot.  By default, `echo` goes to STDOUT, and this resulted in an error of `myStr: command not found`.  This must be because the output sent to STDOUT from here must be getting `eval`ed at some higher calling script.  This is also why the single-quotes are used- we *don't want* the "$0" to be expanded here- we want it to be expanded by the higher-level calling script, so we need to make sure it's preserved and not expanded here.  The way we do that is by using single-quotes.  And since ShellCheck will alert by default whenever it sees a potential expansion inside single-quotes, we have to add the `shellcheck disable` annotation above it.

I wanted to see what "summary" expands to, after all is said and done.  I initially tried the same `>&2 echo` trick that I used above...

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-135pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

...but that didn't work:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-136pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

I Google "awk print a string" and find [this result](https://www.gnu.org/software/gawk/manual/html_node/Print-Examples.html){:target="_blank" rel="noopener"}, which suggests using the `print` command instead.  I try this...

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-137pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...and get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-138pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so I'm still getting a "command not found" error, which means our string is still accidentally getting interpreted as a command.  I Google "awk print to stderr", since I suspect that printing to a destination other than STDOUT will have the effect we want.  I get [this link](https://web.archive.org/web/20230407073708/https://groups.google.com/g/comp.unix.shell/c/iLB2_h4QFIo){:target="_blank" rel="noopener"}, with a comment (again by Stephane Chazelas; this guy is everywhere!) that suggests the command `​​print "foo" | "cat >&2"`.  I try the equivalent for my code:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-139pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...and I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-140pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

This seems to fix the error, at least!  The only problem is, I'm not sure where (or whether) my print statement output is rendered.  I add a 2nd, tracer print statement:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-141pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...which results in the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-142pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Great!  So the "summary" variable evaluates to "Set or show the global Ruby version".  We can be reasonably confident of this because that's the string printed out immediately before the "foobar" string.

But wait, when I initially glanced at the call to `substr`, I saw that the 2nd parameter was `10`.  I had assumed that this meant we wanted the substring only up to the 10th character, and that the first param of `$0` was the index of the character that we wanted to start at.  This can't be the case, since we clearly have more than 10 characters in the output.  I look up the documentation for `substr` by Googling "awk substr", and I get [this result](https://web.archive.org/web/20201129014027/https://thomas-cokelaer.info/blog/2011/05/awk-the-substr-command-to-select-a-substring/){:target="_blank" rel="noopener"}, which says that the syntax of `substr` is as follows:

> substr(s, a, b) : it returns b number of chars from string s, starting at position a. The parameter b is optional, in which case it means up to the end of the string.

Ah OK, so I bet that our "$0" flag evaluates to the line of code that's found by the `/^Summary:/` regex, and the `10` says "take everything from the 10th character to the end of the line".  That explains why the "summary" variable didn't include the string "Summary:".  To triple-check this hypothesis, I do one last test, which is print the "$0" string in its entirety (not just the substring represented by "summary"):

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-143pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

This results in:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-144pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Yep!  So "Summary: " is 9 characters long.  The 10th character is the "S" in "Set or show...", so that's where our substring starts.  This also explains why the error message I was getting earlier was "Set: command not found".  Our substring starts with "Set", and it was this string fragment that the higher-level `eval` was mis-interpreting as a command to execute.  Lastly, this also confirms that the way `awk` commands work is, they run one or more regexes against each line of an input (which means they must be separated by `\n` newlines by default), and for each matching line, they run the code inside the curly braces.

I think we can move on now.  But before I forget, I make sure to clean up the print statements I added.

One last thing before moving on to the next `awk` command is the line of code after the `summary` declaration: `next`.  [GNU.org says](https://web.archive.org/web/20220525202544/https://www.gnu.org/software/gawk/manual/html_node/Next-Statement.html){:target="_blank" rel="noopener"}:

> The next statement forces awk to immediately stop processing the current record and go on to the next record. This means that no further rules are executed for the current record, and the rest of the current rule's action isn't executed.
>
> ...
>
> At the highest level, awk program execution is a loop that reads an input record and then tests each rule's pattern against it. If you think of this loop as a for statement whose body contains the rules, then the next statement is analogous to a continue statement. It skips to the end of the body of this implicit loop and executes the increment (which reads another record).

OK, easy enough.  So if the current line of `awk` input starts with "Summary:", we *only* want to instantiate a variable named "summary" and populate it with the substring of the current line of text.  We explicitly *do not* want to execute any of the remaining rules that we'll examine next.

It's interesting that we can declare a variable inside the curly braces, but with spaces on the left and right of the `=` sign that we usually couldn't have in a shell script.  For example, if I open a bash shell and type `foo = 5`, I get the following:

```
bash-3.2$ foo = 5

bash: foo: command not found
```

The rules for whitespace when declaring variables seem to be different inside `awk` code, which makes me wonder what else is different.  I really don't want to do a deep-dive into `awk` right now, though, because I think that would slow down my reading of the codebase.  I decide to keep pushing forward.

(stopping here for the day; 40791 words)

Next `awk` rule is:

```
    /^Usage:/ {
      reading_usage = 1
      usage = usage "\n" $0
      next
    }
```

If the line of code starts with the string "Usage:", then we execute the code inside the curly braces.  That code sets a variable called `reading_usage` equal to 1, and it sets another variable (called simply `usage`) equal to... what?  It looks like we're running a command (confusingly, also called `usage`) and passing it the newline string "\n" plus the line of text that was matched, as we did with the previous "Summary" command.  But where is that `usage` command coming from?  I Google `awk usage command` but nothing comes up.  I'm a bit flummoxed.

I decide to start at the end and work backwards.  This whole `awk` command is part of the `collect_documentation` function body.  What is that function's return value?  I copy/paste the entire function into a new `bash` terminal:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-145pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then check how the function is called in the code.  I see we pipe some text to it:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-151pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I mimic this in the simplest way I can think of, by `echo`ing "Summary: foobar" and piping that to the function:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-146pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>


I do the same with "Usage: foobar":

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-147pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I assumed that "help" would be populated the same way, but when I try "Help: foobar", I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-148pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>


I scroll down in the code a bit and I notice that, while there is a line here of `help = help "\n" $0`, it doesn't come with a regex before the opening curly brace, so maybe that means there's no matching lines?  But if that's the case, how does "help=" get populated?  I assume it must be happening somehow, otherwise why have `help = help "\n" $0` in the function at all?

I don't think it's correct to say that curly braces without a regex means the code will never get executed.  I find a StackOverflow answer [here](https://web.archive.org/web/20160901162438/https://stackoverflow.com/questions/38596130/what-does-it-mean-when-an-awk-script-has-code-outside-curly-braces){:target="_blank" rel="noopener"}, which in fact says the opposite - that `awk` code without a regex will *always* be run:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-149pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>


I have a hypothesis that might address part of my confusion, specifically on where the 2nd reference to `usage` comes from.  I scroll through the code and see that `collect_documentation` is called by `documentation_for`, which in turn is called by `print_summary`.  [That function](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L106){:target="_blank" rel="noopener"}, in turn, declares local variables `summary`, `usage`, and `help`.  There are similar functions called [`print_help`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L120){:target="_blank" rel="noopener"} and [`print_usage`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L143){:target="_blank" rel="noopener"}, which declare the same local variables in a similar way.

I also see that `documentation_for ` is called within the context of an `eval` command:

```
print_summary() {
  local command="$1"
  local summary usage help
  eval "$(documentation_for "$command")"

  if [ -n "$summary" ]; then
    printf "   %-9s   %s\n" "$command" "$summary"
  fi
}
```

Since the output of `collect_documentation` appears to be the 3 `print` statements [starting on line 88](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L88){:target="_blank" rel="noopener"}, my guess is that we `eval` the following:

```
summary="Summary: foobar"
usage="
help="
```
The effect of `eval`ing the above is to set 3 variables, which are presumably used in the final output.

Going back to our current block of code:

```
    /^Usage:/ {
      reading_usage = 1
      usage = usage "\n" $0
      next
    }
```

...I further suspect that the 2nd reference to `usage` in the line `usage = usage "\n" $0` is referencing the local `usage` variable which was declared in the `print_summary` or `print_usage` or `print_help` function.

Lastly, I suspect that the purpose of this block is to handle the case when we reach the *beginning* of a "Usage" comment.  We set the `reading_usage` flag to 1, so that we know we're currently in the middle of reading a usage comment.  This is useful because there is logic in the next `awk` command that we only want to execute if we're in the middle of reading a usage comment:

```
    /^( *$|       )/ && reading_usage {
      usage = usage "\n" $0
      next
    }
```

We'll get back to the above `awk` command later; this is just to outline my current hypothesis.

I do a quick experiment.  I create a function named `baz` which `echo`s a string that, when `eval`ed, should set a variable named `bar` to "this is a bar".  I create another function named `foo` which creates a local variable named `bar`, calls the earlier `baz` function and `eval`s the results, and then `echo`s the value of its local `bar` variable.  I see the following:

```
$ bash

The default interactive shell is now zsh.
To update your account to use zsh, please run `chsh -s /bin/zsh`.
For more details, please visit https://support.apple.com/kb/HT208050.
bash-3.2$ baz() { echo "bar='this is a bar'"; }
bash-3.2$ foo() { local bar; eval "$(baz)"; echo "bar: $bar"; }
bash-3.2$ foo
bar: this is a bar
```

OK, so even though I didn't set the value of `bar` inside the `foo` function, calling `eval` on the result of `baz` still results in `bar`'s value being set within the context of the body of `foo`.

What I think this means is, the 2nd reference to `usage` above is *not* the local `usage` variable declared in `print_summary` etc.  I think this `usage` variable is local to the `awk` function, and just happens to be named the same thing as the outer local variable.  I believe that the outer local var named `usage` doesn't get set until we eval the line `usage=....`.

I feel like today's analysis has got me kinda muddled in the brain.  I have multiple active threads that I haven't tied up, multiple trains of thought going at once, and in my experience that tends to lead to a less-than-scientific process being used.  I could break here and come back tomorrow with a clearer head.  Or I could try to recap what I think I know so far, from the top.

I know I'm skipping ahead again, but I decide to do a quick experiment to see if I can trigger the `/^( *$|       )/ && reading_usage` condition in the next `awk` command.  I remove the tracer statements that I previously added to `collect_documentation`, as well as the test for the presence of `gawk` and `awk` (since I know `awk` exists on my machine), and I echo two separate strings, both of which I pipe to `collect_documentation`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-152pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I see that, when I pipe a multi-line string that begins with "Usage:" to `collect_documentation`, and I be sure to include the requisite # of spaces before lines 2-4, the entire multi-line string is included as part of the `usage=` assignment.  However, when I *don't* prepend lines 2-4 with those spaces, only the "Usage: " line is included in the `usage` assignment.  The rest of the lines are added to the `help` assignment.

I think this actually makes sense- if we've already encountered the "Usage:" string on a previous line that was processed by `awk`, this means the `reading_usage` flag has been set, so it's now truthy.  That's the 2nd part of the `/^( *$|       )/ && reading_usage` condition.  And if there are sufficient space characters at the beginning (`^`) of the current line, that means the regex condition is met.  Note that there are actually 2 ways that the first condition could be triggered: one is by prepending the line with 7 spaces (i.e. the `|       `) half of the regex, and the other (according to [this guide](https://web.archive.org/web/20230321100428/https://opensource.com/article/19/11/how-regular-expressions-awk){:target="_blank" rel="noopener"} to regex in `awk`) *seems to be* a line containing *only* zero or more spaces.  However, I can't reproduce this 2nd case.  When I try adding a line of only spaces, I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-153pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I would have expected to see:

```
usage="Usage:

"
help=" bar
 baz"
```

So my hypothesis is incorrect.  However, proving this first regex pattern feels like a bit of a distraction from the more important work of understanding the overall `awk` command, so I decide to push forward.  The important thing is that we execute the code inside the following block *if and only if* we've already encountered "Usage:":

```
    /^( *$|       )/ && reading_usage {
      usage = usage "\n" $0
      next
    }
```

(stopping here for the day; 42117 words)

Next block of code:

```
    {
      reading_usage = 0
      help = help "\n" $0
    }
```

If we reach this block of code (i.e. if we haven't met any of the previous regex conditions, which all trigger the `next` command and would cause us to skip this step), then we know we are no longer reading part of the "Usage" section, so we turn off that flag by setting "reading_usage" to "0".  We then append a newline and the current line to the pre-existing "help" variable, which contains a multi-line string.

Next line of code:

```
    function escape(str) {
      gsub(/[`\\$"]/, "\\\\&", str)
      return str
    }
```

Here we declare a helper function which will be used further down in the `awk` code.  This function, called "escape", looks for the characters `, \, $, or ", and escapes any and all instances it finds (i.e. it prepends it with the \ character).  It then returns the modified string.

The & character has a special meaning here, according to [the GNU docs](https://web.archive.org/web/20220608181534/https://www.gnu.org/software/gawk/manual/html_node/String-Functions.html){:target="_blank" rel="noopener"} for the "sub()" function:

> If the special character '&' appears in replacement, it stands for the precise substring that was matched by regexp. (If the regexp can match more than one string, then this precise substring may vary.) For example:
>
> ```
> { sub(/candidate/, "& and his wife"); print }
> ```
>
> changes the first occurrence of 'candidate' to 'candidate and his wife' on each input line.

In this case, the docs say that the function "changes the first occurrence", but that's just because the function that the doc is discussing here is the "sub" function.  Under the docs for "gsub", we see:

> As in sub(), the characters '&' and '\' are special...

Next block of code:

```

    function trim(str) {
      sub(/^\n*/, "", str)
      sub(/\n*$/, "", str)
      return str
    }
```

This is a 2nd helper function, which deletes any number of newlines at the beginning of the string (`      sub(/^\n*/, "", str)`) or at the end of the string (`sub(/\n*$/, "", str))`).

We can prove this by passing a multi-line string with newlines in strategic places:

```
bash-3.2$ echo -e "
> Usage: foo
> \nfoo
> bar\nbaz
> buz\n
> " | collect_documentation
summary=""
usage="Usage: foo"
help="foo
bar
baz
buz"
```

We can see that there are separate help lines for "foo", "bar", "baz", and "buzz".  I was initially expecting to see "bar\nbaz" on its own line, since I placed the newline in the middle of the string (not the beginning or the end, as referenced by ^ and $ in the regexes).  But it appears that the newline in the middle of that string was interpreted as a real newline, not as part of the string.  Note that we need the `Usage: foo` line because `collect_documentation` only prints output if there is either a `summary` or `usage` variable set by `awk`.  Also note that I initially tried a simple `echo` with no flags, not the `echo -e` command that you see above.  This resulted in the newlines being treated as a printable part of the string, not as regular newlines.  [According to StackOverflow](https://stackoverflow.com/questions/8467424/echo-newline-in-bash-prints-literal-n){:target="_blank" rel="noopener"}, the solution is to use either `echo -e` or `printf`.

Question: if `printf` and `echo -e` automatically handle the newlines for us, why do we need the `trim` function at all?

Next lines of code:

```
END {
      if (usage || summary) {
        print "summary=\"" escape(summary) "\""
        print "usage=\"" escape(trim(usage)) "\""
        print "help=\"" escape(trim(help)) "\""
      }
    }
```

I have been confused by this `END` thing since I skipped ahead in the code a few days ago.  It looked like the termination of a heredoc, but I didn't see where the heredoc began, so I didn't know what to make of it.  Attempting to answer my question, I consulted [the GNU awk docs](https://www.gnu.org/software/gawk/manual/gawk.html#BEGIN_002fEND){:target="_blank" rel="noopener"}.  Searching for the string "END", I was rewarded with an answer:

> All the patterns described so far are for matching input records. The BEGIN and END special patterns are different. They supply startup and cleanup actions for awk programs. BEGIN and END rules must have actions; there is no default action for these rules because there is no current record when they run.

That means our `END` command is like a "cleanup" action that happens after all the lines of text have been read.  And this command states that, if `usage` or `summary` variables are non-empty, then we print lines of text which, when converted to actual code by the `eval` caller, will set  `summary`, `usage`, and `help` variables equal to (respectively) the escaped `summary` variable, the trimmed and escaped `usage` variable, and the trimmed + escaped `help` variable.

And that's the end of the body of `collect_documentation`!

Next block of code:

```
documentation_for() {
  local filename
  filename="$(command_path "$1")"
  if [ -n "$filename" ]; then
    extract_initial_comment_block < "$filename" | collect_documentation
  fi
}
```

This is the definition of a function named `documentation_for`.  In its body, we declare a local variable named `filename`, and set it equal to the filepath of the command we pass to `documentation_for` when we call it.  We get this filepath with the help of our previously-examined `command_path` helper function.  If `filename` is non-empty, we pass the filename to `extract_initial_comment_block` to get just the comment lines at the head of the file, we strip out the `#` comment indicators, and we pass the result to `collect_documentation`.

Next block of code:

```
print_summary() {
  local command="$1"
  local summary usage help
  eval "$(documentation_for "$command")"

  if [ -n "$summary" ]; then
    printf "   %-9s   %s\n" "$command" "$summary"
  fi
}
```

This is the definition of a function named `print_summary`.  We create a local variable named `command` and set it equal to the first argument passed to this function.  We then create 3 more local variables, called `summary`, `usage`, and `help`.  We then run `documentation_for` on our `command` variable, and `eval` the result (which should be the `summary=...` / `usage=....` / `help=...` lines of text) in order to populate values in the local variables we just declared.  If our `summary` variable is non-empty, we print just the contents of that variable; since this function is called `print_summary`, that's all we want to do here.

Next block of code:

```
print_summaries() {
  for command; do
    print_summary "$command"
  done
}
```

Another definition for a function, this one called `print_summaries`.  This just iterates over all the commands that the user passed in as arguments, and calls the previous `print_summary` function on each one.

(stopping here for the day; 43137 words)

Next block of code:

```
print_help() {
  local command="$1"
  local summary usage help
  eval "$(documentation_for "$command")"
  [ -n "$help" ] || help="$summary"

  if [ -n "$usage" ] || [ -n "$summary" ]; then
    if [ -n "$usage" ]; then
      echo "$usage"
    else
      echo "Usage: rbenv ${command}"
    fi
    if [ -n "$help" ]; then
      echo
      echo "$help"
      echo
    fi
  else
    echo "Sorry, this command isn't documented yet." >&2
    return 1
  fi
}
```

This is another function definition, but a big one.  So we'll break it up further into shorter snippets.

The first few lines of this function, called `print_help`, function the same as those of `print_summary`.  We declare 4 local vars (called `command`, `summary`, `usage`, and `help`), and initialize `command` to be the first argument passed to `print_help`.  We then `eval` the return value of `documentation_for $command`.  That return value is the `summary=...`, `usage=...`, etc., so calling `eval` on that multi-line string has the effect of initializing the remaining 3 valueless variables with their values.

The next line:
```
[ -n "$help" ] || help="$summary"
```

This says that, if the `help` variable is empty, we initialize it to be the same value as `summary`.

Next line:

```
if [ -n "$usage" ] || [ -n "$summary" ]; then
```

If we have a non-empty value for either our `usage` or `summary` variable, then we execute the contents of this `if` block.

Next block of code:

```
    if [ -n "$usage" ]; then
      echo "$usage"
    else
      echo "Usage: rbenv ${command}"
    fi
```

If `usage` is non-empty (i.e. if this command has specific usage instructions in its file), then we echo it.  Otherwise, we echo a default value of `Usage: rbenv` plus the name of the command.

Next block of code:

```
if [ -n "$help" ]; then
      echo
      echo "$help"
      echo
    fi
```
If the `help` variable is non-empty, we echo its value, surrounded by a newline both before and after.

Last block of code for our `print_help` function:

```
  else
    echo "Sorry, this command isn't documented yet." >&2
    return 1
  fi
```

This is the `else` block for our `if [ -n "$usage" ] || [ -n "$summary" ]; then` condition.  If neither the `usage` nor the `summary` variables have values, we print an error message to STDERR and return a non-zero exit status.

That's it for the `print_help` function!

Next block of code:

```
print_usage() {
  local command="$1"
  local summary usage help
  eval "$(documentation_for "$command")"
  [ -z "$usage" ] || echo "$usage"
}
```

The first 3 lines should look familiar- we instantiate and populate 4 local variables, named `command`, `summary`, `usage`, and `help`.  Then, if `usage` contains a value, we print it to STDOUT.

Next block of code:

```
unset usage
if [ "$1" = "--usage" ]; then
  usage="1"
  shift
fi
```

First we unset the `usage` variable if it has already been set, to guarantee that it's empty.  If the first argument to `rbenv help` is `--usage`, we set the value of the `usage` variable to "1".  We then remove that first argument from the list of shell arguments, leaving us with a new first argument (which is accessed in the next block of code).

### Quick aside

I checked the status of [the PR I submitted to RBENV](https://github.com/rbenv/rbenv/pull/1422){:target="_blank" rel="noopener"} (the one about the `KSH_ARRAYS` option), and it looks like it was merged!  Holy crap, I'm now officially a contributor to the RBENV codebase! :party:

Next block of code:

```
if [ -z "$1" ] || [ "$1" == "rbenv" ]; then
  echo "Usage: rbenv <command> [<args>]"
  [ -z "$usage" ] || exit
  echo
  echo "Some useful rbenv commands are:"
  print_summaries commands local global shell install uninstall rehash version versions which whence
  echo
  echo "See \`rbenv help <command>' for information on a specific command."
  echo "For full documentation, see: https://github.com/rbenv/rbenv#readme"
```

If `[ -z "$1" ]` is true, that means the first argument is empty.  This, in turn, means either the user typed `rbenv help` without arguments, or they typed `rbenv help --usage` and the `--usage` argument was `shift`ed off in the previous block of code.  If that's the case, *or* if the first argument to `rbenv help` was `rbenv` (i.e. the user typed `rbenv help rbenv`), we do the following:

First, we echo a general usage instruction that applies to all rbenv commands.  Then, if we set the value of `usage` in the preious `if` block, we exit.  Otherwise, if that variable is currently empty, we echo summaries for a hard-coded list of rbenv commands (the line `print_summaries commands local global shell install...`), as well as some additional hard-coded strings before and after the summaries.

Next block of code:

```
else
  command="$1"
  if [ -n "$(command_path "$command")" ]; then
    if [ -n "$usage" ]; then
      print_usage "$command"
    else
      print_help "$command"
    fi
  else
    echo "rbenv: no such command \`$command'" >&2
    exit 1
  fi
fi
```
This is the `else` block for the `if [ -z "$1" ] || [ "$1" == "rbenv" ]; then` condition.  If that condition is false, that means the user provided an argument to `rbenv help` which was *not* "rbenv" (i.e. they typed `rbenv help` plus a specific command like `global`, `local`, etc.  In this case, we do the following:

First, we set the `command` variable equal to the first argument.  If that command is associated with a file in our `$PATH` directories, then we either print any `usage` instructions for that command (if they exist), or else print the `help` instructions for that command.  Remember that the `print_help` method specifies that we only print `help` instructions if either `summary` or `usage` instructions also exist.  So I think this means we don't actually need the `if [ -n "$usage" ] || ` check on [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L126){:target="_blank" rel="noopener"}.  Because if we've reached this line, that means the `if` check [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L169){:target="_blank" rel="noopener"} (which is the same check) must have failed.  Alternately, we could keep that `if` check and delete [the one here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L168){:target="_blank" rel="noopener"}, which (I think?) should have the same effect.

TODO- submit a PR for this change.

Lastly, if the `if` check here (`if [ -n "$(command_path "$command")" ]; then`) fails, then we echo a "no such command" error message and direct it to STDERR, and we exit with a non-zero status.

That's it for this command!  On to the next command in our repo.
