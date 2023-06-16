<script>
  export const identifier = "main";
  import Carousel from "$lib/Carousel.svelte";
  let images = import.meta.glob("$lib/space-struts/*.jpeg");
  let pix = [];
  let imageParts=[]
  let imageID=""
  for (let image in images) {
      console.log("raw image text",image);
      imageID=image.split('/').pop();
      console.log("ImageID=",image,imageID);
      pix.push(imageID);
  }
  console.log("FP now IMAGES",pix);

  function shuffle(a) {
    for (let i = a.length; i; i--) {
      let j = Math.floor(Math.random() * i);
      [a[i - 1], a[j]] = [a[j], a[i - 1]];
    }
    return a;
  }
  let showThese = shuffle(pix).slice(0, 8);
</script>

<div class="main grid">
  <div>
    <h1>Left Hand {identifier}!</h1>
    <p>
      This is the main page. and is full of text This is the main page. and is full of text This is
      the main page. and is full of text This is the main page. and is full of text This is the main
      page. and is full of text This is the main page. and is full of text This is the main page.
      and is full of this text
    </p>
  </div>

  <Carousel />
</div>
<div>
  <container class="grid">
    {#each showThese as index}
      <a href="/pix/{index.slice(4,8)}">
        <article>
            <img src="/images/space-struts/{index}" alt="image" />
        </article>
      </a>
    {/each}
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
    grid-column-gap: 2px;
    grid-row-gap: 2px;
  }
</style>
