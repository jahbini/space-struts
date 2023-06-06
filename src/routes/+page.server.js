import { getUserById } from "$lib/server/database.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ cookies }) {
  const userId = cookies.get("userId") || null;
  console.log("Main page server USERRID :", userId);
  if (!userId) {
    return { user: null };
  }

  const user = await getUserById(userId);
  if (user) {
    return { user };
  } else return { user: null };
}
