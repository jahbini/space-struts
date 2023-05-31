import { fail, redirect } from "@sveltejs/kit";

export const actions = {
  async login({ request, cookies }) {
    const data = await request.formData();
    const password = data.get("password");
    const email = data.get("email");
    // form validation

    // create user
    const user = await loginUser({ email, password });
    console.log(user);
    if (user) {
      // set cookie
      cookies.set("userId", user.id);
      // redirect to home page
      throw redirect(302, "/");
    }
  }
};
