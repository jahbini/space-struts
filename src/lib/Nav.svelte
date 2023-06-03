<script>
  export const identifier = "nav";
  import { page } from "$app/stores";
  let myId = "component nav";
</script>

<div class="nav">
  <a role="button" href="/">Home</a>
  {@debug myId, page}
  {#if $page.data.user}
    <a data-sveltekit-reload role="button" href="/logout">Sign out</a>
  {:else}
    <a role="button" href="/register">Sign up</a>
    <a role="button" href="/login">Sign in</a>
  {/if}
</div>

<style>
  .nav {
    background: #531;
    padding: 1rem;
    grid-area: Nav;
  }
</style>
