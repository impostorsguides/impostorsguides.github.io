As usual, tests first.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-file-read.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "${RBENV_TEST_DIR}/myproject"
  cd "${RBENV_TEST_DIR}/myproject"
}
```

This just makes a Ruby project directory and navigates into it.  By the way, we've seen this `setup` function before in other test files.  Apparently [this is a special `bats` function](https://github.com/sstephenson/bats#setup-and-teardown-pre--and-post-test-hooks), which gets called before each test case.  You can also define a `teardown` hook method, which gets called after each test case, though that isn't done in this specific test file.

Next block of code:

```
@test "fails without arguments" {
  run rbenv-version-file-read
  assert_failure ""
}
```

Our first test covers the sad-path case where no arguments are provided to the command.  In this case, we expect the command to fail with no error output.

I try this in my bash terminal, and I get the following:

```
bash-3.2$ rbenv version-file-read

bash-3.2$ echo "$?"

1
```

The syntax "$?" stands for the most recent exit code, which in this case is 1.  This means an error occurred.  Again, I'm not sure why we'd not want to give a user some helpful feedback in the event of an error.  This could be a good candidate for another Github issue/question, but again, I'm trying to build up some goodwill + political capital, so I'll refrain from posting that question for now.

Next test:

```
@test "fails for invalid file" {
  run rbenv-version-file-read "non-existent"
  assert_failure ""
}
```

(stopping here for the day; 71208 words)

This test passes the name of a non-existent file to the `version-file-read` command, and asserts that the command fails with no printed output.

Next test:

```
@test "fails for blank file" {
  echo > my-version
  run rbenv-version-file-read my-version
  assert_failure ""
}
```

We create an empty version file via the `echo > <new_filename>` command, and then we pass that filename to the `version-file-read` command.  Since we didn't pass any input to `echo`,  the file is empty, so the command fails (again, with no printed output).

Next test:

```
@test "reads simple version file" {
  cat > my-version <<<"1.9.3"
  run rbenv-version-file-read my-version
  assert_success "1.9.3"
}
```

This happy-path test begins by creating a valid version file named "my-version", containing the string "1.9.3".  We then pass that filename to `version-file-read`, and assert that the command passes and "1.9.3" is the printed output.

Next test:

```
@test "ignores leading spaces" {
  cat > my-version <<<"  1.9.3"
  run rbenv-version-file-read my-version
  assert_success "1.9.3"
}
```

This test is similar to the previous test, except the Ruby version string contained in the version file is prefixed with several space characters.  The test asserts that the command is successful and that these extra spaces are trimmed off before the version is printed to STDOUT.

Next test:

```
@test "reads only the first word from file" {
  cat > my-version <<<"1.9.3-p194@tag 1.8.7 hi"
  run rbenv-version-file-read my-version
  assert_success "1.9.3-p194@tag"
}
```

This test creates a version file with a valid Ruby version, plus a 2nd version and some random text.  We run the command with the name of the version file, and assert that only the first Ruby version is printed to the string.  The 2nd valid version and the random string are both ignored.

Next test:

```
@test "loads only the first line in file" {
  cat > my-version <<IN
1.8.7 one
1.9.3 two
IN
  run rbenv-version-file-read my-version
  assert_success "1.8.7"
}
```

This test is similar to the last one, except this Ruby version file contains a multi-line string *and* random text after each valid Ruby version.  Here we assert that the command is successful, and that all text after the Ruby version (including the subsequent lines) are trimmed off.

Next test:

```
@test "ignores leading blank lines" {
  cat > my-version <<IN

1.9.3
IN
  run rbenv-version-file-read my-version
  assert_success "1.9.3"
}
```

This test again uses a multi-line heredoc, but this time the first line contains only a newline character.  The test asserts that the command is successful and that the parser ignores this newline, and returns the correct version number anyway.

Next test:

```
@test "handles the file with no trailing newline" {
  echo -n "1.8.7" > my-version
  run rbenv-version-file-read my-version
  assert_success "1.8.7"
}
```

With this test, we pass the `-n` flag when `echo`ing the expected version number to the new version file.  This flag asserts that the shell does not append a trailing newline character to the file, as is normally standard behavior for this command.  We then run the `version-file-read` command and assert that it was successful, and that the expected version number was sent to STDOUT.

Next test:

```
@test "ignores carriage returns" {
  cat > my-version <<< $'1.9.3\r'
  run rbenv-version-file-read my-version
  assert_success "1.9.3"
}
```

This test asserts that the `version-file-read` command trims off trailing `\r` characters (aka carriage returns) before outputting the version number to STDOUT.

Next test:

```
@test "prevents directory traversal" {
  cat > my-version <<<".."
  run rbenv-version-file-read my-version
  assert_failure "rbenv: invalid version in \`my-version'"

  cat > my-version <<<"../foo"
  run rbenv-version-file-read my-version
  assert_failure "rbenv: invalid version in \`my-version'"
}
```

Here we assert that strings which would normally cause directory traversal to happen (i.e. "..") will trigger a failure in the `version-file-read` command.

This test is a bit unexpected for me, since I would have assumed the only logic needed for this command would be related to trimming whitespace and extraneous characters or lines.  The only way I would expect a string like ".." to cause directory traversal in this case is if `version-file-read` takes the input argument and attempts to pass it to a command like `cd`.  I decide to look up the issue and/or commit which introduced this test.

I find [this issue](https://github.com/rbenv/rbenv/issues/977) in the Github history, which describes a security vulnerability reported by another contributor.  It looks like an earlier version of RBENV included the possibility of using a version of Ruby other than that intended by the user, if a malicious person was somehow able to modify the victim's RBENV version file.  A description of the vulnerability from the issue:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-1055am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

By injecting the un-sanitized value of `VERSION` into the path that RBENV uses to find its version of Ruby, it could be possible for an attacker to redirect that path to one controlled by the attacker.  The consequences of that depend on what happens after that directory path is redirected.  Could an attacker subsequently plant a malicious executable also named `ruby` in the location where RBENV would normally look for the non-malicious Ruby executable?  Could an attacker therefore cause arbitrary code to be executed on the victim's machine?  I don't know enough about security to discount that as a possibility, but from reading the conversation in the Github issue, it sounds like this issue is a low priority from a security standpoint, so I'm gonna guess that my hypothesis is doubtful.

Regardless, this was an interesting little tangent!

Next and last spec:

```
@test "disallows path segments in version string" {
  cat > my-version <<<"foo/bar"
  run rbenv-version-file-read my-version
  assert_failure "rbenv: invalid version in \`my-version'"
}
```

This test was introduced in the same PR that introduced the previous test.  It asserts that `version-file-read` takes steps to prevent strings which resemble directories from being included in the version file that it reads.  We create a version file with `foo/bar` as its contents, then pass that file to the command and assert that it fails with a helpful error message.

Onto the file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file-read)

The usual first block of code:

```
#!/usr/bin/env bash
# Usage: rbenv version-file-read <file>
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

