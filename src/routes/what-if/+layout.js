// /Users/jahbini/development/ucoa/space-struts/src/routes/(front)/what-if
/** {import('./$types').LayoutData}  */
export function load() {
  return { navPages: import.meta.glob("./*/+page.svelte"), navRoute: "what-if" };
}
