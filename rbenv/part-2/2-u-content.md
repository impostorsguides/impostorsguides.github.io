
There's one more file we have to examine before we can call it a day on the `libexec/` folder.  The `test/` directory has its own folder named `libexec`, containing a command named `rbenv-echo`.  This command is only used inside [the `rbenv.bats` spec file](https://github.com/rbenv/rbenv/blob/ ed1a3a554585799cd0537c6a5678f6c793145b8e/test/rbenv.bats){:target="_blank" rel="noopener" }.

Because it's in `test/libexec/` (not regular `libexec/`), that means:

- it's only available to tests, not callable by users, and
- it doesn't have any tests of its own.

But it's got some interesting syntax, so let's look at it anyway, starting with the "Usage" comments.

## ["Usage" Comments](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/libexec/rbenv-echo#L2){:target="_blank" rel="noopener" }

```
# Usage: rbenv echo [-F<char>] VAR
```

There's one required argument (`VAR`), and one optional flag (`-F<char>`).

[Here's an example](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rbenv.bats#L74){:target="_blank" rel="noopener" } of using the command without the `-F` flag:

```
run rbenv echo "RBENV_HOOK_PATH"
```

Here, when we run `rbenv echo` **without** the `-F:` flag, we can see that we expect the result to be an unseparated list of paths:

```
assert_success "${RBENV_ROOT}/rbenv.d:${BATS_TEST_DIRNAME%/*}/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
```

And [here's](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rbenv.bats#L57){:target="_blank" rel="noopener" } and example of using the command with the `-F` flag:

```
run rbenv echo -F: "PATH"
```

In this test, we **do** pass the `-F:` flag, and we expect the output to be a **separated** list of paths:

```
assert_line 0 "${BATS_TEST_DIRNAME%/*}/libexec"
assert_line 1 "${RBENV_ROOT}/plugins/ruby-build/bin"
assert_line 2 "${RBENV_ROOT}/plugins/rbenv-each/bin"
```

We'll see later that `-F:` means we want to interpret the `:` symbol as a field separator, and therefore to separately `echo` each section of the string in between the `:` characters.  For example, `rbenv echo -F: a:b:c` would print `a`, `b`, and `c` on separate lines.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/libexec/rbenv-echo){:target="_blank" rel="noopener" }

The first and only block of code in this file is:

```
if [[ $1 == -F* ]]; then
  sep="${1:2}"
  echo "${!2}" | tr "${sep:-:}" $'\n'
else
  echo "${!1}"
fi
```

This is a short but dense block of code.  Let's break it down.

### Checking whether the user passed the `-F` flag

```
if [[ $1 == -F* ]]; then
  ...
fi
```

We have an `if` conditional, which checks whether the command's first argument starts with "-F".

### If the user **did** pass the flag

```
sep="${1:2}"
```

If the argument starts with `-F`, then we create a variable named `sep`.

What are we storing in the new variable?  I ask ChatGPT about the above syntax:

```
The syntax "${1:2}" is a substring expansion in Bash. It allows you to extract
a portion of a string starting from a specific index.

In this case, ${1:2} extracts a substring from the first argument ($1) starting
from the third character (index 2). The syntax is variable:offset:length, where
variable is the name of the variable containing the string, offset is the starting
index (0-based), and length is an optional parameter indicating the number of
characters to extract.

Let's break down the components of "${1:2}":

 - ${1}: It references the value of the first argument passed to the script.
 - :2: It specifies the starting index as 2, indicating that the substring should
 start from the third character.
 - The result is the portion of the string from the third character onwards.
```

We can verify this with an experiment.  I paste the following function in my Bash terminal:

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

So `sep` contains everything from the 3rd character (i.e. `:`) until the end of the first argument.  In our case, `:` is also the last character in the first argument, so `sep` just contains `:`.

### Printing the value of the variable we passed in

The next line of `rbenv-echo` is:

```
echo "${!2}" | tr "${sep:-:}" $'\n'
```

The first part of this is `echo "${!2}"`.  It's parameter expansion, but that exclamation mark is something we haven't seen yet, at least not in RBENV.

I ask ChatGPT again, and get the following response:

```
It echoes the value of the variable named by the second argument ($2) by using
indirect variable expansion ("${!2}"), which expands to the value of the variable
whose name is stored in $2.
```

So the 2nd argument to `rbenv echo` is the **name** (not the **value**) of a variable.  For example, when we call the following in our test:

```
run rbenv echo -F: "PATH"
```

The 2nd argument is the literal string "PATH", **not** the value that our `$PATH` environment variable resolves to.

So `"${2}"` would resolve to the string "PATH", and we need the `!` character to capture what the `PATH` env var resolves to.  Therefore, we echo `"${!2}"`, not  `"${2}"` or `"$2"`.

I Google "bash indirect parameter expansion", and I get confirmation of ChatGPT's answer via [StackOverflow](https://web.archive.org/web/20230406191600/https://stackoverflow.com/questions/8515411/what-is-indirect-expansion-what-does-var-mean){:target="_blank" rel="noopener" }.

Let's try this for ourselves, with an experiment.

#### Experiment- indirect parameter expansion

I create the following script:

```
#!/usr/bin/env bash

echo "${1}"

echo "${!1}"
```

The 1st `echo` line prints out the first argument directly, and the 2nd `echo` line prints out what it would resolve to if treated as a named variable.

I then run the script as follows:

```
$ FOO='foo bar baz' ./foo FOO

FOO
foo bar baz
```

The 1st `echo` line treats the argument as a literal string, and the 2nd one treats it as a variable name that it then resolves to its underlying value.

Great, I think we get it now!

### Splitting the path into separate lines

After we've `echo`ed the value of our variable, we pipe that value to a command named `tr`:

```
tr "${sep:-:}" $'\n'
```

What does this command do?  I type `man tr` in my terminal and get:

```
NAME
     tr – translate characters

SYNOPSIS
     tr [-Ccsu] string1 string2
     tr [-Ccu] -d string1
     tr [-Ccu] -s string1
     tr [-Ccu] -ds string1 string2

DESCRIPTION
The tr utility copies the standard input to the standard output with substitution
or deletion of selected characters.

...

In the first synopsis form, the characters in string1 are translated into the
characters in string2 where the first character in string1 is translated into
the first character in string2 and so on.
```

In our case, `"${sep:-:}"` is `string1` and `$'\n'` is `string2`.  So we read from `stdin`, replacing any occurrences of `"${sep:-:}"` with `$'\n'`.

If we refer back to [the docs on shell parameter expansion](https://web.archive.org/web/20220905173558/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener" }, we see that `"${sep:-:}"` means:

 - Use the value of `sep`, if it exists.
 - If `sep` is unset or null, fall back to the character `:`.

The string that we use to replace `sep` is:

```
$'\n'
```

This syntax is called [ANSI-C quoting](https://web.archive.org/web/20230613061217/https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html){:target="_blank" rel="noopener" }.  It ensures that Bash treats the special newline character (`\n`) as a newline, rather than as a literal string.

To summarize: the code...

```
echo "${!2}" | tr "${sep:-:}" $'\n'
```

...means that:

 - We print (to `stdout`) the value of the variable whose name is passed in as the 2nd argument.
 - We pipe that `stdout` output to the `stdin` of the `tr` command.
 - We use `tr` to replace any occurrences of the value of `sep` (falling back to `:` if `sep` is undefined) with a newline.

Let's test this hypothesis.

#### Experiment- splitting standard input using `tr`

I rewrite my `foo` script to look like the following:

```
#!/usr/bin/env bash

separator="${1:-:}"

tr "${separator}" $'\n'
```

I then run the script in my terminal, like so:

```
$ echo "foo:bar:baz" | ./foo
```

The output I see is:

```
$ echo "foo:bar:baz" | ./foo

foo
bar
baz
```

Then, I call it again, `echo`ing the same string with a different separator, and passing that new separator as the first argument to `foo`:

```
$ echo "foo5bar5baz" | ./foo 5

foo
bar
baz
```

Changing the separator in the `echo`ed string had the same result, **provided that** I also passed that separator as an argument to `foo`.  If I leave off the argument to `foo`, I no longer see my 3 separate lines:

```
$ echo "foo5bar5baz" | ./foo

foo5bar5baz
```

### If the user did **not** pass the flag

What happens if we *don't* pass the `-F` flag to `rbenv echo`?  That's handled in the `else` condition:

```
else
  echo "${!1}"
fi
```

Here we're still using indirect expansion, except this time we perform it on the first argument, not the 2nd one.  But we're still `echo`ing that variable's value to STDOUT.

So the following invocation in our test...

```
run rbenv echo "RBENV_HOOK_PATH"
```

...prints the following result:

```
"${RBENV_ROOT}/rbenv.d:${BATS_TEST_DIRNAME%/*}/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
```

In other words, we print the un-separated value of `RBENV_HOOK_PATH`, i.e. a sequence of directories which are joined together with the `:` character.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's the end of `rbenv echo`, and of the `libexec/` directory.  Let's review what we've learned.
