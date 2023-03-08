---
layout: default
category: rbenv-piecemeal
---

{% if page.previous-permalink %}
  <div style="margin-top: 2em" />
  Previous: <a href={{ page.previous-permalink }}>{{ page.previous-title }}</a>
{% endif %}

<h2>{{ page.title }}</h2>

{% if page.subtitle %}
  <h3>{{ page.subtitle }}</h3>
{% endif %}

{{ content }}

{% if page.next-permalink %}
  Next: <a href={{ page.next-permalink }}>{{ page.next-title }}</a>
{% endif %}


