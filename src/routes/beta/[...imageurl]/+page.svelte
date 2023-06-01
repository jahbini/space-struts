<script>
  /** @type {import('./$types').PageData} */
  export let page;
  /** @type {import('./$types').Actions} */
  export let form;
</script>

<div>
  <container class="grid">
    <p>{console.log("Page meta has loaded:", $page.data)}</p>
    <img src={$page.params.imageurl} alt="image" />
    <pre>
{@debug}
  {JSON.stringify($page.data.image)}
</pre>
{#if form?.error}
      <div
        class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative"
        role="alert"
      >
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline">{form.error}</span>
      </div>
{/if}
    <form method="POST" action="/meta?/create">
      <!-- Markup example 1: input is inside label -->
      <label for="keywords">
        keywords
        <input type="text" id="keywords" name="keywords" value={$page.data.image.tags} required />
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
      <input type="hidden" id="photoID" name="photoID" value={$page.data.image.photoURL} />

      <button type="submit">Submit</button>
    </form>
  </container>
</div>

<style>
</style>
