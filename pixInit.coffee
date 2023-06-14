fs = require 'fs'
allFiles = fs.readdirSync 'static/images/space-struts'
Files = {}
for file in allFiles
  number = (file.match /.*IMG_(\d\d\d\d).*/)
  continue if !number
  number=number[1]
  console.log number,file
  Files["#{number}"]={
    heading: 'empty Headline',
    tldr: null,
    photoURL: "/src/lib/space-struts/" + file,
    tags: ""
    }

allImages = fs.readFileSync 'src/lib/server/images.json', "utf8"
allImages = JSON.parse allImages
for image in allImages
  number = (image.photoURL.match /.*IMG_(\d\d\d\d).*$/)[1]
  Files["#{number}"]= {...image}


for number,image of Files 
  #number = (image.photoURL.match /.*IMG_(\d\d\d\d).*$/)[1]
  if image.heading == 'empty Headline'
    image.heading = image.photoURL
  image.tldr = image.photoDescription || "A Strut"
  delete image.photoDescription

  console.log "an image", image
  fs.mkdirSync "src/routes/pix/#{number}",{recursive:true}
  imageText = JSON.stringify(image,null,2);
  templateInfo = """//js file for image #{number}

  /** @type {import('./$types').PageLoad} */
  export async function load({ cookies }) {
  return  { image: #{imageText }};
  }
"""
  templatePage = """
  <script>
  // file for image #{number}
  import Pix from "$lib/Pix.svelte"
   /** @type {import('./$types').PageData} */
   import { page } from "$app/stores";
  </script>
  <h1>{$page.data.image.heading}!!</h1>
  <Pix { ...$page.data.image } />
  <style>
  </style>
"""
  fs.mkdirSync "src/routes/pix/#{number}",{recursive:true}
  fs.writeFileSync "src/routes/pix/#{number}/+page.js",templateInfo
  fs.writeFileSync "src/routes/pix/#{number}/+page.svelte",templatePage

