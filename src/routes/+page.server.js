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
        user: null
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
