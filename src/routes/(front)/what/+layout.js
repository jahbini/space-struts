
/** {import('./$types').LayoutData}  */
 export function load() {
console.log("WE ARE LOADED!");
   return {navPages: import.meta.glob("./*/+page.svelte"),
	navPage: "what"}
};
  
