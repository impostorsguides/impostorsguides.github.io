We've arrived at the final line of code in the shim:

```
exec "/usr/local/bin/rbenv" exec "$program" "$@"
```

## The `exec` Command

What does the `exec` command at the start of the line do?  I first try `man exec` but I get the "General Commands Manual", indicating that this is a builtin command.  I then try `help exec` and see:

```
$ help exec
exec [ -cl ] [ -a argv0 ] [ command [ arg ... ] ]
       Replace the current shell with command rather than forking.   If
       command  is  a  shell  builtin  command or a shell function, the
       shell executes it, and exits when the command is complete.
```

SO we're *replacing the current shell* with the command that we're running, "rather than forking".  What does that mean?  I Google "what is exec in bash", and one of the first links I find is from [ComputerHope](https://web.archive.org/web/20230323171516/https://www.computerhope.com/unix/bash/exec.htm){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/what-is-exec.png" >
    <img src="/assets/images/what-is-exec.png" width="90%" alt="What is the `exec` bash command?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

<p style="text-align: center">
</p>

To be honest, that explanation creates more questions for me than it answers, including:

 - What's a process?
 - What's the difference between forking a process and replacing the current process with the new one (i.e. what `exec` does)?
 - Why use `exec` over forking, or vice-versa?

## What is a process?

I Google "what is a process in unix" and the first result is from [TechTarget.com](https://web.archive.org/web/20230306013812/https://www.techtarget.com/whatis/definition/process){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/what-is-a-process.png">
    <img src="/assets/images/what-is-a-process.png" width="90%" alt="What is a process in UNIX?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

<p style="text-align: center">
</p>

So from this definition, we learned that:

 - "A process is an instance of a program running on your computer."
 - One process (the "parent process") can create a new process (the "child process").
 - The child process shares resources with the parent process.  I'm not yet sure what resources they mean.
 - If the parent process dies, the child process also dies.

Another useful search result comes from [TheUnixSchool.com](https://web.archive.org/web/20221005124821/https://www.theunixschool.com/2012/09/what-is-process-in-unix-linux.html){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/what-is-a-process-2.png">
    <img src="/assets/images/what-is-a-process-2.png" width="90%" alt="What is a process in UNIX?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

From this link, we additionally learned that:

 - A process has properties associated with it, such as a PID, a PPID, etc.
 - `ps` is a command we can use to see which processes are currently running.

OK, I guess this helps somewhat.  But we still have question #2 to contend with.

## What's the difference between `exec`ing and `fork`ing?

[This StackOverflow answer](https://stackoverflow.com/a/1653415/2143275){:target="_blank" rel="noopener"} is a bit long, but it addresses this question:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/fork-vs-exec.png">
    <img src="/assets/images/fork-vs-exec.png" width="90%" alt="What's the difference between `fork` and `exec`?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The example they give for `fork`ing (rather than `exec`ing) is a web server that needs one process to spin off and handle a request that the server receives, while the parent thread continues to listen for new requests in a separate process.

It appears that, if you know the parent process will be done after running the child process, then `exec` is the way to go because you can re-use the parent's process ID instead of creating a new one.  On the other hand, if the parent still has work to do after the child finishes executing, then `fork` is the way to go.

#### Experiment- messing around with `exec`

Directly in my terminal, I run:

```
$ exec ruby -e "puts 5+5"
10

[Process completed]
```

Since "the shell exits when the command is complete", the final output I see in my terminal tab is `[Process completed]`, and I can no longer run any commands in this tab.  I have to close this tab and open a new one to resume entering commands in the terminal.

Next, I want to see if I can observe this forking behavior as it happens.  I think I'll need to print out the current PID in order to do this, so I Google "how to print the current pid in bash" and find [this link](https://web.archive.org/web/20210515210156/https://www.xmodulo.com/process-id-pid-shell-script.html){:target="_blank" rel="noopener"}, which tells me to use `"$$"`.

I open a new tab, create a script named `./foo` to read as follows:

```
#!/usr/bin/env bash

echo "PID of foo: $$"

./bar
```

I `chmod` the above script to be executable.  Then I create a 2nd script, named `./bar` (also `chmod`'ed), which reads as follows:

```
#!/usr/bin/env bash

echo "PID of bar: $$"
```

In `./foo`, I'm just calling `./bar` directly, with no `exec` beforehand.  I theorize this will default to a `fork`, and that the PID printed by `./foo` will be different from that printed by `./bar`.  I run `./foo` in my terminal and see the following:

```
$ ./foo

PID of foo: 57955
PID of bar: 57956
```

In this case, I was right!  Now, I update `./foo` to preface `./bar` with a call to `exec`:

```
#!/usr/bin/env bash

echo "PID of foo: $$"

exec ./bar
```

When I run it, I get:

```
$ ./foo

PID of foo: 58695
PID of bar: 58695
```

Now the PIDs are the same!  This tells me that the `foo` process did indeed get **replaced** by the `bar` process.


## Using `exec` in the RBENV shim

So that's what the shell builtin `exec` command does.  But the line of code we're looking at is:

```
exec "/usr/local/bin/rbenv" exec ...
```

This means we're running the builtin `exec` command, and *passing it* the `rbenv exec` command.  What does `rbenv exec` do?

To avoid getting ahead of ourselves by looking at the `rbenv-exec` file, for now I just check whether `rbenv exec` accepts a `--help` command:

```
$ rbenv exec --help
Usage: rbenv exec <command> [arg1 arg2...]

Runs an executable by first preparing PATH so that the selected Ruby
version's `bin' directory is at the front.

For example, if the currently selected Ruby version is 1.9.3-p327:
  rbenv exec bundle install

is equivalent to:
  PATH="$RBENV_ROOT/versions/1.9.3-p327/bin:$PATH" bundle install
```

In other words, `rbenv exec` ensures that, when UNIX is checking `PATH` for a directory containing the command we entered, the first directory it finds is the one containing the version of Ruby you have set as your current version.

So the chain of events here is:

 - We call our program (i.e. `bundle` from the command line).
 - That call gets intercepted by the shim file.
 - The shim file sets a value for `RBENV_ROOT`, as well as (sometimes) the value for `RBENV_DIR` (if the file you're running contains a path, i.e. `path/to/file.rb`)
 - The shim file calls `rbenv exec` to ensure that the version of Ruby we want to use is the first version that UNIX finds in our `PATH`.

Based on steps 3 and 4, we can deduce that `rbenv exec` (or a sub-program it calls) relies on the values of `RBENV_ROOT` and possibly `RBENV_DIR` being set, and that those are important to how RBENV determines which Ruby version to use.

But wait- why do we need the Ruby-specific `if`-block in *every* shim, regardless of whether it's a `ruby` shim or not?  We stated earlier that this `if`-block takes up over 2/3 of the lines of code in this file, and that's a clue that it must be pretty important.  But why is that so?

We'll answer this question next.
