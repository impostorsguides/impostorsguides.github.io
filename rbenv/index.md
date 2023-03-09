---
layout: default
title: The Impostor's Guide To RBENV
permalink: /rbenv/
---
# The Impostor's Guide to RBENV
Long-form link <a href="/rbenv/ch-0">here</a>

<ol>
  {% assign sorted_pages = site.pages | sort:"id" %}

  {% for page in sorted_pages %}
    {% if page.category == 'rbenv-piecemeal' %}
      <li><a href="{{ page.url }}">{{ page.title }}</a></li>
    {% endif %}
  {% endfor %}
</ol>
