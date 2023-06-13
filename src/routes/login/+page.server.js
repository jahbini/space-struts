import { fail, redirect } from "@sveltejs/kit";
import { loginUser } from "$lib/server/database.js";
// directory ucoa/space-struts/src/routes/login

/** @type {import('./$types').PageServerLoad} */
export async function load({ params, cookies }) {
  const userId = cookies.get("userId");
  if (userId) {
    throw redirect(302, "/");
  }
  console.log("in PageServerLoad Params", params);
  return {
    image: "wSome hot stuff",
    moreData: "JAH2"
  };
}
export const actions = {
  async login({ request, cookies }) {
    const data = await request.formData();
    console.log("data from login form:", data);
    const password = data.get("password");
    const email = data.get("email");
    // form validation

    // create user
    const user = await loginUser({ email, password });
    if (user == "undefined") {
      return fail(422, {
        error: "Invalid login"
      });
    }
    console.log("Got the sucka:", user);
    if (user) {
      // set cookie
      cookies.set("userId", user.id);
      // redirect to home page
      throw redirect(302, "/");
    }
    return fail(422, {
      error: "Invalid login"
    });
  }
};
