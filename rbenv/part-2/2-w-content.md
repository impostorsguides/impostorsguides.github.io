Let's start with the "Summary" and "Usage" comments.

## "Summary" and "Usage" comments

```
# Usage: rbenv version-file [<dir>]

# Summary: Detect the file that sets the current rbenv version
```

Looks like we specify a directory in which we want to search for a version file.

To try this out, I make a new directory and add a `.ruby-version` file to it:

```
$ mkdir foo && cd $_

$ echo 2.7.6 > .ruby-version

$ rbenv version-file .

./.ruby-version
```

The command prints out the file name, using the same shortened `./` syntax I used when I passed the directory as an argument.

I try again with the full `/path/to/directory` as an argument:

```
$ rbenv version-file ~/Workspace/OpenSource/foo

/Users/myusername/Workspace/OpenSource/foo/.ruby-version
```

With the full path as an argument, I get the full path to the `.ruby-version` as a response.

Lastly, I remove the `.ruby-version` file and re-run the command:

```
$ rm .ruby-version

$ rbenv version-file ~/Workspace/OpenSource/foo

$
```

No big surprises here.  If we delete the `.ruby-version` file in a directory, no output is returned from the command.

Moving on to the test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-file.bats){:target="_blank" rel="noopener"}

### Setup steps

After the `bats` shebang and the import of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This helper function just makes a test directory and `cd`s into it.  We've seen this before- `setup()` is called by the BATS test runner.

### Creating a Ruby version file

Next block of code:

```
create_file() {
  mkdir -p "$(dirname "$1")"
  echo "system" > "$1"
}
```

This helper function takes in a path to file (i.e. `path/to/filename`) and creates the file's parent directory (i.e. `path/to/`).  It then creates a file named `filename` and adds the string `system` to it.

From this, we can infer that the purpose of the file is to contain the current Ruby version for RBENV to read from.

### When the version is set globally

Next block of code (and first test):

```
@test "detects global 'version' file" {
  create_file "${RBENV_ROOT}/version"
  run rbenv-version-file
  assert_success "${RBENV_ROOT}/version"
}
```

Here we create the global "version" file using our `create_file` helper method (which populates that global version file with the string "system"), and run the command.  We then assert that the command was successful, and that the output was the path to the version file we just created.

### No version file, and no directory specified

Next block of code:

```
@test "prints global file if no version files exist" {
  assert [ ! -e "${RBENV_ROOT}/version" ]
  assert [ ! -e ".ruby-version" ]
  run rbenv-version-file
  assert_success "${RBENV_ROOT}/version"
}
```

Here we start with some sanity-check assertions:

- one to assert that the global `version` file doesn't already exist, and
- the other to assert that a local `.ruby-version` file does not exist either.

We then assert that the command is successful and its output is the same global `version` file.

This is a bit unexpected IMO, since if the first sanity-check assertion passed then that file shouldn't exist.  Why would we lead the user to think the version is set by a file that doesn't actually exist?

TODO- answer the above question.

### When the version is set in the current directory

Next test:

```
@test "in current directory" {
  create_file ".ruby-version"
  run rbenv-version-file
  assert_success "${RBENV_TEST_DIR}/.ruby-version"
}
```

 - We start by creating the `.ruby-version` file in our local directory.
    - Remember that the `create_file` function uses the `dirname` command, which creates a directory based on the `path/to/filename` that is passed as a parameter.
    - If no `path/to/` is given, it returns the current directory, which means `.ruby-version` is created inside the current directory.
 - We then run the command under test and assert that the Ruby version was pulled from that local `.ruby-version` file.

### When the version is set in the parent directory

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

 - We create the same `.ruby-version` file in the current directory.
 - Then we create a sub-directory named `project` and `cd` into that, meaning our `.ruby-version` file is now in our parent directory.
 - Then we run `rbenv version-file` and assert that it returns the path to the version file from the parent directory.

### When both current and parent directory contain `.ruby-version` files

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

