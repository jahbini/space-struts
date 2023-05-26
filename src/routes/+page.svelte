<script>
export const identifier="main";
import Carousel from '$lib/Carousel.svelte';
let images = import.meta.glob("$lib/space-struts/*.jpeg")
let imageCount = 0;
let pix = [];
for (let image in images) {
    imageCount++;
    pix.push(image);
    console.log("image",image);
}
console.log("how many images??",imageCount);
console.log('pix[2]',pix[2]);

</script>

<div class="main grid">
<div>
    <h1>Left Hand {identifier}!</h1>
<p>
 This is the main page. and is full of text
 This is the main page. and is full of text
 This is the main page. and is full of text
 This is the main page. and is full of text
 This is the main page. and is full of text
 This is the main page. and is full of text
 This is the main page. and is full of text
 </p>
</div>

<Carousel/>
</div>
<div>
<container class="grid">
{#each [20,21,22,23,24,25] as index}
<a href="/meta/{pix[index]}">
<article>
<header>
    <img src={pix[index]} alt="image" />
</header>
<p>{index}</p>
</article>
</a>
{/each}
    <p>
        This is the container it is {imageCount } images long?
 This is the main page. and is full of text
 This is the main page. and is full of text
 </p>
</div>
<style>
    .main {
	background-color: #f0f0f0;
	padding: 20px;
        grid-template-columns: 3fr 1fr;
    }
container { 
display: grid; 
grid-template-columns: repeat(4, 1fr); 
grid-template-rows: repeat(2, 1fr); 
grid-column-gap: 2px;
grid-row-gap: 2px; 
}
</style>

