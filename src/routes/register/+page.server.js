import { fail, redirect } from "@sveltejs/kit";
import { createUser } from "$lib/server/database.js";
// direectory space-struts/src/routes/register

/** @type {import('./$types').PageServerLoad} */
export async function load({ params ,cookies }) {
  const userId = cookies.get("userId");
	if (userId) {
		throw redirect(302,"/");
	}
  console.log("in PageServerLoad Params", params);
  return {
    image: "KWOW, something",
    moreData: "JAH2"
  };
}
console.log("dot server js has entered the building");
export const actions = {
  async create({ request, cookies }) {
    const data = await request.formData();
    const username = data.get("username");
    const password1 = data.get("password");
    const password2 = data.get("confirmPassword");
    const email = data.get("email");
    // form validation
    if (password1 !== password2) {
      return fail(422, {
        error: "Passwords do not match"
      });
    }

    // create user
    const userId = await createUser({
      username,
      password: password1,
      email
    });

    // set cookie
    cookies.set("userId", userId);
    // redirect to home page
    throw redirect(302, "/");
  }
};

console.log("ACTIONS ON REGISTER", JSON.stringify(actions), actions);
