### Parameter Expansion

Moving on to the next line of code:

```
program="${0##*/}"
```

Judging by the variable name, it looks like we're trying to store the name of the program.  Let's see whether we're right with an experiment.

#### Experiment- are we storing the string we think we're storing?

I edit the shim file (`~/.rbenv/shims/bundle`) to echo the value of `program` after the above line of code:

```
...
program="${0##*/}"
echo "program name: $program"
...
```

Then I run the following:

<p style="text-align: center">
  <img src="/assets/images/echo-program.png" width="50%" alt="echo the contents of the `program` variable">
</p>

Don't worry about `Could not locate Gemfile`- that's what happens when you try to run the `bundle` command in a directory without a file named `Gemfile`.  If I were to create an empty file named `Gemfile` and re-run the command, that error would go away and be replaced by a success message.

The important thing here is that the `bundle` command printed out `program name: bundle`.  Just to be safe, I do the same experiment with the shim for the `ruby` command (i.e. `~/.rbenv/shims/ruby`):

```
program="${0##*/}"
echo "program name: $program"
```

Then I run:

<p style="text-align: center">
  <img src="/assets/images/echo-program-2.png" width="50%" alt="echo the contents of the `program` variable">
</p>

Same thing- it printed the name of the first command I entered into the terminal, followed by the expected output of the `ruby -e "puts 5+5"` command.  By this point, I am confident that `${0##*/}` evaluates to "bundle" in my case.

Before I forget, I delete my `echo` commands from both the `bundle` and `ruby` shims.

