### for-loops in bash

Moving onto the next line of code.

```
  for arg; do

  ...

  done
```
We saw a regular `bash` for-loop earlier, in our experiment with delimiters.  This loop is a bit weird, though, because we haven't yet seen an `arg` variable explicitly defined by the code.  Yet here it is, being referenced in our loop.

If we haven't seen this variable defined yet, does that mean it’s defined or built-in by the language?  As usual, Googling turns up [a StackOverflow post](https://archive.ph/p4Cjp):

<p style="text-align: center">
  <img src="/assets/images/arg-for-loop.png" width="70%" alt="What is `arg` in a bash `for` loop?" style="border: 1px solid black; padding: 0.5em">
</p>

Scrolling down in the answer a bit, we see:

<p style="text-align: center">
  <img src="/assets/images/arg-for-loop-2.png" width="70%" alt="Omitting `in` in a bash `for` loop?" style="border: 1px solid black; padding: 0.5em">
</p>

The above statement implies that `$@` expands to the list of arguments provided to the script.  Let’s see if that’s true with another experiment.

#### Experiment- what does `$@` evaluate to?

I write a new script (again named simply "foo"):

```
#!/usr/bin/env bash

echo "$@"
```

Running the script with some random arguments, we get:

```
$ ./foo bar baz buzz

bar baz buzz
```

Changing the script a bit:

```
#!/usr/bin/env bash

for arg in "$@";
do
  echo "$arg"
done
```

Running this, we get:

```
$ ./foo bar baz buzz
bar
baz
buzz
```
And finally, testing whether we can eliminate `in "$@"`:

```
#!/usr/bin/env bash

for arg;
do
  echo "$arg"
done
```
Running this results in:

```
$ ./foo bar baz buzz
bar
baz
buzz
```

Awesome!  So we learned:

 - `$@` stands for the arguments that you pass to the script
 - If you write a `for` loop but leave off the `in ___` part, bash defaults to using `$@`

### Case statements

Moving on to the next line:

```
case "$arg" in
...
esac
```

I've seen case statements before (Ruby has them, as well), but I still feel like familiarizing myself with any bash-specific idiosyncracies.

