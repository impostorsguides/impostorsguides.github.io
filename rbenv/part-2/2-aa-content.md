We're getting close to the end here, only 3 more commands.  First, the tests:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/versions.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_version() {
  mkdir -p "${RBENV_ROOT}/versions/$1"
}
```

(stopping here for the day; 77103 words)

This helper function creates a version sub-directory inside RBENV's `versions/` directory.

Next block of code:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This helper function creates and navigates into RBENV's test directory.

Next block of code:

```
stub_system_ruby() {
  local stub="${RBENV_TEST_DIR}/bin/ruby"
  mkdir -p "$(dirname "$stub")"
  touch "$stub" && chmod +x "$stub"
}
```

This helper function makes a substitute for the system Ruby file, in an executable file named "stub" located inside a directory named `bin/ruby`.  Because we previously loaded `test_helper`, and because that file modifies `$PATH` to include `RBENV_TEST_DIR` before the real "system" Ruby installation, we can be confident that this stubbed Ruby version is the version that RBENV will encounter when searching for "system" Ruby.

First test:

```
@test "no versions installed" {
  stub_system_ruby
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-versions
  assert_success "* system"
}
```

This test sets up a fake installation of system Ruby, and asserts that RBENV's "versions/" folder does not exist (to indicate that there are no Ruby versions installed via RBENV).  It then runs the "versions" command and asserts that the user's system Ruby installation is indicated in the printed output.  The "*" symbol is used to indicate which is the currently-selected Ruby version, if more than one version is installed.

Next test:

```
@test "not even system ruby available" {
  PATH="$(path_without ruby)" run rbenv-versions
  assert_failure
  assert_output "Warning: no Ruby detected on the system"
}
```

This test removes the `ruby` executable from `$PATH`, and then runs the `versions` command.  It asserts that the command fails because there's no Ruby version installed (not even "system" Ruby), and that an error message to that effect is printed to STDOUT.

Next test:

```
@test "bare output no versions installed" {
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-versions --bare
  assert_success ""
}
```

As a sanity check step, this test asserts that no Ruby versions have been registered with RBENV.  It then runs the `versions` command with the `–bare` flag, and asserts that the command was successful but that nothing was printed to STDOUT.  We didn't strip out the system Ruby from `$PATH` the way we did with the previous test, and we know that the `versions` command prints out "system" when the `--bare` flag is *not* passed, so one of the jobs of `--bare` must be to strip out the "system" Ruby from the list of installed Ruby versions.

Next test:

```
@test "single version installed" {
  stub_system_ruby
  create_version "1.9"
  run rbenv-versions
  assert_success
  assert_output <<OUT
* system
  1.9
OUT
}
```

Here we both stub the "system" Ruby to ensure it exists, and create an installed version (v1.9) that RBENV will recognize as being different from the "system" Ruby.  We then run the command and assert that a) it completed successfully, and b) that the output printed to STDOUT includes both the system and non-system versions that we added during the test setup.  Here, "system" has an asterisk in front of it, indicating that RBENV thinks this is the currently-installed version.  My guess is that it thinks this because there is no global or local version file which indicates a non-system version currently in-use.

Next test:

```
@test "single version bare" {
  create_version "1.9"
  run rbenv-versions --bare
  assert_success "1.9"
}
```

This test is similar to the previous one featuring the `--bare` flag, except this time we create an installed Ruby version in the setup phase.  We then run the `versions –bare` command and assert that this Ruby version is the only thing printed to STDOUT.

Next test:

```
@test "multiple versions" {
  stub_system_ruby
  create_version "1.8.7"
  create_version "1.9.3-p13"
  create_version "1.9.3-p2"
  create_version "2.2.10"
  create_version "2.2.3"
  create_version "2.2.3-pre.2"
  run rbenv-versions
  assert_success
  assert_output <<OUT
* system
  1.8.7
  1.9.3-p2
  1.9.3-p13
  2.2.3-pre.2
  2.2.3
  2.2.10
OUT
}
```

Here we create both the "system" Ruby and 6 other Ruby versions.  We then run the `versions` command and assert that a) it was successful, and b) that all 6 Ruby versions as well as the "system" Ruby are printed to STDOUT.  Since we didn't specify either a global or local Ruby version, the expected STDOUT output includes an asterisk next to "system" to indicate that this is the Ruby version currently in-use.

Next test:

```
@test "indicates current version" {
  stub_system_ruby
  create_version "1.9.3"
  create_version "2.0.0"
  RBENV_VERSION=1.9.3 run rbenv-versions
  assert_success
  assert_output <<OUT
  system
* 1.9.3 (set by RBENV_VERSION environment variable)
  2.0.0
OUT
}
```

Here we create the "system" Ruby version and 2 additional versions.  We then run the `versions` command, passing in the first of the 2 additional versions as the value for the `RBENV_VERSION` env var.  We assert that:

 - the command was successful,
 - the "system" version and the 2 additional versions all appear in the printed output,
 - the version set by the env var is indicated as the currently-selected Ruby version, and
 - that the source of the Ruby version selection was an environment variable.

Next test:

```
@test "bare doesn't indicate current version" {
  create_version "1.9.3"
  create_version "2.0.0"
  RBENV_VERSION=1.9.3 run rbenv-versions --bare
  assert_success
  assert_output <<OUT
1.9.3
2.0.0
OUT
}
```

Here we create two Ruby versions- "1.9.3" and "2.0.0".  We then run the command, passing both the `--bare` flag and "1.9.3" as the value for `RBENV_VERSION`.  Remember from the previous test that the value of `RBENV_VERSION` determines the version of Ruby that `rbenv version` thinks is currently in-use.  However, here we're testing with the `--bare` flag, so we expect the asterisk character to be stripped out of the printed output.  And that's exactly what the 2nd assertion states- we expect both Ruby versions to be printed, but no asterisk next to "1.9.3".

Note that none of the installed Ruby versions are the "system" version.  We're testing the command with the `--bare` flag here, so "system" will not be printed to STDOUT, which means we don't need to bother stubbing it.

Next test:

```
@test "globally selected version" {
  stub_system_ruby
  create_version "1.9.3"
  create_version "2.0.0"
  cat > "${RBENV_ROOT}/version" <<<"1.9.3"
  run rbenv-versions
  assert_success
  assert_output <<OUT
  system
* 1.9.3 (set by ${RBENV_ROOT}/version)
  2.0.0
OUT
}
```

Here we stub out "system" Ruby as well as create two installed Ruby versions- "1.9.3" and "2.0.0".  We also create RBENV's global Ruby version file, and set its contents equal to the first of the 2 versions we created.  We then run the command without any flags, and assert that:

 - it was successful,
 - the printed output includes both of our installed Ruby versions,
 - the selected version is the one mentioned in the global version file, and
 - the source of the selected version is RBENV's global version file

Next test:

```
@test "per-project version" {
  stub_system_ruby
  create_version "1.9.3"
  create_version "2.0.0"
  cat > ".ruby-version" <<<"1.9.3"
  run rbenv-versions
  assert_success
  assert_output <<OUT
  system
* 1.9.3 (set by ${RBENV_TEST_DIR}/.ruby-version)
  2.0.0
OUT
}
```

Here we stub the "system" Ruby and create two fake Ruby installations- one for v1.9.3 and one for v2.0.0.  We then create a local Ruby version file and set its contents equal to v1.9.3.  We run the command and assert that:

 - The command was successful,
 - The two installed Ruby versions *and* the system Ruby are included in the printed output
 - v1.9.3 is selected as the version in-use, and
 - The local version file is listed as the source of the selection preference.

Next test:

```
@test "ignores non-directories under versions" {
  create_version "1.9"
  touch "${RBENV_ROOT}/versions/hello"

  run rbenv-versions --bare
  assert_success "1.9"
}
```

This test creates Ruby v1.9, and also creates a file named `hello` inside RBENV's `versions/` directory.  It runs `versions` with the `--bare` flag, and we assert that only v1.9 is printed to STDOUT.  This is because `rbenv versions` only considers *directories* (not *files*) when deriving its list of installed Ruby versions.  I'm actually not sure why this would need to be tested, considering RBENV is theoretically the only program installing things into its `versions/` directory, and could therefore guarantee that nothing besides sub-directories would appear there.  I add this to my running list of questions.

Next test:

```
@test "lists symlinks under versions" {
  create_version "1.8.7"
  ln -s "1.8.7" "${RBENV_ROOT}/versions/1.8"

  run rbenv-versions --bare
  assert_success
  assert_output <<OUT
1.8
1.8.7
OUT
}
```

Here we create both an installed Ruby version ("1.8.7") and a symlink to that version in the same "versions/" directory.  We then run the `versions` command with the `--bare` flag, and assert that:

 - The command was successful, and
 - The printed output lists the canonical and symlink versions separately

Last test:

```
@test "doesn't list symlink aliases when --skip-aliases" {
  create_version "1.8.7"
  ln -s "1.8.7" "${RBENV_ROOT}/versions/1.8"
  mkdir moo
  ln -s "${PWD}/moo" "${RBENV_ROOT}/versions/1.9"

  run rbenv-versions --bare --skip-aliases
  assert_success

  assert_output <<OUT
1.8.7
1.9
OUT
}
```

Here we create an installed Ruby version "1.8.7" and a symlink, as in the last test.  Then we create a directory named "moo" inside our current directory, and create a 2nd symlink inside `versions/`, this time to our new `moo/` directory.  We create this 2nd symlink inside RBENV's `versions/` directory and call this symlink "1.9", indicating we want RBENV to interpret it as a separate Ruby version.  We then call the `versions` command, passing *both* the `--bare` flag and a ``skip-aliases` flag, which we haven't seen before.  We assert that:

 - The command is successful,
 - The canonical "1.8.7" version and the symlink to the `moo/` directory are included in the output, and
 - The symlink to "1.8.7" is *not* included.

