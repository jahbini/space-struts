<script lang="coffeescript" type="text/coffeescript">

import Select from 'svelte-select'
import * as seenModule from '$lib/seen.m.coffee'
import { onMount } from 'svelte'
import  _  from 'underscore'
import { page } from '$app/stores';
import  Checkme from './Checkme.svelte'
import { Geo, M } from './Geo.coffee'
import ColorPicker from 'svelte-awesome-color-picker';


items = ['One', 'Two', 'Three'];
duh=($page.url.searchParams.get 'useShapes') || []
duh=  duh.split /, ?/ if 'string' == typeof duh

useShapes = ("#{shape}": shape for shape in duh) || {}

G={Polyhedra:[]}
# C is the creation, and is a series of triangles segments
# it is created with a single segment as a starting point
C={}

svgSize=200
defaultSize=48
context1="undefined"
context2=null
dotsToShow=null
facesToShow=null
yinYanToShow=null
cliquesToShow=null
labels=null
pointName = {}
# points on screen is the final list of seenPoint values
pointsFromShapes= []
pointsToShow= []
pointsOnScreen=[]

linesToShow=null
segmentsActive={}
segmentsByMagnitude=[]
segmentNames=[]
cliqueTriangles=[]
cliqueTrianglesToShow=null
# cliqueTriangles are used to show the coords for all the triangles in the clique

uiSelectedAngle=null
anglesToShow=null
anglesActive={}
anglesByMagnitude=[]
angleNames=[]

selected={}
scene1=null
scene2=null
xform=null
openSegments = []

pageState=
  vertex: true
  labels: true
  segmentMagnitudes: {}
  angleMagnitude: ""  #a string value of format 999.999 0-360
  magnitude: false
  useShapes: useShapes 
  showFaces: false
  showYinYan: true
  cliquesToShow: {}
  openSegments:[]

###
# the Memo is an object used by Geo with keys of the forms:
# "#xyz" for points
# "#xyx-#xyz" for segments
# "#xyz-#xyz-#xyz" for bivectors
# the elements of the xyz coordinates are
# z: zero 0
# o: -1
# O: +1
# f: -1/Phi
# F: 1/Phi
# p: -Phi
# P: Phi
# where Phi == (1+sqrt(5))/2
#
###
###
# Global level code: At this point, the data in the Geo/Memo can 
# compute seen objects for display.  This code can request data
# for points, segments and soon, triangles according to the UI
# allowed by this code.
###
defaultSize=98
# Create a shape
pSize = 55
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

pointFrame = (points,color = "#000000",fill=null)->
  debugger unless points[points.length-1]
  p=seen.Shapes.path ...points
  p.cullBackfaces = false
  m= new seen.Material new seen.Colors.hex color
  m.a=0xff
  p.stroke m
  p.surfaces[0].fillMaterial = fill
  p.surfaces[0]["stroke-width"]=1
  p

wireframe = (points,color = "#000000",fill=null)->
  debugger unless points[points.length-1]
  pointLowdown = for s in points
    if "Point" == s.constructor.name
      s
    else
      G.createSeenPoint s
  p=seen.Shapes.path pointLowdown
  p.cullBackfaces = false
  m= new seen.Material new seen.Colors.hex color
  m.a=0xff
  p.stroke m
  p.surfaces[0].fillMaterial = fill
  p.surfaces[0]["stroke-width"]=1
  p

rgbObj = r:50,g:50,b:200,a:0.2

materialfiller= null

filledAngle = (points)->
  p=seen.Shapes.path points
  p.cullBackfaces = false
  m= seen.C rgbObj.r,rgbObj.g,rgbObj.b,rgbObj.a*255
  m= new seen.Material m
  #p.stroke m
  p.surfaces[0].fillMaterial = materialfiller
  p.surfaces[0]["stroke-width"]=0
  p

showSegments = (segments,color="#000000")->
  p=new seen.Model()
  return p unless segments.length
  for s in segments
    p.add wireframe s.path, color if s
  p.scale defaultSize
  p

