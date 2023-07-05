<script>
  // file for image 1971
  import Pix from "$lib/Pix.svelte";
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
  import image from "./+page.json";
</script>

<div class="container grid">
  <div>
    <Pix {...image} />
  </div>
  <div />
  <div />
</div>

<style>
</style>
