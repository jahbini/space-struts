<script lang="coffeescript" type="text/coffeescript">

import Select from 'svelte-select'
import * as seenModule from '$lib/seen.m.coffee'
import { onMount } from 'svelte'
import  _  from 'underscore'
import { page } from '$app/stores';
import { GeoPhi, M } from '$lib/coffee/geoPhi.coffee'
import ColorPicker from 'svelte-awesome-color-picker';


duh=($page.url.searchParams.get 'useShapes') || []
duh=  duh.split /, ?/ if 'string' == typeof duh

useShapes = ("#{shape}": shape for shape in duh) || {}

G={Polyhedra:[]}
# C is the creation, and is a series of triangles segments
# it is created with a single segment as a starting point
C={}

svgSize=600
defaultSize=48
context1="undefined"
dotsToShow=null
faceColors = {}
facesToShow=null
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
cliqueTriangleToShow=null
# cliqueTriangles are used to show the coords for all the triangles in the clique


selected={}
scene1=null
scene2=null
xform=null

pageState=
  vertex: false
  labels: false
  #segmentMagnitudes: {}
  #angleMagnitude: ""  #a string value of format 999.999 0-360
  magnitude: false
  useShapes: useShapes 
  showFacesNow: true
  cliquesToShow: {}
  openSegments:[]
  activeClique: null
  activeCliqueTriangle: null
  structure: []

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
  p=seen.Shapes.path ...points
  p.cullBackfaces = false
  m= new seen.Material new seen.Colors.hex color
  m.a=0xff
  p.stroke m
  p.surfaces[0].fillMaterial = fill
  p.surfaces[0]["stroke-width"]=1
  p

normalizeXYZ = (pointsV6) ->
    pointsXYZ = []
    for s in pointsV6
      [x,y,z] = s.sixPhiToCartesianDisplay()
      pointsXYZ.push seen.P(x,y,z)
    pointsXYZ


wireframe = (points,color = "#000000",fill=null,seenBias=null)->
  pointLowdown = normalizeXYZ G.normalizeFrame points,seenBias
  p=seen.Shapes.path pointLowdown
  p.cullBackfaces = false
  if color.constructor?.name == "Material"
    m= color
  else
    m= new seen.Material new seen.Colors.hex color
    m.a=0xff
  p.stroke m
  p.surfaces[0].fillMaterial = fill
  p.surfaces[0]["stroke-width"]=1
  p

rgbObj = r:50,g:50,b:200,a:0.2

materialfiller= null

showSegments = (segments,color="#000000")->
  p=new seen.Model()
  return p unless segments.length
  for s in segments
    p.add wireframe s.path, color if s
  p.scale defaultSize
  p

hexColorFromID = (id)->
    col= id.match(/[f|F|p|P|z|H|h|O|o]{3}/)
    #console.log "HEX Color",col,id
    return "#000000" unless col
    hueman = '#'
    for hueStrength in col[0]
      switch hueStrength
        when 'S' then hueman += 'C0'
        when 's' then hueman += '20'
        when 'M' then hueman += 'E0'
        when 'm' then hueman += '10'
        when 'H' then hueman += 'B0'
        when 'h' then hueman += '20'
        when 'z' then hueman += '60'
        when 'f' then hueman += '90'
        when 'F' then hueman += 'D0'
        when 'p' then hueman += '20'
        when 'P' then hueman += '40'
        when 'o' then hueman += '30'
        when 'O' then hueman += '70'
    #console.log "Hex color",hueman
    hueman

makeColorFromFace = (fID,transparency=10)->
    makeColorFromID fID,transparency

makeColorFromID = (id,transparency=10)->
    hueman= hexColorFromID id
    faceColor = seen.Colors.hex hueman
    faceColor.a = transparency
    new seen.Material faceColor
  
showCentroid = (faces,color="#000000")->
  p=new seen.Model()
  return p unless faces.length
  for s in faces
    centroid = G.formPointsfromPhi "#zzz"
    items= G.formPointsFromPhi s
    for pp in items
      centroid.add pp

    centroid.divide 5
    tet = seen.Shapes.tetrahedron()
    tet.scale .04
    tet.translate centroid.x,centroid.y,centroid.z
    p.add tet
  p.scale defaultSize
  p

fiboTriangles = []
cnames = []

splitName = (longName)->
  value = longName.split /-|<|>/
  return value

