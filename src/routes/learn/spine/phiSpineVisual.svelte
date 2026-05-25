<script>
  // The golden spiral: each quarter-turn scales the radius by φ, so the powers
  // φᵏ sit at angle k·90°. Markers: φʲ (gold), φᵏ (blue), φʲ⁺ᵏ (green) — showing
  // multiplication = adding the turn counts.
  import { seenAction, glyph, seg } from '$lib/seenViz.js';

  export let j = 3, k = 2, show3D = false;
  const PHI = (1 + Math.sqrt(5)) / 2;
  $: sceneData = { j, k };

  const S = 20;
  const pt = (kk) => { const th = kk * Math.PI / 2, r = Math.pow(PHI, kk); return [r * Math.cos(th), r * Math.sin(th), 0]; };
  const draw = (seen, model, d) => {
    let prev = null;
    for (let i = 0; i <= 6 * 16; i++) {
      const t = i / 16, p = pt(t);
      if (prev) model.add(seg(seen, prev, p, '#cdbb88', S));
      prev = p;
    }
    const mark = (kk, col) => { if (kk >= 0 && kk <= 6) model.add(glyph(seen, pt(kk), col, 7, S)); };
    mark(d.j, '#b8860b'); mark(d.k, '#5b8def'); mark(d.j + d.k, '#2a7d2a');
  };
  const act = seenAction({ draw, cameraZ: -700 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>golden spiral: φʲ (gold), φᵏ (blue), φʲ⁺ᵏ (green); each quarter-turn ×φ — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
