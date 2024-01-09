TODO: write a post on the pros and cons of `fish` vs `zsh` vs `bash`.

Next line of code:

```
commands=(`rbenv-commands --sh`)
```

## Storing the list of shell-specific commands

This line stores the output of `rbenv-commands --sh` in a variable called `commands`.  Since this appears to be executing the libexec folder's `rbenv-commands` script directly, I add `libexec/` to my `$PATH` and run the same command, with the following results:

```
$ PATH=~/Workspace/OpenSource/rbenv/libexec/:$PATH
$ rbenv-commands --sh

rehash
shell
```

When I run `rbenv commands --help`, I see the following:

```
$ rbenv commands --help
Usage: rbenv commands [--sh|--no-sh]

List all available rbenv commands
```

I see `--sh` and `--no-sh` listed as valid flags in the `Usage` section, but no explanation as to what these flags do.

Looking at [the `rbenv-commands` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L30){:target="_blank" rel="noopener"} itself, I see that the `--sh` flag narrows down the output to just the commands whose files contain `sh-` in their names (i.e. `shell` and `rehash`).

I'm not yet sure what makes these commands special or requires them to be treated differently, so I write down that question and decide to revisit it later.

## Kicking off the `rbenv` shell function

Next line of code:

```
case "$shell" in
  fish )
    cat <<EOS
  function rbenv
...
esac
```
Here we use a case statement to execute one of several branches of code, based on the different values of our `$shell` var.  Each branch handles a different shell program.  We'll look at what happens when the user's shell is `fish`.

If that's the case, we call the `cat` function, which takes as its input a [heredoc](https://web.archive.org/web/20230501025456/https://tldp.org/LDP/abs/html/here-docs.html){:target="_blank" rel="noopener"} string (a pattern that we previously saw in [the `init.bats` test file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/init.bats#L36){:target="_blank" rel="noopener"}).

