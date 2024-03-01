## NOTE: This Page Is A Work In Progress

There's still one thing I don't understand.  The RBENV README [says](https://web.archive.org/web/20230513160954/https://github.com/rbenv/rbenv#rbenv-shell){:target="_blank" rel="noopener" } the following:

> Note that you'll need rbenv's shell integration enabled (step 3 of the installation instructions) in order to use this command (i.e. `rbenv shell`). If you prefer not to use shell integration, you may simply set the RBENV_VERSION variable yourself:
>
>```
>export RBENV_VERSION=jruby-1.7.1
>```

Why would someone **choose** to do this themselves, setting `RBENV_VERSION` manually rather than adding `rbenv init` to their shell configuration file and allowing RBENV to set the version on their behalf?

What's the benefit of doing this extra step yourself?

<!-- I can't find a direct quote from RBENV's maintainers saying why someone would decline to use shell integration.  My best guess is that the `sh-` dispatch feature has the power to add or modify environment variables in the current context.  This could potentially present a problem if the user installs an RBENV plugin or hook which turns out to modify those environment variables in a malicious manner.  I'm not a security expert, but I believe that if the user doesn't have shell integration installed, this damage would be confined to the child process.  With shell integration enabled, however, those malicious changes could affect the user's current shell as well.  Although `rbenv init` doesn't directly activate any hooks or plugins, `rbenv-sh-shell` does, and (I suppose?) it's always possible -->

After a lot of searching through the Github issues for the term "shell", I find [this issue](https://github.com/rbenv/rbenv/issues/1409){:target="_blank" rel="noopener" } which says the following:

> ...it's absolutely possible to use most rbenv functionality without ever enabling its shell integration. This is all that's needed:
>
> ```
> export PATH=~/.rbenv/bin:~/.rbenv/shims:"$PATH"
> ```
>
> Calling most rbenv commands, switching between versions, and executing shims will all work with this approach. Rbenv was intentionally designed to not need shell integrations (unlike RVM).

So even without RBENV's shell function, you can still call `rbenv local 2.7.5`, `rbenv version`, etc. as long as your `$PATH` variable includes the above two directories.

The `"unlike RVM"` comment at the end tells me that there's something about RVM which the core team didn't like, and which prompted them to design RBENV without the need for shell integrations.  If we knew what this was, it would help answer our question.

I Google `"rvm vs rbenv"`, and one of the first results I see is [this Reddit thread](https://web.archive.org/web/20220501024630/https://www.reddit.com/r/rails/comments/f009mb/there_are_two_ruby_version_manager_rvm_vs_rbenv/){:target="_blank" rel="noopener" } (NOTE- it's from 2020) which has comments from multiple people on why they switched from RVM to RBENV.

I lightly edited the comments because I'm not super-interested in the holy war of which version manager is better.  I'm mostly interested in why someone might choose to make that switch.  Some of the comments I found include:

- "I used to use RVM but got bit one too many times by the (things) they do to your shell env (such as) overriding `cd`..."
- "When I was in a Mac, I used rbenv after getting frustrated with rvm. I found rbenv less buggy when it came to switching versions automatically when changing directories."

I also found [this Reddit post](https://web.archive.org/web/20230122012707/https://www.reddit.com/r/rails/comments/5hnu32/rbenv_or_rvm_which_one_to_use_and_why/){:target="_blank" rel="noopener" } (from 2017) with the following quotes:

- "RBenv has you add a shim to your path, while RVM does a bunch of hackery to hook into your system."
- "I like rbenv because I think it messes with cd less. Additionally there is less redundancy in how it downloads gems because it gets one gem per Ruby version vs. one gem per gemset."
- "last I used rvm it rewrites cd ? and other odd things that I really wouldn't expect a ruby version manager to do. rbenv doesn't, and I haven't experienced any major oddities."
- "rvm... rewrites basic shell functions."

NOTE- [gemsets](https://web.archive.org/web/20230327130121/https://rvm.io/gemsets/basics){:target="_blank" rel="noopener" } are RVM's way of isolating gem dependencies in Ruby.  RVM allows you to create multiple isolated environments under the umbrella of a single Ruby version.  This means you can install (for example) Ruby 3.0.0, create one gemset containing Rails `v6.0`, and another gemset containing Rails `v7.0`, and switch back-and-forth between them for the purposes of testing a potential version upgrade.  The cost of doing this is that you have to maintain these separate gemsets yourself, and it can potentially take up more space on your machine if you have multiple gemsets with the same Ruby version.

The ability to switch between gem versions sounds useful, but later in the same thread, I found the following:

> Rvm does provide gemsets, but bundler makes them obsolete. This was primarily useful in the dark days of Ruby 1.8 and rails 2.3 when rails apps didn't use bundler, so working on apps with different dependencies could be horrible.

At first this info appeared interesting but ultimately irrelevant, since right now I'm mainly concerned with the shell-specific differences between RVM and RBENV.  But while searching StackOverflow issues for questions containing "rvm cd", I subsequently found [this issue](https://stackoverflow.com/questions/30591281/rvm-must-cd-to-directory-to-change-gemset-according-to-ruby-version-ruby-gem){:target="_blank" rel="noopener" } from 2015 talking about an RVM user's trouble with gemsets.

It seems that RVM would use the correct gemset if the user `cd`'ed into a project's directory, but if the user was already in that directory and opened a new terminal tab, the wrong gemset was used.  This was because (at least, at the time of the post) RVM's hook into the `cd` command was not executed upon opening up a new terminal tab.  Some similar issues from the RVM Github repo:

 - [Here](https://github.com/rvm/rvm/issues/3317){:target="_blank" rel="noopener" } is an issue which reports similar behavior.
 - [Here](https://github.com/rvm/rvm/issues/3270){:target="_blank" rel="noopener" } is an issue from the same repo where a user is unable to see their expected gemset when opening a new `tmux` terminal.
 - Another user in the same thread reported similar problems when running a terminal inside their VS Code code editor.
 - Another similar Github issue [here](https://github.com/rvm/rvm/issues/4824){:target="_blank" rel="noopener" }.  This time the user saw both an unexpected gemset and Ruby version.
 - Another similar Github issue [here](https://github.com/rvm/rvm/issues/4462){:target="_blank" rel="noopener" }, this time when the user switched from one git branch to another.  This issue also involved both unexpected gemsets and Ruby versions.

As of 17 May 2023, all these issues were still open.

My goal in listing the above is not to dump on RVM.  It's a widely-used tool and many people sing its praises.  The intention is strictly to better understand the pain point which motivated RBENV's core team to create their tool.

The choice of overriding `cd` is one of many ways to implement Ruby version management, and it was the approach that the RVM core team made.  Many people were and are happy with this choice, and RVM continues to have many fans today.  However, some RVM users (including, apparently, RBENV's core team) experienced enough pain as a result of this choice that it motivated them to come up with an alternative approach, i.e. creating shims for Ruby commands and adding them to `"$PATH"`.

For what it's worth, I'd also be interested in reading about people who switched *from* RBENV *to* RVM.  I did find a few quotes, including the following:

- "Last I tried rbenv, I had to install an additional plugin just to install ruby versions. Rvm is `batteries included` and I like that."

I also saw quite a lot of love for two other version managers- `chruby` and `asdf`.  I also saw little to no hate for either of these two tools.  Additionally, [this link](https://web.archive.org/web/20230510020715/https://www.sitepoint.com/ruby-version-managers-macos/){:target="_blank" rel="noopener" } gives what appears to be an impartial comparison of the pros and cons of RVM, RBENV, and the other version managers.  Here's a quick summary:

## `rvm`

### Pros

- Still maintained and widely used.

### Cons

- Overrides the `cd` utility in your shell, which some people find off-putting.
- Includes functionality (such as gemsets) which is now considered redundant.

## `rbenv`

### Pros

- No overriding of `cd`, as in `rvm`.

### Cons

- The use of shims can hide where a command's original file lives.  For example, the command `which ruby` shows the shim's directory (`/Users/myusername/.rbenv/shims/ruby`), not the actual path to the Ruby executable (ex.- `/Users/myusername/.rbenv/versions/2.7.5/bin/ruby`).
- A (slight) performance lag, since RBENV executes the shim first, followed by the actual executable.

## `chruby`

### Pros

- No overriding of `cd`, like in `rvm`.
- No use of shims, like in `rbenv` or `asdf`.

### Cons

- None listed in the article.

I'd love to add more to the above list, so please reach out if you think certain info is missing.

## Summary

So it seems like, even with shell integration enabled, RBENV still tries to avoid some of the downsides it perceives in RVM.  For example, even with shell integration enabled, RBENV doesn't monkey-patch the `cd` command.  According to the RBENV `README.md` file, the only thing shell integration adds is:

> However, rbenv offers some integrations, and they are enabled by doing eval `"$(rbenv init ...)"` in your shell. What that does is:
>
> - Ensures that shims are in PATH (although, you can also do this manually)
> - Sets up rbenv completions
> - Sets up the rbenv shell function - this enables commands that need to change the state of your running shell, and the only command that needs this is rbenv shell
> - Automatically performs a rbenv rehash to ensure all shims are up to date (potentially slow—you can disable this by using rbenv init - --no-rehash)
