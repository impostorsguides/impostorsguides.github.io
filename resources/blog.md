---
layout: page
permalink: /blog/
title: Blog
---

<ul class='blog-roll'>
{% for post in site.posts %}

  <li class='blog-post-item'>
    <h2>
      <a href="{{ post.permalink}}">{{ post.title }}</a>
    </h2>
    <h4>{{ post.createdAt }}</h4>
    <p>{{ post.excerpt }}</p>
  </li>
{% endfor %}
</ul>