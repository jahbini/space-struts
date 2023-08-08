<script>
  /*  /src/routes/(front)/what/collar */
  import Card from "/src/lib/CardLeftImage.svelte";
  import { page } from "$app/stores";
  import Pix from "$lib/Pix.svelte";
  import image from "/src/routes/pix/2387/+page.json";
</script>

<template lang="pug">

div.container.grid
  div
   <Pix { ...image } />
  article
    p The Flying-A is good for two things: It gives the exact locations to glue the cross pieces to make GG, the Golden Triangle.  Since it is made from three Pomonas, or two equal gnomon triangles, the long sides of the resulting GG are exactly right.

    p Other than that, the FlyinA has no use in either two or three dimension construction, except for cool outer space shadow battles on the wall. Pew! Pew! Boom!

    p It also might work as a tractor wheel.
</template>

<style>
</style>
