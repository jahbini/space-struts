<script>
  // For a chosen edge, the live engine returns every apex that completes a
  // golden triangle (36-72-72) or golden gnomon (108-36-36) — exact lattice
  // points, tagged as already-built or new growth sites.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';

  const geo = new GeoPhi();
  const dod = geo.Polyhedra.Dodecahedron1;
  const disp = (v) => v.sixPhiToCartesianDisplay();
  const existing = new Set(geo.allPoints.map((v) => disp(v).map((x) => +x.toFixed(4)).join(',')));
  const dist = (a, b) => { const p = disp(a), q = disp(b); return Math.hypot(p[0]-q[0], p[1]-q[1], p[2]-q[2]); };

  export let vi = 0, ni = 0, show3D = false;
  $: v1 = dod[vi];
  $: nbrs = dod.filter((w) => w !== v1).map((w) => ({ w, d: dist(v1, w) }))
              .sort((a, b) => a.d - b.d).slice(0, 3).map((o) => o.w);
  $: v2 = nbrs[ni % nbrs.length];
  $: cands = v2 ? geo.goldenApexCandidates(v1, v2) : [];
  const cartKey = (c) => [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()].map((x) => +x.toFixed(4)).join(',');
  $: tagged = cands.map((c) => ({ ...c, novel: !existing.has(cartKey(c)) }));
  $: golden = tagged.filter((c) => c.kind === 'golden').length;
  $: gnomon = tagged.filter((c) => c.kind === 'gnomon').length;
  $: novel = tagged.filter((c) => c.novel).length;
  const cstr = (c) => '(' + [c.cart.x, c.cart.y, c.cart.z].map((q) => q.toFloat().toFixed(3)).join(', ') + ')';
</script>

<div class="phi-calc">
  <div class="title">Where can the next triangle go?</div>

  <div class="pick">
    <span>edge</span>
    <button on:click={() => { vi = (vi + dod.length - 1) % dod.length; ni = 0; }}>‹v</button>
    <span class="mono">{v1.ID}</span>
    <button on:click={() => { vi = (vi + 1) % dod.length; ni = 0; }}>v›</button>
    <button on:click={() => (ni = (ni + 1) % nbrs.length)}>↻nbr</button>
  </div>
  <div class="mono sub">to {v2 ? v2.ID : '—'}</div>

  <div class="stat">
    {tagged.length} candidates · {golden} golden · {gnomon} gnomon · <b>{novel} new</b>
  </div>

  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>

  <div class="rows">
    {#each tagged as c}
      <div class="crow">
        <span class="kind {c.kind}">{c.kind === 'golden' ? '△' : '▽'}</span>
        <span class="mono">{cstr(c)}</span>
        <span class="tag">{c.novel ? 'new' : 'built'}</span>
      </div>
    {/each}
  </div>
</div>

<style>
  .phi-calc {
    float: right; position: sticky; top: 1rem; z-index: 5;
    max-height: calc(100vh - 2rem); overflow: auto;
    width: 290px; margin: 0 0 0.8rem 1.2rem; padding: 0.6rem 0.7rem;
    background: #fffaf0; border: 1px solid #e7d9b0; border-radius: 0.5rem;
    font-family: sans-serif; font-size: 0.72rem; color: #333; line-height: 1.25;
  }
  .title { font-weight: bold; color: #b8860b; text-align: center; margin-bottom: 0.4rem; }
  .pick { display: flex; align-items: center; justify-content: center; gap: 0.3rem; }
  .pick button { height: 20px; border: 1px solid #ccc; background: #fff; border-radius: 4px; cursor: pointer; color: #2a7; font-weight: bold; font-size: 0.66rem; padding: 0 0.3rem; }
  .pick button:hover { background: #eee; }
  .sub { text-align: center; color: #888; }
  .mono { font-family: ui-monospace, monospace; }
  .stat { text-align: center; color: #555; margin: 0.4rem 0; font-style: italic; }
  .toggle { display: block; text-align: center; margin: 0.2rem 0 0.4rem; font-weight: bold; cursor: pointer; }
  .rows { display: flex; flex-direction: column; gap: 0.1rem; border-top: 1px dashed #e7d9b0; padding-top: 0.35rem; }
  .crow { display: flex; align-items: center; gap: 0.4rem; }
  .kind { width: 1rem; text-align: center; font-weight: bold; }
  .kind.golden { color: #b8860b; }
  .kind.gnomon { color: #2a7d2a; }
  .tag { margin-left: auto; font-size: 0.62rem; color: #999; }
  @media (max-width: 820px) {
    .phi-calc { float: none; position: static; width: auto; max-height: none; overflow: visible; margin: 1rem 0; }
  }
</style>
