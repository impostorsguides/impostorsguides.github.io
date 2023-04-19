## Counting Parameters

First question- what does `$#` evaluate to?  According to [StackOverflow](https://web.archive.org/web/20211120050118/https://askubuntu.com/questions/939620/what-does-mean-in-bash){:target="_blank" rel="noopener"}:

> `echo $#` outputs the number of positional parameters of your script.

So `[ "$#" -eq 0 ]` means "if the # of positional parameters is equal to zero"?  Let's test that with an experiment.

### Experiment- counting parameters

I write the following script, named `foo`:

```
#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
  echo "no args given"
else
  echo "$# args given"
fi
```

When I run it with no args, I see:

```
$ ./foo

no args given
```

When I run it with one arg, I see:

```
$ ./foo bar

1 args given
```

And when I run it with multiple args, I see:

```
$ ./foo bar baz

2 args given
```

Good enough for me!  I think we can conclude that `[ "$#" -eq 0 ]` returns true if the number of args is equal to zero.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

But whose positional parameters are we talking about- the `abort` function's params, or rbenv's params?

I try wrapping my experiment code in a simple function definition:

```
#!/usr/bin/env bash

function myFunc() {
  if [ "$#" -eq 0 ]; then
    echo 'no args given';
  else
    echo "$# args given";
  fi
}

echo "$# args given to the file";

myFunc foo bar baz buzz
```

I'm passing 4 args to `myFunc`, but I'm planning to call my script with only 2 args, with the intention that:

 - If `$#` refers to the number of args sent to the file, then we should see the same counts from the `echo` statements outside vs. inside the function.
 - But if `$#` refers to the # of args sent to `myFunc`, then we'll see different counts for these two `echo` statements.

When I run the script file with multiple args, I see:

```
$ ./foo bar baz

2 args given to the file
4 args given
```

We see different counts for the # of args passed to the file vs. to `myFunc`.  So when `$#` is inside a function, it *must* be refer to the # of args passed to that same function.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Back to our block of code:

```
  { if [ "$#" -eq 0 ]; then cat -
  ...  } >&2
```

So if the number of args we pass to `abort` is 0, then we execute `cat -`.  What is `cat -`?

I type `help cat` in my terminal, and get the following:

> The `cat` utility reads files sequentially, writing them to the standard output.  The file operands are processed in command-line order.  If file is a single dash ('-') or absent, `cat` reads from the standard input.

OK, so if there are no args passed to `abort`, then we read from standard input.  Interesting.  Based on what we learned earlier about redirection and piping, I wonder if the caller of the `abort` function is piping its `stdout` to the `stdin` here, so that `abort` can read it via `cat -`.

I search for `| abort` in this file, and I find [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L99-L101){:target="_blank" rel="noopener"}:

```
  { rbenv---version
    rbenv-help
  } | abort
```

It looks like we're doing something similar with curly braces (i.e. capturing the output from a block of code) and piping it to `abort`.  So, yeah, it looks like we were right about the purpose of `cat -`- it lets us capture arbitrary input from `stdin` and print it to the screen.

Let's try to replicate that and see what happens:

```
#!/usr/bin/env bash

function foo() {
  {
    if [ "$#" -eq 0 ]; then cat -
    fi
  } >&2
  exit 1
}

echo "Whoops" | foo
```

When I run this script, I see:

```
$ ./foo

Whoops
```

Gotcha- so the logic inside the `if` clause is meant to allow the user (aka the caller of the "abort" function) to be able to send text into the function via piping.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
