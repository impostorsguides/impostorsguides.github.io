
That's it!  That's the entire `rbenv` file.

In the process of learning about this command, we talked about:

 - What annotations are.
 - How to read RBENV's tests.
 - Testing happy paths, sad paths, and alternate paths.
 - What command substitution is.
 - What "red-green-refactor" and "test-driven development" mean.
 - How to use the `shift` command.
 - How to use `xtrace` plus the `PS4` env var to debug your code
 - The `BASH_SOURCE`, `LINENO`, and `FUNCNAME` environment variables which ship with bash.
 - More ways to use parameter expansion, such as the `:+` modifier.
 - How to define a shell function.
 - How to group multiple lines of output together, using the `{ ... }` curly brace syntax.
 - What data streams (ex.- `stdout`, `stdin`, and `stderr`) are
 - How to redirect output from one data stream to another.
 - What 'piping' is, and how it differs from 'redirection'.
 - How to count the parameters passed to a file or function, using the `"$#"` syntax.
 - How to read from standard input using the `cat -` command.
 - What the `.dylib` file extension means.
 - Dynamically loading helper libraries and overriding builtin commands, using `enable -f`.
 - What `/dev/null` is and how to use it.
 - Using the `local` keyword inside a function to limit a variable's scope.
 - Combining command substitution with the `echo` command, to return arbitrary data from a function.
 - What native extensions are.
 - Resolving a file's canonical filepath using the `readlink` command.
 - Performing a path search on a command using the `type` command.
 - Displaying the first N lines of a stream of input using the `head` command.
 - What hard links and symbolic links are, and how they work.
 - Preventing an error from causing an early exit of the script, using the `|| true` pattern.
 - Iterating over paths in a directory more safely, using the `shopt -s nullglob` command.
 - What the Filesystem Hierarchy Standard (or FHS) is.
 - How to read a version number.
 - Finding the true path to a command, bypassing any aliases or shell functions, using the `command` command.
 - Calling child scripts which `export` environment variables that are usable by the parent script, using the `echo` + `eval` pattern.

What should we do next?

Normally I'd want to copy the order in which the files appear in the "libexec" directory, which would mean looking at `rbenv---version` next.  But I still have questions around shell integration and the `rbenv-init` file, mainly:

 - Why would someone **not** want to enable shell integration?
 - What's the downside of enabling it?
 - How would you use RBENV without it?

I think it makes more sense to start with `rbenv-init` and come back to `rbenv---version` afterward.
