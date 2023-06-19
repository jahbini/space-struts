<script>
  export const identifier = "nav";
  import { page } from "$app/stores";
  
  function splitAt(paths,n){
	let x = [];
	for (let text in paths) {
		let t = text.split("/")[n];
		x.push(t);
	};
	   return x;
  } 

  let x = [];
  let owner = "nothing";
  function makeButtons(myInfo){
  if (myInfo.navRoute )
   { x = splitAt(myInfo.navPages, 1);
     owner = myInfo.navRoute;
    } else { 
	  x= [];
	  }
  }
  let myId = "component nav";
 $: makeButtons($page.data);
</script>

<nav>
 <ul>
  <li><a role="button" href="/">Home</a></li>
  </ul>
  <ul>
  {#each x as NP }
    <li><a role="button" href="/{owner}/{NP}">{NP}</a></li>
  {/each}
  </ul>
</nav>

<style>
  nav {
    background: #337;
    padding: 1rem;
    grid-area: Nav;
  }
</style>
