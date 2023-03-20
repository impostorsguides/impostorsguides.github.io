Having finished reading [the code for RBENV's shims](https://docs.google.com/document/d/1xG_UdRde-lPnQI7ETjOHPwN1hGu0KqtBRrdCLBGJoU8/edit), we need to decide what's next.  [RBENV's README on Github](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb/) could help inform that decision.

A couple possibilities stand out:

## Shim Rehashing

> Through a process called rehashing, rbenv maintains shims in that directory to match every Ruby command across every installed version of Ruby...

This brings up a good question- we've already looked at the shim file itself, but where did that shim file come from?  It sounds like that's part of the “rehashing” process described here, but how does that process work?

From the README:

> Choosing the Ruby Version
When you execute a shim, rbenv determines which Ruby version to use by reading it from the following sources, in this order:
>
> The RBENV_VERSION environment variable, if specified. You can use the rbenv shell command to set this environment variable in your current shell session.
>
> The first .ruby-version file found by searching the directory of the script you are executing and each of its parent directories until reaching the root of your filesystem.
>
> The first .ruby-version file found by searching the current working directory and each of its parent directories until reaching the root of your filesystem. You can modify the .ruby-version file in the current working directory with the rbenv local command.
>
> The global ~/.rbenv/version file. You can modify this file using the rbenv global command. If the global version file is not present, rbenv assumes you want to use the "system" Ruby—i.e. whatever version would be run if rbenv weren't in your path.

The process by which RBNV checks which Ruby version to use is something I *thought* I understood from my last write-up.  But it turns out there's additional logic to do this which doesn't live in the shim file itself.  Maybe I should try to find where that extra logic lives?

## Installing Ruby via RBENV

The README also talks about Ruby installation, a process which seems important in the Ruby version management lifecycle:

> ...`ruby-build`, which provides the rbenv install command that simplifies the process of installing new Ruby versions.
>
> The `rbenv install` command doesn't ship with rbenv out of the box, but is provided by the `ruby-build` project.

Why wouldn't they ship RBENV with `rbenv install` already included?  I've used it before and it seems both useful and important enough to include by default.  If one *doesn't* use RBENV, I don't know what the process is to wire up a new Ruby version with RBENV once you install it yourself, but I can't imagine it's easy.

## Shell Integration

From the README:

> `rbenv init` is the only command that crosses the line of loading extra commands into your shell. Coming from RVM, some of you might be opposed to this idea.

Why would someone be opposed to this idea?  It seems like there's something important or controversial here that I don't fully understand.

## RBENV sub-commands

Again from the README:

> Like git, the rbenv command delegates to subcommands based on its first argument.

The delegation process seems important since that's how RBENV executes any and all commands that it exposes.  How does this work, under-the-hood?

## Making A Decision

I see the following directories in the Github repo:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-237pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

Out of all the directories I see, `libexec/` has the most files in it.  While this doesn't *necessarily* mean that it's the most important directory, it does indicate that a lot of development has taken place in that directory.  It also means that, if I were to finish reading through all the files in that directory, I will have taken a big step toward understanding the codebase as a whole.

I decide to start there.
