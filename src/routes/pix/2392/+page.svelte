<script>
// file for image 2392
import Pix from "$lib/Pix.svelte"
 /** @type {import('./$types').PageData} */
 import { page } from "$app/stores";
</script>
<h1>{$page.data.image.heading}!!</h1>
<Pix { ...$page.data.image } />
<style>
</style>