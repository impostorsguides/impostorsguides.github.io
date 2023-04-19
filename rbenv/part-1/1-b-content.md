Our first line of code in the shim file is:

```
#!/usr/bin/env bash
```

## The shebang line

From a Google search for the string `"#!/usr/bin/env bash"`, I learned that this line of code is called a ["shebang"](https://web.archive.org/web/20230323182633/https://en.wikipedia.org/wiki/Shebang_(Unix)){:target="_blank" rel="noopener"}.

In UNIX, a shebang is a special line of code at the top of a script file which tells UNIX which program to use in order to execute the code which comes after it.  In this case, since the shebang ends in "bash", we're telling UNIX to use `bash` to evaluate the code.

### Different types of shebangs

Note that you might sometimes see `#!/usr/bin/bash` instead of as a shebang, instead of `#!/usr/bin/env bash`.  The difference between these two is that `/usr/bin/env` checks your terminal environment for variables, sets them, and then runs your command.  If we type just `env` into our terminals, we can see a list of the environment variables that `env` will set:

```
~/Workspace/OpenSource ()  $ env

TERM_PROGRAM=Apple_Terminal
SHELL=/bin/zsh
TERM=xterm-256color
TMPDIR=/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/
USER=myusername
PATH=/Users/myusername/.nvm/versions/node/v18.12.1/bin:/Users/myusername/.rbenv/shims:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/Users/myusername/.rbenv/shims:/Users/myusername/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/myusername/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/myusername/.asdf/shims:/Users/myusername/.asdf/bin:/Users/myusername/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin
PWD=/Users/myusername/Workspace/OpenSource
...
```

The benefit of using the `/usr/bin/env bash` shebang instead of `/usr/bin/bash` is that the former will likely work on more peoples' machines than the latter.  This is because one of the environment variables that `/usr/bin/env` loads is the `$PATH` env var (as we can see above in the output of the `env` command).

If we use the `/usr/bin/bash` shebang, then whoever runs our script **must** have `bash` installed in their `/usr/bin/` directory.  But that's not a safe bet.  For example, my `bash` executable is installed at `/bin/bash`, with no `/usr/` prefix.  If we load `PATH` into our environment via the `/usr/bin/env bash` shebang, then UNIX will search through all the directories in `PATH` until it finds `bash`.  More directories in our `$PATH` means more chances to find a working `bash` executable.

The links [here](https://web.archive.org/web/20230326212656/https://www.baeldung.com/linux/bash-shebang-lines){:target="_blank" rel="noopener"} and [here](https://web.archive.org/web/20230316084258/https://stackoverflow.com/questions/16365130/what-is-the-difference-between-usr-bin-env-bash-and-usr-bin-bash){:target="_blank" rel="noopener"} contain additional info on the differences between the two types of shebangs, including some cases where you might **not** want to use `/usr/bin/env bash`.

### Why do we need any shebang at all?

Hypothetically, we *could* leave the shebang out from this file.  But **somehow** we have to tell UNIX which program to use when running the file.  If we don't do so in the file itself (i.e. by using a shebang), we'd have to do so when we type the command into the terminal.  So instead of typing `bundle install` in the command line, we'd have to type the following every time:

```
/usr/bin/env bundle install
````

or:

```
/bin/bash bundle install
````

Using a shebang not only saves us a few keystrokes, but it's also one less thing that we humans can mess up when manually typing our command into the terminal.

### Other shells besides `bash`

As I mentioned before, the string "bash" at the end of the shebang tells UNIX to use `bash` when interpreting the code which follows.  But `bash` is not the only interpreter we can tell UNIX to use for a script that we write.  The only reason the code author used it here is because they wrote the subsequent code in bash.  If they had written it in Ruby, they could have written `#!/usr/bin/env ruby` instead (i.e. replace `bash` with `ruby` in the shebang).  In fact, let's try doing exactly that, as an experiment.

#### Experiment- writing a script with a Ruby shebang

We start by writing a regular Ruby script with a `.rb` file extension.  We'll name the file `hello.rb`, and the file will include the following code:

```
puts "Hello world!"
```

When we run `ruby hello.rb` from the command line, we get:

```
$ ruby hello.rb

Hello world
```

What happens if we don't use the `ruby` command, instead just running the file as if it were an executable?

```
$ ./hello.rb

zsh: permission denied: ./hello.rb
```

OK, well this is just because we haven't yet updated the file permissions to [make the file executable](https://askubuntu.com/questions/229589/how-to-make-a-file-e-g-a-sh-script-executable-so-it-can-be-run-from-a-termi){:target="_blank" rel="noopener"}.  That's a step we'll need to do whenever we make a brand-new file.  We do that with the `chmod` command, passing `+x` to tell UNIX to update the file's execution permission:

```
$ chmod +x hello.rb
```

Now that we've made the file executable, when we actually run it, we get:

```
$ ./hello.rb

./hello.rb: line 1: puts: command not found
```

Our error is telling us that UNIX doesn't recognize the command `puts`.  That's because `puts` is a Ruby command, and we haven't yet told UNIX that we want to use Ruby.

Lastly, let's add a Ruby-specific shebang to the top of the file:

```
#!/usr/bin/env ruby

puts "Hello world"
```

Now, when we re-run the file, we get:

```
$ ./hello.rb

Hello world
```

Success!  We've told bash which interpreter we want to use, meaning that we no longer need to use the `ruby` command at the terminal prompt.

#### Experiment- does the shebang have to be on the first line?

I update my script so that the shebang is on line 2 instead of line 1:

```

#!/usr/bin/env ruby

puts "Hello world"
```

Note the single empty line above the shebang.  When I run the file, I once again see:

```
$ ./foo

./foo: line 4: puts: command not found
```

So as it turns out, the shebang line *must* be on the very first line of the file.  Good to know.

### Can the computer use the file extension instead of the shebang?

We have a `.rb` file extension at the end, but the terminal doesn't use the extension when deciding how to interpret the file.  I came across [this StackOverflow post](https://web.archive.org/web/20211027134850/https://superuser.com/questions/267632/file-extension-for-file-to-be-run-by-terminal){:target="_blank" rel="noopener"} while looking for documentation on this:

<p style="text-align: center">
  <img src="/assets/images/file-extension-for-terminal.png" width="70%" alt="StackOverflow question about which file extension to use for a shell script"  style="border: 1px solid black; padding: 0.5em">
</p>

Which had [this answer](https://superuser.com/a/885285){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/file-extension-not-used.png" width="70%" alt="File extensions aren't used when the terminal tries to interpret a file."  style="border: 1px solid black; padding: 0.5em">
</p>

This got me wondering *why* a terminal doesn't use file extensions.  So I posted a question on StackOverflow (subsequently closed) on StackOverflow (click to expand):

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-17mar2023-228pm.png">
    <img src="/assets/images/screenshot-17mar2023-228pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

From the comments, it looks like this is one big difference between Windows and UNIX.  The former takes the approach of [using the file extension to determine which program](https://superuser.com/questions/266268/where-in-the-registry-does-windows-store-with-which-program-to-open-certain-file){:target="_blank" rel="noopener"} to use when executing a given file.  This means Windows application developers have to tell the OS which file extensions their application can open.  The benefit of this is, no shebang in the file itself.

UNIX, on the other hand, doesn't use such registry, at least not when directly running scripts from the terminal.  This means that the author of a file (rather than the author of an application) gets to decide how to open their file.  Different philosophies, different trade-offs.

## File Permissions

Why is it necessary to run `chmod +x` on our file, before we can execute it?  Why can't a user execute their own file by default?  I asked myself this same question, and since I couldn't find an answer online already, [I asked StackOverflow](https://web.archive.org/web/20230406160905/https://stackoverflow.com/questions/75627561/my-umask-output-is-022-why-cant-i-execute-a-file-i-just-created-without-c/){:target="_blank" rel="noopener"}.

The question I asked involves a command called `umask` which isn't super-important here.  The thrust of my question was "Why can't a file's creator execute a file without jumping through `chmod` hoops?"  The answer came about in the comments below one of the answers:

<p style="text-align: center">
  <img src="/assets/images/why-cant-a-file-creator-execute-the-file.png" width="60%" alt="The answer to my question about why a file's creator can't execute their own file without first `chmod`ing it."  style="border: 1px solid black; padding: 0.5em">
</p>

Because [UNIX is multi-user in nature](https://web.archive.org/web/20230331054614/https://en.wikipedia.org/wiki/Multi-user_software){:target="_blank" rel="noopener"}, it needs to account for the scenario where a user gains access to a system that they shouldn't have access to, and writes a malicious script that they then try to execute.  Because they don't have permission to execute the script without authorization from the system's administrator, they are prevented from doing so.  This, in a nutshell, is why we have to `chmod` our scripts every time.

#### Experiment- analyzing a file's permissions

File permissions are divided into 3 different categories- one for the file's owner, one for the group that the user belongs to, and one for everybody else.  The `+x` flag for `chmod` actually updates the "executable" permissions for *all 3* of those groups, *not* just for me, the file's creator.  We can see this in action by running an experiment.

We delete our old `foo` file and creating a new one, then looking at its permissions:

```
$ rm foo
$ touch foo
$ ls -l foo
-rw-r--r--  1 myusername  staff  0 Mar  2 11:24 foo
```

The key here is the `-rw-r--r--` section.  According to [this source](https://web.archive.org/web/20221006191132/https://mason.gmu.edu/~montecin/UNIXpermiss.htm){:target="_blank" rel="noopener"}, the first `-` means that what we're looking at are *file* permissions, not *directory* permissions.  If we were looking at directory permissions, the leading `-` would be replaced with a `d`.

Characters 2-4 are for the first permissions category (i.e. the file creator).  Characters 5-7 are for users in the same [user group](https://web.archive.org/web/20211206154949/https://docs.oracle.com/cd/E19120-01/open.solaris/819-2379/userconcept-35906/index.html){:target="_blank" rel="noopener"} as the file's creator, and characters 8-10 are for everyone else.  In each of these bunches of 3 characters, `r` means that group can read the file, `w` means they can write to it, and `x` means they can execute it.

Let's run `chmod +x foo` and then re-run `ls -l foo`:

```
$ chmod +x foo
$ ls -l foo

-rwxr-xr-x  1 myusername  staff  0 Mar  2 11:24 foo
```

As we can see, now each permissions category has `x` set.

## The `PATH` variable

Let's go back to the `/usr/bin/env` command in our shebang, and specifically to the environment variables which are loaded by that command.  As we discussed, an important example of these is the `PATH` variable.  It's important because it contains a list of directories that UNIX will search through, when it looks for the command we ask `env` to run (as well as the order in which the search will happen).  So if my shebang is `#!/usr/bin/env ruby`, and my `PATH` variable looks like the following:
```
/Users/myusername/.rbenv/shims:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin
```

...then UNIX will check for the `ruby` command in the following directories, in the order they appear below:

```
/Users/myusername/.rbenv/shims
/usr/local/sbin
/usr/local/bin
/usr/bin
/bin
```

The directories in the `PATH` string are concatenated together into a single string, with the `:` character used as a delimiter.  This delimiter is also called an ["internal field separator"](https://web.archive.org/web/20220715010436/https://www.baeldung.com/linux/ifs-shell-variable){:target="_blank" rel="noopener"}, and UNIX refers to it by the environment variable `IFS`.

The `IFS` link above contains an experiment, which I've modified slightly below so we can see an example of this env var and its usage.

#### Experiment- IFS and delimiters

Our `$PATH` variable is pretty inscrutable, with all those directories concatenated together.  Let's write a script to make it easier to read.

```
#!/usr/bin/env bash

string="$PATH"

for path in $string
do
  echo "$path"
done
```
When I run the script, I see:

```
$ ./foo

/Users/myusername/.nvm/versions/node/v18.12.1/bin:/Users/myusername/.rbenv/shims:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/Users/myusername/.rbenv/shims:/Users/myusername/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/myusername/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/myusername/.asdf/shims:/Users/myusername/.asdf/bin:/Users/myusername/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin
```

Then, I add the following to the top of the script:

```
IFS=":"
```

When I re-run the script, I get:
```
bash-3.2$ ./foo

/Users/myusername/.nvm/versions/node/v18.12.1/bin
/Users/myusername/.rbenv/shims
/Users/myusername/.yarn/bin
/Users/myusername/.config/yarn/global/node_modules/.bin
/Users/myusername/.rbenv/shims
/Users/myusername/.rbenv/bin
/usr/local/lib/ruby/gems/3.1.0
/Users/myusername/.cargo/bin
/usr/local/opt/redis@3.2/bin
/usr/local/opt/mongodb@3.2/bin
/usr/local/sbin
/Users/myusername/.yarn/bin
/Users/myusername/.config/yarn/global/node_modules/.bin
/usr/local/opt/ruby/bin
/Users/myusername/.asdf/shims
/Users/myusername/.asdf/bin
/Users/myusername/.rbenv/shims
/usr/local/opt/redis@3.2/bin
/usr/local/opt/mongodb@3.2/bin
/usr/local/sbin
/Users/myusername/.yarn/bin
/Users/myusername/.config/yarn/global/node_modules/.bin
/usr/local/bin
/System/Cryptexes/App/usr/bin
/usr/bin
/bin
/usr/sbin
/sbin
/Library/Apple/usr/bin
/Applications/Postgres.app/Contents/Versions/latest/bin
```

Note that some directories (such as `/Users/myusername/.rbenv/shims`) appear multiple times.  That's a sign of less-than-great code cleanliness on my part, namely in my shell config scripts.  One day I'll figure out and fix the root cause of that issue. ;-)

This experiment also shows that iterating over a string is similar to iterating over an array, where the items in the array are equivalent to the items in the string separated by the value of `$IFS`.  So if, like my machine, yours uses the " " character, then a string like "foo bar baz" (with 3 words and two spaces) will be separated into 3 separate strings ("foo", "bar", and "baz") for the purposes of iteration.

Let's move on to line 2 of the shim file.
