<script>
  /*  /src/routes/(front)/what/collar */
  import Card from "/src/lib/CardLeftImage.svelte";
  import { page } from "$app/stores";
  import Pix from "$lib/Pix.svelte";
  import image from "/src/routes/pix/2403/+page.json";
</script>

<template lang="pug">

div.container.grid
  div
   <Pix { ...image } />
  article
    p The Hut is made from four GG's and two GT's.  Six of them can be assembled into an invtroverted cube or and extroverted Dodecahedron. In either configuration, the resulting structure is rigid.

    p The Hut complements the Hat's ability to create equalateral triangles in one blade, the Hut does the same to create perfect square shapes.

    p it also might work as a tractor wheel.
</template>

<style>
</style>
