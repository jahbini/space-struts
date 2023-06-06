<script>
  import Header from "$lib/Header.svelte";
  import Footer from "$lib/Footer.svelte";
  import Nav from "$lib/Nav.svelte";
  import Aside from "$lib/Aside.svelte";
</script>

<body>
  <div class="sitecontainer">
    <div class="site">
      <Header class="" />
      <Nav class="" />
      <div class="mainly">
        <slot />
      </div>
      <Aside />
      <Footer />
    </div>
  </div>
</body>

<style>
  @import "@picocss/pico";
  html,body {
   width: 100%;
   height: 100%;
  }
  .sitecontainer {
    padding: 0;
    height: 100vh;
    width: 100vw;
  }
  .mainly {
    grid-area: Main;
  }
  .site {
    display: grid;
    grid-template-columns: 10% 75% 15%;
    grid-template-rows: 10% 5% minmax(auto,75%)  5%;
    grid-template-areas:
      "Header Header Header"
      "Nav Nav Nav"
      "None Main Aside"
      "Footer Footer Footer";
    min-height: 100vh;
  }
</style>
