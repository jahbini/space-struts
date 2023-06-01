import { fail, redirect } from "@sveltejs/kit";
import { loginUser } from "$lib/server/database.js";

export const actions = {
  async login({ request, cookies }) {
    const data = await request.formData();
    console.log("data from login form:",data);
    const password = data.get("password");
    const email = data.get("email");
    // form validation

    // create user
    const user = await loginUser({ email, password });
    if ( user == "undefined" ){
	return fail(422, {
		error: "Invalid login"
	});
  }
    console.log("Got the sucka:" , user);
    if (user) {
      // set cookie
      cookies.set("userId", user.id);
      // redirect to home page
      throw redirect(302, "/");
    };
	return fail(422, {
		error: "Invalid login"
	});
    }
};
