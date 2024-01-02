---
layout: default
title: The Shell
permalink: /shell/
path: shell
---


<ul class="resources-titles">
  <h2>The Impostor's Guide To The Shell</h2>
  <h3><a href="/rbenv/introduction">Introduction</a></h3>
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
    <h3><li>Part 2: The `rbenv` command</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2a' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 3: The `rbenv init` command</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2b' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 4: Other RBENV Commands</li></h3>
    <ol>
      {% for page in sorted_pages %}
        {% if page.category == 'rbenv-pt-2' %}
          <li><a href="{{ page.url }}">{{ page.title }}</a></li>
        {% endif %}
      {% endfor %}
    </ol>
    <h3><li>Part 5: Infrastructure Files</li></h3>
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
