<script>
  import { onMount, onDestroy } from 'svelte';

  let isExpanded = false;

  function open(event) {
    event.stopPropagation();
    isExpanded = true;
  }

  function close(event) {
    event.stopPropagation();
    isExpanded = false;
  }

  // Handle Escape key to close
  onMount(() => {
    const handleKey = e => {
      if (e.key === 'Escape') close(e);
    };
    window.addEventListener('keydown', handleKey);
    return () => {
      window.removeEventListener('keydown', handleKey);
    };
  });
 $: console.log("JAH sez", isExpanded);
</script>

{#if isExpanded}
  {@debug isExpanded}
  <!-- EXPANDED VIEW -->
  <div class="floater-expanded" on:dblclick={close}>
    <div role="button" class="close-button" on:click|stopPropagation={close}>✖</div>
    <div class="slot-wrapper">
      <slot />
    </div>
  </div>
{:else}
  <!-- SMALL VIEW -->
  <div class="floater-small" on:click={open}>
    <div class="slot-wrapper">
      <slot />
    </div>
  </div>
{/if}

<style>
  .floater-small {
    width: 2in;
    height: 2in;
    overflow: hidden;
    background: rgba(0, 0, 0, 0.7);
    border-radius: 10px;
    margin: 0.25in;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    position: relative;
    z-index: 1;
  }

  .floater-expanded {
    position: fixed;
    top: 1in; /* Shift down about an inch */
    left: 50%;
    transform: translateX(-50%);
    width: 90vw;
    height: 85vh;
    background: rgba(0, 0, 0, 0.95);
    border-radius: 16px;
    box-shadow: 0 0 30px #000;
    z-index: 9999;
    padding: 1rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  .close-button {
    position: absolute;
    top: 10px;
    right: 15px;
    font-size: 24px;
    color: white;
    cursor: pointer;
    z-index: 10000;
  }

  .slot-wrapper {
    width: 100%;
    height: 100%;
    max-height: 80vh;
    max-width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
</style>