That's all the tests.  Now on to the code:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-versions){:target="_blank" rel="noopener"}

(stopping here for the day; 78722 words)

First block:

```

#!/usr/bin/env bash
# Summary: List installed Ruby versions
# Usage: rbenv versions [--bare] [--skip-aliases]
#
# Lists all Ruby versions found in `$RBENV_ROOT/versions/*'.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

No surprises here:

 - The `bash` shebang
 - The "Summary", "Usage", and "help" comments
 - `set -e` to tell the shell to exit immediately upon encountering an error
 - `set -x` to tell the shell to print to STDOUT in verbose mode, in this case only when `RBENV_DEBUG` is set.

Next block of code:

```
unset bare
unset skip_aliases
# Provide rbenv completions
for arg; do
  case "$arg" in
  --complete )
    echo --bare
    echo --skip-aliases
    exit ;;
  --bare ) bare=1 ;;
  --skip-aliases ) skip_aliases=1 ;;
  * )
    rbenv-help --usage versions >&2
    exit 1
    ;;
  esac
done
```

First we explicitly unset any variables named `bare` or `skip_aliases`.  To be honest, not sure why this is necessary.  The string `skip_aliases` only occurs in one file within the `rbenv` codebase, and that's in this file.  This was also the case even as of [the PR](https://github.com/rbenv/rbenv/pull/812/files){:target="_blank" rel="noopener"} which introduced this code.

Two theories I can think of:

 - Will running the code set the respective variables in the shell, causing a subsequent run in the same shell to pick up the previously-set values?
 - Will a value for a variable which is set in one file be picked up in another file which is executed by the original file?

I try an experiment to test the first hypothesis, making the following script...

```
echo "old foo: $foo"

foo=5

echo "new foo: $foo"
```

... and running it multiple times:

```
$ ./foo

old foo:
new foo: 5

$ ./foo

old foo:
new foo: 5

```

If the value of the `foo` variable was persisting across multiple runs of the script, I would have expected the 2nd and subsequent script runs to print out a value on line 3, not just line 7.  But that doesn't appear to be happening here, so so I feel like this disproves the first hypothesis.  What about the 2nd one?

I make 2 scripts, one named `foo1`...

```
#!/usr/bin/env bash

# foo1.sh

foo=1

./foo2
```

...and one named `foo2`:


```
#!/usr/bin/env bash

# foo2.sh

echo "foo inside foo2: $foo"
```

`foo1` sets the `foo` variable and then calls `foo2`, which attempts to read and `echo` it to the terminal.  If variable scopes worked this way in bash, I would expect the `echo` statement on line 5 of `foo2` to print the number "1".  When I run `foo1`, however, the following happens:

```
$ ./foo1

foo inside foo2:
```

No value is `echo`'ed after `foo inside foo2`.  Therefore, it looks like a variable which is set in one script does not carry over to other scripts executed within the same context.

So I'm pretty confused as to why `unset` is used in this way.  While I'm Googling for things like "global variables bash", I remember that variables can be passed in as environment variables.  I try running the `foo` script again, this time as follows:

```
$ foo=bar ./foo

old foo: bar
new foo: 5
```

This time I see `foo` printed to the screen.  What about if I do the above, but use `unset` like this?

```
#!/usr/bin/env bash

unset foo
echo "old foo: $foo"

foo=5

echo "new foo: $foo"
```

When I run it again, I get this:

```
$ foo=bar ./foo

old foo:
new foo: 5
```

OK, so the `unset` command is meant to prevent a previously-set value of `bare` or `skip_aliases` from interfering with the functionality of this command.  What are some other ways this could possibly happen?  I know there's a command named `declare` which lets you set variable values- could this interfere with the `versions` command?

Possibly!  I change my `foo1` script to the following:

```
#!/usr/bin/env bash

# foo1.sh

declare foo=1

./foo2
```

I then run it with the same `foo2` script, and this time I get:

```
$ ./foo1

foo inside foo2:
```

Then I try commenting out line 5 of `foo1` entirely, and running the `declare` command directly in my terminal:

```
$ declare foo=6

$ ./foo1

foo inside foo2:
```

Neither of these `declare` statements caused the `declare`d value to show up in the `foo2` script.

Without posting a question in the RBENV repo's "Issues" Github page, I can't say for sure what the reason is.  But to me, the most likely reason for using `unset` in the `versions` file was to guard against any users who have `declare`'ed variables with the same names as the ones used in this file.  I'm content to move on from here.

NOTE: I might want to read more about `declare` [here](https://linuxhint.com/bash_declare_command/){:target="_blank" rel="noopener"}.

Next block of code:

```
# Provide rbenv completions
for arg; do
  case "$arg" in
  --complete )
    echo --bare
    echo --skip-aliases
    exit ;;
  --bare ) bare=1 ;;
  --skip-aliases ) skip_aliases=1 ;;
  * )
    rbenv-help --usage versions >&2
    exit 1
    ;;
  esac
done
```

Here we handle the possible argument values.  We iterate over each arg in the arguments array, checking whether it's one of several allow-listed values.  If the arg is `--complete`, we echo two strings ("--bare" and "--skip-aliases") and exit.  If the arg is "--bare", we set a variable named `bare` equal to 1.  If the argument is `--skip-aliases`, then we set a different variable named `skip_aliases` equal to 1.  Otherwise, we just echo the "Usage" instructions from the top of this file to STDERR, and exit with an error status code.

Next block of code:

```
versions_dir="${RBENV_ROOT}/versions"
```

Here we just declare a variable named `versions_dir`, and set it equal to the "versions/" directory.

Next block of code:

```
if ! enable -f "${BASH_SOURCE%/*}"/rbenv-realpath.dylib realpath 2>/dev/null; then
  if [ -n "$RBENV_NATIVE_EXT" ]; then
    echo "rbenv: failed to load \`realpath' builtin" >&2
    exit 1
  fi

  READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
  if [ -z "$READLINK" ]; then
    echo "rbenv: cannot find readlink - are you missing GNU coreutils?" >&2
    exit 1
  fi

  resolve_link() {
    $READLINK "$1"
  }

  realpath() {
    local cwd="$PWD"
    local path="$1"
    local name

    while [ -n "$path" ]; do
      name="${path##*/}"
      [ "$name" = "$path" ] || cd "${path%/*}"
      path="$(resolve_link "$name" || true)"
    done

    echo "${PWD}/$name"
    cd "$cwd"
  }
