The `completions/` directory stores scripts which are used to enable word completion in `bash` and `zsh` shells, respectively.  You can activate RBENV's completion logic by adding the proper shell integration command to your shell's config file.

In `bash`, that means adding the code `eval "$(rbenv init - bash)"`  to your `.bashrc` file.  In `zsh`, you'd add `eval "$(rbenv init - zsh)"` to your `.zshrc` file.  From there, `rbenv-init` will `source` the completion files via [this block of code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-init#L123-L126){:target="_blank" rel="noopener"}:

```
completion="${root}/completions/rbenv.${shell}"
if [ -r "$completion" ]; then
  printf "source '%s'\n" "$completion"
fi
```

What about the `fish` shell?  Per [the `fish` shell docs](https://web.archive.org/web/20230523204133/https://fishshell.com/docs/current/completions.html){:target="_blank" rel="noopener"}:

> Fish automatically searches through any directories in the list variable `$fish_complete_path`, and any completions defined are automatically loaded when needed.

In other words, `fish` automatically supports certain word completions out-of-the-box, by searching for executables in certain pre-defined directories.

## Why are completions useful?

Completions are pretty handy if you're searching for a certain command.  For example, in your command line, type `rbenv` and hit the `tab` key.  When I do so, I get the following:

```
$ rbenv

--version           global              install             root                version             version-name        which
commands            help                local               shell               version-file        version-origin
completions         hooks               prefix              shims               version-file-read   versions
exec                init                rehash              uninstall           version-file-write  whence
```

These are all the commands that `rbenv` exposes.  If I type `rbenv r` and hit `tab`, I see all the commands which start with `r`:

```
$ rbenv r

rehash  root
```

That's completions in a nutshell.  There are two files in the `completions/` directory:

- `rbenv.zsh`, and
- `rbenv.bash`.

Let's inspect the files in that order.

## `rbenv.zsh`

The code for `rbenv.zsh` looks like so:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

As usual, we'll break it up into sections.

### Checking whether an option is on

The first 3 lines of code are:

```
if [[ ! -o interactive ]]; then
  return
fi
```

What does `-o` do?  The `man test` page references an `-o` flag, but it's actually a different flag, i.e. `expression1 -o expression2` is true if *either* `expression1` or `expression2` is true.  We don't have 2 expressions in our case, so we have to search elsewhere for an answer.

[StackOverflow comes to the rescue](https://web.archive.org/web/20230408143552/https://stackoverflow.com/questions/5897760/what-does-flags-o-and-l-means-in-bash){:target="_blank" rel="noopener"}:

```
-o : True if shell option "OPTIONNAME" is enabled.
```

Let's test the `-o` flag with an experiment.

#### Experiment- the `test` command's `-o` flag

I run the following in my terminal:

```
$ set +o verbose
$ [[ -o verbose ]] && echo "TRUE"

```

In the above code, we use `set +o verbose` to turn the `verbose` option **off**.  The result is that `TRUE` was **not** printed to the screen.

Next, we'll use `set -o verbose` to turn the same option **on**:

```
$ set -o verbose
$ [[ -o verbose ]] && echo "TRUE"
[[ -o verbose ]] && echo "TRUE"
TRUE
```

When we turn on the `verbose` option and run our test, we see the test itself (because `verbose` mode means any executed commands will also be printed to the screen), followed by the string `TRUE` that we expected to see.

### The `interactive` option

So we're testing whether a certain option is on, namely the `interactive` option.  What is the 'interactive' option, you ask?  [The Linux Documentation Project](https://web.archive.org/web/20230529202612/https://tldp.org/LDP/abs/html/intandnonint.html){:target="_blank" rel="noopener"} give us an answer:

> An **interactive** shell reads commands from user input on a `tty`. Among other things, such a shell reads startup files on activation, displays a prompt, and enables job control by default. The user can **interact** with the shell.
>
> A shell running a script is always a non-interactive shell.

And StackOverflow [fills in some of the gaps](https://web.archive.org/web/20220423122639/https://unix.stackexchange.com/questions/50665/what-is-the-difference-between-interactive-shells-login-shells-non-login-shell){:target="_blank" rel="noopener"} in the above answer:

> Interactive: As the term implies: Interactive means that the commands are run with user-interaction from keyboard. E.g. the shell can prompt the user to enter input.
>
> Non-interactive: the shell is probably run from an automated process so it can't assume it can request input or that someone will see the output. E.g., maybe it is best to write output to a log file.

So we're checking whether we're interacting with the user or with a shell script.  If we're not interacting with a user, we exit out of the `rbenv.zsh` script via the `return` keyword.

### Adding completions to the `rbenv` command with the `compctl` keyword

Next line of code is:

```
compctl -K _rbenv rbenv
```

`compctl` is a `zsh` builtin, so we'll need to use the `help` command to view its docs:

```
ZSHCOMPCTL(1)       General Commands Manual         ZSHCOMPCTL(1)

NAME
  zshcompctl - zsh programmable completion

DESCRIPTION

Control the editor's completion behavior according to the supplied set of options...

...

-K function
    Call the given function to get the completions.  Unless the name starts with an
    underscore, the function is passed two arguments: the prefix and the suffix of
    the word on which completion is to be attempted, in other words those characters
    before the cursor position, and those from the cursor position onwards.  The
    whole command line can be accessed with the -c and -l flags of the read builtin.
    The function should set the variable reply to an array containing the completions
    (one completion per element); note that reply should not be made local to the
    function.
```

In summary, `compctl -K` tells the shell that, when trying to autocomplete `rbenv` in the terminal, we first call the `_rbenv` shell function.  That function will set the value of a `reply` shell variable equal to an array of... something (we'll dig into that next).  The instructions explicitly tell us **not** to use the `local` keyword on the `reply` variable.  This way, it will be available outside the `_rbenv` shell function, after it has been set.

### Declaring the `_rbenv` helper function

Next block of code is:

```
_rbenv() {
  local words completions
  read -cA words
```

We declare the `_rbenv` function.  The implementation starts with the declaration of two local variables- `words` and `completions`.

Next we use the `read` command (which we learned about [when discussing the `rbenv versions` command](/rbenv/commands/versions){:target="_blank" rel="noopener"}) to populate the `words` variable.

Checking the `help` page for the `-c` and `-A` flags for `read`, we see:

```
-c
-l    These flags are allowed only if called inside a function
      used for completion (specified with the -K flag to compctl).
      If the -c flag is given, the words of the current command
      are read.

-A    The first name is taken as the name of an array and all
      words are assigned to it.
```

We read all the words of the command, and store them in an array variable, which in this case is named `words`.

Let's try this for ourselves with an experiment.

#### Experiment- building our own word completion for a new command

I make a file called `foobar` in my current directory, containing the following:

```
#!/usr/bin/env bash

echo "Hello"
echo "args:"

echo "$@"
```

It just prints out a few static strings, followed by the arguments it receives.

Then I make another file (also in my current directory) named `_foobar`:

```
#!/usr/bin/env bash

function _foobar {
  reply=(foo bar baz);
}

compctl -K _foobar foobar
```

Note that I didn't try to use the `read` command with the `-cA` flags here.  We'll do that further down, in a separate experiment.

I load `_foobar` into memory via `source _foobar`:

```
$ source _foobar
```

Then, when I type `./foobar ` in my terminal (with a space at the end) and hit the tab key, the3 words in my `reply` array automatically appear:

```
$ ./foobar

bar  baz  foo
```

When I hit `tab` again, the terminal auto-completes with the first option in the list:

```
$ ./foobar bar

bar  baz  foo
```

And when I hit `Enter`, my `./foobar` command works as expected:

```
$ ./foobar bar

Hello
args:
bar
```

Let's move on to the next line of code.

### Checking the length of the commands in the terminal

```
  if [ "${#words}" -eq 2 ]; then
```

Referring back to [the docs for parameter expansion](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"} we see that a `#` before a variable name inside the curly braces resolves to the length of the variable, like so:

```
$ foo="foo bar"
$ echo "${#foo}"
7
```

We see `7` because the string `foo bar` has 7 characters in it.

And if we pass an array instead of a string, we get the number of items in the array:

```
$ foo=(bar baz)
$ echo "${#foo}"
2
```

Therefore, our line of code:

```
if [ "${#words}" -eq 2 ]; then
```

...says "If the length of `words` is equal to 2, then execute the code inside the `if` block".

### If the user tab-completes with just `rbenv` in the terminal

Next line of code is:

```
completions="$(rbenv commands)"
```

We set the value of a variable named `completions` equal to the return value of `rbenv commands`, using command substitution.

Does it store the contents as a string, or as an array?

For what it's worth, we don't *really* need to know the answer to this question.  After all, we're not checking the length of the `completions` variable like we do with the `words` variable.  I'm mostly just curious, and I find it helpful to know what data types I'm working with in my variables.

To answer this, I need to know how to print a variable's type in the terminal.  StackOverflow [has the answer](https://web.archive.org/web/20220714213343/https://unix.stackexchange.com/questions/269825/how-can-i-get-a-variables-datatype-in-zsh){:target="_blank" rel="noopener"}:

> You can use `t` parameter expansion flag:
>
> ```
$ print -rl -- ${(t)fpath}
array-special
$ a=1
$ print -rl -- ${(t)a}
scalar
$ a=(1 2)
$ print -rl -- ${(t)a}
array
$ typeset -A a
$ print -rl -- ${(t)a}
association
>```
>
> Note that you can't distinguish between array of integers or array of strings.

Looks like I need to use parameter expansion, coupled with `(t)` before the variable name.

With that in mind, a quick experiment.

#### Experiment- checking the type of a variable with `(t)`

```
# sanity check to make sure we get 'array' as expected

$ foo=(1 2 3)
$ echo "${(t)foo}"
array

# now the actual experiment

$ foo="$(rbenv commands)"
$ echo "${(t)foo}"
scalar
```

Great, so we're storing the output of `rbenv commands` as a single string, not as an array of strings.

### Why are we checking for a length of 2?

At this point, I'm wondering why `2` is the magic number that we're checking against the length of `words`.  Why not 1, or 3?

I edit the `rbenv.zsh` file to include the following 4 `echo` statements after `read -cA words`:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  echo                              # this line is new
  echo "inside _rbenv"              # this line is new
  echo "words: $words"              # this line is new
  echo "words.length: ${#words}"    # this line is new

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

In order for the updated completion file to take effect in `zsh`, I have to re-run `rbenv init`:

```
$ eval "$(rbenv init - zsh)"
```

Then when I type `rbenv` plus a space and hit `tab`, I see:

```
$ rbenv
inside _rbenv
words: rbenv
words.length: 2
                                                           rbenv
--version           global              install             root                version             version-name        which
commands            help                local               shell               version-file        version-origin
completions         hooks               prefix              shims               version-file-read   versions
exec                init                rehash              uninstall           version-file-write  whence
```

So the length of `words` is 2 when the user just types `rbenv` and a space afterward.  This represents the string `rbenv` plus an empty string after the space character.  We can prove this to ourselves by printing each element in `words`.

I update the completion file to add the following `for` loop below my previous `echo` statements:

```
for word in "$words[@]";
do
  echo "word: $word"
  echo "word type: ${(t)word}"
  echo "word length: ${#word}"
  echo "---"
done
```

We've seen the `[@]` syntax before; its function is to tell the `for` loop that the value of `$words` is an array, so you can iterate over it.

When I type `rbenv foo bar` and hit tab, I see:

```
$ rbenv foo bar baz
inside _rbenv
words: rbenv foo bar baz
words.length: 5
rbenv
foo
bar
baz

word: rbenv
word type: scalar
word length: 5
---
word: foo
word type: scalar
word length: 3
---
word: bar
word type: scalar
word length: 3
---
word: baz
word type: scalar
word length: 3
---
word:
word type: scalar
word length: 0
---
```

The last iteration of the `for` loop shows up as:

```
word:
word type: scalar
word length: 0
```

It's got a length of zero, and it's a scalar type so it must be either a string or an integer.  Integers can't have a length of 0, so it must be a string.

Before moving on, I make sure to delete all the `echo` statements from `rbenv.zsh`, and re-run the `eval "$(rbenv init - zsh)"` command to reset my word completions.

### If the user asked for completions for a sub-command

Next line of code:

```
else
  completions="$(rbenv completions ${words[2,-2]})"
fi
```

Again, we're storing a value in the `completions` local variable, but it's a new value now, i.e. the result of the `rbenv completions` command, plus the value of `${words[2, -2]}`.  Let's start by checking what that value is.

Recall from the earlier `echo` attempts that `words` was equal to an array of `rbenv`, `foo`, `bar`, `baz`, and the empty string `""`.  If we make a new array named `words` in our terminal, we can inspect it using the `${words[2, -2]}` syntax:

```
$ words=(rbenv foo bar baz "")

~/Workspace/OpenSource/impostorsguides.github.io (main)  $ echo "$words[2, -2]"

foo bar baz
```

So `${words[2, -2]}` takes the values in the array starting with the 2nd item (skipping `rbenv`), and ending at the 2nd-to-last item (skipping the empty string).

For example, if I type `rbenv local `, we'd reach the `else` block of our code, and the `completions` variable would be set to the output of `rbenv completions local`.  On my machine, that is:

```
$ rbenv completions local

--help
--unset
system
2.7.5
3.0.0
```

In other words, the above 5 strings, joined with newlines into a single string.

#### 1-based arrays in `zsh`

Observant readers will notice that the way to access the 2nd element in the `words` array was with the syntax `[2,...]`, **not** `[1,...]`.  [As StackOverflow notes](https://web.archive.org/web/20220714213343/https://unix.stackexchange.com/questions/269825/how-can-i-get-a-variables-datatype-in-zsh){:target="_blank" rel="noopener"}, array positioning in `zsh` is 1-based:

```
$ echo "$words[0]"

$ echo "$words[1]"
rbenv
$ echo "$words[2]"
foo
```

This is different from the 0-based indexing you may have encountered in other languages, such as Ruby:

```
irb(main):001:0> foo = [1,2,3]
=> [1, 2, 3]
irb(main):002:0> foo[0]
=> 1
irb(main):003:0> foo[1]
=> 2
irb(main):004:0> foo[2]
=> 3
```

This is something to watch out for when working with arrays in `zsh`.

### Storing the completions in `reply`

The last line of code in the file is:

```
reply=("${(ps:\n:)completions}")
```

Clearly we're setting a (non-local) variable named `reply` equal to `("${(ps:\n:)completions}")`.  What does this evaluate to?

The `(ps:\n:)` syntax at the start of the parameter expansion looks similar to the `(t)` syntax that we encountered earlier.  If we search for `ps:\n` on [the docs page](https://web.archive.org/web/20230320043037/https://zsh.sourceforge.io/Doc/Release/Expansion.html){:target="_blank" rel="noopener"}, we see the following:

> f
>
> Split the result of the expansion at newlines. This is a shorthand for 'ps:\n:'.

So the syntax in question takes a string containing one or more newlines, and uses those newlines as a delimiter to split the string into an array.

As a test, I run the following code in my `zsh` shell:

```
foo="foo\nbar\nbaz\nbuzz"
bar=("${(ps:\n:)foo}")
echo "$bar"
echo "${(t)bar}"
```

I see the following output:

```
$ foo="foo\nbar\nbaz\nbuzz"

$ bar=("${(ps:\n:)foo}")

$ echo "$bar"

foo
bar
baz
buzz

$ echo "${(t)bar}"

array
```

Looks good to me!

In summary, the line of code...

```
reply=("${(ps:\n:)completions}")
```

...splits the output generated from either the `if` or `else` block using the newline `\n` character as a delimiter, and then sets the `reply` variable equal to that array.

### Summary

To summary `rbenv.zsh`:

 - If we're not running in interactive mode (i.e. if the input is coming from the computer, as opposed to from the user), we exit the script.
 - Otherwise, we create a completion function named `_rbenv` and use the `compctl -K` command to tell the computer to use this function to generate completion options for the `rbenv` command.
 - This function reads the input from standard input, which `zsh` feeds it when tab completion is attempted.
    - If the length of this input indicates that the user hit `tab` after entering only `rbenv`, then `zsh` uses the output of `rbenv commands` as the possible tab completions.
    - If the length of this input indicates that the user hit tab after entering `rbenv` plus a sub-command (such as `rbenv version` or `rbenv local`), then `zsh` uses the output of `rbenv completions` plus the list of sub-commands the user entered (i.e. the output of `rbenv completions version` or `rbenv completions local`).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on to the `rbenv.bash` file.

## `rbenv.bash`

The entire file looks like this:

```
_rbenv() {
  COMPREPLY=()
  local word="${COMP_WORDS[COMP_CWORD]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(rbenv commands)" -- "$word") )
  else
    local words=("${COMP_WORDS[@]}")
    unset "words[0]"
    unset "words[$COMP_CWORD]"
    local completions=$(rbenv completions "${words[@]}")
    COMPREPLY=( $(compgen -W "$completions" -- "$word") )
  fi
}

complete -F _rbenv rbenv
```

Let's break this down.

### Declaring the function

```
_rbenv() {
  ...
}
```

We declare the `_rbenv()` function.  In this case, the syntax is exactly the same in `bash` as it is in `zsh`.

### Initializing our list of completions

Next line:

```
COMPREPLY=()
```

Here we initialize a variable called `COMPREPLY`, giving it the initial value of an empty array.  [According to the `bash` docs](https://www.gnu.org/software/bash/manual/bash.html#Programmable-Completion){:target="_blank" rel="noopener"}, `COMPREPLY` functions similarly to the `reply` variable in `zsh`:

> `COMPREPLY`
>
> An array variable from which Bash reads the possible completions generated by a shell function invoked by the programmable completion facility... Each array element contains one possible completion.

So we can assume that we'll be adding more entries into the `COMPREPLY` array, and that once our function is finished executing, `bash` will use the final value of `COMPREPLY` to populate the completions that we see in our terminal.

### Checking the current word (for which the user wants completions)

Next line:

```
local word="${COMP_WORDS[COMP_CWORD]}"
```

Again according to [the docs](https://www.gnu.org/software/bash/manual/bash.html#Programmable-Completion){:target="_blank" rel="noopener"} for `COMP_CWORD`:

> COMP_CWORD
>
> An index into ${COMP_WORDS} of the word containing the current cursor position. This variable is available only in shell functions invoked by the programmable completion facilities...

Furthermore, the docs go on to describe `COMP_WORDS` as well:

> COMP_WORDS
>
> An array variable consisting of the individual words in the current command line.

We can verify what the docs tell us with an experiment.

#### Experiment- verifying the value of `COMP_CWORD`

I make the following script, called `foo`:

```
#!/usr/bin/env bash

_foobar() {
  echo
  echo "COMP_CWORD: ${COMP_CWORD}"
  echo "COMP_WORDS: ${COMP_WORDS[@]}"
  echo "0th word: ${COMP_WORDS[0]}"
  echo "1st word: ${COMP_WORDS[1]}"
  echo "2nd word: ${COMP_WORDS[2]}"
  echo "3rd word: ${COMP_WORDS[3]}"
  echo "4th word: ${COMP_WORDS[4]}"
}

complete -F _foobar foo
```

It prints the following:

- a newline (so that the completion output is not mixed-up with the command I typed)
- the value of `COMP_CWORD`
- the value of `COMP_WORDS` (which I happen to know is an array, hence the `[@]` syntax at the end)
- the 0th through the 4th items stored in `COMP_WORDS`

I then type `source ./foo` in my terminal, followed by `./foo` plus 2 arguments and a space, and I hit `tab`:

```
bash-3.2$ ./foo bar baz

COMP_CWORD: 3
COMP_WORDS: ./foo bar baz
0th word: ./foo
1st word: bar
2nd word: baz
3rd word:
4th word:
```

When I cancel out of this and re-type the command with 3 arguments and a space, I see the following:

```
bash-3.2$ ./foo bar baz buzz
COMP_CWORD: 4
COMP_WORDS: ./foo bar baz buzz
0th word: ./foo
1st word: bar
2nd word: baz
3rd word: buzz
4th word:
```

Lastly, I cancel out and re-type the command, but this time I leave off the space at the end:

```
bash-3.2$ ./foo bar baz buzz
COMP_CWORD: 3
COMP_WORDS: ./foo bar baz buzz
0th word: ./foo
1st word: bar
2nd word: baz
3rd word: buzz
4th word:
```

From the above experiment, we learn the following:

- `COMP_CWORD` prints the index of the word that the user is currently typing at the terminal prompt.
- It uses the space character as a delimiter to determine this index.
- `COMP_WORDS` is the array of words that the user has typed so far.
- The current word's text can be derived by indexing into `COMP_WORDS`, using `COMP_CWORD` as the index.

The final point above is what we're doing on the current line of code- grabbing the value of `COMP_WORDS` at index `COMP_CWORD`, and storing it in the local variable `word`.

### If the user wants completions for the main `rbenv` command

Next block of code:

```
if [ "$COMP_CWORD" -eq 1 ]; then
```

If the value of `COMP_CWORD` is `1`, that means the user has typed the following in their terminal, and hit the `tab` key:

```
bash-3.2$ rbenv
```

In this case, the user is asking for tab completions for the `rbenv` command, **not** for one of its sub-commands.  To generate those tab completions, we execute the code on the next line of code.

### Storing the output of `rbenv commands` as the completion result

Next line:

```
COMPREPLY=( $(compgen -W "$(rbenv commands)" -- "$word") )
```

Here we assign a new value to our (currently empty) `COMPREPLY` array.

#### The `compgen` command

The first thing we see is that, inside the `COMPREPLY=( ... )` array assignment, we invoke command substitution with the `compgen` command.  This is a `bash` builtin, and the `help` docs for this command state:

```
compgen: compgen [-abcdefgjksuv] [-o option] [-A action] [-G globpat] [-W wordlist] [-P prefix] [-S suffix] [-X filterpat] [-F function] [-C command] [word]
    Display the possible completions depending on the options.  Intended
    to be used from within a shell function generating possible completions.
    If the optional WORD argument is supplied, matches against WORD are
    generated.
```

From this, we see the following:

 - The `compgen` command is used to display possible completions.
 - The `-W` flag that we've passed is followed by a "wordlist", or a list of words to match against
 - The `word` argument is a comparator word which we'll use to narrow down the words in our list of words

For example, if we run the following:

```
bash-3.2$ compgen -W "foo foobar bar baz" -- foo
```

Our `wordlist` is `"foo foobar bar baz"`, and our comparator word is `foo`.  From this, we would expect `foo` and `foobar` to match the comparator.  And we'd be right- when we run this, we get:

```
bash-3.2$ compgen -W "foo foobar bar baz" -- foo

foo
foobar
```

What does this mean for RBENV?  Instead of `"foo foobar bar baz"`, our `wordlist` is the output of the `rbenv commands` command.  On my machine, that resolves to:

 ```
 bash-3.2$ rbenv commands

--version
commands
completions
exec
global
help
hooks
init
install
local
prefix
rehash
root
shell
shims
uninstall
version
version-file
version-file-read
version-file-write
version-name
version-origin
versions
whence
which
```

And if we're inside the `if` block, the value of `word` will be whatever RBENV command we've supplied.  For example, if we've attempted tab completion after typing `rbenv version`, then `word` will equal `version`.  When I `echo` the `word` variable, type `rbenv version` with no spaces, and hit `tab` once, I see:

```
bash-3.2$ rbenv version
word: version
```

If I hit `tab` a 2nd time, I see:

```
bash-3.2$ rbenv version
word: version

word: version

version             version-file        version-file-read   version-file-write  version-name        version-origin      versions
```

We can see that all the possible commands which were output (i.e. `version`, `version-file`, `version-file-read`, `versions`, etc.) match the string `version`.  Why do we see the contents of `COMPREPLY` printed with two tabs, but not with one?

TODO- what's the difference between one tab and two tabs, in terms of bash completion?

### If the user wants completions for a sub-command of `rbenv`

Next block of code:

```
else
  local words=("${COMP_WORDS[@]}")
  unset "words[0]"
  unset "words[$COMP_CWORD]"
  local completions=$(rbenv completions "${words[@]}")
  COMPREPLY=( $(compgen -W "$completions" -- "$word") )
fi
```

If the index of the current word is greater than 1, that means the user is attempting tab completions for more than one word.  In other words, they've typed `rbenv` **plus** a sub-command.  In that case, our earlier `if` conditional (`if [ "$COMP_CWORD" -eq 1 ]; then`) would return false, and we would drop into the above `else` block.

Here, we do the following:

 - Create a local variable named `words`, and store the entire contents of the `COMP_WORDS` array (i.e. all the words the user typed into the terminal).
 - Remove the first word (i.e. `rbenv`) and the last word (i.e. the empty string) from our new `words` array.
 - Create a new local variable named `completions`, with contents equal to the output of `rbenv completions` plus all the words in our newly-truncated `words` array.
    - For example, if we type `rbenv local` plus a space, and then hit `tab`, then `words` will equal `local`.
    - Therefore, the contents of our `completions` variable is equal to the output of `rbenv completions local`.
    - On my machine, that evaluates to:
    ```
    --help
    --unset
    system
    2.7.5
    3.0.0
    ```
 - We call `compgen -W`, passing that list of completions as our output and narrowing it down to those that match the last word
