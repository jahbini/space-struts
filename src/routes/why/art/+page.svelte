<script>
  /*  /src/routes/(front)/how/template */
  import Card from "/src/lib/CardLeftImage.svelte";
  import SlotSearch from "/src/lib/SlotSearch.svelte";
  const selectors = [
    {
      id: "tag0",
      options: ["pentagon", "pentagram", "dodecahedron", "hexagon", "tetrahedron", "golden ratio"]
    },
    {
      id: "tag1",
      options: [
        "ceramic art",
        "eastern art",
        "moslem art",
        "christian art",
        "architecture",
        "music",
        "sacred geometry"
      ]
    }
  ];
</script>

<template lang="pug">
SlotSearch(selectors="{selectors}")
<Card image="/images/space-struts/IMG_2259.jpeg" heading="Art" >

  h3 The 2.5D art of the Golden Ratio
  h6
    a(href="https://en.wikipedia.org/wiki/The_Sacrament_of_the_Last_Supper") Salvadore Dali had the right idea

  p
    | The search above will keep you amused and informed even as you discover that even Beethoven used the
    | Golden Ratio.  But you won't find very many barns, houses or office buildings that use pentagrams.

  p
    | That can easily change with Space Struts as a construction system.  All the edges can be fully triangulated and 
    | reinforced to any level of structural integrity.
  

  h5 There are many strategies for war.  We have few for peace.
  h6 -- The Celarien.

</Card>
</template>

<style>
</style>
