<script>
  import * as THREE from 'three';
  import { onMount } from 'svelte';
  import { Text } from 'troika-three-text';
  import { PhiBase } from '$lib/phiBase.js';

  let container;
  let renderer, scene, camera;

  // PhiBase inputs
  let p1 = 1, n1 = 2;
  let p2 = 1, n2 = -1;

  // Operation selection
  let op = 'add';
  const ops = [
    { key: 'add', label: 'Add', fn: (a, b) => a.add(b) },
    { key: 'sub', label: 'Sub', fn: (a, b) => a.sub(b) },
    { key: 'mul', label: 'Mul', fn: (a, b) => a.mul(b) },
    { key: 'div', label: 'Div', fn: (a, b) => a.div(b) }
  ];

  const phi = (1 + Math.sqrt(5)) / 2;

  /**
   * Create a single line of 3D text at (0,y)
   */
  function createTextLine(text, y) {
    const label = new Text();
    label.text = text;
    label.fontSize = 0.3;
    label.position.set(-2.5, y, 0);
    label.color = '#333';
    label.sync();
    return label;
  }

  /**
   * Create a group of phi-base bars and a label
   * p: coefficient of phi, n: unit coefficient, y: vertical position
   */
  function createPhiBaseBar(p, n, y, labelText) {
    const group = new THREE.Group();
    const phiColor = '#FFD700';  // gold
    const unitColor = '#87CEFA'; // light sky blue

    let offset = -0.5;
    // φ segments
    for (let i = 0; i < Math.abs(p); i++) {
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(phi / 5, 0.2, 0.2),
        new THREE.MeshStandardMaterial({ color: phiColor, emissive: phiColor, emissiveIntensity: 0.5 })
      );
      mesh.position.set(offset + (phi / 10) * Math.sign(p), y, 0);
      group.add(mesh);
      offset += (phi / 5) * Math.sign(p);
    }
    // unit segments
    for (let i = 0; i < Math.abs(n); i++) {
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(1 / 5, 0.2, 0.2),
        new THREE.MeshStandardMaterial({ color: unitColor, emissive: unitColor, emissiveIntensity: 0.5 })
      );
      mesh.position.set(offset + (1 / 10) * Math.sign(n), y, 0);
      group.add(mesh);
      offset += (1 / 5) * Math.sign(n);
    }
    // add label above bars
    const textMesh = createTextLine(labelText, y + 0.3);
    group.add(textMesh);
    return group;
  }

  function refreshScene() {
    scene.clear();
    const a = new PhiBase(p1, n1);
    const b = new PhiBase(p2, n2);
    let res;
    try {
      res = ops.find(o => o.key === op).fn(a, b);
    } catch (e) {
      console.error('Operation error:', e);
      return;
    }
    // groups at y=1,0,-1
    debugger;
    const g1 = createPhiBaseBar(p1, n1, 1, `p${p1},${n1}`);
    const g2 = createPhiBaseBar(p2, n2, 0, `p${p2},${n2}`);
    const gRes = createPhiBaseBar(res.p, res.n, -1, `${op}: p${res.p},${res.n}`);
    scene.add(g1, g2, gRes);
  }

  function update() {
    refreshScene();
  }

  onMount(() => {
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(500, 500);
    container.appendChild(renderer.domElement);

    scene = new THREE.Scene();
    scene.background = new THREE.Color('#fdf6e3');

    camera = new THREE.PerspectiveCamera(45, 1, 0.1, 100);
    camera.position.set(0, 0, 10);

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(1, 1, 2);
    scene.add(light);

    (function animate() {
      requestAnimationFrame(animate);
      renderer.render(scene, camera);
    })();

    update();
  });
</script>

<div class="canvas-container" bind:this={container}></div>

<div class="controls">
  <div class="operation-row">
    {#each ops as { key, label }}
      <button class:selected={op === key} on:click={() => { op = key; update(); }}>
        {label}
      </button>
    {/each}
  </div>

  <h3>Adjust PhiBase Values</h3>

  <div class="control-row">
    <label>p₁:</label>
    <button on:click={() => { p1--; update(); }}>−</button>
    <span>{p1}</span>
    <button on:click={() => { p1++; update(); }}>+</button>
  </div>

  <div class="control-row">
    <label>n₁:</label>
    <button on:click={() => { n1--; update(); }}>−</button>
    <span>{n1}</span>
    <button on:click={() => { n1++; update(); }}>+</button>
  </div>

  <div class="control-row">
    <label>p₂:</label>
    <button on:click={() => { p2--; update(); }}>−</button>
    <span>{p2}</span>
    <button on:click={() => { p2++; update(); }}>+</button>
  </div>

  <div class="control-row">
    <label>n₂:</label>
    <button on:click={() => { n2--; update(); }}>−</button>
    <span>{n2}</span>
    <button on:click={() => { n2++; update(); }}>+</button>
  </div>
</div>

<style>
  .canvas-container {
    width: 500px;
    height: 500px;
    float: left;
    border: 1px solid #ccc;
    background-color: #fffaf0;
  }

  .controls {
    float: right;
    width: 240px;
    padding: 1rem;
    background: #f0f0f0;
    border-radius: 0.5rem;
    font-family: sans-serif;
    line-height: 1.8;
  }

  .controls h3 {
    margin-top: 0;
    margin-bottom: 1rem;
    font-size: 1.2rem;
  }

  .operation-row {
    display: flex;
    justify-content: center;
    margin-bottom: 0.75rem;
  }

  .operation-row button,
  .control-row button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    font-weight: bold;
    color: green;
    border-radius: 5px;
    border: 1px solid #ccc;
    background: white;
    cursor: pointer;
    margin: 0 1px;
  }

  .operation-row button.selected {
    background: #ccc;
  }

  .control-row {
    margin-bottom: 0.75rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .control-row label {
    display: inline-block;
    width: 30px;
    font-weight: bold;
  }

  .control-row button:hover,
  .operation-row button:hover {
    background: #ddd;
  }

  .control-row span {
    display: inline-block;
    width: 20px;
    text-align: center;
  }
</style>

