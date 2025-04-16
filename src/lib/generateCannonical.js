// generateCanonicalData.js
import * as THREE from 'three';
const phi = (1 + Math.sqrt(5)) / 2;
const Q = phi + 2; // Norm² for each basis vector

// Six basis vectors as defined in the patent.
const sixBases = [
  [phi,0,1],
  [phi,0,-1],
  [0,1,phi],
  [0,-1,phi],
  [1,phi,0],
  [-1,phi,0]
];

// Solve a 3x3 system A*x=b.
function solve3x3(A,b) {
  const [a11,a12,a13] = A[0], [a21,a22,a23] = A[1], [a31,a32,a33] = A[2];
  const det = a11*(a22*a33 - a23*a32) - a12*(a21*a33 - a23*a31) + a13*(a21*a32 - a22*a31);
  if(Math.abs(det)<1e-6)return null;
  const invDet = 1/det;
  const inv = [
    [(a22*a33 - a23*a32)*invDet, (a13*a32 - a12*a33)*invDet, (a12*a23 - a13*a22)*invDet],
    [(a23*a31 - a21*a33)*invDet, (a11*a33 - a13*a31)*invDet, (a13*a21 - a11*a23)*invDet],
    [(a21*a32 - a22*a31)*invDet, (a12*a31 - a11*a32)*invDet, (a11*a22 - a12*a21)*invDet]
  ];
  return [
    inv[0][0]*b[0]+inv[0][1]*b[1]+inv[0][2]*b[2],
    inv[1][0]*b[0]+inv[1][1]*b[1]+inv[1][2]*b[2],
    inv[2][0]*b[0]+inv[2][1]*b[1]+inv[2][2]*b[2]
  ];
}

// Complete a partially specified 6-vector (with some entries as numbers, others null)
// by using the first three specified indices to solve for the unique intersection P,
// then filling in missing entries as: v[i] = round((P·b_i)/|b_i|²).
function completePartialVector(vPartial) {
  let indices = [];
  for(let i=0;i<6;i++){
    if(vPartial[i]!=null) indices.push(i);
  }
  if(indices.length<3) throw new Error("At least 3 values required.");
  let A=[], b=[];
  for(let k=0;k<3;k++){
    const i = indices[k];
    const bi = sixBases[i];
    const norm2 = bi[0]*bi[0]+bi[1]*bi[1]+bi[2]*bi[2];
    A.push(bi);
    b.push(vPartial[i]*norm2);
  }
  const P = solve3x3(A,b);
  if(P===null) throw new Error("No unique intersection.");
  let vComplete = vPartial.slice();
  for(let i=0;i<6;i++){
    if(vComplete[i]==null){
      const bi = sixBases[i];
      const norm2 = bi[0]*bi[0]+bi[1]*bi[1]+bi[2]*bi[2];
      const dotP = P[0]*bi[0]+P[1]*bi[1]+P[2]*bi[2];
      vComplete[i] = Math.round(dotP/norm2);
    }
  }
  return { v: vComplete, P: P };
}

// Generate canonical one-step candidates.
// For each of the three pairs [0,1], [2,3], [4,5] choose one index and assign ±1.
function generateOneStepCandidates() {
  let candidates = [];
  const vals = [1,-1];
  for(let i0 of [0,1]){
    for(let i1 of [2,3]){
      for(let i2 of [4,5]){
        for(let s0 of vals){
          for(let s1 of vals){
            for(let s2 of vals){
              let candidate = [null,null,null,null,null,null];
              candidate[i0] = s0;
              candidate[i1] = s1;
              candidate[i2] = s2;
              try { candidates.push(completePartialVector(candidate)); }
              catch(e){}
            }
          }
        }
      }
    }
  }
  let unique = new Map();
  candidates.forEach(obj=>{ unique.set(obj.v.join(','),obj); });
  return Array.from(unique.values());
}

