<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
  import { PhiBase } from '$lib/phiBase.js';
  import { SixPhiVector } from '$lib/sixPhi.js';

  const WRAP_SIZE = 10;
  const OFFSET_RADIUS = 2.5;
  const DISPLAY_INTERVAL_MS = 100;

  let container;
  let scene, camera, renderer, controls;
  let meshGroup;
  let interval;

  let x = 0, y = 0, z = 0;

  let pointsMap = {};
  let faceList = [];
  let triangleMeshes = [];

  function wrap(val, width = WRAP_SIZE) {
    console.log('wrap()', { val, width });
    return ((val + width / 2) % width + width) % width - width / 2;
  }

  function loadJsonSync() {
    console.log('loadJsonSync()');
    const xhr = new XMLHttpRequest();
    xhr.open('GET', '/faces.json', false);
    xhr.send(null);
    if (xhr.status === 200) {
      const json = JSON.parse(xhr.responseText);
      pointsMap = json.points;
      console.log("pointsmmap",pointsMap);
      faceList = json.trails.filter(f => f.id.startsWith('face') || f.id === 'dodecahedron1');
    } else {
      console.error('Failed to load /faces.json');
    }
  }

  function convertSymbolToVec(symbol) {
    const entry = pointsMap[symbol];
    if (!entry) {
      console.error('Missing point:', symbol);
      return new THREE.Vector3(0, 0, 0);
    }

    const [xPhi, yPhi, zPhi] = entry.coords.map(c => {
      const [p, n] = c.replace('p', '').split(',').map(Number);
      return new PhiBase(p, n);
    });

    const x = xPhi.toFloat();
    const y = yPhi.toFloat();
    const z = zPhi.toFloat();

    const v = new THREE.Vector3(x, y, z);
    console.log(`Symbol ${symbol} → phiBase [${xPhi}, ${yPhi}, ${zPhi}] → float ${v.toArray()}`);
    return v;
  }

  function convertSymbolToVecBad(symbol) {
    console.log('convertSymbolToVec()', { symbol });
    const coeffs = pointsMap[symbol].coords.map(c => {
      const [p, n] = c.replace('p', '').split(',').map(Number);
      return new PhiBase(p, n);
    });
    console.log("Coeffs", coeffs);
    debugger;
    const floatCoords = new SixPhiVector(coeffs).toFloatArray();
    return new THREE.Vector3(...floatCoords);
  }

  function buildShell() {
    console.log('buildShell()', { x, y, z });

    //const centerOffset = new THREE.Vector3(
    //  wrap(x) + OFFSET_RADIUS,
    //  wrap(y) + OFFSET_RADIUS,
    //  wrap(z) + OFFSET_RADIUS
    //);
    const centerOffset = new THREE.Vector3(0, 0, 0);

    const material = new THREE.MeshBasicMaterial({ 
      color: 0x00ff00, 
      wireframe: false, 
      opacity: 1.0, 
      transparent: false,
      side: THREE.DoubleSide
    });
    const triangles = [];

    for (const face of faceList) {
      //const vecs = face.points.map(s => convertSymbolToVec(s).add(centerOffset));
      const vecs = [];
      for (const symbol of face.points) {
        const baseVec = convertSymbolToVec(symbol);
        const finalVec = baseVec.clone().add(centerOffset);
        console.log(`Symbol ${symbol} → base ${baseVec.toArray()} → final ${finalVec.toArray()}`);
        vecs.push(finalVec);
      }
      //console.log('Triangle sample:', vecs[0].toArray());
      for (let i = 1; i < vecs.length - 1; i++) {
        const geometry = new THREE.BufferGeometry().setFromPoints([vecs[0], vecs[i], vecs[i + 1]]);
        triangles.push(new THREE.Mesh(geometry, material));
      }
    }

    console.log('buildShell() → #triangles:', triangles.length);
    return triangles;
  }

  function displayShell(meshes) {
    console.log('displayShell()', { count: meshes.length });

    if (!meshGroup) {
      console.warn('displayShell(): meshGroup is not initialized yet.');
      return;
    }

    if (interval) clearInterval(interval);
    meshGroup.clear();

    const queue = [...meshes];
    interval = setInterval(() => {
      const mesh = queue.shift();
      if (!mesh) {
        clearInterval(interval);
        return;
      }
      //console.log('Adding triangle to meshGroup:', mesh.uuid);
    }, DISPLAY_INTERVAL_MS);
  }

  function initializeScene() {
    console.log('initializeScene()');
    loadJsonSync();

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf0f0f0);

    camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.z = 15;

    renderer = new THREE.WebGLRenderer();
    renderer.setSize(window.innerWidth, window.innerHeight);
    container.appendChild(renderer.domElement);

    controls = new OrbitControls(camera, renderer.domElement);

    meshGroup = new THREE.Group();
    scene.add(meshGroup);
    const testGeo = new THREE.BoxGeometry(1, 1, 1);
    const testMat = new THREE.MeshBasicMaterial({ color: 0xff0000 });
    const testMesh = new THREE.Mesh(testGeo, testMat);
    scene.add(testMesh);

    const light = new THREE.AmbientLight(0xffffff);
    scene.add(light);

    const animate = () => {
      requestAnimationFrame(animate);
      renderer.render(scene, camera);
    };
    animate();

    triangleMeshes = buildShell();
    displayShell(triangleMeshes);
  }

  onMount(() => {
    console.log('onMount() → calling initializeScene()');
    initializeScene();
  });


  $: {
    console.log('$ reactive → shell rebuild triggered', { x, y, z });
    if (meshGroup) {
      triangleMeshes = buildShell();
      displayShell(triangleMeshes);
    } else {
      console.warn('Reactive update skipped: meshGroup not ready');
    }
    console.log('$ reactive → shell rebuild completcompletee', { x, y, z });
  }
</script>
<!-- === DOM Elements === -->
<div bind:this={container} class="webgl-canvas"></div>

<div class="ui-overlay">
  <label>X: <input type="text" bind:value={x} /></label>
  <label>Y: <input type="text" bind:value={y} /></label>
  <label>Z: <input type="text" bind:value={z} /></label>
</div>

<!-- === Styles === -->
<style>
  .webgl-canvas {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: 0;
  }

  .ui-overlay {
    position: absolute;
    top: 1rem;
    left: 1rem;
    z-index: 1000;
    background-color: white;
    padding: 1rem;
    border-radius: 0.5rem;
    box-shadow: 0 0 10px rgba(0, 0, 0, 0.2);
  }

  input {
    width: 60px;
    margin-right: 10px;
  }
</style>
