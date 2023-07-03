Now we move on to the `rbenv.d/` directory.  The first file we'll look at is inside `rbenv.d/exec/`, a `bash` script called `gem-rehash.bash`.

## [gem-rehash.bash](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash.bash){:target="_blank" rel="noopener"}

Since I notice that this is file ends in the ".bash" extension, I'm curious where and how the file gets executed.  So the first thing I do is search for the filename "gem-rehash" in the codebase, however I don't see any hard-coded references to this file anywhere in RBENV.

My next step is to Google "gem-rehash.bash", thinking that maybe this filename is part of some Rubygems standard and that there are other libraries with similarly-named files.  But no such luck- the only search results that appear are related to the RBENV library.

One of the search results does catch my eye, however:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-923am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

I decide to open that up.  Inside I look for where "gem-rehash.bash" is referenced:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-924am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

I scan this a bit more closely, and I see "Auditing installed plugins" in the logs that the question references.  This reminds me that we're currently in a directory named "rbenv.d/exec/gem-rehash/", and that "rbenv.d" is one of the directories that is checked for plugins by... which file was it again?

I search for "rbenv.d" in the code, and I find:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-925am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

2 files are ".bats" test files, 1 file is the "test_helper.bash" file, and the last result is the "libexec/rbenv" file.  That's the file which [adds the "rbenv.d" directory](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81){:target="_blank" rel="noopener"} to the "RBENV_HOOK_PATH" environment variable.  Then later, the `rbenv-hooks` file uses `RBENV_HOOK_PATH` to [generate a list of hook files](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks#L55){:target="_blank" rel="noopener"}, and then `rbenv-hooks` is subsequently called by multiple other commands ([`rbenv-exec`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L37){:target="_blank" rel="noopener"}, [`rbenv-rehash`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash#L159){:target="_blank" rel="noopener"}, and others) to actually invoke / source those hook files.

OK, so now that we know how this file is invoked, what does it do?

```
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

This is the only line of code in the file.  Looks like it just:

Accesses a single environment variable named `RUBYLIB`,
Prepends the value of `${BASH_SOURCE%.bash}` to the previous value of `RUBYLIB`, and
Exports the new `RUBYLIB` value.

What is the value of `$BASH_SOURCE` that gets prepended to `RUBYLIB`?  To find out, I update `gem-rehash.bash` to the following:

```
echo "BASH_SOURCE: $BASH_SOURCE"
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

I then open a new terminal tab and run a simple `rbenv exec` command:

```
$ rbenv exec ruby -e '1+1'
BASH_SOURCE: /Users/myusername/.rbenv/rbenv.d/exec/gem-rehash.bash
```

So `BASH_SOURCE` is the name of the file we're running.  As a refresher on what the "%.bash" syntax is, I look up [the docs for bash parameter expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-930am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

Right, it has to do with trimming off certain patterns.  As an experiment, I try the following in my terminal:

```
bash-3.2$ foo="foobarbaz.bash"

bash-3.2$ echo "${foo%.bash}"

foobarbaz

bash-3.2$ foo="foobarbaz.bash.bash.bash"

bash-3.2$ echo "${foo%.bash}"

foobarbaz.bash.bash

bash-3.2$ foo="foobarbaz.bash.bash.bash.buz"

bash-3.2$ echo "${foo%.bash}"

foobarbaz.bash.bash.bash.buz

bash-3.2$
```

So "${foo%bar}" will trim "bar" from the value of a variable named "foo".  Or in our case, we trim ".bash" off the end of our variable named "BASH_SOURCE".  Since "BASH_SOURCE" equals "/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash.bash", that means we're left with the filename without its extension, or "/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash".

To test this, I update `gem-rehash.bash` to equal the following:

```
echo "RUBYLIB before: $RUBYLIB"
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
echo "RUBYLIB after: $RUBYLIB"
```

When I do the same dummy `rbenv exec` command, I now get:

```
$ rbenv exec ruby -e '1+1'

RUBYLIB before:
RUBYLIB after: /Users/myusername/.rbenv/rbenv.d/exec/gem_rehash:
```

So before, the value of `RUBYLIB` was empty.  Afterwards, it's equal to `/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash:`.  Which makes sense, given that we prepend the modified value of `BASH_SOURCE` to the existing value (i.e. ""), and separate the two with the ":" symbol.

So that's it for this file.  Before closing the `gem-rehash.bash` file, I be sure to remove the two `echo` statements I added.

The only other file in the `rbenv.d` directory is [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash/rubygems_plugin.rb){:target="_blank" rel="noopener"}, called `rubygems_plugin.rb`.  Let's look at that one now.

## [rubygems_plugin.rb](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash/rubygems_plugin.rb){:target="_blank" rel="noopener"}

This is another file whose invocation is unclear to me.  Where does this file get called / executed?

I try the same strategy as last time, beginning with searching for the filename in the codebase.  Again finding nothing, I try Googling for the filename to see if it's part of some established convention:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-948am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

