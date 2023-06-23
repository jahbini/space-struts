<script>
   export let heading;
   export let tldr;
   export let photoURL;
   export let width=400;
   export let tags;
  function locatePhoto(photoURL,width) {
    let imageName=photoURL.split('/').pop();
    if(width==0) return "/images/space-struts/"+imageName;
    return "/images/space-struts/size"+width+"/"+imageName;
   }
</script>

<pix>
<a href="{locatePhoto(photoURL,0)}">
<article>
<header>
<h4>{heading}</h4>
</header>
<img src={locatePhoto(photoURL,width)}  alt="{heading}" />
<p>{tldr}</p>
<!--
<footer>
<p>{tags}</p>
</footer>
-->
</article>
</a>
</pix>
