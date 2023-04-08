The next line of code tells us:

```
if [ -f "$arg" ]; then
...
fi
```

## Detecting whether a string is a filepath

Running `man test` and searching for the `-f` string reveals the following:

<p style="text-align: center">
  <img src="/assets/images/man-test-f.png" width="70%" alt="What is the `-f` flag when passed inside brackets?">
</p>

> True if file exists and is a regular file.

So our case statement matches if the arg *could be* a filepath, and we further check this by using `[ -f "$arg" ]` to verify that it *actually is* a filepath.

FWIW, I'm guessing they say "regular file" here in order to distinguish from other types of files which are mentioned in other flag descriptions, such as "block special file" for the `-b` flag, and "character special file" for the `-c` flag.  I didn't spend too much time researching these special file types, because it doesn't look especially relevant to our goal here.  If you're curious about that, I found [this StackOverflow post](https://web.archive.org/web/20220712131700/http://unix.stackexchange.com/questions/60034/what-are-character-special-and-block-special-files-in-a-unix-system){:target="_blank" rel="noopener"} which appears to contain the answer.

To test whether the `-f` flag behaves the way I think it does, I update my `foo` script to look like the following:

```
#!/usr/bin/env bash

for arg; do
  case "$arg" in
    */* )
      echo "match: $arg";
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
done
```

Then I run:

```
$ echo "bar" > bar
```

I run this command so that I have a file in my directory called `./bar`.

Lastly, I run the following:

```
$ ./foo 1 2 3 a/b /b a/ / '' ./bar foo

not a match: 1
not a match: 2
not a match: 3
match: a/b
turns out, is not a filepath
match: /b
turns out, is not a filepath
match: a/
turns out, is not a filepath
match: /
turns out, is not a filepath
not a match:
match: ./bar
is definitely a filepath
not a match: foo
```

As expected, the arguments which are known to *not* match a file in my current directory (i.e. `a/b`, `/b`, `a/`, and `/`) result in the output `turns out, is not a filepath`.  My `./bar` argument, which is known to match a file, results in the output `is definitely a filepath`.

But wait, the last argument (`foo`) *also* matches a filepath, i.e. the `./foo` script we're running!  It doesn't match because it doesn't have a `/` in its argument, but it *still is* a file.  Does that mean the RBENV shim is accidentally *skipping* some filepaths which it should be capturing?

Let's try an experiment which should tell us whether this is in fact happening with the shim for the `ruby` command.

### Experiment- are we skipping potentially valid filepaths?

I update the shim for my `ruby` command to look like the following.  Newly-added lines are indicated with comments in blue at the right of the screenshot:

<p style="text-align: center">
  <img src="/assets/images/new-ruby-shim.png" width="70%" alt="shim for `ruby` command with echo statements">
</p>

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

Judging by the fact that we see `about to set RBENV_DIR...` in the 2nd test case but not the first, we can say that calling `ruby ./bar.rb` definitely causes additional code to be executed in our shim, above and beyond what gets executed when we only call `ruby bar.rb`.

Does this matter?

The answer to that is tied to what this case branch's purpose is.  We'll see what that is in the next section.

Before I move on, I make sure to delete the modifications I made to my `ruby` shim file.

Next 2 lines of code are:

```
export RBENV_DIR="${arg%/*}"
break
```

Here we see that the purpose of our case statement is to set the `RBENV_DIR` environment variable.

### What does the `RBENV_DIR` env var do?

To answer this question, I search for it in the `rbenv` codebase on my local machine (which I've downloaded from [the Github repo](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}).

Note that I search using the `ag` command, which you can learn how to install [here](https://github.com/ggreer/the_silver_searcher){:target="_blank" rel="noopener"}.  Your computer will likely ship with the `grep` command, but `ag` is *much* faster.

When I run this search, I see multiple references to it in various code files:

<p style="text-align: center">
  <img src="/assets/images/ag-rbenv-dir.png" width="70%" alt="Searching the rbenv codebase for RBENV_DIR">
</p>

The reference that catches my eye is in the README.md file.  This file will likely tell me in plain English what I want to know.

Sure enough, I find that it contains the following table:

<p style="text-align: center">
  <img src="/assets/images/rbenv-env-vars.png" width="70%" alt="Environment variables in RBENV" style="border: 1px solid black; padding: 0.5em">
</p>

So the intention is for `RBENV_DIR` to control where `rbenv` looks for your `.ruby-version` file.  I happen to know from being a long-time RBENV user that the `.ruby-version` file is one way that RBENV uses to detect which Ruby version you want to use.  It's quite common, when running a Ruby file that depends on a specific Ruby version, to include a `.ruby-version` file in the same directory as the executed file.  This file contains the hard-coded version number that you want to use when running your Ruby script, and is one method you can use to tell RBENV to pin your project to a specific Ruby version.

But what is the `export` keyword at the start of `export RBENV_DIR="${arg%/*}"`?

## `export` statements

The assignment statement `export FOO='bar'` creates a variable named `FOO` and sets its value to `bar`, **but** it does something else as well.  We've already seen variables declared earlier, i.e. `program="${0##*/}"`.  What does the use of `export` buy us?

[It turns out](https://web.archive.org/web/20220713174024/https://www.baeldung.com/linux/bash-variables-export){:target="_blank" rel="noopener"} there are two kinds of variables in a bash script: a shell variable and an environment variable.  When we created the `program` variable, that was an example of creating a **shell** variable.  Shell variables are only accessible from within the shell they're created in.  Environment variables, on the other hand, are accessible from within child shells created by the parent shell.

The blog post link above gives two examples, one demonstrating access of an environment variable from a child shell, and the other of accessing a shell variable from a child shell.  We can do an experiment in our terminal to see for ourselves.

### Experiment- environment vs shell variables

We can type the following directly in our terminal:

```
$ export MYVAR1="Here is my environment variable"

$ MYVAR2="Here is my shell variable"

$ echo $MYVAR1

Here is my environment variable

$ echo $MYVAR2

Here is my shell variable

$ bash    # Open a new child shell

bash $ echo $MYVAR1

Here is my environment variable

bash $ echo $MYVAR2

```

We can see here that `MYVAR1` is visible from within our new child shell, but `MYVAR2` is not.  That's because the declaration of `MYVAR1` was prefaced with `export`, while the declaration of `MYVAR2` was not.

So our current line of code creates an environment variable called `RBENV_DIR`, which will be available in child shells.  This implies that we'll be creating a child shell soon.  What will that child shell do?

The short answer is that the child shell is used by RBENV to detect which Ruby version is the right one, and then run the original command corresponding to the shim that's being executed (i.e. `bundle` or whatever).

A deeper answer would require an explanation of how the RBENV codebase works as a whole, which is beyond the scope of this post.  But if you want to know more, I've already written a 500-page deep-dive into the codebase, written in the same format as this guide (with experiments, beginner-friendly explanations, etc).  Sign up below to get notified when I post it.

{% include convert_kit_2.html %}

In the meantime, what do the contents of the `RBENV_DIR` variable look like?  To answer that, we have to know what the following resolves to:

```
"${arg%/*}"
```

Let's try an experiment.

### Experiment- more fun with parameter expansion

I type the following directly in my terminal:

```
$ arg="/foo/bar/baz"
$ bar="${arg%/*}"
$ echo $bar

/foo/bar
```

So `"${arg%/*}"` takes the argument, and trims off the last `/` character and everything after it.  This aligns with something I found earlier, in [the GNU docs](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/gnu-docs-param-expansion.png" width="70%" alt="GNU docs for parameter expansion" style="border: 1px solid black; padding: 0.5em">
</p>

As a reminder, the line of code that we're examining now is:

```
export RBENV_DIR="${arg%/*}"
```

With the above reminder, we now know enough to piece together what this line of code is doing:

 - It creates a new environment variable named `RBENV_DIR` which will be available in any child shells,
 - takes the directory of the file that was passed to the `ruby` command, and
 - sets the new env var equal to the *directory containing that Ruby file*.

As a reminder of the entire `if` block we just looked at:

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

Summing up what all this does:

 - If the command you're running is the `ruby` command:
 - RBENV will iterate over each of the arguments you passed to `ruby`
 - If the arg is `--` or if it starts with `-e`, it will immediately stop checking the remaining args, and proceed to running the code outside the case statement (what that code does is TBD).
 - if the argument contains a `/` character, RBENV will check to see if that argument corresponds to a valid filepath.  If it does, it will grab the file's parent directory and use that to (later on) check which Ruby version to use.

## Setting `RBENV_ROOT`

The next line of code is pretty straight-forward:

```
export RBENV_ROOT="/Users/myusername/.rbenv"
```

This line of code just sets a 2nd environment variable named `RBENV_ROOT` to (in my case) the `.rbenv` hidden directory inside my home directory.  Referring back to the `README.md` file we just read, we see that this env var "Defines the directory under which Ruby versions and shims reside."  Given this is an env var and not a shell var, we can assume that this variable will be used by a child process.

