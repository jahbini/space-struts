# Seen.js in this project

`src/lib/seen.m.coffee` is themadcreator's **Seen.js** — a lightweight 3-D
engine that renders to **SVG or `<canvas>`** (no WebGL). It's the project's
native 3-D tool. Prefer it over three.js.

## Importing & the `window.seen` global

The module ends with `if window? then window.seen = seen`. So you import it for
its **side-effect** and then use the global:

```js
import '$lib/seen.m.coffee';   // sets window.seen
// ...later, in browser code:
const seen = window.seen;
if (!seen) { setTimeout(retry, 50); return; }   // guard: may not be ready yet
```

Pages that use it set `export const ssr = false;` in `+page.js` (it's
browser-only).

## Binding to a DOM node, not just an id

`seen.Util.element(x)` accepts **a string id _or_ a DOM element** (seen.m.coffee
~line 57). This is important: pass the **element** so the renderer survives the
node being moved/recreated by Svelte (e.g. inside a `Floater`, or toggled
visibility). Bind via a Svelte `use:` action:

```js
function seenCanvas(node, data) {           // node = the <canvas>
  let ctx, model, scene;
  function init() {
    const seen = window.seen;
    if (!seen) { setTimeout(init, 50); return; }
    model = seen.Models.default();
    model.cullBackfaces = false;
    scene = new seen.Scene({ model,
      viewport: seen.Viewports.center(node.width, node.height),
      cullBackfaces: false });
    scene.camera.translate(0, 0, -600);     // negative z = move camera back
    ctx = seen.Context(node, scene);        // <-- pass the ELEMENT
    const drag = new seen.Drag(node, { inertia: true });
    drag.on('drag.rotate', (e) => {
      const xf = seen.Quaternion.xyToTransform(...e.offsetRelative);
      model.transform(xf); ctx.render();
    });
    draw(data);
  }
  function draw(d) { /* rebuild model.children, then ctx.render() */ }
  init();
  return { update(d) { data = d; draw(d); } };  // re-draw on prop change
}
```

```svelte
<canvas use:seenCanvas={sceneData} width="520" height="520"></canvas>
```

The canvas `width`/`height` **attributes** are the bitmap size (what
`Viewports.center(node.width, node.height)` uses). Scale the *display* with CSS
(`width:100%; max-width:520px; height:auto`).

## API cheat-sheet (verified against seen.m.coffee)

| Thing | Call | Notes |
|---|---|---|
| Point/vector | `seen.P(x,y,z)` | `.copy/.add/.subtract/.divide/.scale` |
| Model | `seen.Models.default()` / `new seen.Model()` | `.add`, `.children=[]` to clear, `.scale`, `.translate`, `.transform(xf)`, `.remove` |
| Scene | `new seen.Scene({model, viewport, cullBackfaces})` | `scene.camera.translate(x,y,z)` |
| Viewport | `seen.Viewports.center(w=500,h=500,x=0,y=0)` | |
| Context | `seen.Context(elOrId, scene)` → `ctx.render()` | picks Svg vs Canvas by tagName |
| Drag | `new seen.Drag(elOrId,{inertia:true})` | `.on('drag.rotate', e => …)` |
| Rotate | `seen.Quaternion.xyToTransform(x, y)` | feed `...e.offsetRelative` |
| Material | `new seen.Material(seen.Colors.hex('#rrggbb'))` | **alpha lives on `mat.color.a`, not `mat.a`** — see Gotchas |
| Color | `seen.Colors.hex('#rrggbb')` / `seen.C(r,g,b,a)` | |
| Shapes | `seen.Shapes.tetrahedron()`, `.cube()`, `.icosahedron()`, `.sphere(subdiv)`, `.pyramid()`, `.text(str,opts)` | tetra fits a 2×2×2 cube |
| **Path/polygon** | `seen.Shapes.path([p1,p2,p3,p4])` | **takes an ARRAY** of points, not varargs |
| Shape ops | `shape.scale(n)`, `.translate(x,y,z)`, `.fill(mat)`, `.stroke(mat)`, `.cullBackfaces`, `.surfaces[0].fillMaterial`, `.surfaces[0]["stroke-width"]` | |

### Gotchas that cost time
- **`Shapes.path` takes an array.** The `explore/playground` `pointFrame()` calls
  it with spread (`path ...points`) and is wrong/dead; `wireframe()` passes an
  array and is the working one.
- **`window.seen` may be undefined on first tick** — always guard with a
  `setTimeout` retry (the playground does `if !seen then setTimeout onMount,50`).
- **Material alpha lives on `mat.color.a`, NOT `mat.a`.** Setting `mat.a = 0x80`
  silently does nothing — render shading reads `@color.a`
  (`seen.m.coffee` ~L812: `color.a = @color.a` inside `Material::render`).
  And `seen.Colors.hex('#rrggbb')` constructs a Color without alpha, defaulting
  to `0xFF` (opaque). To get a 50%-transparent fill:
  ```coffee
  c = seen.Colors.hex('#d4af37')
  c.a = 0x80                          # set alpha on the COLOR
  mat = new seen.Material(c)
  path.fill mat
  ```
  Or use `seen.C(r, g, b, a)` which takes alpha as the 4th arg.
- **Backface culling requires consistent winding.** `cullBackfaces = true` on a
  path culls when the projected normal's z ≥ 0 (model-space outward normal
  pointing toward camera survives). If your triangle source sorts/randomises
  vertex order (e.g. `geoPhi.createTriangle` sorts the path), half your
  triangles will be wound the wrong way and get culled when they shouldn't.
  Re-orient explicitly before rendering: compute `(b-a)×(c-a)` and flip
  `[a,c,b]` when the dot with the outward direction is negative. Example in
  `src/routes/explore/teapot/+page.svelte` (`orientOutward`).
- **`scene.cullBackfaces` and `surface.cullBackfaces` AND together** (with
  normal.z). Render keeps a surface when `(!scene.cullBackfaces ||
  !surface.cullBackfaces || normal.z < 0)`. So leaving the scene flag on but
  setting `surface.cullBackfaces = false` per shape is the way to mix culled
  panels with see-through ones (e.g. golden hull culled, teapot mesh not).
- Working example to copy: `src/routes/explore/playground/+page.svelte`
  (CoffeeScript). It does Scene + Viewport + Context + Drag + wireframes.
- A glyph at a point: `seen.Shapes.tetrahedron()` → `.scale(sz)` → `.translate(x,y,z)`
  → `.fill(material)`.
