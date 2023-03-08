# Scraps of notes

## Initially impressed with ChatGPT

As a last resort, I try ChatGPT haha:

ChatGPT link- https://chat.openai.com/chat/1a2694aa-d446-46b0-a1dd-f40d24377efb

<p style="text-align: center">
  <img src="/assets/images/chat-gpt-why-shebangs-over-file-extensions.png" width="70%" alt="Asking ChatGPT why shebangs are preferred over file extensions when deciding how to interpret a file.">
</p>

ChatGPT lists several reasons for why shebangs might be preferred over file extensions, including:

 - using a shebang instead of a file extension means that you can interpret multiple files with different extensions using the same interpreter, if each file has the same shebang.
 - relying on file extensions means you can't open a file if its file extension isn't known to be associated with a given application, i.e. it isn't standard.
 - relying on the shebang allows you to execute a file using different interpreters, depending on the environment, which might only be known at runtime.

While we don't seem to be relying on any of these facts in the case of RBENV, each point makes sense in a more general sense.

### Aside- using ChatGPT as a last resort

Sometimes I find that the questions I want to ask aren't a good fit for StackOverflow, which [has a very specific format](https://stackoverflow.com/help/how-to-ask) that they want you to use when asking your questions.  This might be because my question takes the form of "What are the pros and cons of X?", which can be interpreted as being opinion-based.  Or they might take the form of "Why was X originally done in Y way?", which is how my question above was interpreted.  StackOverflow wants questions that are likely to have objective, clear-cut answers.  With other types of questions, there didn't use to be a great alternative.  Quora would have been the closest thing that *I* could think of, but I'd never ask a question on their because their interface has way too many ads, and also the quality of answers is just too low.

I'm starting to think that ChatGPT might be a decent alternative.  *It's not perfect* by any means, but the answers I've pulled from it so far have been detailed and appear to be directionally accurate.  It's still important to verify whether the specific claims it makes are actually correct (as I'll illustrate in the next aside), but I feel like that's something we should be doing anyway, even with answers from humans.  I plan on using ChatGPT as a backstop if I get stuck on subsequent questions while writing this post, if only to give me ideas for what directions to look in when I get stuck.

## Getting burned by ChatGPT

So once again, I turned to ChatGPT.  This time the answer it gave me may have been misleading.  The question I asked was:

```
In a UNIX environment, why aren't new files executable by the creator of the file until you run the `chmod`
command?  Shouldn't the file's creator automatically have the ability to execute the file?
```

And the answer it gave was:

<p style="text-align: center">
  <img src="/assets/images/chat-gpt-why-arent-files-executable-by-default.png" width="70%" alt="Asking ChatGPT why files aren't executable by their creator until `chmod` is run.">
</p>

I wanted to verify the statement `When a new file is created, it inherits the default permissions of the directory it was created in...`, so I did an experiment.  I made a directory, verified that its permissions were such that the user who created it could "execute" it, and then created a file inside that directory.  But that file was not, by default, executable by its creator.  That implies the ChatGPT statement was incorrect.  So I Googled `do unix files inherit the permissions of a directory`, and got [this link](https://archive.ph/uQX9j#selection-1631.0-1645.117) as the first result:

<p style="text-align: center">
  <img src="/assets/images/file-permissions-inheritance-in-unix-1.png" width="70%" alt="Confirming that ChatGPT was not, in fact, correct about UNIX file permissions inheritance.">
</p>

This is confirmed by [this StackOverflow post](https://archive.ph/SFV8x):

<p style="text-align: center">
  <img src="/assets/images/file-permissions-inheritance-in-unix-2.png" width="50%" alt="More confirmation that ChatGPT was not, in fact, correct about UNIX file permissions inheritance.">
</p>

So lesson learned- we can't trust ChatGPT implicitly.

---------------------

<!-- ### Asking questions on StackOverflow

When I'm writing a question on StackOverflow, I try to make my chain of thought as clear as possible.  Whenever I make an assertion, I explain why and how I came to that conclusion.  For example, if I make a statement because I read it on another StackOverflow post, I'll link to that post (or even better, I'll link to the specific answer on that post).  Doing this helps people who are trying to answer my question to see how I reached my conclusion.  If they aren't able to do this, it's harder for them to correct me effectively if my assertion is mistaken.

I try to phrase my question as usefully as possible, adhering to the StackOverflow community guidelines on [how to ask a good question](https://archive.ph/EHVnj).  The people who answer questions are taking valuable time out of their day to help less-knowledgeable folks like me, and I want to respect their time.

Sticking to the above guidelines will usually result in a well-written question.  However, I am only human and, despite my best efforts, I will sometimes make mistakes.  I hope that my good-faith effort to ask an effective question will be clear to others, but sometimes I still get downvoted or called-out by folks who are in a less-than-sympathetic mood for whatever reason.  I'd be lying if I said I didn't care at all when that happens- upvotes feel good, after all.  But at the end of the day, if I've done everything I can to craft my question well, I'm willing to lose a few internet points if it means I'll gain a little knowledge. -->
