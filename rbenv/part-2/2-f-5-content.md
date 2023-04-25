Next line of code is:

```
mkdir -p "${RBENV_ROOT}/"{shims,versions}
```

Here we make two sub-directories inside "$RBENV_ROOT"- one named "shims" and one named "versions".  No big deal.

Next line of code:

```
case "$shell" in
 ...
esac
```

Here we have a simple case statement, which branches based on the value of our "$shell" string.

Next lines of code:

```
fish )
  echo "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
  echo "set -gx RBENV_SHELL $shell"
;;
```

The first case branch is if our shell is "fish".  If it is, we `echo` a few commands to the script which calls `eval` on `rbenv init`.

Both these commands use the "fish" shell's "set" command to set shell variables.  More info [here](https://fishshell.com/docs/current/cmds/set.html){:target="_blank" rel="noopener"}.  The "-g" flag makes the variable global, and the `-x` flag makes the variable available to child processes.  We're creating two such variables here: `PATH` and `RBENV_SHELL`.  Well, technically, we're *creating* one variable (`RBENV_SHELL`) and *resetting* another (`PATH`).  The latter already existed in our terminal; we're just pre-pending it with `${RBENV_ROOT}/shims'` so that the shims which RBENV creates will be findable by our terminal.

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-806am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Next lines of code:

```
* )
  echo 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
  echo "export RBENV_SHELL=$shell"

  completion="${root}/completions/rbenv.${shell}"
  if [ -r "$completion" ]; then
    echo "source '$completion'"
  fi
;;
```

The first two lines of code do exactly what the two lines in the "fish" case branch do, just with regular bash syntax instead of fish syntax.

The next line of code creates a file path where the user's completion file should live, assuming the user is using a shell program that RBENV has a completions file for.  It only has two for now- "bash" and "zsh", as we saw in our sojourn into the "/completions" directory.  After the filepath is created, the "if" block checks whether that file actually exists and is readable:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-807am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

If it does exist, we run `source` on that file in order to run its contents.

Next lines of code:

```
if [ -z "$no_rehash" ]; then
  echo 'command rbenv rehash 2>/dev/null'
fi
```
If "$no_rehash" was not set (i.e. if the user did NOT pass "--no-rehash" as an argument), then we run "rbenv command rehash" and send any errors to /dev/null.  We don't yet know what the "rbenv rehash" command does; we'll get to that when we cover the "libexec/rbenv-rehash" file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