- We create 2 Ruby version files- one in the current directory and one in a new sub-directory.
- We then navigate to the sub-directory and run the `rbenv version-file` command.
- Lastly, we assert that:
    - the command was successful, and that
    - the version file returned as output was the file from the sub-directory (i.e. the one we're currently in), *not* the one from the parent directory.

### When a sibling directory has a `.ruby-version` file

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

- We create two Ruby version files in two different sub-directories, each of which is new.
- We then navigate into one of them, but when we run the `rbenv version-file` command, we specify the *other* directory as our `RBENV_DIR`.
- Lastly, we assert that:
  - the command was successful, and that
  - the sub-directory we specified (i.e. the other one, *not* the one we're currently in) is the one used to source the Ruby version.

### When a sibling directory does NOT have a `.ruby-version` file

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

- We create a directory named `widget/blank`.
- We then create a directory which is a sibling of `widget` named `project`, containing the `.ruby-version` file.
- Next, we navigate into that `project` directory.
- We run the command, specifying the other directory (`widget/blank`) as our `RBENV_DIR`.
- Lastly, we assert that:
    - the command was successful, and also that
    - the Ruby version file in our *current* directory (the one **with** the `.ruby-version` file) was printed as the output of our command, *even though* we specified another directory as our `RBENV_DIR`.

### When the target directory contains a `.ruby-version` file

Next test:

```
@test "finds version file in target directory" {
  create_file "project/.ruby-version"
  run rbenv-version-file "${PWD}/project"
  assert_success "${RBENV_TEST_DIR}/project/.ruby-version"
}
```

This test creates a Ruby version file inside a new sub-directory named `project`.  We then run `rbenv version-file` and pass an argument containing the new sub-directory we just created.  We assert the command was successful and that the printed output contains the path to our newly-created version file.

### Sad path- no version file, but a directory **was** specified

Last test:

```
@test "fails when no version file in target directory" {
  run rbenv-version-file "$PWD"
  assert_failure ""
}
```

Here we test the sad-path case where we haven't created a local *or* a global Ruby version file.  We simply run the command without any setup steps, and assert that the command failed and that there was no meaningful output.

You may be wondering how the test above is different from the test with the description `"prints global file if no version files exist"`.  The difference is that our current test specifies an argument when it runs `rbenv version-file` (`$PWD`), while the earlier test does not.  We'll get to the specifics below, but for now we'll just say that, when there's no version file:

- passing an argument causes the code to go down a different branch of logic than not passing an argument.  The former ends with a non-zero exit code and no output, which is what this test covers.
- On the other hand, the latter case ends with `echo`ing the string `"${RBENV_ROOT}/version"` (even if that version file doesn't exist, as we saw in the earlier test), and a 0 exit code.

Now on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file){:target="_blank" rel="noopener"}

Let's get the repetitive stuff over with:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

- `set -e` to tell the shell to exit immediately when it encounters an error
- Set the shell's "verbose" mode when the `RBENV_DEBUG` env var is set

### Storing the target directory

Next block of code:

```
target_dir="$1"
```

Here we're just setting a variable named `target_dir` equal to the first argument passed to `rbenv version-file`.

### Searching for the local version file

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

The condition for this loop is "Does the local `root` variable match this regular expression?", which is then negated to mean "Is the local `root` variable *different from* this regular expression?".  But what does the regular expression signify?

I find the meaning of the regular expression hard to deduce.  I suspect that the intention of the `while` loop is to keep checking progressively higher parent directories until a `.ruby-version` file was found, stopping at the machine's root directory of "/" if nothing was found.

To test this, I add an `echo` statement to the inside of the `while` loop, to print the value of the `root` variable:

```
find_local_version_file() {
  local root="$1"
  while ! [[ "$root" =~ ^//[^/]*$ ]]; do
    echo "root: $root"  >> /Users/myusername/.rbenv/results.txt     # I added this line
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

When I run the last test in the test file, and print out the `/Users/myusername/.rbenv/results.txt` file, I see:

```
$ cat results.txt

root: /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.Dk5
root: /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T
root: /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp
root: /var/folders/tn
root: /var/folders
root: /var
root:
```

So it looks like we were right about the logic inside the while loop- we progressively go up one parent directory at a time, looking for the `.ruby-version` file.

But when there's no more parent directories left (i.e. we're already as high as we can go in the directory structure), we have to exit out of the while loop.  If we don't, we'll be stuck in an infinite loop.  We can therefore conclude that this is the intent of the condition in the `while` loop- to exit out when we're already as high as we can go (i.e. when we've shaved off the last of the "forward-slash plus text" blocks and now have an empty string).

So even though I can't explicitly state what each character in the above regex does, we were still able to deduce its overall meaning, which is valuable in itself.

### When the user has passed an argument

Next block of code:

```
if [ -n "$target_dir" ]; then
  find_local_version_file "$target_dir"
```

If the user passed an argument to the `version-file` command, and  `$target_dir` is therefore not an empty variable, then we run our `find_local_version_file` helper function on that argument.  In this case, the `rbenv version-file` command will return whatever `find_local_version_file "$target_dir"` returns.  If that command returns a non-zero exit code or prints an empty string, then so will our `rbenv version-file` command.

What about if `$target_dir` is empty, i.e. if the user didn't pass an argument?

### When the user has **not** passed an argument

```
else
  find_local_version_file "$RBENV_DIR" || {
    [ "$RBENV_DIR" != "$PWD" ] && find_local_version_file "$PWD"
  } || echo "${RBENV_ROOT}/version"
fi
```

In that case, we run that same `find_local_version_file` function.  But instead of passing `$target_dir` as an argument, we try 3 different strategies.

- First, we search for `.ruby-version` inside whatever `RBENV_DIR` is set to.
- If that fails, we check whether `RBENV_DIR` is equal to the current directory.  If it's not, then we search for `.ruby-version` in the current directory.
- As a last resort, we simply echo the `version` file from the `RBENV_ROOT` directory (*regardless* of whether or not it even exists).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

To summarize:

If we pass an argument to `rbenv version-file`, that means the user wants to check a specific directory on their machine.  They're not interested in any other directory but that one.

So it makes sense that the above `if/else` block wouldn't have the same number of `||` or-checks in the `if` block (when the user **did** specify a directory) that we have if the `else` block (when the user did **not** specify a directory).

It might seem misleading to tell the user that their Ruby version is set by `~/.rbenv/version`, when that file potentially doesn't exist.  The reason we do so is because, [according to the core team](https://github.com/rbenv/rbenv/discussions/1510){:target="_blank" rel="noopener"}, the intent of the `rbenv version-file` command is to describe where the version number **is expected to be** set, not (necessarily) where it **is being** set.

That's it for the `version-file` file.  On to the next file.
