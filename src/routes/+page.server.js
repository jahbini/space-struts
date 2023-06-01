import { getUserById } from "$lib/server/database.js";

export async function load({ cookies }) {
  const userId = cookies.get("userId");
  if ( userId == 'undefined')
	{
		return  { user:{ username:"bubba bo bob brain" }  };
	}

  const user = await getUserById(userId);
  if (user != 'undefined') {
  return { user };
  } else return {user:"error" };
}
