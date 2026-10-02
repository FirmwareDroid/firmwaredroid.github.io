---
layout: default
title: Documentation
description: Install, operate, query, extend, and maintain FirmwareDroid.
permalink: /documentation/
body_class: documentation-page documentation-index
---
{% assign posts_with_order = site.posts | where_exp: "item", "item.order != nil" | sort: "order" %}
{% assign posts_with_pos = site.posts | where_exp: "item", "item.order == nil and item.position != nil" | sort: "position" %}
{% assign posts_other = site.posts | where_exp: "item", "item.order == nil and item.position == nil" | sort: "date" | reverse %}
{% assign sorted_posts = posts_with_order | concat: posts_with_pos | concat: posts_other %}

{% assign extra_posts = "" | split: "" %}
{% for p in sorted_posts %}
  {% assign p_grp = p.group | default: p.doc_group %}
  {% assign matched = false %}
  {% for grp in site.data.doc_groups %}
    {% if p_grp == grp.id %}
      {% assign matched = true %}
    {% endif %}
  {% endfor %}
  {% if matched == false and p_grp != nil %}
    {% assign extra_posts = extra_posts | push: p %}
  {% endif %}
{% endfor %}

<section class="docs-hero"><div class="container"><p class="eyebrow"><span></span> FMD documentation</p><h1>Build your analysis workflow.</h1><p class="docs-lead">Start with a working deployment, follow a firmware through the analysis pipeline, or extend FMD with your own tooling.</p><div class="docs-quick-links">{% for grp in site.data.doc_groups %}<a href="#{{ grp.id }}">{{ grp.kicker }}</a>{% endfor %}{% if extra_posts.size > 0 %}<a href="#more">Additional Guides</a>{% endif %}</div></div></section>

<section class="docs-catalog container">
  {% for grp in site.data.doc_groups %}
    {% assign group_posts = "" | split: "" %}
    {% for p in sorted_posts %}
      {% assign p_grp = p.group | default: p.doc_group %}
      {% if p_grp == nil %}
        {% if p.categories contains "Setup" %}
          {% assign p_grp = "start" %}
        {% elsif p.categories contains "Architecture" %}
          {% assign p_grp = "understand" %}
        {% else %}
          {% assign p_grp = "extend" %}
        {% endif %}
      {% endif %}
      {% if p_grp == grp.id %}
        {% assign group_posts = group_posts | push: p %}
      {% endif %}
    {% endfor %}

    {% if group_posts.size > 0 %}
      <div class="docs-group" id="{{ grp.id }}"><div class="docs-group-heading"><span>{{ grp.number }}</span><div><p class="kicker">{{ grp.kicker }}</p><h2>{{ grp.title }}</h2></div></div><div class="docs-card-grid">
        {% for post in group_posts %}
          <a class="docs-card{% if post.featured %} featured{% endif %}" href="{{ post.url | relative_url }}"><span class="docs-icon"><i class="{{ post.icon | default: 'fas fa-book-open' }}"></i></span><div><p class="card-label">{{ post.label | default: post.categories.first | default: 'Guide' }}</p><h3>{{ post.title }}</h3><p>{{ post.description }}</p></div><i class="fas fa-arrow-right"></i></a>
        {% endfor %}
      </div></div>
    {% endif %}
  {% endfor %}

  {% if extra_posts.size > 0 %}
    <div class="docs-group" id="more"><div class="docs-group-heading"><span>04</span><div><p class="kicker">Additional Guides</p><h2>More resources and tutorials</h2></div></div><div class="docs-card-grid">
      {% for post in extra_posts %}
        <a class="docs-card{% if post.featured %} featured{% endif %}" href="{{ post.url | relative_url }}"><span class="docs-icon"><i class="{{ post.icon | default: 'fas fa-book-open' }}"></i></span><div><p class="card-label">{{ post.label | default: post.categories.first | default: 'Guide' }}</p><h3>{{ post.title }}</h3><p>{{ post.description }}</p></div><i class="fas fa-arrow-right"></i></a>
      {% endfor %}
    </div></div>
  {% endif %}
</section>

<section class="docs-help"><div class="container"><div><p class="kicker">Need more detail?</p><h2>Read the source or join the project.</h2><p>FMD is an open-source research project. The repository contains the current implementation and authoritative list of integrated tools.</p></div><div><a class="button primary-button" href="https://github.com/FirmwareDroid/FirmwareDroid" target="_blank" rel="noopener"><i class="fab fa-github"></i> Open the repository</a><a class="button ghost-button" href="https://github.com/FirmwareDroid/FirmwareDroid/issues" target="_blank" rel="noopener">View issues</a></div></div></section>
