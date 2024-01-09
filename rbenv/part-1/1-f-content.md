Moving onto the next line of code.

```
  for arg; do

  ...

  done
```

## for-loops in bash

We saw a regular `bash` for-loop earlier, in our experiment with delimiters and `IFS`.  This loop is a bit weird, though, because we haven't yet seen an `arg` variable explicitly defined by the code.  Yet here it is, all the same.

If we haven't seen this variable defined yet, does that mean it's defined or built-in by the language?  As usual, Googling turns up [a StackOverflow post](https://web.archive.org/web/20230406161948/https://stackoverflow.com/questions/73134672/linux-shell-for-arg-do){:target="_blank" rel="noopener"}:

<center>
  <a href="/assets/images/arg-for-loop.png" target="_blank">
    <img src="/assets/images/arg-for-loop.png" width="90%" alt="What is `arg` in a bash `for` loop?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Scrolling down in the answer a bit, we see:

<center>
  <a href="/assets/images/arg-for-loop-2.png" target="_blank">
  <img src="/assets/images/arg-for-loop-2.png" width="90%" alt="Omitting `in` in a bash `for` loop?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The above statement implies that `$@` expands to the list of arguments provided to the script.  Let's see if that's true with another experiment.

### Experiment- what does `$@` evaluate to?

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

They print on separate lines this time, because now we're iterating over them with the `for` loop and making a separate call to `echo` for each arg, instead of printing them all at once via `$@`.

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

Awesome!  Nothing changed, meaning that the `in "$@"` bit is optional in this case.

So we learned:

 - `$@` stands for the arguments that you pass to the script
 - If you write a `for` loop but leave off the `in ___` part, bash defaults to using `$@`

## Case statements

Moving on to the next line:

```
case "$arg" in
...
esac
```

If you've done any programming before, you've likely seen case statements before (Ruby has them, as well).  But it might still pay to familiarize ourselves with the way `bash` in particular handles them.

I try `help case` in my `bash` terminal, and get the following:

```
bash-3.2$ help case

case: case WORD in [PATTERN [| PATTERN]...) COMMANDS ;;]... esac
    Selectively execute COMMANDS based upon WORD matching PATTERN.  The
    `|' is used to separate multiple patterns.
```

OK, pretty short and doesn't tell me much more than I already know.

I find [this link](https://web.archive.org/web/20220820011836/https://linuxize.com/post/bash-case-statement/){:target="_blank" rel="noopener"}, which explains bash's case statement syntax.  It's much too long to copy/paste in its entirety, but there's a lot of good stuff in it.  Here is the general pattern that `case` statements take in `bash`:

```
case EXPRESSION in

  PATTERN_1)
    STATEMENTS
    ;;

  PATTERN_2)
    STATEMENTS
    ;;

  PATTERN_N)
    STATEMENTS
    ;;

  *)
    STATEMENTS
    ;;
esac
```

And here is a specific example the article provides:

```
#!/bin/bash

echo -n "Enter the name of a country: "
read COUNTRY

echo -n "The official language of $COUNTRY is "

case $COUNTRY in

  Lithuania)
    echo -n "Lithuanian"
    ;;

  Romania | Moldova)
    echo -n "Romanian"
    ;;

  Italy | "San Marino" | Switzerland | "Vatican City")
    echo -n "Italian"
    ;;

  *)
    echo -n "unknown"
    ;;
esac
```

From these snippets and from the article as a whole, my takeaways are:

 - Each `case` statement starts with the `case` keyword, followed by the case expression and the `in` keyword. The statement ends with the `esac` keyword.

 - The `)` operator terminates a pattern list.

 - You can use multiple patterns separated by the `|` operator.

 - A pattern can have [special characters](https://web.archive.org/web/20220820011901/https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html){:target="_blank" rel="noopener"}.

 - A pattern and its associated commands are known as a clause.

 - Each clause must be terminated with `;;`.

 - The commands corresponding to the first pattern that matches the expression are executed.

 - It is a common practice to use the wildcard asterisk symbol (`*`) as a final pattern to define the default case. This pattern will always match.

 - If no pattern is matched, the return status is zero.

 - Otherwise, the return status is the [exit status](https://web.archive.org/web/20220806222213/https://linuxize.com/post/bash-exit/){:target="_blank" rel="noopener"} of the executed commands (aka the clause).

The only thing new here, at least for me, is the syntax.  In general, these rules all appear to match how case statements work in Ruby and other languages I've worked with.

### Experiment- building a simple `case` statement

To solidify our understanding of how `bash` handles case statements, let's build a simple one here.  I start by updating my `foo` script to look like the following:

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

Next, I add a few non-default conditions:

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

Lastly, I try adding a clause with more than one pattern:

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
  "4" | "5" )
    echo "Either four or five"
    ;;
  *)
    echo "$@"
    ;;
esac
```

When I run it, I get:

```
$ ./foo 4

Either four or five

$ ./foo 5

Either four or five
```

No surprises so far- all the examples worked the way I'd expect.  Interestingly, when I remove the quotes from around the numbers in the case statements, the script continues to function as normal.

## Pattern-matching in case statements

Next line of code:

```
    -e* | -- ) break ;;
    ...
```

In the earlier list of bullet points, I mentioned:

