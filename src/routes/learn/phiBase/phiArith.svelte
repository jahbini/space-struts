<script>
  // Interactive PhiBase calculator. Imports the canonical exact implementation
  // (the same code the geometry engine uses) so division and the lattice
  // membership test are the real thing, not a teaching mock-up.
  import { PhiBase } from '$lib/coffee/phiBase.coffee';

  export let p1 = 2, n1 = 1;   // φ³ = 2φ + 1
  export let p2 = 1, n2 = 1;   // φ² = φ + 1
  export let op = 'div';
  export let show3D = false;

  const ops = [
    { key: 'add', sym: '+', fn: (a, b) => a.add(b) },
    { key: 'sub', sym: '−', fn: (a, b) => a.sub(b) },
    { key: 'mul', sym: '×', fn: (a, b) => a.mul(b) },
    { key: 'div', sym: '÷', fn: (a, b) => a.div(b) }
  ];

  // two worked examples per operation; clicking one prepopulates the calculator
  const groups = [
    { op: 'add', name: 'Add', ex: [
      { label: 'φ² + φ = φ³', p1: 1, n1: 1, p2: 1, n2: 0 },
      { label: 'φ + 1 = φ²',  p1: 1, n1: 0, p2: 0, n2: 1 } ] },
    { op: 'sub', name: 'Subtract', ex: [
      { label: 'φ² − φ = 1',  p1: 1, n1: 1, p2: 1, n2: 0 },
      { label: 'φ − 1 = 1/φ', p1: 1, n1: 0, p2: 0, n2: 1 } ] },
    { op: 'mul', name: 'Multiply', ex: [
      { label: 'φ × (1/φ) = 1', p1: 1, n1: 0, p2: 1, n2: -1 },
      { label: 'φ × φ = φ²',    p1: 1, n1: 0, p2: 1, n2: 0 } ] },
    { op: 'div', name: 'Divide', ex: [
      { label: 'φ³ ÷ φ² = φ',           p1: 2, n1: 1, p2: 1, n2: 1 },
      { label: '1 ÷ (φ+2) → leaves Z[φ]', p1: 0, n1: 1, p2: 1, n2: 2 } ] }
  ];

  const fmt = (pb) => {
    let s = '';
    if (pb.p !== 0) s += pb.p === 1 ? 'φ' : pb.p === -1 ? '−φ' : `${pb.p}φ`;
    if (pb.n !== 0) s += (s ? (pb.n > 0 ? ' + ' : ' − ') : (pb.n < 0 ? '−' : '')) + Math.abs(pb.n);
    if (!s) s = '0';
    return pb.d === 1 ? s : `(${s}) / ${pb.d}`;
  };

  $: a = new PhiBase(p1, n1);
  $: b = new PhiBase(p2, n2);
  let result = null, error = null;
  $: {
    error = null;
    try {
      result = ops.find((o) => o.key === op).fn(new PhiBase(p1, n1), new PhiBase(p2, n2));
    } catch (e) {
      error = e.message;
      result = null;
    }
  }
  const preset = (g, q) => { op = g.op; p1 = q.p1; n1 = q.n1; p2 = q.p2; n2 = q.n2; };
</script>

