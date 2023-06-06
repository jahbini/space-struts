import { error, json } from "@sveltejs/kit";
//import { isLeft } from 'fp-ts/lib/Either.js';
//import * as t from 'io-ts';
//import { PathReporter } from 'io-ts/lib/PathReporter.js';

//import { PositiveInt } from '../../types';
import { getImageByURL, getUserById } from "$lib/server/database.js";

import { fail, redirect } from "@sveltejs/kit";
import { setImage } from "$lib/server/database.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ params, cookies }) {
  console.log("in PageServerLoad Params", params);
  const userId = cookies.get("userId");
  let user;
  if (userId != "undefined") {
    user = await getUserById(userId);
    try {
          if (!user.admin) { throw redirect(302, "/"); }
	}
    catch { cookies.delete("userId"); throw redirect(302, "/"); }
  }
  else {
    cookies.delete("userId"); 
    throw redirect(302, "/");
	}
  return {
    user,
    image: await getImageByURL(params),
    moreData: "JAH2"
  };
}

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
