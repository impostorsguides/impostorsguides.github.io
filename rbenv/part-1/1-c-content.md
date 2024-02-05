The next line of code is:

```
set -e
```

## The `set` command

This is the first time we've encountered the `set` command.  Let's look it up in the docs.

### How to look up a command

In many cases, we can find the manual for various terminal commands using the `man` command.  If we fail to find what we're looking for using `man`, we can try checking StackOverflow or another source.  But the quality of those sources can vary widely, so a useful habit is to stick to official docs when we can.

However, I've found that these `man` pages can be tricky to parse, and if the command you're looking up is a "builtin" (more on this later), then you'll get back a result which may not be helpful to you for the command you're looking for.  Let's walk through an example.

#### Experiment- looking up a `man` page

One terminal command that most of us are familiar with by now is `ls`, which prints out the contents of a directory.  Let's use that command as a springboard to help us learn about `man` pages.

If we type `man ls` in the terminal, we get:

<p style="text-align: center">
  <a href="/assets/images/man-ls.png" target="_blank">
    <img src="/assets/images/man-ls.png" width="95%" alt="man entry for the ls command">
  </a>
</p>

Here we can see:
 - the command's name and a brief description
 - a synopsis of the API (the order in which you'd type the command, its flags and args, etc.)
 - a longer description of the command itself (here, "operand" means "the arg you pass to `ls`")
 - a list of the command's possible arguments + flags, and what each one does

If we keep scrolling down the `man` page, we'll also see:

 - a list of environment variables which affect how `ls` works
 - a description of the exit code(s) that `ls` might return, and under what conditions they might be returned
 - examples of how to use the `ls` command
 - various other bits of information which aren't immediately relevant to us now

If you're not familiar with `man` pages, I recommend running `man ls` in your terminal, and skimming the results.

### Looking up the `man` page for `set`

Let's try looking up the above `set` command in its `man` page.  I type `man set` into my terminal and I see the following:

<p style="text-align: center">
  <a href="/assets/images/man-set.png" target="_blank">
    <img src="/assets/images/man-set.png" width="95%" alt="man entry for the set command">
  </a>
</p>

This `man` page looks a bit different.  It doesn't mention the command name (`set`) in the top-left corner, the way the `man ls` results did.  Instead we just see the word `BUILTIN`.

As it turns out, depending on the command you give it, sometimes `man` will give you documentation on that command (like it did with `ls`), while other times, it returns the above- an explanation of what a [builtin command](https://web.archive.org/web/20230226091101/https://www.gnu.org/software/bash/manual/html_node/Shell-Builtin-Commands.html){:target="_blank" rel="noopener"} is in UNIX.

So when does it give you one result, vs. the other?

I found an answer [here](https://unix.stackexchange.com/questions/167004/why-dont-shell-builtins-have-proper-man-pages){:target="_blank" rel="noopener"}.  The gist of it is that `man` pages are provided only for commands which come from UNIX.  But Bash is not UNIX.  UNIX is the operating system, and Bash is the application we're using to interact with the operating system (aka [the "shell"](https://web.archive.org/web/20220601094544/https://www.pcmag.com/encyclopedia/term/shell){:target="_blank" rel="noopener"} which surrounds the operating system).

The `set` command is a builtin program provided by Bash, not [an external command](https://web.archive.org/web/20220709025237/https://www.geeksforgeeks.org/internal-and-external-commands-in-linux/){:target="_blank" rel="noopener"} provided by UNIX.  Shell authors keep the docs for their commands separate from the docs for OS commands because comingling them together in the same folder would lead to user confusion about whether a given program was a builtin or an external command.

To look up docs on builtin commands, we can use the `help` command.  More on that in a minute.

## What are shells?

Here's [an article from PCMag](https://web.archive.org/web/20220601094544/https://www.pcmag.com/encyclopedia/term/shell){:target="_blank" rel="noopener"}, which describes a shell as "The outer layer of an operating system, otherwise known as the user interface."  If we think of the shell of an egg as being its "outer layer", then this word choice starts to make sense.

There are many examples of shell programs- others include `zsh`, `fish`, `ksh`, etc.  Later on, we'll actually encounter some of these other shells again, when we dive into specific `rbenv` commands.

Wait, but... if there are multiple different kinds of shell programs, doesn't that create a sort of "Wild West" situation where everyone implements commands in their own way?  Is there some sort of industry standard that all shells have to adhere to, to prevent chaos?

### POSIX

I Google "is there a standard for os shells", and the first result that comes up for me is [this link](https://web.archive.org/web/20150929014542/https://refspecs.linuxfoundation.org/LSB_1.0.0/gLSB/stdshell.html){:target="_blank" rel="noopener"}, which includes the following quote:

> After careful research and testing, Bash shell was adopted as the standard for GNU/Linux. At the time of evaluation, Bash was found mostly compliant with the POSIX-1003.2 standard, and its maintainer demonstrated interest in bringing the shell to full compliance.

The phrase "mostly compliant with the POSIX-1003.2 standard" catches my eye.  This seems like the most likely candidate for the standard I had in mind.  For confirmation, I Google "What is POSIX".  One of the results that comes up is from [Wikipedia](https://web.archive.org/web/20230330180553/https://en.wikipedia.org/wiki/POSIX){:target="_blank" rel="noopener"}, which says:

> The Portable Operating System Interface... is a family of standards specified by the IEEE Computer Society for maintaining compatibility between operating systems.  POSIX defines both the system and user-level application programming interfaces (APIs), along with command line shells and utility interfaces, for software compatibility (portability) with variants of Unix and other operating systems.

I interpret this to mean that POSIX defines the standards that determine how users talk to computers (aka "user-level APIs") and also how one part of the computer talks to another part (aka the "system-level APIs").  Looks like we were correct!

### Experiment- which shell are you using?

I'm typing this on a 2019 Macbook Pro, [which ships with `zsh` as its default shell](https://web.archive.org/web/20221205115311/https://scriptingosx.com/2019/06/moving-to-zsh-part-3-shell-options/){:target="_blank" rel="noopener"}.  Your default shell might be the same as mine, or it might Bash or another shell.

To find out what shell we're using, we can open the terminal and type the `echo` command, passing [`"$0"`](https://web.archive.org/web/20230124040420/https://linuxhint.com/0-bash-script/){:target="_blank" rel="noopener"} as a parameter:

```
$ echo "$0"
```

When I do this, I see:

```
$ echo "$0"

-zsh
```

We see `-zsh` as the output, telling us that our current shell is `zsh`.

Now, when I open up a Bash terminal *from* my `zsh` terminal and repeat this, I see the following:

```
$ bash

The default interactive shell is now zsh.
To update your account to use zsh, please run `chsh -s /bin/zsh`.
For more details, please visit https://support.apple.com/kb/HT208050.

bash-3.2$ echo "$0"

bash
```

Now we see Bash!

By the way, ignore the line that reads `The default interactive shell is now zsh.`  We know we're now in a Bash terminal because:

 - the command prompt starts with `bash-3.2$`, and
 - more importantly, we saw "bash" when we `echo`'ed `"$0"`.

You may have also heard about the `$SHELL` environment variable:

```
echo "$SHELL"
```

When I exit out of my Bash shell and type this on my machine from my original `zsh` shell, I see:

```
$ echo "$SHELL"

/bin/zsh
```

That's easier to remember, and should work fine in most cases.  The only reason I went with the `echo "$0"` command above is that I wanted the ability to open up Bash **from `zsh`** and see Bash as the output, for the purposes of the demonstration.  If I were to do this with `echo "$SHELL"`, I would continue to see `zsh`, even though we're now in a Bash shell:

```
bash-3.2$ echo "$SHELL"

/bin/zsh
```

That's because [`$SHELL` returns the current user's login shell](https://unix.stackexchange.com/a/669344/142469){:target="_blank" rel="noopener"}, **not** the shell that the user is currently using.  But if you are currently inside your default shell anyway (which you likely will be in most cases), using `$SHELL` should be fine.

### Making `help` easier to work with in `zsh`

In a regular Bash (i.e. not `zsh`) terminal, typing `help set` offers an explanation of the `set` command:

<p style="text-align: center">
  <a href="/assets/images/bash-help-set.png" target="_blank">
    <img src="/assets/images/bash-help-set.png" width="95%" alt="displayed output for `help set` command in bash">
  </a>
</p>

However, when I try to type `help set` into `zsh`, I see that `General Commands Manual` for builtin commands, which I don't find particularly helpful.  I'd rather see information on the specific command I type in.

I could configure my laptop to make Bash the default shell for my machine.  Then I'd be able to type `help set` and see what I'm looking for.  However, I'm a creature of habit, and over time I've gotten used to `zsh`.  I don't feel like changing the default shell would be worth the effort.

After some Googling around, I found [this StackOverflow question](https://superuser.com/questions/1563825/is-there-a-zsh-equivalent-to-the-bash-help-builtin){:target="_blank" rel="noopener"}, with [this answer](https://superuser.com/a/1563859/300277){:target="_blank" rel="noopener"} describing how to make the `help` output more helpful:

<p style="text-align: center">
  <a href="/assets/images/run-help-override.png" target="_blank">
    <img src="/assets/images/run-help-override.png" width="95%" alt="StackOverflow answer for how to configure the help command in zsh" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

It appears to be telling me to:

 - [unalias](https://web.archive.org/web/20230405124404/https://ss64.com/osx/alias-zsh.html){:target="_blank" rel="noopener"} the current definition of the `run-help` command ([which is aliased to `man` by default in `zsh`](https://web.archive.org/web/20230403130053/https://wiki.archlinux.org/title/zsh){:target="_blank" rel="noopener"})
 - [autoload](https://stackoverflow.com/a/63661686/2143275){:target="_blank" rel="noopener"} a new implementation of the `run-help` command
 - set a new value for [`HELPDIR`](https://web.archive.org/web/20230320043124/https://zsh.sourceforge.io/Doc/Release/User-Contributions.html){:target="_blank" rel="noopener"} ("The HELPDIR parameter tells run-help where to look for the help files.")
 - create an alias for our new `run-help` command, called `help`

This all sounds fine, so I add the code from StackOverflow into my `~/.zshrc` file:

<br />

<div style="width: 800px; margin: auto">
  <div>
    <img src="/assets/images/zshrc.png" width="100%" alt="code in ~/.zshrc file">
  </div>
  <i>(NOTE- the numbers on the far-left side of the screenshot are line numbers displayed by my code editor, **not** part of the code I'm typing.)</i>
</div>

<br />

I then run `source ~/.zshrc` to reload the file into memory.

### What is a `.rc` file?

When you open a new terminal tab or window in `zsh`, one of the first things that happens is that `zsh` runs [a few setup scripts](https://web.archive.org/web/20230317222607/https://zsh.sourceforge.io/Intro/intro_3.html){:target="_blank" rel="noopener"}.  One of these setup scripts is called `.zshrc`.  This file is where you'd put configuration options that you'd want to run on every new terminal tab or window.  This includes our `help` configuration, so that's why we add that code in `.zshrc`.

There are other setup scripts   which get loaded as well, such as `.zshenv`, but `.zshrc` is the one I interact with most.  Other shells have similar `rc` files (ex.- Bash has `.bashrc`).  The `rc` in `.zshrc` stands for "run commands" or "run control", depending on [who you ask](https://web.archive.org/web/20230320050723/https://unix.stackexchange.com/questions/3467/what-does-rc-in-bashrc-stand-for){:target="_blank" rel="noopener"}.

## Finally getting some answers on `set`

Back to the `set` command.

Now I'm able to re-run `help set` from my regular `zsh` terminal window, and get a definition:

<p style="text-align: center">
  <a href="/assets/images/zsh-help-set.png" target="_blank">
    <img src="/assets/images/zsh-help-set.png" width="85%" alt="successful `help set` output">
  </a>
</p>

For me, the format of the `help` output makes it less-readable than a `man` page, BUT at least now I can see the original source of truth for builtin commands, despite using `zsh` instead of Bash.

From the first paragraph, I see the following:

> Set  the options for the shell and/or set the positional parameters, or declare and set an array.

So we're setting "options".  But "options" is pretty vague.  What are options in a terminal?

## Shell Options

I Google "shell options", and one of the first results is [this link](https://web.archive.org/web/20230315104403/https://tldp.org/LDP/abs/html/options.html){:target="_blank" rel="noopener"} from The Linux Documentation Project:

> Options are settings that change shell and/or script behavior.
>
> The `set` command enables options within a script. At the point in the script where you want the options to take effect, use `set -o option-name` or, in short form, `set -option-abbrev`.
>
> These two forms are equivalent.
>
> ```
> #!/bin/bash
>
>      set -o verbose
>      # Echoes all commands before executing.
> ```
>
> ```
>      #!/bin/bash
>
>      set -v
>      # Exact same effect as above.
> ```
>
> To disable an option within a script, use `set +o option-name` or `set +option-abbrev`.

Further down the link, I see a list of options available to set:

<center>
  <a href="/assets/images/screenshot-5apr2023-1013am.png" target="_blank">
    <img src="/assets/images/screenshot-5apr2023-1013am.png" width="95%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

I've highlighted the description of the `-e` flag.  It says:

> Abort script at first error, when a command exits with non-zero status (except in until or while loops, if-tests, list constructs)

Let's look more closely at exit codes (also called exit statuses).

## Exit Codes

Shell scripts need a way to communicate whether they've completed successfully or not.  The way this happens is via exit codes.  We return an exit code via typing `exit` followed by a number.  If the script completed successfully, that number is `0`.  Otherwise, we return a non-zero number which indicates the type of error that occurred during execution.   [This link](https://web.archive.org/web/20230322083153/https://tldp.org/LDP/abs/html/exit-status.html){:target="_blank" rel="noopener"} from The Linux Documentation Project says:

<p style="text-align: center">
  <a href="/assets/images/exit-codes.png" target="_blank">
    <img src="/assets/images/exit-codes.png" width="95%" alt="A description of exit codes" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

For further reading, see [the GNU docs](https://web.archive.org/web/20230202185938/https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html){:target="_blank" rel="noopener"} on exit codes.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Back to `set -e`.  It sounds like, if you add `set -e` to your bash script and an error occurs, the program exits immediately, as opposed to continuing on with the execution.

OK, but... why do I need `set -e` for that?

When I write a Ruby script and an error occurs, the interpreter exits immediately.  Is the helpfile implying that a Bash program would just continue executing if you *leave out* `set -e` and an error occurs?

Let's try an experiment to figure out whether that's the case.

#### Experiment- will `set -e` cause a script to stop when an error is raised?

I make 2 bash scripts, one called `foo` and one called `bar`:

`foo` looks like so:

```
#!/usr/bin/env bash

set -e

./bar

echo "foo ran successfully"
```

It does the following:

 - declares the script as a Bash script
 - calls `set -e` in the theory that this will cause any error to prevent the script from continuing
 - runs the `./bar` script, and
 - prints a summary line

In theory, if an error occurs when running `./bar`, our execution should stop and we shouldn't see "foo ran successfully" as output.

Meanwhile, `bar` looks like so:

```
#!/usr/bin/env bash

echo "Inside bar; about to crash..."

exit 1
```

It does the following:

 - declares the script as a Bash script (just like in foo)
 - prints a logline to STDOUT, and
 - triggers a non-zero exit code (i.e. an error)

I run `chmod +x` on both of these scripts, to make sure they're executable.  Then I run `./foo` in my terminal:

```
$ ./foo

Inside bar; about to crash...
```

OK, so we did **not** see the summary line from `foo` printed to the screen.  To me, this indicates that the execution inside `foo` halted once the `bar` script ran into the non-zero exit code.

Now I comment out `set -e` from `foo`:

```
#!/usr/bin/env bash

# set -e

./bar

echo "foo ran successfully"
```

Now when I re-run `./foo`, I see the following:

```
$ ./foo

Inside bar; about to crash...
foo ran successfully
```

This time, I **do** see the summary logline from `foo`.  This tells me that the script's execution continues, even though we're still getting the same non-zero exit code from the `bar` script.

Based on this experiment, I think we can conclude that `set -e` does, in fact, prevent execution from continuing when the script encounters an error.

### Why isn't `set -e` the default?

But my earlier question remains- why must a developer explicitly include `set -e` in their bash script?  Why is this not the default?  This question feels like it has a subjective answer, meaning that I doubt the answer will be found in the `man` or `help` pages, so I decide to use StackOverflow.

There, I find [these](https://stackoverflow.com/questions/13468481/when-to-use-set-e){:target="_blank" rel="noopener"} [two](https://serverfault.com/questions/143445/what-does-set-e-do-and-why-might-it-be-considered-dangerous){:target="_blank" rel="noopener"} posted questions.  From reading the answers, I gather that the reason `set -e` is not the default is *probably* because the UNIX authors wanted to give developers more fine-grained control over whether and how to handle different kinds of exceptions.  `set -e` halts your program immediately whenever any kind of error is triggered, so you don't have to explicitly catch each kind of error separately.  Depending on the program you're writing, this might be considered a feature or a bug; it appears to be a matter of preference.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That concludes our look at `set -e`.  Let's move on to the next line of code.
