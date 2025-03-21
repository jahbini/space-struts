<script>
  import SixBasisVisualizer from './six_basis_visualizer.svelte';

  // Define edges for a simple example (one or two triangles)
  const edges = [
    [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }],
    [{ x: 1, y: 0, z: 0 }, { x: 0.5, y: Math.sqrt(3) / 2, z: 0 }],
    [{ x: 0.5, y: Math.sqrt(3) / 2, z: 0 }, { x: 0, y: 0, z: 0 }],
    // Second triangle
    [{ x: 0.5, y: Math.sqrt(3) / 2, z: 0 }, { x: 1.5, y: Math.sqrt(3) / 2, z: 0 }],
    [{ x: 1.5, y: Math.sqrt(3) / 2, z: 0 }, { x: 1, y: 0, z: 0 }]
  ];
</script>

<SixBasisVisualizer edges={edges} />

