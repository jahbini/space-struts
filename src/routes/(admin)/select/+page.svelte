<script>
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
</script>

<div class="Mainly">
  <container class="grid">
    <p>{console.log($page.data)}</p>
       {@debug $page}
    <a href="/editpost?new"> Create new article<a/>  
    <ul>
    {#each $page.data.articles as article }
      <li> <a href="/editpost?{article.slug}"> {article.slug}</a></li>
    {/each}
    </ul>
  </container>
</div>

<style>
</style>