But what is this weird syntax which evaluates to the name of the program?  After Googling that exact string ("${0##*/}"), I find [this StackOverflow link](https://archive.ph/1wCki), which says:

<p style="text-align: center">
  <img src="/assets/images/param-expansion-example-1.png" width="50%" alt="parameter expansion- first example" style="border: 1px solid black; padding: 0.5em">
</p>

We actually saw `$0` before, when we were testing out the name of our shell.  The author claims that `$0` will evaluate to the path of the file that we're executing.  This fits with that earlier test, because at that time, "the file that we're executing" was our shell program.

Let's test out what happens when that file is *not* a shell program.

#### Experiment- messing around with parameter expansion

I create a directory named "foo".  Inside of that a subdirectory named "bar", and inside of that I create a file named "baz".  Inside of "baz" I type the following:

```
#!/usr/bin/env bash

echo "$0"
```

I then `chmod +x` it, so that it will execute:

```
$ chmod +x ./foo/bar/baz
```

And when I run it:

```
$ ./foo/bar/baz

./foo/bar/baz
```

The output was `./foo/bar/baz`, meaning we've verified that we can reproduce the `$0` behavior described in the StackOverflow post.

Based on the answer, I wondered whether wrapping `$0` in curly braces would change its output.  I tried this too:

```
#!/usr/bin/env bash

echo "${0}"
```

When I executed this updated version of `./foo/bar/baz`, it displayed the same output as before.  So `"$0"` and `"${0}"` seem to be functionally equivalent.

Now to test the 2nd part of the answer, about removing prefixes.  I'll first try the same syntax as in the StackOverflow answer (i.e. `##*/`):

```
#!/usr/bin/env bash

echo "${0##*/}"
```
When I run it:

```
$ ./foo/bar/baz

baz
```

So without the `##*/` syntax, we get `./foo/bar/baz` as our output.  **With** this new syntax, we get just `baz` as the output.  Therefore, adding `##*/` inside the curly braces had the effect of removing the leading `./foo/bar/` from `./foo/bar/baz`.

Out of curiosity, what happens when I remove one of the two "#" symbols?

```
#!/usr/bin/env bash

echo "${0#*/}"
```

Running it returns:

```
$ ./foo/bar/baz

foo/bar/baz
```

So instead of either `./foo/bar/baz` or `baz` as the output, now we get `foo/bar/baz`.  In other words, no leading `./` before `foo/`.

This is expected.  The StackOverflow answer mentions that including only one `#` will cause the parameter expansion to stop after matching the first case of its search pattern.  In this case, our search pattern is the `*/` character, meaning the first `/` character plus anything before it.  So one `#` will cause `./` to be removed, while two `##` will cause `./foo/foo/` to be removed.

Lastly, going back to the concept that the StackOverflow answer mentioned, i.e. "parameter expansion".  I Google around a bit and find [this link](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html), which looks like good documentation for me to bookmark and refer back to later, if I need to.

I feel like my understanding of the topic is good enough for now.  Next line of code.

### Conditional statements

```
if [ "$program" = "ruby" ]; then
...
fi
```

We already know what the bracket syntax does.  We also know we need double-quotes to expand our `program` variable safely.  And `if ... then` is one of the few bash commands which is likely to be readable to a layperson.  `fi` is just the way to close an `if` statement in `bash`.

So the purpose of this `if` check is to ensure the subsequent code only gets executed if the user typed `ruby` into the terminal as the program name.  Otherwise, nothing inside the `if` block gets executed.  Later, we'll examine that subsequent code and what it actually does.

The one thing that trips me up is the single equals sign.  In Ruby, we use single equals for variable assignment and double-equals for a comparison.  And in fact, we literally *just did that* here in `bash`-land, when we assigned to the `program` local variable using a single-equals sign.  But in bash, it looks like you can get away with single equals for a comparison operation, as long as the comparison is wrapped in square brackets?

Let's see whether this is true.

#### Experiment- double- vs. single-equals comparison

I run the following experiment, in a new script file:

```
#!/usr/bin/env bash

program='ruby'
[ "$program" == "ruby" ] && echo "True"
```

When I `chmod` the file and run it, `True` prints out.  OK, using double-equals sign for a comparison operation does, in fact, work in bash.  I then remove one of the equals signs and run it again, and the same thing happens.  So it seems like, in bash, the double- and single-equals syntaxes are equivalent.

To confirm this further, I Google "bash double vs single equals" and I find [this StackOverflow post](https://stackoverflow.com/questions/12948456/is-there-any-difference-between-and-operators-in-bash-or-sh):

<p style="text-align: center">
  <img src="/assets/images/double-vs-single-equals.png" width="90%" alt="the difference between = and == in bash" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so even though we're guaranteed to be using the `bash` shell by the time we execute this code (because of the shebang), we don't know *which version of `bash`* we're using.  It could be an older version, perhaps even one which doesn't support double-equals for a comparison operation.

Interestingly, I also try running the following directly in my terminal, without creating a whole new file (remember my terminal is zsh):

```
[ "$program" == "ruby" ] && echo "True"
zsh: = not found
```

So does that mean we can’t use double-equals in zsh?

To answer this, I Google around a bit and find [this link](https://archive.ph/2iSkK) for a StackOverflow question.  Apparently in `zsh`,...

```
a == is a logical operator only inside [[ ... ]] constructs.
```

I know that `==` is an example of a "logical operator", so the above implies that I need to use double-brackets in my command.

So what’s the difference between single- and double-`[`?

#### Double- vs. single-`[`

[This StackOverflow page](https://web.archive.org/web/20220602085208/https://serverfault.com/questions/52034/what-is-the-difference-between-double-and-single-square-brackets-in-bash) provides some help:

<p style="text-align: center">
  <img src="/assets/images/brackets.png" width="70%" alt="bracket syntax in bash" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so `[` is more POSIX-compliant than `[[`, therefore it’s more portable across a wider array of machines.  `[[` is more modern and comes with some helpful extras (like easier compatibility with `==`, as we saw earlier), so it can sometimes be easier to use.  But if you’re writing a script that will be used by many people and you can’t predict which shell they’ll run it on (or which version of a shell), you’re probably safer using `[`.

Lastly, I discovered further down in that StackOverflow link that I *can* use single-brackets with `==`, but I have to wrap the double-equals sign in quotes, like this:

```
[ "$program" '==' "ruby" ] && echo "True"
True

```

I thought it was interesting to highlight, but I doubt I'd ever bother going to that extra trouble, just to use double-equals.
