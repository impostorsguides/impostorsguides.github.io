Now we move on to the `rbenv.d/` directory.  The directory structure looks like this:

 - `rbenv.d/`
    - `exec/`
      - `gem-rehash/`
        - `rubygems_plugin.rb`
      - `gem-rehash.bash`

There are two files in total:

 - `rbenv.d/exec/gem-rehash.bash`, and
 - `rbenv.d/exec/gem-rehash/rubygems_plugin.rb`.

 Let's start with `gem-rehash.bash`.

## [gem-rehash.bash](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash.bash){:target="_blank" rel="noopener" }

### When and where does `gem-rehash.bash` get run?

If we remember back to the `libexec/rbenv` file, we recall that the `RBENV_HOOK_PATH` environment variable [gets updated to include the `rbenv.d/` directory](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81){:target="_blank" rel="noopener" }.  And if we recall our read-through of `libexec/rbenv-hooks`, `RBENV_HOOK_PATH` gets used in [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks#L55-L63){:target="_blank" rel="noopener" } to return a list of scripts, which later get run by `rbenv-exec` [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-exec#L36-L41){:target="_blank" rel="noopener" }.  From what we learned about how `rbenv-hooks` works, we can assume that the file we're looking at now (`gem-rehash.bash`) will get run anytime `rbenv-exec` is run.

### What is this file used for?

This file only has one line of code (which we'll get to in a minute), and it hasn't changed much since it was first added [in this PR](https://github.com/rbenv/rbenv/pull/638){:target="_blank" rel="noopener" }.  The title of the PR (`"Bring rbenv-gem-rehash functionality to core"`) implies that this file's functionality used to be part of some external library, but that functionality was later moved into RBENV itself.

If we Google "rbenv-gem-rehash", one of the first results we'll find is [this Github repo](https://github.com/rbenv/rbenv-gem-rehash){:target="_blank" rel="noopener" }, whose job was to save RBENV users from having to run `rbenv rehash` every time they install a gem.  The README file includes the following line:

> This plugin is deprecated since its behavior is now included in rbenv core.

So `gem-rehash.bash` is part of a pre-installed hook, which automatically runs `rbenv rehash` on the user's behalf.

### How does the file work?

As mentioned earlier, the file only contains one line of code:

```
export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

This line prepends the value of `${BASH_SOURCE%.bash}` to any previous value of `RUBYLIB`, and re-exports the new `RUBYLIB` value.

To determine the value of `${BASH_SOURCE%.bash}` that gets prepended to `RUBYLIB`, we can update `gem-rehash.bash` to the following:

```
echo "BASH_SOURCE: $BASH_SOURCE"
echo "BASH_SOURCE%.bash: ${BASH_SOURCE%.bash}"

export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

If we run any `rbenv exec` command, we should get our answer.  However, bear in mind that we rarely call `rbenv exec` directly.  Instead, it's called [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-rehash#L80){:target="_blank" rel="noopener" } by shims when we run a gem's executable.

So instead, let's run a command which invokes a shim:

```
$ ruby -e 'puts 5+5'

BASH_SOURCE: /Users/myusername/.rbenv/rbenv.d/exec/gem-rehash.bash
BASH_SOURCE%.bash: /Users/myusername/.rbenv/rbenv.d/exec/gem-rehash
10
```

So `BASH_SOURCE` is the name of the file we're running, and the parameter expansion simply shaves off the `.bash` suffix.

### What is `RUBYLIB`?

We're prepending `/Users/myusername/.rbenv/rbenv.d/exec/gem-rehash` to our `RUBYLIB` variable.  But what is the purpose of this variable?

If we run `man ruby` and search for `RUBYLIB`, we see the following:

> RUBYLIB
>
> A colon-separated list of directories that are added to Ruby's library load path (`$:`).  Directories from this environment variable are searched before the standard load path is searched.

So by prepending our directory to `RUBYLIB`, we're indirectly updating Ruby's load path to include that directory as well.

The above docs also mention that Ruby's load path is referred to with the `$:` syntax.  Googling `Ruby "$:"` reveals that `$:` is shorthand for Ruby's `$LOAD_PATH` environment variable.  If we then Google `"RubyGems LOAD_PATH"` to see how `$LOAD_PATH` is used by RubyGems, we find [the "RubyGems Plugins" page](https://web.archive.org/web/20221013080106/https://guides.rubygems.org/plugins/){:target="_blank" rel="noopener" }, which says:

> RubyGems will load plugins in the latest version of each installed gem or `$LOAD_PATH`. Plugins must be named `'rubygems_plugin'` (`.rb`, `.so`, etc) and placed at the root of your gem's `#require_path`. Plugins are installed at a special location and loaded on boot.

So RubyGems will read from `$LOAD_PATH` in order to find the `rubygems_plugin.rb` file.  But in order for it to *find* that file, its directory must be added first.  That's the job of `gem-rehash.bash`- to add `rbenv.d/exec/gem-rehash/rubygems_plugin.rb` to `LOAD_PATH` so that RubyGems can find and execute it.

We can prove this to ourselves with an experiment

#### Experiment- which loads first, `gem-rehash.bash` or `rubygems_plugin.rb`?

We mentioned that `gem-rehash.bash` gets called whenever we run a Ruby command which has a shim.  One of those Ruby commands that we might run is `gem install`, which (unsurprisingly) installs a gem!  Let's remove our previous `echo` commands from `gem-rehash.bash`, and add a new one to the first line of the file:

```
echo "Hello from gem-rehash.bash"
```

Let's also skip ahead to `rubygems_plugin.rb` and add the following `puts` statement to the top of the file:

```
puts "Hello from rubygems_plugin.rb"
```

If we run `gem install foobarbazbuzz` (or another non-existent gem), we see:

```
$ gem install foobarbazbuzz

Hello from gem-rehash.bash
Hello from rubygems_plugin.rb

ERROR:  Could not find a valid gem 'foobarbazbuzz' (>= 0) in any repository
ERROR:  Possible alternatives: foobarbaz
```

So `gem-rehash.bash` gets called first, updates `RUBYLIB` to include the `rbenv.d/exec/gem-rehash/` directory, and then `rubygems_plugin.rb` gets called (because we've just added its directory to `RUBYLIB`).

If we comment out the one and only line in `gem-rehash.bash`, will `rubygems_plugin.rb` still get run?  Let's find out.

I update `gem-rehash.bash` to the following:

```
echo "hello from gem-rehash.bash"

# export RUBYLIB="${BASH_SOURCE%.bash}:$RUBYLIB"
```

When I re-run the `gem install foobarbazbuzz` command, I see:

```
$ gem install foobarbazbuzz

hello from gem-rehash.bash
ERROR:  Could not find a valid gem 'foobarbazbuzz' (>= 0) in any repository
ERROR:  Possible alternatives: foobarbaz
```

We still see `hello from gem-rehash.bash`, but now we no longer see `Hello from rubygems_plugin.rb`.  So without our update of `RUBYLIB`, we won't run our `rubygems_plugin.rb` file.

But what does the code in `rubygems_plugin.rb` do?  Let's break down the code line-by-line.

## [rubygems_plugin.rb](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/rbenv.d/exec/gem-rehash/rubygems_plugin.rb){:target="_blank" rel="noopener" }

First block of code:

```
hook = lambda do |installer|
  ...
end
```

### Telling RubyGems what to do after installing or uninstalling a gem

Here we define a lambda, or a block of code which can be stored in a variable and passed around to anyone who wants to call it.  We expect that whoever calls our lambda will pass a single argument to it- an instance of the `Gem::Installer` class.

If we look at [the docs page](https://web.archive.org/web/20230323054237/https://docs.ruby-lang.org/en/master/Gem/Installer.html){:target="_blank" rel="noopener" } for this class, we see:

> The installer invokes pre and post install hooks. Hooks can be added... through a rubygems_plugin.rb file in an installed gem...

This is the part of `Gem::Installer` that we care about.  For now, we're just defining our `hook` lambda.  Later on, we'll actually invoke it.

### Running `rbenv rehash`

Next block of code:

```
begin
  # Ignore gems that aren't installed in locations that rbenv searches for binstubs
  if installer.spec.executables.any? &&
      [Gem.default_bindir, Gem.bindir(Gem.user_dir)].include?(installer.bin_dir)
  ....
```

We wrap our code in a `begin/end` block, because we'll invoke the `rescue` keyword later.  The code inside the `begin` block is our happy path, and the code inside our `rescue` block is our sad path, i.e. what happens if something goes wrong inside the `begin` block.

Per [the docs](https://web.archive.org/web/20230521071726/https://docs.ruby-lang.org/en/2.4.0/syntax/exceptions_rdoc.html){:target="_blank" rel="noopener" }, you can leave out the `begin` keyword, but **only** if your code is inside a method.

What goes on inside the happy path?  According to the comment, we check two things.

#### Checking if the gem has any executables

```
if installer.spec.executables.any?...
```

First we check whether the gem that we're installing (or un-installing) has any commands that can be run from the terminal.  [The docs for `Gem::Installer`](https://web.archive.org/web/20230323054237/https://docs.ruby-lang.org/en/master/Gem/Installer.html#method-i-spec){:target="_blank" rel="noopener" } tell us that the `installer.spec` method is "a lazy accessor for the installer's spec".  What is "the installer's spec"?  If we step through the code, we see that this method returns an instance of the `Gem::Specification` class.

In turn, the `Gem::Specification` class has an instance method called `#executables`.  If we look up [the docs for *that* method](https://web.archive.org/web/20230616110144/https://guides.rubygems.org/specification-reference/#executables){:target="_blank" rel="noopener" }, we see that this method returns any commands that the gem exposes.  If the gem doesn't expose any commands, there's no point in running `rbenv rehash`, because there's nothing to create a shim for.

For example, if we were to put a debugger inside our `rubygems_plugin.rb` file, then run `gem install rails` and step through the code, we'd see that the `railties` gem (which is one of the gems that Rails depends on) exposes the `rails` command, which you'd type in the terminal whenever you want to do Rails-y things.

One big gotcha here- if you try to re-install a gem that you've already installed, even one with executables, you'll get an empty array for `#executables`.  I don't yet know why this is, but I have a question out to the RubyGems folks [here](https://github.com/rubygems/rubygems/discussions/6806){:target="_blank" rel="noopener" } to find out.

#### Checking if the Gem's executable directory matches RBENV's expectations

```
... && [Gem.default_bindir, Gem.bindir(Gem.user_dir)].include?(installer.bin_dir)
```

We see a lot of calls to methods with `bindir` or `bin_dir` in their names.  A "bindir" is a directory where executable files are located.  This doesn't necessarily mean that the files are literal binary code.  The use of `bindir` as a name is a historical artifact from the days when executable files were compiled into binary code, before being executed.  Hence, `bin` came to be associated with `executable`.

These days, that's not necessarily true, as we in UNIX-land can invoke a filename and execute it as a command, provided it has a shebang at the top.

In the above code snippet, we see the following method calls:

 - `Gem.default_bindir`
    - "The default directory for binaries" (source [here](https://ruby-doc.org/stdlib-2.6/libdoc/rubygems/rdoc/Gem.html#method-c-default_bindir){:target="_blank" rel="noopener" })
    - On my machine, this evaluates to `/Users/myusername/.rbenv/versions/2.7.5/bin`.
 - `Gem.user_dir`
    - "Path for gems in the user's home directory" (source [here](https://ruby-doc.org/stdlib-2.6/libdoc/rubygems/rdoc/Gem.html#method-c-user_dir){:target="_blank" rel="noopener" })
    - On my machine, this evaluates to `/Users/myusername/.gem/ruby/2.7.0`.
    - Note that this path does not actually exist on my machine!
 - `Gem.bindir`
    - "The path where gem executables are to be installed." (source [here](https://ruby-doc.org/stdlib-2.6/libdoc/rubygems/rdoc/Gem.html#method-c-bindir){:target="_blank" rel="noopener" })
    - On my machine, `Gem.bindir(Gem.user_dir)` evaluates to `/Users/myusername/.gem/ruby/2.7.0/bin`.
    - Note that this path does not actually exist on my machine!
 - `installer.bin_dir`
    - "The directory a gem's executables will be installed into" (source [here](https://web.archive.org/web/20230708134234/https://ruby-doc.org/stdlib-3.1.0/libdoc/rubygems/rdoc/Gem/Installer.html){:target="_blank" rel="noopener" })
    - On my machine, this evaluates to `/Users/myusername/.rbenv/versions/2.7.5/bin`.

So here we check whether the actual directory where a gem's executables will be installed matches either:

 - The default RubyGems directory for executables, or
 - The sub-directory inside the user's home directory where executables are stored.

Why do we check these two directories specifically?  The comment above the `if`-check tells us:

```
# Ignore gems that aren't installed in locations that rbenv searches for binstubs
```

These are the two directories that RBENV says it will search for executables to shim.

### Executing 'rbenv rehash'

Next block of code:

```
`rbenv rehash`
```

The backtick syntax tells Ruby to execute the terminal command specified inside the backticks.  In this case, we're telling UNIX to execute `rbenv rehash` in the shell.  From the book ["The Ruby Programming Language"](https://books.google.cl/books?id=jcUbTcr5XWwC&pg=PA53&lpg=PA53&dq=ruby+backticks&source=bl&ots=fLIozb7tjF&sig=ACfU3U1zDhjFnvjOQy1jhjp5mu0USP3zkg&hl=en&sa=X&sqi=2&ved=2ahUKEwjUmsW_pP__AhW1LLkGHf7gAcgQ6AF6BQiXARAD#v=onepage&q=ruby%20backticks&f=false){:target="_blank" rel="noopener" }:

<center>
  <a target="_blank" rel="noopener" href="/assets/images/screenshot-8jul2023-1011am.png">
    <img src="/assets/images/screenshot-8jul2023-1011am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

> Ruby supports another syntax involving quotes and strings.  When text is enclosed in backquotes (the \` character, also known as backticks), that text is treated as a double-quoted string literal.  The value of that literal is passed to the specially-named `Kernel.` method.  This method executes the text as an operating system shell command and returns the command's output as a string.
>
> Consider the following Ruby code:
>
> `ls`
>
> On a Unix system, these four characters yield a string that lists the names of the files in the current directory.  This is highly platform-dependent, of course.  A rough equivalent in Windows might be `dir`.

#### A warning about using backticks in Ruby

If you use backticks, don't use them with user input.  Or at the very least, sanitize said input before passing it to the command wrapped in backticks.  Otherwise, you could potentially be executing malicious code which could delete your entire machine's directory structure, download arbitrary code from the internet, or other destructive things.

Source [here](https://www.hilman.io/blog/2016/01/stop-using-backtick-to-run-shell-command-in-ruby/).

### Rescuing from errors

Next block of code:

```
rescue
  warn "rbenv: error in gem-rehash (#{$!.class.name}: #{$!.message})"
```

The intent here is to gracefully fail if `rbenv rehash` throws an error.

But are we actually rescuing anything with this rescue block?

Given [this conversation](https://news.ycombinator.com/item?id=28197331){:target="_blank" rel="noopener" }:

> What I don't like about backticks in Ruby is that they "ignore" errors in commands you run. It's up to the program author to remember to check $? for the last executed command's exit status. And guess how many times the average Ruby script using this feature implements error handling? Usually it's totally forgotten.

It sounds like the `exit 1` calls inside the `rbenv-rehash` file would not actually cause the backtick syntax to raise an exception, which would need to happen in order for us to reach the code inside this `rescue` block.

Is that true?  Let's find out with an experiment.

#### Experiment- do non-zero exit codes cause the backtick syntax to raise an exception?

Referring back to the code from `rbenv-rehash`, I remember that the command uses a file named `.rbenv-shim` as a lockfile.  It temporarily creates this file inside the `.rbenv/shims/` directory while the shims are being created, and deletes the file when it's done.  If this file already exists, it exits with a non-zero exit code.

To trigger a non-zero exit intentionally, I create this file in the expected directory, and then run `gem install railties`.  I see the following:

```
$ touch ~/.rbenv/shims/.rbenv-shim

$ gem install railties

rbenv: cannot rehash: /Users/myusername/.rbenv/shims/.rbenv-shim exists
Successfully installed railties-7.0.6
Parsing documentation for railties-7.0.6
Done installing documentation for railties after 0 seconds
1 gem installed
```

I was able to trigger a non-zero exit, yet we don't see our warning beginning with `rbenv: error in gem-rehash...` printed to the screen.  Therefore, we've confirmed that we do *not* reach the `rescue` block here.

I submitted a PR [here](https://github.com/rbenv/rbenv/pull/1513){:target="_blank" rel="noopener" } to address this, and am waiting for a response.

## If gems are installed via `bundle install`

Next block of code:

```
if defined?(Bundler::Installer) && Bundler::Installer.respond_to?(:install) && !Bundler::Installer.respond_to?(:install_without_rbenv_rehash)
  ...
else
  ...
end
```

This code was introduced in 2015 as part of [this PR](https://github.com/rbenv/rbenv/pull/806){:target="_blank" rel="noopener" }, and its goal (according to the PR description) was to prevent the `bundle install` command from running `rbenv rehash` multiple times.  Ideally, we'd like that command to run once, after all the gems have been installed.

According to the PR description, the `if` block is executed if we're running `bundle install`, and the `else` code is executed if we're not, i.e. if we're just running `gem install` by itself, without `bundler`.  But when I add various `puts` statements both inside and outside the `if` block, I don't see my output when I run `bundle install` in a brand-new Rails app.

After a lot of digging, I discovered that there was [a commit added to Bundler in 2016](https://github.com/rubygems/bundler/pull/4954/files){:target="_blank" rel="noopener" } which changed the way plugins are loaded.  This change resulted in Bundler using a different load path from the one that it used prior to the change, meaning RBENV's `rubygems_plugin.rb` never gets loaded and we don't execute our post-install hook.  This was confirmed by [an answer to a question I posted](https://github.com/rbenv/rbenv/discussions/1516){:target="_blank" rel="noopener" } on the RBENV "Q&A" page.

Furthermore, I re-add the following line of code to my local copy of Bundler's `lib/bundler/cli/install.rb` file, which the above PR removed:

```
Gem.load_env_plugins if Gem.respond_to?(:load_env_plugins)
```

When I re-run `bundle install` in that same brand-new Rails app, this time I see the `puts` statements.  I delete the line of code I added to `lib/bundler/cli/install.rb`, and re-run `bundle install` using the version of Bundler which was the latest stable version back in 2015, i.e. `1.13.7`:

```
$ bundle _1.13.7_ install
```

Once again, I see the `puts` statements.  OK, we're back in business.

Back to our code:

```
if defined?(Bundler::Installer) && Bundler::Installer.respond_to?(:install) && !Bundler::Installer.respond_to?(:install_without_rbenv_rehash)
```

Here we check the following 3 things:

 - `defined?(Bundler::Installer)`
    - Is the class `Bundler::Installer` defined?
    - This will return true if we've previously loaded a file which defines the `Bundler::Installer` class, and false if not.
 - `Bundler::Installer.respond_to?(:install)`
    - Does that class implement a method called `install`?
 - `!Bundler::Installer.respond_to?(:install_without_rbenv_rehash)`
    - Does that class **not** implement a method called `install_without_rbenv_rehash`?

It makes sense why we'd do the first check- if `Bundler::Installer` is not defined, then we're not running the `bundle install` command.  I'm not sure why the 2nd check is happening, but the 3rd check seems to be present in order to prevent infinite looping of the code, as per [this comment](https://github.com/rbenv/rbenv/pull/806#discussion_r43037156){:target="_blank" rel="noopener" } in the original PR.

### Opening up the `Bundler::Installer` class

Next block of code:

```
Bundler::Installer.class_eval do
...
end
```

We're calling the `class_eval` on the `Bundler::Installer` class.  In Ruby, we commonly use `class_eval` if we want to add one or more methods to each instance of a class, or if we want to add a method to the class itself.  That's what we'll be doing next.

### Redefining the `self.install` method

Next block of code:

```
class << self
  alias install_without_rbenv_rehash install
  def install(root, definition, options = {})
  ...
  end
end
```

The `class << self` block turns any methods defined inside the block into class methods.  We're defining a method called `install` here, but we know that this method already exists because we're inside an `if` block which specifically checked that it exists, via `Bundler::Installer.respond_to?(:install)`.  We can see the previous definition of the method [here](https://github.com/rubygems/bundler/blob/master/lib/bundler/installer.rb#L22){:target="_blank" rel="noopener" }.  It has the exact same signature as our new definition, i.e. the same name and the same arguments.

So we're not *defining* the `install` class method, but *re-defining* it.

We're also calling `alias install_without_rbenv_rehash install` here.  This means we're creating a method named `install_without_rbenv_rehash` which copies our **existing implementation** of `install` (*before* it is over-ridden; see below).

### Checking that we're in a certain directory

```
begin
  if Gem.default_path.include?(Bundler.bundle_path.to_s)
    ...
  end
```

What is `Gem.default_path`?  It sounds like it would return a string representing a path that RubyGems would use to look for gems.  But it actually doesn't return a string, it returns an array of (up to) 3 string paths.  These paths are referred to in [the RubyGems source code](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/defaults.rb#L175){:target="_blank" rel="noopener" } as:

 - [`user_dir`](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/defaults.rb#L103){:target="_blank" rel="noopener" }
    - the directory on the user's machine where gems are stored, assuming no Ruby version manager (such as RBENV) is being used.
    - On my machine, this resolves to `/Users/myusername/.gem/ruby/3.1.0`.
 - [`default_dir`](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/defaults.rb#L37){:target="_blank" rel="noopener" }
    - the default directory where gems are installed for the current Ruby version, *whether or not* a Ruby version manager is being used.
    - On my machine, this resolves to `/Users/myusername/.rbenv/versions/3.1.4/lib/ruby/gems/3.1.0`.
 - [`vendor_dir`](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/defaults.rb#L248){:target="_blank" rel="noopener" }
    - the directory where vendor gems are installed.
    - Vendor gems are gems which have been installed directly into a sub-directory of your project, as opposed to in a central location on your machine which is managed by RubyGems.
    - On my machine, this resolves to `/Users/myusername/.rbenv/versions/3.1.4/lib/ruby/vendor_ruby/gems/3.1.0`.

Next: what is `Bundler.bundle_path.to_s`?  According to [the source code](https://github.com/rubygems/bundler/blob/master/lib/bundler.rb#L93){:target="_blank" rel="noopener" }, the `bundle_path` method:

> Returns absolute path of where gems are installed on the filesystem.

On my machine, `Bundler.bundle_path.to_s` resolves to `/Users/myusername/.rbenv/versions/3.1.4/lib/ruby/gems/3.1.0`.

There aren't any comments in [the original PR](https://github.com/rbenv/rbenv/pull/806){:target="_blank" rel="noopener" } about why this `if` conditional is necessary.  The conditional seems to be checking whether the directory that Bundler will use to install gems is one of the above 3 directories (`user_dir`, `default_dir`, or `vendor_dir`).  But it's hard to tell why we care about that, or under what circumstances the `if` check would return `true` vs. `false`.

One clue we have is in what happens inside the `if` block.  Let's look at that.

## Counting the initial number of installed gems

Next block:

```
bin_dir = Gem.bindir(Bundler.bundle_path.to_s)
bins_before = File.exist?(bin_dir) ? Dir.entries(bin_dir).size : 2
```

[The source code](https://github.com/rubygems/rubygems/blob/master/lib/rubygems.rb#L301){:target="_blank" rel="noopener" } tells us that `Gem.bindir contains:

> The path where gem executables are to be installed.

It turns out that the argument to this method call is optional.  We can call `Gem.bindir` by itself.  It also turns out the `Gem.bindir`'s value is the same as `Bundler.bundle_path.to_s`, i.e.:

```
/Users/richiethomas/.rbenv/versions/3.1.4/bin
```

Once we have the directory where gems will be installed, we make sure it actually exists via `File.exist?(bin_dir)`, and then count the number of items it already contains via `Dir.entries(bin_dir).size`.

If that directory doesn't exist, we default to the number 2.  I'm not sure why 2 is the default here.  Furthermore, the existence of any default number implies that we'll keep moving forward even if `bin_dir` doesn't exist.  I'm not sure why we'd do that either, since it seems hard to install any gems at all if that directory doesn't exist.

I decide to check what the initial value of this directory is before *any* gems get installed, i.e. on a freshly-installed version of Ruby.  I install a Ruby version which didn't previously exist on my machine (`3.2.2`) and check the `bin` directory:

```
$ ls /Users/richiethomas/.rbenv/versions/3.2.2/bin

bundle		erb		irb		rake		rdbg		ri		typeprof
bundler		gem		racc		rbs		rdoc		ruby
```

Because I'm lazy, rather than manually count the number of entries, I go into `irb` and repeat the same `Dir.entries` command that's in our `rubygems_plugin.rb` file:

```
irb(main):002:0> Dir.entries('/Users/richiethomas/.rbenv/versions/3.2.2/bin').size

=> 15
```

That looks like too many.  Now I go back and count the entries manually, and I come up with 13.  That's 2 less than what `Dir.entries` gives us.  Interesting.  I remove the `.size` and look at the entries themselves:

```
irb(main):006:0> Dir.entries('/Users/richiethomas/.rbenv/versions/3.2.2/bin')

=> [".", "..", "rdbg", "irb", "rake", "bundle", "ri", "rbs", "racc", "erb", "rdoc", "typeprof", "bundler", "ruby", "gem"]
```

OK, so `"."` and `".."` are being counted as entries.  This explains the default value of `2`- it implies that we're assuming an empty directory.

So we count the number of installed gems before the install itself happens.  But we only do this if `Gem.default_path.include?(Bundler.bundle_path.to_s)` is true.  And if we skip ahead a bit, we see the following code:

```
if bin_dir && File.exist?(bin_dir) && Dir.entries(bin_dir).size > bins_before
  `rbenv rehash`
end
```

So we only run `rbenv rehash` if `bin_dir` has been initialized.  And `bin_dir` is only initialized inside our current `if` block:

```
if Gem.default_path.include?(Bundler.bundle_path.to_s)
  bin_dir = Gem.bindir(Bundler.bundle_path.to_s)
  bins_before = File.exist?(bin_dir) ? Dir.entries(bin_dir).size : 2
end
```

So we know that, if `Gem.default_path.include?(Bundler.bundle_path.to_s)` returns false, `rbenv rehash` won't be run, and this hook as a whole becomes a no-op.

Next block of code:

```
rescue
  warn "rbenv: error in Bundler post-install hook (#{$!.class.name}: #{$!.message})"
end
```

This just catches any errors that happen while trying to count the current number of gems, and [alerts the user with a warning message](https://web.archive.org/web/20211021081737/https://apidock.com/ruby/v2_5_5/Kernel/warn){:target="_blank" rel="noopener" }.

### Installing the gems

Next block of code:

```
result = install_without_rbenv_rehash(root, definition, options)
```

Here's where we call the **original** version of `Bundler::Installer::install` (**not** the new one we just finished defining above).  We can prove this to ourselves by adding a `debugger` just before this line of code, and calling `step` once we get to this method call:

```
(byebug) step

[17, 26] in /Users/myusername/.rbenv/versions/3.1.4/lib/ruby/gems/3.1.0/gems/bundler-1.13.7/lib/bundler/installer.rb
   17:     attr_reader :post_install_messages
   18:
   19:     # Begins the installation process for Bundler.
   20:     # For more information see the #run method on this class.
   21:     def self.install(root, definition, options = {})
=> 22:       installer = new(root, definition)
   23:       Plugin.hook("before-install-all", definition.dependencies)
   24:       installer.run(options)
   25:       installer
   26:     end
```

The above `install` method looks nothing like the one we just defined.  Also, the filepath at the top of the screen:
```
/Users/myusername/.rbenv/versions/3.1.4/lib/ruby/gems/3.1.0/gems/bundler-1.13.7/lib/bundler/installer.rb
```

...is different from the file that we're currently in:

```
rbenv.d/exec/gem-rehash/rubygems_plugin.rb
```

Both of these facts indicate that the purpose of `alias`ing the `install` method is to wrap the original method inside a new method, which supplements its behavior with additional behavior.

### Running `rbenv rehash`, if needed

Next block of code:

```
if bin_dir && File.exist?(bin_dir) && Dir.entries(bin_dir).size > bins_before
  `rbenv rehash`
end
result
```

We run `rbenv rehash` if the following 3 things are true:

 - the `bin_dir` variable has been initialized
 - it corresponds to a directory which actually exists, and
 - the number of items it contains now is greater than what it was before we called `install_without_rbenv_rehash`

This is the "additional behavior" that our version of the `install` method adds to the existing `install` method.  Furthermore, this is how the core team achieved its goal of only running `rbenv rehash` after all the gems had been installed.

Lastly, before exiting, we simply return the result of the call to the original `install` method.  This ensures that the end result of our wrapper method has the same return value as the original, so that any callers get back the object that they're expecting.

This is another example of the principle of the "shim", in the sense that anyone calling `install` method has no idea that they're talking to *this* version of `install`, not the original `install`.

## If gems are installed via `gem install`

Last block of code:

```
else
  begin
    Gem.post_install(&hook)
    Gem.post_uninstall(&hook)
  rescue
    warn "rbenv: error installing gem-rehash hooks (#{$!.class.name}: #{$!.message})"
  end
end
```

If the `if` condition from earlier returns `false`, then we reach this `else` block.  We register our `hook` lambda with RubyGems via the `post_install` and `post_uninstall` class methods.  According to [the docs](https://www.rubydoc.info/github/rubygems/rubygems/Gem.post_install){:target="_blank" rel="noopener" }, `post_install`:

> Adds a post-install hook that will be passed an Gem::Installer instance when Gem::Installer#install is called

And [`post_uninstall`](https://www.rubydoc.info/github/rubygems/rubygems/Gem.post_uninstall){:target="_blank" rel="noopener" }:

> Adds a post-uninstall hook that will be passed a Gem::Uninstaller instance and the spec that was uninstalled when Gem::Uninstaller#uninstall is called

Basically, we just tell RubyGems what to do after a gem is installed or uninstalled, i.e. call `rbenv rehash` if the gem includes any executables.

If anything goes wrong during this process and an exception is raised, we rescue with a warning message.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for `rbenv.d`.  On to the next directory.
