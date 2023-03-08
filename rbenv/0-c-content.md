### The `set` command

```
set -e
```

This is the first time I've encountered the `set` command, so I'll have to do some research here.

#### How to look up a command we don't recognize

When looking for the answer to a programming question, I want to avoid wild goose chases and time-wasting rabbit holes.  Usually, that means looking for the most authoritative, original source of truth that I can find.  And it doesn't get any more "authoritative" than reading the manual.

In many cases, we can find the manual for various terminal commands using the `man` command.  If we fail to find what we're looking for using `man`, we can try checking StackOverflow or another source.  But the quality of those sources can vary widely, so a useful habit is to stick to official docs when we can.

#### Experiment- looking up a `man` page

One terminal command that most of us are familiar with by now is `ls`, which prints out the contents of a directory.  Let's use that command as a springboard to help us learn about `man` pages.

If we type `man ls` in the terminal, we get:

<p style="text-align: center">
  <img src="/assets/images/man-ls.png" width="75%" alt="man entry for the ls command">
</p>

Here we can see:
 - the command's name and a brief description
 - a synopsis of the API (the order in which you'd type the command, its flags and args, etc.)
 - a longer description of the command itself (here, "operand" means "the arg you pass to `ls`")
 - an explanation of the command's possible arguments + flags, and what each one does

If we keep scrolling down the `man` page, we'll also see:

 - a list of environment variables which affect how `ls` works
 - a description of the exit code(s) that `ls` might return, and under what conditions they might be returned
 - examples of how to use the `ls` command
 - various other bits of information which aren't immediately relevant to us now

If you're not familiar with `man` pages, I recommend at least skimming the page for `ls`.

#### Looking up the `man` page for `set`

Let's try looking up the above `set` command in its `man` page.  I type `man set` into my terminal and I see the following:

<p style="text-align: center">
  <img src="/assets/images/man-set.png" width="75%" alt="man entry for the set command">
</p>

This `man` page looks a bit different.  If we read it closely, we see that it doesn't describe the `set` command itself.  We don't see the `set` command specifically mentioned at the top, the way we did with `ls`.  Nor do we see the same synopsis or the other sections we saw last time.  Instead, it seems to describe something called the "General Commands Manual".

At first glance, this appears to be an explanation of what a [builtin command](https://archive.ph/Esst2) is in UNIX, not an explanation of the command you're interested in.  As it turns out, depending on the command you give it, sometimes `man` will give you documentation on that command (like it did with `ls`), while other times, it returns the above.

So when does it give you one result, vs. the other?

I found an answer [here](https://unix.stackexchange.com/questions/167004/why-dont-shell-builtins-have-proper-man-pages).  The gist of it is that `man` pages are provided only for commands which come from UNIX.  But `bash` is not UNIX.  UNIX is the operating system, and `bash` is the application we're using to interact with the operating system (aka [the "shell"](https://web.archive.org/web/20220601094544/https://www.pcmag.com/encyclopedia/term/shell) which surrounds the operating system).

### What are shells?

Here's [an article from PCMag](https://web.archive.org/web/20220601094544/https://www.pcmag.com/encyclopedia/term/shell), which describes a shell as "The outer layer of an operating system, otherwise known as the user interface."  I like that definition because it clarifies why the term "shell" was chosen (a shell is "the outer layer" of an egg).

[Wikipedia](https://web.archive.org/web/20220730195425/https://en.wikipedia.org/wiki/Shell_(computing)) confirms this:

<p style="text-align: center">
  <img src="/assets/images/wiki-shell-definition.png" width="75%" alt="Wikipedia's definition of a computing shell" style="border: 1px solid black; padding: 0.5em">
</p>

There are many such applications- other examples include "zsh", "fish", etc.  Later on, we'll actually encounter these two shells again, when we dive into specific `rbenv` commands.

#### What is POSIX?

Further down in the PCMag article, we read:

  > "The term originally referred to the software that processed the commands typed into the Unix operating system. For example, the Bourne shell was the original Unix command line processor, and C shell and Korn shell were developed later."

Wait, but... if there are multiple different kinds of shell programs, doesn't that create a sort of "Wild West" situation where everyone implements commands in their own way?  Is there some sort of industry standard that all shells have to adhere to, to prevent chaos?

I Google "is there a standard for os shells", and the first result that comes up for me is [this link](https://archive.ph/Qr2UB), which includes the following quote:

> After careful research and testing, Bash shell was adopted as the standard for GNU/Linux. At the time of evaluation, Bash was found mostly compliant with the POSIX-1003.2 standard, and its maintainer demonstrated interest in bringing the shell to full compliance.

The phrase "mostly compliant with the POSIX-1003.2 standard" catches my eye.  This seems like the most likely candidate for the standard I had in mind.  For confirmation, I Google "What is POSIX".  Even before I click on any search results, I see the following definition from Google's Dictionary feature:

<p style="text-align: center">
  <img src="/assets/images/what-is-posix-google.png" width="75%" alt="Google's definition for POSIX" style="border: 1px solid black; padding: 0.5em">
</p>

> a set of formal descriptions that provide a standard for the design of operating systems, especially ones which are compatible with Unix.

Looks like we were correct!

#### More about shells

Each shell has its own set of commands, its own syntax, etc.  Some shells (such as `bash` and `zsh`) are quite similar to each other (in terms of the commands they offer).  Others (such as `bash` vs. `fish`) are *very* different from each other.  Therefore, it's important to distinguish which commands are available in all shells from those which are only available in certain shells.

One way we do that is by putting the documentation for UNIX commands in one folder (accessible via the `man` command), and docs for the shell-specific commands (these are called ["builtins"](https://archive.ph/68hcy)) in another folder (accessible via the `help` command in `bash`, or via `run-help` in `zsh` with some extra configuration; see below).

It would be misleading to include manual files for each shell's commands in the same folder that we use to include the manuals for the operating system's commands.  So the shell authors keep the docs for their commands separate.

Moral of the story- if you ever see the  "General Commands Manual" thing when looking up a `man` page, the command you're looking up is probably a *shell builtin*, not a UNIX command.

#### Experiment- which shell are you using?

I'm typing this on a 2019 Macbook Pro, [which ships with `zsh` as its default shell](https://archive.ph/QGwEP).  Your default shell might be the same as mine, or it might `bash` or another shell.

To find out what it is, open your terminal and type the `echo` command, passing [`"$0"`](https://archive.ph/PIQ25) as a parameter:

```
$ echo "$0"
```

When I do this, I see:

```
$ echo "$0"

-zsh
```

We see `-zsh` as the output, telling us that our current shell is `zsh`.

Now, when I open up a `bash` terminal *from* my `zsh` terminal and repeat this, I see the following:

```
$ bash

The default interactive shell is now zsh.
To update your account to use zsh, please run `chsh -s /bin/zsh`.
For more details, please visit https://support.apple.com/kb/HT208050.

bash-3.2$ echo "$0"

bash
```

Now we see `bash`!

By the way, ignore the line that reads `The default interactive shell is now zsh.`  We know we're now in a `bash` terminal because:

 - the command prompt starts with `bash-3.2$`, and
 - more importantly, we saw "bash" when we `echo`'ed `"$0"`.

Note that you might also see advice online about using the `$SHELL` environment variable, like so:

```
echo "$SHELL"
```

When I exit out of my `bash` shell and type this on my machine from my original `zsh` shell, I see:

```
$ echo "$SHELL"

/bin/zsh
```

That's easier to remember, and should work fine in most cases.  The only reason I went with the `echo "$0"` command above is that I wanted the ability to open up `bash` **from `zsh`** and see `bash` as the output, for the purposes of the demonstration.  If I were to do this with `echo "$SHELL"`, I would continue to see `zsh`, even though we're now in a `bash` shell:

```
bash-3.2$ echo "$SHELL"

/bin/zsh
```

That's because [`$SHELL` returns the current user's login shell](https://unix.stackexchange.com/a/669344/142469), **not** the shell that the user is currently using.  But if you are currently inside your default shell anyway (which you likely will be in most cases), using `$SHELL` should be fine.

### Making `help` easier to work with in `zsh`

I try to pull up the `help` docs for `set` to find out more about this command.

In a regular `bash` (i.e. not `zsh`) terminal, typing `help set` offers an explanation of the `set` command:

<p style="text-align: center">
  <img src="/assets/images/bash-help-set.png" width="75%" alt="displayed output for `help set` command in bash">
</p>

On the other hand, typing `help set` into `zsh` displays that `General Commands Manual`, which we've already seen.

Unexpectedly seeing the `General Commands Manual` screen (instead of the command I actually want) is starting to get annoying.

I could configure my laptop to make `bash` the default shell for my machine.  After all, even though `zsh` is now the default for Macbooks, `bash` is still quite common, perhaps even more common worldwide than `zsh`.  This means that quite a few StackOverflow (and other) posts that I will encounter will assume I'm using `bash`.

However, that feels like overkill.  After some Googling around, I found [this StackOverflow question](https://superuser.com/questions/1563825/is-there-a-zsh-equivalent-to-the-bash-help-builtin), with [this answer](https://superuser.com/a/1563859/300277):

<p style="text-align: center">
  <img src="/assets/images/run-help-override.png" width="75%" alt="StackOverflow answer for how to configure the help command in zsh" style="border: 1px solid black; padding: 0.5em">
</p>

It appears to be telling me to:

 - [unalias](https://archive.ph/4ek8N) the current definition of the `run-help` command ([which is aliased to `man` by default in `zsh`](https://archive.ph/cLX5h))
 - [autoload](https://stackoverflow.com/a/63661686/2143275) a new implementation of the `run-help` command
 - reset [`HELPDIR`](https://archive.ph/bFr1h) ("The HELPDIR parameter tells run-help where to look for the help files.")
 - create an alias for our new `run-help` command, called `help`

Essentially what we're doing here is loading `run-help` into our shell, telling it the directory where the docs for the `zsh` commands can be found, and aliasing the `help` command to this `run-help` command (so that we can just type `help` instead of the full `run-help`).

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

#### What is a `.zshrc` file?

When you open a new terminal tab or window in `zsh`, one of the first things that happens is that `zsh` runs [a few setup scripts](https://archive.ph/KlEQ0).  One of these setup scripts is called `.zshrc`.  This file is where you'd put configuration options that you'd want to run on every new terminal tab or window.  This includes our `help` configuration, so that's why we add that code in `.zshrc`.

There are other files as well, such as `.zshenv`, but `.zshrc` is the one I interact with most.  Other shells have similar `rc` files (ex.- `bash` has `.bashrc`).  The `rc` in `.zshrc` stands for "run commands" or "run control", depending on [who you ask](https://archive.ph/r0z0j).

### Finally getting some answers on `set`

Back to the `set` command.

Now I'm able to re-run `help set` from the same terminal window and get a definition:

<p style="text-align: center">
  <img src="/assets/images/zsh-help-set.png" width="75%" alt="successful `help set` output">
</p>

This is great.  IMHO it's a bit less-readable than the output of the `man ls` command, BUT at least now I can see the original source of truth for builtin commands, despite using `zsh` instead of `bash`.

From the first paragraph, I see an explanation of the `-s` flag, and then I see:

```
For the meaning of the other flags, see zshoptions(1).
```

#### `zshoptions`

It's telling me that I need to use another command in order to read about the flags for zsh.  But what's with that `(1)` syntax at the end of the command?  Is that part of what I'm supposed to type?

Although I'm pretty sure this won't work, I try typing `zshoptions(1)` in my terminal, since that **appears to be** the syntax I'm meant to use.  Sure enough, that fails:

```
$ zshoptions(1)
zsh: unknown file attribute: 1
```

What about just "zshoptions"?

```
$ zshoptions
zsh: command not found: zshoptions
```

Welp, I'm out of ideas.  Feels like I'm banging my head against a wall here.  What is "zshoptions", and why is the helpfile telling me to use it?

I try Googling "command not found: zshoptions".  One of the first results I see is [this link](https://archive.ph/QGwEP).  Opening up that link, I read "You can find a full list of zsh options in the zsh Manual or with `man zshoptions`".

OK, so I'm supposed to type `man zshoptions` in the terminal?  Then I guess I'm confused what the `(1)` at the end of `zshoptions(1)` means.

#### Section headers in `man` output

I Google "what is the parentheses number in man bash" and find [this link](https://web.archive.org/web/20230209205725/https://stackoverflow.com/questions/62936/what-does-the-number-in-parentheses-shown-after-unix-command-names-in-manpages-m) with the following answer...

<p style="text-align: center">
  <img src="/assets/images/man-num-parentheses-1.png" width="75%" alt="what are the parentheses in a `man` title" style="border: 1px solid black; padding: 0.5em">
</p>

...followed by this additional answer:

<p style="text-align: center">
  <img src="/assets/images/man-num-parentheses-2.png" width="75%" alt="what are the parentheses in a `man` title" style="border: 1px solid black; padding: 0.5em">
</p>

Cool, so those numbers indicate which section of the UNIX manual the docs can be found in.  Also, it's possible to specify a certain section if a command by a certain name appears in more than one section.  Now I know.

Continuing onward... typing `man zshoptions` has a ton of output to parse.  Luckily, I happen to know [how to search for what I'm looking for in a `man` page](https://archive.ph/UpEPh): typing `/` puts me into search mode in the `man` output.  Then, typing `-e` as a search string and hitting "Enter" takes me to the first occurrence of said search string, and hitting `n` (for `next`) shows me the subsequent occurrences until I find the flag I'm looking for.  Eventually, that takes me to this section:

<p style="text-align: center">
  <img src="/assets/images/set-e.png" width="75%" alt="search for `-e`">
</p>

Just based on my own instinct, the important text seems to be "If a command has a non-zero exit status,... exit."

### Exit Codes

We'll dive more deeply into exit statuses and their meaning with an experiment below, but if you want answers now, check out [this link](https://archive.ph/nCzoq) from The Linux Documentation Project:

<p style="text-align: center">
  <img src="/assets/images/exit-codes.png" width="75%" alt="A description of exit codes" style="border: 1px solid black; padding: 0.5em">
</p>

Exit codes are how shell scripts tell their caller whether they completed successfully or not.  The number can be used to indicate the type of error that occurred during execution, if any.

Here are [the GNU docs](https://web.archive.org/web/20230202185938/https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html) on exit codes, if you want to read more about them.

Back to the first sentence, I interpret it to mean that, if you add `set -e` to your bash script and an error occurs, the program exits immediately, as opposed to continuing on with the execution.  OK, but... isn't that what happens anyway?  That's certainly what I see when I write a Ruby script and an error occurs.  Is the helpfile implying that a program would just continue executing if you *leave out* `set -e` and an error occurs?

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

 - declares the script as a `bash` script
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

 - declares the script as a `bash` script (just like in foo)
 - prints a logline to STDOUT, and
 - triggers a non-zero exit code (i.e. an error)

I run `chmod +x` on both of these scripts, to make sure they're executable.  Then I run `./foo` in my terminal:

```
$ ./foo

Inside bar; about to crash...
```

OK, so we did **not** see the summary line from `foo` printed to the screen.  To me, this indicates that the execution inside `foo` halted once the `bar` script ran into the non-zero exit code.

Now I comment out `set -e` from `foo`:

<p style="text-align: center">
  <img src="/assets/images/commented-set-e.png" width="50%" alt="a commented-out `set -e` command">
</p>

Now when I re-run `./foo`, I see the following:

```
$ ./foo

Inside bar; about to crash...
foo ran successfully
```

This time, I **do** see the summary logline from `foo`.  This tells me that the script's execution continues, even though we're still getting the same non-zero exit code from the `bar` script.

Based on this experiment, I think we can conclude that `set -e` does, in fact, prevent execution from continuing when the script encounters an error.

#### Why isn't `set -e` the default?

But my earlier question remains- why must a developer explicitly include `set -e` in their bash script?  Why is this not the default?  This question feels like it has a subjective answer, meaning that I doubt the answer will be found in the `man` or `help` pages, so I decide to use StackOverflow.

There, I find [these](https://stackoverflow.com/questions/13468481/when-to-use-set-e) [two](https://serverfault.com/questions/143445/what-does-set-e-do-and-why-might-it-be-considered-dangerous) posted questions.  From reading the answers, I gather that there are valid reasons for not using `set -e`, including the ability to catch and handle different errors in different ways:

<p style="text-align: center">
  <img src="/assets/images/set-e-default.png" width="75%" alt="why is `set -e` not the default?" style="border: 1px solid black; padding: 0.5em">
</p>

Therefore, the reason `set -e` is not the default is *probably* because the UNIX authors wanted to give developers more fine-grained control over whether and how to handle different kinds of exceptions.  `set -e` halts your program immediately whenever any kind of error is triggered, so you don't have to explicitly catch each kind of error separately.  Depending on the program you're writing, this might be considered a feature or a bug; it appears to be a matter of preference.

Moving on to line 3 of the code.
