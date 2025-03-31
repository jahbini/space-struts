<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';

  const phi = (1 + Math.sqrt(5)) / 2;
  const sixBases = [
    [phi, 0, 1],     // B0
    [phi, 0, -1],    // B1
    [0, 1, phi],     // B2
    [0, -1, phi],    // B3
    [1, phi, 0],     // B4
    [-1, phi, 0]     // B5
  ];

  const colors = ['red', 'orange', 'green', 'blue', 'purple', 'gray'];
  let activeColorIndex = null;

  function sixBaseToCartesian(coords) {
    return coords.reduce(
      (acc, val, i) => {
        acc[0] += val * sixBases[i][0];
        acc[1] += val * sixBases[i][1];
        acc[2] += val * sixBases[i][2];
        return acc;
      },
      [0, 0, 0]
    );
  }

  let container;

  function createEdge(a, b, material) {
    const points = [
      new THREE.Vector3(...a),
      new THREE.Vector3(...b)
    ];
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    return new THREE.Line(geometry, material);
  }

  function createPlaneFromOrigin(basisVec, color) {
    const radius = 1.2;
    const segments = 64;
    const geometry = new THREE.CircleGeometry(radius, segments);
    const material = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.15, side: THREE.DoubleSide });
    const circle = new THREE.Mesh(geometry, material);

    const norm = new THREE.Vector3(...basisVec).normalize();
    const up = new THREE.Vector3(0, 0, 1);
    const quaternion = new THREE.Quaternion().setFromUnitVectors(up, norm);
    circle.quaternion.copy(quaternion);

    circle.position.set(0, 0, 0);
    return circle;
  }

  function generateEdges() {
    const edges = [];
    const origin = [0, 0, 0, 0, 0, 0];
    for (let i = 0; i < 6; i++) {
      const target = [...origin];
      target[i] += 1;
      const a = sixBaseToCartesian(origin);
      const b = sixBaseToCartesian(target);
      edges.push({ a, b, basis: i });
    }
    return edges;
  }

  function renderScene() {
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xeeeeee);

    const camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    const edges = generateEdges();

    edges.forEach(({ a, b, basis }) => {
      const color = (activeColorIndex === null || activeColorIndex === basis) ? colors[basis] : '#ddd';
      const material = new THREE.LineBasicMaterial({ color });
      scene.add(createEdge(a, b, material));
      scene.add(createPlaneFromOrigin(sixBases[basis], color));
    });

    const sphere = new THREE.Mesh(
      new THREE.SphereGeometry(0.05, 16, 16),
      new THREE.MeshBasicMaterial({ color: 'red' })
    );
    sphere.position.set(0, 0, 0);
    scene.add(sphere);

    camera.position.z = 5;
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.update();

    function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();
  }

  $: if (container) renderScene();
</script>

<div bind:this={container} style="width: 100%; height: 600px;"></div>

<div style="margin-top: 1em; display: flex; gap: 1em; flex-wrap: wrap;">
  {#each colors as color, i}
    <button on:click={() => activeColorIndex = activeColorIndex === i ? null : i}
            style="background: {color}; color: white; padding: 0.5em 1em; border: none; cursor: pointer;">
      {activeColorIndex === i ? 'Show All' : `Highlight B${i}`}
    </button>
  {/each}
</div>

