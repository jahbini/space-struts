<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';
  export let edges;

  let scene, camera, renderer;

  const phi = (1 + Math.sqrt(5)) / 2;

  const sixBases = [
    [phi, 0, 1],
    [phi, 0, -1],
    [0, 1, phi],
    [0, -1, phi],
    [1, phi, 0],
    [-1, phi, 0]
  ];

  function sixBaseToCartesian(coords) {
    let x = 0, y = 0, z = 0;
    for (let i = 0; i < 6; i++) {
      x += coords[i] * sixBases[i][0];
      y += coords[i] * sixBases[i][1];
      z += coords[i] * sixBases[i][2];
    }
    //x = x* 5;
    //y = y* 5;
    //z = z* 5;
    return { x, y, z };
  }

  onMount(() => {
    const container = document.getElementById('three-container');
    
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(renderer.domElement);
    
    const material = new THREE.LineBasicMaterial({ color: 0xFFFFFF });
    
    edges.forEach(edge => {
      debugger
      const edgeCart = [sixBaseToCartesian(edge[0]), sixBaseToCartesian(edge[1])];
      const points = [
        new THREE.Vector3(edgeCart[0].x, edgeCart[0].y, edgeCart[0].z),
        new THREE.Vector3(edgeCart[1].x, edgeCart[1].y, edgeCart[1].z)
      ];
      const geometry = new THREE.BufferGeometry().setFromPoints(points);
      const line = new THREE.Line(geometry, material);
      scene.add(line);
    });
    
    const originSphere = new THREE.Mesh(
      new THREE.SphereGeometry(0.1, 16, 16),
      new THREE.MeshBasicMaterial({ color: 0xff0000 })
    );
    scene.add(originSphere);
    
    camera.position.z = 5;

    function animate() {
      requestAnimationFrame(animate);
      renderer.render(scene, camera);
    }
    animate();
  });
</script>

<div id="three-container" style="width: 100%; height: 100%;">
  
</div>

