import { getUserById } from "$lib/server/database.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ cookies }) {
  const userId = cookies.get("userId") || null;
	console.log("USERRID :",userId);
  if (!userId) {
    return { user: null};
  }

  const user = await getUserById(userId);
  if (user != "undefined") {
    return { user };
  } else return { user: "error" };
}
