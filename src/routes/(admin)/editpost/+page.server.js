import { error, json } from "@sveltejs/kit";
import { getArticleBySlug, getUserById } from "$lib/server/database.js";
//
/** @type {import('./$types').PageServerLoad} */
export async function load({ url, cookies }) {
  let articleData = {
		  slug:"make me unique",
		  published: false,
		  headline: "catch their attention!",
		  tags:"space-struts,...",
		  summary:"what's it all about",
		  text:"spill the beans..."
	}
  console.log("in Manage PageServerLoad set stage for articles",  url);
  // guard this page from casual eyes
  const userId = cookies.get("userId");
  if (userId != "undefined") {
    const user = await getUserById(userId);
    try {
	  if (!user.admin) { throw redirect(302, "/"); }
	  if (url.search != '?new') {
	articleData = getArticleBySlug(url.search.slice(1));
	}
    }
    catch { cookies.delete("userId"); throw redirect(302, "/"); }

  return {
    //it has to work when the article list is empty
    user:user,
    article:articleData
   } 
  
}
}

