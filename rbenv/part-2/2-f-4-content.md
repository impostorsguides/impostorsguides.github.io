

Next few lines of code:

```
if [ -z "$print" ]; then
  case "$shell" in
  ...
  esac
...
fi
```

Here we check whether our `$print` variable is empty.  If it is, then we run a case statement based on what shell we're using.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines:

```
  bash )
    if [ -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.bash_profile" ]; then
      profile='~/.bashrc'
    else
      profile='~/.bash_profile'
    fi
    ;;
```

If our shell is "bash", we run another "if/else" check.  We reach the "if" branch if the "~/.bashrc" file exists *and* if the "~/.bash_profile" file does NOT exist.  If this condition is true, we set a new "profile" variable equal to "~/.bashrc".  If it's false, we set it equal to "~/.bash_profile".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
  zsh )
    profile='~/.zshrc'
    ;;
```
If our shell is "zsh", we set the "profile" var equal to "~/.zshrc".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
  ksh )
    profile='~/.profile'
    ;;
```

Similar to the last "case" branch, but with "ksh" instead of "zsh".  Looks like the standard config file for "ksh" is located at "~/.profile" instead of zsh's "~/.zshrc".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
  fish )
    profile='~/.config/fish/config.fish'
    ;;
```
Same deal as before, but with the standard config file for the "fish" shell instead of "ksh".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next (and final) case branch:

```
  * )
    profile='your profile'
    ;;
```

The catch-all default is just the string "your profile".  We'll find out why the code sets "profile" equal to the human-readable string "your profile" in the next block of code.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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
Here we take everything inside the curly braces, and we send the output to STDERR.

The content of the data we send is a message telling the user what text to add to their shell configuration file (i.e. ~/.zshrc, ~/.profile, etc., depending on their shell).  Here we also see where that "your profile" string gets used.  If we run `rbenv init foobar` in the terminal, we see:

```
$ rbenv init foobar
# Load rbenv automatically by appending
# the following to your profile:

eval "$(rbenv init - foobar)"
```

Here we see that `the following to ${profile}:` evaluates to `the following to your profile:`.  In contrast, if we run `rbenv init zsh`, we see:

```
$ rbenv init zsh
# Load rbenv automatically by appending
# the following to ~/.zshrc:

eval "$(rbenv init - zsh)"
```

Here, that same string evaluates to `the following to ~/.zshrc:`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
