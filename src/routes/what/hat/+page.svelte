<script>
  /*  /src/routes/(front)/what/collar */
  import Card from "/src/lib/CardLeftImage.svelte";
  import { page } from "$app/stores";
  import Pix from "$lib/Pix.svelte";
  import image from "/src/routes/pix/2544/+page.json";
</script>

<template lang="pug">

div.container.grid
  div
   <Pix { ...image } />
  article
    p.
      The Hat is made of 3 gnomon triangles.  Several joined together make a simple but useful 3D object.
      It tiles the plane in cookie-cutter fashion and gives rise to all the patterns based on hex tiles.

    p.
      In 3 dimensions, two hats can join on two short sides to make a half tetrahedron, or join on all three long sides to make  a flying saucer.
      Five Hats joined on two edges for the face of the Great Dodecahedron.

    p Technically the shape is formed from the intersection of three blades to create an equilateral triangle on a fourth blade.
</template>
div

<style>
</style>
