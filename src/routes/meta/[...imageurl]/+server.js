import { error, json } from "@sveltejs/kit";
//import { isLeft } from 'fp-ts/lib/Either.js';
//import * as t from 'io-ts';
//import { PathReporter } from 'io-ts/lib/PathReporter.js';

//import { PositiveInt } from '../../types';
import { POST } from "./+server.js";

/** @type {import('./$types').PageServerLoad} */
export async function load({ params }) {
  console.log("in PageServerLoad Params", params);
  return {
    someInfo: "JAH"
  };
}