The `bash` shebang
"Usage" comments
Tell the shell to exit on the first exception
Tell the shell to output verbose loglines when `RBENV_DEBUG` is set
Next block of code:

```
VERSION_FILE="$1"
```

We store the first argument in a variable named `VERSION_FILE`.

Next block of code:

```
if [ -s "$VERSION_FILE" ]; then
  # Read the first word from the specified version file. Avoid reading it whole.
  IFS="${IFS}"$'\r'
  read -n 1024 -d "" -r version _ <"$VERSION_FILE" || :

  ...
fi
```

(stopping here for the day; 72302 words)

First we test if the value stored in `VERSION_FILE` actually represents an existing file (this is what the `-s` flag does).  If so, we modify the value of the internal field separator to be its original value, plus something extra.  I was initially confused about what that "something extra" was, specifically the dollar sign followed by single-quotes.  I was under the impression that dollar signs were used for parameter or variable expansion, but that double-quotes were required for this (as well as either a variable or curly braces / parentheses).  I Googled "bash dollar sign plus single quote" and [this StackOverflow answer](https://web.archive.org/web/20220929180039/https://stackoverflow.com/questions/11966312/how-does-the-leading-dollar-sign-affect-single-quotes-in-bash) comes up as the first search result.  One of the comments underneath the question points to [a page of bash documentation](https://web.archive.org/web/20220614132338/https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html), and that page contains the following info:

Words of the form $'string' are treated specially. The word expands to string, with backslash-escaped characters replaced as specified by the ANSI C standard. Backslash escape sequences, if present, are decoded as follows:

...
\r
carriage return
...

Now I think I see what's happening here.  The line of code...

```
IFS="${IFS}"$'\r'
```

...means that we're concatenating the 'carriage return' character to the end of the original set of `IFS` characters.  Much clearer.

Next:

```
read -n 1024 -d "" -r version _ <"$VERSION_FILE" || :
```

Here we read up to the first 1024 characters of the file.  According to `help read`:

> If -n is supplied with a non-zero NCHARS argument, read returns after NCHARS characters have been read.
>
> If the -r option is given, this signifies `raw' input, and backslash escaping is disabled.

The `-d ""` syntax is a bit weird, and it took a lot of Googling before I could get my head around it.  What eventually worked was Googling `"read -d" plus IFS bash`, after which I found [this link](https://archive.ph/jWSEH) as the 2nd result:

> With `-d ''` it sets the delimiter to `'\0'` and makes `read` read the whole input in one instance, and not just a single line. `IFS=$'\n'` sets newline (`\n`) as the separator for each value. `__` is optional and gathers any extra input besides the first 3 lines.

I interpret this to mean that we read the whole contents of "$VERSION_FILE", not just the first line, and that the input which is read is then delimited according to the value of `IFS` that we set on the previous line.

The "_" at the end is used to store any subsequent variables read by the `read` command after the first one, which is stored in a variable named `version`.  The use of the underscore character is a convention (at least in Ruby) to indicate that the variable is a throwaway value, and will not be used subsequently.

Lastly, [this StackOverflow article](https://web.archive.org/web/20220804070349/https://superuser.com/questions/1022374/what-does-mean-in-the-context-of-a-shell-script) mentions the `|| :` syntax.  I found it when I Googled `bash "|| :"`.  Judging from the following answer, it appears that the intention of `|| :` is to prevent the `read` command from returning a non-successful exit code:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-1058am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So to summarize the `read -d` line of code, we're taking the first non-whitespace line from the input file, trimming any whitespace from that line, trimming anything after the `IFS` value (which now includes the carriage return character in addition to whatever its previous value was), and storing it as the version number of record for the subsequent lines of code.

As a follow-up, it looks like this `read -d` line of code was a refactor of the previous version of similar logic, which looked like this [according to Github](https://github.com/rbenv/rbenv/pull/1393/files):

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-1100am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

According to the `man cut` entry, the job of `cut` is to "cut" out the specified portion (in this case, the first 1024 bytes) of the specified file (in this case, "$VERSION_FILE"):

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-1101am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

So it looks like `read -d` was just a way to one-line some logic which previously took up multiple lines.  As far as why we limit to the first 1024 bytes, the Github history reveals this PR is origin of the 1024-byte limit, but the description doesn't say why it was introduced.  I'm assuming that's a performance optimization, but I can't be sure.
—------------
Tangent: Trimming whitespace

While Googling around, I also searched for `"-d" read bash`, and I got [this link](https://archive.ph/Xkto2) as the first result.  Among other things, it mentions:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-1102am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I remember that the specs mentioned that leading spaces should be ignored, so I assume that's at least partially why this command is used.  However I was confused about how the above command leads to the whitespace being trimmed, i.e. which part of this command was the key to the whitespace being trimmed.  I hypothesized that maybe it's the `read` command itself which does the trimming.  To test this, I did the following in my terminal:

```
$ read foo <<< "   doo   "

$ echo "${#foo}"

3
```

The command `read foo` stores the contents of `read` in the variable `foo`.  And the `<<<` command directs the subsequent string into the STDIN of `read`.  We then `echo` the length of the `foo` string (adding `#` before the variable inside a parameter expansion causes the variable to be expanded into the length of the variable).  If the leading and trailing whitespaces were preserved, we'd expect the length to be equal to the # of original characters, including the whitespaces (3 spaces before and after), so 9 in this case.  But since these spaces were trimmed, we instead just get 3 characters (i.e. the length of `doo` by itself).

Next block of code:

```
  if [ "$version" = ".." ] || [[ $version == */* ]]; then
    echo "rbenv: invalid version in \`$VERSION_FILE'" >&2
  elif [ -n "$version" ]; then
    echo "$version"
    exit
  Fi
```

First we check whether there is an attempt to traverse directories by using either ".." or a string which resembles a path, i.e. a string including a forward-slash.  If either of these conditions returns true, we echo an error message to STDERR.  Note that there is no exit inside this conditional branch, the way there is in the subsequent `elif` branch.  We simply exit the `if` condition and continue to the next line of code, which happens to be `exit 1` (see below).

Otherwise, if there's a non-empty string stored in "$version", we simply echo that string and exit with a successful exit code.

Last bit of code in this file:

```
exit 1
```

We'd reach this line of code if there was no value set for "$version", or if there was a value but it was set to one of the conditions in the `if` block above (i.e. `[ "$version" = ".." ]` or `[[ $version == */* ]]`).  In either case, we exit with a non-success return code.

Note that there is no validation of the contents which are read from the specified file, at least not inside the `version-file-read` command.  We don't check that the printed file contents represent a valid Ruby version; we just strip the whitespace and prevent directory traversal, and then print the rest to STDOUT.  The Ruby version validation is expected to be performed in the consumer of this command.

On to the next file.
