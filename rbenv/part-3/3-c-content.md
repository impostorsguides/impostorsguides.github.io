The `bin/` directory contains only one file, a symlink called `rbenv` which points to the `libexec/rbenv` file we've already looked at.

If we look at the `git` history for this symlink file, we can see that it was added in [this PR](https://github.com/rbenv/rbenv/pull/3/files){:target="_blank" rel="noopener"}, quite early in RBENV's history.  Prior to that, all the sub-commands (which now live in `libexec/`) lived directly in `bin/`.

So, why the change of directories?

When we previously read through the `rbenv` command, specifically the part about [making hooks available](/rbenv/rbenv/making-hooks-available){:target="_blank" rel="noopener"}, we learned about the [Filesystem Hierarchy Standard](https://es.wikipedia.org/wiki/Filesystem_Hierarchy_Standard){:target="_blank" rel="noopener"}.  Part of that standard addresses the `bin/` and `libexec/` directories, and why you might use one vs. the other.

## Uses of the `bin/` directory

Referring to section 3.4 of [the main FHS document](https://web.archive.org/web/20230502051228/https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.pdf){:target="_blank" rel="noopener"}, we see that it addresses the `bin/` directory and its uses:

> `/bin` contains commands that may be used by both the system administrator and by users... It may also contain commands which are used indirectly by scripts.

In other words, `bin/` is meant to store commands which are intentionally exposed to the user.  You can feel free to rely on programs in `bin/` directly, call the executables contained within, or write scripts which do so.

## Uses of the `libexec/` directory

Skipping ahead to section 4.7 of the FHS [says](https://web.archive.org/web/20230502051228/https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.pdf){:target="_blank" rel="noopener"}, we see that the `/usr/libexec` folder:

> ...includes internal binaries that are not intended to be executed directly by users or shell
scripts.

This directory signals to users (those who are familiar with the FHS, at least) that the files in the directory are meant to be executed by the library itself, not directly by the user.

Note that putting a command inside `libexec` won't *prevent* a user from calling a given executable; after all, they could always decide to add `libexec/` to their `$PATH`.  Instead, the name *implies* that doing this would be a bad idea.

It's the equivalent of marking a method `private` in Ruby.  You can still call it by using `.send`, but you might be shooting yourself in the foot by doing so.

## Why use two separate directories?

Maybe all this seems like overkill.  What's the harm in letting users call internal code themselves?  [This StackOverflow answer](https://unix.stackexchange.com/a/386015/142469){:target="_blank" rel="noopener"} addresses that question:

> It's a question of supportability - platform providers have learned from years of experience that if you put binaries in `PATH` by default, people will come to depend on them being there, and will come to depend on the specific arguments and options they support.
>
> By contrast, if something is put in `/usr/libexec/` it's a clear indication that it's considered an internal implementation detail, and calling it directly as an end user isn't officially supported.
>
> You may still decide to access those binaries directly anyway, you just won't get any support or sympathy from the platform provider if a future upgrade breaks the private interfaces you're using.

This answer implies something about why the FHS is important- it's a way for library authors to signal which parts of the library can be safely relied upon to be stable, and which ones cannot.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So `bin/` is meant to be exposed to users directly, while `libexec/` signals that the user should **not** invoke these commands directly.  Let's move on.
