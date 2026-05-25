<script>
  // Pick a Cartesian point from the 7-symbol vocabulary, map it to the six-basis
  // with the real SixPhiVector, and map back — the round-trip is exact.
  import { PhiBase } from '$lib/coffee/phiBase.coffee';
  import { SixPhiVector } from '$lib/coffee/sixPhiVector.coffee';

  const P = (a, b) => new PhiBase(a, b);
  // the canonical decode the geometry engine uses
  const decode = {
    z: P(0, 0), O: P(0, 1), o: P(0, -1),
    f: P(-1, 1), F: P(1, -1), p: P(-1, 0), P: P(1, 0)
  };
  const syms = ['z', 'O', 'o', 'f', 'F', 'p', 'P'];

  export let sx = 'z', sy = 'O', sz = 'F', show3D = false;

  const fmt = (pb) => {
    let s = '';
    if (pb.p !== 0) s += pb.p === 1 ? 'φ' : pb.p === -1 ? '−φ' : `${pb.p}φ`;
    if (pb.n !== 0) s += (s ? (pb.n > 0 ? ' + ' : ' − ') : (pb.n < 0 ? '−' : '')) + Math.abs(pb.n);
    return s || '0';
  };

  $: x = decode[sx];
  $: y = decode[sy];
  $: z = decode[sz];
  $: six = SixPhiVector.fromPhiPoint(x, y, z);
  $: cart = six.sixPhiToCartesianDisplay();
  $: roundTrips = [x.toFloat(), y.toFloat(), z.toFloat()]
       .every((v, i) => Math.abs(v - cart[i]) < 1e-9);
</script>

<div class="phi-calc">
  <div class="title">Cartesian → six-basis → Cartesian</div>

  <div class="pickers">
    <label>x
      <select bind:value={sx}>{#each syms as s}<option value={s}>{s}</option>{/each}</select>
    </label>
    <label>y
      <select bind:value={sy}>{#each syms as s}<option value={s}>{s}</option>{/each}</select>
    </label>
    <label>z
      <select bind:value={sz}>{#each syms as s}<option value={s}>{s}</option>{/each}</select>
    </label>
  </div>

  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>

  <div class="block">
    <div class="lbl">Cartesian point</div>
    <div class="mono">x = {fmt(x)} = {x.toFloat().toFixed(4)}</div>
    <div class="mono">y = {fmt(y)} = {y.toFloat().toFixed(4)}</div>
    <div class="mono">z = {fmt(z)} = {z.toFloat().toFixed(4)}</div>
  </div>

  <div class="block">
    <div class="lbl">Six-basis vector</div>
    <div class="mono six">[{six.v.map((c) => `P(${c.p},${c.n})`).join(', ')}]</div>
  </div>

  <div class="block">
    <div class="lbl">Mapped back</div>
    <div class="mono">({cart.map((c) => c.toFixed(4)).join(', ')})</div>
    {#if roundTrips}
      <span class="badge in">✓ round-trips exactly</span>
    {:else}
      <span class="badge out">✗ mismatch</span>
    {/if}
  </div>
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
  .pickers { display: flex; justify-content: center; gap: 0.6rem; margin-bottom: 0.5rem; }
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
