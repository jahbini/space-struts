// tilePlaneEngine.js (used by /learn/hullTwo)

import { PhiBase } from '$lib/phiBase.js';
import { loadFaces } from './loadFacesHelper.js';

// Triangle queue
let triangleQueue = [];
let placedEdges = new Set();
let currentScale = 1; // Start at phi^30 scale
let symbolToVec = {};

function encodeEdge(p1, p2) {
  return [p1.toString(), p2.toString()].sort().join('|');
}

export async function resetTiling() {
  triangleQueue = [];
  placedEdges = new Set();
  currentScale = 1;

  symbolToVec = await loadFaces();

  // Use the square face for seed triangle (first 3 points)
  const seed = ['#ffz', '#Ffz', '#FFz'].map(id => symbolToVec[id]);
  console.log(" Adding stuff to ???");
  debugger;
  triangleQueue.push(seed);
  placedEdges.add(encodeEdge(seed[0], seed[1]));
  placedEdges.add(encodeEdge(seed[1], seed[2]));
  placedEdges.add(encodeEdge(seed[2], seed[0]));
}

export function nextTriangle() {
  console.log("nextTriangles", triangleQueue);
  if (triangleQueue.length === 0) return null;
  const tri = triangleQueue.shift();

  // Convert phiBase 6-vectors to Cartesian
  const scale = Math.pow(PhiBase.PHI, currentScale);
  const triFloatArray = tri.map(v => {
    const f = v.toFloatArray();
    return [f[0] * scale, f[1] * scale, f[2] * scale];
  });
  return triFloatArray;
}

