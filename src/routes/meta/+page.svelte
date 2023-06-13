<script>
  /** @type {import('./$types').PageData} */
  export let data;
  export let page;
  console.log("lala data.svelte", data);
  console.log("lala page.svelte", page);
</script>

<div>
  <p>
    HI! {JSON.stringify(data)}
    {JSON.stringify(page)}
  </p>
</div>

<style>
</style>
