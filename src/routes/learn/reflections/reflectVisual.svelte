<script>
  // Left-column visual: the mirror plane with the original (gold) and reflected
  // (green) points, drawn large with seen.js. Driven by the picker state from
  // the page. Always mounted (so seen stays initialized); parked off-screen via
  // CSS when show3D is false. seen binds to the canvas element via an action.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';
  import '$lib/seen.m.coffee'; // side-effect: sets window.seen

  export let s0 = 'z', s1 = 'O', s2 = 'F', plane = 'A', show3D = false;

  const PHI = (1 + Math.sqrt(5)) / 2;
  const normals = {
    A: [PHI, 1, 0], B: [PHI, -1, 0], C: [1, 0, PHI],
    D: [-1, 0, PHI], E: [0, PHI, 1], F: [0, PHI, -1]
  };

  $: code = s0 + s1 + s2;
  $: base = GeoPhi.createPhiPoint('#' + code);
  $: reflected = GeoPhi.createPhiPoint('#' + code + '~' + plane);
  $: sceneData = base && reflected
    ? { base: base.sixPhiToCartesianDisplay(), reflected: reflected.sixPhiToCartesianDisplay(), normal: normals[plane] }
    : null;

  const unit = (a) => { const m = Math.hypot(...a) || 1; return a.map((x) => x / m); };
  const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
  const perp = (n) => unit(Math.abs(n[0]) < 0.9 ? cross(n, [1, 0, 0]) : cross(n, [0, 1, 0]));
  const S = 130;

  function seenCanvas(node, data) {
    let ctx, model, scene;
    const glyph = (seen, p, color, sz) => {
      const t = seen.Shapes.tetrahedron();
      t.scale(sz); t.translate(p[0]*S, p[1]*S, p[2]*S);
      t.fill(new seen.Material(seen.Colors.hex(color)));
      return t;
    };
    function draw(d) {
      const seen = window.seen;
      if (!seen || !model || !d || !d.base) return;
      model.children = [];
      const n = unit(d.normal), u = perp(n), v = cross(n, u), r = 1.6;
      const corner = (a, b) => seen.P((u[0]*a+v[0]*b)*r*S, (u[1]*a+v[1]*b)*r*S, (u[2]*a+v[2]*b)*r*S);
      const pl = seen.Shapes.path([corner(1,1), corner(-1,1), corner(-1,-1), corner(1,-1)]);
      pl.cullBackfaces = false;
      const pm = new seen.Material(seen.Colors.hex('#5b8def')); pm.a = 70;
      pl.fill(pm);
      model.add(pl);
      model.add(glyph(seen, [0,0,0], '#999999', 4));
      model.add(glyph(seen, d.base, '#b8860b', 10));
      model.add(glyph(seen, d.reflected, '#2a7d2a', 10));
      if (ctx) ctx.render();
    }
    function init() {
      const seen = window.seen;
      if (!seen) { setTimeout(init, 50); return; }
      model = seen.Models.default();
      model.cullBackfaces = false;
      scene = new seen.Scene({ model, viewport: seen.Viewports.center(node.width, node.height), cullBackfaces: false });
      scene.camera.translate(0, 0, -600);
      ctx = seen.Context(node, scene);
      const drag = new seen.Drag(node, { inertia: true });
      drag.on('drag.rotate', (e) => {
        const xf = seen.Quaternion.xyToTransform(...e.offsetRelative);
        model.transform(xf); ctx.render();
      });
      draw(data);
    }
    init();
    return { update(d) { data = d; draw(d); } };
  }
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:seenCanvas={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>#{code} → #{code}~{plane} — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
