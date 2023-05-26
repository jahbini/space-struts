<script>
    /** @type {import('./$types').PageData} */
 import  { page }  from '$app/stores'
 export let data;
</script>


<div>

<h1>{data.image.title}</h1>
<div>{@html data.image.content}</div>
<img style="max-width:25%" src="{$page.params.imageurl}" alt="image" />
</div>

<style>
</style>
