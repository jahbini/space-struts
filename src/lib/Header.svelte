<script>
  import { page } from "$app/stores";
  export const identifier = "header";
</script>

<template lang="pug">
d.header.grid
  d
    img(src="images/dodecahedron.svg")
  d
    p.
      Greetings, come and begin to understand 3D geometry like a star ship captain.
  d
    img(src="images/dodecahedron.svg?raw")
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
