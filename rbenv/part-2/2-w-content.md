Test file comes first:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-file.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the import of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This helper function just makes a test directory and `cd`s into it.

(stopping here for the day; 68919 words)

Next block of code:

```
create_file() {
  mkdir -p "$(dirname "$1")"
  echo "system" > "$1"
}
```

This helper function takes in a path to file (i.e. `path/to/filename`) and creates the file's parent directory (i.e. `path/to/`), then creates a file named `filename` and adds the string `system` to it.  From this, we can infer that the purpose of the file is to contain the current Ruby version for RBENV to read from.

Next block of code (and first test):

```
@test "detects global 'version' file" {
  create_file "${RBENV_ROOT}/version"
  run rbenv-version-file
  assert_success "${RBENV_ROOT}/version"
}
```

Here we create the global "version" file using our `create_file` helper method (which populates that global version file with the string "system"), and run the command.  We then assert that the command was successful, and that the output was the path to the version file we just created.

From this, we can deduce that the purpose of the `rbenv version-file` command is to return the path to the file which sets the current Ruby version.

Next block of code:

```
@test "prints global file if no version files exist" {
  assert [ ! -e "${RBENV_ROOT}/version" ]
  assert [ ! -e ".ruby-version" ]
  run rbenv-version-file
  assert_success "${RBENV_ROOT}/version"
}
```

Here we start with some sanity-check assertions- one to assert that the global `version` file doesn't already exist, and the other to assert that a local `.ruby-version` file does not exist either.  We then assert that the command is successful and its output is the same global `version` file.  This is a bit weird, since if the first sanity-check assertion passed then that file shouldn't exist.  Why would we lead the user to think the version is set by a file that doesn't actually exist?  I add this to my running list of questions to come back to, and keep moving.

Next test:

```
@test "in current directory" {
  create_file ".ruby-version"
  run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/.ruby-version"
}
```

Here we start by creating the `.ruby-version` file in our local directory.  Remember that the `create_file` function uses the `dirname` command, which creates a directory based on the `path/to/filename` that is passed as a parameter.  If no `path/to/` is given, it returns the current directory, which means `.ruby-version` is created inside the current directory.  We then run the command under test and assert that the Ruby version was pulled from that local `.ruby-version` file.

Next test:

```
@test "in parent directory" {
  create_file ".ruby-version"
  mkdir -p project
  cd project
  run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/.ruby-version"
}
```

Here we create the same `.ruby-version` file in the current directory, but then we create a sub-directory named `project` and `cd` into that, meaning our `.ruby-version` file is now in our parent directory.  Then we run `rbenv version-file` and assert that it returns the path to the version file from the parent directory.

Next test:

```
@test "topmost file has precedence" {
  create_file ".ruby-version"
  create_file "project/.ruby-version"
  cd project
  run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/project/.ruby-version"
}
```

