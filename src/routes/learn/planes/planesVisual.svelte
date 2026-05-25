<script>
  // The dodecahedron's 20 vertices (gold) with the selected mirror plane shown
  // as a translucent disk perpendicular to its nX±nY normal.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';
  import { seenAction, glyph, poly, unit, cross, perp } from '$lib/seenViz.js';

  export let sel = 'A+C', show3D = false;

  const geo = new GeoPhi();
  const planes = geo.mirrorPlanes;
  const verts = geo.Polyhedra.Dodecahedron1.map((v) => v.sixPhiToCartesianDisplay());

  $: selPlane = planes.find((p) => p.label === sel) || planes[0];
  $: normal = [selPlane.v.x.toFloat(), selPlane.v.y.toFloat(), selPlane.v.z.toFloat()];
  $: sceneData = { normal };

  const S = 110;
  const draw = (seen, model, d) => {
    for (const v of verts) model.add(glyph(seen, v, '#b8860b', 5, S));
    const n = unit(d.normal), u = perp(n), w = cross(n, u), r = 1.9;
    const corners = [[1,1],[-1,1],[-1,-1],[1,-1]].map(([a, b]) =>
      [(u[0]*a+w[0]*b)*r, (u[1]*a+w[1]*b)*r, (u[2]*a+w[2]*b)*r]);
    model.add(poly(seen, corners, '#5b8def', 70, S));
  };
  const act = seenAction({ draw, cameraZ: -650 });
</script>

<figure class="visual" class:hidden={!show3D}>
  <canvas use:act={sceneData} width="520" height="520" class="seen"></canvas>
  <figcaption>dodecahedron vertices + mirror plane {sel} — drag to rotate</figcaption>
</figure>

<style>
  .visual { margin: 0.4rem 0 1rem; }
  .visual.hidden { position: absolute; left: -99999px; top: 0; }
  canvas.seen { width: 100%; max-width: 520px; height: auto; background: #f3eed8; display: block; border: 1px solid #e7d9b0; border-radius: 0.4rem; }
  figcaption { font-size: 0.78rem; color: #777; margin-top: 0.3rem; }
</style>
