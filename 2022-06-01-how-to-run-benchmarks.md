---
layout: post
title:  "How do I run the benchmarks in the '/benchmarks' directory?"
categories: mysql2
author: richie
---

# The setup

First I had to clone the Github repo and install the gems.

I initially tried to run the following command:

```
bundle exec ruby benchmark/active_record.rb
```

But I got the following error:

```
`require': cannot load such file -- benchmark/ips (LoadError)
```

I subsequently noticed that the gem mentioned in the error message was part of the `optional` gem group, so I had to re-run `bundle install` with the `--with=benchmarks` flag included.

That resulted in a successful installation of the missing `benchmark/ips` gem.  However, re-running `bundle exec benchmarks/active_record.rb` resulted in the following error:

```
~/Desktop/Workspace/OpenSource/mysql2 (master)  $ be ruby benchmark/active_record.rb
Traceback (most recent call last):
	11: from benchmark/active_record.rb:18:in `<main>'
	10: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/benchmark-ips-2.10.0/lib/benchmark/ips.rb:49:in `ips'
	 9: from benchmark/active_record.rb:19:in `block in <main>'
	 8: from benchmark/active_record.rb:19:in `each'
	 7: from benchmark/active_record.rb:20:in `block (2 levels) in <main>'
	 6: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_handling.rb:52:in `establish_connection'
	 5: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_adapters/abstract/connection_pool.rb:1046:in `establish_connection'
	 4: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_adapters/abstract/connection_pool.rb:1205:in `resolve_pool_config'
	 3: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `require'
	 2: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:299:in `load_dependency'
	 1: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `block in require'
/Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `require': cannot load such file -- active_record/connection_adapters/mysql_adapter (LoadError)
	11: from benchmark/active_record.rb:18:in `<main>'
	10: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/benchmark-ips-2.10.0/lib/benchmark/ips.rb:49:in `ips'
	 9: from benchmark/active_record.rb:19:in `block in <main>'
	 8: from benchmark/active_record.rb:19:in `each'
	 7: from benchmark/active_record.rb:20:in `block (2 levels) in <main>'
	 6: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_handling.rb:52:in `establish_connection'
	 5: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_adapters/abstract/connection_pool.rb:1046:in `establish_connection'
	 4: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activerecord-6.1.6/lib/active_record/connection_adapters/abstract/connection_pool.rb:1205:in `resolve_pool_config'
	 3: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `require'
	 2: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:299:in `load_dependency'
	 1: from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `block in require'
/Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/activesupport-6.1.6/lib/active_support/dependencies.rb:332:in `require': Could not load the 'mysql' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile. (LoadError)
```

The important part of this error seems to be:

```
cannot load such file -- active_record/connection_adapters/mysql_adapter (LoadError)
```

# The short story

After much investigation, the TL;DR from the above error seems to be that [the benchmark files are outdated and non-runnable](https://stackoverflow.com/questions/72496891/mysql2-gem-how-to-run-benchmark-files).  However I'm still waiting on a response to [the Github issue I posted](https://github.com/brianmario/mysql2/issues/1269), so TBD on that.

# The long story

The above error seems to indicate that the `mysql` gem was not installed.  Taking another look at the Gemfile, I see:

```
gem 'mysql' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.4')
```

In order to find out what the values on either side of `<` evaluate to, I run the following:

```
$ ruby -e "p Gem::Version.new(RUBY_VERSION)"
=> #<Gem::Version "2.6.0">
$ ruby -e "p Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.4')"
=> false
```

This explains why `mysql` wasn't installed- the `if` condition returns false.  However, that still leaves me at a loss since the benchmark file appears to require that this gem be installed.  How are you supposed to run the benchmark file if your Ruby version is > 2.4.0?

In addition, attempting to install the `mysql` gem with my Ruby version (2.6.0) results in the following error:

```
~/Desktop/Workspace/OpenSource/mysql2 (master)  $ gem install mysql
Building native extensions. This could take a while...
ERROR:  Error installing mysql:
	ERROR: Failed to build gem native extension.

    current directory: /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/mysql-2.9.1/ext/mysql_api
/Users/richiethomas/.rbenv/versions/2.6.0/bin/ruby -I /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0 -r ./siteconf20220601-90095-13x48i7.rb extconf.rb
checking for mysql_ssl_set()... *** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.

Provided configuration options:
	--with-opt-dir
	--without-opt-dir
	--with-opt-include
	--without-opt-include=${opt-dir}/include
	--with-opt-lib
	--without-opt-lib=${opt-dir}/lib
	--with-make-prog
	--without-make-prog
	--srcdir=.
	--curdir
	--ruby=/Users/richiethomas/.rbenv/versions/2.6.0/bin/$(RUBY_BASE_NAME)
	--with-mysql-config
	--without-mysql-config
/Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:467:in `try_do': The compiler failed to generate an executable file. (RuntimeError)
You have to install development tools first.
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:552:in `try_link0'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:570:in `try_link'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:782:in `try_func'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:1069:in `block in have_func'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:959:in `block in checking_for'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:361:in `block (2 levels) in postpone'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:331:in `open'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:361:in `block in postpone'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:331:in `open'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:357:in `postpone'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:958:in `checking_for'
	from /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/2.6.0/mkmf.rb:1068:in `have_func'
	from extconf.rb:45:in `<main>'

To see why this extension failed to compile, please check the mkmf.log which can be found here:

  /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/extensions/x86_64-darwin-19/2.6.0/mysql-2.9.1/mkmf.log

extconf failed, exit code 1

Gem files will remain installed in /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/gems/mysql-2.9.1 for inspection.
Results logged to /Users/richiethomas/.rbenv/versions/2.6.0/lib/ruby/gems/2.6.0/extensions/x86_64-darwin-19/2.6.0/mysql-2.9.1/gem_make.out
```

The important part of the above error message seems to be:

```
You have to install development tools first.
```

I recognize this from previous error messages.  In the past, the solution to this has been to run:

```
xcode-select --install
```

However, I already have XCode installed, and when I run the above command, I see:

```
xcode-select: error: command line tools are already installed, use "Software Update" to install updates
```

Googling how to run a `Software Update`, I see [this StackOverflow link](https://stackoverflow.com/a/71149175/2143275), advising me to run the following:

```
softwareupdate --list --verbose
```

Running that gives me the following output:

```

Software Update Tool

Finding available software
Software Update found the following new or updated software:
* Label: macOS Catalina 10.15.7 Update-
	Title: macOS Catalina 10.15.7 Update, Version:  , Size: 5149093K, Recommended: YES, Action: restart,
```

This seems to indicate that I need to upgrade my OSx.  I do so, and this takes 2-3 hours.  I then try to install the `mysql` gem.  I get the same error (`You have to install development tools first.`).

I then remember that I may need to simply update XCode to the latest version.  I do this as well, which takes probably 5-6 hours, and similarly results in no improvement in the situation.

In frustration, I post [this StackOverflow question](https://stackoverflow.com/questions/72496891/mysql2-gem-how-to-run-benchmark-files) and [this Github issue](https://github.com/brianmario/mysql2/issues/1269).  While the repo's maintainer hasn't replied to the GH issue yet, someone did reply to my SO question with an explanation that seems helpful.  It appears that I needed to run `benchmark/db_setup.rb` to create some necessary DB state.  However this by itself still wasn't enough, and the SO answer indicates that no solution may be possible, as it appears likely that the code in `benchmark` is out of date.