Inside the heredoc is where we begin creating a function named `rbenv`.  According to [the docs](https://web.archive.org/web/20230320234416/https://fishshell.com/docs/current/cmds/function.html){:target="_blank" rel="noopener"}, in `fish` we begin a function declaration with the `function` keyword.

We're creating a function inside a string because that string will be sent to `stdout`, and later used as input for a call to `eval` in our shell configuration file.  We do this because `eval` can execute the code we give it (in this case, our `rbenv` function definition).  Furthermore, it execute that code in such a way that the `rbenv` shell function will actually be available for us to use.

## Installing `fish`

The `fish` shell uses much different syntax than other shells use.  We can refer back to the [Fish shell docs](https://web.archive.org/web/20220720181625/https://fishshell.com/docs/current/cmds/set.html){:target="_blank" rel="noopener"}, however I can already tell that I'll need to install `fish` on my laptop in order to experiment with its syntax.  For example, in the two lines above, why do we use a "$" sign on line 1, but not on line 2?

To install `fish`, I'll use the Homebrew package manager:

```
brew install fish
```

<center>
  <a target="_blank" href="/assets/images/screenshot-13mar2023-808am.png">
    <img src="/assets/images/screenshot-13mar2023-808am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Now when I write a `fish` shebang as the first line of my script, my computer will know how to handle that.

## Storing the command name

Next few lines:

```
  set command \$argv[1]
  set -e argv[1]
```

### The Escape Character

The `\` before the dollar sign is called the [escape character](https://web.archive.org/web/20230317171428/https://www.gnu.org/software/bash/manual/html_node/Escape-Character.html){:target="_blank" rel="noopener"}.  It's necessary because, without it, the interpreter will try to resolve `$argv[1]` into a `bash` variable (since `rbenv-init` is being evaluated as a `bash` script).

We don't want that, at least not here.  Instead, we want `set command $argv[1]` to be part of what gets `echo`'ed to `eval`, so that it gets included in the definition of the `rbenv` shell function.  So whenever you see `\` in this part of `rbenv-init`, it's because we want the character which comes after it to be treated as a string, not as code to be evaluated.

You'll need to leave it out when trying to evaluate `fish` code inside a `fish` shell.  Let's strip it out now, to make the code easier to analyze:

```
  set command $argv[1]
  set -e argv[1]
```

This is the code as our `fish` shell function will see it.

NOTE- occasionally, we **will** want `bash` to treat code with a dollar sign as code.  If we see a `$` **without** the escape character, we'll know that we're looking at a variable which will be resolved to a specific value by the time it reaches `fish`.  This might not make sense in the abstract, but I'll call it out again when we reach a specific example.

### Setting the `command` variable

To understand the above code, let's open up a `fish` shell, and type `man set`:

```
SET(1)                                                                     fish-shell                                                                     SET(1)

NAME
       set - display and change shell variables

SYNOPSIS
       set
       set (-f | --function) (-l | local) (-g | --global) (-U | --universal)
       set [-Uflg] NAME [VALUE ...]
       set [-Uflg] NAME[[INDEX ...]] [VALUE ...]
       set (-a | --append) [-flgU] NAME VALUE ...
       set (-q | --query) (-e | --erase) [-flgU] [NAME][[INDEX]] ...]
       set (-S | --show) [NAME ...]
...
```

The `SYNOPSIS` section of the `man` entry shows us several ways to invoke `set`.  The one we're using here is `set [-Uflg] NAME [VALUE ...]`.  The way we set a shell variable in `fish` is **not** with the syntax `foo='bar'`, but rather `set foo 'bar'`:

```
> set foo 'bar'

> echo "$foo"

bar
```

In the case of our `rbenv` shell function, instead of creating a variable named `foo` and setting it equal to `"bar"`, we're creating a variable named `command` and setting it equal to `$argv[1]`.  What does `$argv[1]` do?

### `argv` in `fish`

According to [the docs](https://web.archive.org/web/20230320234417/https://fishshell.com/docs/current/language.html#envvar-argv){:target="_blank" rel="noopener"}, `argv` is:

```
argv

a list of arguments to the shell or function. argv is only defined when inside
a function call, or if fish was invoked with a list of arguments, like fish
myscript.fish foo bar. This variable can be changed.
```

So `argv` is the list of arguments passed to (in our case) the `rbenv` shell function that we're defining.  And it looks like we can access them using array indexing syntax.  Let's confirm that with an experiment.

#### Experiment- accessing `argv` in `fish`

I make a simple fish script, containing the following:

```
#!/usr/bin/env fish

function foo
  echo "argv: $argv"
  echo "argv[0]: $argv[0]"
  echo "argv[1]: $argv[1]"
  echo "argv[2]: $argv[2]"
  echo "argv[3]: $argv[3]"
end
```

When I run it, I get:

```
> ./foo.fish

argv: bar baz buzz

./foo.fish (line 5): array indices start at 1, not 0.
  echo "argv[0]: $argv[0]"
                       ^
in function 'foo' with arguments 'bar baz buzz'
	called on line 11 of file ./foo.fish

argv[1]: bar

argv[2]: baz

argv[3]: buzz
```

A few things to call out here:

 - We got an error, but the code continued executing.  Presumably that's because we didn't include the `fish` equivalent of [the `bash` `set -e` command](https://web.archive.org/web/20230209180114/https://linuxhint.com/bash-set-e/){:target="_blank" rel="noopener"}, so the code just continues executing when it hits an error.
 - As the error states, `fish` array indices start at 1, not 0.
 - We were correct in our hypothesis that we can access the individual args in `argv` using array indexing syntax.

### Removing an argument from the list

So we store the first argument inside the new variable named `command`.  Then we call `set -e argv[1]`.  But remember, we're in `fish`-land now, so `set -e` here does **not** mean the same thing it does in `bash`.

According to the `SYNOPSIS` section of the above `man` entry for `set`, the `-e` flag is short for `--erase`.  The longer name of the flag `--erase` suggests to me that we're deleting the value inside `argv[1]`.

Let's see if that's true with another experiment.

#### Experiment- modifying `argv` in `fish` using `set`

I write a simple fish script, which declares a function that takes in any args which are passed from the command line:

```
#!/usr/bin/env fish

function foo
  echo "old argv: $argv"
  set -e argv[1]
  echo "new argv: $argv"
  exit
end

foo $argv
```

I call it from the command line, passing in a few arguments:

```
$ ./foo bar baz buzz

old argv: bar baz buzz
new argv: baz buzz
```

Initially, the args passed to the foo function are `bar`, `baz`, and `buzz`.  After I call `set -e argv[1]`, the new args are `baz` and `buzz`.  This means that `set -e argv[1]` has the effect of removing the first arg from the arg list.  This is the same thing that `shift` does in zsh.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So to summarize the following lines:

```
set command $argv[1]
set -e argv[1]
```

Taken together, these two lines mean that we're creating a variable named `command` and setting its value equal to the value of `argv[1]`, and then we're deleting `argv[1]` itself.

## Executing the correct `rbenv` command

Next few lines of code:

```
switch "\$command"
  case ${commands[*]}
    rbenv "sh-\$command" \$argv|source
  case '*'
    command rbenv "\$command" \$argv
  end
end
```

To make this easier to read, let's first remove the escape characters from the code:

```
switch "$command"
  case ${commands[*]}
    rbenv "sh-$command" $argv|source
  case '*'
    command rbenv "$command" $argv
  end
end
```

This is **almost** correct, but it's not what we would see in `fish`.  Notice that the code `${commands[*]}` has a dollar sign, but it did **not** have an escape character.  That means `bash` will treat this as code, and will resolve it to a value before it gets `echo`'ed.

So what would it resolve to?  The easiest way to determine this is to simply print out the function definition.  But we haven't yet installed the `rbenv` shell integrations in our `fish` shell yet.  Let's do that first.

## Installing shell integrations in `fish`

In my `fish` shell, I type `rbenv init` to get the installation instructions that are printed out due to [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L73){:target="_blank" rel="noopener"}:

```
> rbenv init

# Load rbenv automatically by appending
# the following to ~/.config/fish/config.fish:

status --is-interactive; and rbenv init - fish | source
```

It tells me to copy the code `status --is-interactive; and rbenv init - fish | source` into the file `~/.config/fish/config.fish`.  So that's what I do.  I then open a new terminal tab and enter the `fish` shell again.

If I were in `bash`, I could print out the shell function by typing `which rbenv`.  I don't know what the equivalent of that is in `fish`, so I Google "print a shell function definition fish".  The first link I find is [this one](https://web.archive.org/web/20230320234416/https://fishshell.com/docs/current/cmds/functions.html){:target="_blank" rel="noopener"}:

<center>
  <a target="_blank" href="/assets/images/screenshot-10may2023-938am.png">
    <img src="/assets/images/screenshot-10may2023-938am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

In the `fish` shell, I type `functions rbenv`:

```
> functions rbenv

# Defined via `source`
function rbenv
  set command $argv[1]
  set -e argv[1]

  switch "$command"
  case rehash shell
    rbenv "sh-$command" $argv|source
  case '*'
    command rbenv "$command" $argv
  end
end
```

So by the time we get to defining the body of the `rbenv` shell function, the line `case ${commands[*]}` resolves to `case rehash shell`.  This maps to what we see if we type `rbenv commands --sh` directly in our terminal:

```
> rbenv commands --sh

rehash
shell
```

So the code we're **really** trying to read is:

```
  switch "$command"
  case rehash shell
    rbenv "sh-$command" $argv|source
  case '*'
    command rbenv "$command" $argv
  end
```

Much easier to read.

## Executing the user's command

So if the command that the user typed in was either `rehash` or `shell`, then we run:

```
rbenv "sh-$command" $argv|source
```

And if the user's command **wasn't** one of those two commands, we run:

```
command rbenv "$command" $argv
```

The first thing to notice is that we execute `shell` or `rehash` by calling `rbenv` directly, whereas we execute any other commands by calling `command rbenv`.  Let's recall our earlier coverage of the `command` command.  This command skips any shell functions, aliases, etc. and goes straight to `PATH` when searching for how to execute the program that it's given.

A quick proof of that is follows.  I define a function named `ls` in my terminall, which just prints `Hello world`.  Then I run the function as I would the `ls` utility:

```
$ ls() {
function> echo "Hello world"
function> }

$ ls ./
Hello world
```

When I preface `ls` with the `command` command, I get my normal `ls` behavior back:

```
$ command ls ./

404.html				_config.yml				cp_img					sales_letter.md
404.md					_data					feed.xml				script
CNAME					_includes				foo					start-here.md
Gemfile					_layouts				index.md				timestamped-archived-pages
Gemfile.lock				_sass					rbenv
Github commits to consider analyzing	_site					resources
README.md				assets					robots.txt
```

But back to our `case` statement.

The fact that we're using `command rbenv` in the `'*'` case tells us that we're explicitly trying to avoid the `rbenv` shell function.  And by extension, the fact that we're not using `command` in the first branch of the `case` must mean we're **not** trying to avoid that shell function.

In other words, in the first case, we want to call the `rbenv` shell function, **not** the version of `rbenv` which is in our `$PATH` (i.e. the `libexec/rbenv` file that we previously examined).  In the 2nd case, we want to call the `rbenv` file directly, bypassing the shell function.

I was wondering why this is the case, so I looked up the `git` history for this block of code.  I discovered [this PR from 2011](https://github.com/rbenv/rbenv/pull/57){:target="_blank" rel="noopener"}:

<center>
  <a target="_blank" href="/assets/images/screenshot-11may2023-918am.png">
    <img src="/assets/images/screenshot-11may2023-918am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The goal seems to be to allow shell-specific commands to set and/or modify environment variables in the current environment.  In the context of the `fish` shell, this is done by:

 - calling `rbenv "sh-$command" $argv` (which is just the code from [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L118){:target="_blank" rel="noopener"}, minus the escape characters), and then
 - piping the output from that command to the `source` command.

If we look at [the `fish` docs for the `source` command](https://web.archive.org/web/20230303210037/https://fishshell.com/docs/current/cmds/source.html){:target="_blank" rel="noopener"}, we can see:

<center>
  <a target="_blank" href="/assets/images/screenshot-11may2023-926am.png">
    <img src="/assets/images/screenshot-11may2023-926am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

> the commands will be evaluated by the current shell, which means that changes in shell variables will affect the current shell.

This sounds a lot like what the stated goal of the PR was.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

With that, we come to the end of the shell function definition for `fish`.  Next, we'll look at the shell function definitions for the remaining shells that RBENV supports.  These function definitions are largely identical, so we can cover them all in one post.
