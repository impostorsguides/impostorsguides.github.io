
## Code

The first line in [this file](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv){:target="_blank" rel="noopener"} is:

```
#!/usr/bin/env bash
```

This is the shebang, which we're already familiar with from Part 1.  This tells us that UNIX will use Bash to process the script.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next line of code is:

```
set -e
```

We've seen this line as well- it means we immediately exit with a non-zero status code as soon as an error is raised.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
if [ "$1" = "--debug" ]; then
...
fi
```

We recognize the `if` statement and the `[` syntax from earlier.  Here, we're testing whether `"$1"` evaluates to the string `--debug`.  I suspect that `$1` represents the first argument that gets passed to the command, but I'm not sure if the indexing is 0-based or 1-based.  A quick Google search leads me [here](https://web.archive.org/web/20211006091051/https://stackoverflow.com/questions/29258603/what-do-0-1-2-mean-in-shell-script){:target="_blank" rel="noopener"}:


<center>
  <a target="_blank" href="/assets/images/stackoverflow-answer-positional-arguments.png">
    <img src="/assets/images/stackoverflow-answer-positional-arguments.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

My guess was correct.  Based on this, we can conclude that if the first argument is equal to "--debug", then... what?

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
  export RBENV_DEBUG=1
```

We recognize the `export` statement from Part 1.  We set `RBENV_DEBUG` equal to 1, and then export it.

We know from [here](https://unix.stackexchange.com/a/28349/142469){:target="_blank" rel="noopener"} that an `export`ed variable is available in the same script, in a child script, and in a function which is called inside that same script, but not in the parent process or other sibling scripts called by that parent process.  So we can assume that `RBENV_DEBUG` will be used in one of those places in the near future.

## The `shift` keyword

Next line of code.

```
shift
```

What does `shift` do?  According to [the docs](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_09_07.html){:target="_blank" rel="noopener"}:

> This command takes one argument, a number. The positional parameters are shifted to the left by this number, N. The positional parameters from `N+1` to `$#` are renamed to variable names from `$1` to `$#` - `N+1`.
>
> Say you have a command that takes 10 arguments, and N is 4, then `$4` becomes `$1`, `$5` becomes `$2` and so on.  `$10` becomes `$7` and the original `$1`, `$2` and `$3` are thrown away.
>
> ...
>
> If N is not present, it is assumed to be 1.

Am I the only one who thinks there's an off-by-one error in this explanation?  If `N` is 4, then shouldn't `$5` become `$1`, not `$2`?

Let's see for ourselves how `shift` works.

### Experiment- the `shift` command

I write a script containing the following code:

```
#!/usr/bin/env bash

echo "old arg length: $#"
echo "old args: $@"
echo "old fifth arg: $5"

echo
echo "Calling 'shift 4'..."
echo
shift 4

echo "new arg length: $#"
echo "new args: $@"
echo "new first arg: $1"
```

`$#` evaluates to the number of positional arguments, and `$@` evaluates to the list of args.

I run it, passing it the args `foo`, `bar`, and `baz`, and I get:

```
$ ./foo bar baz buzz quox bing

old arg length: 5
old args: bar baz buzz quox bing
old fifth arg: bing

Calling 'shift 4'...

new arg length: 1
new args: bing
new first arg: bing
```

Great, it does what we thought it would- decreases the argument count by 4, and lops the first 4 arguments off the front of the list.

We also proved that the Linux Documentation Project's example **does** contain an off-by-one error.

So to summarize the entire `if` block: if the user passes `--debug` as their first arg to `rbenv`, we set RBENV_DEBUG and trim the `--debug` flag off the list of args.

## The `xtrace` feature

Next block of code:

```
if [ -n "$RBENV_DEBUG" ]; then
  # https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi
```

Since the `-n` flag is passed to the `[` command, I run `man test` and search for `-n`.  I see:

```
-n string     True if the length of string is nonzero.
```

So if the length of `$RBENV_DEBUG` is non-zero (i.e. if we just set it), then execute the code inside this `if`-block.  Which is:

```
# https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
```

The first line of code is just a comment, containing [a link to an article](https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful){:target="_blank" rel="noopener"} about a program named `xtrace`.  Inside the article, we see the following:

> #### Making xtrace more useful
> (by AnMaster)
>
> xtrace output would be more useful if it contained source file and line number. Add this assignment PS4 at the beginning of your script to enable the inclusion of that information:
>
> `export PS4='+(${BASH_SOURCE:-}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'`
>
> Be sure to use single quotes here!
>
> The output would look like this when you trace code outside a function:
>
> `+(somefile.bash:412): echo 'Hello world'`
>
> ...and like this when you trace code inside a function:
>
> `+(somefile.bash:412): myfunc(): echo 'Hello world'`
>
> That helps a lot when the script is long, or when the main script sources many other files.
```

The article mentions that, by setting an environment variable called `PS4` equal to some complicated string, the output of our command line will look different.

So what is PS4, and what does it do?

I try `man PS4` but get no answer.  I Google "PS4 bash", and I open up [the first result I see](https://web.archive.org/web/20230304080135/https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/){:target="_blank" rel="noopener"}.  It mentions not only PS4, but also PS1, PS2, and PS3.  I scroll down to the section on PS4 and I see:

> PS4 – Used by "set -x" to prefix tracing output
>
> The PS4 shell variable defines the prompt that gets displayed, when you execute a shell script in debug mode as shown below.

OK, so we're updating the prompt which is displayed when `set -x` is executed.  That makes sense, because right after we set `PS4` inside our file, the next line is `set -x`.

But what are we updating `PS4` to?

Judging by the dollar-sign-plus-curly-brace syntax, there appears to be some parameter expansion happening here.  On a hunch, I try an experiment.

### Experiment- `BASH_SOURCE` and `LINENO`

I make a script named `foo` with the first half of our `PS4` value, i.e. everything before the space in the middle:

```
#!/usr/bin/env bash

echo "+(${BASH_SOURCE}:${LINENO}):"
```

When I `chmod` and run it, I get:

```
$ chmod +x foo

$ ./foo

+(./foo:3):
```

So the `+(`, `:`, and `):` don't do anything special- they're literal characters which get printed directly to the screen.  That leaves `${BASH_SOURCE}`, which looks like it gets evaluated to `./foo` (the name of my script file), and `${LINENO}`, which looks like it resolves to `3` (the line number that the `echo` command appears on, in my script).

What about the 2nd half of `PS4`?

```
${FUNCNAME[0]:+${FUNCNAME[0]}(): }
```

After Googling `FUNCNAME`, I find the online version of [its `man` page entry](https://web.archive.org/web/20230322221925/https://www.man7.org/linux/man-pages/man1/bash.1.html){:target="_blank" rel="noopener"}:

```
FUNCNAME
              An array variable containing the names of all shell
              functions currently in the execution call stack.  The
              element with index 0 is the name of any currently-
              executing shell function.  The bottom-most element (the
              one with the highest index) is "main".  This variable
              exists only when a shell function is executing.
              Assignments to FUNCNAME have no effect.  If FUNCNAME is
              unset, it loses its special properties, even if it is
              subsequently reset.
```

So `FUNCNAME` is an array variable.  That explains why we're invoking `FUNCNAME[0]` inside the parameter expansion syntax.  And it "contain(s) the names of all shell functions currently in the execution call stack."  Lastly, it "...exists only when a shell function is executing."

Can we reproduce this behavior?  Let's try another experiment.

### Experiment- attempting to print `FUNCNAME`

I make a script named `foo`, which looks like this:

```
#!/usr/bin/env bash

bar() {
  for method in "${FUNCNAME[@]}"; do
    echo "$method"
  done
  echo "-------"
}

foo() {
  for method in "${FUNCNAME[@]}"; do
    echo "$method"
  done
  echo "-------"
  bar
}

foo
```

It implements two functions, one named `foo` and one named `bar`.  Each function iterates over `FUNCNAME` call stack and prints each item in the call stack.  In addition, `foo` calls `bar`, so `bar` should have one more item in its callstack than `foo` does.

When I run `foo`, I get:

```
$ ./foo
foo
main
-------
bar
foo
main
-------
```

Success- `bar` had one more item printed than `foo` did, just like we hoped.

Getting back to the 2nd half of the `PS4` value:

```
${FUNCNAME[0]:+${FUNCNAME[0]}(): }
```

We see `${ ... }`, so we know we're dealing with parameter expansion again.  And if we take out the two references to `FUNCNAME[0]` (which we know will equal the current function **if we're currently inside a function**), then we're left with `${__:+__():}`.

I'm curious what `:+` means, so I look for these two characters in [the parameter expansion docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}.  I see:

> ${parameter:+word}
>
> If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
>
> ```
> $ var=123
> $ echo ${var:+var is set and not null}
> var is set and not null
> ```

So you can pass in a variable, and if that variable is set, Bash will print whatever string you give it.  That seems to be what's happening here, except instead of checking for `var`, we're checking for `FUNCNAME[0]`.  If it's set, we print its value, followed by `():`.

And that actually fits with what we were told by the article that was linked in the code comment.  It said the terminal would appear...

> ...like this when you trace code inside a function:
>
> `+(somefile.bash:412): myfunc(): echo 'Hello world'`

So the following...

```
${FUNCNAME[0]:+${FUNCNAME[0]}(): }
```

...means that if `FUNCNAME[0]` has a non-null value (i.e. if we're currently inside a function call), then we print the value of `FUNCNAME[0]` (i.e. the name of the current function) plus `():` appended to the end.

The `myfunc():` before `echo 'Hello world'` is our value of `FUNCNAME[0]` in the example, plus `():` at the end.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Does all that pan out when we actually run `rbenv` with the `--debug` flag?  Let's try with `rbenv --debug version`:

```
$ rbenv --debug version
```

There's a ton of output.  Below is one line from that output [which comes from *outside* of a function](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L73){:target="_blank" rel="noopener"}...

```
+(/Users/myusername/.rbenv/bin/rbenv:73): shopt -s nullglob
```

...and another [which comes from *inside* a function](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L41){:target="_blank" rel="noopener"}:

```
++(/Users/myusername/.rbenv/bin/rbenv:41): abs_dirname(): local path=/Users/myusername/.rbenv/bin/rbenv
```

Although we haven't yet reached these lines of code and don't yet know what they do, the format of the output does line up with what we've learned about our new `PS4` value.

### Aside- what is `xtrace`?

I kept noticing the phrase `xtrace` being thrown around on some of the links I encountered while trying to solve the above.  I Googled "what is xtrace bash", and found [this link](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_02_03.html){:target="_blank" rel="noopener"}, which says:

<center>
  <a target="_blank" href="/assets/images/stackoverflow-answer-12mar2023-138pm.png">
    <img src="/assets/images/stackoverflow-answer-12mar2023-138pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer about `xtrace`">
  </a>
</center>

That's a lot, but the bottom table shows the short notation of `set -x` corresponds to the long notation of `set -o xtrace`, or "set the xtrace option".  So `xtrace` is the name of a mode in bash.

RBENV calls `set -x` at the beginning of the file, because we want to enable debugging over the entire file.  But the cool thing about `set -x` is, you don't have to call it only at the beginning of a script.

According to the above link from TLDP, you can enable it only for a certain section of code that you suspect is buggy, and disable it as soon as the section of buggy code is complete.  This reduces the amount of noise you have to wade through before getting to the helpful lines of the `xtrace` output.

Even further, **you can do this anywhere you want in your code, as many times as you want.**

I think that's pretty cool.

So summarizing the first 2 blocks of code: we first check if the user passed `--debug` as the first argument.  If they do:

 - we `export` the `RBENV_DEBUG` env var.
 - Then in the 2nd block, if the `RBENV_DEBUG` env var has been set:
    - we change the terminal prompt to output more useful version of `PS4`, and
    - we call `set -x` to put bash into debug mode.

If we look for `RBENV_DEBUG` throughout the codebase, we can see it used in multiple locations:


<center>
  <a target="_blank" href="/assets/images/screenshot-24mar2023-623pm.png">
    <img src="/assets/images/screenshot-24mar2023-623pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

All of the line numbers are pretty low: I see lines 4, 5, 6, 11, 10, 4, etc.  So it looks like at the start of all these files, we check if `RBENV_DEBUG` has been set, and if it has, we invoke `xtrace` via the `set -x` command.  This is why we had to `export` this env var.

Since the `rbenv` file sets `RBENV_DEBUG` and the files listed above consume `RBENV_DEBUG`, this also implies that these files will be run as child processes of the `rbenv` command.  But we'll get to that later.

Lastly, this implies that you can't just turn on `xtrace` in a parent script and expect it to remain on in the parent's child scripts.  Instead, you need to turn it on for each file that you expect to run.

We can prove this with an experiment:

### Experiment- does "xtrace" trickle down to child scripts?

I make a script named `foo` which looks like so:

```
#!/usr/bin/env bash

set -x

echo "Inside foo"

./bar
```

A simple bash script which turns on xtrace, prints a string, then calls a 2nd script, named `bar`.

I create that 2nd script, which looks like this:

```
#!/usr/bin/env bash

set -x

echo "Inside bar"
```

The `bar` script calls `set -x` and `echo` the same way `foo` does, but `bar` doesn't call a child script the way `foo` does.

When I run `foo`, I see the following:

```
$ ./foo

+ echo 'Inside foo'
Inside foo
+ ./bar
+ echo 'Inside bar'
Inside bar
```

We see `xtrace` statements print out for the `echo` statements inside **both** `foo` and `bar`.

Then, I remove the call to `set -x` in `bar`:

```
#!/usr/bin/env bash

echo "Inside bar"
```

When I re-run `foo`, I now see the following:

```
$ ./foo

+ echo 'Inside foo'
Inside foo
+ ./bar
Inside bar
```

I no longer see the `xtrace` statement inside `bar` (`+ echo 'Inside bar'`).  I only see the *result* of the echo statement, which I would have seen either way.

So the effects of `xtrace` do **not** automatically trickle down from parent to child scripts.  We have to manually call `set -x` for each new script we run.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on to the next block of code.

