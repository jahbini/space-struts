# Floater & the lesson-visual pattern

## `Floater.svelte`

`src/lib/Floater.svelte` is a slot wrapper that shows content as a small
**2-inch thumbnail**, and **expands to a full-screen overlay** when clicked.

```svelte
<Floater><AnyContent /></Floater>
```

- Small view: `.floater-small` (2in × 2in, dark, `cursor:pointer`, click to open).
- Expanded: `.floater-expanded` (fixed, 90vw × 85vh, z-9999, ✖ close button,
  **Esc** to close, **double-click** to close).
- Implementation: it renders the `<slot/>` inside *either* the small or the
  expanded `<div>` via `{#if isExpanded}`.

### Caveat
Because the slot lives in two `{#if}` branches, expanding/collapsing can move (or
recreate) the slotted DOM. A live `seen` canvas inside a Floater must therefore
bind by **element** (a `use:` action), never by id, or it gets stranded. See
[`seen.md`](seen.md).

**For lesson visuals we ended up NOT using Floater** (see below) — the chosen
pattern shows the canvas large directly and hides it off-screen. Floater is still
the right tool when you want a small inline preview that pops to fullscreen.

## The approved lesson-visual pattern ✅

This is the agreed style for **every learn page with a visual**. Reference
implementation: `src/routes/learn/reflections/`. **All seven lessons now use it.**

**Shared helper:** `src/lib/seenViz.js` exports `seenAction({draw, cameraZ})`
(the canvas `use:` action), plus `glyph`, `seg`, `poly`, and `unit/cross/perp`.
Each `…Visual.svelte` just supplies a `draw(seen, model, data)` and a reactive
`sceneData`. (The original `reflections/reflectVisual.svelte` predates the helper
and inlines the same logic — fine to leave, or refactor to the helper.)

**Three parts:**

1. **Calc panel** (sidebar) — `reflect.svelte`. A sticky, right-floated control
   panel. Exports its state as **bindable props**, including a `show3D` toggle:
   ```svelte
   <script>
     export let s0='z', s1='O', s2='F', plane='A', show3D=false;
   </script>
   <label class="toggle"><input type="checkbox" bind:checked={show3D}/> show 3-D</label>
   ```
   ```css
   .phi-calc { float:right; position:sticky; top:1rem; width:290px;
               max-height:calc(100vh - 2rem); overflow:auto; … }
   ```

2. **Visual** (left column) — `reflectVisual.svelte`. A **large** seen canvas,
   **always mounted** (so `seen` stays initialized), driven by the picker props.
   When hidden it is **parked off-screen**, not unmounted:
   ```svelte
   <figure class="visual" class:hidden={!show3D}>
     <canvas use:seenCanvas={sceneData} width="520" height="520" class="seen"></canvas>
   </figure>
   ```
   ```css
   .visual.hidden { position:absolute; left:-99999px; top:0; }   /* off-screen, not display:none */
   canvas.seen { width:100%; max-width:520px; height:auto; }
   ```

3. **Page** (`+page.svx`) — holds the shared state and wires both:
   ```svelte
   <script>
     import ReflectCalc from './reflect.svelte';
     import ReflectVisual from './reflectVisual.svelte';
     let s0='z', s1='O', s2='F', plane='A', show3D=false;
   </script>
   <ReflectCalc bind:s0 bind:s1 bind:s2 bind:plane bind:show3D />
   <ReflectVisual {s0} {s1} {s2} {plane} {show3D} />
   ```
   The visual is rendered **unconditionally** (no `{#if}`) — `show3D` only flips
   the off-screen CSS class, so toggling never re-initializes `seen`.

### Why off-screen instead of `{#if}` / `display:none`
Unmounting (`{#if}`) destroys the canvas and strands the `seen` context;
`display:none` can zero the canvas size. Parking it at `left:-99999px` keeps the
node alive and sized, so the toggle is instant and `seen` stays warm. (Jim
explicitly asked for "move it off screen when hidden.")

### Page text layout (so the floated calc never covers text)
In `+page.svx`, reserve a right gutter on the markdown blocks (mdsvex here won't
parse markdown inside a wrapper `<div>`, so use scoped element styles):
```css
h1,h2,p,pre { margin-right: 320px; }
@media (max-width: 820px) { h1,h2,p,pre { margin-right: 0; } }  /* drop on narrow */
```
The calc's own CSS also drops `float/sticky` under 820px.

### Working framing values (reflections)
`S=130` (cartesian→screen scale), `camera.translate(0,0,-600)`, canvas bitmap
`520×520`, point glyphs `tetrahedron().scale(10)`, origin `.scale(4)`. These
looked right to Jim — reuse as a starting point and adjust per scene.
