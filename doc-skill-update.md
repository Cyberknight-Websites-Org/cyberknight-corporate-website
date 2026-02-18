# Documentation Skill — Required Front Matter Updates

The `_documentation/` collection files now require two additional front matter fields:
`section` and `description`. Any skill that creates or edits documentation markdown
files must include these fields.

---

## What Changed

Two front matter fields were added to every file in `_documentation/`:

| Field | Purpose |
|---|---|
| `section` | Groups the document under a named section on the `/docs/` index page |
| `description` | One-sentence summary displayed inside the doc card on the `/docs/` index page |

---

## New Front Matter Format

### Before

```yaml
---
layout: doc
title: Some Guide Title
permalink: /docs/some-guide/
---
```

### After

```yaml
---
layout: doc
title: Some Guide Title
permalink: /docs/some-guide/
section: getting-started
description: A one-sentence summary of what this guide covers.
---
```

---

## The `section` Field

The `section` value determines which section heading the doc card appears under on
the `/docs/` index page. The index page reads all sections from a data file
(`_data/doc_sections.yml`) and loops through `site.documentation` filtered by this
value using Liquid's `where` filter.

### `_data/doc_sections.yml`

Sections are defined in this YAML file in the corporate website repository. Each
entry has two keys:

```yaml
- id: getting-started
  title: Getting Started

- id: flyers
  title: Flyers
```

- `id` — the value used in the doc's `section:` front matter field
- `title` — the heading displayed on the `/docs/` index page

The `/docs/` index page loops over this file dynamically, so it never needs to be
edited manually when sections are added or changed. The data file alone controls
what sections exist and in what order they appear.

### Current valid `section` values

| Value | Section heading on `/docs/` |
|---|---|
| `getting-started` | Getting Started |
| `flyers` | Flyers |

### Adding a new section

To introduce a new section (e.g., `announcements`):

1. Add a new entry to `_data/doc_sections.yml` in the corporate website repository:
   ```yaml
   - id: announcements
     title: Announcements
   ```
2. Use the matching `id` as the `section:` value in the new doc's front matter.

The `/docs/` index page will pick it up automatically — no other file needs to be
edited. Any doc whose `section` value does not have a matching entry in
`_data/doc_sections.yml` will be silently omitted from the index.

---

## The `description` Field

This is a plain-text string (no markdown). It appears as a paragraph below the
guide title in the doc card on `/docs/`. It should be one sentence that tells the
reader what the guide covers.

**Guidelines:**
- Plain text only — no markdown formatting, no links
- One sentence, ending with a period
- Should describe what the guide does or covers, not just restate the title
- 20–40 words is a good target length

**Good example:**
```yaml
description: The Event Flyer Generator creates professional, AI-generated flyers for your events using the information already entered in the event form.
```

**Bad example (too vague, restates the title):**
```yaml
description: A guide about event flyers.
```

---

## Existing Files for Reference

### `_documentation/getting-started.md`

```yaml
---
layout: doc
title: Getting Started with Your Council Website
permalink: /docs/getting-started/
section: getting-started
description: A guide to getting started with your council website, covering the Secure Portal, creating events, publishing posts, managing members, and sending announcements.
---
```

### `_documentation/generating-event-flyers.md`

```yaml
---
layout: doc
title: Generating Event Flyers
permalink: /docs/generating-event-flyers/
section: flyers
description: The Event Flyer Generator creates professional, AI-generated flyers for your events using the information already entered in the event form.
---
```

---

## Summary Checklist for the Skill

When creating a new file in `_documentation/`:

- [ ] Include `section:` with one of the valid values from `_data/doc_sections.yml`
- [ ] Include `description:` as a plain-text, one-sentence summary (20–40 words)
- [ ] Do not use markdown or HTML inside the `description` value
- [ ] If a new section is needed, add it to `_data/doc_sections.yml` — do not edit
      `docs/index.md`