fi
```

We've seen this `if` check before, in `rbenv-hooks`.  We check whether we're able to replace the shell builtin named `realpath` with an identically-named command which comes from the file `rbenv-realpath.dylib`.  If we're *not* able to do this, we execute the logic inside the `if` block.  That logic consists of replacing the existing `realpath` implementation with a more performant one, defined here in the file.  Since we've already examined this logic in detail in a previous section, we'll make do with this abbreviated explanation, and move on.

Next block of code:

```
if [ -d "$versions_dir" ]; then
  versions_dir="$(realpath "$versions_dir")"
fi
```

Here we check whether the string in the `versions_dir` variable we just created corresponds to an existing directory on our machine.  If it does, we pass the string to the `realpath` command to eliminate the possibility that the directory is an alias or a symlink to another directory.  `realpath` will return the canonical version of the given directory.

Next block of code:

```
list_versions() {
  shopt -s nullglob
  for path in "$versions_dir"/*; do
    if [ -d "$path" ]; then
      if [ -n "$skip_aliases" ] && [ -L "$path" ]; then
        target="$(realpath "$path")"
        [ "${target%/*}" != "$versions_dir" ] || continue
      fi
      echo "${path##*/}"
    fi
  done
  shopt -u nullglob
}
```

(stopping here for the day; 79797 words)

We declare a helper function called `list_versions`.  Inside it, we temporarily turn on the `nullglob` option, so that when we attempt to expand the glob "$versions_dir"/* on the next line, it will expand to an empty string if the directory's contents are empty (i.e. it contains no filepaths or directory paths).  See [here](https://web.archive.org/web/20211102131455/http://bash.cumulonim.biz/NullGlob.html){:target="_blank" rel="noopener"} for more info.

If it does contain one or more paths, then for each path in that `versions_dir` directory, we do the following:

 - We check whether that path is a directory.  If it is, then we assume it's a directory which represents a version of Ruby.
    - For each item that represents a directory, we next check whether the `skip_aliases` flag has been set AND whether the current path is a symlink.
      - If both of those things are true, then we use our `realpath` helper function to turn the symlink into its canonical directory.
      - If the canonical directory is the same as our `versions_dir` variable, we don't do anything with this path; we skip it and start at the beginning with the next path.
    - If we've reached this far in the helper method, we `echo` just the last part of the directory, with everything up to the final "/" character trimmed off.  For example, if the path is `/Users/myusername/.rbenv/versions/2.7.5`, then we just echo "2.7.5".

As a final cleanup step, our `list_versions` helper function turns off the `nullglob` option.

Next block of code:

```
if [ -n "$bare" ]; then
  list_versions
  exit 0
