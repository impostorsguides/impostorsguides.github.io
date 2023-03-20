Moving on to line 3 of the code.

```
[ -n "$RBENV_DEBUG" ] && set -x
```

What do those brackets mean?

## Tests and conditions

[This answer](https://stackoverflow.com/a/2188369/2143275) from StackOverflow says:

<p style="text-align: center">
  <img src="/assets/images/what-are-brackets.png" width="85%" alt="What are brackets in bash?" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so `[` and `test` are synonyms as far as `bash` is concerned.  I run `man test` and see the following:

<p style="text-align: center">
  <img src="/assets/images/man-test.png" width="75%" alt="`man` entry for the `test` command" >
</p>

Here we have a formal definition of `[` (aka `test`).  It's a "condition evaluation utility", which I interpret to mean that it's similar to an if-clause in Ruby.  Let's test whether that's true with an experiment:

### Experiment- `[` vs `test`

I create a file named `./foo`:

```
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

At least in this case, `test` and `[ ... ]` appear to produce the same results.

Now what about that -n flag?

## Passing flags to `[`

If we're looking for docs on a flag that we're supposed to pass to a certain command, we can usually find those docs inside the docs for the command itself. In this case, I search for `-n` in the `man` page for `test`:

<p style="text-align: center">
  <img src="/assets/images/man-test-n.png" width="70%" alt="Documentation for the `test` command's `-n` flag">
</p>

It looks like `[ -n "$RBENV_DEBUG" ]` returns a zero exit code (or in the parlance of a true/false check, it returns `true`) if the length of the string that it receives is greater than zero (i.e. if the string is *not* empty).  In this case, the string it receives is the value of the `RBENV_DEBUG` environment variable.

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

So using the `-n` flag to test the length of `FOO` resulted in printing `Hi` to the screen because `FOO` has a greater-than-zero string length.  But `BAR` and `""` both do not, so nothing was printed in those two cases.

This all works as expected.  Then, out of curiosity, I removed the double-quotes from `$BAR`:

```
$ [ -n $BAR ] && echo "Hi"
Hi
```

This was unexpected.  Since `$BAR` hadn't been set, I expected nothing to be printed to the screen.  I've read before that leaving the double-quotes off can cause unexpected behavior, depending on what the variable value is set to.  But if it's not set to anything, I would expect its length to be zero, and therefore the statement to return false.

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

Another question about the bracket syntax: what would happen if I used single-quotes instead of double-quotes?  Does that matter?  Time for another simple experiment.

### Experiment- single- vs. double-quotes

Since I've already defined my FOO variable in my terminal tab, I type the following in the same tab:

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

OK, so when using single-quotes instead of double-quotes, the shell doesn't expand the variable into its underlying value.  It just treats the variable name as a string literal, and in this case we echo that string to the terminal.

So if the `[ -n "$RBENV_DEBUG" ]` condition returns true, the `&&` syntax ensures that we then execute the 2nd half of this line of code: `set -x`.  If that condition returns false, we exit early and don't evaluate `set -x`.

## Verbose Mode

We know about `set` already, but what does the `-x` flag do?

To find the answer, remember that we have to use `man zshoptions` to look up `set` flags:

<p style="text-align: center">
  <img src="/assets/images/man-zshoptions.png" width="75%" alt="`man` entry for the `zshoptions` command">
</p>

Using the `/` search command from within `man zshoptions`, we type `-x` and keep hitting the `n` key until we see the following:

<p style="text-align: center">
  <img src="/assets/images/man-zshoptions-2.png" width="75%" alt="`man` entry for the `zshoptions` command">
</p>

There were a few other "hits" while searching for `-x` in `man zshoptions`, but they were either for the wrong case (i.e. the uppercase `-X` instead of the lowercase `-x`, which is a different flag), or else were in the body of the description for another command (ex.- the description for `GLOBAL_EXPORT <Z>` contains a reference to `-x`, but does not tell us what `-x` does).

The `man` entry tells us that the `-x` flag causes `bash` to "(p)rint commands and their arguments as they are executed".  That kind of sounds to me like what "debug mode" or "verbose mode" does in many command line programs.  Which would make sense, given the condition for the `test` command included a variable named `RBENV_DEBUG`.

Let's see if that's what happens.

### Experiment- the `set -x` command

I write a new script, run `chmod +x` on it, and add the following code:

<p style="text-align: center">
  <img src="/assets/images/exp-set-x.png" width="30%" alt="Experiment script- `set -x`">
</p>

Side note- I found out from [this link](https://stackoverflow.com/questions/6348902/how-can-i-add-numbers-in-a-bash-script) that you add two integers in `bash` with the `$((...))` syntax.

As you can see, this script includes `set -x` at the top.  When I run this script, I see the following:

<p style="text-align: center">
  <img src="/assets/images/set-x-results.png" width="50%" alt="Results of a script with `set -x` included">
</p>

The lines with `+` in front of them appear to be the lines which are printed out *as a result of `set -x`*, while the lines without `+` are lines that would have printed out anyway (i.e. as a result of the `echo` commands I included in the script).

Now, when I comment out `set -x` and re-run the script, I see:

<p style="text-align: center">
  <img src="/assets/images/set-x-results-2.png" width="50%" alt="Results of the same script without `set -x`">
</p>

Now we don't see the `+` lines.

From this, I think we can conclude that `set -x` prints each line of code that is run, just as our docs described.

So to summarize, `[ -n "$RBENV_DEBUG" ] && set -x` tells us that we will print each command as it is executed, but **only if** we set the `$RBENV_DEBUG` environment variable to equal  any non-empty string value.

## Is it dangerous to rely on builtin commands?

Relatedly, while researching the `set` command, it dawned on me that if `man set` pulls up the "General Commands Manual", that must mean it's a builtin command (i.e. its implemented by a specific shell).  This is confirmed by a browse of [the GNU `bash` docs on `set`](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html), titled "The Set Builtin".

But RBENV is a widely-popular Ruby version manager, meaning it must be running on machines that use `bash`, but also machines that use `zsh` and other shells too.

Our file has a `bash` shebang, meaning `set` will always be evaluated using `bash`.  But if we didn't have that shebang, would the `set` command (and therefore RBENV) behave differently in different shells?

More broadly, *is it dangerous for a script to rely on built-ins, since they could be implemented differently in different shells?*

I decide to [post my question on StackOverflow](https://stackoverflow.com/questions/73447693/rbenv-is-it-risky-to-rely-on-builtin-shell-commands-such-as-set-since-builti).  A side benefit of this is that, in the past, just the act of writing out my question on StackOverflow has helped unblock me and helped me answer my own question, even when I don't end up posting it.

The next day, I see someone commented on my question:

> As long as you stick to features from POSIX sh, you're usually pretty safe.

Googling for the phrase "POSIX docs", I find [the POSIX docs page](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_25) containing the `set` command, and verified that while it is considered a "special built-in", POSIX does have an opinion on its implementation:

> If no options or arguments are specified, `set` shall write the names and values of all shell variables in the collation sequence of the current locale.

The use of the word "shall" seems to indicate that a shell is required to implement its version of `set` in the manner prescribed by POSIX if it wants to be considered POSIX-compliant.  This, I think, is enough to satisfy my question.

Note that I subsequently found [this blog article](https://archive.ph/JGREI), which seems to confirm my assumption that POSIX is the standard by which we can feel safe in using `set` in the rbenv shim.
