<script>
  // /Users/jahbini/development/ucoa/space-struts/src/routes/pix/2540-theCollar
  /*  /src/routes/(front)/what/collar */
  import Card from "/src/lib/CardLeftImage.svelte";
  let image = "/src/lib/space-struts/IMG_2540.jpeg";
  let heading = "The Collar";
  let photoDescription =
    "<h2> The Collar is made of 10 gnomon triangles.  Several joined together make a pentagonal corridor</h2>";
</script>

<template lang="pug">
<Card image="{image}" heading="{heading}" >
p {photoDescription}
</Card>
div(style='max-width:250px')
  container
    a href="/meta/{image}"
      article
        header
            p {heading}
        body
          img(src="{image}" alt="{heading}")
        footer
        raw {photoDescription}

</template>

<style>
</style>
