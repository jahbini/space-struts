<script>
  import { onMount } from 'svelte';
  import * as THREE from 'three';


  let scene, camera, renderer;
  let { edges } = $props();

  onMount(() => {
    const container = document.getElementById('three-container');
    
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(renderer.domElement);
    
    const material = new THREE.LineBasicMaterial({ color: 0x000000 });
    
    edges.forEach(edge => {
      const points = [
        new THREE.Vector3(edge[0].x, edge[0].y, edge[0].z),
        new THREE.Vector3(edge[1].x, edge[1].y, edge[1].z)
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

