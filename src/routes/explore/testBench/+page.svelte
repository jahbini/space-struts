<script>
  import * as THREE from 'three';
  import { onMount } from 'svelte';
  import { SixPhiVector, ZERO6} from '$lib/coffee/sixPhiVector.coffee';
  import { PHI, PhiBase, ONE, ZERO } from '$lib/coffee/phiBase.coffee';
  import { GeoPhi, M } from '$lib/coffee/geoPhi.coffee'
  let container;

  function P(p,n) {
    return new PhiBase(p,n);
  }

  const G= new GeoPhi()
  function normalizeXYZ (pointsV6) {
      let pointsXYZ = [];
      return pointsV6.map( s => s.sixPhiToCartesianDisplay());
  }

  /**
   * Adds a white line-loop polygon to your Three.js scene.
   * @param {Array<[number, number, number]>} pointsArray - Array of [x, y, z] points.
   * @param {THREE.Scene} scene - Your Three.js scene object.
   */
  function drawPolygonOutline(pointsArray, color = 0xff0000 ) {
    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array(pointsArray.flat());
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    let material = new THREE.LineBasicMaterial({ color: color, linewidth: 1 });
    return new THREE.LineLoop(geometry, material);
  }
  const face = "#ooO-#zfP-#OoO-#Fpz-#fpz";
  const faceA = "#ooO~ABC-#zfP~ABC-#OoO~ABC-#Fpz~ABC-#fpz~ABC";
  const faceB = "#ooO~B-#zfP~B-#OoO~B-#Fpz~B-#fpz~B";
  const faceC = "#ooO~C-#zfP~C-#OoO~C-#Fpz~C-#fpz~C";
  const faceD = "#ooO~D-#zfP~D-#OoO~D-#Fpz~D-#fpz~D";
  const faceE = "#ooO~E-#zfP~E-#OoO~E-#Fpz~E-#fpz~E";
  const faceF = "#ooO~F-#zfP~F-#OoO~F-#Fpz~F-#fpz~F";
  let List = normalizeXYZ(G.formPointsFromPhi(face));
  let aList = normalizeXYZ(G.formPointsFromPhi(faceA));
  let bList = normalizeXYZ(G.formPointsFromPhi(faceB));
  let cList = normalizeXYZ(G.formPointsFromPhi(faceC));
  let dList = normalizeXYZ(G.formPointsFromPhi(faceD));
  let eList = normalizeXYZ(G.formPointsFromPhi(faceE));
  let fList = normalizeXYZ(G.formPointsFromPhi(faceF));

  let ooO = new SixPhiVector([ P(0,  0), P(0,  0), P(1,  0), P(0,  0), P(0,  0), P(0,  0) ]);
  let ozp = new SixPhiVector([ P(0,  0), P(0,  0), P(0,  1), P(0,  0), P(0, -1), P(1,  0) ]);
  let OoO = new SixPhiVector([ P(1,  0), P(0,  0), P(1,  0), P(0,  0), P(0,  0), P(0,  0) ]);
  let Fpz = new SixPhiVector([ P(0,  1), P(1,  0), P(0,  1), P(0, -1), P(0,  0), P(0,  0) ]);
  let fpz = new SixPhiVector([ P(0, -1), P(1,  0), P(0,  1), P(0, -1), P(0,  0), P(0,  0) ]);
  let XList = normalizeXYZ( [ ooO, ozp, OoO, Fpz, fpz ] );

  function toSixPhi(sixInt) {
    return new sixPhiVector( sixInt.map( x => new PhiBase( 0, x)));
  }
  XList = GeoPhi.normalizeXYZ ( [
    new SixPhiVector([ P(4, -5),  P(-5, 8),  P(4, -6),  P(-2, 3),  P(-4, 7),  P(1, -2) ]), // P1
    new SixPhiVector([ P(-1, 2),  P(-1, 3),  P(1, -1),  P(4, -6),  P(-5, 8),  P(-4, 6) ]), // P2
    new SixPhiVector([ P(-2, 2),  P(0, 1),   P(-5, 8),  P(-4, 7),  P(-1, 1),  P(5, -8) ]), // P3
    new SixPhiVector([ P(3, -6),  P(2, -4),  P(-6, 9),  P(-5, 8),  P(6, -10), P(-4, 7) ]), // P4
    new SixPhiVector([ P(-4, 7),  P(-4, 5),  P(6, -10), P(-1, 1),  P(-1, 2),  P(2, -3) ])  // P5
  ]);
  let listPhi = [
    [ P(0, 2),   P(0, 0),    ZERO      ],  // P1
    [ P(1, -1),  P(-5, 10),  ZERO      ],  // P2
    [ P(-1, 0),  P(-3, 6),   ZERO      ],  // P3
    [ P(-1, 0),  P(3, -6),   ZERO      ],  // P4
    [ P(1, -1),  P(5, -10),  ZERO      ]  // P5
  ]
  debugger
  let checkValue = listPhi.map(p => SixPhiVector.fromPhiPoint(...p) )
  onMount(() => {
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, container.clientWidth / container.clientHeight, 0.1, 1000);
    camera.position.z = 30;

    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(renderer.domElement);

    const material1 = new THREE.PointsMaterial({ color: 0xff0000, size: 0.5 });
    const material2 = new THREE.PointsMaterial({ color: 0x0000ff, size: 0.5 });


    let lineLoopA=drawPolygonOutline(aList,0xFF0000);
    let lineLoopB=drawPolygonOutline(bList,0x888800);
    let lineLoopC=drawPolygonOutline(cList,0x008888);
    let lineLoopD=drawPolygonOutline(dList,0x880088);
    let lineLoopE=drawPolygonOutline(eList,0x00F800);
    let lineLoopF=drawPolygonOutline(XList,0x000088);
    let lineLoop=drawPolygonOutline(GeoPhi.normalizeXYZ(checkValue),0xCCCCCC);
    //scene.add(lineLoopA);
    //scene.add(lineLoopB);
    //scene.add(lineLoopC);
    //scene.add(lineLoopD);
    //scene.add(lineLoopE);
    scene.add(lineLoopF);
    scene.add(lineLoop);

    const startTime = Date.now();
    const animate = () => {
      requestAnimationFrame(animate);
      lineLoopF.rotation.x += 0.005;
      //lineLoop.rotation.x += 0.005;
      const elapsed = (Date.now() - startTime) / 1000; // seconds
      const hue = (elapsed * 20) % 360; // cycles through hue every 18 seconds

      lineLoopF.material.color.setHSL(hue / 360, 1, 0.5);
      
      renderer.render(scene, camera);
    };
    renderer.render(scene, camera);
    animate();
  });
</script>

<div bind:this={container} style="width:100%; height:100vh;"></div>
