# Image Pop-up (Lightbox) Feature

This document describes in full detail the image pop-up/lightbox feature used on this Jekyll site. It is intended for another agent to replicate the feature in a separate repository.

---

## Overview

When a user clicks on a designated image, it opens in a fullscreen modal (lightbox) with a dark backdrop. If the image belongs to an ordered gallery, the user can navigate between images using left/right arrow buttons or keyboard arrow keys. The dialog can be closed with a close button, the Escape key, or by clicking outside the image.

The feature is implemented with:
- A reusable Jekyll include (`_includes/image_dialog.html`) containing the HTML dialog element and all JavaScript logic
- A SCSS file (`_sass/dialog.scss`) for styling
- CSS classes and HTML data attributes applied to images in the various layouts

---

## Files to Copy

### 1. `_includes/image_dialog.html` — **MUST COPY**

This is the core of the feature. It contains both the `<dialog>` HTML and the `<script>` tag with all JavaScript logic.

**Full contents:**

```html
<script>
  window.addEventListener("load", dialogButtonInitializer);

  function dialogButtonInitializer() {
    const all_pictures = document.querySelectorAll("picture");
    const all_lightbox_images = document.querySelectorAll(
      ".announcement-img-lightbox",
    );
    const dialog = document.querySelector("dialog");
    const dialogContent = document.getElementById("img-dialog-content");
    const closeButton = document.getElementById("img-dialog-close");
    const prevButton = document.getElementById("img-dialog-prev");
    const nextButton = document.getElementById("img-dialog-next");
    const body = document.querySelector("body");

    var isDesktop = window.matchMedia("(min-width: 800px) and (orientation: landscape) and (hover: hover) and (pointer: fine)");
    let currentImageOrder = null;
    let galleryImages = Array.from(all_lightbox_images).filter(img => img.hasAttribute('data-image-order'));

    // Function to update arrow button visibility
    function updateArrowVisibility() {
      const shouldShowArrows = isDesktop.matches && galleryImages.length > 1;
      prevButton.style.display = shouldShowArrows ? "flex" : "none";
      nextButton.style.display = shouldShowArrows ? "flex" : "none";
    }

    // Function to show image by order
    function showImageByOrder(order) {
      const targetImage = galleryImages.find(img => img.getAttribute("data-image-order") === order.toString());
      if (targetImage) {
        const fullImageUrl = targetImage.getAttribute("data-full-image") || targetImage.src;
        const imgHtml = `<img src="${fullImageUrl}" alt="Full size image">`;
        dialogContent.innerHTML = imgHtml;
        currentImageOrder = order;
      }
    }

    // Function to navigate to previous image
    function navigatePrevious() {
      if (currentImageOrder === null || galleryImages.length <= 1) return;

      const orders = galleryImages.map(img => parseInt(img.getAttribute("data-image-order"))).sort((a, b) => a - b);
      const currentIndex = orders.indexOf(currentImageOrder);
      const previousIndex = currentIndex === 0 ? orders.length - 1 : currentIndex - 1;
      showImageByOrder(orders[previousIndex]);
    }

    // Function to navigate to next image
    function navigateNext() {
      if (currentImageOrder === null || galleryImages.length <= 1) return;

      const orders = galleryImages.map(img => parseInt(img.getAttribute("data-image-order"))).sort((a, b) => a - b);
      const currentIndex = orders.indexOf(currentImageOrder);
      const nextIndex = currentIndex === orders.length - 1 ? 0 : currentIndex + 1;
      showImageByOrder(orders[nextIndex]);
    }

    // Handle announcement-img-lightbox class images (including those inside pictures)
    all_lightbox_images.forEach((img) => {
      img.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation(); // Prevent picture click event from triggering

        if (img.hasAttribute('data-image-order')) {
          // Handle images with gallery navigation
          const order = parseInt(img.getAttribute("data-image-order"));
          currentImageOrder = order;
          showImageByOrder(order);
        } else {
          // Handle individual images without gallery navigation
          const fullImageUrl = img.getAttribute("data-full-image") || img.src;
          const imgHtml = `<img src="${fullImageUrl}" alt="Full size image">`;
          dialogContent.innerHTML = imgHtml;
          currentImageOrder = null;
        }

        dialog.showModal();
        body.style.overflow = "hidden";
        updateArrowVisibility();
      });
    });

    // Handle regular picture elements (only those that don't contain lightbox images)
    all_pictures.forEach((openDialogButton) => {
      openDialogButton.addEventListener("click", (event) => {
        // Skip if the click was on a lightbox image
        if (event.target.classList.contains("announcement-img-lightbox")) {
          return;
        }

        // Copy the contents of the clicked picture into the dialog content
        let htmlContent = event.target.outerHTML;
        htmlContent = htmlContent
          .replace(/max-height: 60vh/g, "")
          .replace(/border-radius: 1rem;/g, "");
        dialogContent.innerHTML = htmlContent;

        dialog.showModal();
        body.style.overflow = "hidden";
      });
    });

    // Handle close button click
    closeButton.addEventListener("click", () => {
      dialog.close();
      body.style.overflow = "";
    });

    // Handle arrow button clicks
    prevButton.addEventListener("click", (event) => {
      event.stopPropagation();
      navigatePrevious();
    });
    nextButton.addEventListener("click", (event) => {
      event.stopPropagation();
      navigateNext();
    });

    // Handle keyboard navigation
    document.addEventListener("keydown", (event) => {
      if (!dialog.open) return;

      if (event.key === "ArrowLeft") {
        event.preventDefault();
        navigatePrevious();
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        navigateNext();
      } else if (event.key === "Escape") {
        event.preventDefault();
        dialog.close();
        body.style.overflow = "";
      }
    });

    // Update arrow visibility on resize/orientation change
    isDesktop.addEventListener("change", updateArrowVisibility);

    dialog.addEventListener("click", (event) => {
      const dialogDimensions = dialog.getBoundingClientRect();
      if (
        event.clientX < dialogDimensions.left ||
        event.clientX > dialogDimensions.right ||
        event.clientY < dialogDimensions.top ||
        event.clientY > dialogDimensions.bottom
      ) {
        dialog.close();
        body.style.overflow = "";
      }
    });
  }
</script>

<dialog id="img-dialog">
  <button
    id="img-dialog-close"
    style="
      position: fixed;
      top: 1rem;
      right: 1rem;
      width: 3rem;
      height: 3rem;
      background: white;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
    "
  >
    <img
      src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/xmark.svg"
      alt="Close"
      style="width: 2rem; height: 2rem"
    />
  </button>
  <button
    id="img-dialog-prev"
    style="
      position: fixed;
      left: 1rem;
      top: 50%;
      transform: translateY(-50%);
      width: 3rem;
      height: 3rem;
      background: white;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
    "
  >
    <img
      src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/chevron-left.svg"
      alt="Previous"
      style="width: 2rem; height: 2rem"
    />
  </button>
  <button
    id="img-dialog-next"
    style="
      position: fixed;
      right: 1rem;
      top: 50%;
      transform: translateY(-50%);
      width: 3rem;
      height: 3rem;
      background: white;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
    "
  >
    <img
      src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/chevron-right.svg"
      alt="Next"
      style="width: 2rem; height: 2rem"
    />
  </button>
  <div id="img-dialog-content"></div>
</dialog>
```

