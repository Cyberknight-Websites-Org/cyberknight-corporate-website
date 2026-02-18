---
layout: docs-index
title: Documentation
permalink: /docs/
---

Guides and tutorials for using your council website and the Cyberknight Secure Portal.

## Getting Started

{% assign section_docs = site.documentation | where: "section", "getting-started" %}
{% for doc in section_docs %}
<div class="doc-item">
  <h3><a href="{{ doc.url | relative_url }}">{{ doc.title }}</a></h3>
  {% if doc.description %}<p>{{ doc.description }}</p>{% endif %}
</div>
{% endfor %}

## Flyers

{% assign section_docs = site.documentation | where: "section", "flyers" %}
{% for doc in section_docs %}
<div class="doc-item">
  <h3><a href="{{ doc.url | relative_url }}">{{ doc.title }}</a></h3>
  {% if doc.description %}<p>{{ doc.description }}</p>{% endif %}
</div>
{% endfor %}
