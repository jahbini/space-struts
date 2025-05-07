<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
//  import GeoSixPhi from '$lib/coffee/geoSixPhi.coffee';
  import {PhiBase,ZERO, PHI}  from '$lib/coffee/phiBase.coffee';
  import { quantizedFromCartesian, SixPhiVector } from '$lib/coffee/sixPhiVector.coffee'; 
  let container;

  console.log("phibase",PhiBase);
  // Golden ratio and related constant.
  const phi = PhiBase.PHI;

  // new scan
  function computeLegalAddresses () {
    var P, Pfloat, addresses, i, j, k, key, steps, v, vRounded, xStart, yStart, zStart, zero;
    addresses = new Map();
    debugger 
    let testx = 10;
    let testy = 10;
    let testz = 10;
    let testxPhi=PhiBase.fromFloat(testx)
    let testyPhi=PhiBase.fromFloat(testy)
    let testzPhi=PhiBase.fromFloat(testz)
    let testv= SixPhiVector.fromPhiPoint( testxPhi, testyPhi, testzPhi );
    let textxyz= testv.sixPhiToCartesianDisplay() 
    if ( false) {    
      const ONE=new PhiBase(0,1);
      steps = [ new PhiBase(0,-1), ZERO, ONE, new PhiBase(1,-1), new PhiBase(1,0), new PhiBase(1,1), new PhiBase(2,-1), new PhiBase(2,0),new PhiBase(2,1) ]
      steps = [ new PhiBase(0,-1), ZERO, ONE, new PhiBase(1,-1), new PhiBase(1,0)]
      const scanLimit = steps.length
      for (i=0; i<=scanLimit; i++){
        steps[i + scanLimit] = steps[i].negate();
      }
      console.log("steps", steps);
      for (i =0; i < steps.length; i++) {
        for (j =0; j < steps.length; j++) {
          for (k =0; k < steps.length; k++) {
            P = [ steps[i], steps[j+1], steps[k-1] ];
            key=[ steps[i].toString(), steps[j].toString(), steps[k].toString()].join(',');
            v= SixPhiVector.fromPhiPoint( steps[i], steps[j], steps[k] );
            addresses.set(key,{ ID: key, v: v,  P: P });
          }
        }
      }
     } else {
      const range = 4;
      const step = phi;
      for (let x = -range; x <= range; x += step) {
        let xPhi=PhiBase.fromFloat(x)
        for (let y = -range; y <= range; y += step) {
          let yPhi=PhiBase.fromFloat(y)
          for (let z = -range; z <= range; z += step) {
            let zPhi=PhiBase.fromFloat(z)
            const C3= {x,y,z}
            const P = [xPhi, yPhi, zPhi];
            const v= SixPhiVector.fromPhiPoint( xPhi, yPhi, zPhi );
            key= [ xPhi.toString(), yPhi.toString(), zPhi.toString() ].join(",")
            addresses.set(key,{ ID: key, v: v, C3:C3, P: P });
          }
        }
      }
      }
    return addresses;
  };

  // Compute golden triangles from legal addresses.
  // We convert each legal address to a THREE.Vector3 (via sixToCartesian)
  // and then loop over triples, accepting triangles that are isosceles and
  // whose edge ratio approximates the golden ratio.
  function computeGoldenTriangles(addresses, tolRatio = 0.05) {
    const points = [];
    addresses.forEach(item => {
      points.push({ v: item.v, P: item.v.sixPhiToCartesianDisplay() })
      });
    const triangles = [];
    const n = points.length;
    console.log("input Number of points",n);
    function distanceTo(p1,p2) {
      let diff = (p1[0] - p2[0])^2;
      diff += (p1[1] - p2[1])^2;
      diff += (p1[2] - p2[2])^2;
      return Math.sqrt(diff);
    }
    for (let i = 0; i < n; i++) {
      let iPushed = 0;
      for (let j = 0; j < n; j++) {
        for (let k = 0; k < n; k++) {
          const P1 = points[i].P, P2 = points[j].P, P3 = points[k].P;
          const d12 = distanceTo(P1,P2);
          const d23 = distanceTo(P2,P3);
          const d31 = distanceTo(P3,P1);
          // Identify candidate isosceles triangle.
          let dual, oppo;
          if (Math.abs(d12 - d31) < 0.1*d12) {
            dual = d12; oppo = d23;
          } else if (Math.abs(d12 - d23) < 0.1*d12) {
            dual = d12; oppo = d31;
          } else if (Math.abs(d23 - d31) < 0.1*d23) {
            dual = d23; oppo = d12;
          } else {
            continue;
          }
          // Check if ratio is approximately φ (or its reciprocal).
          const ratio = oppo / dual;
          if (Math.abs(ratio - phi)/phi < tolRatio || Math.abs((1/ratio) - phi)/phi < tolRatio) {
            triangles.push([points[i].v, points[j].v, points[k].v]);
            iPushed++;
          }
        }
      }
      console.log("Fibo on i=",i,iPushed);
    }
    console.log("Number of triangles",triangles.length);
    return triangles;
  }

  // Three.js scene variables.
  let scene, camera, renderer, controls;

  // Draw a small sphere marker at point P.
  function placeMarker(P, color = 0x00ffff, radius = 0.1) {
    const geom = new THREE.SphereGeometry(radius, 16, 16);
    const mat = new THREE.MeshBasicMaterial({ color });
    const marker = new THREE.Mesh(geom, mat);
    marker.position.copy(P);
    scene.add(marker);
  }

  // Draw an edge (line) between points P and Q.
  function drawLine(P, Q, color = 0xEEDC82) {
    const geom = new THREE.BufferGeometry().setFromPoints(
      [new THREE.Vector3(...P),new THREE.Vector3(...Q)]);
    const mat = new THREE.LineBasicMaterial({ color, linewidth: 2 });
    const line = new THREE.Line(geom, mat);
    scene.add(line);
  }

  onMount(() => {
    // Set up Three.js scene.
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x000000);
    camera = new THREE.PerspectiveCamera(
      5,
      container.clientWidth / container.clientHeight,
      0.1,
      1000
    );
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);
    controls = new OrbitControls(camera, renderer.domElement);
    camera.position.set(0, 0, 75);
    controls.update();

    // Mark the origin.
    placeMarker(new THREE.Vector3(0, 0, 0), 0xff0000, 0.1);

    // Compute legal addresses.
    const addresses = computeLegalAddresses();
    //const addresses = computeILLegalAddresses();
    console.log("Number of legal addresses:", addresses.size);

    // Visualize legal addresses as small blue markers.
    addresses.forEach(item => {
      const P = item.v.sixPhiToCartesianDisplay();
      placeMarker(new THREE.Vector3(...P), 0x00ffff, 0.01);
    });

    if ( true) {
      // Compute golden triangles among the legal addresses.
      const goldenTriangles = computeGoldenTriangles(addresses);
      console.log("Number of golden triangles:", goldenTriangles.length);

      // For each golden triangle, draw edges (in a tan color) connecting its vertices.
      goldenTriangles.forEach(tri => {
        const P1 = tri[0].sixPhiToCartesianDisplay(tri[0]);
        const P2 = tri[1].sixPhiToCartesianDisplay(tri[1]);
        const P3 = tri[2].sixPhiToCartesianDisplay(tri[2]);
        drawLine(P1, P2, 0xEEDC82);
        drawLine(P2, P3, 0xEEDC82);
        drawLine(P3, P1, 0xEEDC82);
      });
    }
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
