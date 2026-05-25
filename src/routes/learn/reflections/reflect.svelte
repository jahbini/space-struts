<script>
  // The sidebar control panel: pick a vertex and a plane, see the exact
  // original vs reflected six-vectors. State is exported so the page can share
  // it with the visual in the left column.
  import { GeoPhi } from '$lib/coffee/geoPhi.coffee';

  export let s0 = 'z', s1 = 'O', s2 = 'F', plane = 'A', show3D = false;

  const syms = ['z', 'O', 'o', 'f', 'F', 'p', 'P'];
  const planes = ['A', 'B', 'C', 'D', 'E', 'F'];

  $: code = s0 + s1 + s2;
  $: base = GeoPhi.createPhiPoint('#' + code);
  $: reflected = GeoPhi.createPhiPoint('#' + code + '~' + plane);

  const sixStr = (v) =>
    '[' + v.v.map((c) => (c.d === 1 ? `P(${c.p},${c.n})` : `P(${c.p},${c.n})/${c.d}`)).join(', ') + ']';
  const cartStr = (v) => '(' + v.sixPhiToCartesianDisplay().map((x) => x.toFixed(4)).join(', ') + ')';
  $: hasFraction = reflected && reflected.v.some((c) => c.d !== 1);
</script>

<div class="phi-calc">
  <div class="title">Reflect a vertex through a plane</div>

  <div class="pickers">
    <label>x<select bind:value={s0}>{#each syms as s}<option value={s}>{s}</option>{/each}</select></label>
    <label>y<select bind:value={s1}>{#each syms as s}<option value={s}>{s}</option>{/each}</select></label>
    <label>z<select bind:value={s2}>{#each syms as s}<option value={s}>{s}</option>{/each}</select></label>
    <label>plane<select bind:value={plane}>{#each planes as q}<option value={q}>{q}</option>{/each}</select></label>
  </div>

  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>

  {#if base}
    <div class="block">
      <div class="lbl">#{code} (original)</div>
      <div class="mono six">{sixStr(base)}</div>
      <div class="mono">{cartStr(base)}</div>
    </div>
  {/if}
  {#if reflected}
    <div class="block">
      <div class="lbl">#{code}~{plane} (reflected)</div>
      <div class="mono six">{sixStr(reflected)}</div>
      <div class="mono">{cartStr(reflected)}</div>
      {#if hasFraction}
        <span class="badge out">denominator 5 → lands in ⅕Z[φ]</span>
      {:else}
        <span class="badge in">on the plane → still in Z[φ]</span>
      {/if}
    </div>
  {/if}
</div>

<style>
  .phi-calc {
    float: right; position: sticky; top: 1rem; z-index: 5;
    max-height: calc(100vh - 2rem); overflow: auto;
    width: 290px; margin: 0 0 0.8rem 1.2rem; padding: 0.6rem 0.7rem;
    background: #fffaf0; border: 1px solid #e7d9b0; border-radius: 0.5rem;
    font-family: sans-serif; font-size: 0.72rem; color: #333; line-height: 1.3;
  }
  .title { font-weight: bold; color: #b8860b; text-align: center; margin-bottom: 0.5rem; }
  .pickers { display: flex; flex-wrap: wrap; justify-content: center; gap: 0.5rem; margin-bottom: 0.3rem; }
  .pickers label { font-weight: bold; }
  .pickers select { font-size: 0.72rem; margin-left: 0.2rem; }
  .toggle { display: block; text-align: center; margin: 0.3rem 0; font-weight: bold; cursor: pointer; }
  .block { margin-top: 0.5rem; padding-top: 0.4rem; border-top: 1px dashed #e7d9b0; }
  .lbl { color: #b8860b; font-weight: bold; margin-bottom: 0.15rem; }
  .mono { font-family: ui-monospace, monospace; }
  .six { word-break: break-all; }
  .badge { display: inline-block; margin-top: 0.3rem; padding: 0.12rem 0.4rem; border-radius: 0.35rem; font-size: 0.68rem; }
  .badge.in { background: #def0d8; color: #2a7d2a; }
  .badge.out { background: #f6ddd8; color: #b3401f; }
  @media (max-width: 820px) {
    .phi-calc { float: none; position: static; width: auto; max-height: none; overflow: visible; margin: 1rem 0; }
  }
</style>
