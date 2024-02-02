---
layout: page
permalink: /blog/
title: Blog
---

<ul class='blog-roll'>
{% for post in site.posts %}

  <li class='blog-post-item'>
    <p class='blog-post-created-at'>{{ post.createdAt }}</p>
    <p class='blog-post-title'>
      <a href="{{ post.permalink}}">{{ post.title }}</a>
    </p>
    <p>{{ post.excerpt }}</p>
  </li>
{% endfor %}
</ul>