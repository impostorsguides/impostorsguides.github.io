---
layout: default
title: The Shell
permalink: /shell/
path: shell
---

<h1>Introduction</h1>

<blockquote>"The most effective debugging tool is still careful thought, coupled with judiciously placed print statements." — Brian Kernighan, <a href="https://web.archive.org/web/20220122011437/https://wolfram.schneider.org/bsd/7thEdManVol2/beginners/beginners.pdf" target="_blank" rel="noopener"><u>Unix for Beginners</u></a>.</blockquote>

<blockquote>"Don't chase your dreams. Humans are persistence predators. Follow your dreams at a sustainable pace until they get tired and lie down." – <a href="https://bsky.app/profile/raven.corvids.club/post/3k4rcbonfkq2u" target="_blank" rel="noopener">@raven.corvids.club (on BlueSky)</a></blockquote>

<h2>Background</h2>

<p>What's the first thing that happens when you type <code>bundle install</code> into the terminal and hit "Enter"?</p>

<p>This is the question which set me off on this entire project. For those unfamiliar with the <code>bundle install</code> command, it comes from the <a href="https://web.archive.org/web/20240126020236/https://bundler.io/" target="_blank" rel="noopener">Bundler library</a>.  Bundler provides "a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed", according to its website.</p>

<p>Professionally, I work on a large Rails codebase with many contributors, and <code>bundle install</code> is one of the most common commands we find ourselves typing.  I was frustrated that I didn't know how this command worked under-the-hood.  Since I'm a big believer that <a href="https://ideas.time.com/2011/11/30/the-protege-effect/" target="_blank" rel="noopener">"The best way to learn something is to explain it to someone else"</a>, I decided to blog about what I was learning, as I learned it.</p>

<p>As it turns out, my deep-dive took me on a detour into the code for my Ruby version manager.  That version manager, named RBENV, creates shim files for every Ruby command you enter, including <code>bundle</code>.  Therefore, the first file I encountered in my deep-dive was this shim.</p>

<p>In the process of exploring this shim file (and RBENV's code in general), I ended up learning a lot about the UNIX shell and Bash, the language RBENV is written in.  At the risk of sounding like I'm backwards-rationalizing, I'd argue this is actually more useful than learning about Bundle, since Bash is much more broadly-used than Bundle.</p>

<p>Along the way, I kept a journal of all my wins, my frustrations, my questions, my a-ha moments, etc.  The document you're reading is an edited version of that journal.</p>

<h2>Disclaimer</h2>

<p>This is NOT an official guide to RBENV's codebase.  I am *not* a member of the RBENV core team, nor is this guide endorsed by the core team in any way. It is simply the (sometimes incorrect) educated guesses of a journeyman engineer who wants to attain mastery by <a href="https://www.amazon.com/Teach-everything-know-Nathan-Barry-ebook/dp/B00IVZUNQW/" target="_blank" rel="noopener">teaching what he's learning</a>.  Please treat what you read here accordingly.</p>

<p>If you spot any errors or omissions, let me know at impostorsguides [at] gmail.</p>

<hr />

<h2>Table of Contents</h2>

<ul class="resources-titles">
  <ol type="I">
    <h3><li>Part 1: The RBENV Shim</li></h3>
    <ol>
    {% assign sorted_pages = site.pages | sort:"id" %}

    {% for page in sorted_pages %}
      {% if page.category == 'rbenv-introduction' %}
        <li><a href="{{ page.url }}">{{ page.title }}</a></li>
      {% endif %}
    {% endfor %}
    </ol>
    <h3><li>Part 2: The `rbenv` command (work-in-progress)</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2a' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 3: The `rbenv init` command (work-in-progress)</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2b' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 4: Other RBENV Commands (work-in-progress)</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 5: Infrastructure Files (work-in-progress)</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-3' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
  </ol>
  <h3><a href="/rbenv/conclusion">Conclusion</a></h3>
</ul>
