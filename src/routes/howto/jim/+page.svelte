<script>
  import Hello from "./Hello.svelte";
  export let name = "world";
</script>

<template lang="pug">
p something

<Hello class="hello" />

p nothing

</template>
