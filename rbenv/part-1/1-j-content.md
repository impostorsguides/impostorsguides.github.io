## What We Learned

We covered a lot in this series, including:

 - What dotfiles and dot directories are
 - What version management is, and why it matters
 - What shims are
 - What a shebang is
 - What the `PATH` variable is, and how it's used
 - How to read and modify UNIX's file permissions
 - What the internal field separator (aka `IFS`) is, and what it's useful for
 - How to look up documentation on our machine, using both the `man` and `help` commands
 - What a "shell" is
 - What POSIX is
 - What a "builtin" command is
 - How to find out which shell is your machine's default
 - What a `.rc` file is
 - What shell options are, and how to set them with the `set` command
 - Some common shell options (`set -e` and `set -x`), and what they do
 - How to write boolean conditions in a shell script using the `[` or `test` command
 - Some useful flags for `[ ... ]` (such as `-n` and `-f`).
 - What parameter expansion is, how to use it, and some common use cases
 - Double- vs. single-`=` in a shell script
 - Single-`[ ... ]` vs. double-`[[ ... ]]` in a shell script
 - Using the `$@` symbol to fetch the list of arguments provided to a script
 - How to iterate over arguments in a shell script, using a for-loop
 - How to write a case statement in `bash`
 - What `export` statements are, and why they're useful
 - The difference between shell variables and environment variables
 - The `exec` and `fork` commands, and when to use each one
 - What a "process" is
 - How to use Github and the repository's git history to figure out *why* the code is the way that it is.

And possibly more, as well.  I lost count lol.

## I still have more questions!

Such as:

 - What happens inside the child process that gets created by the call to `exec` at the end of the shim file?
 - We still haven't seen the actual logic which picks the right version number, so it must be happening somewhere else.  Where does that live, and how does it work?
 - We only scratched the surface of what can be done in `bash`.  What are some other `bash`-related things that we can learn from the RBENV codebase?

These and more questions will be answered in the upcoming soup-to-nuts walk-through of the RBENV codebase.  By the end of the walk-through, we will have learned:

 - how RBENV keeps your Ruby versions separate, organized, and compartmentalized.
 - how RBENV implements the "order of precedence" (`shell > script local > cwd local > global`) mentioned [here](https://github.com/rbenv/rbenv/pull/298#issuecomment-11710825){:target="_blank" rel="noopener"}.
 - how to patch RBENV's behavior using hooks and plugins.
 - how to use common `bash`-isms, such as:
    - `sed`
    - `awk`
    - command substitution
    - and many more

## If you like what you've read

Drop me a line on Mastadon- impostorsguides@mastodon.social.