fi
```

If the `bare` flag is turned on, we have all the information we need to print the requested output.  We don't need to worry about sorting the versions, determining which of our versions is the current version, etc.  We simply call our `list_versions` function to print each version one-by-one, then exit.

Next block of code:

```
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z.\1/; s/$/.z/; G; s/\n/ /' | \
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}
```

Here's another helper function, which (judging by the function's name) sorts the versions according to their number.  It uses `sed` and `awk`, two utilities that we looked at awhile ago but which I don't use often enough to have mentally retained.  So I'll have to Google again for a bit.

The first part of this is the `sed` command:

```
sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z.\1/; s/$/.z/; G; s/\n/ /'
```

After Googling "sed bash", I find [the GNU.org manual](https://web.archive.org/web/20221016162544/https://www.gnu.org/software/sed/manual/sed.html){:target="_blank" rel="noopener"} for `sed`.  After reading through the introduction and getting my bearings, I find [the section on `sed` scripts](https://web.archive.org/web/20221016162544/https://www.gnu.org/software/sed/manual/sed.html#sed-scripts){:target="_blank" rel="noopener"}.  It implies that the commands inside the stringified script are delimited using semi-colons:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar23-1048am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

In our script, we also see a string with a bunch of semi-colons in it, delimiting each of the manipulations we want `sed` to perform on the input it is given.  So we know we can break the script down into the following commands:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar23-1049am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Now all we need to do is look up their meanings one at a time in section 3.2, the `sed` commands summary.

The first `sed` command is "h;".  When I look up this command in the commands summary, I see:

```
     h
          Replace the contents of the hold space with the contents of the pattern space.
