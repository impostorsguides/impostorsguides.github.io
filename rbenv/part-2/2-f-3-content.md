Next block of code:

```
print=""
no_rehash=""
for args in "$@"
do
...
done
```
Pretty straightforward.  We're declaring two variables (`print` and `no_rehash`), setting them to empty strings, then iterating over each arg in the list of args sent to `rbenv init`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines:

```
  if [ "$args" = "-" ]; then
    print=1
    shift
  fi

  if [ "$args" = "--no-rehash" ]; then
    no_rehash=1
    shift
  fi
```
I bit off a fairly big block here, but it's pretty straightforward.  For each of the args, we check whether the arg is equal to either the "-" string or the "--no-rehash" string.  If the first condition is true, we set the "print" variable equal to 1.  If the 2nd condition is true, we set the "no_rehash" variable equal to 1.  Otherwise, they remain empty strings.  These variables will likely be used later in the file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next lines of code:

```
shell="$1"
if [ -z "$shell" ]; then
  shell="$(ps -p "$PPID" -o 'args=' 2>/dev/null || true)"
  shell="${shell%% *}"
  shell="${shell##-}"
  shell="${shell:-$SHELL}"
  shell="${shell##*/}"
  shell="${shell%%-*}"
fi
```

Here we grab the new 1st argument (due to the `shift` calls in the previous `for` loop), and store it in a variable named `shell`.  If that argument was empty, then we attempt to set it to the return value of a certain terminal command.  That command is `ps -p "$PPID" -o 'args='`.  We then progressively whittle down the value of this output, until we get to just the name of the user's shell.

To see in detail what happens here, I add a bunch of `echo` statements to this line of code:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-756am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I open a new tab, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-757am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So the whole purpose of this series of parameter expansions is just to store a string like "zsh" (or "bash" or "fish" or whatever the user's shell happens to be).  Again, to be used later, presumably.

Let's remove the tracers we just added, and move on to the next line of code:

```
root="${0%/*}/.."
```
`$0` in a bash script resolves to the name of the file that's being run.  Therefore, so does `${0}`.  Adding `%/*` just trims off everything from the final `/` character to the end of the string.  If we echo `${0%/*}` tot the console (along with the value of `$root`, for completeness) and open a new terminal tab, we get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-758am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-759am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

As expected, we see the parent dir of the `rbenv-init` file, and the value of `$root`.  The name "root" makes sense, because it's the root directory of RBENV.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
