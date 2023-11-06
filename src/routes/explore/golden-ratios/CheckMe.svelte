<script>
  export let n
  export let v=false;
  export let update
</script>

<template>
<label>
 <input type="checkbox" on:input={()=>update(n,!v)} bind:checked={v} />
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

