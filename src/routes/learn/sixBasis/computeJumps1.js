// This code generates all single and double steps

const phi = (1 + Math.sqrt(5)) / 2;

const sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
];

// Compute all possible 1-step and 2-step jumps from a given six-base coordinate
function computeJumps(point) {
  if (point.length !== 6) {
    throw new Error("Input must be an array of 6 integers");
  }
  
  let oneStepJumps = [];
  let twoStepJumps = [];
  
  // Compute 1-step jumps by modifying one coordinate at a time
  for (let i = 0; i < 6; i++) {
    let stepUp = [...point];
    let stepDown = [...point];
    stepUp[i] += 1;
    stepDown[i] -= 1;
    oneStepJumps.push(stepUp, stepDown);
  }
  
  // Compute 2-step jumps by modifying two coordinates at a time
  for (let i = 0; i < 6; i++) {
    for (let j = i + 1; j < 6; j++) {
      let stepCombo1 = [...point];
      let stepCombo2 = [...point];
      let stepCombo3 = [...point];
      let stepCombo4 = [...point];
      
      stepCombo1[i] += 1; stepCombo1[j] += 1;
      stepCombo2[i] -= 1; stepCombo2[j] -= 1;
      stepCombo3[i] += 1; stepCombo3[j] -= 1;
      stepCombo4[i] -= 1; stepCombo4[j] += 1;
      
      twoStepJumps.push(stepCombo1, stepCombo2, stepCombo3, stepCombo4);
    }
  }
  
  return { oneStepJumps, twoStepJumps };
}

// Example usage:
console.log(computeJumps([1, 0, -1, 1, 0, 0]));

