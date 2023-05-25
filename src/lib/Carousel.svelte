<script>
  export const name = "Carousel";
</script>

<div class="carousel">

<script>
  let slidePosition = 0;

function updateSlidePosition() {
  let slides = document.getElementsByClassName('carousel__item');
  console.log("in slides", slides);
  for (let slide of slides) {
    slide.classList.remove('carousel__item--visible');
    slide.classList.add('carousel__item--hidden');
  }
  if (slidePosition === slides.length-1) {
    slidePosition = 0;
  } else {
    slidePosition++;
  }
  slides[slidePosition].classList.add('carousel__item--visible');
}

setInterval( updateSlidePosition,2500);

</script>
      <div class="carousel__item carousel__item--visible">
        <img src="/images/space-struts/IMG_2227.jpeg" />
      </div>
      <div class="carousel__item">
        <img src="/images/space-struts/IMG_2228.jpeg" />
      </div>
      <div class="carousel__item">
        <img src="/images/space-struts/IMG_2229.jpeg" />
      </div>
</div>

<style>

.carousel {
  overflow: hidden;
  max-width: 600px;
  position: relative;
}

.carousel .carousel__item,
.carousel .carousel__item--hidden {
  display: none;
}

.carousel .carousel__item img {
  width: 100%;
  max-width: 600px;
  height: auto;
}

.carousel .carousel__item--visible {
  display: block;
  animation: fadeVisibility 0.5s;
}

@keyframes fadeVisibility {
  0% {
    opacity: 0;
  }
  100% {
    opacity: 1;
    transform: opacity linear;
  }
}
</style>
