<script>
  import Header from "$lib/Header.svelte";
  import Footer from "$lib/Footer.svelte";
  import Nav from "$lib/Nav.svelte";
  import Aside from "$lib/Aside.svelte";
  import "@picocss/pico";
</script>

<svelte:head>
  <!-- Default theme. ~960B -->
</svelte:head>

<body>
  <div class="sitecontainer">
    <Header class="" />
    <Nav class="" />
    <div class="site">
      <div class="mainly">
        <slot />
      </div>
      <Aside />
    </div>
    <Footer />
  </div>
</body>

<style>
  body {
    width: 100%;
    height: 100%;
  }
  .sitecontainer {
    padding: 0.1in;
    display: flex;
    flex-direction: column;
    height: auto;
    width: 100vw;
  }
  .mainly {
    grid-area: Main;
  }
  .site {
    display: grid;
    grid-template-columns: 10% 75% 15%;
    grid-template-areas: "None Main Aside";
    min-height: 100vh;
  }
</style>
