<script>
  // The chosen point (gold) among the six golden basis directions (rays).
  import { PhiBase } from '$lib/coffee/phiBase.coffee';
  import { SixPhiVector } from '$lib/coffee/sixPhiVector.coffee';
  import { seenAction, glyph, seg, unit } from '$lib/seenViz.js';

  export let sx = 'z', sy = 'O', sz = 'F', show3D = false;

  const P = (a, b) => new PhiBase(a, b);
  const decode = { z: P(0,0), O: P(0,1), o: P(0,-1), f: P(-1,1), F: P(1,-1), p: P(-1,0), P: P(1,0) };
  const PHI = (1 + Math.sqrt(5)) / 2;
  const bases = [[PHI,1,0],[PHI,-1,0],[1,0,PHI],[-1,0,PHI],[0,PHI,1],[0,PHI,-1]];

  $: pt = SixPhiVector.fromPhiPoint(decode[sx], decode[sy], decode[sz]).sixPhiToCartesianDisplay();
  $: sceneData = { pt };

  const S = 110;
  const draw = (seen, model, d) => {
    for (const b of bases) {
      const u = unit(b).map((x) => x * 1.8);
      model.add(seg(seen, [0, 0, 0], u, '#cdbb88', S));
      model.add(glyph(seen, u, '#cdbb88', 3, S));
    }
    model.add(glyph(seen, [0, 0, 0], '#999999', 4, S));
    if (d && d.pt) model.add(glyph(seen, d.pt, '#b8860b', 11, S));
  };
  const act = seenAction({ draw, cameraZ: -600 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>#{sx}{sy}{sz} among the six golden directions — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
