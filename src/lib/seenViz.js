// Shared Seen.js helpers for the learn/ lesson visuals.
// See GPT/seen.md and GPT/floater-and-visuals.md for the full pattern.
import '$lib/seen.m.coffee'; // side-effect: sets window.seen

// A Svelte action that drives a <canvas> with seen.js. `draw(seen, model, data)`
// rebuilds the model children; the action re-runs draw whenever the bound data
// changes. Binds to the canvas ELEMENT so it survives being moved/recreated.
export function seenAction({ draw, cameraZ = -600 }) {
  return (node, data) => {
    let ctx, model;
    function redraw(d) {
      const seen = window.seen;
      if (!seen || !model) return;
      model.children = [];
      draw(seen, model, d);
      if (ctx) ctx.render();
    }
    function init() {
      const seen = window.seen;
      if (!seen) { setTimeout(init, 50); return; }
      model = seen.Models.default();
      model.cullBackfaces = false;
      const scene = new seen.Scene({
        model, viewport: seen.Viewports.center(node.width, node.height), cullBackfaces: false
      });
      scene.camera.translate(0, 0, cameraZ);
      ctx = seen.Context(node, scene);
      const drag = new seen.Drag(node, { inertia: true });
      drag.on('drag.rotate', (e) => {
        const xf = seen.Quaternion.xyToTransform(...e.offsetRelative);
        model.transform(xf); if (ctx) ctx.render();
      });
      redraw(data);
    }
    init();
    return { update(d) { redraw(d); } };
  };
}

// a point glyph (small tetrahedron) at cartesian p, scaled by S
export const glyph = (seen, p, color, sz, S) => {
  const t = seen.Shapes.tetrahedron();
  t.scale(sz); t.translate(p[0] * S, p[1] * S, p[2] * S);
  t.fill(new seen.Material(seen.Colors.hex(color)));
  return t;
};

// a line segment a→b (cartesian, pre-scale)
export const seg = (seen, a, b, color, S) => {
  const p = seen.Shapes.path([seen.P(a[0]*S, a[1]*S, a[2]*S), seen.P(b[0]*S, b[1]*S, b[2]*S)]);
  p.cullBackfaces = false;
  p.stroke(new seen.Material(seen.Colors.hex(color)));
  return p;
};

// a translucent filled polygon from cartesian corners
export const poly = (seen, corners, color, alpha, S) => {
  const p = seen.Shapes.path(corners.map((c) => seen.P(c[0]*S, c[1]*S, c[2]*S)));
  p.cullBackfaces = false;
  const m = new seen.Material(seen.Colors.hex(color)); m.a = alpha;
  p.fill(m);
  return p;
};

// vector helpers
export const unit = (a) => { const m = Math.hypot(...a) || 1; return a.map((x) => x / m); };
export const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
export const perp = (n) => unit(Math.abs(n[0]) < 0.9 ? cross(n, [1, 0, 0]) : cross(n, [0, 1, 0]));
