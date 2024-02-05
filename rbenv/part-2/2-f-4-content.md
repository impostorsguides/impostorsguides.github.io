Next few lines of code:

```
if [ -z "$print" ]; then
fi
```

Here we check whether our `$print` variable is empty.  If it is, then we print a series of instructions which tell the user which config file to add shell completions to, and what code to add to that file.  The code for constructing those instructions and code is below.

## Identifying the User's Shell Config File

The first block of code inside the `if` statement is:

```
case "$shell" in
  bash )
    if [ -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.bash_profile" ]; then
      profile='~/.bashrc'
    else
      profile='~/.bash_profile'
    fi
    ;;
  zsh )
    profile='~/.zshrc'
    ;;
  ksh )
    profile='~/.profile'
    ;;
  fish )
    profile='~/.config/fish/config.fish'
    ;;
  * )
    profile='your profile'
    ;;
  esac
```

This `case` statement is pretty long, but it actually doesn't do much.  Its only job is to check the `"$shell"` variable that we set earlier, and set a variable named `profile` depending on what the user's shell is.

The value we set for `profile` is a path to the user's shell configuration file, or the string `"your profile"` if none of the 4 supported shells were detected.

3 of the 4 shells (`zsh`, `ksh`, and `fish`) are straightforward- we directly set `profile` to a hard-coded filepath.

The case statement for Bash, however, is marginally more complex:

```
bash )
  if [ -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.bash_profile" ]; then
    profile='~/.bashrc'
  else
    profile='~/.bash_profile'
  fi
  ;;
```

If our shell is "bash", we run another `if/else` check.  We first check whether the `~/.bashrc` corresponds to an existing file:

```
[ -f "${HOME}/.bashrc" ]
```

If that file exists, we then check whether `~/.bash_profile` does **not** correspond to an existing file.  If this condition is true, we set the `profile` variable equal to `~/.bashrc`.

If either of these tests are false, we set `profile` equal to `~/.bash_profile`.

The catch-all, default case branch:

```
  * )
    profile='your profile'
    ;;
```

This just sets `profile` equal to the string `"your profile"`.  We'll find out why it does this in the next block of code.

## Printing The Instructions

Next lines of code:

```
{ echo "# Load rbenv automatically by appending"
  echo "# the following to ${profile}:"
  echo
  case "$shell" in
  fish )
    echo 'status --is-interactive; and rbenv init - fish | source'
    ;;
  * )
    printf 'eval "$(rbenv init - %s)"\n' "$shell"
    ;;
  esac
  echo
} >&2
```
Here we take everything inside the curly braces, and we send the output to `stderr`.

The content of the data we send is a message telling the user what code to add to their shell configuration file (i.e. `~/.zshrc`, `~/.profile`, etc., depending on their shell).

If we call `rbenv init` and specify `fish` as our shell, we see:

```
$ rbenv init fish

# Load rbenv automatically by appending
# the following to ~/.config/fish/config.fish:

status --is-interactive; and rbenv init - fish | source
```

We see that `profile` evaluates to `~/.config/fish/config.fish`, as we expected from the hard-coded value in our earlier `case` statement.

If we specify Bash, we see:

```
$ rbenv init bash
# Load rbenv automatically by appending
# the following to ~/.bash_profile:

eval "$(rbenv init - bash)"
```

Specifying `zsh` results in:

```
$ rbenv init zsh
# Load rbenv automatically by appending
# the following to ~/.zshrc:

eval "$(rbenv init - zsh)"
```

When the user specifies a shell other than one that RBENV supports, the string `the following to ${profile}:` evaluates to `the following to your profile:`:

```
$ rbenv init foobar

# Load rbenv automatically by appending
# the following to your profile:

eval "$(rbenv init - foobar)"
```

## The `printf` command

We saw that the `eval` command is almost identical for the output of `rbenv init bash` and `rbenv init zsh`.  The only difference is that the name of the shell has changed.  That's because we dynamically interpolated the value of `"$shell"` into the string, using the `printf` command:

```
printf 'eval "$(rbenv init - %s)"\n' "$shell"
```

Running `man printf` in the terminal returns the following:

```
PRINTF(1)                                                            General Commands Manual                                                           PRINTF(1)

NAME
     printf – formatted output

SYNOPSIS
     printf format [arguments ...]

DESCRIPTION
     The printf utility formats and prints its arguments, after the first, under control of the format.  The format is a character string which contains three
     types of objects: plain characters, which are simply copied to standard output, character escape sequences which are converted and copied to the standard
     output, and format specifications, each of which causes printing of the next successive argument.

     The arguments after the first are treated as strings if the corresponding format is either c, b or s...
```

The above `man` entry is saying that the first argument to `printf` is the *format* you want your output to take, and the remaining argument(s) are passed to that format string.

In our code:

 - The string `'eval "$(rbenv init - %s)"\n'` is the *format*, and
 - The value of the `"$shell"` variable is the one and only *argument*.

In our format argument, we substitute the `%s` syntax means with the value of `"$shell"` variable.  This passing in of one string to another is called "string interpolation".

The `s` in `%s` just means that we'll be passing in a string.  We can also tell `printf` to expect numbers:

```
$ printf "There are %d orders valued at over %d euros.\n" 64 1500

There are 64 orders valued at over 1500 euros.
```

It can even convert hexadecimal numbers for us:

```
$ printf "0xf as a human-readable number is %d.\n" 0xF

0xf as a human-readable number is 15.
```

## Exiting early

The last line of code inside the `if` block is just an exit statement:

```
  ...
  exit 1
fi
```

The non-zero exit code tells us that running `rbenv init` without `-` (which is how we ended up inside the `if`-block) is a sad-path case.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on.
