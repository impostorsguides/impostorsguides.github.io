There's just one more file we have to examine before we can call it a day on the "libexec/" folder.  I see the "test/" directory has its own folder named "libexec", containing a command named `rbenv-echo`.  I `grep` for the usage of this command, and I only see one case, inside [the `rbenv.bats` spec file](https://github.com/rbenv/rbenv/blob/ed1a3a554585799cd0537c6a5678f6c793145b8e/test/rbenv.bats).  Let's look at the `rbenv-echo` command now.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/libexec/rbenv-echo)

```
#!/usr/bin/env bash
# Usage: rbenv echo [-F<char>] VAR

if [[ $1 == -F* ]]; then
  sep="${1:2}"
  echo "${!2}" | tr "${sep:-:}" $'\n'
else
  echo "${!1}"
fi
```

We have the `bash` shebang and "Usage" comments.

Then we have an `if` conditional, which checks whether the command's first argument starts with "-F".  If it does, then we create a variable named "sep".  Not sure what "sep" refers to; the command we're currently examining appears to be strictly utilitarian in nature (it's only called from within one specific test file), so it's not meant for public consumption and therefore the core team probably felt like they could skimp on readability a bit, since it's just for their own use.  I've done that before as well; they probably didn't expect someone to read every last file the way I'm doing.

At any rate, what are we storing in "sep"?  The `bash` syntax is:

```
"${1:2}"
```

To see what happens here, I once again pull up [the GNU "Parameter Expansion" Docs](https://web.archive.org/web/20220905173558/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html), and search for the string "1:2".  No luck, so I search for "1:".  This time I find the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-949am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>


I Google "set –", and I find [this StackExchange answer](https://web.archive.org/web/20221015064720/https://unix.stackexchange.com/questions/308260/what-does-set-do-in-this-dockerfile-entrypoint) which says that "set --" tells the shell to set everything after "--" as the positional arguments (i.e. the members of "$@").  So the line:

```
Set – 01234567890abcdefgh
```

...sets arg "$1" equal to `01234567890abcdefgh`.  The line after that:

```
echo ${1:7}
```

...treats the number `1` in this case as the value of argument "$1", and prints everything starting from the 7th character onward (characters are 0-based here).

This also appears to be what's happening in the case of our code.  We're setting the "sep" variable equal to the value of `rbenv echo`'s first argument.  But not the whole argument- only the section of the argument from character 2 to the end (shaving off the first 2 chars, i.e. the "-F" chars).

We can verify this with an experiment.  I paste the following function in my `bash` terminal:

```
foo() {
  echo "${1:2}"
}
```
When I run it with a similar string, I get:

```
bash-3.2$ bar=abcdefghijklmnop
bash-3.2$ foo "$bar"
cdefghijklmnop
```

We see the first two characters are shaved off, leaving only the chars from position 2 to the end of the string.

The next line of `rbenv-echo` is:

```
echo "${!2}" | tr "${sep:-:}" $'\n'
```

The first part of this, `echo "${!2}"`, looks strange to me.  I search the GNU Parameter Expansion docs for "!", expecting to get the phone book, but luckily I only get 7 results.  Most of them are in this paragraph:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-950am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

I don't know what a "nameref" is, and therefore I don't know which of the "if" branches in this definition is relevant to our code.  This is a great example of the issue I take with the GNU docs- they're written for people who are already familiar with `bash`.  There is no example code, no links to definitions for jargon (like "nameref"), and no plain-English wording.  It seems to me that, if we want to tell noobies to "read the fucking manual", then we need to write the manual with those noobies in mind.

OK, rant over.

I Google "bash parameter expansion exclamation mark", and I find [another StackOverflow link](https://web.archive.org/web/20211211034729/https://unix.stackexchange.com/questions/41292/variable-substitution-with-an-exclamation-mark-in-bash), which contains the following clarification:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-952am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

This time we have actual example code.  It looks like the "!" syntax is known as 'indirect expansion", which means you can pass the name of a variable as a stringified argument, and the consumer of the argument will look for a variable with that stringified name, and expand *that variable* instead of the string itself.  That makes sense, given how I saw the `rbenv echo` command being used inside the `rbenv.bats` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-953am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so we `echo` the value of the variable whose name we're passing to `rbenv echo` via the 2nd argument (that's what the "2" in `"${!2}"` means)/  Then we pipe that `echo`'ed value to a command named `tr`.  Specifically, the full command is `tr "${sep:-:}" $'\n'`.  What does this command do?  I type `man tr` in my terminal and get:

NAME
     tr – translate characters

SYNOPSIS
     tr [-Ccsu] string1 string2
     tr [-Ccu] -d string1
     tr [-Ccu] -s string1
     tr [-Ccu] -ds string1 string2

DESCRIPTION
The tr utility copies the standard input to the standard output with substitution or deletion of selected characters.

Hoping for some example code, I Google "bash tr command" and find [this link](https://web.archive.org/web/20221029094817/https://linuxhint.com/bash_tr_command/) as the first result.  One of its examples of how to use `tr` is:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-954am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so we're replacing the value:

```
"${sep:-:}"
```

...with the value:

```
$'\n'
```

The value `"${sep:-:}"` looks to me like the syntax we saw earlier, where we provide a variable name as well as a default value if the variable is uninitialized (or initialized to null).  To test this, I do the following in my terminal:

```
bash-3.2$ sep="foo"

bash-3.2$ echo "${sep:-:}"

foo

bash-3.2$ sep=

bash-3.2$ echo "${sep:-:}"

:
```

I think we can conclude that, yes, that is what's happening here.

The string that we replace it with looks to be a simple newline.  I'm a bit confused why we need the leading "$" character, so I try `echo`'ing the newline with and without the dollar sign:

```
bash-3.2$ echo $'\n'


bash-3.2$ echo '\n'

\n
```

OK, so the dollar sign ensures that we replace "sep" with an actual newline, not an escaped one.

So in summary: the code...

```
echo "${!2}" | tr "${sep:-:}" $'\n'
```

...appears to mean that we `echo` the value of the variable whose name is passed in as the 2nd argument, and we replace any occurrences of the value of "sep" (or ":" if "sep" doesn't exist) with a newline.  With that knowledge, it seems like "sep" most likely stands for "separator".

Let's test this hypothesis.  I make the following function and paste it into my terminal:

```
foo() {
  sep="${1:2}"
  echo "${!2}" | tr "${sep:-:}" $'\n'
}
```

I then run the following code:

```
bash-3.2$ bar="foo5bar5baz"

bash-3.2$ foo xy5 bar

foo
bar
baz

bash-3.2$
```

I declare a variable named "bar" and set it to the strings "foo", "bar", and "baz", all separated by the character "5".  I then call my "foo" function with the arg "xy5" as my first arg (the "x" and "y" are throw-away characters, similar to "-F" in the original code, because "sep" is defined in a way that it shaves off those first two chars) and the string "bar" as my 2nd arg (because `foo` internally uses indirect expansion to change the string "bar" into the variable "bar", and then expands that variable).  The result is my "foo5bar5baz" string, with the "5" characters replaced with newlines.  I then try this again, but without telling my function to use "5" as a separator:

```
bash-3.2$ foo xy bar

foo5bar5baz
```

This time, since we didn't specify "5" as a separator, we just get our original string back, without any newline separation.  Lastly, I change the definition of "bar" to use the ":" character instead of "5", and run the last command again:

```
bash-3.2$ bar="foo:bar:baz"

bash-3.2$ foo xy bar

foo

bar

baz

bash-3.2$
```

We once again see our original string, this time split into 3 separate lines according to the default ":" separator.

What happens if we *don't* pass the "-F" flag?  That's handled in the `else` condition:

```
else
  echo "${!1}"
fi
```

Here we're still using indirect expansion, except this time we perform it on the first argument, not the 2nd one.  But we're still `echo`ing that variable's value to STDOUT.

That's it!  That's the definition of `rbenv echo`.


