<script>
/*  /src/routes/(front)/what/collar */
import Card from '/src/lib/CardLeftImage.svelte';
import { page } from "$app/stores";
import Pix from "$lib/Pix.svelte"
import image from "/src/routes/pix/2385/+page.json";
</script>

<template lang="pug" >
div.container.grid
  div
   <Pix { ...image } />
  article
    p Pomona is the starting point of all construction.  Pomona is two equal length sticks glued in a perfect 36degree (1/10 of a circle) angle.  

    p This two dimensional structure gives rise to the Golden Gnomon, The Flying-A, and then the Golden Triangle.

</template>
<style>
</style>

