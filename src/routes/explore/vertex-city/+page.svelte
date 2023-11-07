<script lang="coffeescript" type="text/coffeescript">

import * as seenModule from '$lib/seen.m.coffee';
import { onMount } from 'svelte'
import  _  from 'underscore'
import { Memo } from './memo.coffee'
import { page } from '$app/stores';
import  Checkme from './Checkme.svelte'

duh=($page.url.searchParams.get 'useShapes') || "None"
duh=  duh.split /, ?/ if 'string' == typeof duh

useShapes = "#{shape}": shape for shape in duh
G={Polyhedra:[]}
context1="undefined"
context2=null
image=null
labels=null
showLines=null
segmentsActive={}

selected={}
scene1=null
scene2=null
xform=null

filters=
  vertex: true
  labels: true
  segmentMagnitudes: {}
  magnitude: false
  useShapes: useShapes 

shapesText=""
segmentText=""
    
pointName = {}
pointsToShow= []
segmentsByMagnitude=[]
allSegmentMagnitudes = []

M = new Memo()

###
  saveThis: (key, value)->
  theLowdown: (key)=>
  waitFor: (aList,andDo)=>
  notifyMe: (n,andDo)=>
###

class Geo
  octahedron = "#O00-#o00-#0o0-#0O0-#00o-#00O"
  cube = "#OOO-#oOO-#OoO-#ooO-#OOo-#oOo-#Ooo-#ooo"
  tetrahedron1="#ooo-#oOO-#OoO-#OOo"
  tetrahedron2="#OOO-#Ooo-#oOo-#ooO"
  icosahedron1 = "#zOF-#zoF-#zof-#zOf-#oFz-#ofz-#OFz-#Ofz-#FzO-#fzO-#Fzo-#fzo"
  icosahedron2 = "#zFO-#zFo-#zfo-#zfO-#Foz-#foz-#FOz-#fOz-#OzF-#Ozf-#ozF-#ozf"
  dodecahedron1="#ooo-#ooO-#oOo-#oOO-#Ooo-#OoO-#OOo-#OOO-#zfp-#zFp-#zfP-#zFP-#pzf-#Pzf-#pzF-#PzF-#fpz-#Fpz-#fPz-#FPz"
  dodecahedron2="#ooo-#oOo-#ooO-#oOO-#Ooo-#OOo-#OoO-#OOO-#zpf-#zpF-#zPf-#zPF-#fzp-#fzP-#Fzp-#FzP-#pfz-#pFz-#Pfz-#PFz"

  fe= (Math.sqrt(5)-1)/2.0
  Phi= (1+Math.sqrt 5)/2

  #  "Z": 0
  decode = 
    "z": 0
    "O": 1
    "o": -1
    "f": -1/Phi
    "F": 1/Phi
    "p": -Phi
    "P": Phi
  ###+
  # param: ptxt encoding of essential points above text
  # returns new seen.P decorated with ID: ptxt
  # side-effect: adds point to pointName map to this returned value
  ###
  createSeenPoint = (ptxt,shapeName = "")->
    return null if ! xyz=ptxt.match '#(.)(.)(.)$'
    if null != p=(M.theLowdown ptxt).value
      p.shapeName[shapeName] = shapeName
      return (M.theLowdown ptxt).value
    p = seen.P decode[xyz[1]],decode[xyz[2]],decode[xyz[3]]
    p.d = p.magnitude().toFixed 3
    p.shapeName = { "#{shapeName}": shapeName }
    p.ID = ptxt
    (M.saveThis ptxt, p).value #return just the point value, not the meta info
    
  formPointsFrom =(shape,shapeName="") ->
    shapePoints = for i in shape.split '-'
      createSeenPoint i,shapeName
    (M.saveThis shapeName,shapePoints).value
    
  menuItems= ()=>
    for key of @Polyhedra
      key
  
  createSegment = (ptxt1,ptxt2)->
    (t=ptxt1; ptxt1=ptxt2; ptxt2=t) if ptxt2<ptxt1
    p1=createSeenPoint ptxt1
    p2=createSeenPoint ptxt2
    path = [p1,p2]
    d=p1.copy().subtract(p2).magnitude()
    d=d.toFixed 3
    ID= ptxt1+'-'+ptxt2
    M.saveThis ID, {ID,path,d}


  createSegments: (points)->
    theSegments={}
    for i,p1 in points
      for j,p2 in points[i...]
          continue if i.ID == j.ID
          tag = i.ID + '-' + j.ID
          continue if M.MM[tag]
          theSegments[tag]= createSegment i.ID,j.ID
    segmentsByMagnitude=_.chain(theSegments)
      .map (v)->v.value
      .sortBy 'd'
      .groupBy('d')
      .value()
    allSegmentMagnitudes = [k for k of segmentsByMagnitude]

  constructor:()->
    @Polyhedra = 
      Tetrahedron1: formPointsFrom tetrahedron1, "tetrahedron"
      Tetrahedron2: formPointsFrom tetrahedron2, "tetrahedron"
      Octahedron: formPointsFrom octahedron,"octahedron"
      Cube: formPointsFrom cube,"cube"
      Icosahedron1: formPointsFrom icosahedron1, "icosahedron"
      Icosahedron2: formPointsFrom icosahedron2, "icosahedron"
      Dodecahedron1: formPointsFrom dodecahedron1, "dodecahedron"
      Dodecahedron2: formPointsFrom dodecahedron2, "dodecahedron"
      None: []
    Melements=  _(M.MM).filter (item,key)-> key.match /^#...$/
    @createSegments _.mapObject Melements, (item,key)->item.value



