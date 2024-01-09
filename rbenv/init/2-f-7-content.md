Next block of code:

```
ksh )
  cat <<EOS
function rbenv {
```

## Declaring the `rbenv` function in `ksh`

This is the 2nd branch of our outer case statement (the one which checks which shell the user is using).  If the user is using the `ksh` shell (aka the Korn shell), we employ a similar strategy of starting to `cat` a function definition, but this time we don't close that definition (that comes later).

Note that the `function` keyword prior to the function name is optional in `bash` and `zsh`, but mandatory in `fish` and `ksh`.  One reason you might **not** want to use the `function` keyword in `bash` or `zsh` is portability.  According to [StackOverflow](https://unix.stackexchange.com/a/73752/142469){:target="_blank" rel="noopener"}, leaving the keyword off means your script will be more portable with older shells.

### Declaring a local variable in `ksh`

Next block of code:

```
  typeset command
EOS
  ;;
```

For now, we just declare a variable named `command`, which is scoped locally to the `rbenv` function according to [the Korn shell docs](https://web.archive.org/web/20161203165249/https://docstore.mik.ua/orelly/unix3/korn/ch06_05.htm){:target="_blank" rel="noopener"}:

> typeset without options has an important meaning: if a typeset statement is used inside a function definition, the variables involved all become local to that function (in addition to any properties they may take on as a result of typeset options).

In other words, here the `typeset` keyword is doing what the `local` keyword would do in `bash`.

## Declaring the `rbenv` function in other shells

Next lines of code:

```
* )
  cat <<EOS
rbenv() {
  local command
EOS
  ;;
```

This is the default, catch-all case for our "$shell" variable switch statement.  If the user's shell is not `fish` or `ksh`, then we `cat` our `rbenv` function definition, and (again) create a local variable named "command".

## Implementing the function body for all non-`fish` shells

Next block of code:

```
if [ "$shell" != "fish" ]; then
...
fi
```

The remaining code inside `rbenv-init` is only executed if the user's shell is *not* `fish`.  If their shell *is* `fish`, we've already finished `echo`ing their shell function definition, so there's nothing more to do.

Next lines of code:

```
IFS="|"
```

Here we set the `IFS` variable (which stands for "internal field separator") to the pipe symbol `|`.  [We've covered this before](https://web.archive.org/web/20220715010436/https://www.baeldung.com/linux/ifs-shell-variable){:target="_blank" rel="noopener"}, but `IFS` is a special shell variable that determines how bash separates a string of characters into multiple strings.  For example, let's say we have a string `a|b|c|d|e`.  If `IFS` is set to the pipe character (as above), and if we pass our single string to a `for` loop, then bash will internally split our string into 5 strings ('a', 'b', 'c', 'd', and 'e') and iterate over each of them.

We'll see why we needed to reset the value of `IFS` shortly.

## Printing the remaining function body

Next block of code:

```
cat <<EOS
...
EOS
```

The `cat << EOS` line of code starts a new heredoc, so that we can finish implementing our `rbenv` function.

## The function body itself

Next block of code:

```
  command="\${1:-}"
  if [ "\$#" -gt 0 ]; then
    shift
  fi

  case "\$command" in
  ${commands[*]})
    eval "\$(rbenv "sh-\$command" "\$@")";;
  *)
    command rbenv "\$command" "\$@";;
  esac
}
```

This is the rest of the file, and it's a lot of code.  It's basically everything in the shell function except for the function's initial declaration, and the declaration of the `command` local variable.

We'll break it up into more digestable pieces, but first, let's see what it looks like in the shell function itself, without the escape characters:

```
  command="${1:-}"
  if [ "$#" -gt 0 ]
  then
    shift
  fi
  case "$command" in
    (rehash | shell) eval "$(rbenv "sh-$command" "$@")" ;;
    (*) command rbenv "$command" "$@" ;;
  esac
}
```

I find the code easier to read without the escape characters.

### Storing the user's command

First line of the above is:

```
command="${1:-}"
```

Here we see some parameter expansion.  I feel like I may have seen the `:-` syntax before, but I don't remember what it does.  Referring to the GNU docs and searching for `:-`, I find the following:

<center>
  <a target="_blank" href="/assets/images/screenshot-13mar2023-854am.png">
    <img src="/assets/images/screenshot-13mar2023-854am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The docs go on to show multiple variations of the `:-` syntax, however all of them contain something after the hyphen character.  None of them end in `:-` the way that our code does.  We'll have to do some experiments to see for sure what this does.

#### Experiment- parameter expansion with `:-`

I write the following simple script:

```
#!/usr/bin/env bash

command="${1:-}"

echo "$command"
```

I `chmod` it and run it, both with and without arguments:

```
$ ./foo

$ ./foo bar baz buzz

bar
```

When I ran the command without any arguments, nothing printed out.  When I ran it with 3 arguments, only the first argument printed out.  So it looks like we did indeed capture the first argument.

For more context, I read [this StackExchange post](https://web.archive.org/web/20220531142657/https://unix.stackexchange.com/questions/338146/bash-defining-variables-with-var-number-default){:target="_blank" rel="noopener"}, which seems to say the same thing that the GNU docs said:

> The variables used in `${1:-8}` and `${2:-4}` are the positional parameters `$1` and `$2`. These hold the values passed to the script (or shell function) on the command line. If they are not set or empty, the variable substitutions you mention will use the default values `8` and `4` (respectively) instead.

What if we were to provide a default value after the `:-` syntax?  Would that work as we expect?  Let's modify the experiment accordingly, adding a default value of `foo` for the first argument:

```
#!/usr/bin/env bash

command="${1:-foo}"

echo "$command"
```

When we call the script, again both with and without arguments, we see:

```
$ ./foo

foo

$ ./foo bar baz buzz

bar
```

So the script continues to print the first argument if there is one, but if there isn't, it defaults the value to `foo`.  Cool!  That means our script populates the `command` variable with the first argument, but does not supply a default value of no argument is specified.

## Conditionally removing the first argument

Next lines of code:

```
  if [ "$#" -gt 0 ]
  then
    shift
  fi
```

If we recall, `$#` is shorthand for the number of arguments passed to the script.  So if the number of arguments is greater than zero, we shift the first one off of the argument stack.

## Handling the user's command

Next lines of code:

```
  case "$command" in
    (rehash | shell) eval "$(rbenv "sh-$command" "$@")" ;;
    (*) command rbenv "$command" "$@" ;;
  esac
```

This block of code is short and familiar enough that we can analyze it all at once.  Functionally, it's the same as the end of the `fish` shell function.  We create a `case` statement which branches depending on the value of the `command` that the user entered.

Recall that the value of the `commands` variable was set to:

```
commands=(`rbenv-commands --sh`)
```

Therefore, if the user's command is present in the return value of `rbenv-commands --sh` (i.e. if it's equal to either `rehash` or `shell`), then we re-run the *shell function* version of `rbenv`, but this time pre-pending `sh-` to it.

If the user's command was something *other than* `shell` or `rehash`, we use the `command` shell program to skip the `rbenv` function and go directly to the `rbenv` script inside `libexec`.  We pass as arguments the name of the command and any other arguments the user included.

Here we see why we needed to override `IFS`.  The output of `rbenv-commands --sh` is `rehash | shell`.  With `IFS` set to its default value, `bash` would only execute this branch of the case statement if the user entered the string `"rehash | shell"` as their "command".  With `IFS` set to `|`, this logic works as expected- we execute the `case` branch if the user's command was either `rehash` *or* `shell`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

And with that, we've reached the end of the `rbenv-init` file!
