<script>
  // a (gold), b (blue) and the result (green) plotted on a number line. Gold
  // ticks mark the powers of φ; grey ticks mark the integers.
  import { PhiBase } from '$lib/coffee/phiBase.coffee';
  import { seenAction, glyph, seg } from '$lib/seenViz.js';

  export let p1 = 2, n1 = 1, p2 = 1, n2 = 1, op = 'div', show3D = false;

  const PHI = (1 + Math.sqrt(5)) / 2;
  const ops = {
    add: (a, b) => a.add(b), sub: (a, b) => a.sub(b),
    mul: (a, b) => a.mul(b), div: (a, b) => a.div(b)
  };

  $: a = new PhiBase(p1, n1);
  $: b = new PhiBase(p2, n2);
  let rv = null;
  $: { try { rv = ops[op](new PhiBase(p1, n1), new PhiBase(p2, n2)).toFloat(); } catch (e) { rv = null; } }
  $: sceneData = { av: a.toFloat(), bv: b.toFloat(), rv };

  const S = 26;
  const draw = (seen, model, d) => {
    model.add(seg(seen, [-5, 0, 0], [10, 0, 0], '#bbbbbb', S));
    for (let i = -4; i <= 9; i++) model.add(seg(seen, [i, -0.15, 0], [i, 0.15, 0], '#dddddd', S));
    for (const k of [1, 2, 3, 4]) {
      const x = Math.pow(PHI, k);
      model.add(seg(seen, [x, -0.3, 0], [x, 0.3, 0], '#e0c060', S));
    }
    const mark = (x, y, col) => {
      model.add(seg(seen, [x, 0, 0], [x, y, 0], col, S));
      model.add(glyph(seen, [x, y, 0], col, 6, S));
    };
    mark(d.av, 1.0, '#b8860b');
    mark(d.bv, 0.55, '#5b8def');
    if (d.rv != null) mark(d.rv, -1.0, '#2a7d2a');
  };
  const act = seenAction({ draw, cameraZ: -650 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>a (gold), b (blue), result (green) on the number line; gold ticks = powers of φ — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
