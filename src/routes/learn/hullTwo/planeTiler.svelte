<script>
  import * as THREE from 'three';
  import { onMount } from 'svelte';
  import { PhiBase } from '$lib/phiBase';
  import { nextTriangle, resetTiling } from './tilePlaneEngine.js';
  import { loadFaces } from './loadFacesHelper.js';

  let container;
  let scene;
  let camera;
  let renderer;
  let meshGroup;
  let markerGroup;
  let symbolToVec = {};

  const phi = PhiBase.PHI;
  const scale = Math.pow(phi, 0);

  onMount(async () => {
    console.log('Initializing Three.js scene...');
    initThree();

    console.log('Loading faces.json...');
    symbolToVec = await loadFaces();

    console.log('Adding base square...');
    addBaseSquare();

    console.log('Adding phi markers...');
    addPhiMarkers();

    console.log('Resetting tiling engine...');
    await resetTiling();

    console.log('Starting to add triangles...');
    addTriangle();

    console.log('Starting animation loop...');
    debugger;
    animate();
  });

  function initThree() {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1000);
    camera.position.set(0, 0, 200);

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(500, 500);
    container.appendChild(renderer.domElement);

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(1, 1, 1);
    scene.add(light);

    const ambient = new THREE.AmbientLight(0x888888);
    scene.add(ambient);

    meshGroup = new THREE.Group();
    markerGroup = new THREE.Group();
    scene.add(meshGroup);
    scene.add(markerGroup);
  }

  function addBaseSquare() {
    const size = 100;
    const squareGeom = new THREE.PlaneGeometry(size, size);
    const squareMat = new THREE.MeshBasicMaterial({ color: 0x4444aa, wireframe: true, opacity: 0.5, transparent: true });
    const square = new THREE.Mesh(squareGeom, squareMat);
    square.rotation.x = -Math.PI / 2; // Make it lie flat on XZ
    scene.add(square);
  }

  function addPhiMarkers() {
    const dotMat = new THREE.MeshBasicMaterial({ color: 0xff0000 });
    const dotGeom = new THREE.SphereGeometry(0.5, 6, 6);

    for (const vec of Object.values(symbolToVec)) {
      const [x, y, z] = vec.toFloatArray();
      const dot = new THREE.Mesh(dotGeom, dotMat);
      dot.position.set(x * scale, y * scale + 2, z * scale);
      markerGroup.add(dot);
    }
  }

  function addTriangle() {
    const tri = nextTriangle();
    if (!tri) {
      console.log('No more triangles in queue.');
      return;
    }

    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array([
      tri[0][0], tri[0][1], tri[0][2],
      tri[1][0], tri[1][1], tri[1][2],
      tri[2][0], tri[2][1], tri[2][2],
    ]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.computeVertexNormals();

    const material = new THREE.MeshStandardMaterial({ color: 0xffffcc, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(geometry, material);
    meshGroup.add(mesh);

    setTimeout(addTriangle, 100);
  }

  function animate() {
    requestAnimationFrame(animate);
    renderer.render(scene, camera);
  }
</script>

<div bind:this={container} style="width: 500px; height: 500px; border: 1px solid #ccc" />

