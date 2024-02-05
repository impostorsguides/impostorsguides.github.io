In this section, we learned about:

 - Heredocs and here strings, and their similarities and differences.
 - Using the `printf` command to do string interpolation.
 - Using brace expansion to combine several similar commands into one line of code.
 - Importing files via the `source` command, and the difference between `source foo` and `./foo`.
 - How to escape code within strings using the `\` escape character.
 - What escape characters are, and why they're used.
 - Some very basic syntax of non-Bash shells:
   - How to declare a local variable in `fish` and `ksh`.
   - Accessing the arguments passed to a `fish` shell script via `argv[]`.
   - How to declare local variables in a `fish` script using the `set` command.
   - How to print a function definition in `fish` using the `functions` command.
   - How to evaluate `fish` code inside the current process context using the `source` command.
   - The difference between `set -e` in `fish` vs. Bash
   - How the `function` keyword is optional in Bash and `zsh`, but not in `fish` or `ksh`.
 - Why you might *not* want to use the `function` keyword in your Bash or `zsh` shells.
 - How to set a default value in a parameter expansion using `:-`.
 - Why the core team was unsatisfied with RVM's approach of overriding the `cd` command, and decided to make shell integration optional in RBENV.
 - The pros and cons of using Bash, `zsh`, `fish`, and `ksh`, and why you might pick one over the others.