// Generate canonical two-step candidates by summing pairs of one-step moves.
function generateTwoStepCandidates(oneSteps) {
  let candidates = [];
  for(let i=0;i<oneSteps.length;i++){
    for(let j=i;j<oneSteps.length;j++){
      let sum = oneSteps[i].v.map((val,k)=> val+oneSteps[j].v[k]);
      try { candidates.push(completePartialVector(sum.slice())); }
      catch(e){}
    }
  }
  let unique = new Map();
  candidates.forEach(obj=>{ unique.set(obj.v.join(','),obj); });
  return Array.from(unique.values());
}

// Patent conversion: Given a six-vector v = [a,b,c,d,e,f],
// compute Cartesian coordinates:
// x = φ*(a+b) + (e-f)
// y = (c-d) + φ*(e+f)
// z = (a-b) + φ*(c+d)
function sixToCartesian(v) {
  const [a,b,c,d,e,f] = v;
  return [phi*(a+b)+(e-f), (c-d)+phi*(e+f), (a-b)+phi*(c+d)];
}

// Compute golden triangles from canonical points.
// Points is an array of objects with property v.
// For each triple, convert to Cartesian (using sixToCartesian) and check if the triangle is isosceles
// with long-to-short edge ratio approximating φ (or its reciprocal). Each triangle is stored as a sorted array of keys.
function computeGoldenTriangles(points, tolRatio=0.05) {
  let pts = points.map(obj=>{
    let key = obj.v.join(',');
    let P = obj.P ? obj.P : sixToCartesian(obj.v);
    return { key, P };
  });
  let triangles = [];
  const n = pts.length;
  for(let i=0;i<n;i++){
    for(let j=i+1;j<n;j++){
      for(let k=j+1;k<n;k++){
        const P1 = new THREE.Vector3(...pts[i].P);
        const P2 = new THREE.Vector3(...pts[j].P);
        const P3 = new THREE.Vector3(...pts[k].P);
        const d12 = P1.distanceTo(P2);
        const d23 = P2.distanceTo(P3);
        const d31 = P3.distanceTo(P1);
        let shortEdge, longEdge;
        if(Math.abs(d12-d31)<0.1*d12){ shortEdge=d12; longEdge=d23; }
        else if(Math.abs(d12-d23)<0.1*d12){ shortEdge=d12; longEdge=d31; }
        else if(Math.abs(d23-d31)<0.1*d23){ shortEdge=d23; longEdge=d12; }
        else continue;
        const ratio = longEdge/shortEdge;
        if(Math.abs(ratio-phi)/phi < tolRatio || Math.abs((1/ratio)-phi)/phi < tolRatio){
          let tri = [pts[i].key, pts[j].key, pts[k].key].sort();
          triangles.push(tri);
        }
      }
    }
  }
  let unique = new Map();
  triangles.forEach(tri=>{ unique.set(tri.join('|'),tri); });
  return Array.from(unique.values());
}

// MAIN EXECUTION
function main() {
  const oneSteps = generateOneStepCandidates();
  const twoSteps = generateTwoStepCandidates(oneSteps);
  // Merge one-step and two-step moves (deduplicate by canonical six-vector string).
  let allPointsMap = new Map();
  oneSteps.concat(twoSteps).forEach(obj=>{
    allPointsMap.set(obj.v.join(','), obj);
  });
  const allPoints = Array.from(allPointsMap.values());
  // Prepare points object (do not include Cartesian values).
  let pointsObj = {};
  allPoints.forEach(obj=>{
    pointsObj[obj.v.join(',')] = { v: obj.v };
  });
  // Compute golden triangles from allPoints.
  const triangles = computeGoldenTriangles(allPoints);
  let trianglesObj = {};
  triangles.forEach(tri=>{
    trianglesObj[tri.join('|')] = tri;
  });
  const data = { points: pointsObj, triangles: trianglesObj };
  process.stdout.write(JSON.stringify(data) + "\n");
}

main();
