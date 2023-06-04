import { error, json } from "@sveltejs/kit";
import { getAllArticles, getUserById } from "$lib/server/database.js";
//
/** @type {import('./$types').PageServerLoad} */
export async function load({ params, cookies }) {
  console.log("in Manage PageServerLoad list All Articles", params);
  // guard this page from casual eyes
  const userId = cookies.get("userId");
  if (userId != "undefined") {
    const user = await getUserById(userId);
    try {
	  if (!user.admin) { throw redirect(302, "/"); }
}
    catch { cookies.delete("userId"); throw redirect(302, "/"); }
  return {
    //it has to work when the article list is empty
    user:user,
    articles:[]
   } 
  
}
}

