As usual, let’s look at the test file first!

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/shims.bats)

After the `bats` shebang and the loading of `test_helper`, the first spec is:

```
@test "no shims" {
  run rbenv-shims
  assert_success
  assert [ -z "$output" ]
}
```

This test asserts that, when there are in fact no shims installed, running `rbenv shims` completes successfully but prints nothing to the screen.

Next spec:

```
@test "shims" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/ruby"
  touch "${RBENV_ROOT}/shims/irb"
  run rbenv-shims
  assert_success
  assert_line "${RBENV_ROOT}/shims/ruby"
  assert_line "${RBENV_ROOT}/shims/irb"
}
```

This test creates the `shims/` sub-directory inside `RBENV_ROOT`, along with two shim sub-directories inside `shims/`.  Then when we run the command under test, we assert that it completed successfully and that the output included the full paths to the two shims we created.

Next and last spec:

```
@test "shims --short" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/ruby"
  touch "${RBENV_ROOT}/shims/irb"
  run rbenv-shims --short
  assert_success
  assert_line "irb"
  assert_line "ruby"
}
```

Here we do the same setup as in the last spec, but when we run the command, we pass the `--short` argument.  We then assert that, instead of getting the full filepaths, we just get the shims’ names.

On to the file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-shims)

The first block of code is:

```
#!/usr/bin/env bash
# Summary: List existing rbenv shims
# Usage: rbenv shims [--short]

set -e
[ -n "$RBENV_DEBUG" ] && set -x

# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --short
  exit
fi
```

This is old hat by now:

The `bash` shebang
The “Summary” and “Usage” comments
`set -e` to exit after the first error
Setting verbose mode when `RBENV_DEBUG` is passed.
Completion instructions (only the `--short` argument is available for `rbenv shims`)

Next block of code:

```
shopt -s nullglob
```

Here we set the `nullglob` shell option, so that any filepath patterns which don’t expand into actual files to instead expand into the null string, so that an attempt to iterate over the list of filepaths will instead iterate zero times.

Last block of code:

```
for command in "${RBENV_ROOT}/shims/"*; do
  if [ "$1" = "--short" ]; then
    echo "${command##*/}"
  else
    echo "$command"
  fi
done | sort
```

For each item in the "${RBENV_ROOT}/shims/" directory (which contains our list of shim files), we echo a string representing that shim.  If the `--short` argument was passed, we shave off the parent filepath and only print the filename.  If no `--short` argument was passed, we print the entire filepath.

As a last step, we take the series of printed shim names (or filepaths) and sort them alphabetically.

That’s it for this file!  It was a short one, for sure.

Next file.
