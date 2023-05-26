/** @type {import('./$types').PageLoad} */
export function load({ params }) {
  console.log('load', params);
  return {
    image: {
      stuff: params,
      title: `Title for ${params.slug} goes here`,
      content: `Content for ${params.slug} goes here`
    }
  };
}
