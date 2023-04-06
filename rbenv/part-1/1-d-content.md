Moving on to line 3 of the code.

```
[ -n "$RBENV_DEBUG" ] && set -x
```

What do those brackets mean?

## Tests and conditions

I run `man [` in the terminal and I see the following:

```
TEST(1)                                                              General Commands Manual                                                             TEST(1)

NAME
     test, [ – condition evaluation utility

SYNOPSIS
     test expression
     [ expression ]

DESCRIPTION
     The test utility evaluates the expression and, if it evaluates to true, returns a zero (true) exit status; otherwise it returns 1 (false).  If there is no
     expression, test also returns 1 (false).
```

OK, so `[ ... ]` is how `bash` does conditional logic.  Also, it looks like `test` are synonyms as far as `bash` is concerned.

Let's run an experiment to see how that works.

### Experiment- `[` and `test`

I create a file named `./foo` containing the following:

```
#!/usr/bin/env bash

 if [ 5 == 5 ]; then
   echo "True"
 else
   echo "False"
 fi
```

I run `chmod +x foo` so I can execute the script, then `./foo`:
```
$ ./foo

True
```

I then change the condition to `5 == 6` to make sure the `else` clause also works:

```
#!/usr/bin/env bash

 if [ 5 == 6 ]; then
   echo "True"
 else
   echo "False"
 fi
```

When I run it, I see:

```
$ ./foo

False
```

I then update the script to use the `test` command instead of the square brackets, and repeat the experiment:

```
 if test 5 == 5; then
   echo "True"
 else
   echo "False"
 fi
```

Same results:

```
$ ./foo

True
```

Lastly, testing the `else` clause...

```
#!/usr/bin/env bash

 if test 5 == 6; then
   echo "True"
 else
   echo "False"
 fi
```

...results in:

```
$ ./foo

False
```

So as expected, we were successfully able to get `test` and `[ ... ]` to produce the same results.

Now what about that -n flag?

## Passing flags to `[`

If we're looking for docs on a flag that we're supposed to pass to a certain command, we can usually find those docs inside the docs for the command itself. In this case, I search for `-n` in the `man` page for `test`:

<p style="text-align: center">
  <img src="/assets/images/man-test-n.png" width="70%" alt="Documentation for the `test` command's `-n` flag">
</p>

It looks like `[ -n "$RBENV_DEBUG" ]` is `true` if the length of `"$RBENV_DEBUG"` is greater than zero (i.e. if the string is *not* empty).

Let's see if `-n` behaves the way we expect.

### Experiment- the `-n` flag

First I run the following directly in my terminal tab:

```
$ export FOO='foo'

$ [ -n "$FOO" ] && echo "Hi"

"Hi"

$ [ -n "$BAR" ] && echo "Hi"

$ [ -n "" ] && echo "Hi"

```

So using the `-n` flag to test the length of `"$FOO"` resulted in printing `Hi` to the screen because `"$FOO"` has a greater-than-zero string length.  But `"$BAR"` and `""` both do not, so nothing was printed in those two cases.

This all works as expected.  Then, out of curiosity, I removed the double-quotes from `"$BAR"`:

```
$ [ -n $BAR ] && echo "Hi"
Hi
```

Removing the quotes caused `Hi` to be printed.  This was unexpected.  Since `$BAR` hadn't been set, I expected nothing to be printed to the screen.

Lastly, I removed `$BAR` entirely:

```
$ [ -n ] && echo "Hi"
Hi
```

Since I don't pass any value at all to the flag, I would expect the length of the non-existent "string" to be zero.

Why are the last two cases not returning the results I expect?

In this case, [this StackOverflow post](https://archive.ph/x5AYq) comes through with an answer:

> `[ -n ]` does not use the `-n` test.
>
> The `-n` in `[ -n ]` is not a test at all. When there is only one argument between `[` and `]`, that argument is a string that is tested to see if it is empty. Even when that string has a leading `-`, it is still interpreted as an operand, not a test. Since the string `-n` is not empty (it contains two characters, `-` and `n`, not zero characters) `[ -n ]` evaluates to true.

...and [here](https://unix.stackexchange.com/a/141025/142469):

> You need to quote your variables. Without quotes you are writing `test -n` instead of `test -n <expression>`. The `test` command has no idea that you provided a variable that expanded to nothing.

OK great.  So when I don't use double-quotes, the script thinks I'm just running `[ -n ]`, which the interpreter interprets as an operand of length 2, which is why it returns true.  This is true whether I'm running `[ -n ]` or `[ -n $BAR ]`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Another question about the bracket syntax: what would happen if I used single-quotes instead of double-quotes?  Does that matter?  Time for another experiment.

#### Experiment- single- vs. double-quotes

Since I've already defined my `FOO` variable in my terminal tab, I type the following in the same tab:

```
$ echo "$FOO"
```

Which results in:

```
foo
```

Next I use single-quotes:

```
$ echo '$FOO'
```

When I run it, I get the following:

```
$FOO
```

So when using single-quotes instead of double-quotes, the shell doesn't expand the variable into its underlying value.  It just treats the variable name as a string literal, and in this case we echo that string to the terminal.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Returning back to the line of code:

```
[ -n "$RBENV_DEBUG" ] && set -x
```

If the `[ -n "$RBENV_DEBUG" ]` condition returns true, the `&&` syntax ensures that we then execute the 2nd half of this line of code: `set -x`.  If that condition returns false, we exit early and don't evaluate `set -x`.

We know about `set` already, but what does the `-x` flag do?

## Verbose Mode

I Google "set -x bash" and find [this StackOverflow post](https://stackoverflow.com/questions/36273665/what-does-set-x-do){:target="_blank" rel="noopener"}, with an answer that says:

> `set -x`
>
> Prints a trace of simple commands, `for` commands, `case` commands, ... and arithmetic for commands and their arguments or associated word lists after they are expanded and before they are executed.

That kind of sounds to me like what "debug mode" or "verbose mode" does in many command line programs.  Which would make sense, given the condition for the `test` command included a variable named `RBENV_DEBUG`.

Let's see if that's what happens.

### Experiment- the `set -x` command

I write a new script, run `chmod +x` on it, and add the following code:

```
#!/usr/bin/env bash

set -x

echo "foo"

bar="$(( 5+5 ))"

echo "$bar"
```

Side note- I found out from [this link](https://stackoverflow.com/questions/6348902/how-can-i-add-numbers-in-a-bash-script) that, if you want to add two integers in `bash`, you use the `$((...))` syntax.

As you can see, this script includes `set -x` at the top.  When I run this script, I see the following:

```
$ ./foo

+ echo foo
foo
+ bar=10
+ echo 10
10
```

The lines with `+` in front of them appear to be the lines which are printed out as a result of `set -x`.  The lines without `+` are lines that would have printed out anyway (i.e. as a result of the `echo` commands I included in the script).

Now, when I comment out `set -x` and re-run the script, I see:

```
$ ./foo

foo
10
```

Now we don't see the `+` lines anymore.

From this, I think we can conclude that `set -x` prints each line of code that is run, just as our docs described.

So to summarize, `[ -n "$RBENV_DEBUG" ] && set -x` tells us that we will print each command as it is executed, but **only if** we set the `$RBENV_DEBUG` environment variable to equal  any non-empty string value.

Let's move on to the next line of code.
