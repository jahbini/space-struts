import { getUserById } from "$lib/server/database.js";
import { fail, redirect } from "@sveltejs/kit";

/** @type {import('./$types').PageServerLoad} */
export async function load({ cookies }) {
  cookies.delete("userId");
	console.log("Deleting user");
	throw redirect (302,"/");
}