```

I'm not sure what "hold space" and "pattern space" refer to, so I Google "bash sed hold space".  I find [this StackOverflow answer](https://stackoverflow.com/a/12834372/2143275){:target="_blank" rel="noopener"}, which says:

> When sed reads a file line by line, the line that has been currently read is inserted into the pattern buffer (pattern space). Pattern buffer is like the temporary buffer, the scratchpad where the current information is stored. When you tell sed to print, it prints the pattern buffer.
>
> Hold buffer / hold space is like a long-term storage, such that you can catch something, store it and reuse it later when sed is processing another line. You do not directly process the hold space, instead, you need to copy it or append to the pattern space if you want to do something with it.

OK, for each line that `sed` encounters, it first puts that line in the "hold space", or the place in memory that it uses to store things for later.

The next `sed` command is `s/[+-]/./g;`.  I think I recognize the square brackets from Ruby regexes, but there's always the chance that `sed` regexes work differently.  In [the GNU `sed` manual](https://www.gnu.org/software/sed/manual/sed.html){:target="_blank" rel="noopener"}, I search for the string "bracket" and find the section ["5.5 Character Classes and Bracket Expressions"](https://www.gnu.org/software/sed/manual/sed.html#Character-Classes-and-Bracket-Expressions){:target="_blank" rel="noopener"}:

> A bracket expression is a list of characters enclosed by '[' and ']'. It matches any single character in that list; if the first character of the list is the caret '^', then it matches any character not in the list. For example, the following command replaces the words 'gray' or 'grey' with 'blue':
>
> `sed  's/gr[ae]y/blue/'`

The `/g` at the end stands for "global", which means the pattern will match *all* examples it finds, not just the first one:

> The s command can be followed by zero or more of the following flags:
>
> g
>
> Apply the replacement to all matches to the regexp, not just the first.

What that means for us is, `sed` will find all examples of a "+" or "-" character, and replace it with a "." character.

We can test this by running just this particular `sed` regex against a test file.  I make a simple text file named "bar" and paste the following Ruby versions inside it.  The Ruby versions were taken from [the official Ruby release list](https://web.archive.org/web/20221006111802/https://www.ruby-lang.org/en/downloads/releases/){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1056am.png" width="30%" style="border: 1px solid black; padding: 0.5em">
</p>

I figured this looked like a fairly exhaustive list of all the various representations that Ruby uses for their version numbers.

I then ran the following command in my `bash` terminal:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1057am.png" width="30%" style="border: 1px solid black; padding: 0.5em">
</p>

We can see that the "-" characters in the original have been replaced by "." characters in the output.

Next `sed` command is:

```
s/.p\([[:digit:]]\)/.z.\1/;
```

This is another search-and-replace command.  The first "." after the "/" character matches any single character, according to [this link](https://web.archive.org/web/20221021041253/https://users.monash.edu.au/~erict/Resources/sed/){:target="_blank" rel="noopener"} (I searched for "period" in the GNU docs, but didn't find anything relevant).  The subsequent "p" matches the literal character "p".

Next is the `\(...\)` syntax.  The slashes simply escape the opening and closing parentheses.  The parentheses themselves are meant to create a sub-expression, as mentioned [here](https://web.archive.org/web/20221016162544/https://www.gnu.org/software/sed/manual/sed.html#Back_002dreferences-and-Subexpressions){:target="_blank" rel="noopener"}.  The concept of sub-expressions is actually related to the `\1` syntax that we also see in the current `sed` command.  From the docs:

> back-references are regular expression commands which refer to a previous part of the matched regular expression. Back-references are specified with backslash and a single digit (e.g. '\1'). The part of the regular expression they refer to is called a subexpression, and is designated with parentheses.
>
> Back-references and subexpressions are used in two cases: in the regular expression search pattern, and in the replacement part of the s command...
>
> In a regular expression pattern, back-references are used to match the same content as a previously matched subexpression. In the following example, the subexpression is '.' - any single character (being surrounded by parentheses makes it a subexpression). The back-reference '\1' asks to match the same content (same character) as the sub-expression.
>
> The command below matches words starting with any character, followed by the letter 'o', followed by the same character as the first.
>
> ```
> $ sed -E -n '/^(.)o\1$/p' /usr/share/dict/words
> bob
> mom
> non
> pop
> sos
> tot
> wow
> ```
>
> In the s command, back-references can be used in the replacement part to refer back to subexpressions in the regexp part.
>
> The following example uses two subexpressions in the regular expression to match two space-separated words. The back-references in the replacement part prints the words in a different order:
>
> ```
> $ echo "James Bond" | sed -E 's/(.*) (.*)/The name is \2, \1 \2./'
> The name is Bond, James Bond.
> ```

Note that I actually got lucky finding the info on `\1`.  I was searching the GNU docs for the word "parentheses", found section 5.7, and saw that it also referenced the `\1` syntax.

Next are the double-brackets followed by `:digit:` followed by the double-closing-brackets.  We get an explanation of this character sequence from [the "Bracket Expressions" docs](https://www.gnu.org/software/sed/manual/sed.html#Character-Classes-and-Bracket-Expressions){:target="_blank" rel="noopener"} that we looked at previously:

> Finally, certain named classes of characters are predefined within bracket expressions, as follows.
>
> These named classes must be used inside brackets themselves. Correct usage:
>
> ```
> $ echo 1 | sed 's/[[:digit:]]/X/'
> X
> ```
>
> '[:digit:]'
> Digits: 0 1 2 3 4 5 6 7 8 9.

So to summarize the line `s/.p\([[:digit:]]\)/.z.\1/;`:

 - We look for a character plus a "p" plus any digit.
 - If we find a match, we replace that match with ".z.", followed by the same digit in the sub-expression.

We can test this by combining this new `sed` command with the previous command we just tested, and running the combo on the same input file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1101am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we can see that, for example, `2.0.0.p247` has been changed to `2.0.0.z.247`, because ".p247" matches the replacement pattern.  On the other hand, `2.1.0.preview1` remains unchanged because the "p" character is not followed by a digit.

Next `sed` command is `s/$/.z/;`.  Another search-and-replace command.  The "$" sign represents the end of the input, again according to [this link](https://web.archive.org/web/20221021041253/https://users.monash.edu.au/~erict/Resources/sed/){:target="_blank" rel="noopener"}.  So we're searching for the end of the input, and we're replacing it with ".z".  Essentially we're concatenating ".z" to the end of the input line.  We can test that again, by running this command after our previous commands:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1103am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we can see that every single line now has a ".z" at the end of it, which was not the case at the end of our previous experiment.  I'm not sure where we're going with all this ".z" stuff.  My best guess is that it will somehow help with the subsequent sorting, but if we're adding the same string to the same position of every version string, I don't yet see how it would make a difference.  Nevertheless, this approach was written and approved by people who are better at shell scripting than I am, so I'm choosing to have faith that they know what they're doing.  Maybe I'm about to learn something cool from this technique.

(stopping here for the day; 81818 words)

Next `sed` command:

```
G;
```

From the "3.2 sed commands summary" section of [the GNU `sed` docs](https://web.archive.org/web/20221016162544/https://www.gnu.org/software/sed/manual/sed.html#sed-commands-list){:target="_blank" rel="noopener"}, we see this command does the following:

> G
>
> Append a newline to the contents of the pattern space, and then append the contents of the hold space to that of the pattern space.

So we're just appending the hold space to the end of the pattern space.  What does this look like in our case?  I add `G;` to the end of the command I've been running, and get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1106am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

If we compare the above side-by-side with the previous screenshot, we see that each of the previous command's entries is now followed by the the original string value of the Ruby version.

Last `sed` command:

```
s/\n/ /
```
This appears to replace any newlines with a space character.  Let's see if I'm right, by adding it to our commands list and running it again:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1107am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Yep, looks like I was right.  Now, instead of each modified version string being appended with its original version, the two strings are on the same line, separated by a space.

OK, so the above text is what we're piping to the next command, i.e. `sort`.  That command, in full, is:

```
LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n
```

The first bit of syntax that Google is:

```
LC_ALL=C
```

I find [more GNU docs](https://web.archive.org/web/20220707190251/https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html){:target="_blank" rel="noopener"} on the `LC_ALL` environment variable:

> 2.3.2 Locale Environment Variables
>
> ...
>
> For example, assume you are a Swedish user in Spain, and you want your programs to handle numbers and dates according to Spanish conventions, and only the messages should be in Swedish. Then you could create a locale named 'sv_ES' or 'sv_ES.UTF-8' by use of the localedef program. But it is simpler, and achieves the same effect, to set the LANG variable to es_ES.UTF-8 and the LC_MESSAGES variable to sv_SE.UTF-8; these two locales come already preinstalled with the operating system.
>
> LC_ALL is an environment variable that overrides all of these. It is typically used in scripts that run particular programs. For example, configure scripts generated by GNU autoconf use LC_ALL to make sure that the configuration tests don't operate in locale dependent ways.

OK, so `LC_ALL` is used to tell different programs (in our case, the `sort` command) how to handle characters that could be treated differently in different countries.  I happen to know, for example, that in the US we would write "one million dollars" as "$1,000,000.00" (i.e. separating using the comma character for thousands characters, and a period as the decimal separator), but that's not how people write "one million" in other countries.  According to [this link](https://www.beresfordresearch.com/how-to-write-a-million-in-different-countries/){:target="_blank" rel="noopener"}, that same number is written as "$1.000.000,00" in many South American countries (i.e. reversing the usage of commas and decimals).  I presume that `LC_ALL` would dictate a certain way for the user's computer to handle questions like this, regardless of what that user's previous setting was.

What are we setting `LC_ALL` to here?  What does that `=C` mean?  Another result when I Googled for `LC_ALL` was [this StackOverflow post](https://web.archive.org/web/20221019143235/https://unix.stackexchange.com/questions/87745/what-does-lc-all-c-do){:target="_blank" rel="noopener"}.  One answer says the following:

> `LC_ALL` is the environment variable that overrides all the other localisation settings (except `$LANGUAGE` under some circumstances).
>
> Different aspects of localisations (like the thousand separator or decimal point character, character set, sorting order, month, day names, language or application messages like error messages, currency symbol) can be set using a few environment variables.
>
> You'll typically set `$LANG` to your preference with a value that identifies your region (like `fr_CH.UTF-8` if you're in French speaking Switzerland, using `UTF-8`).  The individual LC_xxx variables override a certain aspect. LC_ALL overrides them all...
>
> In a script, if you want to force a specific setting, as you don't know what settings the user has forced (possibly LC_ALL as well), your best, safest and generally only option is to force LC_ALL.
>
> The C locale is a special locale that is meant to be the simplest locale. You could also say that while the other locales are for humans, the C locale is for computers... In the C locale, characters are single bytes, the charset is ASCII..., the sorting order is based on the byte values¹, the language is usually US English... and things like currency symbols are not defined...
>
> You generally run a command with LC_ALL=C to avoid the user's settings to interfere with your script. For instance, if you want [a-z] to match the 26 ASCII characters from a to z, you have to set LC_ALL=C.

So we're setting the localization settings equal to a standardized, computer-friendly configuration for the purposes of sorting.

Next part of this command is:

```
sort -t.
```

According to the `man` page for `sort`:

> DESCRIPTION
>
> The sort utility sorts text and binary files by lines.  A line is a record separated from the subsequent record by a newline (default) or `NUL` `´\0´` character (`-z` option).  A record can contain any printable or unprintable characters.  Comparisons are based on one or more sort keys extracted from each line of input, and are performed lexicographically, according to the current locale's collating rules and the specified command-line options that can tune the actual sorting behavior.  By default, if keys are not given, sort uses entire lines for comparison.

So `sort` uses the newline character to separate its input into lines, and sorts those lines [lexicographically](https://stackoverflow.com/questions/45950646/what-is-lexicographical-order){:target="_blank" rel="noopener"}, or sorting them as strings (rather than as numbers).  So the numbers 1, 2, and 10 would be sorted as "1", "10", and "2".  The user's locale settings would normally dictate which rules are used to compare one string with another for sorting purposes (that's what "collating rules" refers to here).  But in our case, since we're applying `LC_ALL=C`, the collating rules that we found from the StackOverflow answer will be used for all users, regardless of their localization settings.

When I look up the `-t` flag in the `man` page, I see:

> -t char, --field-separator=char
>
> Use `char` as a field separator character.

So we're specifying the "." character as our "field separator".  But what is that?  I Google "bash sort field separator".  The first result is a StackOverflow article which doesn't turn out to be useful, but the 2nd result is [this link](https://web.archive.org/web/20220624080724/https://docstore.mik.ua/orelly/unix3/upt/ch22_03.htm){:target="_blank" rel="noopener"}:

> Section 22.2 explained how sort separates a line of input into two or more fields using whitespace (spaces or tabs) as field delimiters. The -t option lets you change the field delimiter to some other character.

There's a link to section 22.2, so I open that up as well.  I get the following additional info:

> Unless you tell it otherwise, sort divides each line into fields at whitespace (blanks or tabs), and sorts the lines by field, from left to right.
>
> That is, it sorts on the basis of field 0 (leftmost), but when the leftmost fields are the same, it sorts on the basis of field 1, and so on. This is hard to put into words, but it's really just common sense. Suppose your office inventory manager created a file like this:
>
> <p style="text-align: center">
>  <img src="/assets/images/screenshot-18mar2023-1110am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
></p>
>
> You'd want all the supplies sorted into categories, and within each category, you'd want them sorted alphabetically:
>
> <p style="text-align: center">
>  <img src="/assets/images/screenshot-18mar2023-1111am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
></p>

So instead of using whitespace to separate our lines into fields, we're using ".".  So a line such as "2.1.0.preview1.z" would be separated into fields "2", "1", "0", "preview1", and "z".  Field 1 from row 1 would be compared with field 1 of row 2.  If they're different, then we'd use our collating rules from `LC_ALL=C` to determine which row to put first.  If they're the same, then we'd move on to the next field from each row, comparing field 2 from rows 1 and 2 in the same manner.  And so on and so forth.

The next bit of unknown syntax is the `-k` flag, which appears to be repeated multiple times in this command:

```
-k 1,1
-k 2,2n
-k 3,3n
-k 4,4n
-k 5,5n
```

I check the `man` entry for `sort` again, and find the following:

> -k field1[,field2], --key=field1[,field2]
>
> Define a restricted sort key that has the starting position `field1`, and optional ending position `field2` of a key field.  The `-k` option may be specified multiple times, in which case subsequent keys are compared when earlier keys compare equal...

Hmmm OK, so we are using the `-k` flag multiple times because we want to define subsequent keys to compare with in case earlier keys are equal.  But why do we need both `field1` and `field2`?  I keep searching the `man` entry for `-k`.  Further down, I see:

> Fields are specified by the `-k field1[,field2]` command-line option.  If field2 is missing, the end of the key defaults to the end of the line.

I think I see now- `field2` tells the `sort` command where to terminate one key and start the next key?

I Google "bash sort keys" to try and get confirmation of this.  The first result is a StackOverflow post which (judging by its title) doesn't appear useful IMO.  The 2nd result is [this link](https://web.archive.org/web/20220410153515/https://riptutorial.com/bash/example/31704/sort-by-keys){:target="_blank" rel="noopener"}, from a site called "RIP Tutorial".  I've highlighted the relevant sentence below:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar23-1113am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The above example assumes that the field separator is whitespace, but we can just as easily imagine it's the "." character from our use case.

OK, so the series of "-k" flags tells `sort` to initially sort by the first field, and then the 2nd field, and then the 3rd, and so on.  I guess I'm a bit surprised that this is not the default behavior, but that's OK.  `bash` has to account for an extremely wide variety of use cases, and they're probably aware of scenarios that I'm not which would make this behavior impractical as the default setting.

Last question is about the "n" character at the end of keys like "-k 2,2n".  I keep reading the `man` page, and I encounter the following:

> The arguments field1 and field2 have the form m.n (m,n > 0) and can be followed by one or more of the modifiers b, d, f, i, n, g, M and r, which correspond to the options discussed above.

By "the options discussed above", I take it the authors mean that these letters correspond to flags mentioned in the "flags" section.  I look for the `-n` flag, and I find:

> -n, --numeric-sort, --sort=numeric
>
> Sort fields numerically by arithmetic value.  Fields are supposed to have optional blanks in the beginning, an optional minus sign, zero or more digits (including decimal point and possible thousand separators).

OK, so `-k 2,2n` just tells `sort` to use numerical (as opposed to lexicographical) sorting when comparing key / field 2.

But one thing I noticed is that every key has the "n" suffix, *except* for the first one (i.e. `-k 1,1`).  Does this mean that the first key is sorted lexicographically, *not* numerically?

Let's test this out.  I make a file named "bar" with the following contents:

```
2.1
10.1
1.1
1.2
1.10
```

I then sort it with the following command:

```
 $ sort -t. -k 1,1 -k2,2n bar

