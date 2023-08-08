<script>
  export const identifier = "BambooCanDo";
  import footerText from "./footerText.txt?raw";
</script>

<template lang="pug">
footer(class="footer")
  p {footerText}
d
  p.noColor {footerText}
</template>

<style>
  a {
    color: black;
  }
  .pure-button {
    background: dark-grey;
  }
  .noColor {
    color: #fff;
  }
  p {
    font-size: small;
  }
  .footer {
    background-color: beige;
    padding-top: 0.1in;
    position: fixed;
    bottom: 0px;
  }
</style>
