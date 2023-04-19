

The next line of code is:

```
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"
```

We already learned what `[ -n ...]` does from reading about `$RBENV_DEBUG`.  It returns true if the length of (in our case) `$READLINK` is non-zero.  So if the length of `$READLINK` *is* zero, then we `abort` with the specified error message.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's look at the next 3 lines of code together, since it's just a simple function declaration:

```
  resolve_link() {
    $READLINK "$1"
  }
```

When we call this `resolve_link` function, we invoke either the `greadlink` command or (if that doesn't exist) the `readlink` command.  When we do this, we pass any arguments which were passed to `resolve_link`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
abs_dirname() {
  local cwd="$PWD"
  local path="$1"

  while [ -n "$path" ]; do
    cd "${path%/*}"
    local name="${path##*/}"
    path="$(resolve_link "$name" || true)"
  done

  pwd
  cd "$cwd"
}
```

So here's where we're declaring the version of `abs_dirname` from the `else` block (as an alternative to the `abs_dirname` function in our `if` block above).

The first two lines of code in our function body are:

```
    local cwd="$PWD"
    local path="$1"
```

We declare two local variables:

 - A var named `cwd`.
    - This likely stands for "current working directory".
    - Here we store the absolute directory of whichever directory we're currently in when we run the `rbenv` command.
 - A var named `path`, which contains the first argument we pass to `abs_dirname`.

Next line of code:

```
while [ -n "$path" ]; do
...
done
```

In other words, while the length of our `path` local variable is greater than zero, we do...something.  That something is:

```
cd "${path%/*}"
local name="${path##*/}"
path="$(resolve_link "$name" || true)"
```

The above 3 lines of code are inside the aforementioned `while` loop.  Taken together, they are pretty hard for me to get my head around.

To see what's actually happening at each step in this loop, I try adding multiple `echo` statements to the `while` loop's code:

<p style="text-align: center">
  <a href="/assets/images/screenshot-12mar2023-655pm.png" target="_blank">
    <img src="/assets/images/screenshot-12mar2023-655pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

Note that I make the above change inside the code for my RBENV installation (i.e. the code at `~/.rbenv/libexec/rbenv`), **not** the code I've pulled down from Github.

I prefaced the `echo` statements with `>&2` because I don't want these `echo` statements to be interpreted as the output of the `abs_dirname` function.

Another change I need to make in this same file is to temporarily comment out the `if`-block that we just finished reading, to make sure that our `else`-block gets evaluated:

<p style="text-align: center">
  <a href="/assets/images/screenshot-12mar2023-653pm.png" target="_blank">
    <img src="/assets/images/screenshot-12mar2023-653pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

Re-running the `rbenv init` command:

<p style="text-align: center">
  <img src="/assets/images/much-output-12mar2023-656pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

And when I run `rbenv commands`, I get the logging statements above, plus a list of commands I can run from `rbenv`:

<p style="text-align: center">
  <img src="/assets/images/much-echo-12mar2023-702pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The first thing I notice is that I don't know how many iterations of the `while` loop took place.  I can figure it out, because there are 2 references to `new path:`, but it's kind of hard to read because everything is muddled together.  This would be easier to read if each iteration included some sort of demarcation or delimiter.  I add one now:

<p style="text-align: center">
  <img src="/assets/images/new-path-echo-12mar2023-703pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

While I'm at it, I decide to change one of my tracer statements from `>&2 echo "path%/*: ${path%/*}"` to `>&2 echo "path that we will cd into: ${path%/*}"`.  I also remove all the tracer statements outside of the `while` loop.  I made both these changes for added readability.

Re-running `rbenv init`:

<p style="text-align: center">
  <img src="/assets/images/more-tracers-12mar2023-704pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

And re-running `rbenv commands`:

<p style="text-align: center">
  <img src="/assets/images/yet-moar-tracers-12mar2023-705pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So at a certain point the condition in our `while` loop becomes falsy, which means we no longer execute further loops.  What is it inside the loop which causes that condition to *become* falsy, and what can we infer about the purpose of the code from that change?

The `while` loop's condition is true as long as `[ -n "$path" ]` is true.  In other words, the `while` loop continues looping until the length of `"$path"` becomes 0.  But the length of `"$path"` will be greater than zero as long as the length of `$(resolve_link "$name" || true)` is greater than zero.

Out of curiosity, I check the length of `$(true)` in my "foo" bash script:

```
#!/usr/bin/env bash

foo="$(true)"

echo "length: ${#foo}"
```

Remember that the `#` in `${#foo}` means that we're checking for the *length* of `foo`.

Running this script, I get:

```
$ ./foo

length: 0
```

The `while` loop continuously re-sets the value of `$path` to be `resolve_link "$name"`, until the value becomes empty.  At that point, it sets the value of `$path` to the boolean `true`.  Since the length of the `true` boolean is zero (as is the length of the `false` boolean, FYI), this causes the `while` loop to exit.

It seems like the purpose of this loop is to keep `cd`ing into successive values of `path` until the value of `resolve_link` is falsy.  And as we learned earlier, the value of `resolve_link` is determined by the value of either the `greadlink` or `readlink` commands.

These commands return output if the param you pass it is a symlink pointing to another file, and don't return output if the param you pass it is a non-symlink file.

We can verify this by taking the following steps:

- create an executable file named `bar`, and place it inside a directory named `foo`.
- create a symlink to the `foo/bar` file in the same directory as the `foo` directory.  I name the symlink file `baz`.  The command for this is `ln -s foo/bar baz`.
- From the directory containing the symlink, run `readlink baz`.
- Verify that the output is `foo/bar`.
- From the same directory, run `readlink foo/bar`.
- Verify that nothing is output.
- Repeat the above `readlink` steps, but with `greadlink` instead.
- Verify the same output appears.

Here are the above steps in action:

```
$ mkdir foo

$ touch bar

$ chmod +x bar

$ ln -s foo/bar baz

$ readlink baz

foo/bar

$ readlink foo/bar

$

$ greadlink baz

foo/bar

$ greadlink foo/bar

$
```

So the purpose of the `while` link is to allow us to keep `cd`ing until we've arrived at the real, non-symlink home of the command represented by the `$name` variable (in our case, `rbenv`).  When that happens, we exit the `while` loop and run the next two lines of code:

```
pwd
cd "$cwd"
```

`pwd` stands for `print working directory`, which means we `echo` the directory we're currently sitting in.  After we `echo` that, we `cd` back into the directory we were in before we started the `while` loop.

I'm confused about why we do this.  Here are the questions I have in my head right now:

- Coming from Ruby, I'm accustomed to looking at the last statement of a function as the return value of that function.  So why is the last statement of this function a call to navigate to our original directory?
- Given that the `cd` call is the last item in our function, doesn't that make the return value of the `cd` operation also the return value of our `abs_dirname` function?
- Why do we need to print the current working directory beforehand?

At this point I started to wonder whether all these weird things were related.

I suspect that the purpose of the final call to `cd` is to undo the directory changes that we made while inside the `while` loop.  If that's true, I wonder whether the function is using `echo` to return the value output by `pwd`.

<!-- Once we've output that, we wouldn't need to be inside its canonical directory anymore, so it's best to `cd` back into where we started from.  If we didn't do this final `cd`, then calling `abs_dirname` would have an undesirable side effect- we'd be left in a different directory after calling the function, compared to where we were before calling it.

But how could the value of `pwd` be captured?  True, it's being sent to STDOUT, but that's just like `echo`'ing it to the screen.  It's not actually getting `return`ed, is it?  And at any rate, it's not the last line of code in the function, so it can't possibly be the `return` value, can it? -->

Let's test this out by writing our own function which does something similar.  I re-write my `~/foo/bar` script to look like this:

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  pwd

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```

I then create two new directories in my `~/` parent directory, named `bar` and `buzz`.  First I `cd` into `~/bar` and run `../foo/bar`.  I get:

```
$ cd ../bar
$ ../foo/bar
myVar: /Users/myusername
current directory: /Users/myusername/bar
```

Then I `cd` into `~/buzz` and repeat:

```
$ cd buzz
$ ../foo/bar
myVar: /Users/myusername
current directory: /Users/myusername/buzz
```

Then I comment out the `pwd`...

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  # pwd             # commented-out code

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```

...and re-run:

```
$ ../foo/bar
myVar:
current directory: /Users/myusername/buzz
```

OK, so `pwd` *does* in fact control what the return value of this function is.  This implies that the return value of a function in `bash` is *not necessarily* the last line of code in the function.  Instead, it appears to be dictated by what's output to STDOUT.

I un-comment the call to `pwd`, and out of curiosity, I add an `echo` statement just beforehand:

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  echo "Hello world"
  pwd

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```


When I run this, I get:

```
$ ../foo/bar
myVar: Hello world
/Users/myusername
current directory: /Users/myusername/buzz
```

So when we print both "Hello world" and the current working directory, the return value of `foo()` changes to be both the lines we printed.

My current working hypothesis is therefore that the return value of a function is the sum of all things that it `echo`s.

When I Google "bash return value of a function", the first result I see is [a blog post in LinuxJournal.com](https://web.archive.org/web/20220718223538/https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.  Among other things, it tells me:

- "Bash functions, unlike functions in most programming languages do not allow you to return a value to the caller.  When a bash function ends its return value is its status: zero for success, non-zero for failure."
- "To return values, you can:
  - set a global variable with the result, or
  - use command substitution, or
  - pass in the name of a variable to use as the result variable."

Let's try each of these out:

### Experiment- setting a global variable inside a function

I create a script with the following contents:

```
#!/usr/bin/env bash

foo() {
  myVarName="Hey there"
}

echo "value before: $myVarName"     # should be empty

foo

echo "value after: $myVarName"      # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before:
value after: Hey there
```

So it looks like, when we don't make a variable local inside a function, its scope does indeed become global, and we can access it outside the function.

### Experiment- using command substitution to return a value from a function

I update my script to read as follows:

```
#!/usr/bin/env bash

foo() {
  echo "Hey there"
}

echo "value before function call: $myVarName" # should be empty

myVarName=$(foo)

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

So by using command substitution (aka the `"$( ... )"` syntax), we can capture anything `echo`'ed from within the function.

### Experiment- passing in the name of a variable to use

I update the script one last time to read as follows:

```
#!/usr/bin/env bash

foo() {
  local varName="$1"
  local result="Hey there"
  eval $varName="'$result'"
}

echo "value before function call: $myVarName" # should be empty

foo myVarName

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

Credit for these experiments goes to [the LinuxJournal link from earlier](https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
