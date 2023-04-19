

Next line of code is:

```
abort() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}
```

## Shell Functions

This declares a function named `abort`.  There's a block of code surrounded with curly braces, with `>&2` appended to the end:

```
  { if [ "$#" -eq 0 ]; then cat -
  ...  } >&2
```

I'm a bit thrown off by this syntax here. Why is this code...

```
if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
```

...wrapped inside this code?

```
{
...
} >&2
```

Let's start on the outside and work our way in.  What is the function of the curly braces?

## Output Grouping

I Google "curly braces bash", and the first result I get is [this one from Linux.com](https://web.archive.org/web/20230306114329/https://www.linux.com/topic/desktop/all-about-curly-braces-bash/){:target="_blank" rel="noopener"}, which sounds promising.  I scan through the article looking for syntax which is similar to what we're doing, and along the way I learn some interesting but unrelated stuff (for instance, `echo {10..0..2}` will print every 2nd number from 10 down to 0 in your terminal).

Finally I get to the last section of the article, called "Output Grouping".  It's here that I learn that "...you can also use `{ ... }` to group the output from several commands into one big blob."

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-937am.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="...you can also use `{ ... }` to group the output from several commands into one big blob.">
</center>

Cool, mystery solved- we're capturing the output of everything inside the curly braces, so we can output it all together (instead of just the last statement).

## Redirection

Next question- what is `>&2` at the end there?  In the above example, we were redirecting all the output to a file, but that doesn't look like what we're doing here since there's no filename to send things to.

I Google ">&2 bash".  The first result is from [StackExchange](https://askubuntu.com/questions/1182450/what-does-2-mean-in-a-shell-script){:target="_blank" rel="noopener"}:

> Using > to redirect output is the same as using 1>. This says to redirect stdout (file descriptor 1).
>
> Normally, we redirect to a file. However, we can use >& to redirect to stdout (file descriptor 1) or stderr (file descriptor 2) instead.
>
> Therefore, to redirect stdout (file descriptor 1) to stderr (file descriptor 2), you can use >&2

Looks like we're redirecting the output of whatever is inside the curly braces, and sending it to stderr.  I happen to know from prior experience that `stdout` is short-hand for "standard out", and "stderr" means "standard error".  I have a vague notion of what these terms mean, but I'm not sure I could verbalize what they actually refer to.

I Google "stdout stdin stderr" and get [this link](https://web.archive.org/web/20230309084428/https://www.tutorialspoint.com/understanding-stdin-stderr-and-stdout-in-linux){:target="_blank" rel="noopener"} as the first result.  From reading it, I learn that:

 - these three things are called "data streams".
 - "...a data stream is something that gives us the ability to transfer data from a source to an outflow and vice versa. The source and the outflow are the two end points of the data stream."
 - "...in Linux all these streams are treated as if they were files."
 - "...linux assigns unique values to each of these data streams:
    - 0 = stdin
    - 1 = stdout
    - 2 = stderr"

One additional thing to call out is from [the 2nd Google result, from Microsoft](https://web.archive.org/web/20230225220140/https://learn.microsoft.com/en-us/cpp/c-runtime-library/stdin-stdout-stderr?view=msvc-170){:target="_blank" rel="noopener"}:

> By default, standard input is read from the keyboard, while standard output and standard error are printed to the screen.

So... the output of the code between our curly braces would normally be printed to the screen, but instead we're printing it to... the screen?  That doesn't make sense- why would we redirect something from one place and to the same place?

It's helpful to stop associating `stdout` and `stderr` with "the screen" and *start* thinking of them as two ends of a pipe.  We can chain this pipe to other pipes any way we want.  And, importantly, **so can other people**.  So if we redirect the output of our `abort` function to `stderr`, then someone else can pick up where we left off, and send the output of `stderr` anywhere they want.

This idea of chaining and composing things together using (among other things) `stdin`, `stdout`, and `stderr` makes our job as `bash` programmers way easier, and is one of the Big Ideas™ of UNIX.

A website called Guru99 seems to have [some good content on redirection](https://web.archive.org/web/20230309072616/https://www.guru99.com/linux-redirection.html){:target="_blank" rel="noopener"}.  For example:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1039am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Here we're taking the output of the `ls -al` command (which would normally be sent to the screen via `stdout`) and redirecting it to a file instead via the `>` character.

But wait, I've also previously seen the `|` character used to send output from one place to another.  Why are we using `>` here instead?

I Google "difference between < > \| unix", but the special characters confuse Google and I get a bunch of irrelevant results.  I try my luck with ChatGPT, with the understanding that I'll need to double-check its answers after:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1052am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

ChatGPT tells me that `>` and `<` are used for "redirection", i.e. sending output to or pulling input from **a file**.  On the other hand, `|` is used for "piping" output to a **command**.

Based on this, I Google "difference between redirection and piping unix", and one of the first results I get is [this StackExchange post](https://web.archive.org/web/20220630113310/https://askubuntu.com/questions/172982/what-is-the-difference-between-redirection-and-pipe){:target="_blank" rel="noopener"} which says something quite similar to ChatGPT:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1101am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</center>

I like that this person explains how it's possible (but clunky) to use `>` to redirect to a file, and then use `<` to grab the content of that file and redirect it to another command.  So instead, we just use `|` instead.  That somehow makes things much clearer for me.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So what exactly is the output that we're reirecting to `stderr`?  Let's move on to the code inside the curlies.
