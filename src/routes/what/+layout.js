///Users/jahbini/development/ucoa/space-struts/src/routes/(front)/what

/** {import('./$types').LayoutData}  */
 export function load() {
console.log("WE ARE LOADED!");
   return {navPages: import.meta.glob("./*/+page.svelte"),
	navRoute: "what"}
};
  
