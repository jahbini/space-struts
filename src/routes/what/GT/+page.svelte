<script>
/*  /src/routes/(front)/what/collar */
import Card from '/src/lib/CardLeftImage.svelte';
import { page } from "$app/stores";
import Pix from "$lib/Pix.svelte"
import image from "/src/routes/pix/2388/+page.json";
</script>

<template lang="pug" >

div.container.grid
  div
   <Pix { ...image } />
  article
    p GT, the Golden Triangle, is an isocelese triangle with the sides in the ratio of the Golden Ratio, (queue choir).  The unique ratio that becomes the bridge between addition and multiplication and with our Golden Geometry.

    p GG is different from GT, because GG has two shorter sides where GT has two longer sides. 

    p it also might work as a tractor wheel.
</template>
  div
<style>
</style>

