<script>
  // file for image 2407
  import Pix from "$lib/Pix.svelte";
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
  import image from "./+page.json";
</script>

<div class="container grid">
  <template lang="pug">
div
  article
    p These are rumored to be remains of KingD's grandparents, and are enjoying their retirement in Florida's heartland.
div
  <Pix { ...image } />
  </template>
</div>

<style>
</style>
