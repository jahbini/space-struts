import { error, json } from "@sveltejs/kit";
//import { isLeft } from 'fp-ts/lib/Either.js';
//import * as t from 'io-ts';
//import { PathReporter } from 'io-ts/lib/PathReporter.js';

//import { PositiveInt } from '../../types';
import { getImageByURL } from "$lib/server/database.js";
//import {actions } from "./+server.js"

try {
console.log("And what is actions anyhoo?",actions);
}
catch {
	console.log("AINT no actions nowhow");
}
/** @type {import('./$types').Actions} */
export const actions = {
	POST: async (event) => {
	console.log("IS this the POST event???",event);
	},
	default: async (event) => {
	console.log("IS this the DEFAULT event???",event);
	},
	create: async (event) => {
	console.log("IS this the CREATE event???",event);
	}
};

/** @type {import('./$types').PageServerLoad} */
export async function load({ params }) {
  console.log("in PageServerLoad Params", params);
  return {
    image: await getImageByURL(params)
  };
}
