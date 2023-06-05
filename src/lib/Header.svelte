<script>
  import dodecahedron from "./dodecahedron.svg?raw";
  import { page } from "$app/stores";
  export const identifier = "header";
  let kunga = "Lib/Nav :";
</script>

<div class="header grid">
  {@html dodecahedron}
  <p>
    {#if !$page.status.error && $page.data.user}
      Hi, {$page.data.user.username}, welcome back!
    {:else}
      Greetings Stranger, come and begin to understand 3D geometry like a star ship captain
    {/if}
  </p>
  {@html dodecahedron}
</div>

<style>
  .header {
    background: #eee;
    padding: 1rem;
    grid-area: Header;
    grid-template-columns: 1fr 2fr 1fr;
    align-content: center;
    grid-auto-flow: column;
    justify-content: center;
  }
</style>
