---
layout: default
title: The Impostor's Guide To RBENV
permalink: /rbenv/
---
# The Impostor's Guide to RBENV

<ul>
  {% assign sorted_pages = site.pages | sort:"id" %}

  {% for page in sorted_pages %}
    {% if page.category == 'rbenv' %}
      <li><a href="{{ page.url }}">{{ page.title }}</a></li>
    {% endif %}
  {% endfor %}
</ul>
