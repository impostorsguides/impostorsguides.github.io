Over the past 20-ish posts, we've learned about:

 - the `sed` command, what it does, and how it's used.
 - finding all the interpretations of a command (not just the first one) via the `type` command's `-a` flag
 - finding the canonical path (not just a symlink) via the `type` command's `-P` flag
 - trimming text with the `tr` command
 - getting just the filename from a path/to/filename using the `basename` command
 - the `awk` command, what it does, and how it's used.
 - using the shell's `hash` feature to save time when looking up the locations of command files
 - using the `trap` command to tell Bash to execute arbitrary logic when the shell receives certain signals
 - what shell signals are, and some common examples
 - finding the difference between two files using the `diff` command
 - filename expansion (aka "globbing") using the `*` symbol plus `shopt -s nullglob`
 - building arrays in Bash, using parentheses (ex.- `foo=(1 2 3 4 5)`).
 - iterating over arrays in Bash, using parameter expansion (ex.- `for item in ${foo[@]}`).
 - the advantages of testing behavior vs. testing implementation
 - unsetting shell variables via the `unset` command
 - testing whether a variable is set to an empty string using `+x` inside parameter expansion, i.e. `[ -n "\${RBENV_VERSION_OLD+x}" ]`
 - expanding escape sequences using dollar signs plus single quotes, i.e. `$'\r'`
 - how to sort lines in a file using the `sort` command, including how to specify multiple sort keys (with the `-k` flag) and non-default delimiters (with the `-t` flag)
 - Using indirect parameter expansion via `"${ ... }"` plus `!` to turn a named variable passed as an argument into the argument's value.
 - How to use ANSI-C quoting to ensure that Bash interprets escape sequences (such as `\n`) as special characters, instead of literal characters.

There's a few more directories to cover, but they've each only got a few files in them:

 - The `rbenv.d/` directory
 - The `completions/` directory
 - The `.github/` directory
 - The `src/` directory
 - A few files in the root project directory:
  - `.gitignore`
  - `LICENSE`

We're in the final stretch.  Let's move on to the final section.
