---
layout: default
title: Case Studies
description: Real-world evaluations, empirical studies, and security investigations conducted using FirmwareDroid.
permalink: /case-studies/
---
<section class="docs-hero">
  <div class="container">
    <p class="eyebrow"><span></span> Research &amp; Evaluation</p>
    <h1>Case Studies</h1>
    <p class="docs-lead">Explore in-depth investigations, reproducible workflows, and empirical studies carried out using FirmwareDroid to analyze Android firmware images and pre-installed software.</p>
    <div class="docs-quick-links">
      <a href="#android-tv-boxes"><i class="fas fa-tv"></i> Android TV Boxes</a>
      <a href="#scanning-single-app"><i class="fas fa-cube"></i> Single App Triage</a>
      <a href="#mobilesoft-2023"><i class="fas fa-graduation-cap"></i> MOBILESoft 2023</a>
    </div>
  </div>
</section>

<section class="docs-catalog container">
  <div class="case-studies-hub-list">
    {% for cs in site.data.case_studies %}
    <article class="hub-study-card{% unless cs.published %} coming-soon{% endunless %}" id="{{ cs.id }}">
      <div class="hub-study-icon-wrap" aria-hidden="true">
        <i class="{{ cs.icon | default: 'fas fa-microscope' }}"></i>
      </div>
      <div class="hub-study-content">
        <div class="hub-study-meta-top">
          <span class="case-study-badge">{{ cs.badge }}</span>
          {% if cs.published %}
            {% if cs.date %}<span class="hub-tag"><i class="far fa-calendar-alt"></i> {{ cs.date }}</span>{% endif %}
            {% if cs.read_time %}<span class="hub-tag"><i class="far fa-clock"></i> {{ cs.read_time }}</span>{% endif %}
          {% else %}
            <span class="hub-tag status-unpublished"><i class="fas fa-lock"></i> Unpublished · Release Forthcoming</span>
          {% endif %}
        </div>
        <h2 class="hub-study-title">
          {% if cs.published %}
          <a href="{{ cs.url | relative_url }}">{{ cs.title }}</a>
          {% else %}
          <span>{{ cs.title }}</span>
          {% endif %}
        </h2>
        {% if cs.subtitle %}<p class="hub-study-subtitle">{{ cs.subtitle }}</p>{% endif %}
        <p class="hub-study-desc">{{ cs.description }}</p>
        <div class="hub-study-tags">
          {% for tag in cs.tags %}
          <span class="hub-tag">{{ tag }}</span>
          {% endfor %}
        </div>
      </div>
      <div class="hub-study-action">
        {% if cs.published %}
        <a class="button primary-button" href="{{ cs.url | relative_url }}">
          Read case study <i class="fas fa-arrow-right" aria-hidden="true"></i>
        </a>
        {% else %}
        <span class="button disabled-button" aria-disabled="true">
          <i class="far fa-clock" aria-hidden="true"></i> Forthcoming
        </span>
        {% endif %}
      </div>
    </article>
    {% endfor %}
  </div>
</section>

<section class="docs-help">
  <div class="container">
    <div>
      <p class="kicker">Conduct Your Own Research</p>
      <h2>Run custom studies with FirmwareDroid.</h2>
      <p>FirmwareDroid is designed for repeatability and automated analysis. Deploy the Docker Compose stack to inspect firmware images and extract pre-installed applications.</p>
    </div>
    <div>
      <a class="button primary-button" href="{{ '/documentation/' | relative_url }}"><i class="fas fa-book-open"></i> Read documentation</a>
      <a class="button ghost-button" href="https://github.com/FirmwareDroid/FirmwareDroid" target="_blank" rel="noopener"><i class="fab fa-github"></i> View GitHub</a>
    </div>
  </div>
</section>
