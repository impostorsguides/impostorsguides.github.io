<nav style="border-bottom: 1px solid grey; padding-bottom: 1em">
  <div class="internal-links">
    {% for item in site.data.navigation %}
      <a
        class="navlink"
        href="{{ item.link }}"
      >
        {{ item.name }}
      </a>
    {% endfor %}
  </div>
  <div class="external-links">
    {% for item in site.data.social_media %}
      <a
      class="navlink"
        href="{{ item.link }}"
          target="_blank"
        >
        {{ item.name }}
      </a>
    {% endfor %}
  </div>
</nav>

