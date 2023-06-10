
/** {import('./$types').LayoutData}  */
 export function load() {
   return {navPages: import.meta.glob("./*/+page.svelte"),
		navRoute: "why"}
};
  
