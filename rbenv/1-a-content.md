Having finished reading [the code for RBENV’s shims](https://docs.google.com/document/d/1xG_UdRde-lPnQI7ETjOHPwN1hGu0KqtBRrdCLBGJoU8/edit), I’m now looking for something else to look at.  I know RBENV’s codebase is more than just the shim, so I feel like there is more to learn than just that.  One of my goals is to get to the point where I know enough about RBENV to contribute to its codebase.  In order to do that, I definitely need a wider understanding of it than I currently have.  Plus, RBENV’s logic is the first thing that happens in the execution chain when you run a program, so what happens there affects everything downstream.  So I feel like staying in RBENV-land for now.

I decide to peruse [RBENV’s Github page](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb/).  A couple statements stand out:

> Through a process called rehashing, rbenv maintains shims in that directory to match every Ruby command across every installed version of Ruby…

Richie says: This brings up a good question- we’ve already looked at the shim file itself, but where did that shim file come from?  It sounds like that’s part of the “rehashing” process described here, but how does that process work?

<p style="text-align: center">
  <img src="/assets/images/rbenv-how-it-works-readme.png" width="70%" alt="'How It Works' section from RBENV's README file"  style="border: 1px solid black; padding: 0.5em">
</p>

Richie says: The process in which RBNV checks which Ruby version to use is something I *thought* I understood from my last write-up.  But it turns out there’s additional logic to do this which doesn’t live in the shim file itself.  Maybe I should try to find where that extra logic lives?

> (step 6 in the install process) (Optional) Install ruby-build, which provides the rbenv install command that simplifies the process of installing new Ruby versions.

Richie says: when I install new Ruby versions, I typically use `rbenv install`.  This is a pretty important part of the RBENV lifecycle, so it would pay to understand how it works.

> rbenv init is the only command that crosses the line of loading extra commands into your shell. Coming from RVM, some of you might be opposed to this idea.

Why would someone be opposed to this idea?  Seems like there’s something important or controversial here that I don’t fully understand.

> The `rbenv install` command doesn't ship with rbenv out of the box, but is provided by the `ruby-build` project.

Richie says: Why wouldn’t they ship RBENV with `rbenv install` already included?  I’ve used it before and it seems both useful and important enough to include by default.  If one *doesn’t* use RBENV, I don’t know what the process is to wire up a new Ruby version with RBENV once you install it yourself, but I can’t imagine it’s easy.

> Like git, the rbenv command delegates to subcommands based on its first argument.

Richie says: How does it do this?  The delegation process seems important since that’s how RBENV executes any and all commands that it exposes.

—-------

The above questions are all perfectly valid starting points for diving into the code.  However, I’m thinking I want to take a more methodical approach.  I see the following directories, and I don’t know what they mean:



My curiosity might be satisfied if I just start at the top and work my way down through the directories and files.  This seems like the best way to get a “lay of the land”, or a broad overview, as far as RBENV’s codebase goes.

Let’s do that.


