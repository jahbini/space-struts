<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
//  import GeoSixPhi from '$lib/coffee/geoSixPhi.coffee';
  import {PhiBase, PHI}  from '$lib/coffee/phiBase.coffee';

  let container;

  debugger
  console.log("phibase",PhiBase);
  // Golden ratio and related constant.
  const phi = PhiBase.PHI;
  const Q = phi + 2; // |b|^2 for any of our six basis vectors.

  /* 
     Six basis vectors as defined in the patent:
       B₁ = [ φ,  0,  1 ]
       B₂ = [ φ,  0, -1 ]
       B₃ = [ 0,  1,  φ ]
       B₄ = [ 0, -1,  φ ]
       B₅ = [ 1,  φ,  0 ]
       B₆ = [ -1, φ,  0 ]
  */
  const sixBases = [
    [phi, 0, 1],
    [phi, 0, -1],
    [0, 1, phi],
    [0, -1, phi],
    [1, phi, 0],
    [-1, phi, 0]
  ];

  // Mapping from a Cartesian point P = [x, y, z] to its six‑vector address:
  //   v_i = (P · b_i)/Q for i=0,...,5.
  function PtoSixVector(P) {
    return sixBases.map(b => {
      const dot = P[0]*b[0] + P[1]*b[1] + P[2]*b[2];
      return dot / Q;
    });
  }

  // Legal addresses are those where each component is (nearly) an integer.
  function isLegalAddress(v, tol = 0.05) {
    return v.every(component => Math.abs(component - Math.round(component)) < tol);
  }

  // Round a six‑vector to integers.
  function roundSixVector(v) {
    return v.map(component => Math.round(component));
  }

  // Brute‑force search over a Cartesian grid.
  // Returns a Map of legal addresses: key is the rounded six‑vector as a string,
  // value is an object { v: [six‑vector], P: [x,y,z] }.
  function computeLegalAddresses() {
    let addresses = new Map();
    const range = 20;
    const step = 0.5;
    for (let x = -range; x <= range; x += step) {
      for (let y = -range; y <= range; y += step) {
        for (let z = -range; z <= range; z += step) {
          const P = [x, y, z];
          const v = PtoSixVector(P);
          if (isLegalAddress(v, 0.05)) {
            const vRounded = roundSixVector(v);
            const key = vRounded.join(',');
            console.log("p to six vector OK:",P,v);
            addresses.set(key, { v: vRounded, P: P });
          }
        }
      }
    }
    console.log("Number of new points",addresses.length);
    return addresses;
  }

  // The forward mapping from six‑vector to Cartesian, as given in the patent:
  //   x = φ*(a+b) + (e-f)
  //   y = (c-d) + φ*(e+f)
  //   z = (a-b) + φ*(c+d)
  function sixToCartesian(v) {
    const [a, b, c, d, e, f] = v;
    const x = phi * (a + b) + (e - f);
    const y = (c - d) + phi * (e + f);
    const z = (a - b) + phi * (c + d);
    return new THREE.Vector3(x, y, z);
  }

  // Compute golden triangles from legal addresses.
  // We convert each legal address to a THREE.Vector3 (via sixToCartesian)
  // and then loop over triples, accepting triangles that are isosceles and
  // whose edge ratio approximates the golden ratio.
  function computeGoldenTriangles(addresses, tolRatio = 0.05) {
    const points = [];
    addresses.forEach(item => {
      points.push({ v: item.v, P: sixToCartesian(item.v) });
    });
    const triangles = [];
    const n = points.length;
    console.log("input Number of points",n);
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        for (let k = j + 1; k < n; k++) {
          const P1 = points[i].P, P2 = points[j].P, P3 = points[k].P;
          const d12 = P1.distanceTo(P2);
          const d23 = P2.distanceTo(P3);
          const d31 = P3.distanceTo(P1);
          // Identify candidate isosceles triangle.
          let short, long;
          if (Math.abs(d12 - d31) < 0.1*d12) {
            short = d12; long = d23;
          } else if (Math.abs(d12 - d23) < 0.1*d12) {
            short = d12; long = d31;
          } else if (Math.abs(d23 - d31) < 0.1*d23) {
            short = d23; long = d12;
          } else {
            continue;
          }
          // Check if ratio is approximately φ (or its reciprocal).
          const ratio = long / short;
          if (Math.abs(ratio - phi)/phi < tolRatio || Math.abs((1/ratio) - phi)/phi < tolRatio) {
            triangles.push([points[i].v, points[j].v, points[k].v]);
          }
        }
      }
    }
    console.log("Number of triangles",triangles.length);
    return triangles;
  }

  // Three.js scene variables.
  let scene, camera, renderer, controls;

  // Draw a small sphere marker at point P.
  function placeMarker(P, color = 0x00ffff, radius = 0.3) {
    const geom = new THREE.SphereGeometry(radius, 16, 16);
    const mat = new THREE.MeshBasicMaterial({ color });
    const marker = new THREE.Mesh(geom, mat);
    marker.position.copy(P);
    scene.add(marker);
  }

  // Draw an edge (line) between points P and Q.
  function drawLine(P, Q, color = 0xEEDC82) {
    const geom = new THREE.BufferGeometry().setFromPoints([P, Q]);
    const mat = new THREE.LineBasicMaterial({ color, linewidth: 2 });
    const line = new THREE.Line(geom, mat);
    scene.add(line);
  }

  onMount(() => {
    // Set up Three.js scene.
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x000000);
    camera = new THREE.PerspectiveCamera(
      75,
      container.clientWidth / container.clientHeight,
      0.1,
      1000
    );
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);
    controls = new OrbitControls(camera, renderer.domElement);
    camera.position.set(0, 0, 50);
    controls.update();

    // Mark the origin.
    placeMarker(new THREE.Vector3(0, 0, 0), 0xff0000, 0.5);

    // Compute legal addresses.
    const addresses = computeLegalAddresses();
    console.log("Number of legal addresses:", addresses.size);

    // Visualize legal addresses as small blue markers.
    addresses.forEach(item => {
      const P = sixToCartesian(item.v);
      placeMarker(P, 0x00ffff, 0.25);
    });

    // Compute golden triangles among the legal addresses.
    const goldenTriangles = computeGoldenTriangles(addresses);
    console.log("Number of golden triangles:", goldenTriangles.length);

    // For each golden triangle, draw edges (in a tan color) connecting its vertices.
    goldenTriangles.forEach(tri => {
      const P1 = sixToCartesian(tri[0]);
      const P2 = sixToCartesian(tri[1]);
      const P3 = sixToCartesian(tri[2]);
      drawLine(P1, P2, 0xEEDC82);
      drawLine(P2, P3, 0xEEDC82);
      drawLine(P3, P1, 0xEEDC82);
    });

    // Animation loop.
    function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();
  });
</script>

<style>
  canvas {
    display: block;
  }
</style>

<div bind:this={container} style="width: 100%; height: 100%;"></div>
