import { getUserById } from "$lib/server/database.js";
import { fail, redirect } from "@sveltejs/kit";

/** @type {import('./$types').PageServerLoad} */
export async function load({ cookies }) {
  /* @migration task: add path argument */ cookies.delete("userId");
  console.log("Deleting user");
  redirect(302, "/");
}
