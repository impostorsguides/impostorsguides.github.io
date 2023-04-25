

Next line of code:

```
commands=(`rbenv-commands --sh`)
```

This line stores the output of `rbenv-commands --sh` in a variable called `commands`.  Since this appears to be executing the libexec folder's `rbenv-commands` script directly, I add `libexec/` to my `$PATH` and run the same command, with the following results:

```
$ PATH=~/Workspace/OpenSource/rbenv/libexec/:$PATH
$ rbenv-commands --sh

rehash
shell
```

(stopping here for the day; 25761 words)

I didn't see anything relevant to the `--sh` flag when running `rbenv commands --help`, but a quick look at the `rbenv-commands` file itself tells us that the `--sh` flag just narrows down the output to the commands whose files contain `sh-` in their names (i.e. `shell` and `rehash`).  Again, I'm not sure what makes these commands special or requires them to be treated differently, but hopefully we'll answer that question in due time.

Next line of code:

```
case "$shell" in
...
esac
```
Here we're just branching via case statement based on the different values of our `$shell` var.

Our first branch is:

```
fish )
  cat <<EOS
function rbenv
  set command \$argv[1]
  set -e argv[1]
...
EOS
  ;;
```

If the user is using the "fish" shell, we create a multi-line string (also called a "here-string") using the `<<EOS` syntax to start the string, and the `EOS` syntax to end it.  Inside the here-string is where we begin creating a function named "rbenv" (we encountered this when we were dissecting the "rbenv" file).  We're creating a function inside a string because we then "cat" the string out to STDOUT, which is received by the `eval` caller of `rbenv init`.