Here we create 2 Ruby version files- one in the current directory and one in a new sub-directory.  We then navigate to the sub-directory and run the `rbenv version-file` command.  We assert that the command was successful and that the version file returned as output was the file from the sub-directory (i.e. the one we're currently in), *not* the one from the parent directory.

Next test:

```
@test "RBENV_DIR has precedence over PWD" {
  create_file "widget/.ruby-version"
  create_file "project/.ruby-version"
  cd project
  RBENV_DIR="${RBENV_TEST_DIR}/widget" run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/widget/.ruby-version"
}
```

Here we create two Ruby version files in two different sub-directories, each of which is new.  We then navigate into one of them, but when we run the `rbenv version-file` command, we specify the *other* directory as our `RBENV_DIR`.  We assert that the command was successful and that the sub-directory we specified (i.e. the other one, *not* the one we're currently in) is the one used to source the Ruby version.

Next test:

```
@test "PWD is searched if RBENV_DIR yields no results" {
  mkdir -p "widget/blank"
  create_file "project/.ruby-version"
  cd project
  RBENV_DIR="${RBENV_TEST_DIR}/widget/blank" run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/project/.ruby-version"
}
```

Here we create a directory + sub-directory named `widget/blank`, and then create a directory which is a sibling of `widget` named `project` containing the `.ruby-version` file.  We then navigate into that `project` directory.  We run the command, specifying the `widget/blank` directory as our `RBENV_DIR`.  We assert the command was successful, and also that the Ruby version file in our *current* directory was printed as the output of our command (*even though* we specified another directory as our `RBENV_DIR`.

Next test:

```
@test "finds version file in target directory" {
  create_file "project/.ruby-version"
  run rbenv-version-file "${PWD}/project"
  assert_success "${RBENV_TEST_DIR}/project/.ruby-version"
}
```

This test creates a Ruby version file inside a new sub-directory named `project`.  We then run `rbenv version-file` and pass an argument containing the new sub-directory we just created.  We assert the command was successful and that the printed output contains the path to our newly-created version file.

Last test:

```
@test "fails when no version file in target directory" {
  run rbenv-version-file "$PWD"
  assert_failure ""
}
```

Here we test the sad-path case where we haven't created a local *or* a global Ruby version file.  We simply run the command without any setup steps, and assert that the command failed and that there was no meaningful output.

Speaking of "no meaningful output", that's a bit of a bummer.  If an error occurred, *shouldn't* there be a helpful error message so the user can take corrective action?  That could be a good candidate for a future PR.

Anyway, on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file){:target="_blank" rel="noopener"}

Let's get the repetitive stuff over with:

```
#!/usr/bin/env bash
# Usage: rbenv version-file [<dir>]
# Summary: Detect the file that sets the current rbenv version
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

`bash` shebang
"Usage" + "Summary" info
`set -e` to tell the shell to exit immediately when it encounters an error
Set the shell's "verbose" mode when the `RBENV_DEBUG` env var is set

Next block of code:

```
target_dir="$1"
```

Here we're just setting a variable named `target_dir` equal to the first argument passed to `rbenv version-file`.

Next block of code:

```
find_local_version_file() {
  local root="$1"
  while ! [[ "$root" =~ ^//[^/]*$ ]]; do
    if [ -s "${root}/.ruby-version" ]; then
      echo "${root}/.ruby-version"
      return 0
    fi
    [ -n "$root" ] || break
    root="${root%/*}"
  done
  return 1
}
```

We create a helper function named `find_local_version_file`.  This takes a single argument, which we store in a local variable named `root`.

We then create a `while` loop:

```
  while ! [[ "$root" =~ ^//[^/]*$ ]]; do
  ...
  done
```

The condition for this loop is "Does the local `root` variable match this regular expression?", which is then negated to mean "Does the local `root` variable *not* match this regular expression?".  However, I find the meaning of the regular expression hard to deduce.  From the context, I had guessed that the intention of the `while` loop was to keep checking progressively higher parent directories until a `.ruby-version` file was found, stopping at the machine's root directory of "/" if nothing was found.  However, I just tried an experiment where I tested the condition at my machine's root directory, and I found it was still `false`:

```
$ is_foo ()
{
    if [[ "$1" =~ ^//[^/]*$ ]]; then
        echo "True";
    else
        echo "False";
    fi
}
$ cd /
$ is_foo "$(pwd)"

False
```

(stopping here for the day; 70012 words)

In my opinion, the documentation on regular expressions in bash is lacking.  The closest things I can find to "official documentation" in Google are [an HTML version](https://web.archive.org/web/20220923034514/https://man7.org/linux/man-pages/man7/regex.7.html){:target="_blank" rel="noopener"} of the `man` page on regular expressions, and [the bash reference manual](https://web.archive.org/web/20221012211520/https://www.gnu.org/software/bash/manual/bash.html){:target="_blank" rel="noopener"}, which contains information on regexes but it's inter-mingled with a ton of other info that the reader must wade through.  The first link has zero examples (wtf!!!); it's just a wall of text.  It reads like the author thinks documentation is an after-thought, a waste of time.  I'm sorry, but it does.  I'm struggling to relate to the kind of mentality that sees a man page like this and says "It's perfect, ship it as-is."  The 2nd link, thankfully, at least has a few examples scattered throughout.  But there's no dedicated "Regex" section demarcated by its own heading, and the examples don't contain the exhaustive set of bash regex features.  Regular expressions are already one of the most inscrutable features in programming.  One would think the authors of the feature would err on the side of clarity and exhaustiveness when trying to document said feature.

Eventually I did find [this link](https://web.archive.org/web/20220923033933/https://www.gnu.org/software/grep/manual/html_node/Regular-Expressions.html){:target="_blank" rel="noopener"}, also from GNU.org, but it's part of the `man` entry for the `grep` command.  It's unexpected that what appears to be the canonical reference on bash regexes is located inside the docs for a specific command, when there are many commands which use regexes.

Rather than continue to bang my head against the wall in search of documentation that clearly doesn't want to be found, I decide to infer what the regex does through its behavior.  I add some `echo` statements to the function and paste the updated function into my terminal:

```
find_local_version_file() {
  local root="$1"
  while ! [[ "$root" =~ ^//[^/]*$ ]]; do
    echo "root: $root"                              # I added this line
    if [ -s "${root}/.ruby-version" ]; then
      echo "${root}/.ruby-version"
      return 0
    fi
    [ -n "$root" ] || break
    root="${root%/*}"
  done
  echo "final root: $root"                          # I added this line
  return 1
}
```

To try this code out, I first paste the above function in my terminal.  Then I create a series of directories and sub-directories, called `foo/bar/baz`.  I place a `.ruby-version` file inside `foo/`.  I then navigate to `baz/`, and call the above function:

```
bash-3.2$ find_local_version_file() {
>   local root="$1"
>   while ! [[ "$root" =~ ^//[^/]*$ ]]; do
>     echo "root: $root"
>     if [ -s "${root}/.ruby-version" ]; then
>       echo "${root}/.ruby-version"
>       return 0
>     fi
>     [ -n "$root" ] || break
>     root="${root%/*}"
>   done
>   echo "final root: $root"
>   return 1
> }

bash-3.2$ mkdir -p foo/bar/baz

bash-3.2$ touch foo/.ruby-version

bash-3.2$ cd foo/bar/baz

bash-3.2$ find_local_version_file $(pwd)

root: /Users/myusername/Workspace/OpenSource/impostorsguides.github.io/foo/bar/baz
root: /Users/myusername/Workspace/OpenSource/impostorsguides.github.io/foo/bar
root: /Users/myusername/Workspace/OpenSource/impostorsguides.github.io/foo
root: /Users/myusername/Workspace/OpenSource/impostorsguides.github.io
/Users/myusername/Workspace/OpenSource/impostorsguides.github.io/.ruby-version

bash-3.2$
```

We can see what happens here in the happy-path, when there *is* a `.ruby-version` file somewhere in the directory hierarchy- we progressively navigate up one directory at a time until we find what we're looking for, and then we echo the path to the version file.  This "navigating up one directory at a time" is accomplished by the `while` loop, in conjunction with the line `root="${root%/*}"`, which sets `root` equal to its previous value, minus the final forward-slash character and anything after it.

So again, that's the happy-path.  I then navigate to `~/Workspace/OpenSource`, where I know there is no `.ruby-version` file (and where I suspect there is no such file in any of the parent directories), and run the same command again:

```
bash-3.2$ find_local_version_file $(pwd)

root: /Users/myusername/Workspace/OpenSource
root: /Users/myusername/Workspace
root: /Users/myusername
root: /Users
root:
final root:

bash-3.2$
```

Here we see the same behavior happening (root is set to its previous value, minus the final `/` and everything after it).  But when there's nothing left to shave off (i.e. we're already as high as we can go in the directory structure), we have to exit out of the while loop, or else we'll be stuck in an infinite loop.  I think we can therefore conclude that this is the intent of the condition in the `while` loop- to exit out when we're already as high as we can go (i.e. when we've shaved off the last of the "forward-slash plus text" blocks and now have an empty string).

So even though I can't explicitly state what each character in the above regex does, we were still able to deduce its overall meaning, which is valuable in itself.

Next block of code:

```
if [ -n "$target_dir" ]; then
  find_local_version_file "$target_dir"
else
  find_local_version_file "$RBENV_DIR" || {
    [ "$RBENV_DIR" != "$PWD" ] && find_local_version_file "$PWD"
  } || echo "${RBENV_ROOT}/version"
fi
```

If `$target_dir` is not an empty variable (i.e. if the user passed an argument to the `version-file` command), then we run our `find_local_version_file` helper function on that argument.

Otherwise, we run that same function on the current `RBENV_DIR` directory, which in my experience is usually the current directory.  If that returns an empty string, then we check whether `RBENV_DIR` is equal to the current directory.  If it's not, then we run our helper function on the current directory.  If it is the same, we do nothing.  Then if that either/or operation returns nothing, we simply echo the `version` file from the `RBENV_ROOT` directory (*regardless* of whether or not it actually exists).  I'm not sure why we don't check for the existence of that version file first; it seems misleading to print out the path to a file that potentially doesn't exist.

I want to be able to post a Github issue asking about this, but I'm still feeling self-conscious about the recent long-winded PR I posted that was rejected.  I feel like I wasted Mislav's time with that, and I care about developing a reputation as someone who consistently makes valuable contributions and whose signal-to-noise ratio is high.  So I'm going to sit on my question until I'm feeling more confident in the reputation I've built.

That's it for the `version-file` file.  Next file.
