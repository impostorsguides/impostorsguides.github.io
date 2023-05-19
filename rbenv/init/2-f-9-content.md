## NOTE: This Page Is A Work In Progress

While reading through the `rbenv-init` file, we saw that the file's logic branches via a case statement depending on which shell the user is running (i.e. `bash`, `zsh`, `fish`, and sometimes `ksh`).  That made me wonder, what is the difference between each of these shells, and why would a user pick one over the others?

To be honest, my biggest take-away from researching the different shells is that, as a non-power user, the best shell for me is the default of `zsh` on my Macbook.  It's interesting to get a bit of added context on the alternatives, but for now I think I'll stick with what I've got.

The following are some resources I encountered during my research which (frankly) are more in-depth than what I've written below:

 - ["Which Shell Is Right for You? Shell Comparison"](https://web.archive.org/web/20220930220638/http://linuxclass.heinz.cmu.edu/misc/shell-comparison.htm){:target="_blank" rel="noopener"}, from Carnegie Mellon University
 - ["Which Linux Shell Is Best? 5 Common Shells Compared"](https://web.archive.org/web/20220713192347/https://www.makeuseof.com/tag/best-linux-shells/){:target="_blank" rel="noopener"}, from MakeUseOf.com.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

With that said, here are my take-aways from the research I did:

## `bash`

 - `bash` is a shell but also a lanuage.
 - Most users use `bash`, since it's the default for most Linux systems.
 - `bash` does not have inline wildcard expression, the way `zsh` does.
    - For example, if you type `cat *.txt` and hit the `tab` key, `zsh` will expand the `*` character to list all the `txt` files, so `cat *.txt` becomes `cat foo.txt bar.txt buzz.txt`.
    - The `bash` shell does not offer this ability.
 -

## `zsh`

 - `zsh` is the default shell for macOS (used to be `bash` but [it switched with Catalina in 2019](https://web.archive.org/web/20230203074145/https://www.codecademy.com/resources/docs/command-line/bash){:target="_blank" rel="noopener"}).
 - Comes with tab-based auto-completion.
 - [Much more configurable](https://web.archive.org/web/20230322172708/https://www.freecodecamp.org/news/linux-shells-explained/){:target="_blank" rel="noopener"} than `bash`.  There are [plugins](https://github.com/unixorn/awesome-zsh-plugins), and even entire frameworks such as [oh-my-zsh](https://ohmyz.sh/){:target="_blank" rel="noopener"}, which a lot of `zsh` users love.

## `fish`

 - [Does not comply with POSIX standards.](https://web.archive.org/web/20230322172708/https://www.freecodecamp.org/news/linux-shells-explained/){:target="_blank" rel="noopener"}
 - Includes "search as you type" automatic suggestions.
 - Comes with a lot of configurations and features (such as syntax and even error highlighting) already set and always-on by default.
 - Basically takes a "convention over configuration" approach, so some people consider it more beginner-friendly. [source](https://web.archive.org/web/20230322172708/https://www.freecodecamp.org/news/linux-shells-explained/){:target="_blank" rel="noopener"}

## `ksh`

 - [Better for-loop syntax than `bash`](https://web.archive.org/web/20220713192347/https://www.makeuseof.com/tag/best-linux-shells/){:target="_blank" rel="noopener"}.
 - "Tough to find help for `ksh` online."

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Additional Reading:

- ["Comparison of command shells"](https://web.archive.org/web/20230506115535/https://en.wikipedia.org/wiki/Comparison_of_command_shells){:target="_blank" rel="noopener"}, from Wikipedia.
