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
    p.
      The Four Hats Gang grew up in a poor backwater zone of Chi B/Z 10 Troy.
      Contrary to belief back on his homre world, they assure me that she's a real PrincessT at heart.
    p.
      Pursuing years of commerce and it's profits, they formed  Grosahedron, LLC and  never cheated their customers until
      the Exversion was complete.
    p Viva La Inversion, er, Exversion.
div
  <Pix { ...image } />
  </template>
</div>

<style>
</style>
