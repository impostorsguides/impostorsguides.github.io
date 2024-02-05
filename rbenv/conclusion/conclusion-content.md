The term "grok" means `understand (something) thoroughly and intuitively`.  But it's deceptive, because there's always more to understand about any given codebase.  Each reader must decide for themselves whether they've learned enough to move on to other challenges.

And that's kind of the point of this guide- if people have an idea in their head that "I'll be a 10x / ninja / rockstar / whatever once I understand codebase X", this guide is intended to burst that bubble.  Hopefully you've learned something from reading this, but now you also understand how much more there is to learn.

To put it in terms of the [Dunning-Kruger effect](https://web.archive.org/web/20221129140620/https://slidemodel.com/templates/dunning-kruger-effect-curve-for-powerpoint/){:target="_blank" rel="noopener"}, hopefully I've been able to nudge you a bit out of the "Valley of Despair" and toward the "Slope of Enlightenment".

Speaking of which, just like my goal was to make this codebase less mysterious, I also want to make the idea of being a 10x / ninja / rockstar / whatever less magical.  These are just people who consistently put one foot in front of the other, day after day, until one day they woke up and they were on the core team of one of the most widely-used Ruby version managers around.  That could be you!

With all that word salad out of the way, where do we go from here?  A couple options:

## More about the RBENV git history

We could pivot from reading the code to reading the Github history.  This would give us more context on *why* certain decisions were made, which would certainly help us feel like even less of an impostor.

## `ruby-build`

Back in the introduction to Part 2, we mentioned how you could install new versions of Ruby in an RBENV-friendly manner by using the `ruby-build` plugin.  But we didn't actually cover that plugin, because it was part of a separate codebase.  However, `rbenv install` is a not-uncommon command, and it might pay to dive into that codebase like we did here.  It could also help solidify our understanding of RBENV plugins.

## Other Ruby version managers

Alternately, there are other Ruby version managers out there which are also quite popular, or are gaining in popularity.  Examples include [RVM](https://rvm.io/){:target="_blank" rel="noopener"}, [asdf](https://asdf-vm.com/){:target="_blank" rel="noopener"}, and [chruby](https://github.com/postmodern/chruby){:target="_blank" rel="noopener"}.  I don't currently make use of these programs, so I know even less about them than I do about RBENV.  Just like learning a new programming language has taught me more about the languages I currently use, learning how other Ruby version managers work could teach me more about the approach that RBENV takes.

## The `bats` codebase

Tests are the thing that give us confidence in our code, so we can only be as confident in our code as we are in our tests.  But we hardly looked at the `bats` code at all, and the few lines of code that we *did* look at, we kind of glossed over (because this was meant to be a guide on RBENV, not on BATS).  By understanding our testing framework better, we could have more confidence in our tests, and therefore more confidence in our code.

## Ruby's codebase

I'm feeling more confident about grokking codebases, now that I've finished reading RBENV's codebase.  I've started wondering if I could tackle even more challenging codebases, maybe even that of Ruby itself.  If I were to understand that, that would likely make it easier to understand code which is written in Ruby.

## Something else entirely?

Is there something you'd like me to cover?  Reach out to me on [Twitter](https://www.twitter.com/impostorsguides){:target="_blank" rel="noopener"} or email me at [impostorsguides] at {gmail}.

## It's Your Call

I think *I'm* ready to move on, but I reserve the right to come back later, and dive into some of the above. ;-)

## Some resources to keep reading

<ol>
  <li><h3><a href="https://missing.csail.mit.edu/" target="_blank">The Missing Semester of Your CS Education (MIT Course)</a></h3>
  <p>Talks a lot about many of the same tools we've encountered here.  And surprisingly beginner-friendly, considering it's from MIT.</p>
  </li>
  <li><h3><a href="https://devhints.io/bash" target="_blank">Bash Scripting Cheatsheet</a></h3>
  <p>From DevHints.io.  A concise list of examples, tips, and tricks in Bash.</p>
  </li>
</ol>