defaultSize=100
# Create a shape
pSize = 55
phi=1.61803398
phi= (Math.sqrt(5.0)+1.0)/2.0
s05=pSize/phi
s1=pSize
s2=pSize*phi
s3=s2*phi
s4=s3*phi
s5=s4*phi

Bases=
 Groucho:Groucho=0
 Chico: Chico=Groucho+72
 Harpo: Harpo=Chico+72
 Stan: Stan=Harpo+72
 Babe: Babe=Stan+72

toRad = (a) -> (a)*Math.PI/180
To = ( a,l )-> #angle in degrees from x-axis, length
  rad = (a)*Math.PI/360
  new seen.P l* Math.cos(rad), l*Math.sin(rad)

###+
# param:a seen.P
# param:t direction in degrees
# param:l length
# returns: new seen.P at destination
###
fromTo = (a,t,l)->
  a.copy().add To t,l

wireframe = (points,color = "#000000")->
  p=seen.Shapes.path points
  p.cullBackfaces = false
  m= new seen.Material new seen.Colors.hex color
  p.stroke m
  p.surfaces[0].fillMaterial = null
  p.surfaces[0]["stroke-width"]=1
  p

showSegments = (mdl,segments)->
  return [] unless segments.length
  p = mdl.append()
  color = "#000000"
  for s in segments
    p.add wireframe s.path, color if s
  p.scale defaultSize
  
###+
# descr: generate the vertices as tetrahedrons from seen's model mdl
# param: mdl seenjs model to attach this graphic
###
showPoints = (mdl,points)->
  p = mdl.append()
  for point in points
    glyf=seen.Shapes.tetrahedron 1
    glyf.fill '#4cc488'
    glyf.scale 5
    glyf.translate defaultSize*point.x,defaultSize*point.y,defaultSize*point.z
    p.add glyf
  p

showPointNames = (mdl,points)->
  cluster = mdl.append()
  for point in points
    label=seen.Shapes.text point.ID,{
      font: '10px Roboto'
      cullBackFaces: false
      style: "text-anchor":"end"
    }
    label.fill '#000000'
    label.scale 2.5
    label.translate defaultSize*point.x,defaultSize*point.y,125*point.z
    cluster.add label
  cluster
    
viewRotate=
  x: 0
  y: 0
  z: 0
updateRotation = ()->


