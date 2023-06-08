<script>
export let heading;
export let image;
</script>

<container class=flex>
<img src="{image}" alt="slme" />
<div>{heading}</div>
<div><slot></slot></div>
</container>

<style>
img {
 display: inline;
 width:175px;
}
.flex {
 display: inline-flex;
}
div {
   font-size:2em;
   display:inline;
   color:red;
}
.slot {
  display:inline-block;
}
</style>