I find [this link](https://web.archive.org/web/20220820011836/https://linuxize.com/post/bash-case-statement/), which explains bash’s case statement syntax.  I would have preferred a more official form of documentation, but:

 - [the link from The Linux Documentation Project](https://archive.ph/WCqYM) struck me as much-less beginner-friendly, and
 - neither `man case` nor `help case` turned up anything useful.

 At any rate, here are the highlights from the link I found:


1. Each `case` statement starts with the `case` keyword, followed by the case expression and the `in` keyword. The statement ends with the `esac` keyword.

1. You can use multiple patterns separated by the `|` operator. The `)` operator terminates a pattern list.

1. A pattern can have [special characters](https://web.archive.org/web/20220820011901/https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html).

1. A pattern and its associated commands are known as a clause.

1. Each clause must be terminated with `;;`.

1. The commands corresponding to the first pattern that matches the expression are executed.

1. It is a common practice to use the wildcard asterisk symbol (`*`) as a final pattern to define the default case. This pattern will always match.

1. If no pattern is matched, the return status is zero. Otherwise, the return status is the [exit status](https://web.archive.org/web/20220806222213/https://linuxize.com/post/bash-exit/) of the executed commands.

None of this is terribly surprising, since these rules all appear to match how case statements work in Ruby and other languages I've worked with.

#### Experiment- building a simple `case` statement

In case this is your first time encountering case statements, let's build a simple one here.  I start by updating my `foo` script to look like the following:

```
#!/usr/bin/env bash

echo "$@"
```

I then run it as follows:

```
$ ./foo 1

1
```

Next, I wrap the existing code inside a `case` statement with only the default case implemented:

```
#!/usr/bin/env bash

case "$@" in
  *)
    echo "$@"
    ;;
esac
```

I still see the same output when I run it:

```
$ ./foo 1

1
```

Lastly, I add a few non-default conditions:

```
#!/usr/bin/env bash

case "$@" in
  "1" )
    echo "One"
    ;;
  "2" )
    echo "Two"
    ;;
  "3" )
    echo "Three"
    ;;
  *)
    echo "$@"
    ;;
esac
```

When I test the different edge cases, I get:

```
$ ./foo 1

One

$ ./foo 2

Two

$ ./foo 3

Three

$ ./foo 4

4
```

Interestingly, when I remove the quotes from around the numbers in the case statements, the script continues to function as normal.

#### Pattern-matching in case statements

The earlier bullet points also explain the syntax of the subsequent line, which is a condition that the case statement will match against:

```
    -e* | -- ) break ;;
    ...
```

We see two patterns (`-e` and `--`), separated by the `|` character, then terminated by the `)` character, as mentioned in bullet point 2 above.  If the current arg in the iteration matches either pattern, we exit the `for` loop (i.e. we `break`).

Because of point #7 above, I suspect that any text starting with `-e` would fit the `-e*` pattern.  To prove it, I perform an experiment.

#### Experiment- the `-e*` flag in a case statement

I write the following script:

```
#!/usr/bin/env bash

for arg; do
  case "$arg" in
    -e* ) echo "Pattern matched; exiting..."
    break ;;
    * )
      echo "arg is: $arg" ;;
  esac
done

echo "Outside the for loop"
```

This is a simplified version of the original case statement.  It iterates over the args, and if an arg matches `-e*`, we echo a test string ("Pattern matched; exiting...") and break out of the loop.  Otherwise, we just echo the arg itself and keep iterating.  When we’re done with all the args in the loop, we echo "Outside the for loop" to indicate that the script is finished.

I then run the following:

```
$ ./foo bar -ebaz buzz
arg is: bar
Pattern matched; exiting...
Outside the for loop
```

So we printed our first arg, and then "Pattern matched; exiting...", then we did *not* print the third arg (`buzz`).  This is because "-ebaz" starts with "-e", which matched the `break` condition of `-e*`.  Lastly, we printed "Outside the for loop" to prove that `break`ing doesn’t result in an exit of the entire script.  Based on this result, I think we can safely say that we were correct, and the `-e*` flag returns true if a given string starts with `-e`, regardless of what follows after.

To figure out what the `-e` flag actually does, I just ran `ruby –help` and searched for the `-e` entry.  This flag lets you execute Ruby code directly in your terminal, without having to pass a filename to the Ruby interpreter:

<p style="text-align: center">
  <img src="/assets/images/ruby-help-e.png" width="70%" alt="`ruby --help` output`">
</p>

For example:

```
$ ruby -e "puts 'Hello'"

Hello
```

So passing Ruby code directly to the `ruby` interpreter in your terminal (via the `-e` flag) is one of the two scenarios which will cause `rbenv` to assume that any **subsequent** args are meant to be positional args, not flags to the `ruby` command itself.

Regarding the 2nd pattern (`--`), I’ve seen it used in terminal commands before but I doubt I could explain its purpose.  StackOverflow [saves the day again](https://web.archive.org/web/20220623104640/https://unix.stackexchange.com/questions/11376/what-does-double-dash-mean):

<p style="text-align: center">
  <img src="/assets/images/double-dash.png" width="70%" alt="What is a double-dash?" style="border: 1px solid black; padding: 0.5em">
</p>

I think this means that everything before `--` is meant to be a flag, and everything after that is an argument to the script itself.

Hmmm OK, but you still need to be able to process the subsequent arguments in the script, right?  In our case, if the text matches the `--` pattern, does that mean the script breaks out of the list of args, meaning we won’t process anything after `--`?

Not quite.  We'll see shortly that the last line of the shim file makes use of `"$@"` again, specifically to pass those args to `$program`.  The value of `$@` is not modified at all by anything in the `for` loop, so all the args which get passed to the shim file are *also* passed in their original form to `$program`.  By `break`ing here, the only thing we're doing here is preventing those positional arguments from affecting the value of `RBENV_DIR`, which (as we'll see shortly) is the real purpose of the `for`-loop.

#### More pattern-matching with case statements

Next line of code:

```
    */* )
      ...
      ;;

```

Judging by the `)` terminator character and the `;;` a few lines down, we can see that this is another pattern that the case statement will match against.  The only thing that throws me off is the difference between the above pattern (`*/* )`) and the one in my experiment script (`* )`), which I borrowed from the link on case statements.

The pattern searches for a forward-slash, with zero or more arbitrary characters before and/or after it.  To me, that looks like it's trying to match against a file path.  Let’s check that with an experiment.

#### Experiment: how to check for a filepath in a case statement

I make a `bash` script which looks like so

```
#!/usr/bin/env bash

for arg; do
  case "$arg" in
    */* )
      echo "match: $arg";
    ;;
    * )
      echo "not a match: $arg";
    ;;
  esac
done
```

I then run the following in my terminal:

```
$ ./foo 1 2 3 a/b /b a/ / ''
not a match: 1
not a match: 2
not a match: 3
match: a/b
match: /b
match: a/
match: /
not a match:
```

So yes, it appears to be looking for strings which match the `/` symbol with zero or more characters of text on either side.

But just because it *looks* like a valid filepath, doesn't mean it *is* one.  So how do we know it’s a file?
