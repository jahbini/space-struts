const phi = (1 + Math.sqrt(5)) / 2;

const sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
];

function computeJumps() {
  const jumps1Step = [];
  const jumps2Step = [];
  
  // Generate all 1-step jumps (changing one coordinate by ±1)
  for (let i = 0; i < 6; i++) {
    let jumpPos = new Array(6).fill(0);
    let jumpNeg = new Array(6).fill(0);
    jumpPos[i] = 1;
    jumpNeg[i] = -1;
    jumps1Step.push(jumpPos);
    jumps1Step.push(jumpNeg);
  }
  
  // Generate all 2-step jumps (changing two coordinates by ±1)
  for (let i = 0; i < 6; i++) {
    for (let j = i + 1; j < 6; j++) {
      let jump1 = new Array(6).fill(0);
      let jump2 = new Array(6).fill(0);
      let jump3 = new Array(6).fill(0);
      let jump4 = new Array(6).fill(0);
      
      jump1[i] = 1; jump1[j] = 1;
      jump2[i] = -1; jump2[j] = -1;
      jump3[i] = 1; jump3[j] = -1;
      jump4[i] = -1; jump4[j] = 1;
      
      jumps2Step.push(jump1);
      jumps2Step.push(jump2);
      jumps2Step.push(jump3);
      jumps2Step.push(jump4);
    }
  }
  
  return { jumps1Step, jumps2Step };
}

console.log(computeJumps());

