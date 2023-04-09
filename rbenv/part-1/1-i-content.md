In order to make sense of this question, it helps to take another look at RBENV's README file.

In [the "How It Works" section](https://web.archive.org/web/20230408051543/https://github.com/rbenv/rbenv#how-it-works){:target="_blank" rel="noopener"}, we see that if you pass the `ruby` command a filename to run in the form of `path/to/filename.rb`, RBENV will look for the `.ruby-version` file in the file's directory *even if that directory is not the one you're in now*.  And that directory may have its own `.ruby-version` file, possibly containing a different Ruby version from the one you're currently using.

If we put this knowledge together with our working knowledge of what the `if`-block does, we can see how these pieces start to fit together:

 - The first clause of the `case` statement (i.e. the `-e* | -- ) break ;;`) really doesn't do anything other than bail out of the `for`-loop early if one of these two patterns is found.
 - If any arg other than `*/*` is found in the list of args passed to the `ruby` command, the arg is simply ignored.
 - So the one clause in the `case` statement which seems to be doing most of the heavy lifting is the 2nd clause:

```
*/* )
    if [ -f "$arg" ]; then
      export RBENV_DIR="${arg%/*}"
      break
    fi
    ;;
```

Since this clause is only triggered if the filename we're running includes a `/` (aka it contains a directory), my theory is that the purpose of this logic is to handle the case where you're running a Ruby file from a different directory from the one you're in, one with a (potentially) different Ruby version.

Let's see if this is correct.

### Experiment: Does the `if`-block do what we think it does?

I make two sibling directories, named `foo/` and `bar/`, each containing a `.ruby-version` file with a different version number:

```
$ mkdir bar

$ echo "2.7.5" > bar/.ruby-version

$ mkdir foo

$ echo "3.0.0" > foo/.ruby-version
```

I then create two files named `foo/foo.rb` and `bar/bar.rb`, each containing the same thing:

```
$ echo "puts RUBY_VERSION" > bar/bar.rb
$ echo "puts RUBY_VERSION" > foo/foo.rb
```

I `cd` into `bar/` and run `bar.rb`:

```
$ ruby bar.rb

2.7.5
```

Then, **while still inside `bar/`**, I run `foo/foo.rb`:

```
$ ruby ../foo/foo.rb

3.0.0
```

This is what I'd expect with a working version of RBENV: the file I execute should (and does) retain its properly-set Ruby version, regardless of where I am when I run it.

Next, I open up the shim for the `ruby` executable:

```
$ vim `which ruby`
```

From there, **I comment out the entire `if`-block**:

```
  1 #!/usr/bin/env bash
  2 set -e
  3 [ -n "$RBENV_DEBUG" ] && set -x
  4
  5 program="${0##*/}"
  6
  7 <<'###BLOCK-COMMENT'                        # added this line
  8 if [ "$program" = "ruby" ]; then
  9   for arg; do
 10     case "$arg" in
 11     -e* | -- ) break ;;
 12     */* )
 13       if [ -f "$arg" ]; then
 14         export RBENV_DIR="${arg%/*}"
 15         break
 16       fi
 17       ;;
 18     esac
 19   done
 20 fi
 21 ###BLOCK-COMMENT                            # added this line
 22
 23 export RBENV_ROOT="/Users/myusername/.rbenv"
 24 exec "/Users/myusername/.rbenv/libexec/rbenv" exec "$program" "$@"
```

Now, back in my `bar/` directory, I re-run both `bar.rb` and `../foo/foo.rb`:

```
$ ruby bar.rb

2.7.5

$ ruby ../foo/foo.rb

2.7.5
```

With the `if`-block "removed" via a block comment, we now see that the Ruby version for `foo` does not reflect the version number specified in its `.ruby-version` file if we run `foo.rb` from within the `bar/` directory.  But if we `cd` from `bar/` into its sibling `foo/` and run `foo.rb`, it changes back to `3.0.0`:

```
$ cd ../foo
$ ruby foo.rb

3.0.0
```

This would be unexpected behavior if it were the default in RBENV.  We should be able to trust that the Ruby version of a given file will remain consistent regardless of where we run the file from.  The alternative (verifying the Ruby version every time we change directories) is less practical.

So we've proven from an empiral perspective that, whatever else the `if` block does, it also has the effect of changing the Ruby version depending on the root directory of the file we're running.  That's important, but I want to dig deeper.

Let's use git and Github to find the PR which introduced this change.  Reading the discussions inside this commit will give us added context around this design decision, and increase our confidence that we do, in fact, understand the code.

Before moving on, I make sure to remove the block-commenting from the `ruby` shim, and return it back to its original state.

## Using git + Github to find where a change was introduced

If we had the SHA for the commit from the PR in question, we could plug it into Github's search bar and pull it up.  Normally we could just use `git blame <shimfile>` to get the SHA directly from the line of code.  But the shim files are included in the `.gitignore` file for `~/.rbenv`, meaning they're not part of a git repo (and hence don't have their own SHA):

```
$ vim ~/.rbenv/.gitignore

  1 /plugins
  2 /shims                # this is how we know our `ruby` shim isn't part of RBENV's git repository
  3 /version
  4 /versions
  5 /sources
  6 /cache
  7 /libexec/*.dylib
  8 /src/Makefile
  9 /src/*.o
 10 /gems
```

However, since the shims all have the same exact code, I bet there's a great chance that the shim code lives in a single file somewhere in the RBENV codebase, and is just copy-pasted into a new file by RBENV logic somewhere, whenever a new gem is installed.

We can search the RBENV codebase for the code from the `if`-block, but first we need to pick which line of code to search for.  I pick a line which I think will not be too common in the codebase, and therefore, it will have a high signal-to-noise ratio in my search results.  Then I use [the `ag` tool](https://github.com/ggreer/the_silver_searcher){:target="_blank" rel="noopener"} to find its location:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/ag-program-equals.png">
    <img src="/assets/images/ag-program-equals.png" width="90%" alt="searching or the shim code">
  </a>
</center>

Looks like my instinct on the line of code was correct- there is only one search result, line 64 of a file named `libexec/rbenv-rehash`.  Let's have a closer look at that line of code:


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/create-prototype-shim.png">
    <img src="/assets/images/create-prototype-shim.png" width="90%" alt="the 'create-prototype-shim' method in rbenv-rehash">
  </a>
</center>

Looks like it lives inside a function called `create_prototype_shim`.  Feels like we're on the right track!

Now that we know where in the RBENV codebase the if-block comes from, let's look at the git history for that file.  I copy the filepath for `rbenv-rehash` and run `git blame` on it (docs on this command [here](https://web.archive.org/web/20230327142152/https://git-scm.com/docs/git-blame){:target="_blank" rel="noopener"}):


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-9apr2023-124pm.png">
    <img src="/assets/images/screenshot-9apr2023-124pm.png" width="100%" alt="output of the `git blame` command for the `libexec/rbenv-rehash` file">
  </a>
</center>

This is a lot of info.  Let's break down what we're looking at, using line 64 as an example:

 - `283e67b5`- this is the first 8 characters of the SHA that we're looking for.  This is what we'll plug into Github's search box.
 - `libexec/rbenv-rehash`- this is the filename we're looking at, in the form of `path/to/filename` relative to our current directory (`~/.rbenv/`).
 - `(Sam Stephenson`- this is the name of the person who authored the commit.  This is where the command `git blame` gets its name- we want to know "who to blame" (or praise, as the case may be).
 - `2012-12-27 13:41:55 -0600`- this is the full timestamp for when the code was committed to the repository.
 - `64)`- this is the line number of the code in the file itself.
 - `program="\${0##*/}"`- finally, this is the line of code itself.

As I mentioned, what we care about is the left-most column.  It contains the first 8 characters of the commit's unique identifier (also called a SHA) which introduced each line of code.  This isn't the full SHA, just a snippet, but it's almost certainly long enough to make it unlikely that we'll run into any other SHAs which start with the same 8 characters.

Lucky for us, the SHA (`283e67b5`) is the same for the entire `if`-block, so we can be fairly confident that this is indeed the SHA which introduced the entire block of code.  If there were many different SHAs, each with different commit dates, that would indicate this code had been edited and re-edited many times.  In that case, we'd have to manually search for the oldest of these commits, and possibly check out that commit to see if there were even more commits hiding underneath, making it more of a slog to find the original commit containing the info we're looking for.

I open my web browser and go to Github, where I paste the SHA value I copied from `git blame` into the search bar on the top-left and select "In this repository":

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/searching-github-for-sha.png">
    <img src="/assets/images/searching-github-for-sha.png" width="90%" alt="output of the `git blame` command for the `libexec/rbenv-rehash` file" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Although Github says "we couldn't find any code...", that's a bit misleading.  We're not looking for answers from the **codebase**, but rather from the **PR history**.  And on the left-hand side, we can see that Github did find one issue and one commit containing this SHA.  That makes me cautiously optimistic- it means we won't have to manually read through too many links to see if we're on the right track.

I right click on each section to open them in new tabs.  First the commit results:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/git-commit-history-for-sha.png">
    <img src="/assets/images/git-commit-history-for-sha.png" width="90%" alt="Github's results for the commit history containing our SHA" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Reconstructing the commit message (which was truncated due to its length), we can see at the top that the commit message for this commit was:

```
When the ruby shim is invoked with a script, set RBENV_DIR to the script's dirname
```

This definitely sounds like we're on the right track.  Let's also check [the issue link](https://github.com/rbenv/rbenv/pull/299){:target="_blank" rel="noopener"}:


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/rbenv-issue-page.png">
    <img src="/assets/images/rbenv-issue-page.png" width="90%" alt="The newer Github issue related to the PR which introduced this if-block." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The description says `This branch adjusts the behavior of the ruby shim, when invoked with the path to a Ruby script as an argument, to set RBENV_DIR to the directory of the given script.  It should, in effect, remove the need for the ruby-local-exec shebang line.`  That sounds pretty close to what we hypothesized.

Based on this, I think we can safely say that the if-block was added in order to take the Ruby script's filesystem location into account when setting the `RBENV_DIR` environment variable, *regardless of whether it's located in the current directory tree or a different one*.

## The `ruby-local-exec` shebang

But there's something here I still don't understand, specifically that 2nd sentence `It should, in effect, remove the need for the ruby-local-exec shebang line.`  It sounds like there was a previous attempt to solve the problem of setting `RBENV_DIR` which involved a special type of shebang, called `ruby-local-exec`.  That makes me wonder:

 - How did `ruby-local-exec` originally work?
 - Why did the core team feel the need to replace it?  What was wrong with it?
 - Why was our adding of the `if`-block an improvement on that old strategy?

### Looking for `ruby-local-exec`

I suspect that `ruby-local-exec` is a file.  After all, the interpreters that shebangs use (such as the `bash` in `#!/usr/bin/env bash` or the `ruby` in `#!/usr/bin/env ruby`) are just executable files, so `ruby-local-exec` might be a file too.

If it **is** a file, there must have been a git commit somewhere which introduced the file.  Maybe we can use the same strategy here that we used with the `if`-block above.

Since our original Github issue said that the need for the `ruby-local-exec` shebang had been removed, I suspect this file no longer exists in the codebase.  I run `find . -name ruby-local-exec` and no results appear, so that seems to check out.  This means I have to search Github for an older version of the repository which contains the file.

I type "ruby-local-exec" in Github's search field while inside the Github repository (i.e. while my browser is pointed to `https://github.com/rbenv/rbenv`).  When I do this, the "In this repository" option appears in a dropdown, and I select that.


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/ruby-local-exec-search.png">
    <img src="/assets/images/ruby-local-exec-search.png" width="100%" alt="Searching Github for the string 'ruby-local-exec'." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

I'm taken to a search results page, which (among other things) indicates that Github found 6 commits with this string present:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/search-results-for-ruby-local-exec.png">
    <img src="/assets/images/search-results-for-ruby-local-exec.png" width="100%" alt="Github Search results for the string 'ruby-local-exec'." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

I click on "Commits" to see which commits those were.  From there, I see a list of git commits, along with their commit messages:


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/search-results-for-ruby-local-exec-2.png">
  <img src="/assets/images/search-results-for-ruby-local-exec-2.png" width="100%" alt="Github Search results for the string 'ruby-local-exec'." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The commit labeled "Add experimental `ruby-local-exec`" [looks promising](https://github.com/rbenv/rbenv/commit/1411fa5a1624ca5eeb5582897373c58a715fe2d2){:target="_blank" rel="noopener"}, so I click on that.

From there, I'm taken to a list of files, which (in the case of this PR) is just one file- the one I want (`bin/ruby-local-exec`):


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/ruby-local-exec-commit.png">
    <img src="/assets/images/ruby-local-exec-commit.png" width="100%" alt="The original commit for the 'ruby-local-exec' file." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Great, so we finally have confirmation that `ruby-local-exec` was indeed a file at some point.

### How did the `ruby-local-exec` file work?

Now that we have the file, we can read its code to answer this question.

The code for `ruby-local-exec`, in its entirety, was:

```
set -e

cwd="$(pwd)"
dirname="${1%/*}"

cd "$dirname"
export RBENV_VERSION="$(rbenv version-name)"
cd "$cwd"

exec ruby "$@"
```

It's pretty short, so let's quickly examine each line, as we did with the shim file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The first line is:

```
set -e
```

We've seen this command before, so we know what that does- it tells `bash` to exit immediately when it encounters an error.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line:

```
cwd="$(pwd)"
```

We're storing something in a variable called "cwd", but what?

The `pwd` string looks like the `pwd` bash command I'm previously familiar with.  It stands for "print working directory", and it prints the full path for the directory you're currently in:

```
$ pwd

/Users/myusername/Workspace/OpenSource
```

And it *almost* looks like we're doing parameter expansion again, except this time the syntax uses parentheses instead of curly braces.  Is this an important difference?

I Google "bash difference between brackets and parentheses", and the first link I get is [this StackOverflow post](https://web.archive.org/web/20220703173254/https://unix.stackexchange.com/questions/267660/difference-between-parentheses-and-braces-in-terminal){:target="_blank" rel="noopener"} with this answer:


<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/parens-in-bash.png">
    <img src="/assets/images/parens-in-bash.png" width="90%" alt="What is the difference between curly braces and parentheses in bash?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

OK, so "Parentheses cause the commands to be run in a subshell."  What's a subshell?

I Google "what is a subshell bash" and get [this link](https://web.archive.org/web/20221209023619/https://en.wikiversity.org/wiki/Bash_programming/Subshells){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/what-are-subshells.png">
    <img src="/assets/images/what-are-subshells.png" width="90%" alt="What are subshells in bash?" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

So the code `cwd="$(pwd)"` creates a subshell, runs the `pwd` command inside that subshell, and stores the output of the command inside a new variable named `cwd`.  I subsequently learned that this pattern is known as ["command substitution"](https://web.archive.org/web/20230331064238/https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line in `ruby-local-env`:

```
dirname="${1%/*}"
```

This is definitely parameter expansion again, as opposed to command substitution.

What effect does the `%/*` have?  Referring back to [an earlier section of this post](/rbenv/shims/filepaths-env-vars-exports#diving-deeper-into-parameter-expansion){:target="_blank" rel="noopener"}, we're reminded that `%/*` trims off the last `/` character and everything after it.  Which makes sense if we're trying to capture a directory name in a variable named `dirname`.

To see which dirname we're storing, I run an experiment.

#### Experiment- creating our own shebang

I copy-paste the original `ruby-local-exec` into a new file in my current directory (remembering to run `chmod +x` on that new file, or else UNIX won't recognize or use it).  I add a few `echo` loglines, like so:

```
#!/usr/bin/env bash

echo "start of ruby-local-exec"

set -e

cwd="$(pwd)"

dirname="${1%/*}"

echo "dirname: $(pwd $dirname)"

cd "$dirname"
export RBENV_VERSION="$(rbenv version-name)"
cd "$cwd"

echo "just before exec in ruby-local-exec"

exec ruby "$@"
```

I then create a new file called `foo`, which looks like so:

```
#!/usr/bin/env ruby-local-exec

puts "Hello world"
```

The `ruby-local-exec` shebang is meant to execute Ruby scripts, so my `foo` script uses Ruby syntax like the `puts` statement.

The last thing I have to do is update my `PATH` variable to begin with my current directory, so that UNIX will know where to find the `ruby-local-exec` file (and therefore, it will know how to run my `foo` script).

I run the following in my terminal, using our new knowledge of command substitution to update `$PATH`:

```
$ PATH="$(pwd):$PATH"
$ which ruby-local-exec

/Users/myusername/Workspace/OpenSource/rbenv/ruby-local-exec
```

Running `which ruby-local-exec` shows me that UNIX can now find my `ruby-local-exec` command in `PATH`.

Now, when I run `./foo` in my terminal, I see:

```
$ ./foo

start of ruby-local-exec
dirname: /Users/richiethomas/Workspace/OpenSource/
just before exec in ruby-local-exec
Hello world
```

We see that `dirname` evaluates to `/Users/myusername/Workspace/OpenSource/`, the directory I'm in on my machine when I run `./foo`.

This must mean that, inside the shebang file, the parameter expansion `${1}` evaluates to the filename.  We can quickly test this by adding a logline to output just that, without any modifications to `$1`.  Above the logline for `dirname` inside my new shebang, I add:

```
echo "1: ${1}"
```

When I re-run, I get:

```
$ ./foo

start of ruby-local-exec
1: ./foo
dirname: /Users/richiethomas/Workspace/OpenSource/rbenv
just before exec in ruby-local-exec
Hello world
```

Yep, `${1}` inside the shebang evaluated to the filename.

Before moving on, I remove all the loglines I've added to `ruby-local-exec` so far, returning it to its original condition:

```
#!/usr/bin/env bash

set -e

cwd="$(pwd)"

dirname="${1%/*}"

cd "$dirname"
export RBENV_VERSION="$(rbenv version-name)"
cd "$cwd"

exec ruby "$@"
```

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
cd "$dirname"
```

Here we're just using `cd` to navigate into the dirname we just stored.  We don't yet know why (that will come later), but this line is straight-forward.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line:

```
export RBENV_VERSION="$(rbenv version-name)"
```

Here we're again using command substitution, this time to store the output of `rbenv version-name` in an environment variable named `RBENV_VERSION`.

What's the output of `rbenv version-name`?  Running it in my terminal, I see:

```
$ rbenv version-name

2.7.5
```

OK, so we're just storing the current Ruby version inside `RBENV_VERSION`.  But is it the version of the folder we're in, or the version of the folder containing our Ruby script?

### Experiment- which directory's Ruby version does `RBENV_VERSION` contain?

I add a logline inside my new shebang file, just after the assignment to `RBENV_VERSION`, which will `echo` the contents of that env var:

```
echo "RBENV_VERSION: $RBENV_VERSION"
```

I then create a `.ruby-version` file in the same directory as my `foo` script, containing only the string "2.7.5":

```
$ echo "2.7.5" > .ruby-version
```

I then navigate up one directory create a new directory called `bar`, navigate into that, and create a 2nd `.ruby-version` file in this directory, which I set to "3.0.0":

```
~/Workspace/OpenSource/rbenv (master)  $ cd ..
~/Workspace/OpenSource ()  $ mkdir bar
~/Workspace/OpenSource ()  $ cd bar
~/Workspace/OpenSource/bar ()  $ echo "3.0.0" > .ruby-version
~/Workspace/OpenSource/bar ()  $
```

Lastly, I copy my `foo` script from the `rbenv` directory into my new `bar` directory:

```
$ cp ../rbenv/foo .
```

Then, from the `bar` directory, I execute the `foo` script *in the `rbenv` directory*:

```
$ ../rbenv/foo

RBENV_VERSION: 2.7.5
Hello world
```

Lastly, when I run the copy of `foo` *in the `bar` directory*, I see:

```
$ ./foo

RBENV_VERSION: 3.0.0
Hello world
```

So when I run the copy of `foo` in the `rbenv` directory, I see that `RBENV_VERSION` is `2.7.5`.  But when I run `foo` from the `bar` directory, I see `3.0.0`.  We can therefore conclude that RBENV will first look for a `.ruby-version` file in the directory of the script that is being executed, before checking in any other locations (such as the directory the user is currently in when they execute that script).

--------

Next line of code:

```
cd "$cwd"
```

So now we're just changing back to the directory we were originally in when we stored `pwd` inside the `cwd` variable.  Essentially we just ran `cwd="$(pwd)"` so that we would know where to navigate back to after we had stored the right Ruby version inside `RBENV_VERSION`.

Last line of code:

```
exec ruby "$@"
```

Here we're using the `exec` command that we learned about [earlier](#executing-the-original-gem), using it to call `ruby`, and passing along any arguments that the script may have received.  Remember that this will be the *shim* of Ruby, not the original Ruby interpreter itself.

OK, so that's the answer to our first question, about what `ruby-local-exec` does!  Now for question #2: why did the core team feel the need to replace it?

### Why did the core team replace `ruby-local-exec`?

For this, we'll have to search for discussions amongst the core team (in the form of comments and issues on Github pages) which relate to this file.  I don't remember [our original Github issue page](https://github.com/rbenv/rbenv/pull/299){:target="_blank" rel="noopener"} containing any of those discussions, but I do remember that there was a link to a previous discussion:

<p style="text-align: center">
  <img src="/assets/images/see-previous-discussion.png" width="70%" alt="Link to an earlier discussion about ruby-local-exec." style="border: 1px solid black; padding: 0.5em">
</p>

Clicking this link, I'm taken to [the page for an earlier PR](https://github.com/rbenv/rbenv/pull/298){:target="_blank" rel="noopener"}, one that was apparently closed.  The IDs of the 2 PRs are sequential (the IDs are 298 for the cloed one and 299 for the merged one), and their intent is identical, so it's a safe bet that the earlier one was closed in favor of the later one.

### Why the switch from `.rbenv-version` to `.ruby-version`?

This PR's discussion references a file named `.rbenv-version`, which is of course different from the `.ruby-version` file we've previously discussed.  My guess is that, at some point, the RBENV core team switched from a naming convention of `.rbenv-version` to `.ruby-version`, in order to be slightly more inter-operable with other Ruby version managers.  A quick Github search in the RBENV repo for `".rbenv-version" ".ruby-version"` (so that I can find PRs which contain both terms) yields 8 results, of which [this PR](https://github.com/rbenv/rbenv/pull/302){:target="_blank" rel="noopener"} is one.  This quote in particular stands out among the comments:

<p style="text-align: center">
  <img src="/assets/images/switch-rbenv-version-to-ruby-version.png" width="70%" alt="Comments discussing the support of the '.ruby-version' filename over '.rbenv-version'." style="border: 1px solid black; padding: 0.5em">
</p>

This largely confirms my suspicions about inter-operability.

FWIW, there's also a comment by Sam Stephenson (the original author and member of the core team) saying:

```
We will maintain backwards compatibility with existing .rbenv-version files for the foreseeable future.
```

However, when I search my local version of the codebase for `.rbenv-version`, nothing is returned, whereas `.ruby-version` has plenty of references.  So I'm guessing that the plan to support the `.rbenv-version` filename convention must have scrapped at some point.

### Looking for the commit which added `ruby-local-exec`

On the right-hand side of the screen, I see the following:

<p style="text-align: center">
  <img src="/assets/images/commit-SHA-for-ruby-local-exec.png" width="50%" alt="Original commit SHA for the 'ruby-local-exec' file." style="border: 1px solid black; padding: 0.5em">
</p>

Among other things, this tells us that the SHA for this commit starts with `1411fa5`.  In my terminal, I navigate to my local copy of the RBENV codebase and run `git checkout 1411fa5`:

<p style="text-align: center">
  <img src="/assets/images/navigating-to-correct-SHA.png" width="50%" alt="Running `git checkout` to check out the correct SHA." >
</p>

I run `ls bin/ruby-local-exec` to verify that the file exists in this version of the repo, then run `git co HEAD~` to check out the commit *just before* the current one and re-run `ls bin/ruby-local-exec` to verify that the file *no longer exists*:

<p style="text-align: center">
  <img src="/assets/images/verifying-no-file-exists.png" width="50%" alt="verifying I have the correct SHA." >
</p>

This proves that `1411fa5` is indeed the SHA which introduced the shebang file.

### Checking Github for context around this SHA

Now that I know I have the SHA which introduced this file, I can plug *that* back into Github search to look for any issues or discussions around this change:

<p style="text-align: center">
  <img src="/assets/images/gh-search-using-sha.png" width="50%" alt="Github search using SHA as search term." style="border: 1px solid black; padding: 0.5em">
</p>

<p style="text-align: center">
  <img src="/assets/images/gh-search-using-sha-results.png" width="50%" alt="Results of Github search using SHA as search term." style="border: 1px solid black; padding: 0.5em">
</p>

All we see is the 1 commit which introduced this change.  There are no issues associated with this commit.  Unfortunately, that means there is no discussion around why it was introduced or what problems it solves.

## A last resort

As a last resort, I try ChatGPT haha:

<!-- ChatGPT link- https://chat.openai.com/chat/1a2694aa-d446-46b0-a1dd-f40d24377efb -->

<p style="text-align: center">
  <img src="/assets/images/chat-gpt-why-change-shebang.png" width="70%" alt="Asking ChatGPT why RBENV changed their shebang from `ruby-local-exec` to `ruby`."  style="border: 1px solid black; padding: 0.5em">
</p>

ChatGPT says that the newer `ruby` shebang is simpler, more reliable, and more portable than the old `ruby-local-exec` shebang.  Though I don't have any non-AI-generated evidence to support this, it seems like a plausible explanation.

## A warning- getting burned by ChatGPT

I don't want to imply that ChatGPT is a good resource to use in all cases.  It definitely pays to verify any claims it makes.

For example, when I was trying to figure out why files aren't executable-by-default by their creator, I hit a dead end where I couldn't find an authoritative answer online.  So once again, I turned to ChatGPT.  This time the answer it gave me was misleading.  The question I asked was:

```
In a UNIX environment, why aren't new files executable by the creator of the file until you run the `chmod`
command?  Shouldn't the file's creator automatically have the ability to execute the file?
```

And the answer it gave was:

<p style="text-align: center">
  <img src="/assets/images/chat-gpt-why-arent-files-executable-by-default.png" width="70%" alt="Asking ChatGPT why files aren't executable by their creator until `chmod` is run.">
</p>

The answer is partially correct (the goal of the policy is in fact to prevent a malicious user from executing code which could harm your system).  But I wanted to verify the statement `When a new file is created, it inherits the default permissions of the directory it was created in...`.

So I did an experiment.  I made a directory and verified that its permissions were such that the user who created it could "execute" it:

```
$ mkdir foo

$ chmod +x foo

$ ls -l

...
drwxr-xr-x   3 myusername  staff   96 Mar  6 08:43 foo
...
```

Then I created a file inside that directory.  But that file was not, by default, executable by its creator:

```
$ touch foo/bar

$ ls -l foo

total 0
-rw-r--r--  1 myusername  staff  0 Mar  6 08:43 bar
```

This implies that the `foo/bar` file did not inherit its permissions from its parent directory, and that the ChatGPT statement was incorrect.

For added confirmation, I Googled `do unix files inherit the permissions of a directory`, and got [this link](https://web.archive.org/web/20230219234547/https://info.nrao.edu/computing/guide/file-access-and-archiving/unix-file-permissions){:target="_blank" rel="noopener"} as the first result:

<p style="text-align: center">
  <img src="/assets/images/file-permissions-inheritance-in-unix-1.png" width="90%" alt="Confirming that ChatGPT was not, in fact, correct about UNIX file permissions inheritance.">
</p>

This is confirmed by [this StackOverflow post](https://web.archive.org/web/20230129173431/https://superuser.com/questions/264383/how-to-set-file-permissions-so-that-new-files-inherit-same-permissions){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/file-permissions-inheritance-in-unix-2.png" width="80%" alt="More confirmation that ChatGPT was not, in fact, correct about UNIX file permissions inheritance.">
</p>

So lesson learned- we can't trust ChatGPT implicitly.

## How was the if-block an improvement on the old solution?

Prior to this change, did RBENV use the Ruby version in the directory from which it was run, *regardless* of what the Ruby version was in the target directory?  To find out, roll back my RBENV and do an experiment.

I `cd` into my RBENV **installation directory** (i.e. `~/.rbenv`), and verify that it is a git repository by running `ls -la` and searching for the `.git` hidden directory.  Then I get the commit SHA from [this link](https://github.com/rbenv/rbenv/pull/299){:target="_blank" rel="noopener"}, which I see is SHA `e0b8938fef05dd6d08322e113015c51e79c70291`.  I then run `git checkout e0b8938fef05dd6d08322e113015c51e79c70291` to roll back my installed version to the commit which introduced this change.

Next, in my scratch directory (`~/Workspace/OpenSource`), **I open a new terminal tab**.  This way I'm still in my same directory, but opening the new tab caused my `~/.zshrc` (where I invoke `rbenv init`) to be re-run.  This ensures I'm now using the version of RBENV that I just checked out (i.e. the version corresponding to SHA `e0b8938fef05dd6d08322e113015c51e79c70291`).

I then create two directories in my scratch directory- one named `foo/` and one named `bar/`.  I create a `.rbenv-version` file inside each directory- one set to `3.0.0` in `foo/` and the other set to `2.7.5` in `bar/`.  I then create a file named `script`, which I `chmod +x` so it's executable.  The file looks like this:

```
#!/usr/bin/env ruby

ruby_version = `rbenv version`
puts "Ruby version: #{ruby_version}"
```

The `\`` backtick symbols surrounding `rbenv version` mean that we will run the `rbenv version` terminal command, and store the results in the variable named `ruby_version`.  This process is sometimes called [shelling out](https://stackoverflow.com/a/28655406/2143275){:target="_blank" rel="noopener"} to a sub-process.

I then copy the above `script` file from `foo/` into `bar/`, so an identical file exists in each new directory.  When I run `./script` from within `foo/`, followed by `../bar/script` (also from within `foo/`), I see:

```
~/Workspace/OpenSource/foo ()  $ ./script

Ruby version: 3.0.0 (set by /Users/myusername/Workspace/OpenSource/foo/.rbenv-version)

~/Workspace/OpenSource/foo ()  $ ../bar/script

Ruby version: 2.7.5 (set by /Users/myusername/Workspace/OpenSource/bar/.rbenv-version)
```

Next, back in the `~/.rbenv/` directory, I check out the commit **before** the one which introduced this change:

```
$ git co e0b8938fef05dd6d08322e113015c51e79c70291~

Previous HEAD position was e0b8938 Merge pull request #299 from sstephenson/automatic-local-exec
HEAD is now at 811ca05 Run `hash -r` after `rbenv rehash` when shell integration is enabled
```

Then, back in my `foo/` directory, **I open a new terminal tab again**.  Lastly, when I re-run my two scripts, this time I see:

```
$ ./script

Ruby version: 2.7.5 (set by RBENV_VERSION environment variable)

~/Workspace/OpenSource/foo ()  $ ../bar/script

Ruby version: 2.7.5 (set by RBENV_VERSION environment variable)

~/Workspace/OpenSource/foo ()  $
```

This time, the version numbers are the same- `2.7.5`!  Also, the source of the versions has changed- previously, along with the version number, we saw `(set by /Users/myusername/Workspace/OpenSource/bar/.rbenv-version)` in the output.  This time, we see `(set by RBENV_VERSION environment variable)`.  So in both cases, the `.rbenv-version` file was **not** being used to set the version.

### Please don't do what I did here

While searching Github for answers to the above, I actually came across [a post of mine](https://github.com/rbenv/rbenv/issues/1173){:target="_blank" rel="noopener"} on this same repository from 2019, where I asked this exact same question!

I only vaguely remember posting this, but I remember the person who answered me was much nicer and more detailed in his answer than he needed to be.  In retrospect, I'm a bit embarrassed that I posted this question instead of searching through the git history.  If everyone did what I did, open-source maintainers would be overwhelmed and would never get anything done.  I definitely don't recommend that you do what I did- instead, learn from my mistakes.  Github is not a 2nd StackOverflow.

It took multiple read-throughs of the issue at hand, spread out over many weeks, along with trial-and-error in the form of experimentation.  But **eventually** I was able to figure this out on my own, without relying on the above post.  If you've read this far and slogged through all my experiments with me, I'm confident you can do likewise.
