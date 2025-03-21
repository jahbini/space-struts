<script>
  /**
   * @typedef {Object} Props
   * @property {any} n
   * @property {boolean} [v]
   * @property {any} update
   */

  /** @type {Props} */
  let { n, v = $bindable(false), update } = $props();
</script>

<template>
<label>
 <input type="checkbox" oninput={()=>update(n,!v)} bind:checked={v} />
  {n}
</label>
</template>

<style>
  input {
    background:"white";
   }
  label {  margin: 5px; }
  input:selected {
    background:"gray30";
  }
</style>