**Key elements:**
- The `<dialog id="img-dialog">` element is the native HTML5 modal container. It is opened with `.showModal()` and closed with `.close()`.
- Three circular white buttons (close, prev, next) are positioned `fixed` inside the dialog so they always stay in the corners/sides of the viewport.
- Button icons are loaded directly from the Font Awesome GitHub raw CDN — no npm package or font library is required.
- `#img-dialog-content` is an empty `<div>` that gets populated dynamically with an `<img>` tag when the user clicks an image.
- `dialogButtonInitializer()` is the initialization function. It must be called after the DOM is ready.

---

### 2. `_sass/dialog.scss` — **MUST COPY**

This file must be placed in your `_sass/` directory and imported in your main stylesheet.

**Full contents:**

```scss
#img-dialog {
  z-index: 10;
  padding: 0rem;
  margin: auto;
  background: none;
  border: none;
  border-radius: none;
  min-height: 9rem;
  animation: popin 0.3s;
  min-width: 300px;
  width: 95%;
  max-width: 1200px;
}
#img-dialog::backdrop {
  background: rgba(0, 0, 0, 0.8);
  animation: fadein_onlyopacity 0.2s ease-out;
}

#img-dialog-content{
  display: flex;
  justify-content: center;
  align-items: center;

  img {
    /* max-width: 90vw; */
    max-height: 90vh;
    border-radius: 0.5rem;
    border: none;
    animation: none;
    height: auto;
  }
  img:hover {
    cursor: default;
  }
}

// Styles for announcement image lightbox
.announcement-img-lightbox {
  cursor: pointer;
}

@keyframes popin {
  from {
    transform: scale(0);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes fadein_onlyopacity {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
```