1.1
1.2
1.10
10.1
2.1
```

As we can see, the 1st field (the part before the "." character) is sorted lexicographically, as judged by the fact that "10.1" appears before "2.1".  However, the 2nd field (the part after the "." character) is sorted numerically, as judged by the fact that "1.2" appears before "1.10".

Why would the RBENV core team want 10.1 to come before 2.1?  That seems counter-intuitive to me.

I check [the PR](https://github.com/rbenv/rbenv/pull/1111){:target="_blank" rel="noopener"} which introduced this change, and I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1115am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

I see the issue link ([#1086](https://github.com/rbenv/rbenv/issues/1086){:target="_blank" rel="noopener"}), and I click on that to read more about the problem that this PR addresses.  I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-18mar2023-1116am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so the problem that this PR is meant to fix is that the version numbers are not sorted semantically according to major, minor, and patch versions.  If that's the case, I would think that version 10 would come *after* version 2.  But that's not what happens when I make a version 10 sub-directory under RBENV's `versions/` folder and run the `rbenv versions` command:

```
$ mkdir ~/.rbenv/versions/10.5.5-alpha

$ mkdir ~/.rbenv/versions/10.5.5

$ rbenv versions
  system
  10.5.5-alpha
  10.5.5
* 2.7.5 (set by /Users/myusername/.rbenv/version)
  3.0.0
