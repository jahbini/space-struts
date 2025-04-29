// loadFacesHelper.js

import { PhiBase } from '$lib/phiBase';
import { SixPhiVector } from '$lib/sixPhi';

const symbolToVector = {};

/**
 * Convert a string like "p1,-1" to a PhiBase
 * @param {string} str
 * @returns {PhiBase}
 */
function parsePhiString(str) {
  const [pRaw, nRaw] = str.replace('p', '').split(',');
  return new PhiBase(parseInt(pRaw), parseInt(nRaw));
}

/**
 * Convert a set of 3 phi strings to a SixPhiVector
 * @param {string[]} coords
 * @returns {SixPhiVector|null}
 */
function decodeCoords(coords) {
  if (!Array.isArray(coords) || coords.length !== 3) return null;
  const decoded = coords.map(parsePhiString);
  return new SixPhiVector(decoded);
}

/**
 * Load and cache preapproved faces from /faces.json
 * @returns {Promise<Object<string, SixPhiVector>>}
 */
export async function loadFaces() {
  if (Object.keys(symbolToVector).length > 0) return symbolToVector; // already loaded

  const res = await fetch('/faces.json');
  const json = await res.json();

  for (const [symbol, entry] of Object.entries(json.points)) {
    const coords = decodeCoords(entry.coords);
    if (coords && coords.isComplete) {
      symbolToVector[symbol] = coords;
    }
  }

  return symbolToVector;
}

