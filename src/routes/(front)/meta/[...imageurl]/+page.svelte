<script>
  /** @type {import('./$types').PageData} */
  import { page } from "$app/stores";
</script>

<div>
  <container class="grid">
    <img src={$page.params.imageurl} alt="image" />
    <pre>
  {@debug $page}
</pre>
    <form method="POST" action="/meta/[...imageurl]?/create">
      <!-- Markup example 1: input is inside label -->
      <label for="tags">
        keywords
        <input type="text" id="tags" name="tags" value={$page.data.image.tags} required />
      </label>

      <label for="headline">
        Head Line
        <input
          type="text"
          id="headline"
          name="headline"
          value={$page.data.image.headline}
          required
        />
      </label>

      <!-- Markup example 2: input is after label -->
      <label for="photoDescription">tell us more...</label>
      <textarea
        columns="40"
        rows="5"
        id="photoDescription"
        name="photoDescription"
        value={$page.data.image.photoDescription}
      />
      <input type="hidden" id="photoURL" name="photoURL" value={$page.data.image.photoURL} />

      <button type="submit">Submit</button>
    </form>
  </container>
</div>

<style>
</style>
