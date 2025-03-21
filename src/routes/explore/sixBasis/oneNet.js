const phi = (1 + Math.sqrt(5)) / 2;

const sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
];

/**
 * Generates all reachable vertices within a 10x10x10 jump cube.
 * @param {number} maxJumps - The maximum number of jumps allowed.
 * @returns {Array} A list of Cartesian coordinate points.
 */
function generateVertices(maxJumps) {
  let visited = new Set();
  let queue = [[0, 0, 0, 0, 0, 0]];
  visited.add(JSON.stringify(queue[0]));

  for (let step = 0; step < maxJumps; step++) {
    let newQueue = [];

    for (let vertex of queue) {
      for (let i = 0; i < 6; i++) {
        let newVertex1 = [...vertex];
        let newVertex2 = [...vertex];
        newVertex1[i] += 1;
        newVertex2[i] -= 1;

        if (!visited.has(JSON.stringify(newVertex1))) {
          visited.add(JSON.stringify(newVertex1));
          newQueue.push(newVertex1);
        }
        if (!visited.has(JSON.stringify(newVertex2))) {
          visited.add(JSON.stringify(newVertex2));
          newQueue.push(newVertex2);
        }
      }
    }
    queue = newQueue;
  }

  return Array.from(visited).map(v => JSON.parse(v).map((val, index) => 
    val * sixBases[index % 6][index % 3]
  ));
}

// Generate all vertices within 10 jumps
const vertices = generateVertices(10);

// D3.js visualization
const width = 800, height = 800;
const svg = d3.select("body").append("svg")
  .attr("width", width)
  .attr("height", height);

const g = svg.append("g")
  .attr("transform", `translate(${width / 2}, ${height / 2})`);

// Scale and axis setup
const scale = d3.scaleLinear().domain([-10, 10]).range([0, width]);

g.selectAll("circle")
  .data(vertices)
  .enter().append("circle")
  .attr("cx", d => scale(d[0]))
  .attr("cy", d => scale(d[1]))
  .attr("r", 2)
  .attr("fill", "blue");

// Add zoom and pan behavior
d3.select("svg").call(d3.zoom()
  .scaleExtent([0.5, 5])
  .on("zoom", (event) => {
    g.attr("transform", event.transform);
  }));

console.log("D3 visualization created with 1-jump expansion structure.");

