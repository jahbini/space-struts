<script>
/*  /src/routes/(front)/what/collar */
import Card from '/src/lib/CardLeftImage.svelte';
import { page } from "$app/stores";
import Pix from "$lib/Pix.svelte"
import image from "/src/routes/pix/2447/+page.json";
</script>

<template lang="pug" >

div.container.grid
  div
   <Pix { ...image } />
  article
    p This rigid structure is made with 12 Golden Triangles, and 24 Golden Gnomons. This structure is made from six Huts pointing outward. Even though the Hut has a square footprint, it fits very well in the Dodecahedron's cube symmetry.

    p The golden triangles are forced to participate in all the verticies of a dodecahedron made from Huts.  Other variants of the Docahedron have three Gnomons at six corners.
</template>
  div
<style>
</style>

