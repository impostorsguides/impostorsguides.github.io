As usual, we'll do the test first, and the code afterward:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/exec.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_executable() {
  name="${1?}"
  shift 1
  bin="${RBENV_ROOT}/versions/${RBENV_VERSION}/bin"
  mkdir -p "$bin"
  { if [ $# -eq 0 ]; then cat -
    else echo "$@"
    fi
  } | sed -Ee '1s/^ +//' > "${bin}/$name"
  chmod +x "${bin}/$name"
}
```

### The `create_executable` helper function

We start by defining a helper function called `create_executable`.  This function sets a variable named `name` equal to the first argument, but it looks like something else is happening inside the parameter expansion.

#### Storing the name of the executable

I'm not sure what the question-mark syntax does, so I pull up [the bash docs on parameter expansion](https://web.archive.org/web/20230525183815/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-28may2023-834pm.png">
    <img src="/assets/images/screenshot-28may2023-834pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

So with the question mark, we get a specific error message saying that the value of `parameter` (or in our case, `"$1"`) is unset.  I try this in my local `bash` terminal, and I see the following:

```
bash-3.2$ unset foo

bash-3.2$ "${foo:?}"

bash: foo: parameter null or not set

```

So the goal is to show an error if no params are passed to `create_executable`.  If at least one argument **is** passed, however, we store the first argument as the variable `name` and `shift` the arg off the argument list.

#### Making a directory to store our executable

Next bit of code:

```
bin="${RBENV_ROOT}/versions/${RBENV_VERSION}/bin"
mkdir -p "$bin"
```

 We create a variable named `bin` and set its value to the name of a series of directories and subdirectories.  We then make a directory with the name stored in `bin`, using the `-p` flag to ensure that any intermediary directories which don't yet exist will be created as well.

#### Adding content to our executable file

The next bit is long:

```
{ if [ $# -eq 0 ]; then cat -
    else echo "$@"
    fi
  } | sed -Ee '1s/^ +//' > "${bin}/$name"
```

Let's break this into two pieces.  The first piece is:

```
{ if [ $# -eq 0 ]; then cat -
    else echo "$@"
    fi
  }
```

This half is wrapped in curly braces, meaning we perform it as a single operation and send its contents to the next half.  This is called ["command grouping"](https://web.archive.org/web/20230326002400/https://www.gnu.org/software/bash/manual/html_node/Command-Grouping.html){:target="_blank" rel="noopener"} in `bash`, and we've seen it before (for example, when we defined the `abort` helper function [in `libexec/rbenv`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L16-L19){:target="_blank" rel="noopener"}).

What is the output of the command grouping?  We start by invoking `$#` and checking if it's equal to 0.  Referring back to [this line of `libexec/rbenv`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L16){:target="_blank" rel="noopener"}, we recall that `$#` expands to the number of arguments that were passed to the `create_executable` function.

So if the # of arguments is equal to 0, then we `cat -`.  Again referring back to [that same line of `libexec/rbenv`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L16){:target="_blank" rel="noopener"}, we recall that `cat -` reads from `stdin` and redirects its input to `stdout`.

On the other hand, if the # of arguments is **greater than** zero, we `echo $@` (i.e. we print all the arguments to STDOUT).

So to summarize the output of the command grouping- we either print the content passed from `stdin` if no arguments were passed to `create_executable`, or we print the arguments if there were any.

That output gets piped via `|` to the 2nd half of this block of code.  That block is:

```
sed -Ee '1s/^ +//' > "${bin}/$name"
```

##### The `sed` command

First up- what is `sed`?

From the `man sed` page:

```
SED(1)                                                                       General Commands Manual                                                                      SED(1)

NAME
     sed – stream editor

SYNOPSIS
     sed [-Ealnru] command [-I extension] [-i extension] [file ...]
     sed [-Ealnru] [-e command] [-f command_file] [-I extension] [-i extension] [file ...]

DESCRIPTION
     The sed utility reads the specified files, or the standard input if no files are specified, modifying the input as specified by a list of commands.  The input is then
     written to the standard output.

     A single command may be specified as the first argument to sed.  Multiple commands may be specified by using the -e or -f options.  All commands are applied to the input
     in the order they are specified regardless of their origin.

     The following options are available:

     -E      Interpret regular expressions as extended (modern) regular expressions rather than basic regular expressions (BRE's).  The re_format(7) manual page fully describes
             both formats.

     -a      The files listed as parameters for the "w" functions are created (or truncated) before any processing begins, by default.  The -a option causes sed to delay
             opening each file until a command containing the related "w" function is applied to a line of input.

     -e command
             Append the editing commands specified by the command argument to the list of commands.
```

So the `sed` command is a string editor command.  It takes a block of text and a series of commands, and runs the commands on each line of text from the block.

##### The `-E` flag

According to the above `man` entry, the `-E` flag tells UNIX to treat the regular expression as a more modern version called an "extended regular expression", rather than an older version called a "basic regular expression".  [According to `gnu.org`](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html){:target="_blank" rel="noopener"}:

> Extended regexps are those that egrep accepts; they can be clearer because they usually have fewer backslashes.

##### The `-e` flag

According to [StackOverflow](https://unix.stackexchange.com/a/33159/142469){:target="_blank" rel="noopener"}, the `-e` flag means we should be able to pass multiple `sed` commands, chaining them together one after another.  However, it looks like we're only passing one.

##### Reading the regexp pattern

The one and only regexp that we pass to `sed` is:

```
`'1s/^ +//'`
```

Most regexps that I encounter are very specific to the concise use case they're being applied toward, making them notoriously hard to Google unless that use case is a very common one among programmers.  So in this case, I decide to ask ChatGPT what this pattern does:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-29may2023-1209pm.png">
    <img src="/assets/images/screenshot-29may2023-1209pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

From ChatGPT's answer, we learn that:

 - `1` refers to the line number to which we want to apply the regexp pattern.  This is confirmed in the documentation for `sed`, [in Section 4.1 titled `Addresses overview`](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html#Addresses-overview){:target="_blank" rel="noopener"}.
- `s/` indicates we'll be performing a search-and-replace operation, finding some text which matches one pattern and replacing it with something else.  In the `sed` docs, this is covered in [section 3.3 ("The `s` command")](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html#The-_0022s_0022-Command){:target="_blank" rel="noopener"}.
- The `^` caret character after `/` tells `sed` that the subsequent pattern must start at the beginning of the line of input.  The docs confirm this [here](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html#Regular-Expressions-Overview){:target="_blank" rel="noopener"}, in the section "Overview of basic regular expression syntax".
  - Although this section deals with basic regular expressions (not extended ones), [the section on extended regular expression syntax](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html#ERE-syntax){:target="_blank" rel="noopener"} says that `The only difference between basic and extended regular expressions is in the behavior of a few characters: ‘?’, ‘+’, parentheses, braces (‘{}’), and ‘\|’.`
  - Therefore, we can safely assume that the `^` character functions the same in both BREs and EREs.
- `" +"` (i.e. a space followed by a plus sign) means that we want to match against one or more empty-space characters.
  - Remember that the `+` character **is** one of the characters whose behavior differs between basic vs. extended regular expressions.
  - In basic regular expressions, we would add a `\` before `+` if we wanted it to be treated as a special character (i.e. to have the "one or more" meaning).
  - [In extended regular expressions](https://web.archive.org/web/20230524114622/https://www.gnu.org/software/sed/manual/sed.html#ERE-syntax){:target="_blank" rel="noopener"}, it's the opposite- we precede `+` with `\` if we do **not** want it to be treated as a special character.
- The `//` syntax indicates the content that we want to use to replace the one or more empty spaces that we found.
  - With no characters in-between the `//`, we indicate that we want to replace those empty spaces with nothing.
  - In other words, we want to delete them.

To summarize- this command says to look at just line # 1, and delete any spaces at the start of that line (i.e. replace those spaces with the empty string).

Let's test this to prove to ourselves that the above is correct.

##### Experiment- removing empty spaces from a line of output

We create a file named "bar" that looks as follows:

```
#!/usr/bin/env bash

echo "   foo"
echo "   foo"
echo "   foo"
echo "   foo"
echo "bar"
```

When we `chmod +x` our `bar` file, run it, and pipe its output to the same `sed` command, we get:

```
$ ./bar | sed -E '1s/^ +//'
foo
   foo
   foo
   foo
bar
```

As we can see, our empty spaces were removed from the first printed `foo` output, but not from the subsequent lines.

##### Sending the output of `sed` to a file

The output of `sed` is then sent to a filename that we specify, like so:

```
> "${bin}/$name"
```

This means that the output from `sed` gets written to a file with the name of our `name` variable, inside the directory with the name of our `bin` variable.

#### Making our new file executable

Last line of code in our `create_executable` function:

```
chmod +x "${bin}/$name"
```

We give the current user permission to execute the newly-created file via the `chmod +x` command.

### Invalid version number (provided by an env var)

With the `create_executable` file out of the way, the next block of code is our first test:

```
@test "fails with invalid version" {
  export RBENV_VERSION="2.0"
  run rbenv-exec ruby -v
  assert_failure "rbenv: version \`2.0' is not installed (set by RBENV_VERSION environment variable)"
}
```

This test covers the failure mode of attempting to run a command with a Ruby version that's not installed:

 - We set the `RBENV_VERSION` to "2.0" without having first stubbed out a Ruby installation for version 2.0.
 - We then run the command "ruby -v" using "rbenv exec".
 - If we had stubbed out v2.0 of Ruby, we could expect to see "2.0" or equivalent in STDOUT.
 - However, because we have not done this stubbing, we expect our command to fail with an error message indicating that this Ruby version is not installed.
 - Note that the error message also tells us that the invalid version number was provided by the `RBENV_VERSION` environment variable.

### Invalid version number (provided by a `.ruby-version` file)

Next test:

```
@test "fails with invalid version set from file" {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
  echo 1.9 > .ruby-version
  run rbenv-exec rspec
  assert_failure "rbenv: version \`1.9' is not installed (set by $PWD/.ruby-version)"
}
```

This test is similar to the previous one, except this time we're setting the incorrect Ruby version via the ".ruby-version" file instead of via an environment variable:
- We make a test directory and `cd` into it.
- Inside that test directory, we make a `.rbenv-version` file and populate it with a version of Ruby that our setup steps did not specifically install.
- We run a command via "rbenv exec".
- This time it's the "rspec" command, but it doesn't really matter since either way the Ruby version is checked first.
- We assert that the command failed, and that we received an error message.
- Note that this time, the error message also tells us that the invalid version number was provided by the `.ruby-version` file, not by an env var.

### Printing the possible completions for `exec`

Next test:

```
@test "completes with names of executables" {
  export RBENV_VERSION="2.0"
  create_executable "ruby" "#!/bin/sh"
  create_executable "rake" "#!/bin/sh"

  rbenv-rehash
  run rbenv-completions exec
  assert_success
  assert_output <<OUT
--help
rake
ruby
OUT
}
```

This test appears to cover [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L20-L22){:target="_blank" rel="noopener"}.

 - We specify the Ruby version and make two executables within RBENV's directory for that version.
 - We then run `rbenv rehash` to generate the shims for these two new commands, since the completions for `exec` depend on which shims exist.
 - We then run `rbenv completions` for the `exec` command.
 - Lastly, we assert that we get both the "--help" completion and the names of the two executables we just installed.

### Running a hook and respecting the `IFS` value

Next test:

```
@test "carries original IFS within hooks" {
  create_hook exec hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH

  export RBENV_VERSION=system
  IFS=$' \t\n' run rbenv-exec env
  assert_success
  assert_line "HELLO=:hello:ugly:world:again"
}
```

We've seen a test like this before.  The goal is to cover [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L36-L41){:target="_blank" rel="noopener"}.

 - We create a hook file whose output depends on certain values being set for the [internal field separator](https://web.archive.org/web/20220715010436/https://www.baeldung.com/linux/ifs-shell-variable){:target="_blank" rel="noopener"}.
 - We then set the Ruby version to the machine's default version.
 - We then run `rbenv exec` with a command that we know will be on the user's machine (the `env` command, which ships with all `bash` terminals).
 - When we run `rbenv exec`, we set the value of the internal field separator to the characters which our hook depends on in order to produce the expected output.
 - Lastly, we assert that the command was successful and that the output was printed to STDOUT as expected.

It looks like this test was introduced in response to [this issue](https://github.com/rbenv/rbenv/pull/379){:target="_blank" rel="noopener"}, which reported that [a previous PR](https://github.com/rbenv/rbenv/commit/baf7656){:target="_blank" rel="noopener"} broke the way that plugins behave.

### Forwarding arguments

Next test:

```
@test "forwards all arguments" {
  export RBENV_VERSION="2.0"
  create_executable "ruby" <<SH
#!$BASH
echo \$0
for arg; do
  # hack to avoid bash builtin echo which can't output '-e'
  printf "  %s\\n" "\$arg"
done
SH

  run rbenv-exec ruby -w "/path to/ruby script.rb" -- extra args
  assert_success
  assert_output <<OUT
${RBENV_ROOT}/versions/2.0/bin/ruby
  -w
  /path to/ruby script.rb
  --
  extra
  args
OUT
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L47){:target="_blank" rel="noopener"}.  It creates an executable named `ruby`, whose logic consists of:

 - A simplified version of our `bash` shebang (using the `$BASH` env var, which evalates to `/bin/bash` on my machine).
 - A call to print the "$0" argument, which [expands to the name of the script that's being run](https://web.archive.org/web/20220923182330/https://www.gnu.org/software/bash/manual/html_node/Special-Parameters.html#:~:text=If%20Bash%20is%20invoked%20with,executed%2C%20if%20one%20is%20present.){:target="_blank" rel="noopener"}
 - A loop over all the arguments it receives, printing each one followed by a newline.

We then run `rbenv exec` with the name of that script, passing arguments which are formatted in many different ways:


 - as a flag (`-w`)
 - as a string with spaces in it (in this case, resembling a path to a file)
 - as a double-dash ([signifying the end of command options](https://web.archive.org/web/20221023095659/https://unix.stackexchange.com/questions/11376/what-does-double-dash-mean){:target="_blank" rel="noopener"})
 - as regular arguments (`extra` and `args`)

Lastly, we assert that the command exited successfully.  We then pass a heredoc string to `assert_output`, ensuring that the arguments printed out the way we expected.

### Special test- ensuring `rbenv exec` respects the `ruby -S` command

Next test:

```
@test "supports ruby -S <cmd>" {
  export RBENV_VERSION="2.0"

  # emulate `ruby -S' behavior
  create_executable "ruby" <<SH
#!$BASH
if [[ \$1 == "-S"* ]]; then
  found="\$(PATH="\${RUBYPATH:-\$PATH}" which \$2)"
  # assert that the found executable has ruby for shebang
  if head -n1 "\$found" | grep ruby >/dev/null; then
    \$BASH "\$found"
  else
    echo "ruby: no Ruby script found in input (LoadError)" >&2
    exit 1
  fi
else
  echo 'ruby 2.0 (rbenv test)'
fi
SH

  create_executable "rake" <<SH
#!/usr/bin/env ruby
echo hello rake
SH

  rbenv-rehash
  run ruby -S rake
  assert_success "hello rake"
}
```

This is a huge test.  Before we dive into the code, let's figure out what Ruby's `-S` flag is, and when it's useful.

When I type `man ruby` and search for `-S`, eventually I see the following:

```
     -S             Makes Ruby use the PATH environment variable to search for script, unless its name begins with a slash.  This is used to emulate #! on
                    machines that don't support it, in the following manner:

                          #! /usr/local/bin/ruby
                          # This line makes the next one a comment in Ruby \
                            exec /usr/local/bin/ruby -S $0 $*

                    On some systems $0 does not always contain the full pathname, so you need the -S switch to tell Ruby to search for the script if necessary
                    (to handle embedded spaces and such).  A better construct than $* would be ${1+"$@"}, but it does not work if the script is being
                    interpreted by csh(1).
```

OK, so some machines don't support the use of `#!` shebangs, and the goal of the `-S` flag is to be able to overcome this obstacle, enabling the execution of a Ruby script on those machines too.

After a bit of digging, I found [this PR](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"} with the following description:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-29may2023-448pm.png">
    <img src="/assets/images/screenshot-29may2023-448pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

I don't see any hints about this in [the original PR](https://github.com/rbenv/rbenv/commit/4b6ab0389b5b5401ca530f3edbef024972b943fc){:target="_blank" rel="noopener"}, so we'll have to make inferences and best guesses.

The above Github issue reported the following error:

```
/Users/sam/.rbenv/versions/1.9.3-preview1/bin/ruby -S rake  -r /private/tmp/ruby-build.10166-13998/rubinius-1.2.4/config.rb -r /private/tmp/ruby-build.10166-13998/rubinius-1.2.4/rakelib/ext_helper.rb -r /private/tmp/ruby-build.10166-13998/rubinius-1.2.4/rakelib/dependency_grapher.rb build:mri
/Users/sam/.rbenv/versions/1.9.3-preview1/bin/ruby: no Ruby script found in input (LoadError)
rake aborted!
Command failed with status (1): [/Users/sam/.rbenv/versions/1.9.3-preview1/...]
```

In particular, the command which triggered the error was:

```
/Users/sam/.rbenv/versions/1.9.3-preview1/bin/ruby -S rake ...
```

This must have been happening because (on a machine using RBENV) the `rake` executable that was found by `ruby -S` was the `rake` shim that RBENV generated.  This shim would have had a `bash` shebang, not a `ruby` shebang.  This caused Ruby to return the error `no Ruby script found in input (LoadError)`.

We can replicate this error by making a script named `foo`, containing the following:

```
#!/usr/bin/env bash

echo 'Hello world'
```

If we try to execute this script using `ruby`, we get the same error:

```
$ ruby foo

ruby: no Ruby script found in input (LoadError)
```

So the goal of the test is to ensure that RBENV's shims to play nice with programs such as Rubinius, which make use of the `-S` flag (for what reason, I'm not sure yet, but we can skip that for now).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Now to return to the test code:

```
export RBENV_VERSION="2.0"
```

We start by setting RBENV's Ruby version equal to "2.0", because the `create_executable` function depends on that value being set in order to know which directory to store the executable in.

Next:

```
# emulate `ruby -S' behavior
create_executable "ruby" <<SH
...
SH
```

We create an executable named "ruby" using our `create_executable` helper function, and set its contents equal to a heredoc string.  The `create_executable` function will use the `RBENV_VERSION` value that we just set.

The comment above the function invocation tells us that this executable is meant to emulate the `-S` behavior of the real `ruby` command.  I'm going to assume it's a safe assumption that it disregards any behavior not immediately relevant to that flag, in order to act as a minimally-viable test.

The heredoc string representing our pared-down `ruby` command contains:

```
#!$BASH
```

A simple shebang pointing to the `bash` executable.  Inside our `bash` shell, `$BASH` evaluates to the path to the `bash` executable, for example `/bin/bash`.

```
if [[ \$1 == "-S"* ]]; then
...
else
  echo 'ruby 2.0 (rbenv test)'
fi
```

An `if/else` conditional.  If the user's command starts with `-S`, we execute the `if` branch.  Otherwise, we execute the `else` branch.

Let's get the `else` condition out of the way first, since that's easy.  If the condition is false, we print the string `ruby 2.0 (rbenv test)`.

What do we do if the condition is true?

```
found="\$(PATH="\${RUBYPATH:-\$PATH}" which \$2)"
```

First we create a variable named `found` and store something in it.  But what?

I add some `echo` statements to find out:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-15mar2023-340am.png">
    <img src="/assets/images/screenshot-15mar2023-340am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

When I re-run the test and `cat result.txt`, I get:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-15mar2023-341am.png">
    <img src="/assets/images/screenshot-15mar2023-341am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

OK, so the thing which eventually gets stored in "found" is:

```
/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/root/versions/2.0/bin/rake
```

Now, the reason there are so many additional `echo` statements is so I can answer my remaining two questions, which are:

 - How did this get constructed, and
 - What is it used for?

From the text of "result.txt", we know that "RUBYPATH" is an empty variable, and PATH is not.  So the value that we pass as `PATH` to the `which` command is the original `PATH` value, not the empty `RUBYPATH`.

The `which` command resolves to `which rake`.  So that's how we get the value for "command to derive found", i.e.:

```
PATH=/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/root/versions/2.0/bin:/Users/myusername/Workspace/OpenSource/rbenv/libexec:/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/root/shims:/Users/myusername/Workspace/OpenSource/rbenv/test/libexec:/Users/myusername/Workspace/OpenSource/rbenv/test/../libexec:/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/bin:/usr/bin:/bin:/usr/sbin:/sbin which rake
```

So that's the answer to "How did 'found' get constructed?"  Now, what is it used for?

```
  if head -n1 "\$found" | grep ruby >/dev/null; then
    \$BASH "\$found"
  else
    echo "ruby: no Ruby script found in input (LoadError)" >&2
    exit 1
  fi
```

We pass that filepath represented by the "found" variable to "head -1".  According to the "man head" command, `head` does the following:

```
HEAD(1)                                                                      General Commands Manual                                                                     HEAD(1)

NAME
     head – display first lines of a file

SYNOPSIS
     head [-n count | -c bytes] [file ...]

DESCRIPTION
     This filter displays the first count lines or bytes of each of the specified files, or of the standard input if no files are specified.  If count is omitted it defaults to
     10.

     The following options are available:
...
     -n count, --lines=count
             Print count lines of each of the specified files.
```

So calling `head -n1 $found` means we're taking the very first line of the contents of the `found` file.  We then pipe that first line to `grep ruby >/dev/null`.  So we're looking for the string pattern "ruby" in that first line of code.  We don't want any output so we redirect the results to /dev/null.  We only care about the exit code.  If the exit code is 0 (i.e. if `grep` found any matches with the string "ruby"), then we execute the code inside the `if` statement.  According to the `BASH FOUND` line in the output of "result.txt", that code resolves to:

```
/bin/bash /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/root/versions/2.0/bin/rake
```

The above is what `\$BASH "\$found"` [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/exec.bats#L91){:target="_blank" rel="noopener"} resolves to.  Based on this, we know that we're running an executable file named `rake`...

```
/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv/root/versions/2.0/bin/rake
```

...using the `bash` program:

```
/bin/bash
```

So if the first line of the file (i.e. the shebang) contains the word "ruby", then we run the script.  What if that `if` condition is false?

```
    echo "ruby: no Ruby script found in input (LoadError)" >&2
    exit 1
```

We simply print an error message ("ruby: no Ruby script found in input (LoadError)") to STDERR and exit with a non-zero return code.

(stopping here for the day; 97864 words)

Next block of code in this test is:

```
create_executable "rake" <<SH
  #!/usr/bin/env ruby
  echo hello rake
SH
```

Here we create a 2nd executable (thankfully a much shorter one) named `rake`.  It just contains a ruby shebang and, surprisingly, an `echo` command to print the string "hello rake".  I say "surprisingly" because `echo` is a shell command, not a ruby command, but our shebang tells the shell to execute this script using ruby.  Would that even work?

I make an identical script in my terminal:

```
#!/usr/bin/env ruby

echo hello rake
```

I `chmod +x` it and run it, and get the following error:

```
$ ./bar

Traceback (most recent call last):
./bar:3:in `<main>': undefined local variable or method `rake' for main:Object (NameError)
```

As I thought, we get a Ruby-flavored error saying that there's no variable or method named "rake", which makes sense because we haven't wrapped "hello rake" in quotes in our Ruby script.  I'm curious if `echo` would work if we *did* wrap our string in quotes, so I change the script to this:

```
#!/usr/bin/env ruby

echo "hello rake"
```

Now when I run it, I get this:

```
$ ./bar

Traceback (most recent call last):
./bar:3:in `<main>': undefined method `echo' for main:Object (NoMethodError)
```

This is what I expected- Ruby doesn't have an `echo` method, and we get an error.  So how is our test passing?  Shouldn't it be getting the same errors I'm seeing above?

I remove the quote marks I just added and return the script to its original state.

Ah, wait a minute.  My script is *written* the same as in the test, but I'm not *running* it the same way as in the test.  The test is running the script with the `/bin/sh` prefix.  I'm running it by itself, without specifying a runner (because I thought I could rely on the shebang).  What happens when I try running it with the `/bin/sh` command, the same way the test does?

```
$ /bin/sh bar

hello rake
```

OK, *that* worked.  But then why do they include the Ruby shebang in the test file?  I know this file is executed by the other file we created [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/exec.bats#L85){:target="_blank" rel="noopener"}, and I know that file looks at the first line of the `rake` file to check for a Ruby shebang.  But if that shebang isn't going to be used, then why check for it at all?  I add this to my running list of questions and keep moving.

Last block of code for this test:

```
  rbenv-rehash
  run ruby -S rake
  assert_success "hello rake"
```

We run `rbenv rehash` (presumably to make sure all the shims are in place?).  We then run the `ruby` script that we first created, passing the `-S` flag and the `rake` argument.  Lastly, we assert that the command succeeded, and that "hello rake" was printed to STDOUT.

This confuses me.  We run the `rbenv rehash` command, but I'm not sure why because the next command we run is not an `rbenv` command.  Internally, `rbenv` is not used by either the `ruby` script nor the `rake` command that it runs.  So why would we need to ensure that shims exist if there's no `rbenv` command to rely on those shims?

Come to think of it, why is this test even needed?  If it's not running `rbenv`, it's not testing `rbenv`.  Why would we write a test just to ensure that a script named "ruby", which only exists within the scope of this one test, works the way we expect?  Of course it works the way we expect- we wrote it in our test!  We're essentially testing a fake script whose only purpose is to get a test to pass.  It seems like circular logic.

I look up the git history for this test.  I find these 4 ([1](https://github.com/rbenv/rbenv/commit/4b6ab0389b5b5401ca530f3edbef024972b943fc){:target="_blank" rel="noopener"}, [2](https://github.com/rbenv/rbenv/commit/7fc5f46bbb843c6be95c3f87d19ba21fef25c5b8#diff-dcacfbee60d602ec801615df3c0d46f768d41c54d4b50debbbdaa9d50ff17e3e){:target="_blank" rel="noopener"}, [3](https://github.com/rbenv/rbenv/commit/7a10b64cf7e4df3261dec94f3c609a64a04998ef){:target="_blank" rel="noopener"}, and [4](https://github.com/rbenv/rbenv/commit/95a039aaaa3855ea2df4855ad38c06faaba01f9a#diff-dcacfbee60d602ec801615df3c0d46f768d41c54d4b50debbbdaa9d50ff17e3e){:target="_blank" rel="noopener"}).  [One of the PRs](https://github.com/rbenv/rbenv/commit/95a039aaaa3855ea2df4855ad38c06faaba01f9a){:target="_blank" rel="noopener"} mentions [an issue](https://github.com/rbenv/rbenv/issues/480){:target="_blank" rel="noopener"} that the PR is meant to fix.  I open that and read a bit:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-350am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Huh, so running the following code caused `rake cucumber` to fail:

```
/home/user/.rbenv/versions/1.9.3-p448/bin/ruby -S bundle exec cucumber  --profile default
```

Hey, they're running `ruby -S` just like our test is.  Another thing I notice is their `ruby` executable is located inside a sub-folder of the `/home/user/.rbenv` directory.

Are we sure that our test is definitely not running `rbenv`?

As an experiment, I add the following to my `rbenv-exec` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-351am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I also add the following to the test itself:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-352am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

If `rbenv` is being invoked, I expect both the output of `which ruby` from the test file and the output of `echo 'inside rbenv-exec'` from the command file to appear in a new file named "result.txt".  I run the test and `cat` that file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-353am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So it *is* being invoked.  That must mean that the `ruby` command being called from the test file is the RBENV shim of ruby, which *then* calls the real Ruby executable.  To refresh my memory, I open up that file and see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-355am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

At the bottom, we see `exec "/usr/local/bin/rbenv" exec ...`.  That's us calling the shell's `exec` program, and telling it to run the equivalent of "rbenv exec".

OK, *now* I see why this test is needed, *and* I see that it is in fact calling `rbenv exec` after all.  It's just doing it indirectly.  This is also why `rbenv-rehash` is needed- otherwise, the shim that we're calling here wouldn't exist!

But I'm still confused about something I saw in that PR [here](https://github.com/rbenv/rbenv/commit/95a039aaaa3855ea2df4855ad38c06faaba01f9a){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-356am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

What is "shelling out to Ruby"?  And why / how did the reverted PR break this "shelling out" process?  I Google "shelling out to Ruby" and find [this StackOverflow link](https://web.archive.org/web/20150320011119/https://stackoverflow.com/questions/28628985/what-does-shell-out-or-shelling-out-mean){:target="_blank" rel="noopener"}, with the following answer:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-358am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So it sounds like we're talking about calling a Ruby program from a shell program?

(stopping here for the day; 98883 words)

After a bit of clicking around RBENV's Github repo, I find [this issue](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}, which mentions the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-359am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

This appears to be the backstory for how the whole "-S" thing started.  In a very early version of RBENV (this issue is #14), its shims were incompatible with `ruby -S`.  But *how* were they incompatible?  Why would RBENV (in its state at that time) prevent `-S` from working?

I see [the PR associated with this issue](https://github.com/rbenv/rbenv/commit/2a495dc9ac842f745239bb7bb6402a8d8c168992){:target="_blank" rel="noopener"} from looking at the discussion in the issue, and I see that this PR adds the output of `rbenv-which "$RBENV_COMMAND"` to the front of the `$PATH`.  This change is supposed to fix the `-S` problem:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-400am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

It's important to note that, in the end, there continued to be issues with `-S` even after this PR was added.  But for now I just want to mentally catch up to the code authors and their state of mind *at the time they wrote this*.  Later, I can catch up the rest of the way.

I try replicating some of the code from [the PR](https://github.com/rbenv/rbenv/commit/2a495dc9ac842f745239bb7bb6402a8d8c168992){:target="_blank" rel="noopener"} in my terminal, using `ruby` as a stand-in for `RBENV_COMMAND` here:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-401am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

If `RBENV_BIN_PATH` is what was prepended to `PATH`, then running `rbenv exec ruby` would have caused `/Users/myusername/.rbenv/versions/2.7.5/bin` to be prepended to my path, at least for the purposes of this running process.

Again, how does that help `-S` do its job?

And b the way, what *is* the job of the "-S" flag?  According to the "man ruby" command:

```
     -S             Makes Ruby use the PATH environment variable to search for script, unless its name begins with a slash.  This is used to emulate #! on machines that don't
                    support it, in the following manner:

                          #! /usr/local/bin/ruby
                          # This line makes the next one a comment in Ruby \
                            exec /usr/local/bin/ruby -S $0 $*
```

This makes it sound like the "-S" flag lets the user specify a value for PATH when searching for the executable.  So for example, if I have a Ruby file named "foo" in a directory named "/Users/myusername/bar", then I can add that directory to my "$PATH" variable and execute my "foo" file by typing `ruby -S foo` instead of `ruby /Users/myusername/bar/foo`?  I mean I guess that's cool, but why was it important enough to write a test about, especially for the `exec` command?  Wouldn't the `-S` flag just get passed along to the `ruby` command, as with any other flags?  Why do we have a test for `-S` and not for all the myriad other flags that we could pass when running `rbenv exec ruby`?
EDIT: after a few days of thinking, I think I understand why this is important.  The key is in the above "help ruby" output:

```
This is used to emulate `#!` on machines that don't support it
```

Some machines apparently don't support shebangs.  Interesting.  I try to look up which ones, starting with Googling "shebang computing".  The first result is [a Wikipedia article](https://web.archive.org/web/20221102170415/https://en.wikipedia.org/wiki/Shebang_(Unix)){:target="_blank" rel="noopener"} whose title is "Shebang (Unix)".  That title, plus the sentence in the 2nd paragraph (below), give a clue:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-409am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Together, these tell me that one type of machine that *wouldn't* support a shebang is a non-Unix system, such as Windows.  I find another StackOverflow answer [here](https://web.archive.org/web/20220725080603/https://stackoverflow.com/questions/7574453/shebang-notation-python-scripts-on-windows-and-linux){:target="_blank" rel="noopener"}, which tells me essentially the same thing, when I Google "do shebangs work in windows":

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-413am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

I feel like that's a good enough answer for now, so I keep going.

So getting back to [the problem that initiated this whole discussion](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}, some Ruby programs (which would be affected if a Ruby shim were being used) were calling `ruby -S` to execute certain files, meaning those files would be checked for a Ruby shebang before being executed.  But RBENV shims use a `bash` shebang, not a `ruby` shebang.

According to [this issue](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}, the Rubinius installer included certain lines of code which would have caused an error when used with the version of RBENV at that time (SHA # 2fa743206067034aa5a68d7d730b6cbbb3db8124):

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-414am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

It might be instructive to try and reproduce this error.  In order to do that, I'll need to use the same version of RBENV as the SHA above.  The easiest way to do that is to edit my PATH so that the first version of RBENV that it encounters is the one in my current directory, *not* the one that's installed (i.e. the one at `/usr/local/bin/rbenv`).  I can simply do this by prepending any command I enter into the terminal with "PATH='./libexec'".  Since the `rbenv` file lives in `libexec`, the shell will find the executable there and stop searching before it checks `/usr/local/bin/rbenv`.

Since the above error was produced when attempting to install Rubinius, that's the same operation I'll attempt to do with the above updated PATH.  I *could* install Rubinius using a package manager like Homebrew, and if I were actually interested in Rubinius for its own sake, that's what I would do.  However, since I'm only interested in it because I'm trying to reproduce this error, I decide to use the "Install from source" instructions on [this link](https://github.com/rubinius/rubinius#installing-rubinius){:target="_blank" rel="noopener"} instead.

"Installing from source" means downloading the original code from Github, and running an install command in that codebase.  The advantage of this is that, before I run the install command, I can roll back to an earlier version of the code, one that more closely matches what the RBENV core team would have been likely to see at the time.  I can't be 100% sure that it will be the same version they saw at the time, but I can compare the date of [the RBENV issue](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"} (Aug 5, 2011) with the dates of the Rubinius version releases, and I can likely get much, much closer.

I try to clone the repo using the instructions below:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-415am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>


However I get the following error:

```
$ git clone git://github.com/rubinius/rubinius.git
Cloning into 'rubinius'...
fatal: unable to connect to github.com:
github.com[0: 20.201.28.151]: errno=Operation timed out
```

I Google around a bit, plugging in the search term "fatal: unable to connect to github.com errno=Connection refused", and discover this StackOverflow link:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-417am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try changing `git://` to `https://`, and this time it works.

```
$ git clone https://github.com/rubinius/rubinius.git

Cloning into 'rubinius'...
remote: Enumerating objects: 289457, done.
remote: Total 289457 (delta 0), reused 0 (delta 0), pack-reused 289457
Receiving objects: 100% (289457/289457), 164.08 MiB | 6.73 MiB/s, done.
Resolving deltas: 100% (199787/199787), done.
Updating files: 100% (6784/6784), done.
~/Workspace/OpenSource ()  $ cd rubinius
```

Next step is to figure out how to roll back to a certain version.  I don't know which version I want, but I know which date I want to roll back to.  Can you check out an earlier commit based on a date, as opposed to a SHA?  I Google "git checkout a certain date", and get [this StackOverflow answer](https://stackoverflow.com/questions/6990484/how-to-checkout-in-git-by-date){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-419am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I have a bad habit of skipping the answer and copy/pasting the code that looks like a solution, and that's what I did here at first.  I plugged in the above command, changing "2009-07-27" to "2011-05-12".  One day after the date that the RBENV issue was posted, to start with.  I can always keep going backwards from there, but it's harder to roll forward (or at least, I don't yet know how to do so).  Anyway, this is what I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-420am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I see the following warning here:

```
warning: log for 'master' only goes back to Thu, 10 Nov 2022 10:24:56 -0500
```

I also notice that message at the very bottom:

```
HEAD is now at b7a755c83f No more Bundler.
```

I happened to do a `git log` when I first navigated into this repo, and I noticed that "No more Bundler." was the commit message of the HEAD commit.  So it looks like this command didn't send me back to the commit on Aug 12, 2011.  I'm guessing that's because of what the warning tells us, i.e. that the log for master only goes back to... today (at the time I'm writing this, it's 10 Nov 2022).

OK, fine, I'll go back and read the SO post more closely.  I then see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-425am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so there's something called a "reflog", and the entries in this log expire after 90 days.  So this wouldn't have been useful to me.  I keep reading and see another option:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-426am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try this new command, again swapping out their date for mine:

```
$ git checkout `git rev-list -n 1 --first-parent --before="2011-08-12 13:37" master`
Updating files: 100% (15107/15107), done.
Note: switching to 'aeed62a1e75f2eee056549c8e80f2a043c28242c'.

...

HEAD is now at aeed62a1e7 Rewrote the language yield specs.
```

When I do a `git log`, I see:

```
$ git log
commit aeed62a1e75f2eee056549c8e80f2a043c28242c (HEAD)
Author: Brian Ford <bford@engineyard.com>
Date:   Fri Aug 12 00:01:55 2011 -0700

    Rewrote the language yield specs.

commit 01322f9b795dc1647422493615dc95a3209e14dd
Author: Brian Ford <bford@engineyard.com>
Date:   Thu Aug 11 16:43:01 2011 -0700

    A bunch of block and proc language specs.

commit 71ac8edd7c8619284c9557361bed63a7c5ca7dd4
Author: Brian Ford <bford@engineyard.com>
Date:   Wed Aug 10 18:28:13 2011 -0700

    Disable Travis email notifications until notify-on-fail is possible.

...
```

Looks good to me!  Now let's try to install, and see if we get the same error that the RBENV issue reported:

```
$ PATH="/Users/myusername/Workspace/OpenSource/rbenv:$PATH" ./configure --prefix="/Users/myusername/Workspace/OpenSource/rubinius-install" && make install

ERROR: Please unset RUBYLIB to configure Rubinius
```

Damn.  I got an error, but not the one I was hoping for (i.e. something resembling the error in [the RBENV issue](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}).  I Google the error ("ERROR: Please unset RUBYLIB to configure Rubinius"), and I see [this Github link](https://github.com/rbenv/rbenv-gem-rehash/pull/10){:target="_blank" rel="noopener"} as the 2nd result:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-437am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I read through the PR and see that it's meant to address the same error I'm seeing now.  It also says "this is a terrible thing to do", so I mentally reduce the odds of this working, but I proceed anyway.

The diff for the PR looks as follows:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-438am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

It looks like the only affected file is `etc/rbenv.d/exec/~gem-rehash.bash`.  I replace the version of this file on my machine with the updated (aka green) version in the PR, and re-run the install command.

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-439am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

At this point I decide to give up.  I don't have a clear path to debugging the above errors, and I don't know how else to try and reproduce [this error](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}.

(stopping here for the day; 100193 words)

OK, so I *think* I get the gist of [this PR](https://github.com/rbenv/rbenv/commit/2a495dc9ac842f745239bb7bb6402a8d8c168992){:target="_blank" rel="noopener"}: the intent was to look for the *version* of the executable that the user was searching for which corresponded to the one installed in RBENV's shims, and specifically the shim for the user's current RBENV version of Ruby.  That's what would be accomplished if we pre-pended `PATH` with the output of `rbenv-which "$RBENV_COMMAND"`.

It also makes sense what the two added lines of code are doing [here](https://github.com/rbenv/rbenv/commit/2a495dc9ac842f745239bb7bb6402a8d8c168992){:target="_blank" rel="noopener"}, and why that fits in with the above intent.  In the first added line, we create a variable named `RBENV_BIN_PATH`, which stores `RBENV_COMMAND_PATH` in the format needed to be prepended to `PATH`.  And in the 2nd line, we do the prepending.  From there, [this line of code](https://github.com/rbenv/rbenv/commit/2a495dc9ac842f745239bb7bb6402a8d8c168992#diff-d04f77bb5cee32ae66e503a1d4b712f0f2e775f8ecfed610ab5f17cbcaeb8cdcR22){:target="_blank" rel="noopener"} would execute the originally-requested command (i.e. `ruby`), passing any additional arguments / flags.  If `-S` were one of these flags, Ruby would use the now-updated `PATH` to search for the executable (i.e. in [this error](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"}, that executable would be `rake`).

I also get why Mislav would make the comment he made [here](https://github.com/rbenv/rbenv/pull/372){:target="_blank" rel="noopener"}, saying that this solution prevents users from using a different version of Ruby.  This is because the directory which is prepended to PATH contains the user's current RBENV Ruby version.  That directory will always be found first, before any directories for other Ruby versions, since it's the first one in PATH (that's the whole point of the prepending operation in the first place).

OK, I think I get the story up to [this point](https://github.com/rbenv/rbenv/pull/372){:target="_blank" rel="noopener"}.  Without going through each issue and PR with a fine-toothed comb, I can't be sure that this constitutes all the "-S"-related drama up to this point, but I'm willing to assume so for now.

And it looks like this solution worked fine as of [this point](https://github.com/rbenv/rbenv/pull/372){:target="_blank" rel="noopener"}, with the exception that we're now locked into a specific Ruby version.  What I don't get is, why would this be a problem exactly?  Why would a user want to pick one Ruby version to use, but then shell out to another Ruby version from there?  Mislav calls it "the most common pitfall with rbenv" [here](https://github.com/rbenv/rbenv/pull/372){:target="_blank" rel="noopener"}, and references [this issue](https://github.com/rbenv/rbenv/issues/121){:target="_blank" rel="noopener"} as an example, so that's where I start trying to answer this question.

The issue appears to be the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-440am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

To get my bearings, I try the same commands on my machine:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-441am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so the problem appears to still be present in my version of RBENV.  Good to know.  But what are these commands actually trying to do?

```
ruby --version
```

This one's easy- we're just checking the Ruby version as a baseline for comparison against the next 2 commands.

```
perl -e 'system("RBENV_VERSION=system ruby -e \"puts RUBY_VERSION\"")'
```

The `-e` flag tells `perl` to run the perl code inside the single-quotes, rather than running code from a script file containing perl code.  The code that we're telling `perl` to run calls Perl's `system` command, which calls out to a shell process.  Inside that shell process, we run the shell code inside the parentheses.  That shell code sets `RBENV_VERSION` equal to "system" and runs the `ruby` command, passing an "-e" flag of its own and some Ruby code to puts an environment variable's value.  So we're doing the same thing twice (once with Perl and once with Ruby): running a language's interpreter and telling it to run some code which we pass to the interpreter directly, as opposed to passing the interpreter a file we want it to execute.

```
ruby -e 'system("RBENV_VERSION=system ruby -e \"puts RUBY_VERSION\"")'
```

Here we're doing the same thing as step #2 directly above.  Except this time both our outer and inner language is Ruby (as opposed to our inner language being Ruby and our outer lang being Perl).

The Ruby version from RBENV on my machine is 2.7.5, and the system version of Ruby is 2.6.8, as seen here;

```
$ /usr/bin/env ruby --version

ruby 2.6.8p205 (2021-07-07 revision 67951) [universal.x86-darwin21]
```

When we call `ruby --version` or the 3rd command above (`ruby -e 'system...`), we get the correct version.  But when we call the 2nd command above (`perl -e 'system...`), we get the non-RBENV version.

That's because... why again?

Each time we run `puts "$RUBY_VERSION"`, we've just finished running `RBENV_VERSION=system`.  So what I'm wondering now is:

What is changing the value of `RUBY_VERSION`?  I don't see that constant referenced anywhere in the RBENV codebase, so I'm unsure how it's being updated.


Based on reading [this link](https://web.archive.org/web/20220911152812/https://www.rubyguides.com/2019/01/ruby-environment-variables/){:target="_blank" rel="noopener"}, I *think* `RUBY_VERSION` is set internally by Ruby.  So something we're doing outside of the `ruby` command must be influencing the way Ruby internally sets the value of this env var.

My best guess right now is that a given Ruby installation hard-codes this env var's value, and that the behavior that results when you `puts RUBY_VERSION` depends on which Ruby installation you're running that from.  I'm thinking that Ruby gets its version from that hard-coded `RUBY_VERSION` constant, and that each installed version of Ruby has a different hard-coded value for that constant.

So (I guess?) the reason that executing the above `perl` command doesn't work is that it doesn't hit an RBENV shim before hitting the native `perl` command, therefore it doesn't run `rbenv exec` inside said shim, therefore `rbenv exec` doesn't get a chance to modify `PATH` with the correct Ruby version.

But something in this line bothers me:

```
ruby -e 'system("RBENV_VERSION=system ruby -e \"puts RUBY_VERSION\"")'
```

Since we're running `rbenv exec`, we must be reaching [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L24){:target="_blank" rel="noopener"}, which calls `rbenv-version-name`.  That file, in turn, [checks](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L6){:target="_blank" rel="noopener"} whether `RBENV_VERSION` already exists, and if it doesn't, sets it according to the contents of the RBENV version file (either a `.rbenv-version` file or the global version file).  What's happening here when we call the above `system` command with two `ruby` commands, which isn't happening with the "one `perl` and one `ruby` command" version?

I add some `echo` statements to that file, specifically here:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-444am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run it, I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-445am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

I run it again, this time changing `perl` to `ruby`.  This time, I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-446am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

So the value of `RBENV_VERSION` is somehow nullified when we use the `ruby` command, causing us to enter the `if` block.  But that's not the case when we use `perl`.

(stopping here for the day; 101,230 words)

OK, I'm a little bit turned around after a few days of working on this.  Here's what I know so far:

 - The `perl` executable is not controlled by an RBENV shim.  On my machine at least, it ships with the laptop:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-447am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

 - The `ruby` program, however, *is* controlled by RBENV, specifically by the shell function that gets created when `rbenv init` runs in the `.zshrc` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-448am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

 - The value of `RBENV_VERSION` is getting unset somehow when we use the `ruby` command, but not the `perl` command.

I know that environment variables are typically unset using the `unset` command, so I look for this command in the codebase:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-449am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

I wonder if any of these are actually being hit in our code path, so I place `echo` statements before the ones I think are good candidates (inside `rbenv-sh-shell`):

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-450am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-451am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run the `ruby` command again, I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-452am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

I don't see my `echo` messages, therefore (I think?) we can assume that the reason `RBENV_VERSION` is unset by the time we get to `rbenv-exec` is because it was never set in the first place.

We can deduce the following, based on the output below:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-453am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</p>

When running the `perl -e` version:

 - We don't reach the "first line of rbenv exec" logline until we're executing the command which is run by the `system` call.
 - At this point, we're passing `RBENV_VERSION=system` to `ruby -e`.
 - This explains why we see `RBENV_VERSION inside rbenv-exec: system` as the 2nd logline.
 - Because this value is defined, we don't enter the `if` block, and therefore we *don't* see the "inside 'if' block" logline.
 - Because of this, in turn, we don't set `RBENV_VERSION` equal to the output of `rbenv-version-file-read`, which would have set `RBENV_VERSION` equal to 2.7.5.  Instead, we leave its value as "system".
 - Because its value is still "system" by the time it reaches [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L44){:target="_blank" rel="noopener"}, we never prepend `PATH` with `RBENV_BIN_PATH` (i.e. the RBENV-specific path to the user's requested command).  In our case, remember, that requested command is "ruby".
 - Because `PATH` never gets prepended with the RBENV-specific path to the user's command, we use the default system path to that command.  In our case, that default system path to "ruby" is `/usr/bin/ruby`.
 - The version of Ruby in `/usr/bin/ruby` is (on my machine) 2.6.8, so that's what gets printed to the screen.

When running the `ruby -e` version:

 - The `ruby` that we're running in `ruby -e` is the RBENV shim file for "ruby".  Therefore we're *actually* running `rbenv exec ruby -e`.
 - Inside `rbenv exec`, we eventually reach [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L24){:target="_blank" rel="noopener"} and call `RBENV_VERSION="$(rbenv-version-name)"`.
 - `rbenv-version-name`, in turn, reaches [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L6){:target="_blank" rel="noopener"}, which detects that no value has been set for `RBENV_VERSION` up til now, so it enters the `if` block and reads the contents of the RBENV version file that it finds.

OK, I think we can safely say that this is the correct explanation of the difference in behavior between the `perl` and `ruby` commands, as well as the reason why the two commands end up with different versions of RBENV.

But I don't understand this problem as well as I feel like I need to.  Reading up on the evolution of the problem from start to finish would improve my understanding of what happened when, and more importantly, why:

 - Many programs which execute Ruby commands do so using the "-S' flag, because this allows those programs to work on machines which don't support shebangs.
 - [Originally](https://github.com/rbenv/rbenv/blob/2fa743206067034aa5a68d7d730b6cbbb3db8124/libexec/rbenv){:target="_blank" rel="noopener"}, the only other places where `PATH` was being modified were [here](https://github.com/rbenv/rbenv/blob/2fa743206067034aa5a68d7d730b6cbbb3db8124/libexec/rbenv-init#L55){:target="_blank" rel="noopener"} and [here](https://github.com/rbenv/rbenv/blob/2fa743206067034aa5a68d7d730b6cbbb3db8124/libexec/rbenv#L18){:target="_blank" rel="noopener"}.
    - The 1st prepending adds the shims directory to PATH, inside `rbenv-init`.
    - The 2nd prepending adds `libexec/` to `PATH` (i.e. the place where all the RBENV command files live).
 - This caused RBENV to be incompatible with "-S", because _____.
 - [This PR](https://github.com/rbenv/rbenv/issues/14){:target="_blank" rel="noopener"} was merged by Sam Stephenson, the original author of RBENV.  The goal was to make RBENV compatible with the aforementioned "-S" flag.
 - The proposed solution was to prepend `RBENV_BIN_PATH` (i.e. `/Users/myusername/.rbenv/versions/2.7.5/bin` for the `ruby` command) to the beginning of `PATH`, but only when an RBENV command was invoked.
    - In other words, the value of `RBENV_BIN_PATH` for the `perl` command is `/usr/bin`, but since `RBENV_VERSION` is "system" when `perl` is the command, `/usr/bin` would never have been prepended to `PATH`.  A bit of context:


It's at this point that I stop and re-assess my focus on the "-S" bug.  I may not understand how to fix the bug in question.  But I do feel like I know enough to understand the purpose of the original test that set me on this quest.  And maybe that's gonna have to be enough for now, because I'm starting to lose morale and momentum.  And that's the bigger issue.  I can always come back to this point and continue banging my head against the wall.

Now that we've discussed the tests, let's move on to the code:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec){:target="_blank" rel="noopener"}

First few lines of code:

```
#!/usr/bin/env bash
#
# Summary: Run an executable with the selected Ruby version
#
# Usage: rbenv exec <command> [arg1 arg2...]
#
# Runs an executable by first preparing PATH so that the selected Ruby
# version's `bin' directory is at the front.
#
# For example, if the currently selected Ruby version is 1.9.3-p327:
#   rbenv exec bundle install
#
# is equivalent to:
#   PATH="$RBENV_ROOT/versions/1.9.3-p327/bin:$PATH" bundle install

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

Same deal as before:

The `bash` shebang
Comments summarizing what the command is and how to use it
Telling bash to exit on the first error
Setting "verbose" mode (at least, that's what I call it) if the user has set the `RBENV_DEBUG` environment variable

Next few lines of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  exec rbenv-shims --short
fi
```

Here we check whether the user passed the `--complete` flag as the first argument to `rbenv exec`.  If they did, we run `rbenv-shims --short`.  This is a different command from what we usually run when the user passes `--complete`.  For instance, [here](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-commands#L9){:target="_blank" rel="noopener"} we just echo basic strings when the user passes this flag.  I'm curious why we do things differently here.

First of all, what does `rbenv exec --complete` result in?

```
$ rbenv exec --complete
aws-v3.rb
bootsnap
brakeman
bundle
bundle-audit
bundler
bundler-audit
byebug
chromedriver
chromedriver-update
coderay
commonmarker
console
dotenv
elastic_ruby_console
erb
erubis
faker
fission
fluent-post
fog
foreman
gecko_updater
geckodriver
gem
gemoji
geoip
github-markup
github-pages
gli

...
```

And that's just the output starting with A through G.  It looks like this output is based on certain Ruby dependencies that I've previously installed, given the comments we read at the beginning of this file mentioned the specific Ruby version:

```
# Summary: Run an executable with the selected Ruby version
#
# Usage: rbenv exec <command> [arg1 arg2...]
#
# Runs an executable by first preparing PATH so that the selected Ruby
# version's `bin' directory is at the front.
#
# For example, if the currently selected Ruby version is 1.9.3-p327:
#   rbenv exec bundle install
#
# is equivalent to:
#   PATH="$RBENV_ROOT/versions/1.9.3-p327/bin:$PATH" bundle install
```

And judging by the content of [the `rbenv-shims` file](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-shims){:target="_blank" rel="noopener"} (which we'll get to later), it looks like if the user runs `rbenv shims --short`, rbenv will print the name of each shim in its `shims` directory.  Since (I believe?) there's meant to be one shim in that directory for each Ruby gem I have installed, I'm guessing that we add a shim to this folder whenever we install a Ruby gem which exposes a terminal command.

So that's why we run `exec rbenv-shims --short` here, and nothing else (i.e. no `echo`'ing as with other commands).  It looks like the only completions we expose for `rbenv exec` are for commands which you can run using `rbenv exec`.

Next few lines of code:

```
RBENV_VERSION="$(rbenv-version-name)"
RBENV_COMMAND="$1"

if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage exec >&2
  exit 1
fi
```

Here we set the `RBENV_VERSION` variable equal to the output of the `rbenv-version-name` command, and we set the `RBENV_COMMAND` variable equal to the first argument that was passed to `rbenv exec`.  Then if there *was no* first argument passed to `rbenv exec`, we print the `rbenv-help` script for the `exec` command (specifically, that script's output when it receives the `--usage` flag as an argument), and exit this script.

(stopping here for the day; 33174 words)

Next few lines of code:

```
export RBENV_VERSION
RBENV_COMMAND_PATH="$(rbenv-which "$RBENV_COMMAND")"
RBENV_BIN_PATH="${RBENV_COMMAND_PATH%/*}"
```

Here we make `RBENV_VERSION` into an environment variable so that it can be used (presumably) by whichever command is being run by `rbenv exec`.  We also create two new variables (not yet env vars)- `RBENV_COMMAND_PATH`, which we set equal to the output of `rbenv-which $RBENV_COMMAND`, and `RBENV_BIN_PATH`, which we set equal to the value of the previous variable, minus the last `/` character and anything after it.  When I just now `echo`ed the value of `RBENV_BIN_PATH`, it came back as `/Users/myusername/.rbenv/versions/2.7.5/bin`.  The contents of this directory appears to be the Ruby executable scripts for each of the gems I have installed for my current Ruby version (in this case, 2.7.5, judging by the directory path):

```
$ ls /Users/myusername/.rbenv/versions/2.7.5/bin
aws-v3.rb					install_dtrace_on_ubuntu			rspec
bootsnap					irb						rubocop
brakeman					jekyll						ruby
bundle						jmespath.rb					ruby-parse
bundle-audit					just-the-docs					ruby-prof
bundler						kramdown					ruby-prof-check-trace
bundler-audit					ldiff						ruby-rewrite
byebug						listen						safe_yaml
chromedriver					mongrel_rpm					sass
chromedriver-update				newrelic					sass-convert
coderay						newrelic_cmd					scss
commonmarker					nokogiri					setup
console						nrdebug						socksify_ruby
dotenv						pry						spring
elastic_ruby_console				puma						sprockets
erb						pumactl						thor
erubis						racc						tilt
faker						racc2y						xray_profile_ruby_function_calls.d
fission						rackup						xray_top_10_busiest_code_path_for_process.d
fluent-post					rails						xray_top_10_busiest_code_path_on_system.d
fog						rake						xray_trace_all_custom_ruby_probes.d
foreman						rbvmomish					xray_trace_all_ruby_probes.d
gecko_updater					rdbg						xray_trace_memcached.d
geckodriver					rdoc						xray_trace_mysql.d
gem						resque						xray_trace_rails_response_times.d
gemoji						resque-scheduler				y2racc
geoip						resque-web					yard
github-markup					restclient					yardoc
github-pages					ri						yri
gli						ri_cal
htmldiff					rougify
```

Next few lines of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks exec`)
IFS="$OLDIFS"
```

Here we save the old internal field separator, temporarily set a new separator (the carriage return), create a variable named `scripts` corresponding to the output of `rbenv-hooks exec`, and then reset the IFS back to its original value.

I suspect that we change `IFS` and use the `(...)` syntax so that the value of `scripts` is an iterable array of strings.  It's been awhile since we did an experiment, so let's test this hypothesis by adding some `echo` statements to the `rbenv-exec` script:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-457am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Here I added lines 35, 37, 38, 39, 43, and 44.  We're first setting `scripts` equal to just the plain output of `rbenv-hooks exec`, with no `(...)` wrapper or tweaking of the IFS.  We then print it out along with its length, and then execute the original logic (updating the IFS and wrapping the `rbenv-hooks` command in parens), and print out the new value of `scripts` along with its new length.  My hypothesis is that we'll get different lengths for `scripts` #1 vs. #2, i.e. the length of `scripts` #2 will be shorter because this time it'll be an array of strings instead of a single string, and the length of an array is its # of items, not its # of characters.

Here's what we get when we run `rbenv exec ruby` in a new tab:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-458am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Interesting.  I suspect that the length is the same in both cases because it's a single string in both cases.  According to StackOverflow, `bash` [doesn't have data types](https://stackoverflow.com/a/29840856/2143275){:target="_blank" rel="noopener"}, so it's not as simple as calling `type` on a variable to see whether it's a string or an array.  I'm actually not immediately sure how I would go about testing this!  I may have to come back to this experiment when I've learned more `bash`.

Next lines of code:

```
for script in "${scripts[@]}"; do
  source "$script"
done
```

This `for` loop iterates over each filepath contained in the `scripts` variable, and runs `source` on it.  I'm pretty sure the reason we had to reset `IFS` before declaring the `scripts` variable is so that we could do this iteration.  This `for` loop also implies the output of `rbenv-hooks exec` could potentially be multiple filepaths, not just the one we saw just now (i.e. `/usr/local/Cellar/rbenv/1.2.0/rbenv.d/exec/gem-rehash.bash`).  We haven't investigated the `rbenv-hooks` command which populated the value of `scripts`, and we won't know for sure until we get to it.   But based on how this `for` loop looks, I think it's a safe assumption.

By the way, when I open the above `gem-rehash.bash` file, I see one line of code:

```
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

Looks like this just prepends a filepath or a directory or something to a pre-existing environment variable named `RUBYLIB`.  I try `echo`ing both `RUBYLIB` and `BASH_SOURCE` in the `gem-rehash.bash` file, and then running `rbenv exec ruby` in a new terminal, and I get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-500am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

This doesn't tell me much, unfortunately.

I do some digging into the Git history of the `for` loop, and I see that at one point the file used to look like the following, in red:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-501am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

I see references to `PLUGINS` here, and the current version of the code does reference the `rbenv-hooks` command, so maybe it's necessary to enable the user's plugins before running `rbenv exec`.  Maybe certain commands that you can run with `rbenv exec` could depend on the user's plugins / hooks.

BTW- What is the difference, if any, between plugins and hooks, with respect to RBENV?  I'll have to add this to my running list of questions.

While I was digging through the git history of `rbenv-exec`, I found [this commit](https://github.com/rbenv/rbenv/commit/99035a49a9c55d4a5ee67bdc7e372cc9221756c9#diff-0ca831c894125a742cf8127263c4eaacee60548229cbf76360cae72cf624dd7c){:target="_blank" rel="noopener"} in Github.  It shows that the file originally looked like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-502am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

The file is clearly missing a lot of the code it now has, including the looping over the `scripts` variable and the `source`ing of each file.  Maybe if I find the commit which introduced that code, I can figure out why it's needed.  I find that commit [here](https://github.com/rbenv/rbenv/commit/a9837f3a066f6a2a7898ddb281a5ff34e1750df1){:target="_blank" rel="noopener"}, and the commit message is `look for plugin scripts to extend functionality`.  At the time of that commit, the entire file looked like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-503am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

I think it's safe to say that plugins can extend the functionality of the command that the user is trying to run via `rbenv exec`.  It'd be great to have an example of how that would work.

TO-DO: write an rbenv plugin which extends the functionality of a command that is run via `rbenv exec`.

Next lines of code:

```
shift 1
if [ "$RBENV_VERSION" != "system" ]; then
  export PATH="${RBENV_BIN_PATH}:${PATH}"
fi
```

We shift off the current first-position argument, so that on the last line of code in this file, we can pass the remaining arguments to the command that we `exec`.  We then prepend the `PATH` variable with the value of `RBENV_BIN_PATH`.  We do this so that, in the subsequent `exec` command, the first suitable folder in which the shell finds the user's requested executable is the subfolder of the Ruby version that your configuration has asked RBENV to use.  For example, if my current RBENV Ruby version is 2.7.5, RBENV will prepend `/Users/myusername/.rbenv/versions/2.7.5/bin/` to my path, meaning my shell will search this folder first for any executable with the name of the command I'm trying to run.

However, we only do this prepending if the user isn't currently using their system version of Ruby.  I was curious *why* we have this `if` check, and after a bit of digging I found [this commit](https://github.com/rbenv/rbenv/commit/8ee2f2657a088851d0aa75736c7b0305a10522f1){:target="_blank" rel="noopener"}.  It appears that, if the user is running the system version of Ruby, then their Ruby load path is already part of the overall PATH.  And adding it a 2nd time [could break things](https://github.com/rbenv/rbenv/commit/8ee2f2657a088851d0aa75736c7b0305a10522f1){:target="_blank" rel="noopener"}.

Last line of code is:

```
exec -a "$RBENV_COMMAND" "$RBENV_COMMAND_PATH" "$@"
```

To see what this command resolves to, I put the following `echo` statement just above it:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-504am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

When I ran `rbenv exec ruby -e 'puts 1+1', I saw the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-15mar2023-505am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

So now we know what the actual command is that's being run.

According to the SS64.com [command line reference](https://web.archive.org/web/20220628155926/https://ss64.com/bash/exec.html){:target="_blank" rel="noopener"}, `exec` replaces the shell without creating a new process if command is supplied.  The `-a` flag "passes name as the zeroth argument to command."

(stopping for the day; 34402 words)

I try to run an experiment to at least see how this might work.  I write two scripts, one named `foo/baz` and one named `foo/buzz`:

```
#!/usr/bin/env bash
# foo/baz

exec -a blah ./foo/bar 1 2
```
```
#!/usr/bin/env bash
# foo/buzz

exec ./foo/bar 1 2
```

You can see that I `exec` out to a 3rd script from inside each of these scripts.  That `foo/bar` script looks like this:

```
#!/usr/bin/env bash

echo "Hello world"
echo "0: $0"
echo "1: $1"
echo "2: $2"
```

My goal is to see what effect `-a` has on the 0th and subsequent arguments. If this flag causes the 0th argument to change to the argument you pass to it, then I would expect the 0th argument when I run `foo/baz` to be `blah`, since that's what I passed. However, when I run the scripts, the output is the same in both cases:

```
~/Workspace/OpenSource (master)  $ ./foo/baz
Hello world
0: /Users/myusername/Workspace/OpenSource/foo/bar
1: 1
2: 2

~/Workspace/OpenSource (master)  $ ./foo/buzz
Hello world
0: /Users/myusername/Workspace/OpenSource/foo/bar
1: 1
2: 2
```

Why is the 0th argument different from what I expected?  And why would we want "ruby" as the 0th argument?  It seems like `exec` can handle the full `/Users/myusername/.rbenv/versions/2.7.5/bin/ruby` command just fine, right?  I post a [question on StackExchange](https://unix.stackexchange.com/questions/717671/why-isnt-exec-a-working-the-way-i-expect){:target="_blank" rel="noopener"}, and am waiting for an answer.

In the meantime, let's take a look at the spec files for `rbenv-exec`.  Maybe that'll shed some light on the confusion I've had around this file.

```
#!/usr/bin/env bats

load test_helper

@test "supports hook path with spaces" {
  hook_path="${RBENV_TEST_DIR}/custom stuff/rbenv hooks"
  mkdir -p "${hook_path}/exec"
  echo "export HELLO='from hook'" > "${hook_path}/exec/hello.bash"

  export RBENV_VERSION=system
  RBENV_HOOK_PATH="$hook_path" run rbenv-exec env
  assert_success
  assert_line "HELLO=from hook"
}
```

Hmmm, looks like the only test for this command is meant to ensure that a filepath with whitespace characters in it doesn't break the command.  It does a few extra things, such as ensure that `RBENV_VERSION` is set to `system` so that we don't update `PATH`.  But the gist of this test seems to be:

We create a new directory inside RBENV's hooks path, and inside of that we create a bash script which sets the environment variable `HELLO` equal to `'from hook`.
This hook will be run whenever we run `rbenv exec`.
We then run `rbenv exec`, passing it the `env` command (which is a bash command to print out any environment variables).
The `HELLO` env var is created when we run `rbenv exec`, provided we explicitly include its directory among the directories that RBENV checks for hooks (which we do by prepending it with `RBENV_HOOK_PATH="$hook_path"`).
Then running `env` after that should result in `HELLO=from hook` being printed to STDOUT.
We then assert that:
the exit code was 0 (i.e. the command was a success) and
the expected output (`HELLO=from hook`) was returned.

That's it for the `exec` test file!

TODO- should we add any test coverage to `exec.bat`?  If so, what can we use from `test_helper.bash`?
