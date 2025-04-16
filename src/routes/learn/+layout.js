/** {import('./$types').LayoutData}  */
export function load() {
  return { navPages: import.meta.glob("./*/+page.sv*"), navRoute: "learn" };
}
