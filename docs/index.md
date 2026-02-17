---
layout: page
title: Documentation
permalink: /docs/
---

<div class="docs-list" markdown="1">

## Getting Started

Welcome to the Cyberknight Websites documentation. Here you'll find guides and tutorials for using your council website and the Cyberknight Secure Portal.

---

### Available Guides

{% for doc in site.documentation %}
<div class="doc-item">
  <h3><a href="{{ doc.url | relative_url }}">{{ doc.title }}</a></h3>
  {% if doc.description %}<p>{{ doc.description }}</p>{% endif %}
</div>
{% endfor %}

</div>
