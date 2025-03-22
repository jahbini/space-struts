<script>
  import footerText from "./footerText.txt?raw";
</script>

<footer>
  <p>{footerText}</p>
  <div>
  <p class="noColor">{footerText}</p>
  </div>
</footer>

<style>
  a {
    color: black;
  }
  .noColor {
    color: #fff;
  }
  p {
    font-size: small;
  }
  footer {
    background-color: beige;
    padding-top: 0.1in;
    position: fixed;
    bottom: 0px;
  }
</style>
