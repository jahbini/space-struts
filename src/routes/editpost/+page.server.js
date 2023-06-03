import { error, json } from "@sveltejs/kit";
import { error, json } from "@sveltejs/kit";
import { getImageByURL, getUserById } from "$lib/server/database.js";
//
/** @type {import('./$types').PageServerLoad} */
export async function load({ params, cookies }) {
  console.log("in PageServerLoad Params", params);
  const userId = cookies.get("userId");
  const user = { username: "bubba bo bob brain" };
  if (userId != "undefined") {
    const who = await getUserById(userId);
    if (who != "undefined") {
      user.username = who.username;
    } else user.username = "error";
  }
  return {
    user,
    image: await getImageByURL(params),
    moreData: "JAH2"
  };
}
import { fail, redirect } from "@sveltejs/kit";
import { setImage } from "$lib/server/database.js";

export const actions = {
  async create({ request, cookies }) {
    const data = await request.formData();
    const photoURL = data.get("photoURL");
    const tags = data.get("tags");
    const headline = data.get("headline");
    const photoDescription = data.get("photoDescription");
    const update = await setImage({ tags, photoURL, headline, photoDescription });
    if (!update) {
      return fail(422, {
        error: "sorry, some error occurred"
      });
    }

    throw redirect(302, "/");
  }
};
4;
