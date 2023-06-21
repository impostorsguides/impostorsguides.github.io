Over the past 20-ish posts, we've learned about:

 - the `sed` command, what it does, and how it's used.
 - the `awk` command, what it does, and how it's used.
 - finding all the interpretations of a command (not just the first one) via the `type` command's `-a` flag
 - finding the canonical path (not just a symlink) via the `type` command's `-P` flag
 - trimming text with the `tr` command
 - getting just the filename from a path/to/filename using the `basename` command
 - using the shell's `hash` feature to save time when looking up the locations of command files
 - using the `trap` command to tell `bash` to execute arbitrary logic when the shell receives certain signals
 - what shell signals are, and some common examples
 - finding the difference between two files using the `diff` command
 - filename expansion (aka "globbing") using the `*` symbol plus `shopt -s nullglob`
 - building arrays in `bash`, using parentheses (ex.- `foo=(1 2 3 4 5)`).
 - iterating over arrays in `bash`, using parameter expansion (ex.- `for item in ${foo[@]}`).
 - the advantages of testing behavior vs. testing implementation
 - unsetting shell variables via the `unset` command
 - testing whether a variable is set to an empty string using `+x` inside parameter expansion, i.e. `[ -n "\${RBENV_VERSION_OLD+x}" ]`
 - expanding escape sequences using dollar signs plus single quotes, i.e. `$'\r'`
