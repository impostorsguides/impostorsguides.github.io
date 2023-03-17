---
layout: default
title: Resources
permalink: /resources/
---


<ul class="resources-titles">
  <li><h2>bash for Rubyists</h2></li>
  <ol type="I">
    <h3><li>Part 1: The RBENV Shim</li></h3>
    <ol>
    {% assign sorted_pages = site.pages | sort:"id" %}

    {% for page in sorted_pages %}
      {% if page.category == 'rbenv-pt-1' %}
        <li><a href="{{ page.url }}">{{ page.title }}</a></li>
      {% endif %}
    {% endfor %}
    </ol>
    <h3><li>Part 2: Walking Through The Project</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
  </ol>
</ul>
