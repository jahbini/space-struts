<script>
  export const identifier = "main";
  import Carousel from "$lib/Carousel.svelte";
  let images = import.meta.glob("$lib/space-struts/*.jpeg");
  let pix = [
      'IMG_0671.jpeg', 'IMG_1183.jpeg', 'IMG_1297.jpeg', 'IMG_1332.jpeg',
      'IMG_1971.jpeg', 'IMG_1972.jpeg', 'IMG_2005.jpeg', 'IMG_2006.jpeg',
      'IMG_2227.jpeg', 'IMG_2228.jpeg', 'IMG_2229.jpeg', 'IMG_2230.jpeg',
      'IMG_2256.jpeg', 'IMG_2257.jpeg', 'IMG_2258.jpeg', 'IMG_2259.jpeg',
      'IMG_2260.jpeg', 'IMG_2261.jpeg', 'IMG_2262.jpeg', 'IMG_2285.jpeg',
      'IMG_2292.jpeg', 'IMG_2300.jpeg', 'IMG_2307.jpeg', 'IMG_2314.jpeg',
      'IMG_2315.jpeg', 'IMG_2316.jpeg', 'IMG_2317.jpeg', 'IMG_2318.jpeg',
      'IMG_2319.jpeg', 'IMG_2320.jpeg', 'IMG_2321.jpeg', 'IMG_2322.jpeg',
      'IMG_2325.jpeg', 'IMG_2332.jpeg', 'IMG_2333.jpeg', 'IMG_2370.jpeg',
      'IMG_2371.jpeg', 'IMG_2375.jpeg', 'IMG_2376.jpeg', 'IMG_2377.jpeg',
      'IMG_2378.jpeg', 'IMG_2379.jpeg', 'IMG_2380.jpeg', 'IMG_2383.jpeg',
      'IMG_2385.jpeg', 'IMG_2386.jpeg', 'IMG_2387.jpeg', 'IMG_2388.jpeg',
      'IMG_2389.jpeg', 'IMG_2390.jpeg', 'IMG_2391.jpeg', 'IMG_2392.jpeg',
      'IMG_2393.jpeg', 'IMG_2394.jpeg', 'IMG_2395.jpeg', 'IMG_2396.jpeg',
      'IMG_2397.jpeg', 'IMG_2398.jpeg', 'IMG_2399.jpeg', 'IMG_2400.jpeg',
      'IMG_2401.jpeg', 'IMG_2402.jpeg', 'IMG_2403.jpeg', 'IMG_2404.jpeg',
      'IMG_2405.jpeg', 'IMG_2406.jpeg', 'IMG_2407.jpeg', 'IMG_2408.jpeg',
      'IMG_2409.jpeg', 'IMG_2410.jpeg', 'IMG_2411.jpeg', 'IMG_2412.jpeg',
      'IMG_2413.jpeg', 'IMG_2414.jpeg', 'IMG_2415.jpeg', 'IMG_2416.jpeg',
      'IMG_2417.jpeg', 'IMG_2418.jpeg', 'IMG_2428.jpeg', 'IMG_2429.jpeg',
      'IMG_2430.jpeg', 'IMG_2431.jpeg', 'IMG_2439.jpeg', 'IMG_2441.jpeg',
      'IMG_2447.jpeg', 'IMG_2496.jpeg', 'IMG_2533.jpeg', 'IMG_2540.jpeg',
      'IMG_2544.jpeg', 'IMG_2545.jpeg', 'IMG_2546.jpeg', 'IMG_2549.jpeg'
      ];
    pix= [
          'IMG_2385.jpeg','IMG_2386.jpeg','IMG_2387.jpeg','IMG_2388.jpeg','IMG_2403.jpeg','IMG_2407.jpeg','IMG_2540.jpeg','IMG_2544.jpeg'
          ]
  function shuffle(a) {
    for (let i = a.length; i; i--) {
      let j = Math.floor(Math.random() * i);
      [a[i - 1], a[j]] = [a[j], a[i - 1]];
    }
    return a;
  }
  let showThese = shuffle(pix).slice(0, 8);
</script>

<template lang="pug">
div.main.grid
  div
    h3 Space Struts -- The construction system for the Ages.
    p.
      Space Struts is based on solid geometric principles, but we will focus not on the mathematics,
      but on how easy it is to actually construct complicated and novel shapes of your own design.
      In words that can be understood by children, you can get physical confirmation
      of solid geometric principles by the most authouattive source a person has: their own physical and sensory feedback.
  div
    <Carousel />
</template>
  <div>
    <container class="grid">
      {#each showThese as index}
        <a href="/pix/{index.slice(4,8)}">
          <article>
              <img src="/images/space-struts/{index}" alt="image" />
          </article>
        </a>
      {/each}
    </container>
  </div>

<style>
  .main {
    background-color: #f0f0f0;
    padding: 20px;
    grid-template-columns: 3fr 1fr;
  }
  container {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    grid-column-gap: 2px;
    grid-row-gap: 2px;
  }
</style>
