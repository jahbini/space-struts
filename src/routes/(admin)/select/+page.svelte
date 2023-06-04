<script>
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
  $: articles= $page.data.articles;
</script>

<div>
  <container class="grid">
    <p>{console.log($page.data)}</p>
       {@debug $page}
      <button type="submit">New Article</button>
    <ul>
    {#each $articles as article }
      <li> $article.slug </li>
    {/each}
    </ul>
    
    </form>
  </container>
</div>

<style>
</style>