makeColorFromID = (id)->
    hueman = '#'
    for hueStrength in id[1...]
      switch hueStrength
        when 'z' then hueman += '60'
        when 'f' then hueman += '90'
        when 'F' then hueman += 'D0'
        when 'p' then hueman += '20'
        when 'P' then hueman += '40'
        when 'o' then hueman += '30'
        when 'O' then hueman += '70'
    faceColor = seen.Colors.hex hueman
    faceColor.a = 40
    faceColor
  
showCentroid = (faces,color="#000000")->
  p=new seen.Model()
  return p unless faces.length
  for s in faces
    centroid = seen.P 0,0,0
    items= G.formPointsFrom s,s
    for pp in items
      centroid.add pp

    centroid.divide 5
    tet = seen.Shapes.tetrahedron()
    tet.scale .04
    tet.translate centroid.x,centroid.y,centroid.z
    p.add tet
  p.scale defaultSize
  p

showFaces = (faces,color="#000000")->
  p=new seen.Model()
  return p unless faces.length
  for s in faces
    items= G.formPointsFrom s,s
    p.add wireframe items, color, new seen.Material makeColorFromID items[1].ID
  p.scale defaultSize
  p

fiboTriangles = []
cliques= {}
cliqueNames = []
cnames = []

splitName = (longName)->
  value = longName.split /-|<|>/
  return value

showYinYan = (faces) ->
  p=new seen.Model()
  return p unless faces.length

  p.scale defaultSize
  p

moveTriangle = (tID,seenPoint)->
  p = new seen.Model()
  p.add wireframe (tID.split /-|<|>/),"#00f000", new seen.Material seen.C 40,60,80,30
  p.translate seenPoint.x,seenPoint.y,seenPoint.z
  p.scale defaultSize/5
      
# cliques are global structure with segments associated with all triangles
# with one edge parallel to the segmentID
showClique=(segmentID)->
  return null unless segmentID?.match /^#.../
  cliqueTriangles = []
  segmentID = (segmentID.split 'X')[0]
  p=new seen.Model()
  triangles = cliques[segmentID]
  for k,t of triangles
    cliqueTriangles.push k
    p.add wireframe (k.split /-|>|</) ,"#0f0f80"
    p.add wireframe (t.split /-|<|>/) ,"#f0f000"
  p.add wireframe (segmentID.split /-|<|>/),"#ff0000"
  p.scale defaultSize
  p

showCliqueTriangle=(ID)->
  debugger
  return null unless splitID= ID?.split /-|<|>/
  p=new seen.Model()
  p.add wireframe splitID,"#0f0f80"
  p.scale defaultSize
  p

showVectors = (segments)->
  p=new seen.Model()
  return p unless segments.length
  for s in segments
    continue unless s
    p.add filledAngle [s.path[0],s.path[1],s.path[2],s.path[0]]

  p.scale defaultSize
  p
  
###+
# descr: generate the vertices as tetrahedrons from seen's model mdl
# param: mdl seenjs model to attach this graphic
###
showPoints = (points)->
  p = new seen.Model()
  for point in points
    glyf=seen.Shapes.tetrahedron 1
    glyf.fill glyf.filler
    glyf.scale 5
    glyf.translate defaultSize*point.x,defaultSize*point.y,defaultSize*point.z
    p.add glyf
  p

showPointNames = (points)->
  cluster = new seen.Model()
  for point in points
    continue if !point
    label=seen.Shapes.text point.ID,{
      font: '10px Roboto'
      cullBackFaces: false
      style: "text-anchor":"end"
    }
    label.fill '#000000'
    label.scale 2.5
    label.translate defaultSize*point.x,defaultSize*point.y,defaultSize*point.z
    cluster.add label
  cluster
    
