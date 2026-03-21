# AEM Component DOM Rules

## Droppable Components

If a component's `.content.xml` has `componentGroup` set to anything other than `.hidden`, it is **droppable by authors** and CAN appear anywhere in the page DOM hierarchy:

- Direct child of page root parsys
- Inside experience fragments (header, footer, XF containers)
- Inside container components (mycomp-container, column control)
- Nested N levels deep inside any combination of the above

**Rule:** Never assume a specific DOM position for droppable components. Code that traverses the DOM (inert, focus trap, scroll lock, overlays, z-index stacking) must walk UP from the component to find the correct ancestor, not DOWN from body/document.

## Common Patterns

### Finding a body-child ancestor

When you need the top-level body child that contains a component (e.g., for `inert` management):

```javascript
let bodyChild = element;
while (bodyChild.parentElement && bodyChild.parentElement !== document.body) {
  bodyChild = bodyChild.parentElement;
}
// bodyChild is now the direct child of <body> that contains element
```

### Modal inert pattern

Set `inert` on body children that are NOT the ancestor containing the modal, not on all body children except the modal element itself:

```javascript
// CORRECT — works regardless of nesting depth
const bodyChildren = document.body.children;
let ancestor = modalElement;
while (ancestor.parentElement !== document.body) {
  ancestor = ancestor.parentElement;
}
Array.from(bodyChildren).forEach(child => {
  if (child !== ancestor) child.inert = true;
});

// WRONG — fails if modal is nested inside an XF or container
Array.from(bodyChildren).forEach(child => {
  if (child !== modalElement) child.inert = true;  // modalElement may not be a body child!
});
```

### Scroll lock

Lock scroll on `document.documentElement` or `document.body`, never on a parent element:

```javascript
// CORRECT
document.documentElement.style.overflow = 'hidden';

// WRONG — assumes component is a child of the scrolling element
this.parentElement.style.overflow = 'hidden';
```

### Focus trap

Scope focus trap queries to the component's own subtree, not to a hardcoded ancestor:

```javascript
// CORRECT — scoped to component
const focusable = this.querySelectorAll('a, button, input, [tabindex]');

// WRONG — assumes component is at a specific DOM level
document.body.querySelector('.modal-wrapper').querySelectorAll('...');
```

## Experience Fragment Context

Components rendered inside experience fragments (`/content/experience-fragments/`) are included via `<sly data-sly-resource>` in the page template. The XF content is injected into the page DOM at runtime, often wrapped in several `<div>` layers by the XF framework. A component inside an XF may be 5-15 levels deep from `<body>`.

**Never assume** the component's `parentElement` or `closest('body > *')` will return a meaningful container. Always walk up the tree explicitly.
