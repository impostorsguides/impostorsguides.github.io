---
layout: default
title: Resources
permalink: /resources/
---


<ol type="I">
  <h2><li>bash for Rubyists</li></h2>
  <ol >
    <h3><li>Part 1: The RBENV Shim</li></h3>
    <ol type="i">
    {% assign sorted_pages = site.pages | sort:"id" %}

    {% for page in sorted_pages %}
      {% if page.category == 'rbenv-pt-1' %}
        <li><a href="{{ page.url }}">{{ page.title }}</a></li>
      {% endif %}
    {% endfor %}
    </ol>
    <h3><li>Part 2: Walking Through The Project</li></h3>
    <ol type="i">
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
  </ol>
</ol>
