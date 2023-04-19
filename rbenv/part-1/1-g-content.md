The next line of code tells us:

```
if [ -f "$arg" ]; then
...
fi
```

## Detecting whether a string is a filepath

Running `man test` and searching for the `-f` string reveals the following:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/man-test-f.png">
    <img src="/assets/images/man-test-f.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

> True if file exists and is a regular file.

So our case statement matches if the arg *could be* a filepath, and we further check this by using `[ -f "$arg" ]` to verify that it *actually is* a filepath.

FWIW, I'm guessing the man page says "regular file" here in order to distinguish from other types of files which are mentioned in other flag descriptions, such as:

 - "block special file" for the `-b` flag, and
 - "character special file" for the `-c` flag.

 I didn't research these other file types because it didn't look relevant to our goal here.  If you're curious about them, I found [this StackOverflow post](https://web.archive.org/web/20220712131700/http://unix.stackexchange.com/questions/60034/what-are-character-special-and-block-special-files-in-a-unix-system){:target="_blank" rel="noopener"} which appears to contain the answer.  If I'm wrong, and they are relevant to this code, [let me know](https://twitter.com/impostorsguides){:target="_blank" rel="noopener"}!

To test whether the `-f` flag behaves the way I think it does, I update my `foo` script from earlier to look like the following:

```
#!/usr/bin/env bash

for arg; do
  case "$arg" in
    */* )
      echo "could be a filepath: $arg";
      if [ -f "$arg" ]; then
        echo "is definitely a filepath";
      else
        echo "turns out, is not a filepath";
      fi
    ;;
    * )
      echo "not a match: $arg";
    ;;
  esac
  echo "------"
done
```

Then I create an empty file named `bar` in my current directory:

```
$ touch bar
```

I do this so that I have a file in my directory that will return true for the test `[ -f "./bar" ]`.

Lastly, I run the following:

```
$ ./foo 1 2 3 a/b /b a/ / '' ./bar foo

not a match: 1
------
not a match: 2
------
not a match: 3
------
could be a filepath: a/b
turns out, is not a filepath
------
could be a filepath: /b
turns out, is not a filepath
------
could be a filepath: a/
turns out, is not a filepath
------
could be a filepath: /
turns out, is not a filepath
------
not a match:
------
could be a filepath: ./bar
is definitely a filepath
------
not a match: foo
------
```

As expected, the arguments which are known to *not* match a file in my current directory (i.e. `a/b`, `/b`, `a/`, and `/`) result in the output `turns out, is not a filepath`.  My `./bar` argument, which is known to match a file, results in the output `is definitely a filepath`.

But wait, the last argument (`foo`) *also* matches a filepath, i.e. the `./foo` script we're running that's generating this very output!

It doesn't match because it doesn't have a `/` in its argument, but it *still is* a file.  Does that mean the RBENV shim is accidentally *skipping* some filepaths which it should be capturing?

This is an important but subtle question, and relates to the overall purpose of why over 2/3 of this shim is dedicated to this `if` block.

Let's try an experiment which should tell us whether this is in fact happening with the shim for the `ruby` command.

### Experiment- are we skipping potentially valid filepaths?

I find the filepath for the `ruby` shim, using the `which` command, and open it using my `vim` editor:

```
$ which ruby

/Users/myusername/.rbenv/shims/ruby

$ vim /Users/myusername/.rbenv/shims/ruby
```

Then I update the shim to look like the following:

```
#!/usr/bin/env bash
set -e
[ -n "$RBENV_DEBUG" ] && set -x

program="${0##*/}"
if [ "$program" = "ruby" ]; then
  for arg; do
    echo "arg: $arg"                                  # new code
    case "$arg" in
    -e* | -- ) break ;;
    */* )
      echo "arg matches */*: $arg"                    # new code
      if [ -f "$arg" ]; then
        echo "about to set RBENV_DIR for arg $arg"    # new code
        export RBENV_DIR="${arg%/*}"
        break
      fi
      ;;
    esac
    echo "-----"                                      # new code
  done
fi

export RBENV_ROOT="/Users/richiethomas/.rbenv"
exec "/usr/local/bin/rbenv" exec "$program" "$@"
```

I then make a new file called `bar.rb`, which just contains the following:

```
puts 5+5
```

When I run `ruby bar.rb`, I see the following:

```
$ ruby bar.rb

arg: bar.rb
-----
10
```

However, when I run `ruby ./bar.rb`, I see the following:

```
$ ruby ./bar.rb

arg: ./bar.rb
arg matches */*: ./bar.rb
about to set RBENV_DIR for arg ./bar.rb
10
```

We see `about to set RBENV_DIR...` in the 2nd test case, but not the first.

Based on this, we can say that calling `ruby ./bar.rb` definitely causes additional code to be executed in our shim, above and beyond what gets executed when we only call `ruby bar.rb`.

Does this matter?

The answer to that is tied to the reason why this clause of the case statement is here.  Later on, we'll see what that is.

Before I move on, I make sure to delete the modifications I made to my `ruby` shim file.

## The `RBENV_DIR` environment variable

Next 2 lines of code are:

```
export RBENV_DIR="${arg%/*}"
break
```

Here we see that the purpose of our case statement is to set the `RBENV_DIR` environment variable.  But what does this env var do?

To answer this question, I search for it in the `rbenv` codebase on my local machine (which I've downloaded from [the Github repo](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}).

Note that I search using the `ag` command, which you can learn how to install [here](https://github.com/ggreer/the_silver_searcher){:target="_blank" rel="noopener"}.  Your computer will likely ship with the `grep` command, but `ag` is *much* faster.

When I run this search, I see multiple references to it in various code files:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/ag-rbenv-dir.png">
    <img src="/assets/images/ag-rbenv-dir.png" width="90%" alt="Searching the rbenv codebase for RBENV_DIR">
  </a>
</center>

The reference that catches my eye is in the README.md file.  This file will likely tell me in plain English what I want to know.

Sure enough, I find that it contains the following table:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/rbenv-env-vars.png">
    <img src="/assets/images/rbenv-env-vars.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

So `RBENV_DIR` controls where RBENV looks for your `.ruby-version` file.

Again from reading [the README file](https://web.archive.org/web/20230413141208/https://github.com/rbenv/rbenv){:target="_blank" rel="noopener"}, we see that the `.ruby-version` file is one way that RBENV uses to detect which Ruby version you want to use:

> ...rbenv scans the current project directory for a file named .ruby-version. If found, that file determines the version of Ruby that should be used within that directory.

So here we're setting the `RBENV_DIR` variable, in order to tell RBENV where it can find the `.ruby-version` file.

But what is the `export` keyword at the start of `export RBENV_DIR="${arg%/*}"`?

## `export` statements

We've already seen an example of how variables are assigned in `bash`, i.e. `program="${0##*/}"`.  An assignment statement like `export FOO='bar'` is similar, in that creates a variable named `FOO` and sets its value to `bar`, **but** the use of `export` means it's doing something else as well.

What does `export FOO='bar'` do that `FOO='bar'` doesn't do?

It turns out there are two kinds of variables in a bash script: shell variables, and environment variables.  Adding `export` in front of an assignment statement is what transforms a **shell** variable assignment into an **environment** variable assignment.

When we created the `program` variable, that was an example of creating a shell variable.  With this assignment operation `export RBENV_DIR=...`, we're creating an environment variable.

The difference between the two is that shell variables are only accessible from within the shell they're created in.  Environment variables, on the other hand, are also accessible from within child shells created by the parent shell.

[This blog post](https://web.archive.org/web/20220713174024/https://www.baeldung.com/linux/bash-variables-export){:target="_blank" rel="noopener"} gives two examples, one demonstrating access of an environment variable from a child shell, and the other of (attempting to) access a shell variable from a child shell.  To see this for ourselves, we can do an experiment mimicking these examples in our terminal.

### Experiment- environment vs shell variables

We can type the following directly in our terminal:

```
$ export MYVAR1="Here is my environment variable"

$ MYVAR2="Here is my shell variable"

$ echo $MYVAR1

Here is my environment variable

$ echo $MYVAR2

Here is my shell variable
```

So far, so good.  Both the shell variable and the environment variable printed successfully.

Now we open up a new shell **from within our existing shell**, and try again:

```
$ bash    # Open a new child shell

bash $ echo $MYVAR1

Here is my environment variable

bash $ echo $MYVAR2

```

We can see here that `MYVAR1` is visible from within our new child shell, but `MYVAR2` is not.  That's because the declaration of `MYVAR1` was prefaced with `export`, while the declaration of `MYVAR2` was not.

So our current line of code creates an environment variable called `RBENV_DIR`, which will be available in child shells.  This implies that we'll be creating a child shell soon.  What will that child shell do?

The short answer is that the child shell is used by RBENV to detect which Ruby version is the right one, and then run the original command corresponding to the shim that's being executed (i.e. `bundle` or whatever).

A deeper answer would require an explanation of how the RBENV codebase works as a whole, which is beyond the scope of this post.  However, I've already written a deeper dive into the codebase, with experiments, beginner-friendly explanations, etc. similar to this series.  Let me know [via Twitter](https://twitter.com/impostorsguides){:target="_blank" rel="noopener"} or via email (`impostorsguides at gmail dot com`) if you would find that valuable.  If enough people are interested, I'll post it.

In the meantime, what do the contents of the `RBENV_DIR` variable look like?  To answer that, we have to know what the following resolves to:

```
"${arg%/*}"
```

It looks like more parameter expansion, but the `%/*` syntax looks new.  Let's try an experiment.

### Experiment- diving deeper into parameter expansion {#diving-deeper-into-parameter-expansion}

I replace my `foo` script with the following:

```
#!/usr/bin/env bash

myArg="/foo/bar/baz"
bar="${myArg%/*}"
echo $bar
```

When I run the script, I get:

```
$ ./foo

/foo/bar
```

So `"${arg%/*}"` takes the argument, and trims off the last `/` character and everything after it.  This aligns with what we see if we look up [the GNU docs](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/gnu-docs-param-expansion.png">
    <img src="/assets/images/gnu-docs-param-expansion.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

As a reminder, the line of code that we're examining now is:

```
export RBENV_DIR="${arg%/*}"
```

With the above reminder, we now know enough to piece together what this line of code is doing:

 - It creates a new environment variable named `RBENV_DIR` which will be available in any child shells,
 - takes the directory of the file that was passed to the `ruby` command, and
 - sets the new env var equal to the *directory containing that Ruby file*.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

While we're at it, let's summarize what the entire `if` block does:

```
if [ "$program" = "ruby" ]; then
  for arg; do
    case "$arg" in
    -e* | -- ) break ;;
    */* )
      if [ -f "$arg" ]; then
        export RBENV_DIR="${arg%/*}"
        break
      fi
      ;;
    esac
  done
fi
```

Putting together everything we've learned:

 - If the command you're running is the `ruby` command:
 - RBENV will iterate over each of the arguments you passed to `ruby`
    - If the arg is `--` or if it starts with `-e`, it will immediately stop checking the remaining args, and proceed to running the code outside the case statement (what that code does is TBD).
    - If the argument contains a `/` character, RBENV will check to see if that argument corresponds to a valid filepath.
      - If it does correspond to a valid filepath, the shim will store the file's parent directory in an environment variable.
      - At some future place in the code, RBENV will use this environment variable to decide which Ruby version to use.
    - If the argument matches neither of these cases, it's ignored for the purposes of the `for` loop.

## Setting `RBENV_ROOT`

The next line of code is pretty straight-forward, so we'll quickly knock it out before moving to the next line:

```
export RBENV_ROOT="/Users/myusername/.rbenv"
```

This line of code just sets a 2nd environment variable named `RBENV_ROOT`.

Referring back to the `README.md` file we just read, we see that this env var "Defines the directory under which Ruby versions and shims reside."  Given this is an env var and not a shell var, we can assume that this variable will be used by a child process.

In my case, the value to which this env var gets set is the `.rbenv` hidden directory inside my home directory, aka `/Users/myusername/.rbenv`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

You could be forgiven for having some unanswered questions in your head right now.  But we only have one more line of code to go before we're done with our line-by-line examination of the shim, so let's try to power through to the end of the file.  Once we're done, we can start putting together what the shim as a whole does.