**Key notes:**
- The `::backdrop` pseudo-element creates the dark semi-transparent overlay behind the dialog.
- `animation: none` on `#img-dialog-content img` prevents any global image animation styles from firing on the lightbox image.
- `.announcement-img-lightbox` is the CSS class that marks images as clickable — it only adds `cursor: pointer`.
- The `popin` keyframe animates the dialog scaling up from nothing, and `fadein_onlyopacity` fades in the backdrop.

---

## How to Wire It Up

### Step 1: Include the dialog in your layout

In your base layout file (e.g., `_layouts/default.html`), include the dialog HTML inside the `<body>`:

```html
{% include image_dialog.html %}
```

Place this early in the body, before the main page content. In this repository it is placed right before the top navigation bar.

### Step 2: Import the SCSS

In your main stylesheet (e.g., `assets/css/main.scss`), add:

```scss
@import "dialog";
```

Order does not matter much, but it should be alongside other component imports.

### Step 3: Call `dialogButtonInitializer()` after the DOM loads

The include file registers `dialogButtonInitializer` on the `window` `"load"` event. However, if your site uses client-side routing or deferred rendering, you may need to call it manually on `DOMContentLoaded` as well.

In this repository, `default.html` does this inside a `<script>` tag in the `<head>`:

```js
function onNavigateOrLoad() {
  // ... other init calls ...

  // Initialize image lightbox for relevant pages
  if (
    relativeUrl.includes("/announcements/") ||
    relativeUrl === "/members" ||
    relativeUrl === "/members/" ||
    relativeUrl.includes("/posts/")
  ) {
    setTimeout(dialogButtonInitializer, 50);
  }
}

document.addEventListener("DOMContentLoaded", onNavigateOrLoad);
```

> **Important:** The `setTimeout(..., 50)` delay gives the DOM time to fully render before the initializer runs. Without it, `querySelectorAll` may return empty results on some pages.

If you want the lightbox active on all pages, simplify to:

```js
document.addEventListener("DOMContentLoaded", () => {
  setTimeout(dialogButtonInitializer, 50);
});
```

---

## How to Make an Image Lightbox-Enabled

Any image that should open in the lightbox needs:

1. The CSS class `announcement-img-lightbox`
2. Optionally, a `data-full-image` attribute pointing to the full-resolution version (if the `src` is a thumbnail)
3. Optionally, a `data-image-order` attribute (integer) to enable gallery navigation

### Single image (no navigation arrows):

```html
<img
  class="announcement-img-lightbox"
  src="{{ image.thumbnail_url }}"
  alt="Description"
  data-full-image="{{ image.original_url }}"
/>
```

When clicked, the dialog opens showing the `data-full-image` URL. No navigation arrows appear.

### Gallery image (with navigation arrows):

```html
<img
  class="announcement-img-lightbox"
  src="{{ image.thumbnail_url }}"
  alt="Description"
  data-full-image="{{ image.original_url }}"
  data-image-order="{{ forloop.index }}"
/>
```

All images on the page with `data-image-order` form a single gallery. The JavaScript sorts them by their order value and enables previous/next navigation. Navigation arrows only appear on desktop (min-width 800px, landscape, hover-capable pointer device) and only when there is more than one gallery image.

### Image inside a `<picture>` element (automatic support):

Any `<picture>` element that does **not** contain a `.announcement-img-lightbox` image is also made clickable automatically. Clicking it opens the `<img>` inside the picture in the dialog, stripping inline `max-height: 60vh` and `border-radius: 1rem` styles for the full-size view.

---

## Behavior Details

