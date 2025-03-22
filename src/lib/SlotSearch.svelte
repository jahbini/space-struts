<script>
  /* /src/lib/SlotSearch.svelte */
  export let selectors = [];

  function doIt(event) {
    const tags = selectors.map((s) => {
      const el = document.getElementById(s.id);
      return el?.value || '';
    });
    window.open(
      "https://www.google.com/search?rls=en&q=" + tags.join("+") + "&ie=UTF-8&oe=UTF-8",
      "_blank"
    );
  }
</script>

<nav>
  <header><h2>Select and Surf</h2></header>
  <ul>
    {#each selectors as selector}
      <li>
        <select id={selector.id}>
          {#each selector.options as option}
            <option value={option}>{option}</option>
          {/each}
        </select>
      </li>
    {/each}
    <li>
      <button on:click|preventDefault={doIt}>Click Me!</button>
    </li>
  </ul>
</nav>
<style>
</style>