<div class="phi-calc">
  <div class="examples">
    {#each groups as g}
      <div class="grp">
        <span class="grp-name">{g.name}</span>
        {#each g.ex as q}
          <button class="ex" on:click={() => preset(g, q)}>{q.label}</button>
        {/each}
      </div>
    {/each}
  </div>

  <div class="row">
    <div class="operand">
      <div class="name">a</div>
      <div class="step"><label>p</label><button on:click={() => p1--}>−</button><span>{p1}</span><button on:click={() => p1++}>+</button></div>
      <div class="step"><label>n</label><button on:click={() => n1--}>−</button><span>{n1}</span><button on:click={() => n1++}>+</button></div>
      <div class="val">{fmt(a)} = {a.toFloat().toFixed(4)}</div>
    </div>

    <div class="opcol">
      {#each ops as o}
        <button class:sel={op === o.key} on:click={() => (op = o.key)}>{o.sym}</button>
      {/each}
    </div>

    <div class="operand">
      <div class="name">b</div>
      <div class="step"><label>p</label><button on:click={() => p2--}>−</button><span>{p2}</span><button on:click={() => p2++}>+</button></div>
      <div class="step"><label>n</label><button on:click={() => n2--}>−</button><span>{n2}</span><button on:click={() => n2++}>+</button></div>
      <div class="val">{fmt(b)} = {b.toFloat().toFixed(4)}</div>
    </div>
  </div>

  <div class="result">
    {#if error}
      <span class="err">⚠ {error}</span>
    {:else if result}
      <div class="eqline"><span class="eq">a {ops.find((o) => o.key === op).sym} b =</span>
      <span class="res">{fmt(result)}</span>
      <span class="float">≈ {result.toFloat().toFixed(4)}</span></div>
      {#if result.inLattice()}
        <span class="badge in">✓ exact in Z[φ]</span>
      {:else}
        <span class="badge out">✗ left the lattice — d = {result.d}</span>
      {/if}
    {/if}
  </div>

  <label class="toggle"><input type="checkbox" bind:checked={show3D} /> show 3-D</label>
</div>

<style>
  .phi-calc {
    float: right;
    position: sticky;
    top: 1rem;
    z-index: 5;
    max-height: calc(100vh - 2rem);
    overflow: auto;
    width: 290px;
    margin: 0 0 0.8rem 1.2rem;
    padding: 0.6rem 0.7rem;
    background: #fffaf0;
    border: 1px solid #e7d9b0;
    border-radius: 0.5rem;
    font-family: sans-serif;
    font-size: 0.72rem;
    color: #333;
    line-height: 1.25;
  }
  .examples { display: flex; flex-direction: column; gap: 0.2rem; margin-bottom: 0.5rem; }
  .grp { display: flex; align-items: center; gap: 0.25rem; flex-wrap: wrap; }
  .grp-name { width: 3.6rem; font-weight: bold; color: #b8860b; }
  button.ex {
    font-size: 0.66rem; padding: 0.12rem 0.35rem; color: #5a4a1a;
    border: 1px solid #d9c48a; background: #fff; border-radius: 0.3rem; cursor: pointer;
  }
  button.ex:hover { background: #f3e9c8; }
  .row { display: flex; align-items: center; justify-content: center; gap: 0.6rem; }
  .operand { text-align: center; }
  .name { font-weight: bold; font-size: 0.85rem; }
  .step { display: flex; align-items: center; justify-content: center; gap: 0.15rem; margin: 0.1rem 0; }
  .step label { width: 0.9rem; font-weight: bold; }
  .step span { width: 1.5rem; text-align: center; }
  .step button, .opcol button {
    width: 20px; height: 20px; line-height: 1; font-weight: bold; color: #2a7;
    border: 1px solid #ccc; background: #fff; border-radius: 4px; cursor: pointer; padding: 0;
  }
  .step button:hover, .opcol button:hover { background: #eee; }
  .opcol { display: flex; flex-direction: column; gap: 0.15rem; }
  .opcol button.sel { background: #FFD700; color: #333; }
  .val { margin-top: 0.25rem; color: #555; }
  .result { margin-top: 0.55rem; padding-top: 0.5rem; border-top: 1px dashed #e7d9b0; text-align: center; }
  .result .res { font-weight: bold; color: #b8860b; margin: 0 0.25rem; }
  .result .float { color: #888; }
  .badge { display: inline-block; margin-top: 0.3rem; padding: 0.12rem 0.4rem; border-radius: 0.35rem; font-size: 0.68rem; }
  .badge.in { background: #def0d8; color: #2a7d2a; }
  .badge.out { background: #f6ddd8; color: #b3401f; }
  .err { color: #b3401f; font-weight: bold; }
  .toggle { display: block; text-align: center; margin: 0.5rem 0 0.1rem; font-weight: bold; cursor: pointer; }
  /* on narrow screens, drop the float/sticky and let the calc sit inline */
  @media (max-width: 820px) {
    .phi-calc {
      float: none; position: static; width: auto;
      max-height: none; overflow: visible; margin: 1rem 0;
    }
  }
</style>
