---
layout: docs-index
title: Documentation
permalink: /docs/
---

Guides and tutorials for using your council website and the Cyberknight Secure Portal.

{% for section in site.data.doc_sections %}
<h2 id="{{ section.id }}">{{ section.title }}</h2>

{% assign section_docs = site.documentation | where: "section", section.id %}
{% for doc in section_docs %}
<div class="doc-item">
  <h3><a href="{{ doc.url | relative_url }}">{{ doc.title }}</a></h3>
  {% if doc.description %}<p>{{ doc.description }}</p>{% endif %}
</div>
{% endfor %}
{% endfor %}
