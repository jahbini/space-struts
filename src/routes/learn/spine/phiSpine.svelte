<script>
  // Powers of φ computed with the real PhiBase multiply — the coefficients that
  // fall out are consecutive Fibonacci numbers, and φʲ·φᵏ = φ^{j+k} exactly.
  import { PhiBase } from '$lib/coffee/phiBase.coffee';

  const phi = new PhiBase(1, 0); // φ = P(1,0)
  const power = (k) => {
    let r = new PhiBase(0, 1);   // φ⁰ = 1
    for (let i = 0; i < k; i++) r = r.mul(phi);
    return r;
  };
  const spine = Array.from({ length: 10 }, (_, k) => ({ k, v: power(k) }));

  export let j = 3, k = 2, show3D = false;
  $: a = power(j);
  $: b = power(k);
  $: prod = a.mul(b);
  $: sum = power(j + k);
  $: matches = prod.p === sum.p && prod.n === sum.n;
</script>

<div class="phi-calc">
  <div class="title">φᵏ = F₍ₖ₊₁₎·φ + Fₖ</div>
  <table>
    <thead><tr><th>k</th><th>φᵏ = P(p, n)</th><th>≈</th></tr></thead>
    <tbody>
      {#each spine as e}
        <tr><td>{e.k}</td><td>P({e.v.p}, {e.v.n})</td><td>{e.v.toFloat().toFixed(3)}</td></tr>
      {/each}
    </tbody>
  </table>
  <div class="note">The two coefficients are always consecutive Fibonacci numbers.</div>

  <div class="idx">
    <div class="title">Multiply = add the indices</div>
    <div class="steprow">
      <div class="step"><label>j</label><button on:click={() => (j = Math.max(0, j - 1))}>−</button><span>{j}</span><button on:click={() => j++}>+</button></div>
      <div class="step"><label>k</label><button on:click={() => (k = Math.max(0, k - 1))}>−</button><span>{k}</span><button on:click={() => k++}>+</button></div>
    </div>
    <div class="eqline">φ<sup>{j}</sup> × φ<sup>{k}</sup> = φ<sup>{j + k}</sup></div>
    <div class="vals">P({a.p},{a.n}) × P({b.p},{b.n}) = <b>P({prod.p},{prod.n})</b></div>
    {#if matches}<span class="badge in">✓ = φ<sup>{j + k}</sup> = P({sum.p},{sum.n})</span>{/if}
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
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 0.1rem 0.3rem; text-align: left; }
  th { color: #b8860b; border-bottom: 1px solid #e7d9b0; }
  tbody tr:nth-child(even) { background: #f7efd6; }
  td:last-child, th:last-child { text-align: right; color: #888; }
  .note { margin-top: 0.4rem; font-style: italic; color: #555; text-align: center; }
  .idx { margin-top: 0.6rem; padding-top: 0.5rem; border-top: 1px dashed #e7d9b0; text-align: center; }
  .steprow { display: flex; justify-content: center; gap: 0.8rem; }
  .step { display: flex; align-items: center; gap: 0.15rem; }
  .step label { font-weight: bold; }
  .step span { width: 1.4rem; text-align: center; }
  .step button {
    width: 20px; height: 20px; line-height: 1; font-weight: bold; color: #2a7;
    border: 1px solid #ccc; background: #fff; border-radius: 4px; cursor: pointer; padding: 0;
  }
  .step button:hover { background: #eee; }
  .eqline { margin-top: 0.35rem; font-size: 0.95rem; }
  .vals { color: #555; margin-top: 0.2rem; }
  .badge { display: inline-block; margin-top: 0.35rem; padding: 0.12rem 0.4rem; border-radius: 0.35rem; font-size: 0.68rem; background: #def0d8; color: #2a7d2a; }
  .toggle { display: block; text-align: center; margin: 0.5rem 0 0.1rem; font-weight: bold; cursor: pointer; }
  @media (max-width: 820px) {
    .phi-calc { float: none; position: static; width: auto; max-height: none; overflow: visible; margin: 1rem 0; }
  }
</style>
