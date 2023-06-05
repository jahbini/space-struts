<script>
import  Header  from "$lib/Header.svelte";
const thisFile = "src/routes/(admin)/editpost";
import { page } from '$app/stores';
let tag,slug;
$: ( { headline, text,summary, tags, slug} = $page.data.article);
</script>
  <container class="grid">
    {JSON.stringify($page)}
  {@debug thisFile,$page}
    <form method="POST" action="/editpost/create">
      <!-- Markup example 1: input is inside label -->
      <label for="slug">
        Sluggo Line
        <input type="text" id="slug" name="slug" value={slug} required />
      </label>

      <label for="tags">
        tags
        <input type="text" id="tags" name="tags" value={tags} required />
      </label>


      <label for="headline">
        Head Line
        <input type="text" id="headline" name="headline" value={headline} />
      </label>

      <!-- Markup example 2: input is after label -->
      <label for="summary">TL;DR</label>
      <textarea
        columns="40"
        rows="2"
        id="summary"
        name="summary"
        value={summary}
      />


      <!-- Markup example 2: input is after label -->
      <label for="text">tell us Everything...</label>
      <textarea
        columns="40"
        rows="5"
        id="text"
        name="text"
        value={text}
      />

      <button type="submit">Submit</button>
    </form>
  </container>

