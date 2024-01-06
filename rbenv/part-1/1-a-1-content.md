If the goal is to find out what happens when we type `bundle install` into our terminal, then a good place to start is by reading the file which gets executed when running the "bundle" command.

To find that file, let's use the "which" UNIX command. In my terminal, I type the following:

```
$ which bundle

~/.rbenv/shims/bundle
```

Here we see that file containing the `bundle` command's logic lives in a directory called `~/.rbenv/shims`.

## Dotfiles and dot directories

The directory's name begins with a `.` because it's meant to be hidden from the `ls` command.  To view all the contents of a directory *including* dotfiles, we have to pass the `-a` flag to `ls`.

In UNIX, there's [a convention](https://web.archive.org/web/20230312191736/https://en.wikipedia.org/wiki/Hidden_file_and_hidden_directory){:target="_blank" rel="noopener"} whereby the names of files and directories which are meant to be hidden from view by default are prefixed with a dot.  [Techopedia says that](https://web.archive.org/web/20220926030915/https://www.techopedia.com/definition/1837/hidden-file){:target="_blank" rel="noopener"} "They are created frequently by various system or application utilities. Hidden files are helpful in preventing accidental deletion of important data."

That last sentence catches my attention.  I've actually never noticed whether "hidden files... (prevent) accidental deletion of important data."  Let's test that out now.

### Experiment- do hidden files get deleted when running `rm`?

I create a temporary directory named `foo/`, and create two files inside of it- a hidden one named `.bar` and a regular one named `baz`:

```
$ mkdir foo

$ touch foo/.bar

$ touch foo/baz

$ ls -la foo

total 0
drwxr-xr-x   4 myusername  staff  128 Mar  8 10:39 .
drwxr-xr-x  15 myusername  staff  480 Mar  8 10:39 ..
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 .bar
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 baz
```

Then I run `rm foo/*`.  I see the following:

```
$ rm foo/*

zsh: sure you want to delete the only file in /Users/myusername/Workspace/OpenSource/foo [yn]? y
```

Lastly, I re-run `ls -la foo` and see the following:

```
$ ls -la foo

total 0
drwxr-xr-x   3 myusername  staff   96 Mar  8 10:40 .
drwxr-xr-x  15 myusername  staff  480 Mar  8 10:39 ..
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 .bar
```

So yes, it appears that making files hidden with a `.` prefix can prevent them from being accidentally deleted!

### Side note- experiments

We just did our first of many experiments.  Sometimes these experiments will help us construct hypotheses of how we think code might work, and then test whether those hypotheses are correct.  Other times, they're just ways that we can prove to ourselves that what we read on StackOverflow or some random person's blog post is actually correct.

Either way, I've found them to be a good habit to develop as I write.  They help me double-check my thought process.

## What are version managers?

Back to  `~/.rbenv/`.  This hidden directory houses the logic for my Ruby version manager, which is called [RBENV](https://github.com/rbenv/rbenv){:target="_blank" rel="noopener"}.  RBENV lets me switch between Ruby versions without too much hassle.  This is useful because I have multiple Ruby codebases installed on my machine right now, and they all depend on different versions of Ruby.

If we have multiple versions of Ruby installed, that means there are multiple programs on our machine which respond to the `ruby` command in our terminal.  Without a Ruby version manager to help us switch between versions, our OS will just pick the first of these programs that it finds, which may or may not be the version our program depends on.

Not everyone uses RBENV; other people use [rvm](https://rvm.io/){:target="_blank" rel="noopener"}, [chruby](https://github.com/postmodern/chruby){:target="_blank" rel="noopener"}, [asdf](https://asdf-vm.com/){:target="_blank" rel="noopener"}, or other programs.  But RBENV is quite popular in the Ruby community.  RBENV actually maintains a comparison of popular Ruby version managers [here](https://github.com/rbenv/rbenv/wiki/Comparison-of-version-managers){:target="_blank" rel="noopener"}.

## So what's the difference between Bundler and RBENV?

A minute ago, we said that Bundler provides "a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed."

This... sounds a lot like what I just said RBENV does.  So what's the difference between RBENV and Bundler?  Why do I need both?

[Bundler is a dependency management tool.](https://web.archive.org/web/20220911152613/https://www.rubyguides.com/2018/09/ruby-gems-gemfiles-bundler/){:target="_blank" rel="noopener"}  It helps you manage the versions of the **libraries in a given Ruby project** (also known as 'gems').

RBENV, on the other hand, manages the versions of **Ruby on your machine**, across all your projects.  RBENV ensures that your machine is using the version of Ruby that your project depends on, and Bundler ensures that your machine is using the right versions of the libraries that your project depends on.

More info on how these tools all work together can be found [here](https://web.archive.org/web/20221210084104/https://www.honeybadger.io/blog/rbenv-rubygems-bundler-path/){:target="_blank" rel="noopener"}, in this excellent summary from Honeybadger.io.

## Shims

Earlier, I made the claim that a Ruby version manager like RBENV ensures that every time we run a Ruby project, we're using the version that this project depends on.  RBENV accomplishes this task by **intercepting** your call to `ruby`, deciding which Ruby version to use based on the information available to it (more on that later), and then passing the command you entered to the correct Ruby interpreter based on that version.

The file which performs this interception is known as a "shim".  Programs that act as shims are [meant to be "transparent"](https://stackoverflow.com/questions/2116142/what-is-a-shim){:target="_blank" rel="noopener"}, meaning that you think you're talking to the program you invoked (say, `bundle` if we're running `bundle install`), but the whole time you're really talking to the shim.  Similarly, `bundle` thinks it's sending its reply to you, not to a shim.

To quote [RBENV's README file](https://web.archive.org/web/20230405065304/https://github.com/rbenv/rbenv#how-it-works){:target="_blank" rel="noopener"}:

> ### How It Works
>
> After rbenv injects itself into your PATH at installation time, any invocation of `ruby`, `gem`, `bundler`, or other Ruby-related executable will first activate rbenv. Then, rbenv scans the current project directory for a file named `.ruby-version`. If found, that file determines the version of Ruby that should be used within that directory. Finally, rbenv looks up that Ruby version among those installed under `~/.rbenv/versions/`.

The file whose path we discovered earlier (`~/.rbenv/shims/bundle`) is the shim file for the Bundler gem's `bundle` command.

## The code for the shim file

Let's take a look at the shim's code.  I type the following into my terminal:

```
$ cat ~/.rbenv/shims/bundle
```

And what I see is:

```
#!/usr/bin/env bash
set -e
[ -n "$RBENV_DEBUG" ] && set -x

program="${0##*/}"
if [ "$program" = "ruby" ]; then
  for arg; do
    case "$arg" in
    -e* | -- ) break ;;
    */* )
      if [ -f "$arg" ]; then
        export RBENV_DIR="${arg%/*}"
        break
      fi
      ;;
    esac
  done
fi

export RBENV_ROOT="/Users/myusername/.rbenv"
exec "/Users/myusername/.rbenv/bin/rbenv" exec "$program" "$@"
```

Yikes!  That's a spicy meatball.

Explaining this all in detail will require a few more posts at least, but for now the important thing is that the above code does NOT come from the `bundle` command itself, but rather RBENV's *shim* of the `bundle` command.  In fact, if we were to inspect other files in the `~/.rbenv/shims/` folder, we'd see they look *exactly* the same!  The following files all contain exactly the same code as the above:

 - `~/.rbenv/shims/rails`
 - `~/.rbenv/shims/ruby`
 - `~/.rbenv/shims/gem`

Let's break down the code line-by-line, and we'll see why all these files can have the same exact code, yet execute drastically programs.