useTriangle=(event)->
  debugger
  triangle = G.moveTriangle pageState.activeClique,pageState.activeCliqueTriangle
  for seg in triangle.segments
    pageState.openSegments.push seg
  pageState.activeClique=null
  pageState.activeCliqueTriangle=null
  pageState.structure.push triangle
  clearCliqueInSegments()

#    stripName(T,pageState.activeClique)

stripName=(tID,sID)->
  segParts=sID.split />|-|</g
  return tID.split(/-|<|>/g).join('').replace(segParts[0],'').replace(segParts[1],'')


# display the active cantidate triangle.  The triangle's three sides
# will become base segments for more segments if the triangle is accepted by the UI.
displayTriangle = (sID,tID)->
  triangle = M.MM[tID].value
  segment=M.MM[sID].value
  p = new seen.Model()
  ps= tID.split /-|<|>/g
  nickName = segment.vetric.toName()
  offsetSegment = G.cliques[nickName][tID][0]
  cliquePoint = G.cliques[nickName][tID][1]
  tmidPointV6 = M.MM[offsetSegment].value.midPoint
  # translate cantidate triangle to the active segment
  if pageState.showFacesNow
    p.add wireframe ps,"#00f000", faceColors[triangle.face],200
  ps =  G.normalizeFrame ps
  ps = ps.map( (p) -> p.sub(tmidPointV6).add(segment.midPoint) )
  p.add wireframe ps,"#00f000", faceColors[triangle.face],200
  p.scale defaultSize
      
# G.cliques are global structure with segments associated with all triangles
# with one edge parallel to the segmentID
showClique=(sID)->
  cliqueTriangles = []
  # the segment sID is parallel to the original nickname segment 
  segment=M.MM[sID].value
  nickName = segment.vetric.toName()
  p=new seen.Model()
  # go through all the triangles of the clique
  triangles = G.cliques[nickName]
  activeTriangle = pageState.activeCliqueTriangle 
  for k,t of triangles
    # k is "#xyz>#xyz>#xyz"
    # t is [ segment parallel to nickName,  "#xxx" ] 
    if k == activeTriangle
      crayon = new seen.Material seen.C 240,240,240,80
    else
      crayon = new seen.Material seen.C 100,100,100,40
      
    offsetSegment = t[0]
    #push the triangle full name and "#xxx" out to the User Interface
    cliqueTriangles.push [k,t[1] ]

    #calculate the displacement needed from distance between midpoints
    tmidPointV6 = M.MM[offsetSegment].value.midPoint

    #put up a wireframe of the displaced triangle
    ps = for poin in (k.split /-|<|>/)
      r = GeoPhi.createPhiPoint poin
      r=r.sub(tmidPointV6).add(segment.midPoint)
      r

    p.add wireframe ps ,crayon

    mdl1.add showPoints ps ,crayon

  p.scale defaultSize
  p


###+
# descr: generate the vertices as tetrahedrons from seen's model mdl
# param: mdl seenjs model to attach this graphic
###
showPoints = (points,color=null)->
  p = new seen.Model()
  for point in points
    glyf=seen.Shapes.tetrahedron 1
    glyf.fill glyf.filler
    if color == null && point.ID
      glyf.fill makeColorFromID point.ID,220
    else
      glyf.fill color
    [x,y,z] = point.sixPhiToCartesianDisplay()
    glyf.scale 5
    glyf.translate defaultSize*x,defaultSize*y,defaultSize*z
    p.add glyf
  p

makeFaceColor = (sID,transparency=40)->
  #faces are distinguished by the ordinals of the face square points
  # these are strings matching #xxx-#xxx where x == "o" (-1) or "O" (1)
  sCO = sID.replace /[^oO]/g,""
  sCO ='0o'+sCO.replaceAll("o","1").replaceAll("O","7")
  sCO = (17933*Number(sCO)).toString 16
  sCO = "#"+sCO[0..5]
  faceColor = seen.Colors.hex sCO
  faceColor.a = transparency
  new seen.Material faceColor

colorFaces = (faces,color="#000000")->
  faceColors = {}
  for s of faces
    faceColors[s]= makeFaceColor faces[s]
  faceColors

