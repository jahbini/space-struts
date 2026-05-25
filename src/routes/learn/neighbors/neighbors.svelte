<script>
  // The complete nearest-neighbour set is the Ih orbit of the two golden edge
  // vectors: geo.neighborStar = 30 short + 30 long offsets. Add them to a vertex
  // to see every candidate neighbour — including the ones not yet built.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';

  const geo = new GeoPhi();
  const star = geo.neighborStar;
  const short = star.filter((s) => s.lenClass === 's');
  const long = star.filter((s) => s.lenClass === 'L');

  const dod = geo.Polyhedra.Dodecahedron1;
  const disp = (v) => v.sixPhiToCartesianDisplay();
  const existing = new Set(geo.allPoints.map((v) => disp(v).map((x) => +x.toFixed(4)).join(',')));

  export let vi = 0, show3D = false;
  const breakdown = (vertex, offs) => {
    const c = disp(vertex);
    let exist = 0, novel = 0;
    for (const s of offs) {
      const o = [s.offset.x.toFloat(), s.offset.y.toFloat(), s.offset.z.toFloat()];
      const cand = [c[0] + o[0], c[1] + o[1], c[2] + o[2]].map((x) => +x.toFixed(4)).join(',');
      if (existing.has(cand)) exist++; else novel++;
    }
    return { exist, novel };
  };
  $: vertex = dod[vi];
  $: bShort = breakdown(vertex, short);
  $: bLong = breakdown(vertex, long);
</script>

<div class="phi-calc">
  <div class="title">The nearest-neighbour star</div>
  <div class="counts">
    <div><b>{short.length}</b> short offsets (2/φ)</div>
    <div><b>{long.length}</b> long offsets (2)</div>
  </div>

  <div class="vpick">
    <button on:click={() => (vi = (vi + dod.length - 1) % dod.length)}>‹</button>
    <span>vertex {vertex.ID}</span>
    <button on:click={() => (vi = (vi + 1) % dod.length)}>›</button>
  </div>

  <div class="block">
    <div class="lbl">short (2/φ) neighbours</div>
    <div>{bShort.exist} already built · <b>{bShort.novel}</b> new</div>
  </div>
  <div class="block">
    <div class="lbl">long (2) neighbours</div>
    <div>{bLong.exist} already built · <b>{bLong.novel}</b> new</div>
  </div>
  <div class="note">The "new" sites are exactly the neighbours cliques could never reach.</div>
  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>
</div>

<style>
  .phi-calc {
    float: right; position: sticky; top: 1rem; z-index: 5;
    max-height: calc(100vh - 2rem); overflow: auto;
    width: 290px; margin: 0 0 0.8rem 1.2rem; padding: 0.6rem 0.7rem;
    background: #fffaf0; border: 1px solid #e7d9b0; border-radius: 0.5rem;
    font-family: sans-serif; font-size: 0.72rem; color: #333; line-height: 1.3;
  }
  .title { font-weight: bold; color: #b8860b; text-align: center; margin-bottom: 0.4rem; }
  .counts { display: flex; justify-content: space-around; text-align: center; }
  .vpick { display: flex; align-items: center; justify-content: center; gap: 0.6rem; margin: 0.5rem 0; }
  .vpick button { width: 22px; height: 22px; border: 1px solid #ccc; background: #fff; border-radius: 4px; cursor: pointer; color: #2a7; font-weight: bold; }
  .vpick button:hover { background: #eee; }
  .vpick span { font-family: ui-monospace, monospace; }
  .block { margin-top: 0.4rem; padding-top: 0.35rem; border-top: 1px dashed #e7d9b0; }
  .lbl { color: #b8860b; font-weight: bold; }
  .note { margin-top: 0.5rem; font-style: italic; color: #555; text-align: center; }
  .toggle { display: block; text-align: center; margin: 0.4rem 0 0.1rem; font-weight: bold; cursor: pointer; }
  @media (max-width: 820px) {
    .phi-calc { float: none; position: static; width: auto; max-height: none; overflow: visible; margin: 1rem 0; }
  }
</style>
