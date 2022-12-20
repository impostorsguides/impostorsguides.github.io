---
layout: default
title: Start Here
permalink: /start-here/
---

# What is "The Impostor's Guide To Programming"?

It's “David and Goliath” for Github.

The goal is to help a newbie programmer grok an unfamiliar, inscrutable codebase, one line of code at a time.

# What is in-scope for this project?

By the end of reading this material, she should know:

 - What codebase X’s purpose is.
 - How it differs from other tools with the same purpose.
 - What codebase X’s design philosophy is.
 - How its implementation helps it deliver on that philosophy.

Within Y minutes (# TBD), she should be able to answer the first 3 questions.

Within Z hours / days (# TBD), she should be able to answer the 4th question.

Just as important, she should have a framework for learning how to repeat this process on her own, with any library / framework / language she chooses.

# What is *out-of-scope* for this project?

The goal is explicitly NOT to be 100% accurate correct.  Why?  The book "Made To Stick" talks about the inherent trade-off between accuracy and usefulness, and uses the example of teaching a 6th-grader about an atom and its electons.  We can tell a 6th grader that electrons orbit around an atom's nucleus like a planet orbits around the sun, which is a useful metaphor but not 100% accurate.  Or we can talk to that same 6th grader about "electron density" and "probability clouds", which is much more accurate, but is likely to go completely over the child's head.

Quoting the book, "An accurate but useless idea is still useless."  My goal is to be *directionally accurate*.  I want to present just enough information to be useful, then a little more, then a little more.

# What methodology will you use?

The plan is to document various popular open-source projects, one line of code at a time, until I’ve analyzed the whole codebase.  I might also attempt to analyze the repo's commit history, for added context on why certain design decisions were made.

This is an experiment in new ways to help beginner programmers level up.  I'm trying to apply the principles of "sticky ideas" that I learned while reading "Made To Stick", by Chip and Dan Heath.  Principles like:

  - Keep the idea simple.  Not simple as in "use small words", but simple as in "stick to the core idea, and keep it succinct."
  - Present the core information in unexpected ways.  If you're not surprised, you're not learning.  Disrupting peoples' guessing machines means the information will be remembered longer.
  - Make the information concrete.  Don't just give people abstract definitions.  Use tangible examples whenever possible.
  - Build credibility.  In this case, I mean the credibility of the idea I'm "selling", which is that a newbie can become a world-class engineer.  If the newbie can see herself beginning to understand a real-world, widely-used codebase, she'll know this goal really is possible.
  - Appeal to emotion and identity.  "We are engineers with grit.  If we don't understand something, we don't give up.  We break it down into smaller, simpler pieces until we grok it.  Then we run experiments to confirm our understanding.  We take it easy on ourselves, and we get better one day at a time.  If we need help, we ask for it."
  - Use stories.  Stories can be a form of simulated practice.  Talk about real-world examples where we made mistakes, discovered our mistakes, and corrected our mistakes.  Stories can also be a source of inspiration.  Talk about world-class, famous engineers who were once just like us, but got better by stretching their knowledge bit by bit until they became who they are today.
  - Use Robert Cialdini's teaching trick of starting the class with a relevant mystery, then using the rest of class to solve it.  "Cialdini believes that a major benefit of teaching using mysteries is that 'the process of resolving mysteries is remarkably similar to the process of science.' So, by using mysteries, teachers don’t just heighten students’ interest in the day’s material; they train them to think like scientists."
  - The answer to the question "What does RBENV do?" is the sum of the answers to the questions "What does file X / Y / Z / etc. in RBENV do?"  So by examining what each file does in turn, we can gradually develop an understanding of what the program as a whole does.

Heath, Chip; Heath, Dan. Made to Stick (p. 82). Random House Publishing Group. Kindle Edition.

# What specific skills are you trying to impart?

I’d like to acquire (and teach) the skills of:

 - Specific technologies, languages, frameworks, etc. (ex. I learn shell scripting, basic Makefiles, etc. by analyzing RBENV)
 - Learning how to learn (learning by teaching, learning by experimentation and breaking things, etc.)
 - Tenacity and grit; not giving up in the face of a problem that I don’t know how to solve, or a question that I don’t know how to answer.
 - Teaching what I learn, to help others level up as well.

# Why focus on open-source?

Open-source code is a great learning resource.  There are engineers and developers out there who have forgotten more about code than I’ll ever know, and their code contains knowledge that is ours for the asking.  Just as great authors are also voracious readers, great engineers often get that way (at least partly) by reading great code.

# OK, but why blog about it?

## To “Learn By Teaching”

A great way to learn is to teach what you know.  It’s the Feynman Technique.  If I find myself unable to communicate my understanding of something, it means I don’t understand it well enough.  When that happens, I’ll know where to refocus my efforts.

## To Keep Myself Consistent

By writing everyday, I’ll be able to document the progress I’m making.  It’s the “don’t break the chain” productivity trick- small efforts multiplied over time will result in huge leaps in knowledge.

## To Get Feedback

Inevitably, some of the stuff I write here will be wrong.  If you notice that’s the case, I want to hear about it.  Submit a Github pull request or an issue to let me know.

## To Get Help When I’m Stuck

I plan to keep track of the open questions I have, and the problems I’m unable to solve on my own.  If someone else knows how to answer those questions, they can feel free to submit a solution.  Turning this into a collaboration between multiple engineers would mean that we can help fill in each others’ knowledge gaps.

## To “Send The Elevator Back Down”

I started coding in late 2012 - early 2013, at Dev Bootcamp in Chicago.  So many teachers, mentors, and fellow students helped me out along the way.  I would have given up if not for them.  The least I can do now is pay it forward to those in the same position I was in at that point.

## To Make The Learning Resource I Wish I’d Had

There are some learning resources that speak my language, like the Michael Hartl tutorial (“build an X from scratch” is very much my speed).  But I find other docs and resources to be maddeningly abstract.  They’re often written by people suffering from the Curse of Knowledge, people who have long since forgotten what it’s like to be a beginner.  I don’t think it’s productive to tell newbies to “read the fucking manual” when the manual often isn’t written with newbies in mind, i.e. without examples, with jargon that goes undefined, etc.

I love newbies and I never want to lose touch with what it was like to be one.  This is my attempt to offer today’s noobs a learning resource that speaks to them at their level.

## To Build Community

At Dev Bootcamp, I was surrounded by peers of varying skill levels.  In some cases, they were just a little bit ahead of me in their knowledge, enough that they had something to teach me but not so far beyond that they forgot what it was like to be me.  In other cases, I was this same person for other students, and I was able to solidify my newly-acquired knowledge by helping those people fill in the gaps.  Together, we helped each other level up and bonded over tackling tough challenges together.

Dev Bootcamp closed down in 2017.  I think that’s a shame, and I consider myself lucky to have participated in it while it was around.  The more beginner-friendly communities we can build in tech, the more diverse viewpoints we’ll attract to tech, and the more well-rounded our industry will become.

# What’s Your Teaching Writing Style?
I want these code walk-throughs to be fun, or at the very least interesting.  At its best, walking through a codebase and figuring out what it does should be like a Sherlock Holmes mystery!

I find I learn best from people who talk through their thought process, so I try to do likewise.  I verbalize:

 - what I think I’m looking at,
 - the different questions I ask myself, and
 - how I prioritize which questions to pursue and which ones to put on the back burner.

Doing so helps me spot holes in my own logic.  And on a good day, that thought process leads me to the correct answer.

I also experiment, often.  If I think a certain thing is taking place within a section of code, I try to reproduce that behavior on my own, using a “minimally-reproducible example”.  If the experiment behaves the way I hypothesized it should, then I consider the experiment a success.  If not, then it forces me to ask why not.

Oftentimes this process works great.  Sometimes it gets messy.

I hit dead ends.  My thoughts can get muddled by too many questions.  Sometimes I go on rants.

I take solace in the fact that this is probably an experience which is shared by many devs, in their day-to-day work lives.

Take what I write here with a huge grain of salt.  It may well be wrong.

# You’re not an expert.  Aren’t you making the internet a worse place by putting potentially incorrect information out into the world?  Isn’t there enough false info on the internet already?

If I took the above attitude to heart, I’d refrain from publishing anything until it was 100% perfect.  That’s a great recipe for never publishing anything, never getting feedback on anything, and never learning anything.

That’s what would make the internet a worse place.

Or, and here me out: if we see something online that we think is incorrect, we can let the author know.  Even crazier, maybe we could even be kind when we do it.

I know some stuff that you don’t, and you know some stuff that I don’t.  Let’s fill in the blanks for each other, and let’s do it kindly and cooperatively.  That is how the internet gets better.

# Why do so many links on your posts point to Archive.org and Archive.ph?

This project represents many months of research and effort for me.  Over that period of time, I’ve done countless Google searches and found countless links that have helped me.  Over time, the content of those links is bound to change.  It would add to the confusion of a newbie if I told them I read something on a linked resource, only for them to find that the resource now contains completely different information when they click the link.  Even worse would be if the link were broken, leaving nothing on that page at all!

I wanted to preserve how those pages looked at the time I encountered them.  If you can see what I saw when I was thinking through these problems, you’ll be better able to follow my train of thought.  It’s the same reason I often post screenshots of those same pages.  If you see what I saw, it’s easier for me to communicate my train of thought to you.
