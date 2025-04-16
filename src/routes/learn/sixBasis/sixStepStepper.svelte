<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';

  // Exported props: the input vectors and the animation speed (in ms).
  export let inputVectors = [
    [1, null, null, null, null, null],
    [null, 1, null, null, null, null],
    [null, 1, null, null, 2, null],
    [1, null, 3, null, 2, null]
  ];
  export let animationSpeed = 3000;
  export let expanded = false;

  let container;

  // The golden ratio.
  const phi = (1 + Math.sqrt(5)) / 2;

  // Define six basis vectors.
  // Each basis vector represents the normal direction for the corresponding plane.
  const sixBases = [
    [phi, 0, 1],
    [phi, 0, -1],
    [0, 1, phi],
    [0, -1, phi],
    [1, phi, 0],
    [-1, phi, 0]
  ];

  // Fixed color scheme for each basis.
  const basisColors = [
    0xff0000, // red for index 0
    0xff7f00, // orange for index 1
    0xffff00, // yellow for index 2
    0x00ff00, // green for index 3
    0x0000ff, // blue for index 4
    0x8b00ff  // violet for index 5
  ];

  // Utility function to normalize a vector.
  function normalize(v) {
    const len = Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    return [v[0]/len, v[1]/len, v[2]/len];
  }

  // Utility functions for dot and cross products.
  function dot(a, b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
  }
  function cross(a, b) {
    return [
      a[1]*b[2] - a[2]*b[1],
      a[2]*b[0] - a[0]*b[2],
      a[0]*b[1] - a[1]*b[0]
    ];
  }

  // Solve a 3x3 linear system: A x = b.
  // A is an array of 3 arrays (each of length 3) and b is an array of 3 numbers.
  function solve3x3(A, b) {
    const a11 = A[0][0], a12 = A[0][1], a13 = A[0][2];
    const a21 = A[1][0], a22 = A[1][1], a23 = A[1][2];
    const a31 = A[2][0], a32 = A[2][1], a33 = A[2][2];
    const det = a11*(a22*a33 - a23*a32) - a12*(a21*a33 - a23*a31) + a13*(a21*a32 - a22*a31);
    if (Math.abs(det) < 1e-6) return null;
    const invDet = 1 / det;
    const inv = [
      [
        (a22*a33 - a23*a32) * invDet,
        (a13*a32 - a12*a33) * invDet,
        (a12*a23 - a13*a22) * invDet
      ],
      [
        (a23*a31 - a21*a33) * invDet,
        (a11*a33 - a13*a31) * invDet,
        (a13*a21 - a11*a23) * invDet
      ],
      [
        (a21*a32 - a22*a31) * invDet,
        (a12*a31 - a11*a32) * invDet,
        (a11*a22 - a12*a21) * invDet
      ]
    ];
    const x = [
      inv[0][0]*b[0] + inv[0][1]*b[1] + inv[0][2]*b[2],
      inv[1][0]*b[0] + inv[1][1]*b[1] + inv[1][2]*b[2],
      inv[2][0]*b[0] + inv[2][1]*b[1] + inv[2][2]*b[2]
    ];
    return x;
  }

  let scene, camera, renderer, controls;
  let currentInputIndex = 0;

  // Clear all objects from the scene.
  function clearScene() {
    while (scene.children.length > 0) {
      scene.remove(scene.children[0]);
    }
  }

  // Create a full-size circle representing a plane for a given basis index and offset.
  function createPlaneCircle(index, value, radius = 5) {
    const basisVector = sixBases[index];
    const n = normalize(basisVector);
    // Displacement: the point on the plane is given by n * value.
    const displacement = new THREE.Vector3(n[0] * value, n[1] * value, n[2] * value);
    
    const circleGeometry = new THREE.CircleGeometry(radius, 64);
    const circleMaterial = new THREE.MeshBasicMaterial({
      color: basisColors[index],
      side: THREE.DoubleSide,
      opacity: 0.5,
      transparent: true
    });
    const circle = new THREE.Mesh(circleGeometry, circleMaterial);
    
    // Rotate the circle from the default XY plane (normal (0,0,1)) to align with n.
    const defaultNormal = new THREE.Vector3(0, 0, 1);
    const desiredNormal = new THREE.Vector3(n[0], n[1], n[2]);
    const quaternion = new THREE.Quaternion();
    quaternion.setFromUnitVectors(defaultNormal, desiredNormal);
    circle.quaternion.copy(quaternion);
    
    circle.position.copy(displacement);
    return circle;
  }

  // Compute the intersection line of two planes (used in the two-plane case).
  // Each plane is given by normalized normal n and offset d.
  function computeIntersectionLine(n1, d1, n2, d2) {
    const crossVec = cross(n1, n2);
    const crossLengthSq = dot(crossVec, crossVec);
    if (crossLengthSq < 1e-6) return null;
    
    const N1 = new THREE.Vector3(n1[0], n1[1], n1[2]);
    const N2 = new THREE.Vector3(n2[0], n2[1], n2[2]);
    
    const term1 = new THREE.Vector3().copy(N2).multiplyScalar(d1);
    const term2 = new THREE.Vector3().copy(N1).multiplyScalar(d2);
    const diff = new THREE.Vector3().subVectors(term1, term2);
    const N1xN2 = new THREE.Vector3().crossVectors(N1, N2);
    const point = new THREE.Vector3().crossVectors(diff, N1xN2).divideScalar(crossLengthSq);
    const direction = N1xN2.normalize();
    return { point, direction };
  }

  // Main display function for the current input vector.
  function displayCurrentInput() {
    clearScene();
    const currentInput = inputVectors[currentInputIndex];
    const definedPlanes = [];
    
    // Gather defined planes from the input.
    for (let i = 0; i < currentInput.length; i++) {
      if (currentInput[i] !== null) {
        const value = currentInput[i];
        const n = normalize(sixBases[i]);
        definedPlanes.push({ index: i, value, n });
      }
    }
    
    // Case 1: Exactly 3 defined planes.
    if (definedPlanes.length === 3) {
      // Build matrix A and vector b for the system: n · x = d.
      const A = [];
      const b = [];
      for (let i = 0; i < 3; i++) {
        A.push(definedPlanes[i].n);
        b.push(definedPlanes[i].value);
      }
      const intersection = solve3x3(A, b);
      if (intersection === null) {
        console.warn("The three planes do not intersect in a unique point.");
      } else {
        // Draw a marker at the intersection point.
        const markerGeom = new THREE.SphereGeometry(0.2, 16, 16);
        const markerMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
        const marker = new THREE.Mesh(markerGeom, markerMat);
        marker.position.set(intersection[0], intersection[1], intersection[2]);
        scene.add(marker);
        
        // For each of the 6 basis elements:
        // - If defined in the input, draw a full-size circle.
        // - Otherwise, force the plane to contain the intersection and draw a small circle centered there.
        for (let i = 0; i < 6; i++) {
          const n = normalize(sixBases[i]);
          if (currentInput[i] !== null) {
            const circle = createPlaneCircle(i, currentInput[i], 5);
            scene.add(circle);
          } else {
            // Here, we compute the offset required for the plane with normal n
            // to contain the intersection point.
            const computedValue = dot(n, intersection);
            // Instead of placing the circle at n * computedValue,
            // we center the small circle at the intersection to highlight that the plane contains it.
            const smallCircleGeom = new THREE.CircleGeometry(1, 32);
            const smallCircleMat = new THREE.MeshBasicMaterial({
              color: basisColors[i],
              side: THREE.DoubleSide,
              opacity: 0.8,
              transparent: true
            });
            const smallCircle = new THREE.Mesh(smallCircleGeom, smallCircleMat);
            
            const defaultNormal = new THREE.Vector3(0, 0, 1);
            const desiredNormal = new THREE.Vector3(n[0], n[1], n[2]);
            const quaternion = new THREE.Quaternion();
            quaternion.setFromUnitVectors(defaultNormal, desiredNormal);
            smallCircle.quaternion.copy(quaternion);
            
            smallCircle.position.set(intersection[0], intersection[1], intersection[2]);
            scene.add(smallCircle);
          }
        }
      }
    }
    // Case 2: Exactly 2 defined planes.
    else if (definedPlanes.length === 2) {
      definedPlanes.forEach(plane => {
        const circle = createPlaneCircle(plane.index, plane.value, 5);
        scene.add(circle);
      });
      const { n: n1, value: d1 } = definedPlanes[0];
      const { n: n2, value: d2 } = definedPlanes[1];
      const lineData = computeIntersectionLine(n1, d1, n2, d2);
      if (lineData) {
        const { point, direction } = lineData;
        const lineLength = 10;
        const start = new THREE.Vector3().copy(point).add(direction.clone().multiplyScalar(-lineLength / 2));
        const end = new THREE.Vector3().copy(point).add(direction.clone().multiplyScalar(lineLength / 2));
        const lineGeometry = new THREE.BufferGeometry().setFromPoints([start, end]);
        const lineMaterial = new THREE.LineBasicMaterial({
          color: 0xffffff,
          linewidth: 2,
          opacity: 0.8,
          transparent: true
        });
        const line = new THREE.Line(lineGeometry, lineMaterial);
        scene.add(line);
      }
    }
    // Other cases (1 or 0 defined): simply draw each defined plane.
    else {
      for (let i = 0; i < currentInput.length; i++) {
        if (currentInput[i] !== null) {
          const circle = createPlaneCircle(i, currentInput[i], 5);
          scene.add(circle);
        }
      }
    }
  }

  // Cycle to the next input vector.
  function cycleInput() {
    currentInputIndex = (currentInputIndex + 1) % inputVectors.length;
    displayCurrentInput();
  }

  onMount(() => {
    // Set up the Three.js scene.
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x202020);
    camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);
    controls = new OrbitControls(camera, renderer.domElement);
    camera.position.set(0, 0, 15);
    controls.update();

    // Display the first input vector.
    displayCurrentInput();

    // Animation loop.
    function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    // Cycle through input vectors at the specified animation speed.
    setInterval(cycleInput, animationSpeed);
  });
</script>

<style>
  canvas {
    display: block;
  }
</style>

<div bind:this={container} style="width: 100%; height: 600px;"></div>
