<script>
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
  const pageId="render page for route (admin)/select";
</script>

<div class="Mainly">
  <container class="grid">
    <p>{console.log($page.data)}</p>
       {@debug pageId,$page}
    <a href="/editpost?article=new"> Create new article<a/>  
    <ul>
    {#each $page.data.articles as article }
      <li> <a href="/editpost?article={article.id}"> {article.headline}</a></li>
    {/each}
    </ul>
  </container>
</div>

<style>
</style>
