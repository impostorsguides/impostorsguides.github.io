## What We Learned

We covered a lot in this series, including:

 - What dotfiles and dot directories are
 - What version management is, and why it matters
 - What shims are
 - What a shebang is
 - What the `PATH` variable is, and how it's used
 - What the `set` command is, and how it's used
 - Using `set -e` to tell a `bash` script to exit immediately upon encountering an error
 - Using `set -x` to tell a `bash` script to run in verbose mode
 - How to look up documentation on our machine, using both the `man` and `help` commands
 - How to search the `man` and `help` pages if we're looking for a specific term
 - What a "shell" is
 - What a `.zshrc` file is
 - What POSIX is
 - What a "builtin" command is
 - How to find out which shell is your machine's default
 - How to form hypotheses on what our code does, and then run experiments to prove or disprove our hypotheses.
 - How to write boolean conditions in a shell script using the `[` or `test` command, as well as some useful flags for it (such as `-n` and `-f`).
 - How to conditionally execute arbitrary program logic based on the truthiness or falsiness of the above boolean conditions, using either `if` statements or `&&` one-liners.
 - What parameter expansion is, how to use it, and some common use cases
 - double- vs. single-equals in a shell script
 - The difference between `[ ... ]` and `[[ ... ]]` in a shell script
 - What the internal field separator (aka `IFS`) is, and what it's useful for
 - How to iterate over arguments in a shell script, using a for-loop
 - Using the `$@` symbol to fetch the list of arguments provided to a script
 - How to write a case statement in `bash`
 - What `export` statements are, and why they're useful
 - The difference between shell variables and environment variables
 - The `exec` and `fork` commands, and when to use each one
 - What a "process" is
 - How to use Github and the repository's git history to figure out *why* the code is [the way that it is](https://www.youtube.com/watch?v=QXe1PkslirY).
 - What command substitution is and how to use it

And possibly more, as well.  I lost count lol.

## I still have more questions!

Such as:

 - We now know what this shim file is, but where did it come from?  How does RBENV generate a shim file for each of the Ruby programs I have installed?
 - What happens inside the child process that gets created by the call to `exec` at the end of the shim file?
 - We still haven't seen the actual logic which picks the right version number, so it must be happening somewhere else.  Where does that live, and how does it work?

These and more questions will be answered in the upcoming soup-to-nuts walk-through of the RBENV codebase.  By the end of the walk-through, we will have learned:

 - how common `bash` programs like `sed` and `awk` work.
 - most importantly: what to do when you feel like giving up.

Sign up below to get notified when those posts are released!

{% include convert_kit_2.html %}
