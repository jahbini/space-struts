<script>
  export const identifier = "main";
  import Carousel from "$lib/Carousel.svelte";
  let images = import.meta.glob("$lib/space-struts/*.jpeg");
  let pix = [];
  for (let image in images) {
    pix.push(image);
  }

  function shuffle(a) {
    for (let i = a.length; i; i--) {
      let j = Math.floor(Math.random() * i);
      [a[i - 1], a[j]] = [a[j], a[i - 1]];
    }
    return a;
  }
  let showThese = shuffle(pix).slice(0, 6);
</script>

<div class="main grid">
  <div>
    <h1>Left Hand {identifier}!</h1>
    <p>
      This is the main page. and is full of text This is the main page. and is full of text This is
      the main page. and is full of text This is the main page. and is full of text This is the main
      page. and is full of text This is the main page. and is full of text This is the main page.
      and is full of text
    </p>
  </div>

  <Carousel />
</div>
<div>
  <container class="grid">
    {#each showThese as index}
      <div>{JSON.stringify(index)}</div>
      <a href="/meta/{index}">
        <article>
          <header>
            <img src={index} alt="image" />
          </header>
          <p>{index.headline}</p>
        </article>
      </a>
    {/each}
    <p>
      This is the container it is mages long? This is the main page. and is full of text This is the
      main page. and is full of text
    </p>
  </container>
</div>

<style>
  .main {
    background-color: #f0f0f0;
    padding: 20px;
    grid-template-columns: 3fr 1fr;
  }
  container {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    grid-template-rows: repeat(2, 1fr);
    grid-column-gap: 2px;
    grid-row-gap: 2px;
  }
</style>
