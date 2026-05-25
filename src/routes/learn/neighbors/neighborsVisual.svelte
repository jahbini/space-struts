<script>
  // A vertex (gold) with its full nearest-neighbour star: 30 short (green) and
  // 30 long (blue) candidate sites, reached by translation.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';
  import { seenAction, glyph } from '$lib/seenViz.js';

  export let vi = 0, show3D = false;

  const geo = new GeoPhi();
  const star = geo.neighborStar;
  const dod = geo.Polyhedra.Dodecahedron1;
  const disp = (v) => v.sixPhiToCartesianDisplay();

  $: vc = dod[vi].sixPhiToCartesianDisplay();
  $: sceneData = { vc };

  const S = 80;
  const draw = (seen, model, d) => {
    if (!d || !d.vc) return;
    model.add(glyph(seen, [0, 0, 0], '#cccccc', 3, S));
    for (const s of star) {
      const o = [s.offset.x.toFloat(), s.offset.y.toFloat(), s.offset.z.toFloat()];
      const p = [d.vc[0] + o[0], d.vc[1] + o[1], d.vc[2] + o[2]];
      model.add(glyph(seen, p, s.lenClass === 's' ? '#2a7d2a' : '#5b8def', 5, S));
    }
    model.add(glyph(seen, d.vc, '#b8860b', 11, S));
  };
  const act = seenAction({ draw, cameraZ: -900 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>vertex (gold) + 30 short (green) + 30 long (blue) neighbours — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
