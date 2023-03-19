From the section "How rbenv hooks into your shell", I see one of the things that `rbenv init` does is:

```
Installs autocompletion. This is entirely optional but pretty useful. Sourcing `~/.rbenv/completions/rbenv.bash` will set that up. There is also a `~/.rbenv/completions/rbenv.zsh` for Zsh users.
```

OK, so then what is auto-completion (in the `rbenv` sense)?  Let’s take a look at the contents of that folder:

<p style="text-align: center">
  <img src="/assets/images/contents-of-completions-dir.png" width="70%" alt="Contents of the 'completions/' directory"  style="border: 1px solid black; padding: 0.5em">
</p>

Only two files.  Maybe inspecting them will give us a clue?

I’m going to start with the file ending in `.zsh`, since that’s the shell program I use.

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

Another bash script to sink our teeth into!  Let’s start at the top and dive into lines 1-3 first:

```
if [[ ! -o interactive ]]; then
    return
fi
```

This is the first time I’ve seen an exclamation inside a square-bracket or double-bracket conditional before.  From my experience with Ruby, I’m guessing it negates the subsequent conditional statement.  And `man test` seems to support that:

<p style="text-align: center">
  <img src="/assets/images/man-test-bang.png" width="70%" alt="Searching for the exclamation mark in the man entry for the test command"  style="border: 1px solid black; padding: 0.5em">
</p>

So `! expression` is true if `expression` is false.

What does "-o" do?  I don't see anything in the `man test` page for a flag called `-o`.  [StackOverflow to the rescue](https://archive.ph/DcMdD):

```
-o : True if shell option "OPTIONNAME" is enabled.
```

To test this, I run the following in my terminal:

```
$ set +o verbose
$ [[ -o verbose ]] && echo "TRUE"

$ set -o verbose
$ [[ -o verbose ]] && echo "TRUE"
[[ -o verbose ]] && echo "TRUE"
TRUE

$ set +o foobar
set: no such option: foobar
```

The above tells us that:

We can set and unset options (such as "verbose") with our old friend, "set".
We can check if those options are set or unset by passing "-o" to the "test" command (or the bracket syntax)
The option that we set/unset must be one of certain values that are recognized by the shell (‘verbose’ is recognized, but ‘foobar’ is not)

(stopped here for the day; 2013 words)

When we put all the above knowledge together, we see that the first thing this script does is check whether the ‘interactive’ option is set.  If it’s not, we immediately return out of the script.

