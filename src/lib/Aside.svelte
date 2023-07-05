<script>
  export const identifier = "aside";
</script>

<template lang="pug">
d.aside
  button
    a(href="mailto:gimobeamo@spacestruts.com?subject=I want to know more&") Contact Us
</template>

<style>
  a {
    color: black;
  }

  .aside {
    background-color: beige;
    border-radius: 4px;
    padding: 1rem;
    grid-area: Aside;
  }
</style>
