<script>
  // The chosen edge (gold endpoints, dark edge) plus every candidate apex that
  // completes a golden triangle (gold) or golden gnomon (green), with the tile
  // edges drawn faintly.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';
  import { seenAction, glyph, seg } from '$lib/seenViz.js';

  export let vi = 0, ni = 0, show3D = false;

  const geo = new GeoPhi();
  const dod = geo.Polyhedra.Dodecahedron1;
  const disp = (v) => v.sixPhiToCartesianDisplay();
  const dist = (a, b) => { const p = disp(a), q = disp(b); return Math.hypot(p[0]-q[0], p[1]-q[1], p[2]-q[2]); };

  $: v1 = dod[vi];
  $: nbrs = dod.filter((w) => w !== v1).map((w) => ({ w, d: dist(v1, w) }))
              .sort((a, b) => a.d - b.d).slice(0, 3).map((o) => o.w);
  $: v2 = nbrs[ni % nbrs.length];
  $: sceneData = v2 ? {
    v1c: disp(v1), v2c: disp(v2),
    cands: geo.goldenApexCandidates(v1, v2).map((c) => ({
      cart: [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()], kind: c.kind
    }))
  } : null;

  const S = 110;
  const draw = (seen, model, d) => {
    if (!d) return;
    model.add(seg(seen, d.v1c, d.v2c, '#333333', S));
    model.add(glyph(seen, d.v1c, '#b8860b', 9, S));
    model.add(glyph(seen, d.v2c, '#b8860b', 9, S));
    for (const c of d.cands) {
      const col = c.kind === 'golden' ? '#b8860b' : '#2a7d2a';
      model.add(seg(seen, d.v1c, c.cart, col, S));
      model.add(seg(seen, d.v2c, c.cart, col, S));
      model.add(glyph(seen, c.cart, col, 6, S));
    }
  };
  const act = seenAction({ draw, cameraZ: -700 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>edge + golden (gold) & gnomon (green) apex candidates — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