initializeContext= ()->
  # Create scene and add shape to model
  scene1 = new seen.Scene
    model    : mdl1
    viewport : seen.Viewports.center(400,400)
    cullBackfaces: false

  # Create scene and add shape to model
  scene2= new seen.Scene
    model    : mdl2
    viewport : seen.Viewports.center(400,400)
    cullBackfaces: false

  if svgSize < 300
    scene1.camera.translate -200,200,-300
    scene2.camera.translate -200,200,-300
    #scene2.camera.roty 0.05
  else 
    scene1.camera.rotx Math.PI/Math.PI
    scene1.camera.translate 0,-10,0
    scene2.camera.translate 0,0,-100
    #scene2.camera.roty 0.55

  console.log "xform",xform if xform?
  mdl1.transform xform if xform
  mdl2.transform xform if xform

  # Create render context into seen- canvas or svg
  context1 = seen.Context('seen-canvas1', scene1)
  context2 = seen.Context('seen-canvas2', scene2)
  setTimeout context1.render,1
  setTimeout context2.render,1

  dragger = new seen.Drag('seen-canvas1', {inertia : true})
  dragger.on('drag.rotate', (e) ->
    xform = seen.Quaternion.xyToTransform(e.offsetRelative...)
    mdl1.transform(xform)
    mdl2.transform(xform)
    context1.render()
    context2.render()
  )

  ###
  # Slowly rotate sphere
  rx = 0.0004
  ry = 0.00027
  rz = 0.0027
  frame1=context1.animate()
    .onBefore((t, dt) -> 
      anglesToShow?.rotx(rx).roty(ry).rotz(rz) if anglesToShow?.rotx
      linesToShow?.rotx(rx).roty(ry).rotz(rz) if linesToShow?.rotx
      dotsToShow?.rotx(rx).roty(ry).rotz(rz) if dotsToShow?.rotx
      labels?.rotx(rx).roty(ry).rotz(rz) if labels?.rotx
      )
    .start()
  
  frame2=context2.animate()
    .onBefore((t, dt) -> 
      anglesToShow?.rotx(rx).roty(ry).rotz(rz) if anglesToShow?.rotx
      linesToShow?.rotx(rx).roty(ry).rotz(rz) if linesToShow?.rotx
      dotsToShow?.rotx(rx).roty(ry).rotz(rz) if dotsToShow?.rotx
      labels?.rotx(rx).roty(ry).rotz(rz) if labels?.rotx
      )
    .start()
  
  context1.render()
  context2.render()
  ###

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
  debugger
  console.log "Shooting",value
  number= value.target?.value

mdl1=null
mdl2=null
glyf={}
onMount ->
  if !seen
    setTimeout onMount,50
    return
  else
    G=new Geo()
    fiboTriangles= G.fiboTriangles
    cliques = G.cliques
    cliqueNames = G.cliqueNames


    mdl1 = seen.Models.default()
    mdl2 = seen.Models.default()
    mdl1.cullBackfaces = false
    mdl2.cullBackfaces = false
    materialfiller= new seen.Material seen.C 40,60,80,30
    glyf.filler = new seen.Material seen.C 0x4c,0xc4,0x88,0xff
    setSvgSize true
    updateShapesWanted("Dodecahedron1")
  
setSvgSize=(big=true)->
  if big
    svgSize=400
    defaultSize=98
  else
    svgSize=200
    defaultSize=48
  initializeContext()
  makeScene()

###
# updateShapesWanted
# called from user interaction, and recalculates permissable vertices
###
updateShapesWanted = (shape) ->
  pageState.useShapes={}
  pointsFromShapes= []
  pageState.segmentMagnitudes = []
  pointsFromShapes=pointsToShow.concat G.Polyhedra[shape]
  

  {segmentNames,segmentsByMagnitude} = G.createSegments pointsFromShapes
  # remove any segments that don't have a length of the shapes displayed
  for k of pageState.segmentMagnitudes
    pageState.segmentMagnitudes[k] = segmentsByMagnitude[k]?
  
  pageState=
    vertex: pageState.vertex
    labels: pageState.labels
    segmentMagnitudes: pageState.segmentMagnitudes
    magnitude: pageState.magnitude
    angleMagnitude: ""
    useShapes: pageState.useShapes
    showTriangles: false
    showFaces: false
    showYinYan: true
    openSegments: pageState.openSegments

  makeScene()
  context1.render()
  context2.render()

