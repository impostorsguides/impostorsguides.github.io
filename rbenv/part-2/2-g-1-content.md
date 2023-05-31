At this point we've reviewed how RBENV's shims work, as well as the `rbenv` and `rbenv-init` commands.  That's a lot, but it's not quite everything.

There are still a lot of commands that RBENV exposes to users, as well as commands that it uses under-the-hood.  We'll examine those commands in this section, going down the list of files in the `libexec/` directory in the order they appear [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/){:target="_blank" rel="noopener"}.