| Action | Result |
|---|---|
| Click `.announcement-img-lightbox` image | Opens dialog with full-size image |
| Click `<picture>` element (without lightbox class) | Opens dialog with that image |
| Click close button | Closes dialog, restores scroll |
| Press Escape | Closes dialog, restores scroll |
| Click outside the dialog | Closes dialog, restores scroll |
| Press ArrowLeft | Navigate to previous gallery image |
| Press ArrowRight | Navigate to next gallery image |
| Click prev/next button | Navigate to previous/next gallery image |
| Resize to mobile / portrait | Navigation arrows are hidden |

- While the dialog is open, `body.style.overflow = "hidden"` prevents the page from scrolling behind the modal.
- Navigation wraps around: pressing previous on the first image goes to the last, and vice versa.
- `data-full-image` is always preferred over `src`. If neither is present, the image will still show but may be a thumbnail.

---

## Usage Examples in This Repository

### Post gallery (ordered, navigable)

In `_layouts/post.html`:

```html
<div class="post-gallery-grid">
  {% for image in page.post_images %}
    <div class="post-gallery-item">
      <picture>
        <img
          class="post-gallery-thumbnail announcement-img-lightbox"
          src="{{ image.thumbnail_url }}"
          alt="{{ image.alt_text }}"
          data-full-image="{{ image.original_url }}"
          data-image-order="{{ image.order }}"
          style="height: 11rem; width: auto; object-fit: cover"
        />
      </picture>
      {% if image.caption %}<p class="post-gallery-caption">{{ image.caption }}</p>{% endif %}
    </div>
  {% endfor %}
</div>
```

### Announcement attachments (individual, no navigation)

In `_layouts/announcement.html`:

```html
<img
  src="{{ display_url }}"
  alt="Announcement attachment"
  class="attachment-image announcement-img-lightbox"
  data-full-image="{{ full_url }}"
/>
```

### Event flyer (single image)

In `_layouts/event.html`:

```html
<picture style="margin: auto 0rem;">
  <img
    class="event-flyer-image announcement-img-lightbox"
    src="{{ page.event_flyer.thumbnail_url | default: page.event_flyer.original_url }}"
    alt="{{ page.event_flyer.alt_text | default: 'Event flyer' }}"
    data-full-image="{{ page.event_flyer.original_url | default: page.event_flyer.thumbnail_url }}"
    style="height: auto; max-width: 70vw"
  />
</picture>
```

### Officer portraits (ordered, navigable)

In `_layouts/members.html`:

```html
<picture>
  <img
    class="portrait announcement-img-lightbox"
    src="{{ thumbnail_src }}"
    alt="A headshot of {{ officer.officer_position }} {{ officer.officer_name }}"
    data-full-image="{{ original_src }}"
    data-image-order="{{ forloop.index }}"
  />
</picture>
```

---

## External Dependencies

The only external resource is Font Awesome SVG icons loaded directly from the Font Awesome GitHub repository at a pinned commit:

```
https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/xmark.svg
https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/chevron-left.svg
https://raw.githubusercontent.com/FortAwesome/Font-Awesome/a1232e34553634c5363aa62c8d1b02161a4438e1/svgs/solid/chevron-right.svg
```

These are hardcoded into `_includes/image_dialog.html`. No npm install, no CDN link tag in `<head>`, no Font Awesome account needed.

If you want to self-host the icons instead, download those three SVG files and adjust the `src` attributes accordingly.

---

## Summary Checklist

To replicate this feature in another repository:

- [ ] Copy `_includes/image_dialog.html` to the target repo's `_includes/` directory
- [ ] Copy `_sass/dialog.scss` to the target repo's `_sass/` directory
- [ ] Add `@import "dialog";` to the target repo's main SCSS file
- [ ] Add `{% include image_dialog.html %}` somewhere inside `<body>` in the base layout
- [ ] Call `dialogButtonInitializer()` after the DOM is ready (either via the `window "load"` event already in the include, or explicitly on `DOMContentLoaded`)
- [ ] Add `class="announcement-img-lightbox"` to any image that should open in the lightbox
- [ ] Optionally add `data-full-image="<url>"` to point to a higher-resolution version
- [ ] Optionally add `data-image-order="<integer>"` to images that belong to a navigable gallery
