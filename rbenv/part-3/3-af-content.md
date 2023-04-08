Now we move onto the `rbenv/src/` directory.

First file: [`Makefile.in`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/src/Makefile.in){:target="_blank" rel="noopener"}.

This file is short, just 25 lines of code:

```
CC = @CC@

CFLAGS = @CFLAGS@
LOCAL_CFLAGS = @LOCAL_CFLAGS@
DEFS = @DEFS@
LOCAL_DEFS = @LOCAL_DEFS@

CCFLAGS = $(DEFS) $(LOCAL_DEFS) $(LOCAL_CFLAGS) $(CFLAGS)

SHOBJ_CC = @SHOBJ_CC@
SHOBJ_CFLAGS = @SHOBJ_CFLAGS@
SHOBJ_LD = @SHOBJ_LD@
SHOBJ_LDFLAGS = @SHOBJ_LDFLAGS@
SHOBJ_XLDFLAGS = @SHOBJ_XLDFLAGS@
SHOBJ_LIBS = @SHOBJ_LIBS@
SHOBJ_STATUS = @SHOBJ_STATUS@

.c.o:
	$(SHOBJ_CC) $(SHOBJ_CFLAGS) $(CCFLAGS) -c -o $@ $<

../libexec/rbenv-realpath.dylib: realpath.o
	$(SHOBJ_LD) $(SHOBJ_LDFLAGS) $(SHOBJ_XLDFLAGS) -o $@ realpath.o $(SHOBJ_LIBS)

clean:
	rm -f *.o ../libexec/*.dylib
```

That said, I have zero idea what this code does or means.  I don't even know what to call this syntax.  I'm gonna have to look up the git history.  [Here](https://github.com/rbenv/rbenv/pull/528/files){:target="_blank" rel="noopener"} is the PR which added the file.  I search the diff for `Makefile` and find it in 5 locations, including here in a bash script named `configure`:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1024am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

My very tentative guess so far is that the bash script is meant to be an entry point of some sort, and that the `sed` command on line 33 above does... something with it?

I look up [the first commit in this PR](https://github.com/rbenv/rbenv/pull/528/commits/16c7eb41354c3c1ca5fca08bd0501568fa2b5212){:target="_blank" rel="noopener"}, and see that it has the following description:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1025am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

OK, so this is part of a strategy for making `rbenv` faster by making the `realpath` function faster.  I remember seeing references to the `.dylib` file mentioned here.  Those references were in several files that we inspected earlier, such as [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23){:target="_blank" rel="noopener"} in the main `rbenv` file.  At the time I initially encountered this file extension, I remember looking for the referenced file and not finding it.  Possibly this was because I hadn't run the `make -C src` command that they mention here?

I Google "Makefile.in”, and the first result that comes up is [this StackOverflow link](https://web.archive.org/web/20221010012118/https://stackoverflow.com/questions/2531827/what-are-makefile-am-and-makefile-in){:target="_blank" rel="noopener"}:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1026am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

This post says that “Makefile.in” is the input file used by a script named `configure` to generate a file named `Makefile`.

This page also links to [a Wikipedia page](https://web.archive.org/web/20221113191726/https://en.wikipedia.org/wiki/Configure_script){:target="_blank" rel="noopener"} dealing with `configure` scripts:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1028am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

This link mentions that the script's name (“configure”) is a convention that is used, and also that this script is usually a `bash` script.

I try running the `configure` script:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1029am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

I now notice there is a new file named simply “Makefile” (no “.in” file extension).  This file didn't exist before, so it's safe to assume that running the `configure` script resulted in this file being built, as specified in the StackOverflow post.

What does the new file look like?

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1030am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Quite short, just like `Makefile.in`.  In fact, it looks almost exactly like `Makefile.in`:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-19mar2023-1031am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

The only difference appears to be that some values which start and end with `@` are replaced in `Makefile`, either with blank spaces or with certain values.  My guess is that the `@` symbol is used to reference variables in a `Makefile`.

But why not just include the `Makefile` directly?  Why go through the extra step of running the `configure` script?

The Wikipedia page says that the purpose of a `configure` script is “...to aid in developing a program to be run on a wide number of different computers.”  So I'm guessing that the step of running `configure` is necessary because the output of that script can change, depending on the specific machine it is run on.

OK, so we know from [the PR description](https://github.com/rbenv/rbenv/pull/528/commits/16c7eb41354c3c1ca5fca08bd0501568fa2b5212){:target="_blank" rel="noopener"} that we read that the purpose of the Makefile is to increase the speed of a function named “realpath()” (which is a performance bottleneck in RBENV).  How does it do that?

Maybe inspecting the `configure` script is a good place to start.  It's a `bash` script, so I'm already familiar with the syntax.
