<script>
  export const identifier = "nav";
  import { page } from "$app/stores";
  
  function splitAt(paths,n){
	let x = [];
	for (let text in paths) {
		let t = text.split("/")[n];
		console.log("match at?",t,n );
		x.push(t);
	};
	   return x;
  } 

  let x = [];
  let owner ="what";
  function makeButtons(myInfo){
  console.log("DxxADADADA", page.data, myInfo);
  if (myInfo.navRoute )
   { x = splitAt(myInfo.navPages, 1);
     owner = myInfo.navRoute;
    } else { 
	  let navPages = import.meta.glob("/src/routes/**/what/*/+page.svelte");
	  x= splitAt( navPages,5);
	  }
  }
  let myId = "component nav";
  console.log("Navpages=",x);
 $: makeButtons($page.data);
</script>

<div class="nav">
  <a role="button" href="/">Home</a>
  {@debug $page}
  {#if $page.data.user}
    <a data-sveltekit-reload role="button" href="/logout">Sign out</a>
   {#if $page.data.user && $page.data.user.admin}
    <a role="button" href="/select">Manage</a>
   {/if}
  {:else}
    <a role="button" href="/register">Sign up</a>
    <a role="button" href="/login">Sign in</a>
  {/if}
  {@debug x }
  {#each x as NP }
    <a role="button" href="/{owner}/{NP}">{NP}</a>
  {/each}
</div>

<style>
  .nav {
    background: #531;
    padding: 1rem;
    grid-area: Nav;
  }
</style>
