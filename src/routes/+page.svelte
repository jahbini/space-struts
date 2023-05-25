<script>
export const identifier="main";
import Carousel from '$lib/Carousel.svelte';
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

<Carousel >
    <h3>Slide Show Here</h3>
<p>
 This is the xxx page. and is full of text
 This is the xxx page. and is full of text
 </p>

</Carousel>
</div>

<style>
    .main {
	background-color: #f0f0f0;
	padding: 20px;
        grid-template-columns: 3fr 1fr;
    }
</style>

