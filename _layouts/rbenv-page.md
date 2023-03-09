---
layout: default
category: rbenv-piecemeal
---

{% if page.previous-permalink %}
  <div style="margin-bottom: 2em" />
  Previous: <a href={{ page.previous-permalink }}>{{ page.previous-title }}</a>
  </div>
{% endif %}

<h1>{{ page.title }}</h1>

{{ content }}

{% if page.next-permalink %}
<div style="margin-top: 2em" />
  Next: <a href={{ page.next-permalink }}>{{ page.next-title }}</a>
</div>
{% endif %}


