<script>
  import { page } from "$app/stores";
  export const identifier = "header";
</script>

<template >
<div class="header grid">
  <div>
    <img src="/images/dodecahedron.svg" />
  </div>
  <div>
    <h5>
      Greetings, come and begin to understand 3D geometry like a star ship captain.
    </h5>
    {#if $page.data.intro }
    <h6>
    { $page.data.intro}
    </h6>
    {/if}
  </div>
  <div>
    <img src="/images/dodecahedron.svg" />
  </div>
</div>
</template>

<style>
  .header {
    background: #eee;
    padding: 1rem;
    grid-area: Header;
    grid-template-columns: 1fr 2fr 1fr;
    align-content: center;
    grid-auto-flow: column;
    justify-content: center;
  }
</style>
