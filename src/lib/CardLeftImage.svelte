<script>
  export let heading;
  export let image;
</script>

<div class="container horizontal">
  <div class="photo">
    {heading}
    <img src={image} alt="slme" />
  </div>
  <div class="container"><slot /></div>
</div>

<style>
  img {
    display: inline;
  }
  .horizontal {
    display: flex;
    flex-direction: row;
  }
  .photo {
    font-size: 1.2em;
    min-width: 175px;
    max-width: 175px;
  }
  .container .container {
    padding: 1em;
  }
</style>
