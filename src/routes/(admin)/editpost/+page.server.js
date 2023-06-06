import { error, json,fail, redirect } from "@sveltejs/kit";
import { getArticleById, putArticleById, getUserById } from "$lib/server/database.js";
//
/** @type {import('./$types').PageServerLoad} */
export async function load({ url, cookies }) {
  let articleData = {
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
console.log("Must be admin user",user);
    try {
console.log("must be ?new or a number  ",url.searchParams);

	  if (!user.admin) { throw redirect(302, "/"); }
          let article = url.searchParams.get('article');
console.log("what is article??",article);

	articleData = getArticleById({id:article,...articleData});
	}
    catch { cookies.delete("userId"); throw redirect(302, "/"); }

  return {
    //it has to work when the article list is empty
    user:user,
    article:articleData
   }
}
}

export const actions = {
  async default({ request, cookies }) {
    const data = await request.formData();
    const summary = data.get("summary");
    const text = data.get("text");
    const tags = data.get("tags");
    const headline = data.get("headline");
    const published = data.get("published");
    const id = data.get("id")
    console.log("formData??",id,published,headline,tags,text,summary,"That is all...");
    const update = await putArticleById({ id,tags,  headline, text, summary, published });
    if (!update) {
      return fail(422, {
        error: "sorry, some error occurred"
      });
    }
    throw redirect(302,"/editpost?article="+id);
  }
};
