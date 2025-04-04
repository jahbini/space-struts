<script>
  let isExpanded = false;
import { onDestroy } from 'svelte';

onDestroy(() => {
  console.log("Floater destroyed.");
});

  function open(event) {
    event.stopPropagation();
    console.log("Opening...");
    isExpanded = true;
  }

  function close(event) {
    event.stopPropagation();
    console.log("Closing...");
    isExpanded = false;
  }

  $: console.log("Reactive: isExpanded =", isExpanded);
</script>

{#if isExpanded}
  <div
    style="
      position: fixed;
      top: 100px;
      left: 100px;
      width: 80vw;
      height: 60vh;
      background: #222;
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 12px;
      box-shadow: 0 0 30px black;
      z-index: 1000;
    "
    on:dblclick={close}
  >
    <div style="position: absolute; top: 10px; right: 20px;" on:click|stopPropagation={close}>
      ✖
    </div>
    <div>Expanded Floater</div>
  </div>
{:else}
  <div
    style="
      width: 2in;
      height: 2in;
      background: #444;
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 10px;
      cursor: pointer;
      margin: 1em;
    "
    on:click={open}
  >
    Small Floater
  </div>
{/if}
