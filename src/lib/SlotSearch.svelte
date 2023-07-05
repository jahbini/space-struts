<script>
  /*  /src/lib/SlotSearch.svelte */
  export let selectors;
  let selector, option;
  function doIt(event) {
    let tags = [];
    selectors.forEach((element) => tags.push(document.getElementById(element.id).value));
    open(" https://www.google.com/search?rls=en&q=" + tags.join("+") + "&ie=UTF-8&oe=UTF-8");
  }
</script>

<template lang="pug">
nav
  ul
    heading Select and Surf
    +each('selectors as selector')
      li
        select(id="{selector.id}" ) 
          +each('selector.options as option')
            option.small(value="{option}") {option}
    li
      button(on:click|preventDefault!="{doIt }") Click Me!
</template>

<style>
</style>
