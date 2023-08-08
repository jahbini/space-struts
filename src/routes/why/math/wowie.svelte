<script>
  /*  /src/routes/(front)/how/template */
  import Card from "/src/lib/CardLeftImage.svelte";
</script>

<template lang="pug">
<Card image="/images/space-struts/IMG_2544.jpeg" heading="Mathematics" >

  h3 The easier road to mastery in Mathematics
  h6 Less hand waving is a good thing
  p 
    |Geometry is the first mathematics, measuring the size of land; and grew up alongside Arithmetic, the second math, counting bushels of grain.
    | Both have spawned major advancements in the human condition. And still are.

  p
    | Mathematics has always been considered "hard," a hurdle that most people avoid.  After all, when you make that left hand turn, do you really need to measure and calculate?
    | Many of us really don't focus on anything more "mathy" than Taxes.  And that makes calculations even more of a bummer.
    | We live in a world dominated by gravity, and that has shaped ourselves into 2 1/2 Dimension beings, that live in a world of masonary.

  p 
    | And the presentation of Math, with it's bewildering symbols, and waving hands of the instructors are certain turn-offs for actually doing the homework, and getting the "learning" of the lesson.
    | No wonder the creative side of Geometry is hidden behind Calculus, with it's divs, grads and curls. And the average person is pretty much OK with 30, 60, 90 and 45 degrees.

  d.right
    small  Who Cares? -- Overheard at the construction site...
  p
    | Space struts is an end run around the mental complexities of our most verifyable math: Geometry.  With Space Struts, if the 
    | angles are right, it just fits.  And the choice of the only two fixed size parts, the Golden Gnomon and Golden Triangle makes it all simple to build, simple to conceptualize, and simple to expand upon.
    
  p
    | When a basic, physical knowledge of the the Golden 3D Geometry of Space Struts is combined with the presentation of the
    | concepts of Geometric Algebra, a new, super easy to gain mathematical mastery is available to a wider audience.

  p
    | And that wider audience will have the skills to provide new options and advancements in the human condition.  

  h5 Never be a borrower or a lender, but always a teacher and a student
  h6 -- The Celarien.

</Card>
</template>
<div class="grid containerx">
  <div class="text-stuff">speek or be spoken about</div>
  <button class="chat chat-r button">Papa U mao mou</button>
  <button class="chat-l button">wowowie woo</button>
  <div class="text-stuff">
    When a basic, physical knowledge of the the Golden 3D Geometry of Space Struts is combined with
    the presentation of the concepts of Geometric Algebra, a new, super easy to gain mathematical
    mastery is available to a wider audience.
  </div>
  <div class="chat chat-r button">Papa U mao mou</div>
</div>

<style>
  .containerx {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr 1fr 1fr;
    gap: 0px 0px;
  }
  .text-stuff {
    grid-column-start: 1;
    grid-column-end: 5;
  }

  .chat {
    margin-top: 0;
    margin-bottom: 0;
    text-align: right;
    background: #bbb;
    border-radius: 5px;
  }
  .chat-l {
    margin-top: 0;
    margin-bottom: 0;
    grid-column-start: 2;
    grid-column-end: 5;
    text-align: right;
  }
  .chat-r {
    margin-top: 0;
    margin-bottom: 0;
    grid-column-start: 3;
    grid-column-end: 5;
    text-align: right;
  }
  .button {
    background-color: #ccc;
    border: hidden;
  }
</style>
