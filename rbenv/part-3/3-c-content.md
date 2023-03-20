The `bin/` directory seems super-simple- it just contains one file in it called "rbenv", which Github tells me is a "symbolic link" file:

<p style="text-align: center">
  <img src="/assets/images/contents-of-bin-dir.png" width="70%" alt="The contents of the bin/ directory"  style="border: 1px solid black; padding: 0.5em">
</p>

I've heard of this type of file before, but it's one of those things that I'm not sure I could explain to someone if they asked me about it.  My best definition is that it's a file that, instead of containing its own data, points to another file which contains the data in question.  That's about all I'm comfortable saying without starting to trip on my words lol.  Let's start Googling.

From [this Wikipedia page](https://web.archive.org/web/20220817180854/https://en.wikipedia.org/wiki/Symbolic_link), I get the following information:

 - A symbolic link (also symlink or soft link) is a file whose purpose is to point to a file or directory (called the "target") by specifying a path thereto.

 - Symbolic links are supported by POSIX and by most Unix-like operating systems.

 - A symbolic link contains a text string that is automatically interpreted and followed by the operating system as a path to another file or directory. This other file or directory is called the "target".

 - The symbolic link is a second file that exists independently of its target. If a symbolic link is deleted, its target remains unaffected. If a symbolic link points to a target, and sometime later that target is moved, renamed or deleted, the symbolic link is not automatically updated or deleted.

 - Symbolic links pointing to moved or non-existing targets are sometimes called broken, orphaned, dead, or dangling...

 - Symbolic links operate transparently for many operations: programs that read or write to files named by a symbolic link will behave as if operating directly on the target file...

In our case, the symlink file "points to" `../libexec/rbenv`.  But why?  What does that file contain, and why have the data live in that other directory instead of here?

I feel like, to answer this question, we need to look at the git history.

I see "Latest commit 4362494" in the Github metadata of the changed file (see screenshot), so I copy that partial SHA (`4362494`) and search for it in the top-left corner of Github.  I see the following:

<p style="text-align: center">
  <img src="/assets/images/searching-for-sha-4362494.png" width="70%" alt="Searching for SHA 4362494"  style="border: 1px solid black; padding: 0.5em">
</p>

I knew the SHA wouldn't be in the codebase, but I was hoping there would be one or more issues referencing that SHA, and I was right.  I click on "Issues" on the left-hand side, and I'm taken to an index page of "all the issues" which have this SHA (aka just a list of one issue).  I click on it and am taken to a PR page:

<p style="text-align: center">
  <img src="/assets/images/pr-number-3.png" width="70%" alt="Results of search for SHA 4362494"  style="border: 1px solid black; padding: 0.5em">
</p>

There's not much discussion here, or even a PR description.  That's unfortunate- I was hoping for a description of why this change was necessary.

One thing to note is that this PR was merged on Aug 2, 2011.  So at the date of this writing, it's over 11 years old.  Not immediately relevant, just something I'm noticing now.

Given there's no description, I'm guessing it must be self-evident to the authors and repo maintainers why this change was necessary.  There must be something about the term "libexec" that communicates that knowledge.  Maybe it's an industry standard directory name or something?  I Google around a bit and find [a StackOverflow post](https://unix.stackexchange.com/questions/312146/what-is-the-purpose-of-usr-libexec) about `/usr/libexec`:

<p style="text-align: center">
  <img src="/assets/images/so-question-312146.png" width="70%" alt="StackOverflow question about /usr/libexec"  style="border: 1px solid black; padding: 0.5em">
</p>

Note: "FHS" stands for "Filesystem Hierarchy Standard".  Looks like it's one of many standards implemented by the Linux Foundation.

The [answer](https://unix.stackexchange.com/a/386015/142469) I found seems pretty clear as well:

<p style="text-align: center">
  <img src="/assets/images/so-answer-386015.png" width="70%" alt="Answer to StackOverflow question about /usr/libexec"  style="border: 1px solid black; padding: 0.5em">
</p>

OK, so the name `/libexec` communicates that the files in the directory are meant to be executed by another program, not directly by the user.  It appears that the main benefit `/libexec` confers is not that it *prevents* a user from accessing a given executable, but that it *communicates* that it's a bad idea for the user to do so.  It's the equivalent of making a method "private" in Ruby.  You can still access it by calling `.send`, but you could be shooting yourself in the foot by doing so.

Just for the sake of thoroughness, I [search](https://github.com/rbenv/rbenv/search?o=asc&q=libexec&s=created&type=issues) for `libexec` in the `rbenv` Github repo, to see if there are any other issues which reference it.  There are... quite a few:

<p style="text-align: center">
  <img src="/assets/images/search-results-for-libexec.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Searching for 'libexec' in the Github repo">
</p>

171, to be exact.  I notice that the one I found is the oldest one; this might not be relevant, just something I noticed.

It's at this point that I decide to simply look inside that directory:

<p style="text-align: center">
  <img src="/assets/images/contents-of-libexec-dir.png" width="70%" alt="Contents of 'libexec' directory"  style="border: 1px solid black; padding: 0.5em">
</p>

This appears to be the directory containing all the individual commands that RBENV's API exposes.

I notice there are two entries in "Wikis".  I check those but they don't contain an immediate explanation of what `libexec` is for.  I check the titles of the 17 commits, but nothing stands out there either.  I think I'm OK with concluding that the reason for the symlink file is the reason I mentioned above- it's to communicate that people shouldn't depend on or execute the executable files directly, but rather they should rely on the main `rbenv` command to do it for them.  Note to reader- if you know better than I do here, please let me know *how you reached that conclusion* so I can update this document (and so I can learn something as well).

While I was on the subject, I was also curious what the `/bin/` folder is for.  [Another StackOverflow answer](https://askubuntu.com/questions/138547/how-to-understand-the-ubuntu-file-system-layout) pointed me (once again) to the Filesystem Hierarchy Standard.  Seems like a standard which affects quite a few topics that I've encountered so far.

<p style="text-align: center">
  <img src="/assets/images/so-answer-for-system-layout.png" width="70%" alt="StackOverflow answer on what the bin/ folder is for"  style="border: 1px solid black; padding: 0.5em">
</p>

The gist of `/bin` is that it is meant to contain "essential user command binaries".  In other words, the most important of the commands that the user executes themselves.

Good enough for now.  Moving on.