```

When I change the `-k 1,1` flag in my RBENV code to `-k 1,1n`,...

<center>
  <figure>
  <img src="/assets/images/screenshot-18mar2023-1120am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  <figcaption>Adding a `n` to the end of `-k 1,1`</figcaption>
  </figure>
</center>

...it prints out the way I'd expect:

```
$ rbenv versions
  system
* 2.7.5 (set by /Users/myusername/.rbenv/version)
  3.0.0
  10.5.5-alpha
  10.5.5
```

(stopping here for the day; 83932 words)

I check the Github history for any conversation around why the major version isn't sorted numerically, but find nothing.  So either the code authors *and* the code reviewers didn't catch the lack of numerical sorting on major versions, or they *did* see it, and it's an intentional feature, not a bug.

I don't think this is a pressing issue for the core team.  It's taken 20 years for the Ruby community to get to major version 3, which is where we are now.  So the risk of leaving this bug in place is low for now.  I add a commit to my local branch fixing it, and lump it in with the minor test fix I committed before, and continue on my way.

The last bit of code for the `sort_versions` helper method is:

```
| awk '{print $2}'
```

We pipe the output from the `sort` command into the `awk` command.  `awk` takes in each line from our sorted list, splits the line into fields according to whitespace, and runs the command inside the curly braces on each line.  The user has the option of matching the line against certain patterns and only running the curly-brace command when the line matches, but we're not doing that in our case.  Instead, we're just printing every line, specifically the 2nd field of each line.

Our input looks like this:

```
1.1.z 1.1
1.2.z 1.2
1.10.z 1.10
10.1.z 10.1
2.1.z 2.1
```

Since fields are separated by whitespace, field # 2 is everything from each line after the ".z " part.  For example, if the current line is `2.1.z 2.1`, then field #2 is "2.1".  That's what we print from each line, according to the `man awk` entry:

```
AWK(1)                                                                       General Commands Manual                                                                      AWK(1)

