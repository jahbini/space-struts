<script>
   export let heading;
   export let photoDescription;
   export let photoURL;
   export let tags;
</script>

<pix>
{@debug }
<a href="{photoURL}">
<article>
<header>
<img src={photoURL} alt="{heading}" />
</header>
<p>{heading}</p>
<p>{tags}</p>
</article>
</a>
</pix>