recalculateAngles=true
howManyAngles = 5
someAngles=0
showSomeAngles=(event=null)->
  return howManyAngles if !event
  howManyAngles = event.target?.value
  makeScene()

cliqueToShow = null
cliqueTriangleToShow = null

showSomeCliqueTriangles=(event)->
  cliqueTriangleToShow = if event.currentTarget.checked then event.currentTarget.name else null
  makeScene()

showSomeCliques=(event)->
  cliqueToShow = if event.currentTarget.checked then event.currentTarget.name else null
  makeScene()

makeAngles= (event)->
  howManyAngles=1
  angleText=[]
  anglesActive={}
  pageState.angleMagnitude=event.detail?.value 
  pageState.showTriangles=true
  makeScene()

setAngleColor=(event)->
  console.log event.detail
  rgbObj= event.detail.rgb
  materialfiller= new seen.Material seen.C rgbObj.r,rgbObj.g,rgbObj.b,rgbObj.a*255
  makeScene()


makeScene= ()->
  
  ###
  # seen is now loaded and can be used.
  # computation for display will proceed.
  ###

  ###
  # if we are forming segments or angles, we need to pprune the
  # pointsFromShapes and form the names and value  lists
  # for the segments or triangles
  ### 
  mdl1.remove linesToShow if linesToShow
  linesToShow = {}
  # first calculate all the segments from the whole list of points
  #
  {segmentNames,segmentsByMagnitude} = G.createSegments pointsFromShapes
  someLines = []
  segmentsActive={}
  someLines= for key,value of pageState.segmentMagnitudes
    continue unless value
    segmentsActive[key]=true
    segmentsByMagnitude[key]
  mapToNames= (t,a)->
    x=a.ID.split /[-|<|>]/
    t[x[0]] =true
    t[x[1]] =true
    t 
  someLines=_.flatten someLines
  if someLines?.length  && !pageState.showTriangles
    linesToShow = showSegments someLines,"#AAAAAA"
    #linesToShow.translate 220,180
    temp1=_.reduce(someLines,mapToNames,{})
    pointsToShow = _.map(temp1,(k,v)->G.getPointAt v)
  else
    pointsToShow = pointsFromShapes
    
  mdl1.remove facesToShow if facesToShow
  if pageState.showFaces
    facesToShow = showFaces  G.Faces
    mdl1.add facesToShow 
    #mdl.add showCentroid G.Faces
   
  mdl1.remove cliquesToShow if cliquesToShow
  cliquesToShow = showClique cliqueToShow
  mdl1.add cliquesToShow 
   
  mdl1.remove cliqueTrianglesToShow if cliqueTrianglesToShow
  mdl2.remove cliqueTrianglesToShow if cliqueTrianglesToShow
  cliqueTrianglesToShow = showCliqueTriangle cliqueTriangleToShow
  mdl1.add cliqueTrianglesToShow 
  mdl2.add cliqueTrianglesToShow
   
  mdl1.remove yinYanToShow if yinYanToShow
  if pageState.showYinYan
    yinYanToShow = showYinYan  G.Faces
    mdl1.add yinYanToShow 
    mdl1.add showCentroid G.Faces
   
  mdl1.remove dotsToShow if dotsToShow
  if pageState.vertex
    dotsToShow = showPoints pointsToShow
    #dotsToShow.translate 220,180 
    mdl1.add dotsToShow
  
  mdl1.remove labels if labels
  if pageState.labels
    labels = showPointNames pointsToShow
    console.log "LABELS",pointsToShow
    #labels.translate 235,180
    mdl1.add labels
  
  #movedTriangle = moveTriangle "#OoO>#fpz>#zfP",seen.P(0.1,0.2,0.3) 
  if pageState.openSegments.length == 0
    pageState.openSegments.push G.moveSegment "#OoO-#fpz",seen.P(0.2,0.3,0.4)
  for segment in pageState.openSegments  
    temp = M.MM[segment]
    mdl2.add showSegments [temp.value],"#8F50FF"
  openSegments = pageState.openSegments
  #mdl2.add movedTriangle


  scene1.flushCache()
  scene2.flushCache()

  context1.render()
  context2.render()
  items=_.keys(G.Polyhedra)
  

