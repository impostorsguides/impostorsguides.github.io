Moving on to the next line of code:

```
program="${0##*/}"
```

## Parameter Expansion

Judging by the variable name, it looks like we're trying to store the name of the program.  Let's see whether we're right with an experiment.

### Experiment- are we storing the string we think we're storing?

I edit the shim file (`~/.rbenv/shims/bundle`) to echo the value of `program` after the above line of code:

```
...
program="${0##*/}"
echo "program name: $program"
...
```

Then I run the following:

```
$ bundle --version

program name: bundle
Bundler version 2.3.14
```

We see `program name: bundle`.  Just to be safe, I do the same experiment with the shim for the `ruby` command (i.e. `~/.rbenv/shims/ruby`):

```
program="${0##*/}"
echo "program name: $program"
```

Then I run:

```
$ ruby -e "puts 5 + 5"

program name: ruby
10
```

Same thing- it printed the name of the first command I entered into the terminal, followed by the expected output of the `ruby -e "puts 5+5"` command.  By this point, I am confident that `${0##*/}` evaluates to "bundle" in my case.

Before I forget, I delete my `echo` commands from both the `bundle` and `ruby` shims.

But what is this weird syntax which evaluates to the name of the program?  After Googling that exact string `"${0##*/}"`, I find [this StackOverflow link](https://web.archive.org/web/20150926110359/https://unix.stackexchange.com/questions/214465/what-does-prog-0-mean-in-a-bash-script/214469){:target="_blank" rel="noopener"}, which says:

<p style="text-align: center">
  <img src="/assets/images/param-expansion-example-1.png" width="80%" alt="parameter expansion- first example" style="border: 1px solid black; padding: 0.5em">
</p>

The answer says we're dealing with something called "parameter expansion".  They claim that:

 - `$0` will evaluate to the path of the file that we're executing, and that
 - we can modify it by the use of `#` and `*/` inside the curly braces.

We actually saw `$0` before, when we were testing out the name of our shell.  Let's test how `$0` is affected by this parameter expansion syntax.

### Experiment- messing around with parameter expansion

I create a directory named `foo/bar/`, containing a file named `baz`, and `chmod` the file so it will execute:

```
$ mkdir -p foo/bar/

$ touch foo/bar/baz

$ chmod +x ./foo/bar/baz
```

Inside of "baz" I type the following:

```
#!/usr/bin/env bash

echo "$0"
```

And when I run it:

```
$ ./foo/bar/baz

./foo/bar/baz
```

The output was `./foo/bar/baz`, meaning we've verified that we can reproduce the `$0` behavior described in the StackOverflow post.

On a hunch, I try wrapping `$0` in curly braces, to see if its output will change:

```
#!/usr/bin/env bash

echo "${0}"
```

When I execute this updated version of `./foo/bar/baz`, it displays the same output as before.  So `"$0"` and `"${0}"` seem to be functionally equivalent.

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

Now we see `foo/bar/baz`.  The `foo/bar/` prefix is no longer missing, but the leading `./` before `foo/` has been removed.

This is expected.  The StackOverflow answer mentions that including only one `#` will cause the parameter expansion to stop after matching the first case of its search pattern.  In our case, this means the first `/` character plus anything before it.

So one `#` will cause `./` to be removed, while two `##` will cause `./foo/foo/` to be removed.

That's pretty much all there is to cover for this line of code.  Before moving on, I Google around a bit and find [this link](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}, which looks like good documentation for me to bookmark and refer back to later, if I need to.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code.

## `if`-blocks

```
if [ "$program" = "ruby" ]; then
...
fi
```

 - We already know what the bracket syntax does.
 - We also know we need double-quotes to expand our `program` variable safely.
 - And `if ... then` is one of the few bash commands which is likely to be readable even without `bash` experience.
 - `fi` is just the way to close an `if` statement in `bash`.

So the purpose of this `if` check is to ensure the subsequent code only gets executed if the user typed `ruby` into the terminal as the program name.  Otherwise, nothing inside the `if` block gets executed.

We'll examine the code inside the `if` block next.