NAME
       awk - pattern-directed scanning and processing language

SYNOPSIS
       awk [ -F fs ] [ -v var=value ] [ 'prog' | -f progfile ] [ file ...  ]

DESCRIPTION
       Awk scans each input file for lines that match any of a set of patterns specified literally in prog or in one or more files specified as -f progfile.  With each pattern
       there can be an associated action that will be performed when a line of a file matches the pattern.  Each line is matched against the pattern portion of every pattern-
       action statement; the associated action is performed for each matched pattern.  The file name - means the standard input.  Any file of the form var=value is treated as
       an assignment, not a filename, and is executed at the time it would have been opened if it were a filename.  The option -v followed by var=value is an assignment to be
       done before prog is executed; any number of -v options may be present.  The -F fs option defines the input field separator to be the regular expression fs.

       An input line is normally made up of fields separated by white space, or by the regular expression FS.  The fields are denoted $1, $2, ..., while $0 refers to the entire
       line.  If FS is null, the input line is split into one field per character.
```

The line in the description which I'm referring to is:

> An input line is normally made up of fields separated by white space,...

Since the lines are already sorted in the correct order semantically, what we end up with is:

```
1.1
1.2
1.10
10.1
2.1
```

This is the output of `sort_versions`- a sorted list of versions!

Next block of code:

```
versions="$(
  if RBENV_VERSION=system rbenv-which ruby >/dev/null 2>&1; then
    echo system
  fi
  list_versions | sort_versions
)"
```

The line `RBENV_VERSION=system rbenv-which ruby` checks whether the user's machine has "system" Ruby installed.  If it does, the command `echo`s the string "system".  Regardless of whether or not the system Ruby is installed, we then print a sorted list of all the non-system installed Ruby versions.

Next block of code:

```
if [ -z "$versions" ]; then
  echo "Warning: no Ruby detected on the system" >&2
  exit 1
fi
```

If we were successful in storing the "system" Ruby and/or the installed Ruby versions in the variable named `versions`, we continue on.  If we were not successful in this, we print an error saying that we couldn't detect any installed Ruby versions, and then exit with a non-zero return code.

Next block of code:

```
current_version="$(rbenv-version-name || true)"
```

Here we simply store the stringified, currently-selected Ruby version (in my case, 2.7.5) in a variable named `current_version`.

Last block of code:

```
while read -r version; do
  if [ "$version" == "$current_version" ]; then
    echo "* $(rbenv-version 2>/dev/null)"
  else
    echo "  $version"
  fi
done <<<"$versions"
```

Let's break this up into two parts:

```
while read -r version; do
  ...
done <<<"$versions"
```

We pipe the contents of `versions` into the `read` builtin shell command.  The contents of `versions` looks something like this:

```
system
* 2.7.5
3.0.0
```

For each line (separated by the "\n" newline character), we store that line's value in a local variable called `version`.  Then we pass that local variable to the `if` block inside the `while` loop.  When there are no more lines in `versions`, the `while` loop exits.

Part 2 of this code block:

```
  if [ "$version" == "$current_version" ]; then
    echo "* $(rbenv-version 2>/dev/null)"
  else
    echo "  $version"
  fi
```

If this iteration's version is the same as the value we stored in "current_version", we print the version number generated by the `rbenv-version` command to the screen, pre-pended by the asterisk symbol.  We use `rbenv-version` instead of just `version`, because the former contains the source / origin of the version too, not just the version number.  For example, on my machine, `rbenv-version` currently prints the following:

```
2.7.5 (set by /Users/myusername/.rbenv/version)
```

If this iteration's version is *not* the same as `current_version`, we just print the version by itself with no extra info.

In summary, when I run `rbenv versions` on my machine, I get:

```
  system
* 2.7.5 (set by /Users/myusername/.rbenv/version)
  3.0.0
  3.1.0
```

That's it for this file!  On to the next one.

(stopping here for the day; 80802 words)