</script>
<svelte:head>
  <title>Star</title>
</svelte:head>
<div class="pageContainer">
<div>
  <figure style="float:left; margin: 0 0 0 0">
    <canvas width={svgSize+"px"} style="background:white" height={svgSize+"px"} id="seen-canvas1"></canvas>
  </figure>
  <figure style="margin: 0 0 0 0">
    <canvas width={svgSize+"px"} style="background:white" height={svgSize+"px"} id="seen-canvas2"></canvas>
  </figure>
  <div id="SVGstuff" class="hidden" >
    <svg width="400" height="400" id="seen-svg1" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
    <svg width="400" height="400" id="seen-svg2" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
  </div>
</div>


<div class="container" on:load={ updateShapesWanted("Dodecahedron1") }>
  <a class="button" on:click={()=>makeScene(pageState,pageState.showFaces=!pageState.showFaces)} href="#">
    {#if (pageState.showFaces) } Hide {:else} Show {/if} faces</a>
  - -
  <a class="button" on:click={()=>makeScene(pageState,pageState.showYinYan=!pageState.showYinYan)} href="#">
    {#if (pageState.showYinYan) } Hide {:else} Show {/if} YinYan</a>
  - -
  <a class="button" on:click={()=>makeScene(pageState,pageState.vertex=!pageState.vertex)} href="#">
    {#if (pageState.vertex) } Hide {:else} Show {/if} points</a>
  - -
  <a class="button" on:click={()=>makeScene(pageState,pageState.labels=!pageState.labels)} href="#">
    {#if (pageState.labels) } Hide {:else} Show {/if} labels</a>
      <a class="button" on:click={snapshot('seen-svg2',scene2)}>Save Right Image</a>
      <a class="button" on:click={snapshot('seen-svg1',scene1)}>Save Left Image</a>
      <a class="button" on:click={setSvgSize(true)}>make Big Pix</a>

</div>

<div class="mini grid container" >
<div >
  <h5>Cliques</h5>
  {@debug }
  {#each openSegments as clique }
  <label for={clique} >
  <input name={ clique } multiple bind={clique} type="checkbox" on:input={showSomeCliques } />
  {clique}
  </label>
  {/each}

</div>
<div>
  <h6>Triangles</h6>
  <fieldset>
  {@debug cliqueTriangles}
  {#each cliqueTriangles as triName }
  <label for={triName} >
  <input name={triName}  type="radio" on:input={showSomeCliqueTriangles } />
  {triName}
  </label>
  
  {/each}
  </fieldset>

{#if segmentNames.length > 1} 
<div>
  <h5>Angle?</h5>
    <Select value="none" bind:this={uiSelectedAngle} id="Angles" type="checkbox" inputStyles="box-sizing:border-box;" items={segmentNames} role="switch" on:input={makeAngles}></Select>
</div>
<div>
<ColorPicker hex="#20406080"  on:input={setAngleColor} />
  <label for="range">How Many Triangles?
    <input type="range" on:input={showSomeAngles} min="0" value=1 max="{someAngles.length}"  id="range" name="range">
  </label>
</div>
{/if}
</div>
</div>

</div>

<style>
label {
   float:left;
}
Select {--font-size:small; float:right;}
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
.mini { --font-size:small; --padding:1px; }

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