initializeContext= ()->
  # Create scene and add shape to model
  scene1 = new seen.Scene
    model    : mdl
    viewport : seen.Viewports.center(400,400)
    cullBackfaces: false

  # Create scene and add shape to model
  scene2= new seen.Scene
    model    : mdl
    viewport : seen.Viewports.center(400,400)
    cullBackfaces: false
  scene1.camera.translate 0,0,-50
  scene2.camera.translate 50,0,-50
  console.log "xform",xform if xform?
  mdl.transform xform if xform

  # Create render context into seen- canvas or svg
  context1 = seen.Context('seen-canvas1', scene1)
  context2 = seen.Context('seen-canvas2', scene2)

  dragger = new seen.Drag('seen-canvas1', {inertia : true})
  dragger.on('drag.rotate', (e) ->
    xform = seen.Quaternion.xyToTransform(e.offsetRelative...)
    mdl.transform(xform)
    context1.render()
    context2.render()
  )

  myUpdateRotation= ()->
    mdl.reset()
    mdl.rotx viewRotate.x*Math.PI/180
    mdl.roty viewRotate.y*Math.PI/180
    mdl.rotz viewRotate.z*Math.PI/180
    context1.render()
    context2.render()
  updateRotation = myUpdateRotation  
  ###
  # Slowly rotate sphere
  rx = 0.0004
  ry = 0.00027
  frame1=context1.animate()
    .onBefore((t, dt) -> 
      showLines?.rotx(rx).roty(ry)
      image?.rotx(rx).roty(ry)
      labels?.rotx(rx).roty(ry)
      )
    .start()
  
  frame2=context2.animate()
    .onBefore((t, dt) -> 
      showLines?.rotx(rx).roty(ry)
      image?.rotx(rx).roty(ry)
      labels?.rotx(rx).roty(ry)
      )
    .start()
  ###
  context1.render()
  context2.render()

downloadBlob=(name,text)->
  a=document.createElement('a')
  document.body.append a
  a.download=name
  a.href=URL.createObjectURL(new Blob [ text ])
  a.click()
  a.remove();
  
snapshot=(name,scene)->
  try
        console.log "attempt to write"
        context = seen.Context(name, scene)
        context.render()
        svg= document.getElementById(name)
        svgText= svg
        downloadBlob name+'.svg', svgText.outerHTML
    catch nada
      console.log "NADA",nada
  
shootTheMoon= (value)->
  alert("shoot",JSON.stringify(value))
  debugger

mdl=null
onMount ->
  if !seen
    setTimeout onMount,50
    return
  else
    G=new Geo()
    mdl = seen.Models.default()
    mdl.cullBackfaces = false
    initializeContext()
    makeScene filters
  
updateShapesWanted = (shape,show=true) ->
  # reset filters upon adding shape in viewport
  pointsToShow= []
  if shape == "None"
    filters=
      vertex: false
      labels: false
      segmentMagnitudes: {}
      magnitude: false
      useShapes: {None: "None"} 
    
  if show
    filters.useShapes[shape]=shape
  else
    delete filters.useShapes[shape]
  for key of filters.useShapes
    pointsToShow=pointsToShow.concat G.Polyhedra[key]
  delete filters.useShapes.None if pointsToShow.length > 1

  G.createSegments pointsToShow
  # remove any segments that don't have a length of the shapes displayed
  for k of filters.segmentMagnitudes
    filters.segmentMagnitudes[k] = false unless allSegmentMagnitudes[k]
  
  filters=
    vertex: filters.vertex
    labels: filters.labels
    segmentMagnitudes: filters.segmentMagnitudes
    magnitude: filters.magnitude
    useShapes: filters.useShapes
  makeScene filterThis=filters
makeResponsiveScene= (k,v)->
  filters.segmentMagnitudes[k]=v
  makeScene filters

