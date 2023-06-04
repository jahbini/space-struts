<script>
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
</script>

<div class="Mainly">
  <container class="grid">
    <p>{console.log($page.data)}</p>
       {@debug $page}
      <button type="submit">New Article</button>
    <ul>
    {#each $page.data.articles as article }
      <li> {article.slug}</li>
    {/each}
    </ul>
  <a href="/editpost"> Create new article<a/>  
  </container>
</div>

<style>
</style>