> A pattern can have [special characters](https://web.archive.org/web/20220820011901/https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html){:target="_blank" rel="noopener"}.

This explains the syntax of the first clause of the shim's case statement.

We see two patterns (`-e*` and `--`), separated by the `|` character, then terminated by the `)` character, as mentioned in bullet points 2 and 3 above.  If the current arg in the iteration matches either pattern, we exit the `for` loop (i.e. we `break`).  Otherwise, we fall through and check the next clause in the case statement.

In the above link, the `*` symbol is listed as one of the "special characters" available in `bash` pattern matching:

> *
>
> Matches any string, including the null string...

This makes me suspect that any text starting with `-e` (followed by zero or more characters) would fit the `-e*` pattern.  To prove it, I perform an experiment.

### Experiment- the `-e*` flag in a case statement

I write the following script:

```
#!/usr/bin/env bash

for arg; do
  case "$arg" in
    -e* ) echo "Pattern matched on arg $arg; exiting..."
    break ;;
    * )
      echo "arg is: $arg" ;;
  esac
done

echo "Outside the for loop"
```

This is a simplified version of the original case statement.  It iterates over the list of args, and does the following:

 - if an arg matches `-e*`, we echo a test string ("Pattern matched on arg ___; exiting...", where `___` is the value of the argument) and break out of the loop.
 - Otherwise, we just echo the arg itself and keep iterating until we've handled all the arguments.
 - When we're done with the `for`-loop, we echo "Outside the for loop" to indicate that the script is finished.

I then run the following:

```
$ ./foo bar -ebaz buzz

arg is: bar
Pattern matched on arg -ebaz; exiting...
Outside the for loop
```

So we printed our first arg, and then "Pattern matched on arg -ebaz; exiting...", then we did **not** print the third arg (`buzz`).  This is because "-ebaz" starts with "-e", which matched the `break` condition of `-e*`.  Lastly, we printed "Outside the for loop" to prove that `break`ing only terminates the iterations of the `for`-loop, as opposed to the entire script.

Based on this result, I think we can safely say that we were correct, and the `-e*` flag returns true if a given string starts with `-e`, regardless of what follows after.

### What does the `-e` flag do?

We know that this flag is for the `ruby` command because the case statement clause is located inside the aforementioned `if` check in the shim:

```
if [ "$program" = "ruby" ]; then
...
fi
```

So to figure out what the `-e` flag actually does, I just ran `ruby –help` and searched for the `-e` entry.

As it turns out, this flag lets you execute Ruby code directly in your terminal, without having to pass a filename to the Ruby interpreter:

<p style="text-align: center">
  <a href="/assets/images/ruby-help-e.png" target="_blank">
    <img src="/assets/images/ruby-help-e.png" width="90%" alt="`ruby --help` output`">
  </a>
</p>

For example:

```
$ ruby -e "puts 'Hello'"

Hello
```

So passing Ruby code directly to the `ruby` interpreter in your terminal (via the `-e` flag) is one of the two scenarios which will cause `rbenv` to assume that any **subsequent** args are meant to be positional args, not flags to the `ruby` command itself.

Regarding the 2nd pattern (`--`), I've seen it used in terminal commands before but I doubt I could explain its purpose.

What does `--` actually signify?  StackOverflow [saves the day again](https://web.archive.org/web/20220623104640/https://unix.stackexchange.com/questions/11376/what-does-double-dash-mean){:target="_blank" rel="noopener"}:

<center>
  <a target="_blank" href="/assets/images/double-dash.png">
    <img src="/assets/images/double-dash.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

I think this means that everything before `--` is meant to be a flag, and everything after that is an argument to the script itself.

We can deduce something from this clause and the conditions it matches (`-e*` or `--`).  And that is that both of these conditions, in their own way, are meant to signify that everything else which comes afterward is an argument that tells the `ruby` command **what** to process, **not** a flag which tells the script **how** to process it.

## Setting `RBENV_DIR`

Next block of code:

```
    */* )
      ...
      ;;

```

Judging by the `)` terminator character and the `;;` a few lines down, we can see that this is a new clause of our case statement, and that `*/*` is a pattern that the case statement will match against.

One difference I notice is that this is **not** the same as a "catch-all" default case, because the `*/* )` pattern here doesn't exactly match the `* )` pattern in the example code we read earlier.

Instead, it looks like this pattern searches for a forward-slash, surrounded on either side with zero or more arbitrary characters.  The one thing I can think of which would match that pattern is a file path.  Let's check that with an experiment.

#### Experiment: matching the `*/*` pattern

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

I send my `./foo` script the following arguments:

 - 3 arguments with no forward slashes (just 3 random numbers, `1`, `2`, and `3`).
 - 4 arguments containing a forward slash:
    - one with characters both before and after, `a/b`
    - one with a character to the right of the slash, `/b`
    - one with a character to the left of the slash, `a/`
    - one with no characters before or after, `/`
 - an empty string, `''`

When I run the script:

 - the first group of 3 patterns **don't** match
 - the second group of 4 patterns **do** match
 - the final empty string does **not** match

So yes, it appears to be looking for strings which match the `/` symbol with zero or more characters of text on either side.

But just because it *looks* like a valid filepath, doesn't mean it *is* one.  So how do we know it's a file?

We'll answer that question on the next page.