makeScene= (filterThis)->
  
  ###
  # seen is now loaded and can be used.
  # computation for display will proceed.
  ###

  scene1.flushCache()
  scene2.flushCache()
  mdl.remove image if image
  if filterThis.vertex
    image = showPoints(mdl,pointsToShow)
    image.scale 0.90
    #image.translate 220,180 
  
  mdl.remove labels if labels
  if filterThis.labels
    labels = showPointNames(mdl,pointsToShow)
    labels.scale 0.90
    #labels.translate 235,180

  mdl.remove showLines if showLines
  G.createSegments pointsToShow
  someLines = []
  segmentText=[]
  segmentsActive={}
  someLines= for key,value of filterThis.segmentMagnitudes
    continue unless value
    segmentText.push key
    segmentsActive[key]=true
    segmentsByMagnitude[key]
  someLines=_.flatten someLines
  if someLines?.length 
    showLines = showSegments mdl,someLines
    showLines.scale 0.90
    #showLines.translate 220,180

  shapesText = (key for key of filterThis.useShapes).join ', '
  segmentText = segmentText.join ', '
  logo = mdl.append()

  # Render it!
  logo.add seen.Shapes.text("Groucho:"+Groucho, {font : '20px Roboto', cullBackfaces : false, anchor : 'center'}).rotz(toRad Groucho).translate 100,10
  logo.add seen.Shapes.text("Chico:"+Chico, {font : '20px Roboto', cullBackfaces : false, anchor : 'center'}).rotz(toRad Chico).translate 200,20
  logo.add seen.Shapes.text("Harpo:"+Harpo, {font : '20px Roboto', cullBackfaces : false, anchor : 'center'}).rotz(toRad Harpo).translate 230,110
  logo.add seen.Shapes.text("Stan:"+Stan, {font : '20px Roboto', cullBackfaces : false, anchor : 'center'}).rotz(toRad Stan).translate 140,160
  logo.add seen.Shapes.text("Babe:"+Babe, {font : '20px Roboto', cullBackfaces : false, anchor : 'center'}).rotz(toRad Babe).translate 75,98
  logo.scale 0.4
  logo.translate 370,-70
  mdl.remove logo

  context1.render()
  context2.render()
  
</script>
<svelte:head>
  <title>Star</title>
</svelte:head>
<div class="pageContainer">
  <h5>Select Platonic Skeletons, add segments, rotate 'em and save as 3D SVG files: Have Fun</h5>
<div class="sb show dropdown-content" >
  Shapes: {#each _.keys(G.Polyhedra) as theShape  }
    <Checkme n={theShape} update={updateShapesWanted} v={false} />
  {/each}
</div>
<hr/>
<div class="sb show dropdown-content" >
  <a class="button" on:click={()=>makeScene(filters,filters.vertex=!filters.vertex)} href="#">
    {#if (filters.vertex) } hide {:else} show {/if} points</a>
  <a class="button" on:click={()=>makeScene(filters,filters.labels=!filters.labels)} href="#">
    {#if (filters.labels) } hide {:else} show {/if} labels</a>
</div>
<div class="sb show dropdown-content" >
  {#each _.keys(segmentsByMagnitude) as m}
    <Checkme n={m} update={makeResponsiveScene} v={segmentsActive[m]} />
  {/each}
</div>
<hr/>


<div>
  <figure style="float:left; margin: 0 0 0 0">
    <canvas width="400px" style="background:tan" height="400px" id="seen-canvas1"></canvas>
    <figcaption>
      <button on:click={snapshot('seen-svg1',scene1)}>Save Left Image</button>
    </figcaption>
  </figure>
  <figure style="margin: 0 0 0 0">
    <canvas width="400px" style="background:tan" height="400px" id="seen-canvas2"></canvas>
    <figcaption width="400px" style="width:400px">
      <button on:click={snapshot('seen-svg2',scene2)}>Save Right Image</button>
    </figcaption>
  </figure>
  <div id="SVGstuff" class="hidden" >
    <svg width="400" height="400" id="seen-svg1" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
    <svg width="400" height="400" id="seen-svg2" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
  </div>
</div>
</div>

<style>
.dropdown-content {
  display: none;
  background-color: #f6f6f6;
  min-width: 230px;
  border: 1px solid #ddd;
  z-index: 1;
}
.button {
  margin-left: 2px;
}
select {height:140px}

/* Show the dropdown menu */  
.show {display:block;}  
.sb {
  display: flex; 
  flex-wrap: wrap; 
  justify-content: center;
  }
.hidden {
position: absolute;
left: -999px;
}
</style>
