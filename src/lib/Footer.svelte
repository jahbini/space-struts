<script>
  export const identifier = "BambooCanDo";
  import footerText from "./footerText.txt?raw";
</script>

<template lang="pug">
footer(class="footer")
  button
    a(href="mailto:gimobeamo@spacestruts.com?subject=I want to know more&") Contact Us
  p {footerText}
d
  button
    a(href="mailto:gimobeamo@spacestruts.com?subject=I want to know more&") Contact Us
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
  .footer {
    background-color: beige;
    padding-top: 0.1in;
    position: fixed;
    bottom: 0px;
  }
</style>
