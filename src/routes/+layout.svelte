<script>
import Header from './Header.svelte';
import Footer from './Footer.svelte';
import Nav from './Nav.svelte';
import Aside from './Aside.svelte';
</script>
<body>
  <div class="sitecontainer">
    <div class="site">
      <Header class=""/>
      <Nav class=""/>
      <div class="mainly">
        <slot />
      </div>
      <Aside />
      <Footer />
    </div>
  </div>
</body>

<style >
@import "@picocss/pico";

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
  grid-template-rows: 10% 10% 70% 10%;
  grid-template-areas:
    'Header Header Header'
    'Nav Nav Nav'
    'None Main Aside'
    'Footer Footer Footer';
  min-height: 100vh;
}
</style>