What is the ‘interactive’ option, you ask?  [The GNU docs](https://web.archive.org/web/20220727100637/https://www.gnu.org/software/bash/manual/html_node/What-is-an-Interactive-Shell_003f.html) give us an answer:

```
An interactive shell generally reads from and writes to a user’s terminal.
```

And StackOverflow [fills in some of the gaps](https://web.archive.org/web/20220423122639/https://unix.stackexchange.com/questions/50665/what-is-the-difference-between-interactive-shells-login-shells-non-login-shell) in the above answer:

```
Interactive: As the term implies: Interactive means that the commands are run with user-interaction from keyboard. E.g. the shell can prompt the user to enter input.

Non-interactive: the shell is probably run from an automated process so it can't assume it can request input or that someone will see the output. E.g., maybe it is best to write output to a log file.
```

Good enough for now.  Next line of code is:

```
compctl -K _rbenv rbenv
```

I don’t recognize the `compctl` command, so let’s look it up.

```
$ man compctl
No manual entry for compctl
$ help compctl
compctl is a shell builtin
```

<p style="text-align: center">
  <img src="/assets/images/help-compctl.png" width="70%" alt="help page entry for the `compctl` command"  style="border: 1px solid black; padding: 0.5em">
</p>

The text that looks most relevant is:

```
Control the editor's completion behavior according to the supplied set of options.  Various editing commands, notably expand-or-complete-word, usually bound to tab, will attempt to complete a word typed by the user, while others, notably delete-char-or-list, usually bound to ^D in EMACS editing mode, list the possibilities; compctl controls what those possibilities are.  They may for example be filenames (the most common case, and hence the default), shell variables, or words from a user-specified list.
```

OK, so `compctl` appears to help the user alter the behavior of the shell’s completion behavior.  But what are shell completions, in layman’s terms?  [This blog post](https://web.archive.org/web/20220611155916/https://scriptingosx.com/2019/07/moving-to-zsh-part-5-completions/) appears to be the best answer:

<p style="text-align: center">
  <img src="/assets/images/blog-article-on-completions.png" width="70%" alt="blog article on tab completions"  style="border: 1px solid black; padding: 0.5em">
</p>

> Man shells use the tab key (⇥) for completion. When you press that key, the shell tries to guess what you are typing and will complete it, or if the beginning of what you typed is ambiguous, suggest from a list of possible completions.

OK so this does in fact have to do with tab completions from within the terminal.  I still don’t feel like I have a good understanding of

For instance, what does that `-K` flag do?  I run `help compctl` again and do a `/` search for `-K`:

<p style="text-align: center">
  <img src="/assets/images/help-results-for-compctl-k-flag.png" width="70%" alt="help page for compctl, searching for the -K flag"  style="border: 1px solid black; padding: 0.5em">
</p>

```
Call the given function to get the completions.  Unless the name starts with an underscore, the function is passed two arguments...
```

OK, so `compctl -K _rbenv rbenv` calls the `_rbenv` function.  Since it starts with an underscore, it must not pass the two arguments mentioned above.

SIDE RANT- it would be nicer if the man page was explicit about what happens when the name *does* start with an underscore, instead of just leaving us to guess that’s what happens.  Otherwise, how would we know that the # of args passed is zero, and not 1 (or 3)?  Luckily we can guess with confidence that it’s zero, since we have code for the `_rbenv` function and can see that its signature takes zero args, but if we didn’t have that then we’d be screwed.  This is frustrating for me because it’s another example of the user interface of computers being unfriendly to beginners, and it’s one reason why it has taken me this long to feel confident spelunking on my own. </endrant>

Unfortunately, I had to resort to watching [a Youtube video](https://www.youtube.com/watch?v=BHxaUP0kz9w&ab_channel=DevInsideYou).  I say "unfortunately" because, as useful as they sometimes are, they aren’t archivable for posterity in the same way that text pages are with services like archive.org and others.  It would be cool if they were archivable in this way, but videos take up a lot of space on a hard drive, and archiving all the world’s videos would be prohibitively expensive.  So hopefully the above video link is still available at the time you’re reading this.  It was a great video, made by [a guy named Vlad](https://www.linkedin.com/in/agilesteel/?originalSubdomain=ge) who has a channel called [DevInsideYou](https://devinsideyou.com/).  Although Vlad is a Scala developer and his videos have a distinct Scala bent to them, that didn’t interfere with me learning from them at all.

Just in case it’s no longer available, I’ll summarize what I learned below:

 - "A completion is a feature of a shell (zsh, in our case) that allows the shell to finish typing a command for you... this is usually accomplished by hitting the `tab` key, but this is configurable."
 - "It’s quite common for shells to dig deeply into command line tools like git, docker, etc. and understand their sub-commands and arguments."
 - "zsh comes with quite a few completions out-of-the-box, but if you have a tool that zsh doesn’t know, you can teach it."
 - Lots of examples and demos on tab completions.
 - `$fpath`- an array of directories containing files which contain completion functions.
 - zsh calls these functions "widgets" if you start them with an underscore.
 - There’s also `$FPATH` (i.e. all caps) which looks much more like your standard `$PATH` variable (with directories delimited by `:`).
 - If zsh doesn’t have a certain completion, there are various ways to get what you need (plugins, write them yourself, etc.), but at the end of the day, they’re going to need to live in one of the directories of your `$fpath`.

The video also has links to [the section of the zsh docs related to completions](https://zsh.sourceforge.io/Doc/Release/Completion-System.html#Completion-System), and a Github repo containing [a README on how to write your own completions](https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org).

After reading a bit of the 2nd link, I feel like I can make an educated guess of what `compctl -K _rbenv rbenv` does: it tells the shell that, when trying to autocomplete `rbenv` in the terminal, we first call the `_rbenv` shell function.  That function will set the value of a `reply` shell variable equal to an array of... something (we’ll dig into that next).  What I’m confused about is, why does `reply` appear to be a local shell variable, and not an environment variable which would be available outside this script?

Apparently, it’s not!  I did an experiment with the following bash script:

```
#!/usr/bin/env bash

  _foo() {
  bar='5'
  echo $bar
}

_foo
echo $bar
```
My script calls the `_foo` function at the 2nd-to-last line of code, and then prints the value of `$bar` at the last line of code.  In both cases, the output is `5`.  If `bar` were locally-scoped to just the body of the `_foo` function, I would expect referencing it outside that function to throw an error (or at least print an empty line), but it does not.  Hence, `bar` (and by extension, `reply`) exist outside the scope of the functions they’re declared in.

So how do you make a variable local to just its own function scope?  That’s what the `local` command does on the first line of code inside the `_rbenv()` function:

```
  local words completions
```
According to [Linuxtopia](https://web.archive.org/web/20220628155250/https://www.linuxtopia.org/online_books/advanced_bash_scripting_guide/localvar.html), "A variable declared as local is one that is visible only within the block of code in which it appears. It has local "scope". In a function, a local variable has meaning only within that function block."

We confirm this when I update my script to make `bar` local:

```
#!/usr/bin/env bash

  _foo() {
  local bar='5'
  echo $bar
}

_foo
echo $bar
```

When I call my script, I only see the output of `_foo` (i.e. one instance of `5` in the output, not two instances).

(stopping here for the day; 3170 words)

Next line of code is:

```
read -cA words
```

Checking the `help` page for `read`, we see:

<p style="text-align: center">
  <img src="/assets/images/help-page-for-read-command.png" width="70%" alt="help page for the `read` command"  style="border: 1px solid black; padding: 0.5em">
</p>

So where do we "read one line" *from*?  Is it from the argument of the function (of which there are none, in our case), from some environment or shell variable whose name is known by people with more experience than me, or somewhere else entirely that I can’t even think of because I don’t know what I don’t know?

Another resource, [LinuxHunt](https://web.archive.org/web/20220629000155/https://linuxhint.com/bash_read_command/), helps us out:

```
Read is a bash builtin command that reads the contents of a line into a variable. It allows for word splitting that is tied to the special shell variable IFS. It is primarily used for catching user input but can be used to implement functions taking input from standard input.
...
Interactive bash scripts are nothing without catching user input. The read builtin provides methods that user input may be caught within a bash script.
...
To catch a line of input NAMEs and options are not required by read. When NAME is not specified, a variable named REPLY is used to store user input:

{
echo -n "Type something and press enter: ";
read;
echo You typed ${REPLY}
}
```


To test out the above example, I try the following experiment script:

```
#!/usr/bin/env bash

echo "Please enter your name:";
read;
echo "Your name is $REPLY."
```

The above test works as expected:

```
$ ./foo
Please enter your name:
Richie
Your name is Richie.
```

Lastly, a site called [ComputerHope](https://archive.ph/NDo7d) tells us:

<p style="text-align: center">
  <img src="/assets/images/computerhope-read-command.png" width="70%" alt="Description of the `read` command from ComputerHope"  style="border: 1px solid black; padding: 0.5em">
</p>

Cool, so `read` reads from standard input.  That’s pretty unsurprising.  And it stores the results in the name of the variable you pass it (in the case of our code, `words`).  This is starting to make sense.

But what do the `-A` and `-c` flags do?  Checking the `help` page again, we see:

<p style="text-align: center">
  <img src="/assets/images/read-command-a-and-c-flags.png" width="70%" alt="The -A and -c flags for the `read` command"  style="border: 1px solid black; padding: 0.5em">
</p>

I tried to put together an experiment script here:

```
#!/usr/bin/env zsh

compctl -K _foo foo

_foo() {
  foo=(1 2 3 4 5)
  echo "Please enter your name:";
  read -cA foo;
  reply=("$foo")
}

foo
```

My theory was that `compctl -K _foo foo` was telling zsh to call the `_foo` function whenever it saw `foo` called in the shell or in a script.  I was expecting to at least see `Please enter your name:` in the terminal, but nothing happened, not even an error.

This is when I decided to try a straight copy-paste of the example code in the `help` page:

```
$ function whoson { reply=(`users`); }
$ compctl -K whoson talk
```

I then tried `which talk` to see if there was already a command named `talk` somewhere.  Turns out there is:

```
$ which talk
/usr/bin/talk
```

I then had the thought that maybe `compctl -K whoson talk` tells zsh to call `whoson` for a list of the auto-complete commands whenever `talk` is called and the user then hits the tab key.  This appears to be what happens:

```
$ talk myusername myusername myusername
```

My username appeared everytime I hit the `tab` key.  For the record, the `users` command simply returns `myusername` on my machine, since I’m the only user.

OK, that cleared things up substantially.

I have an idea for a more informed experiment.  I make a subdirectory in my root dir named `~/completions` and I add some `compctl` code to it, along with a function:

```
#!/usr/bin/env zsh

compctl -K foo grep

foo() {
  reply=(foo bar baz)
}
```

Then I add my new directory to `fpath`:

```
$ fpath=(~/completions $fpath)
```

My theory is that `foo`, `bar`, and `baz` should show up as options when I try to tab-complete after typing `grep` in my terminal.  But unfortunately, that’s not what happens.  I just see a list of files and directories in my current directory.

Then I try the original `whoson` example again, except I rename `whoson` to `foobar` and change "reply=(`users`)" to "reply=(foo bar baz);".  That works:

<p style="text-align: center">
  <img src="/assets/images/possible-experiment-results-for-completions-1.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So why does it work when I paste the commands directly into the terminal, but not when I add a completion file and update my `$fpath`?

I hope it’s not some stupid syntax error I made... but it probably is lol.

I open up a brand-new terminal tab and update my $fpath again.  I get the same result- no `foo bar baz` options when I tab-complete, just a list of files/subdirectories.

I add the example code to the completion file I created:

```
#!/usr/bin/env zsh

function foobar { reply=(foo bar baz); }

foo() {
  reply=(foo bar baz);
}

compctl -K foo talk
compctl -K foobar grep
```

When I try tab-complete with `grep`, I don’t see my `foo bar baz` options either.  So now I’m thinking it’s a problem with the way I added the completions file to my $fpath.

I remember that, in addition to $fpath, there’s $FPATH.  I try updating $FPATH instead:

```
$ FPATH="Users/myusername/Workspace/mavenlink/completions:$FPATH"
$ echo $FPATH

Users/myusername/Workspace/mavenlink/completions:Users/myusername/Workspace/mavenlink/completions:/usr/local/share/zsh/site-functions:/usr/share/zsh/site-functions:/usr/share/zsh/5.8.1/functions

$ grep
$ talk
```

With both `grep` and `talk`, I continue to see the directory contents, not `foo bar baz`.

What about if I temporarily copy my completion file into one of the other directories in $fpath?

```
$ cp completions/_foo /usr/local/share/zsh/site-functions
$ grep
$ talk
```

Still nothing but directory contents.

Then I wonder whether the completion filename has to be the same as the command I’m trying to tab-complete?

```
$ mv completions/_foo completions/_talk
$ talk
```

Still no better.

Just in case the completion file needs to be renamed AND it needs to be moved to the `site-functions` directory above, I try that:

```
$ mv completions/_talk /usr/local/share/zsh/site-functions
$ talk
```

No dice.

I try moving the call to `compctl` from before the function definition, to after it:

```
#!/usr/bin/env zsh

_foobar() {
  reply=(foo bar baz)
}

compctl -K _foobar talk
```

Still no luck.

I kind of feel like I’m throwing spaghetti at a wall here.  This is where my tendency to give up starts to kick in.  However, I’m writing all this down in order to force myself to power through those moments.  I feel like I have to keep going, but I remember it’s OK to take a break until tomorrow if I need to.

I remember [the video I watched yesterday](https://www.youtube.com/watch?v=BHxaUP0kz9w&ab_channel=DevInsideYou).  And I remember that one of the links in the description was a link to the official ZSH docs, specifically [the section on tab completions](https://web.archive.org/web/20220807190213/https://zsh.sourceforge.io/Doc/Release/Completion-System.html).

This line of the docs stands out:

<p style="text-align: center">
  <img src="/assets/images/docs-on-compinit-and-maybe-compdef.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The current first line of code in my file is a shebang, `#!/usr/bin/env bash`.  Perhaps I need to change it to one of the specified tags?  Perhaps `compdef foobar`?

I make the above replacement, and try again.  Still no luck.  I even try `autoload compinit` and `compinit -i` again (I remember seeing these commands on a StackOverflow answer or a blog article or something), but still no luck.

Further down in the doc, I see:

```
The function compdef can be used to associate existing completion functions with new commands. For example,

`compdef _pids foo`

uses the function `_pids` to complete process IDs for the command `foo`.
```

I update the `compdef` statement to say `#compdef _foobar foobar` and try again.  Still no luck.

(stopping here for the night; 4466 words)

As a side note, one point I didn’t capture well enough when I was writing the above is that I *was in fact* able to get autocomplete to work by doing the following:

 - Creating a new folder called "completions"
 - Creating another new folder called "commands"
 - Adding the "commands" folder to $PATH
 - Creating a file named "_foobar" inside "completions" with the following code:

```
#!/usr/bin/env bash

function _foobar { reply=(foo bar baz); }

compctl -K _foobar foobar
```

 - Creating a file named "foobar" in "commands" with the following code:

```
#!/usr/bin/env bash

echo "Hello"
echo "args:"

echo "$@"
 ```
 - Running "source completions/_foobar".

The above results in the expected autocomplete behavior when I type in "foobar" and hit "tab":

<p style="text-align: center">
  <img src="/assets/images/results-of-tab-completion.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I discovered the above by re-examining the code in the rbenv repo’s "libexec/rbenv-init" file, which does something similar [here](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-init#L99).  Although simply typing `echo "source $filename"` won’t by itself source the given $filename (it just prints "source $filename" to your screen), running `eval `echo "source baz/buss"`` does in fact source the file.  And the code inside `rbenv-init` is meant to be wrapped inside a call to `eval`.  In fact, if you try to just run `rbenv init` in your terminal, you’re given the following instructions:

```
$ rbenv init
# Load rbenv automatically by appending
# the following to ~/.zshrc:

eval "$(rbenv init - zsh)"
```

I think *a lot* of my confusion yesterday and the day before was due to me believing that adding my "completions" directory to $fpath should result in zsh automatically searching in that folder whenever I attempt a tab-complete, coupled with a desire to fully understand everything I had encountered in the docs / StackOverflow posts / Youtube videos I had processed over the last few days.  This tenacity can be useful when trying to solve a difficult problem that’s an immediate blocker to my progress, but it can also cause me to stubbornly bang my head against the wall trying to squeeze every last bit of knowledge out of a line of code, no matter how irrelevant it is to my immediate goal.

I still don’t know how to get zsh to recognize completion code without `source`’ing the file which contains the call to `compctl -K` (I suspect it has something to do with calling `autoload compinit` and/or `compinit -i`, based on posts I read in a haze of confusion), but that knowledge isn’t a blocker to my immediate goal of understanding the `rbenv` repo.  So I decide to save that quest for another day.

Let’s move on to the next line of code:

```
  if [ "${#words}" -eq 2 ]; then
```
Here we see the `${...}` parameter expansion syntax again.  I look up [the docs for parameter expansion](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) again, and search the page for the `#` string, and I see the following:

<p style="text-align: center">
  <img src="/assets/images/param-expansion-docs-2.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So it looks like `#foobar` inside the curly braces is the same as saying "give me the length of the ‘foobar’ variable".  As an experiment, I try the following in my terminal:

```
$ foo="foo bar"
$ echo "${#foo}"
7
```

Makes sense so far.  Since I know (or suspect?) that `words` is an array in the `rbenv` code, I try the following as well:

```
$ foo=(bar baz)
$ echo "${#foo}"
2
```

Sweet, so zsh is smart enough to alter its method for checking length depending on whether the test subject is a string or an array.
So our line of code says "If the length of ‘words’ is equal to 2, then..."

Then what?  Next line of code is:

```
completions="$(rbenv commands)"
```

Looks like we’re setting the value of the `completions` variable equal to "$(rbenv commands)".  But I notice something subtle here- we’re using parentheses, not curly braces here.  I don’t remember seeing this so far.  What’s the difference?  Is this still considered parameter expansion?  I search [the parameter expansion docs](https://web.archive.org/web/20220816200045/https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) for "$(", but don’t find anything.  I Google "dollar sign plus parens zsh" and find [a useful StackOverflow answer](https://web.archive.org/web/20220720215040/https://stackoverflow.com/questions/17984958/what-does-it-mean-in-shell-when-we-put-a-command-inside-dollar-sign-and-parenthe):

```
Usage of the `$` like `${HOME}` gives the value of `HOME`. Usage of the `$` like `$(echo foo)` means run whatever is inside the parentheses in a subshell and return that as the value. In my example, you would get `foo` since `echo` will write `foo` to standard out
```

Short and sweet.  So in our case, we’re storing the return value of `rbenv commands` as the contents of the `completions` local variable.  Does it store the contents as a string, or as an array?  To answer this, I need to know how to print a variable’s type in the terminal.  StackOverflow [to the rescue](https://web.archive.org/web/20220714213343/https://unix.stackexchange.com/questions/269825/how-can-i-get-a-variables-datatype-in-zsh):

<p style="text-align: center">
  <img src="/assets/images/how-to-print-a-variables-type.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="how to print a variable's type">
</p>

Looks like I need to use parameter expansion, coupled with `(t)` before the variable name.  With that in mind, a quick experiment:

```
$ foo=(1 2 3)     # sanity check to make sure we get ‘array’ as expected
$ echo "${(t)foo}"
array

$ foo="$(rbenv commands)"
$ echo "${(t)foo}"
scalar
```

Great, so we’re storing the output of `rbenv commands` as a single string, not as an array of strings.

At this point, I’m wondering why `2` is the magic number that we’re checking against the length here.  Why not 1, or 3?

To answer this, I want to print out the value of the local variable `words` (as well as its length) to the screen when I try to tab-complete using the `rbenv` command.  But to do this, I have to actually go into my local `rbenv` installation and edit its code.  Exciting, right?

Since I don’t know where that code lives, I have to find where it was installed.  I know I installed `rbenv` using `homebrew`, so I Google "homebrew where is package installed".  [The first link](https://web.archive.org/web/20220827131359/https://mkyong.com/mac/where-does-homebrew-install-packages-on-mac/) tells me to check in `/usr/local/Cellar`.  I do so, and I find the directory `/usr/local/Cellar/rbenv/1.2.0/` which includes the `completions` directory and the `rbenv.zsh` file I’ve been reading in Github.  I open it up and it looks the same as what I’ve seen so far:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

I edit it to include the following 3 `echo` statements after `read -cA words`:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  echo "inside _rbenv"
  echo "words: $words"
  echo "words.length: ${#words}"

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

In order for bash to see the new lines of code, I suspect that I have to re-run `rbenv init`.  I don’t think it can hurt to do so, so I go for it:

```
$ eval "$(rbenv init - zsh)"
```

Then when I type `rbenv` plus a space and hit `tab`, I see:

<p style="text-align: center">
  <img src="/assets/images/results-of-tab-complete-1223pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="results of tab complete attempt">
</p>

So the length of `words` is 2 when the user just types `rbenv` with nothing else.  That’s unexpected; shouldn’t it be a length of 1, since I only typed one word?

At any rate, I follow this up by typing `rbenv foo`, and get the following:

<p style="text-align: center">
  <img src="/assets/images/results-of-tab-complete-attempt-1225pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="results of tab complete attempt">
</p>

So there’s a phantom extra word in the `words` array.  I think I can discover what it is by printing each element in `words`.  I update the completion file to add the following `for` loop below my previous `echo` statements:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  echo "inside _rbenv"
  echo "words: $words"
  echo "words.length: ${#words}"

  for word in "$words[@]";
  do
    echo "word: $word"
    echo "word type: ${(t)word}"
    echo "word length: ${#word}"
    echo "---"
  done

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

Note that the `[@]` syntax is something I saw in a previous StackOverflow post, and its function (I believe) is to tell the `for` loop that the value of `$words` is an array, so you can iterate over it.

When I type `rbenv foo bar` and hit tab, I see:

<p style="text-align: center">
  <img src="/assets/images/results-of-tab-complete-attempt-1244pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="results of tab complete attempt">
</p>

So it looks like the phantom word is an empty string.  Not sure where that comes from or why zsh would pass that empty string to the completion function, but there you go.

Before I close up shop for the day, I make sure to clean up the `echo` statements and the `for` loop I added, returning the completion file to its former state:

```
if [[ ! -o interactive ]]; then
    return
fi

compctl -K _rbenv rbenv

_rbenv() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(rbenv commands)"
  else
    completions="$(rbenv completions ${words[2,-2]})"
  fi

  reply=("${(ps:\n:)completions}")
}
```

(stopping here for the day; 5659 words)

Next line of code:

```
completions="$(rbenv completions ${words[2,-2]})"
```
Again, we’re storing a value in the `completions` local variable, but it’s a new value now, namely the result of the "rbenv completions" command, plus whatever "words[2, -2]" evaluates to.  Let’s see what that is first, then we can add it to "rbenv completions" and plug it into our terminal to see what the final output is.

Recall from the earlier "echo" attempts that "words" was equal to an array of "rbenv", "foo", and "bar".  We don’t need to add our "echo"s back to the script; now that we know what the value of "words" was, we should be able to just make a new array in our terminal and play with that:

```
$ words=(rbenv foo bar baz buzz quox)
$ echo "$words[2, -2]"
foo bar baz buzz
```

So "words[2, -2]" takes the values in the array starting with the 2nd item, and ending at the 2nd-to-last item, inclusive.  The only surprise (for me) is that the terminal accesses an array with an index in a 1-based (not 0-based) fashion:

```
$ echo "$words[0]"

$ echo "$words[1]"
rbenv
$ echo "$words[2]"
foo
```

At first this was only mildly surprising, but it kinda started to gnaw at me.  This is actually kind of a big difference between programming in my terminal and in literally every other language I’ve ever worked with.  I could just let this go, but I decide to spike on figuring out what the deal is here.

And I’m glad I did, because [this StackOverflow answer](https://web.archive.org/web/20220818031527/https://stackoverflow.com/questions/50427449/behavior-of-arrays-in-bash-scripting-and-zsh-shell-start-index-0-or-1) made me do a double-take:

<p style="text-align: center">
  <img src="/assets/images/so-answer-50427449.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer on array access in different shells">
</p>

```
TL;DR:
 - bash array indexing starts at 0 (always)
 - zsh array indexing starts at 1 (unless option KSH_ARRAYS is set)

To always get consistent behaviour, use:

${array[@]:offset:length}
```

So `bash` accesses arrays the way I would expect, but `zsh` doesn’t?  Now I’m getting curious.

First, let’s confirm whether the latest script experiments above actually do perform differently in `bash`.  We’ll do this by putting them inside a script file with a `bash` shebang (which I named `foo`):

```
#!/usr/bin/env bash

words=(rbenv foo bar baz buzz quox)
echo "$words[2, -2]"
echo "$words[0]"
echo "$words[1]"
echo "$words[2]"
```

Then, back in the terminal:

```
$ chmod 777 foo
$ ./foo
rbenv[2, -2]
rbenv[0]
rbenv[1]
rbenv[2]
```
Well, OK.  So that didn’t work as expected- for example, it printed `rbenv[1]` instead of the value stored at the corresponding array position.  I Google "accessing an array in bash", and [it turns out](https://web.archive.org/web/20211201072516/https://tecadmin.net/working-with-array-bash-script/) I just needed to wrap `words[...]` inside curly braces:

<p style="text-align: center">
  <img src="/assets/images/creating-bash-array.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Creating an array in bash">
</p>

I update my script accordingly:

```
#!/usr/bin/env bash

words=(rbenv foo bar baz buzz quox)
echo "${words[2, -2]}"
echo "${words[0]}"
echo "${words[1]}"
echo "${words[2]}"
```

Now when I re-run the script, I see:

```
$ ./foo
./foo: line 4: words: bad array subscript

rbenv
foo
bar
```

Hmmm, OK so according to [this link](https://web.archive.org/web/20170309012959/http://askubuntu.com/questions/705126/is-there-a-way-to-specify-a-certain-range-of-numbers-using-array-in-a-script), the way I’m accessing a range of values in the bash script needs tweaking.  I change the syntax to look like this:

```
#!/usr/bin/env bash

words=(rbenv foo bar baz buzz quox)
echo "${words[@][2, -2]}"
echo "${words[0]}"
echo "${words[1]}"
echo "${words[2]}"
```


And I try again:

```
$ ./foo
./foo: line 4: -2: substring expression < 0
rbenv
foo
bar
```

OK, so lines 5 thru 7 worked, but line 4 caused an error (`-2: substring expression < 0`).  So we can’t use negative numbers to access a substring in bash?

[It looks like you can](https://web.archive.org/web/20211219125555/https://unix.stackexchange.com/questions/198787/is-there-a-way-of-reading-the-last-element-of-an-array-with-bash), but only with bash v4.1 or newer.  If I want to do something similar in earlier versions (like v3.2.57,  aka the version on my machine), I need to do something like this:

```
echo "${words[@]:2:${#words} - 2}"
```

All of this is just to say, this is another example that I *really* should be doing my experiments in actual script files, not just in the terminal.

At any rate, we’re in the file `rbenv.zsh`, so we don’t have to worry about the above `bash` syntax because, by the time we’ve reached the current line of code, we know we’re no longer in bash-land.

That said, one of the StackOverflow screenshots above implies that the value of the `KSH_ARRAYS` variable could affect the behavior of `rbenv`’s .zsh script.  I wonder if `rbenv.zsh` accounts for that.  Maybe I could check this by simply adding `KSH_ARRAYS=true` before I run the script, and seeing if the value for `words[1]` changes?

I make a new, stripped-down test script:

```
#!/usr/bin/env zsh

words=(rbenv foo bar baz buzz quox)
echo "words[1]: ${words[1]}"
```
When I run it, I get:

```
$ ./foo
words[1]: rbenv
```

Next, I try to run it again with the env var prefix I mentioned:

```
$ KSH_ARRAYS=true ./foo
words[1]: rbenv
```

So that didn’t work.  After I Googled around a bit for "KSH_ARRAYS", I learned that [KSH_ARRAYS is a zsh option](http://bolyai.cs.elte.hu/zsh-manual/zsh_16.html), not an environment variable.  I then Googled "how to set zsh options", [I learned](https://archive.ph/QGwEP) that you have to use the `setopt` command to set an option, and `unsetopt` to unset it.  I update the script as follows:

```
#!/usr/bin/env zsh

setopt KSH_ARRAYS

words=(rbenv foo bar baz buzz quox)
echo "words[1]: ${words[1]}"
```
This works!

```
$ ./foo

words[1]: foo
```

Now I’m wondering if this phenomenon does, in fact, affect the RBENV tab-completion feature.  I run `vim /usr/local/Cellar/rbenv/1.2.0/completions/rbenv.zsh` again and add the following `echo` call after `read -cA words`:

```
echo "words[2,-2]: ${words[2,-2]}"
```

I then run the following in my terminal:

```
$ unsetopt KSH_ARRAYS
$ rbenv foo bar baz
```

When I try to tab-complete after "baz ", I get:

```
words[2,-2]: foo bar baz
```

I then set `KSH_ARRAYS` and try again:

```
$ setopt ksharrays
$ rbenv foo bar baz
```

This time, I see:
```
words[2,-2]: bar baz
```

So now I do know for a fact that a zsh user whose `KSH_ARRAYS` zsh option has been set will see weird behavior in their RBENV autocomplete.

Should I make a PR to override it just inside this script to ensure the user’s local value doesn’t trip up the script?  What would that look like?

Well, I’d have to store the user’s current value for that option, then unset it.  Then the script would continue running as per usual.  Then after the script runs, I’d have to set the option back to its original value.

If I can figure out how to do the above, it seems pretty straightforward.  But has this already been thought of and/or tried?  I check the RBENV repo’s history for both `KSH_ARRAYS` and `ksharrays` (since [I read that](https://archive.ph/QGwEP) "The labels of the options are case insensitive and any underscores in the label are ignored" by the zsh interpreter).  In both cases, I don’t see any history:

<p style="text-align: center">
  <img src="/assets/images/ksh-arrays-history-in-github.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Searching for `KSH_ARRAYS` history in RBENV's Github repo">
</p>

I think this means we’re good to go!

(stopping here for the day; 6724 words)

OK, so how to store the value and reset it after the script is done?

I come up with the following test script:

<p style="text-align: center">
  <img src="/assets/images/test-script-102pm11mar.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="KSH_ARRAYS test script">
</p>

Lines 3-9 capture the user’s original `ksharrays` setting.  Then we unset the option on line 11, then on lines 15-18 we reset it back if the option was originally set.

However when I set the option in the terminal via `setopt ksharrays` and run this script, I don’t see the `echo` statements that I expect (`"setting ksharrays_is_set to 1..."` and `"setting the ksharrays option..."`).  When I set the option directly in the script (via a call to `setopt ksharrays` on line 2, directly below the shebang), I do see those `echo` statements.

I also try adding `setopt ksharrays` to both `~/.zshrc` and `~/.zshenv`, and confirming that the `setopt` took effect by running `setopt` without args in my terminal, but no dice.

[I post a question](https://unix.stackexchange.com/questions/715638/zsh-why-isnt-my-script-reading-my-option-setting) on StackExchange, and wait for an answer.  In the meantime, I know there must be a difference between my experiment script and the rbenv completion script, because they’re behaving in different ways.  My script is not respecting the `ksharrays` option that I’m setting unless it’s set directly in the script, while the `echo` statements that I added to the completion script change their output depending on whether `ksharrays` is `set` or `unset`.  So I continue to believe that a PR to the `rbenv` repo is still needed.

Eventually, a StackExchange user [replies to my question](https://unix.stackexchange.com/a/715678/142469) with an answer.  TL;DR- running a shell script from inside your terminal doesn’t cause your terminal’s zsh options to carry over into the executed shell script.  However, if you’ve previously defined a tab-complete function via a file that’s been `source`’ed, the shell options which are included in the scope of the function aren’t picked up until the function is called from your terminal, which (in the case of tab-complete) is when you type in your command and hit tab.

I create a PR (which may or may not even be merged) to prevent a zsh user’s errant `KSH_ARRAYS` option from affecting the tab-complete.  PR [here](https://github.com/rbenv/rbenv/pull/1422).

Honestly, the more I think about this, the more I doubt the RBENV maintainers will give the thumbs-up to my PR.  The whole thing is predicated on the idea that a greater-than-zero number of people will override their `KSH_ARRAYS` option in zsh.  But if no one in the 10+ year history of RBENV has submitted a Github issue about this, it’s probably an incredibly small value-add, if it adds value at all.  This PR is purely speculative in nature until someone actually runs into a problem in the wild, therefore the PR could be a solution in search of a problem.

I still want to keep the PR open, because I do think this process has been an educational experience and I’d like that education to continue in the form of feedback from the maintainers.

However, according to [this link](https://web.archive.org/web/20220512071954/https://blog.mads-hartmann.com/2017/08/06/writing-zsh-completion-scripts.html), the canonical way of setting up a tab completion is to create a file whose directory is one of those listed in `$fpath`.  Right now, it looks like RBENV uses a different approach, i.e. it has pre-existing files in the `completions` directory which include a call to `compctl -K`, and it runs `source` on those files when `rbenv init` is run.  Does it make sense to change the approach to turning on these tab-completions to be more in-line with shell conventions?  For example, for the `zsh` shell, those files could be in a directory which is not initially included in `$fpath`.  When `rbenv init` is run, the code could add the directory to `$fpath`.

Maybe, but I’ll save the above idea for another day.

Before I can move on from this file, the last line of code I need to decipher is:

```
reply=("${(ps:\n:)completions}")
```

Clearly we’re setting a (non-local) variable named `reply) equal to `("${(ps:\n:)completions}")`.  What does this evaluate to?

It looks similar to the `(t)` syntax, which I’ve encountered before.  For example, if you want to get the type of the `completions` variable in a parameter expansion, you’d do `${(t)completions}`.

Probably the easiest thing to do first is to `echo` it out and read the output, but I want to get good at finding things in the docs.  Let’s start with that, and then print stuff to the terminal if I get stuck.  I find [the docs page](https://zsh.sourceforge.io/Doc/Release/Expansion.html) for "Parameter Expansion", and search for `ps:\n`.  I see the following:

> f
>
> Split the result of the expansion at newlines. This is a shorthand for ‘ps:\n:’.

OK cool, so the syntax in question takes a string containing one or more newlines, and uses those newlines as a delimiter to split the string.

As a test, I add the following line of code before the call to `reply=`:

```
  foo="foo\nbar\nbaz\nbuzz"
  echo "${(ps:\n:)foo}"
```

When I use tab complete on the partial command `rbenv commands`, I see the following:

```
$ rbenv commands

words[2,-2]: commands
foo
bar
baz
buzz
```

Looks good to me!

OK, so this last line of code sets the `reply` variable equal to a list of commands generated from the `if` statement, after having split the commands according to the newline character.

I feel like that’s good enough to move on!

I could move from the `rbenv.zsh` file to the `rbenv.bash` file, but I’m feeling kind of burnt-out on tab completions at this point, and am itching to learn about something new.  I’ll save the explanation of `rbenv.bash` as an exercise for the reader.

If we’re done with the `/completions` directory, then let’s move on to the next directory in the main project dir: `/libexec`.

We’ve already encountered this dir in passing, when we looked a the symlink from the `/lib` directory.  We also discovered that `/libexec` is where most of the individual `rbenv` commands live.  Because the files are listed in alphabetical order, the first command file that we encounter happens to be the plan `rbenv` command file.