Judging by the fact that the search results include Github repos for other libraries, I conclude that it looks like this file's name *is* part of a convention.  I'm guessing the convention has to do with Rubygems, because the filename includes the string "rubygems".  And in fact, it looks like [that 3rd search result](https://web.archive.org/web/20221013080106/https://guides.rubygems.org/plugins/){:target="_blank" rel="noopener"} describes the convention:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-949am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Based on this statement, and the fact that the "rubygems_plugin.rb" file is located inside "rbenv/rbenv.d/exec/gem-rehash/", we can conclude that "rbenv/rbenv.d/exec/gem-rehash/" is the root of some gem's "#require_path".

After Googling for "gem-rehash", I find [this deprecated Github repo](https://github.com/rbenv/rbenv-gem-rehash){:target="_blank" rel="noopener"}.  I hypothesize that this used to be part of a separate gem, and began as an optional plugin for RBENV, but at some point it got merged into the main repo as a default piece of logic.  To verify this, I run a `git blame` on "rubygems_plugin.rb" and find the earliest commit SHA:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-950am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

I then search for this SHA in the RBENV Github repo:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-953am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Based on the name of [this issue](https://github.com/rbenv/rbenv/pull/638/files){:target="_blank" rel="noopener"}, it sounds like our hypothesis was correct.

OK, another question: *when* does this file get executed?  What kicks off the installation of the now-part-of-the-core-code "rbenv-gem-rehash" gem?

I add some tracer statements to the start of the file (the one located at `/Users/myusername/.rbenv`, NOT the one located at `/Users/myusername/Workspace/OpenSource/rbenv`):

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-954am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

I then open up a new tab, thinking that maybe these files will get executed as part of `rbenv init` (although I don't remember that happening).  However I do not see the logging statements, so that can't be what's happening.

Reading [the docs](https://web.archive.org/web/20221013080106/https://guides.rubygems.org/plugins/){:target="_blank" rel="noopener"} a bit more, it looks like the "rubygems_plugin.rb" file gets called when a user runs the `gem install` command:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-955am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

So the reason I'm not seeing my `puts` statements print out is because I haven't run `gem install` yet.  However, I know that the default behavior for this command is to download gems from the remote Rubygems repository, not from the current directory.  So I Google "gem install from file" and get [this StackOverflow answer](https://web.archive.org/web/20221005194325/https://stackoverflow.com/questions/220176/how-can-i-install-a-local-gem){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-956am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Right, I think I remember this from a previous exposure to Rubygems- I need a file whose extension is ".gem".  I don't have this, and a quick search of the RBENV repo doesn't turn one up either.  Maybe it's worth a try to run it using Ruby directly?

(stopping here for the day; 1006 words)

Separately, I'm also wondering *how* the logic of the `rbenv-gem-rehash` library was moved into the main repo.  The README for `rbenv-gem-rehash [was updated](https://github.com/rbenv/rbenv-gem-rehash/commit/feafdac8edaa85f838e53f468434cc818bdcfe0f){:target="_blank" rel="noopener"} to say "This plugin is deprecated since its behavior is now included in rbenv core."  How was this behavior "included"?  I don't see how "gem install" could be getting invoked here, given how deeply-nested the "rubygems_plugin.rb" file is with respect to the root of the repository.

[It looks like](https://github.com/rbenv/rbenv/pull/638/commits/67f429c41de851052950ffdb372fda90a21a4356){:target="_blank" rel="noopener"} this is the commit which actually brings in the logic from the old gem to the RBENV codebase.  I think it's interesting that the only two files changed here are an update to an environment variable named `RUBYLIB`, and the addition of the "rubygems_plugin.rb" file itself.  Like, I still don't know what's calling the "rubygems_plugin.rb" file, but I *REALLY* don't know why the `RUBYLIB` variable change would need to be included in this file.  What does that have to do with anything?  I don't even know what that variable does.  Maybe I should find out?

I find [this link](https://web.archive.org/web/20220831132623/https://www.oreilly.com/library/view/ruby-in-a/0596002149/ch02s02.html){:target="_blank" rel="noopener"} from O'Reilly, which says that `RUBYLIB` is a "Search path for libraries".  That's... all it says.  I also found [this link](https://web.archive.org/web/20220715143641/https://ruby-doc.com/docs/ProgrammingRuby/html/rubyworld.html){:target="_blank" rel="noopener"} from ruby-doc.com, which says that this variable is an "(a)dditional search path for Ruby programs".  It's good to have confirmation of the first definition from an independent source, but this doesn't add much to the picture.  Some questions I have are:

 - When and where is RUBYLIB used?
 - Why and how is updating the value of RUBYLIB relevant to RBENV's goal of moving the logic of `rbenv-gem-rehash` into the core of `rbenv`?  In other words, why was updating RUBYLIB necessary to achieving this goal?
 - Why is the documentation on RUBYLIB so sparse?  Where are programmers supposed to turn for guidance on when to use (or not use) RUBYLIB?
 - How did the RBENV core team know that updating RUBYLIB was needed?  Where did they pick up this knowledge?  The answer to this is relevant to us noobs, so that we can do likewise with this and future questions.

I now know enough to say that RUBYLIB is important to the way the Ruby language works, therefore I know that I can always look at [the Ruby core code itself](https://github.com/ruby/ruby/search?q=RUBYLIB){:target="_blank" rel="noopener"} to see how RUBYLIB is used.  But I don't relish the idea of doing so, because it's probably in C and I don't want to learn C just to answer this question.  I also feel like that shouldn't be necessary, either- there should be docs on this somewhere.

(stopping here for the day; 1435 words)

This morning I remembered a conversation that I saw in [this PR](https://github.com/rbenv/rbenv/issues/384){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1000am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Mislav says:

```
I also think it's not very optimal if a user needs to remember to `rbenv rehash` for every new installed gem that has an executable.
```

This implies that the goal of moving the `rbenv-gem-rehash` logic into the core repo was to prevent the user from needing to manually run `rbenv rehash` every time they install a new gem.  I wonder if this means that "rubygems_plugin.rb" gets run when a new gem is installed?

I add some loglines to "rubygems_plugin.rb" which are similar to the ones I added before, but this time I add them to the version located at `/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash`:

```
puts "inside rubygems_plugin.rb"          # this is the logline I added

hook = lambda do |installer|
  begin
    # Ignore gems that aren't installed in locations that rbenv searches for binstubs

...
```

I then install a random gem (`draper`, in this case) and observe what happens:

```
$ gem install draper

inside rubygems_plugin.rb
Fetching draper-4.0.2.gem
Fetching activemodel-serializers-xml-1.0.2.gem
Successfully installed activemodel-serializers-xml-1.0.2
Successfully installed draper-4.0.2
Parsing documentation for activemodel-serializers-xml-1.0.2
Installing ri documentation for activemodel-serializers-xml-1.0.2
Parsing documentation for draper-4.0.2
Installing ri documentation for draper-4.0.2
Done installing documentation for activemodel-serializers-xml, draper after 0 seconds
2 gems installed
```

Aha!  I see the tracer statement in action!

OK, so *this* is when the file gets called- at the time a gem is installed.  But what is the call stack?  Where does this file get called *from*?

I add another log line to the file:

```
puts "=============="
puts caller
puts "=============="          # I replaced the earlier logline with these 3

hook = lambda do |installer|
  begin
    # Ignore gems that aren't installed in locations that rbenv searches for binstubs

...
```

And re-run the gem installation:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1009am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</center>

Great, now I have the call stack, which tells me where this file is getting called from!

Although, I am a bit concerned with the error I see at the bottom.  It looks like I somehow borked my ability to install gems.  This is not good.

I Google the error "You don't have write permissions for the /Library/Ruby/Gems/2.6.0 directory.", and the 2nd search result is [this issue](https://github.com/rbenv/rbenv/issues/1267){:target="_blank" rel="noopener"} inside the RBENV Github repo:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1010am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

The issue points to a solution in the RBENV wiki, which I open:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1011am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

I run `rbenv global 2.7.5` and then try to re-run `gem install draper`, and this time it succeeds.  Sweet!

To be on the safe side, I also run `gem update` (another command which previously resulted in the same error).  This succeeds as well:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1012am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Back to the call stack I was inspecting.

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1013am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

The call stack goes in reverse order, starting with the lowest-level file and going down to the start of the process.  I want to start at the top, so I open "/Users/myusername/.rbenv/versions/2.7.5/bin/gem" and go to line 9:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1014am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

So we require `gem_runner`, which triggers a bit of `kernel_require` magic, and eventually we get to line 16 of `/Users/myusername/.rbenv/versions/2.7.5/lib/ruby/2.7.0/rubygems/gem_runner.rb`:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1015am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Before continuing on, I notice the comment on line 14 above:

```
# Load additional plugins from $LOAD_PATH
```

While browsing the files in the stack trace, I also come across this comment block in "/Users/myusername/.rbenv/versions/2.7.5/lib/ruby/2.7.0/rubygems.rb":

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1016am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

So it sounds like Rubygems inspects the files and directories inside `$LOAD_PATH` for files named "rubygems_plugin.rb", "rubygems_plugin.so", etc. and runs them when a gem is installed.  And I bet somewhere in there, `RUBYLIB` gets added to `LOAD_PATH`, which is why it's important to update `RUBYLIB` in [this PR](https://github.com/rbenv/rbenv/pull/638/commits/67f429c41de851052950ffdb372fda90a21a4356){:target="_blank" rel="noopener"}.

That may not be 100% accurate, but I feel confident that it's at least directionally accurate.  Confident enough to move on, at least.

Update- [this StackOverflow answer](https://web.archive.org/web/20160224184825/https://stackoverflow.com/questions/10117125/add-load-path-externally){:target="_blank" rel="noopener"} talks about how `RUBYLIB` is prepended to `LOAD_PATH`.  And it points to [this section of the Ruby source code](https://github.com/dbenhur/rubinius/blob/fdf984d/kernel/loader.rb#L115){:target="_blank" rel="noopener"}, which actually does the prepending.

Woo-hoo!  Mystery (FINALLY) solved!

(stopping here for the day; 1991 words)





