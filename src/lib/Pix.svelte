<script>
   export let heading;
   export let tldr;
   export let photoURL;
   export let tags;
</script>

<pix>
<a href="{photoURL}">
<article>
<header>
<h4>{heading}</h4>
</header>
<img src={photoURL} alt="{heading}" />
<p>{tldr}</p>
<!--
<footer>
<p>{tags}</p>
</footer>
-->
</article>
</a>
</pix>
