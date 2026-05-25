<script>
  // Live from the geometry engine: the 15 mirror planes of Ih (each normal is
  // nX ± nY of the six basis normals) and how the cliques tag onto them.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';

  const geo = new GeoPhi();
  const planes = geo.mirrorPlanes; // [{ label, v:{x,y,z} }] × 15

  // distinct clique objects (cliqueName and its negation alias the same object)
  const seen = new Set();
  let single = 0, dbl = 0, none = 0;
  for (const name of geo.cliqueNames) {
    const c = geo.cliques[name];
    if (!c || seen.has(c)) continue;
    seen.add(c);
    const k = (c.planes || []).length;
    if (k === 1) single++; else if (k >= 2) dbl++; else none++;
  }
  const total = seen.size;

  const norm = (v) => `(${v.x.toID()}, ${v.y.toID()}, ${v.z.toID()})`;

  export let sel = 'A+C', show3D = false;
  const planeCount = (label) => {
    const s = new Set(); let c = 0;
    for (const name of geo.cliqueNames) {
      const cl = geo.cliques[name];
      if (!cl || s.has(cl)) continue; s.add(cl);
      if ((cl.planes || []).includes(label)) c++;
    }
    return c;
  };
  $: selCount = planeCount(sel);
</script>

<div class="phi-calc">
  <div class="title">The 15 mirror planes of Ih</div>
  <div class="rows">
    {#each planes as pl}
      <div class="prow" class:on={pl.label === sel} on:click={() => (sel = pl.label)}>
        <span class="lab">{pl.label}</span>
        <span class="nrm">{norm(pl.v)}</span>
      </div>
    {/each}
  </div>
  <div class="pick">
    plane <b>{sel}</b> contains <b>{selCount}</b> cliques
  </div>
  <div class="stat">
    {total} cliques · {single} in one plane · {dbl} in two · {none} in none
  </div>
  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>
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
  .rows { display: flex; flex-direction: column; }
  .prow { display: flex; gap: 0.4rem; padding: 0.12rem 0.2rem; cursor: pointer; border-radius: 0.25rem; }
  .prow:hover { background: #f3e9c8; }
  .prow.on { background: #FFD700; }
  .lab { width: 3.2rem; font-weight: bold; }
  .nrm { font-family: ui-monospace, monospace; word-break: break-all; }
  .pick { margin-top: 0.5rem; padding-top: 0.4rem; border-top: 1px dashed #e7d9b0; text-align: center; }
  .stat { margin-top: 0.4rem; text-align: center; color: #555; font-style: italic; }
  .toggle { display: block; text-align: center; margin: 0.4rem 0 0.1rem; font-weight: bold; cursor: pointer; }
  @media (max-width: 820px) {
    .phi-calc { float: none; position: static; width: auto; max-height: none; overflow: visible; margin: 1rem 0; }
  }
</style>
