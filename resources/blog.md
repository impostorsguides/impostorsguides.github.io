---
layout: page
permalink: /blog/
title: Blog
---

<ul>
{% for post in site.posts %}

  <li>
    <h2>
      <a href="{{ post.permalink}}">{{ post.title }}</a>
    </h2>
    <h4>Posted on: {{ post.createdAt }}</h4>
    <p>{{ post.excerpt }}</p>
  </li>
{% endfor %}
</ul>