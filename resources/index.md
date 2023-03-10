---
layout: default
title: Resources
permalink: /resources/
---


<ol type="I">
  <li><a href="/rbenv/ch-0">The Impostor's Guide to RBENV</a></li>
  <ol >
    <li>Part 1: The Shim</li>
    <ol type="i">
    {% assign sorted_pages = site.pages | sort:"id" %}

    {% for page in sorted_pages %}
      {% if page.category == 'rbenv-piecemeal' %}
        <li><a href="{{ page.url }}">{{ page.title }}</a></li>
      {% endif %}
    {% endfor %}
    </ol>
  </ol>
</ol>