Since the "fish" shell operates so much differently from other shells, we need to do things a bit differently when defining the "rbenv" function in this shell environment.  We can refer back to the [Fish shell docs](https://web.archive.org/web/20220720181625/https://fishshell.com/docs/current/cmds/set.html){:target="_blank" rel="noopener"}, however I can already tell that I'll need the ability to test some of this "fish" syntax on my local machine.  For example, on these two lines:

```
  set command \$argv[1]
  set -e argv[1]
```

Why do we use a "$" sign on line 1, but not on line 2?

To truly test this syntax out, I need to create fish shell scripts on my local machine.  Since I don't yet have fish installed, I need to install it.  I'll use Homebrew to do that:

```
brew install fish
```

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-808am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Great!  Now when I write a fish shebang as the first line of my script, my computer will know how to handle that.  Here's a simple test script, to ensure that my fish shell was installed properly:

```
#!/usr/bin/env fish

echo 'Hello world'
```

When I run it, I get:

```
$./foo

Hello world
```

Awesome, now we can mess around with fish on our local and see what different syntaxes (syntaces?) do.  Here's a simple fish function, which takes in any args which are passed from the command line:

```
#!/usr/bin/env fish

function foo
  echo "oldest argv: $argv"
  echo "old command: $command"
  set command $argv[1]
  echo "new command: $command"
  echo "old argv: $argv"
  set -e argv[1]
  echo "new argv: $argv"
  exit
end

foo $argv
```

And here is me calling it from the command line:

```
$ ./foo bar baz buzz

oldest argv: bar baz buzz
old command:
new command: bar
old argv: bar baz buzz
new argv: baz buzz
```

Here we see that, initially, the "$command" variable is undefined (as shown by the "old command: <blank>" line.  After we run "set command $argv[1]", its value changes to "bar".  This has the effect of declaring a variable named "command", and setting its value equal to the first argument in the list.

We also see that, initially, the args passed to the foo function are "bar", "baz", and "buzz".  After I call "set -e argv[1]", the new args are "baz" and "buzz".  This means that "set -e argv[1]" has the effect of removing the first arg from the arg list.  This is the same thing that "shift" does in zsh.

Taken together, these two lines mean that we're creating a variable named "command" and setting its value equal to the value of "argv[1]", and then we're deleting argv[1] itself.

Next few lines of code (inside the here-string, but after `set -e argv[1]`):

```
switch "\$command"
  case ${commands[*]}
    rbenv "sh-\$command" \$argv|source
  case '*'
    command rbenv "\$command" \$argv
  end
end
```

Not gonna lie, I had a really hard time with this code.

At first I thought this was just a fish-flavored case statement with two branches, depending on the value of our "command" variable.  I suspected that the first branch is reached if the value of that variable is one of the values in our "commands" variable, but I wasn't 100% sure since I'm not super-familiar with the "[*]" syntax.  To test my hypothesis, I wrote a simple test script in fish:

```
#!/usr/bin/env fish

set command "foo"

switch $command
case ${argv[*]}
  echo "command in args"
case "*"
  echo "command not found"
end
```

I'll save you the drama of why this didn't work and the alternatives I tried, because I don't think it would be very educational to see my muddled thought process here.  In the end, I wrote a StackExchange question and got an answer [here](https://web.archive.org/web/20230407064428/https://unix.stackexchange.com/questions/716850/fish-shell-syntax-for-creating-a-switch-statement-which-checks-against-an-arra){:target="_blank" rel="noopener"}{:target="_blank" rel="noopener"}.  TL;DR- I was getting confused about which parts of the syntax were being resolved by fish and which by bash, as well as when.  The answer appears to be that 1) bash constructs a string containing a function definition, resolving certain parameter expansions and variables along the way, and then 2) that string is evaluated by fish as a set of commands and a function definition.  I was unable to reproduce that behavior in the timebox I gave myself, but I'm relatively confident that this is what happens.

Side note: it's amazing who might answer you when you post a StackExchange question.  It turns out that the person who helped me out was [a well-known ethical hacker](https://web.archive.org/web/20220308002926/https://www.smh.com.au/technology/stephane-chazelas-the-man-who-found-the-webs-most-dangerous-internet-security-bug-20140926-10mixr.html){:target="_blank" rel="noopener"} who helped find and fix a zero-day Bash exploit in millions of laptops, phones, and embedded devices around the world!

On another note, I have to say I'm a bit disheartened that I was unable to understand the interplay of bash and fish well enough to reproduce a simplified test case for you here.  I would have considered that a mark not only of my success in teaching you something, but also in me having learned something.  To the extent that I'm unable to produce such test cases, I consider that a failure on my part.

I compare myself and my work against people like Aaron Patterson and Mislav Marohnić, who would undoubtedly be able to succeed where I've failed here.  If they ever write a guide to reading and understanding open-source code and you're choosing whether to buy their book or mine, I heartily encourage you to buy theirs.  Until then, you'll have to make do with mine.  I console myself with the idea that, while my knowledge of code may not be comparable to theirs, perhaps I can at least pass on a lesson in staying humble and taking things one day at a time.

—--

OK, today is the next day.  I decide to take another crack at this.  I know that what I want is to create a string which represents a fish function, and then cat that string to a fish script.  That fish script should run `eval` on that function string, so that `eval` can turn the string into code.  I know this is how `eval` works in fish because I've reproduced it locally:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-810am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Once the string has been turned into code, I *should* be able to call the function defined in that string.  If I can successfully reproduce the above steps, I will have succeeded in my goal.

So far I have the following:

 - A bash script named "foo" in a folder also named "foo", which looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-811am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

 - A fish script named "bar", which looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-812am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run the "foo" script directly, it successfully prints out the function in the format that I would expect:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-813am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

My hypothesis was that, when I run the "bar" script, the "eval" statement would process the string that is `cat`'ed to STDOUT, and produce a runnable function.  But that's not what happens.  Instead, I see this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-814am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I Googled this exact error string (`Expected end of the statement, but found end of the input`), but shockingly I got no results at all:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-818am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

My mental bandwidth was already pretty shot by the time I hit this wall yesterday, which is why I wrote what I wrote yesterday about being disappointed in myself.

Today, I decide to try again.  I start by creating a bash script named "baz", which implements a simpler function definition:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    echo "Hello world"
  end
EOS
```

There's no dynamic string interpolation or parameter expansion here.  Just a simple 'Hello world' function.  I run `chmod +x baz` so that I can execute it.  I run "baz" by itself to make sure it works:

```
$ vim foo
$ chmod +x foo
$ ./foo

  function bar
    echo "Hello world"
  end
```

I open up a fish shell and try to "eval" the output of this file.  I get the same error:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-820am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I re-read [the fish docs on defining functions](https://fishshell.com/docs/current/cmds/function.html){:target="_blank" rel="noopener"}.  I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-821am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

What stood out to me this time is the semi-colons at the end of the signature and body.  I wonder if it would help things if I reformatted my function string to use semi-colons.

I add semi-colons to the end of each line of the "baz" script:

```
#!/usr/bin/env bash

cat << EOS
  function bar;
    echo "Hello world";
  end;
EOS
```

I then try to re-run the "eval" statement in my fish shell:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-822am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Holy shit, it worked!

Now let's try the same solution in the original "bar" script:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-823am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Hmmm, well I didn't get the same error as last time (in fact, it looks like I didn't get an error at all).  But when I try to call my "foo" function, it says there's no command found.  That means it didn't define my function like I had planned.

Maybe the problem is that I'm not handling the semi-colons correctly with respect to the switch statement.  Let me go back to my "baz" script and increase its complexity a bit with a "switch" statement of its own:

```
#!/usr/bin/env bash

cat << EOS
  function bar;
    set myVar 5;
    switch $myVar;
    case 5;
      echo 'e';
    case '*';
      echo 'Not found';
    end;
  end;
EOS
```

When I "eval" this code, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-826am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Why does it think I'm missing an "end"?  Both the "switch" statement and the function itself have closing "end" lines (11 and 12, respectively).

Oh, hmmm.  I see in the fish docs for switch statements that there isn't supposed to be a closing "end" tag for the switch:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-827am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I delete line 11...

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-830am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

...and try again:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-831am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

TODO- replace this link from gitter.im.

I Google this error ("Missing end to balance this function definition"), and one of the first results is [this link](https://archive.ph/R1eVq){:target="_blank" rel="noopener"}, which contains an IRC discussion of someone experiencing the same error.  At one point, a participant in the discussion says "You're not using `eval` to load it, are you?", which catches my eye.  Am I not supposed to be loading the code with "eval"?

I Google "using eval to load code fish", and one of the first results that comes up is [a discussion in the "fish-shell" Github repo](https://github.com/fish-shell/fish-shell/issues/3993){:target="_blank" rel="noopener"}.  I see several people recommending that a piece of text be piped into "source" instead.  It appears that the fish shell prefers piping over the use of "eval".

I re-write the function again:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    set myVar 5
    echo $myVar
  end
EOS
```

And back in my fish shell, I run the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-838am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so now we know we can load code by `cat`'ing a string and piping the result to the `source` command.  Let's again try a case statement:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    set myVar 5
    switch $myVar
    case 4
      echo '4'
    case 5
      echo '5'
    case '*'
      echo 'Not found'
  end
EOS
```

I still get the same error:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-839am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try adding another 'end' before line 13:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-840am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Same thing:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-841am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Damnit, I'm close!  I can feel it!  I'm sure it's just some stupid syntax issue in my case statement.

I try defining a function with a switch statement directly in my shell, and that works:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-842am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I notice two things here:

I didn't need any semi-colons in order for the case statement or the function to work, and
Both the case statement and the function itself required separate "end" lines.

I post [a StackExchange question](https://unix.stackexchange.com/questions/716957/fish-shell-whats-wrong-with-this-syntax){:target="_blank" rel="noopener"}, and eventually I get an answer: since my function is defined inside a string, my reference to $myVar should really be a reference to "\$myVar":

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-843am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Running this version of the `baz` file via `./baz | source` fixes the glitch!

```
myusername@me ~/foo (master)> ./baz | source
myusername@me ~/foo (master)> bar
5
5
```
Not sure why it outputs "5" twice; my best guess is that the return value of a case statement in fish is the value of the variable that we "switch" on?  Not sure, but I'm now ready to try the final step in this experiment: passing in an array to the `cat`'ed function string:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    echo ${@}
    set myVar 5
    switch "\$myVar"
      case ${@}
        echo 'myVar in nums!'
      case '*'
        echo 'myVar not in nums :-('
    end
  end
EOS
```

When I run this, I get good news!

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-848am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

To make sure I'm not getting a false positive, I change `set myVar 5` to `set myVar 6` in the script...

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-849am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...and re-run it:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-850am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Success!

That's all for today, I think.  I conquered a problem that was flummoxing me yesterday, and I feel a little better as a result.

Next line of code:

```
ksh )
  cat <<EOS
function rbenv {
  typeset command
EOS
  ;;
```

This is the 2nd branch of our outer case statement (the one which checks which shell the user is using).  If the user is using the `ksh` shell (aka the Korn shell), we employ a similar strategy of starting to `cat` a function definition, but this time we don't close that definition (that comes later).  For now, we just declare a variable named `command`, which is scoped locally with respect to the "rbenv" function according to [the Korn shell docs](https://web.archive.org/web/20161203165249/https://docstore.mik.ua/orelly/unix3/korn/ch06_05.htm){:target="_blank" rel="noopener"}:

> typeset without options has an important meaning: if a typeset statement is used inside a function definition, the variables involved all become local to that function (in addition to any properties they may take on as a result of typeset options).

Next lines of code:

```
* )
  cat <<EOS
rbenv() {
  local command
EOS
  ;;
```
This is the default, catch-all case for our "$shell" variable switch statement.  If the user's shell is not fish or ksh, then we "cat" our "rbenv" function definition, and (again) create a local variable named "command".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
