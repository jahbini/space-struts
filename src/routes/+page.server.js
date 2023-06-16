// /Users/jahbini/development/ucoa/space-struts/src/routes/page.server.js
import { getUserById } from "$lib/server/database.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ cookies }) {
  const pageData = {
	navRoute: ".",
        navPages: {
          "/what/":"what",
          "/how/": "how",
          "/why/":"why",
          "/what-if/":"wuzza"
          }, 
        user: null,
        images: [
          'IMG_0671.jpeg', 'IMG_1183.jpeg', 'IMG_1297.jpeg', 'IMG_1332.jpeg',
          'IMG_1971.jpeg', 'IMG_1972.jpeg', 'IMG_2005.jpeg', 'IMG_2006.jpeg',
          'IMG_2227.jpeg', 'IMG_2228.jpeg', 'IMG_2229.jpeg', 'IMG_2230.jpeg',
          'IMG_2256.jpeg', 'IMG_2257.jpeg', 'IMG_2258.jpeg', 'IMG_2259.jpeg',
          'IMG_2260.jpeg', 'IMG_2261.jpeg', 'IMG_2262.jpeg', 'IMG_2285.jpeg',
          'IMG_2292.jpeg', 'IMG_2300.jpeg', 'IMG_2307.jpeg', 'IMG_2314.jpeg',
          'IMG_2315.jpeg', 'IMG_2316.jpeg', 'IMG_2317.jpeg', 'IMG_2318.jpeg',
          'IMG_2319.jpeg', 'IMG_2320.jpeg', 'IMG_2321.jpeg', 'IMG_2322.jpeg',
          'IMG_2325.jpeg', 'IMG_2332.jpeg', 'IMG_2333.jpeg', 'IMG_2370.jpeg',
          'IMG_2371.jpeg', 'IMG_2375.jpeg', 'IMG_2376.jpeg', 'IMG_2377.jpeg',
          'IMG_2378.jpeg', 'IMG_2379.jpeg', 'IMG_2380.jpeg', 'IMG_2383.jpeg',
          'IMG_2385.jpeg', 'IMG_2386.jpeg', 'IMG_2387.jpeg', 'IMG_2388.jpeg',
          'IMG_2389.jpeg', 'IMG_2390.jpeg', 'IMG_2391.jpeg', 'IMG_2392.jpeg',
          'IMG_2393.jpeg', 'IMG_2394.jpeg', 'IMG_2395.jpeg', 'IMG_2396.jpeg',
          'IMG_2397.jpeg', 'IMG_2398.jpeg', 'IMG_2399.jpeg', 'IMG_2400.jpeg',
          'IMG_2401.jpeg', 'IMG_2402.jpeg', 'IMG_2403.jpeg', 'IMG_2404.jpeg',
          'IMG_2405.jpeg', 'IMG_2406.jpeg', 'IMG_2407.jpeg', 'IMG_2408.jpeg',
          'IMG_2409.jpeg', 'IMG_2410.jpeg', 'IMG_2411.jpeg', 'IMG_2412.jpeg',
          'IMG_2413.jpeg', 'IMG_2414.jpeg', 'IMG_2415.jpeg', 'IMG_2416.jpeg',
          'IMG_2417.jpeg', 'IMG_2418.jpeg', 'IMG_2428.jpeg', 'IMG_2429.jpeg',
          'IMG_2430.jpeg', 'IMG_2431.jpeg', 'IMG_2439.jpeg', 'IMG_2441.jpeg',
          'IMG_2447.jpeg', 'IMG_2496.jpeg', 'IMG_2533.jpeg', 'IMG_2540.jpeg',
          'IMG_2544.jpeg', 'IMG_2545.jpeg', 'IMG_2546.jpeg', 'IMG_2549.jpeg'
          ]
          };
  
  const userId = cookies.get("userId") || null;
  console.log("Main page server USERRID :", userId);
  if (userId) {
	  const user = await getUserById(userId);
	  if (user) {
	    pageData.user=user;
	  } else {
		 cookies.set("userId",null);
		}
	}
  return pageData;
}