showFaces = (faces,color="#000000")->
  p=new seen.Model()
  for s of faces
    items= G.formPointsFromPhi faces[s]
    p.add wireframe items, color, faceColors[s]
  p.scale defaultSize
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
    #scene1.camera.rotx Math.PI/Math.PI
    scene1.camera.translate 0,-10,-500
    scene2.camera.translate 0,-10,0
    #scene2.camera.roty 0.55

  console.log "xform",xform if xform?
  mdl1.transform xform if xform
  mdl2.transform xform if xform

  # Create render context into seen- canvas or svg
  context1 = seen.Context('seen-canvas1', scene1)
  setTimeout context1.render,1

  dragger = new seen.Drag('seen-canvas1', {inertia : true})
  dragger.on('drag.rotate', (e) ->
    xform = seen.Quaternion.xyToTransform(e.offsetRelative...)
    mdl1.transform(xform)
    mdl2.transform(xform)
    context1.render()
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
  
  context1.render()
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
    G=new GeoPhi()
    colorFaces G.Faces
    fiboTriangles= G.fiboTriangles

    mdl1 = seen.Models.default()
    mdl2 = seen.Models.default()
    mdl1.cullBackfaces = false
    mdl2.cullBackfaces = false
    mdl2= mdl1
    materialfiller= new seen.Material seen.C 40,60,80,30
    glyf.filler = new seen.Material seen.C 0x4c,0xc4,0x88,0xff
    setSvgSize true
    updateShapesWanted("DodecahedralPair")
  
setSvgSize=(big=true)->
  if big
    svgSize=400
    defaultSize=98
  else
    svgSize=200
    defaultSize=58
  initializeContext()
  makeScene()

###
# updateShapesWanted
# called from user interaction, and recalculates permissable vertices
###
updateShapesWanted = (shape) ->
  console.log "Update Shapes",shape
  pageState.useShapes={}
  pointsFromShapes= []
  pageState.segmentMagnitudes = []
  pointsFromShapes=pointsToShow.concat G.Polyhedra[shape]
  
  ###
  {segmentNames,segmentsByMagnitude} = G.createSegments pointsFromShapes
  # remove any segments that don't have a length of the shapes displayed
  for k of pageState.segmentMagnitudes
    pageState.segmentMagnitudes[k] = segmentsByMagnitude[k]?
  ###
  
  pageState=
    vertex: pageState.vertex
    labels: pageState.labels
    #segmentMagnitudes: pageState.segmentMagnitudes
    magnitude: pageState.magnitude
    #angleMagnitude: ""
    useShapes: pageState.useShapes
    showTriangles: false
    showFacesNow: pageState.showFacesNow
    openSegments: pageState.openSegments
    activeClique: null
    activeCliqueTriangle: null
    structure: pageState.structure
 
  makeScene()
  context1.render()



showSomeCliqueTriangles=(triName)->
  pageState.activeCliqueTriangle =  triName
  makeScene()

clearSomeCliqueTriangles=()->
  pageState.activeCliqueTriangle=null
  cliqueTriangles=[]
  makeScene()

showCliqueInSegments=(segment)->
  pageState.activeClique = segment
  pageState.activeCliqueTriangle=null
  noCliqueTriangle = document.getElementById "clearTriangles"
  noCliqueTriangle.checked = true
  makeScene()

clearCliqueInSegments=()->
  cliqueTriangles = []
  pageState.activeClique=null
  pageState.activeCliqueTriangle=null
  makeScene() 


highlightCliqueSegment=(sID)->
  p = new seen.Model()
  ps=M.MM[sID].value.path
  highLight= wireframe ps,"#ffffff"
  highLight.surfaces[0]["stroke-width"]=8
  p.add highLight
  p.scale defaultSize
  p

renderIt = ()->
  context1.render()

makeScene= ()->
  ###
  # seen is now loaded and can be used.
  # computation for display will proceed.
  ### 

  # remove all children from build up structure, but keep it's transform matrix
  mdl2.children=[]
  mdl1.remove linesToShow if linesToShow
  linesToShow = {}
  # first calculate all the segments from the whole list of points
  #
  pointsToShow = pointsFromShapes
  mdl1.remove facesToShow if facesToShow
  if pageState.showFacesNow
    facesToShow = showFaces  G.Faces
    mdl1.add facesToShow 
    #mdl1.add showCentroid G.Faces

  mdl1.remove dotsToShow if dotsToShow
  if pageState.vertex
    dotsToShow = showPoints pointsToShow
    #dotsToShow.translate 220,180 
    mdl1.add dotsToShow
  
  mdl1.remove labels if labels
  if pageState.labels
    labels = showPointNames pointsToShow
    mdl1.add labels
  
   
  mdl1.remove cliquesToShow if cliquesToShow
  if pageState.activeClique
    cliquesToShow = showClique pageState.activeClique
    mdl1.add cliquesToShow 
    mdl2.add highlightCliqueSegment pageState.activeClique

  mdl1.remove cliqueTriangleToShow if cliqueTriangleToShow
  if pageState.activeCliqueTriangle && pageState.activeClique
    #show the relocated activeCliqueTriangle
    mdl2.add displayTriangle pageState.activeClique,pageState.activeCliqueTriangle
   
  ###
  # show the complete structure on mdl2
  ###
  zero = GeoPhi.createPhiPoint "#zzz"
  if pageState.openSegments.length == 0
    #pageState.openSegments.push G.moveSegment G.cliqueNames[2],zero
    pageState.openSegments.push G.moveSegment "#fPz-#zFP" ,zero
    pageState.openSegments.push G.moveSegment "#OOO-#fPz",zero
  for segment in pageState.openSegments  
    temp = M.MM[segment]
    mdl2.add showSegments [temp.value],"#8F50FF"
  for t in pageState.structure
    mdl2.add (wireframe t.path,"#000000",faceColors[t.face],200).scale defaultSize
  #
  #mdl2.add movedTriangle

  scene1.flushCache()
  scene2.flushCache()
  # re-align the views if the transform has shifted
  mdl1.transform xform if xform
  mdl2.transform xform if xform
  # show the images
  context1.render()
  

</script>
<svelte:head>
  <title>Star</title>
</svelte:head>
<div class="pageContainer grid">
<div>
  <figure style="float:left; margin: 0 0 0 0">
    <canvas width={svgSize+"px"} style="background:#b6b6b6" height={svgSize+"px"} id="seen-canvas1"></canvas>
  </figure>
  <!---
  <figure style="margin: 0 0 0 0">
    <canvas width={svgSize+"px"} style="background:#b6b6b6" height={svgSize+"px"} id="seen-canvas2"></canvas>
  </figure>
  --->
  <div id="SVGstuff" class="hidden" >
    <svg width="400" height="400" id="seen-svg1" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
    <svg width="400" height="400" id="seen-svg2" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" version="1.0" ></svg>
  </div>
</div>


<div class="mini grid container" >
<div class="container" on:load={ updateShapesWanted("DodecahedralPair") }>
  <a class="button" on:click={()=>makeScene(pageState,pageState.showFacesNow=!pageState.showFacesNow)} href="#">
    {#if (pageState.showFacesNow) } Hide {:else} Show {/if} faces</a>
  - -
  <a class="button" on:click={()=>makeScene(pageState,pageState.vertex=!pageState.vertex)} href="#">
    {#if (pageState.vertex) } Hide {:else} Show {/if} points</a>
  - -
  <a class="button" on:click={()=>makeScene(pageState,pageState.labels=!pageState.labels)} href="#">
    {#if (pageState.labels) } Hide {:else} Show {/if} labels</a>
      <a class="button" on:click={snapshot('seen-svg2',scene2)}>Save Right Image</a>
      <a class="button" on:click={snapshot('seen-svg1',scene1)}>Save Left Image</a>

</div>

<div >
  <h5>Open Segments</h5>
  <small><a class="button" name="openSegments" value={ null } bind={null} on:click={clearCliqueInSegments } >
  none</a></small>
  {#each pageState.openSegments as segment }
  <p>
  <small><a class="button" style="color:{hexColorFromID(segment)}" name="openSegments" value={ segment } bind={segment} on:click={showCliqueInSegments(segment) } >
  {segment}</a></small>
  </p>
  {/each}

</div>
<div>
  <h6>Triangles</h6>
  {#if (pageState.activeCliqueTriangle ) } 
  <a class="button"  on:click={useTriangle} href="#" > Use This Triangle </a>
   {/if}
  <fieldset>
  <a class="button"  id="clearTriangles" name="clique" value="none" checked on:click={clearSomeCliqueTriangles}  >
  None
  </a>
  {#each cliqueTriangles as triName }
  <p>
  <small>
  <a class="button"  name="clique" style="color:{hexColorFromID(triName[1])}" value={triName}  on:click={showSomeCliqueTriangles(triName[0]) } >
  {triName[1]}
  </a></small>
  </p>
  
  {/each}
  </fieldset>

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
p { margin-bottom: 2px;}
.hidden {
position: absolute;
left: -999px;
}
</style>
