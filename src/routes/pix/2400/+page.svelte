<script>
// file for image 2400
import Pix from "$lib/Pix.svelte"
 /** @type {import('./$types').PageData} */
 import { page } from "$app/stores";
 import image from "./+page.json";
</script>
<div class="container grid">
<div>
<Pix { ...image } />
</div>
<template lang="pug">
article
  p.
     All acute triangles can be put together to for a disphenoid.
     All acute isoseles triangles create disphenoids that have the the short edges 
     and adjacent faces 
     at exactly 90 degrees from each other.

</template>
<div/>
</div>
<style>
</style>
