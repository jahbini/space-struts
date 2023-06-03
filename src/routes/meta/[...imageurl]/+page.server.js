import { error, json } from "@sveltejs/kit";
//import { isLeft } from 'fp-ts/lib/Either.js';
//import * as t from 'io-ts';
//import { PathReporter } from 'io-ts/lib/PathReporter.js';

//import { PositiveInt } from '../../types';
import { getImageByURL, POST } from "$lib/server/database.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ params }) {
  console.log("in PageServerLoad Params", params);
  return {
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
