import { error, json } from "@sveltejs/kit";
//import { isLeft } from 'fp-ts/lib/Either.js';
//import * as t from 'io-ts';
//import { PathReporter } from 'io-ts/lib/PathReporter.js';

//import { PositiveInt } from '../../types';
import { fail, redirect } from "@sveltejs/kit";
import { createUser } from "$lib/server/database.js";
console.log(" dot server js has entered the building");

export const actions = {
  async create({ request, cookies }) {
    console.log("in form create?", request);
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
