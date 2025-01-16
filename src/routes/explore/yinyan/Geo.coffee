import { Memo } from './memo.coffee'
import _ from 'underscore'
import * as seenModule from '$lib/seen.m.coffee'
import {reflectPointAcrossPlane,rotatePointAroundLine} from './rotate.js'

export M = new Memo()

fe= (Math.sqrt(5)-1)/2.0
Phi= (1+Math.sqrt 5)/2

c1=(Math.sqrt(5)-1)/4.0
menie= (Math.sqrt(5)-1)/4.0
c2=(Math.sqrt(5)+1)/4.0
enie= (Math.sqrt(5)+1)/4.0

stan=(Math.sqrt(10.0+2.0*Math.sqrt(5)))/4.0
laurel=(Math.sqrt(10.0-2.0*Math.sqrt(5)))/4.0



#  "Z": 0
decode = 
  "z": 0
  "O": 1
  "o": -1
  "f": -1/Phi
  "F": 1/Phi
  "E": enie
  "M": menie
  "e": -enie
  "m": -menie
  "S": stan
  "s": -stan
  "L": laurel
  "l": -laurel
  "G": Phi+1/Phi
  "g": -Phi-1/Phi
  "H": 1-1/Phi
  "h": -1+1/Phi
  "p": -Phi
  "P": Phi

#"#ooO-#zfP-#OoO-#Fpz-#fpz",  # Face A
planeVertices = [
    [decode['z'], decode['f'],decode['P']],
    [decode['F'], decode['p'],decode['z']],
    [decode['f'], decode['p'],decode['z']],
  ]; #// Plane defined by a face of the dodecahedron
###
  Memo API
  saveThis: (key, value)->
  theLowdown: (key)=> returns current info on value at key
  waitFor: (aList,andDo)=> wait for updates to ANY of the aList and call andDo via promise
  notifyMe: (n,andDo)=>
###
 
#convert a string like "#FPz-#Fpz-..." into an array of point names
splitIntoNames = (longName)->
  value = longName.split /-|<|>/
  return value

cliques= {}
cliqueNames = []
cnames = []

stripName=(sID,tID)->
  segParts=sID.split />|-|</g
  rValue=tID.split(/<|>|-/g).join('').replace(segParts[0],'').replace(segParts[1],'')
  return rValue
  

createCliques = (G) ->
  return [] unless G.fiboTriangles.length
  cantidates = G.fiboTriangles.slice 0
  for  masterTriangle in cantidates
    for s,idx in masterTriangle.value.segments
      usedPointNames = {}
      sV = (M.theLowdown s).value.vetric
      sVmS = sV.magnitudeSquared()
      cliques[s] = {"#{masterTriangle.value.ID}": {} }
      if masterTriangle.value.ID == "OoO-#zFP"
        debugger
      for cantidateTriangle in cantidates
        for cc in cantidateTriangle.value.segments
          possiblePoint = stripName cc,cantidateTriangle.value.ID
          #if we have already a triangle that reaches this point, skip this one 
          if possiblePoint of usedPointNames
            continue
          cV=(M.theLowdown cc).value.vetric
          # cross product detects parallel segments
          zz=sV.copy().cross cV
          cVmS = cV.magnitudeSquared()
          lDiff = Math.abs cVmS-sVmS
          if lDiff < 0.1  and zz.magnitudeSquared() < 0.1
            cliques[s][cantidateTriangle.value.ID]=[cc,possiblePoint]
            usedPointNames[possiblePoint] = true

  cnames = for s of cliques
    s
  cliqueNames = cnames.slice()
  return {cliques,cliqueNames}


export class Geo
  square = "#ffz-#Ffz-#FFz-#fFz"
  pentagon = "#zFP-#OOO-#PzF-#OoO-#zfP"
  octahedron = "#O00-#o00-#0o0-#0O0-#00o-#00O"
  cube = "#OOO-#oOO-#OoO-#ooO-#OOo-#oOo-#Ooo-#ooo"
  tetrahedron1="#ooo-#oOO-#OoO-#OOo"
  tetrahedron2="#OOO-#Ooo-#oOo-#ooO"
  icosahedron1 = "#zOF-#zoF-#zof-#zOf-#oFz-#ofz-#OFz-#Ofz-#FzO-#fzO-#Fzo-#fzo"
  icosahedron2 = "#zFO-#zFo-#zfo-#zfO-#Foz-#foz-#FOz-#fOz-#OzF-#Ozf-#ozF-#ozf"
  dodecahedron1="#ooo-#ooO-#oOo-#oOO-#Ooo-#OoO-#OOo-#OOO-#zfp-#zFp-#zfP-#zFP-#pzf-#Pzf-#pzF-#PzF-#fpz-#Fpz-#fPz-#FPz"
  dodecahedron2="#ooo-#oOo-#ooO-#oOO-#Ooo-#OOo-#OoO-#OOO-#zpf-#zpF-#zPf-#zPF-#fzp-#fzP-#Fzp-#FzP-#pfz-#pFz-#Pfz-#PFz"

  pentatwist =  "#zOz-#SMz-#Lez-#lez-#sMz-#zoz-#smz-#lEz-#LEz-#mSz-#ooO-#zfP-#OoO-#Fpz-#fpz"  # Face A
  tetrahedron1Faces = {
    "#ooo-#zzz-#oOO": face: "0"
    "#ooo-#zzz-#OOo": face: "1"
    "#ooo-#zzz-#OoO": face: "2"
    "#OoO-#zzz-#OOo": face: "3"
    "#OoO-#zzz-#oOO": face: "4"
    "#OOo-#zzz-#oOO": face: "5"
    }
  ###+
  # param: ptxt encoding of essential points above text
  # returns new seen.P decorated with ID: ptxt
  # side-effect: adds point to pointName map to this returned value
  ###
  createSeenPoint:  (ptxt,shapeName = "")->
    return null if ! xyz=ptxt.match '[@|#](.)(.)(.)(X[0-9]+)?$'
    if null != p=(M.theLowdown ptxt).value
      p.shapeName[shapeName] = shapeName
      return (M.theLowdown ptxt).value
    p = seen.P decode[xyz[1]],decode[xyz[2]],decode[xyz[3]]
    if ptxt[0] == '@'
      po= reflectPointAcrossPlane [p.x,p.y,p.z],planeVertices
      p = seen.P po[0],po[1],po[2]
    p.d = p.magnitude().toFixed 3
    p.shapeName = { "#{shapeName}": shapeName }
    p.ID = ptxt
    (M.saveThis ptxt, p).value #return just the point value, not the meta info
    
  ###
  # formPointsFrom creates entries in the Memo
  # from the point sets of the shape
  # the originating shape name is used as a tag in the Memo
  ###
  formPointsFrom:(shape,shapeName="") ->
    if typeof shape == "string"
      shape = [ shape ]
    #else
      #debugger
    p = []
    for j in shape
      for i in j.split /-|>|</
        p.push @createSeenPoint i,shapeName
    (M.saveThis shapeName,p).value
    p

  getPointAt:(m)->
    return M.MM[m].value if M.MM[m]?
    null

  ###
  # createSegment:
  # creates two seenpoints from the two ID's
  # the resulting seenpoints are stored into the Memo as an array
  # with attributes ID, d for magnitude (to 3 digits) 
  #
  # the vetric is used to detect parallel segments to create cliques
  # midPoint is used to translate any clique element to a cannonical position
  # for further translation in 3space. it is the midpoint of the segment.
  ###
  createSegment: (ptxt1,ptxt2)->
    if typeof ptxt1  == 'object'
      ptxt2=ptxt1[1]
      ptxt1=ptxt1[0]
    (t=ptxt1; ptxt1=ptxt2; ptxt2=t) if ptxt2<ptxt1
    ID= "#{ptxt1}-#{ptxt2}"
    return ID if M.MM[ID]
    p1=@createSeenPoint ptxt1
    p2=@createSeenPoint ptxt2
    points = [p1,p2]
    vetric=p1.copy().subtract(p2)
    midPoint=p1.copy().add(p2).divide 2
    M.saveThis ID, {ID,points,vetric,midPoint}
    ID

  movedTriangles = 1
  itemsConstructed=0
  
  moveSegment: (segmentName,seenDestination,sID=null) ->
    segment = M.MM[segmentName].value
    midPoint =segment.midPoint
    vetric = segment.vetric
    if seenDestination.constructor.name == "Point"
      path = [ segment.points[0].copy().subtract(midPoint).add(seenDestination), 
        segment.points[1].copy().subtract(midPoint).add(seenDestination) ] 
    else
      path = seenDestination
    midPoint=path[0].copy().add(path[1]).divide 2
    if sID
      unlessSegment = M.MM[sID].value
      residual = unlessSegment.midPoint.copy().subtract(midPoint).magnitudeSquared()
      if residual > 0.1
        ID=segmentName+"X"+itemsConstructed++
        M.saveThis ID, {ID, seenDestination,path,midPoint,vetric}
      else
        ID=null
    else
      ID=segmentName+"X"+itemsConstructed++
      M.saveThis ID, {ID, seenDestination,path,midPoint,vetric}
    
    return ID
    
  normalizeFrame: (points,bias=null)->
    bias=seen.P() unless bias?.constructor?.name == "Point"
    for s in points
      if "Point" == s.constructor.name
        r=bias.copy().add s
        r.ID=s.ID
        r
      else
        r=bias.copy().add @createSeenPoint s
        r.ID=s
        r
        

  moveTriangle: (sID,tID) ->
    triangle = M.MM[tID].value
    segment=M.MM[sID].value
    path=@normalizeFrame (tID.split /-|<|>/)
    nickName = (sID.split 'X')[0]
    offsetSegment = @cliques[nickName][tID][0]
    tMidPoint = M.MM[offsetSegment].value.midPoint
    sMidPoint = M.MM[ nickName].value.midPoint
    path = path.map( (p) -> p.copy().subtract(tMidPoint).add(segment.midPoint) )
    s1=@moveSegment triangle.segments[0],[path[0],path[1]],sID
    s2=@moveSegment triangle.segments[1],[path[1],path[2]],sID
    s3=@moveSegment triangle.segments[2],[path[0],path[2]],sID
    segments=[]
    segments.push s1 if s1
    segments.push s2 if s2
    segments.push s3 if s3
    ID = tID+"--"+movedTriangles++
    face = triangle.face
    {value}=M.saveThis ID, {ID, face, segments,path}
    value

  ###
  # createSegments:
  # iterates through all the points (seen.P) created by createPoint
  # and splices each into all the segments those points create
  # creates Object theSegments with all the segments keyed by the endpoint names
  # creates Object segmentsByMagnitude with all segments sorted and grouped by magnitude
  # theSegments are used in the actual drawing
  # segmentsByMagnitude select the segments to be drawn
  # segments are stored in the Memo with keys of the form '#ppp-#ppp' with end point names ppp
  ###
  createSegments: (points)->
    theSegments={}
    for p1,i in points
      for p2,j in points
          continue if p1==p2
          tag= @createSegment p1.ID,p2.ID
          theSegments[tag]= M.MM[tag]
    segmentsByMagnitude=_.chain(theSegments)
      .map (v)->v.value
      .sortBy 'vetric'
      .groupBy('vetric')
    keySort=(k,v)-> +v < +k
    segmentNames= segmentsByMagnitude.keys().sort(keySort).value()
    segmentsByMagnitude = segmentsByMagnitude.value()
    {segmentNames,segmentsByMagnitude}
    
  angleBetween:(localOrigin,segmentID0,segmentID1)->
    # get the underlying seen value
    localOriginData=M.MM[localOrigin].value
    seg0Vector = M.MM[segmentID0].value
    seg1Vector = M.MM[segmentID1].value
    v0 = seg0Vector.copy().subtract localOriginData
    v1= seg1Vector.copy().subtract localOriginData
    dot = v1.dot v0
    raw= dot / (v1.magnitude() * v0.magnitude() )
    # angle in radians
    #angleRadians = Math.atan2(p2.y - p1.y, p2.x - p1.x);
    # angle in degrees
    angleDeg = Math.acos(raw) * 180 / Math.PI;
    angleDeg = angleDeg.toFixed 3
    
  createTriangle: ( p1,p2,p3,face)->
    key = [p1,p2,p3].sort()
    p1=key[0]
    p2=key[1]
    p3=key[2] 
    s1= @createSegment p1,p2
    s2= @createSegment p2,p3
    s3= @createSegment p1,p3
    ID= "#{p1}>#{p2}>#{p3}"
    M.saveThis ID,
      ID: ID
      path:[p1,p2,p3]
      segments:[s1,s2,s3]
      face: face

  # createAngles takes points, and segments .  it returns the angle that the segment makes from the point.
  # all the open triangles that are inspected are sorted by angle magnitude
  # the magnitudes are sorted and converted into groups of angles
  createAngles: (points, segments)->
    biVectors = {}
    for i in points
      for j in segments
        continue unless j?.ID
        [leg0,leg1]= j.ID.split /-|<|>/
        continue if  i.ID== leg0 || i.ID == leg1
        d = @angleBetween i.ID,leg0,leg1
        ID="#{i.ID}<#{leg0}-#{leg1}"
        seg0Vector = M.MM[leg0].value
        seg1Vector = M.MM[leg1].value
        path= [seg0Vector,i,seg1Vector]
        M.saveThis ID, {ID,path,d}
        biVectors[ID]=M.MM[ID] 
    anglesByMagnitude=_.chain(biVectors)
      .map (v)->v.value
      .sortBy 'd'
      .groupBy('d')

    keySort=(k,v)-> +v < +k

    angleNames = anglesByMagnitude.keys().sort(keySort).value() 
    anglesByMagnitude = anglesByMagnitude.value()
    {angleNames,anglesByMagnitude}


  makeHut: (points,value,coordinateID,inner)-> #left top, right top, left bottom,right bottom
    mapp=[0,1,2,0,1]
    shiftInnerToOuter = true
    ex=mapp[coordinateID+1]
    wy=mapp[coordinateID+2]
    pt=[]
    pt[coordinateID]=inner[0]
    pt[ex]='F'
    pt[wy]='z'
    ptID= '#'+pt.join ''
    pl=[]
    if shiftInnerToOuter
      pl[coordinateID]=inner[0]  #JAH
    else
      pl[coordinateID]=inner[1]
    pl[ex]='z'
    pl[wy]='F'
    plID= '#'+pl.join ''
    pr=[]
    if shiftInnerToOuter
      pr[coordinateID]=inner[0]  #JAH
    else
      pr[coordinateID]=inner[1]
    pr[ex]='z'
    pr[wy]='f'
    prID= '#'+pr.join ''
    pb=[]
    pb[coordinateID]=inner[0]
    pb[ex]='f'
    pb[wy]='z'
    pbID= '#'+pb.join ''

    makeT = (p1,p2,p3,belongsTo="hut")=>
      t1=@createTriangle p1,p2,p3,p3
      @Faces[t1.value.ID]=p3

    makeT points[0][0],ptID,pbID
    makeT points[0][1],ptID,pbID
    makeT points[1][0],ptID,pbID
    makeT points[1][1],ptID,pbID
    makeT points[0][0],points[0][1],ptID
    makeT points[1][0],points[1][1],pbID
    makeT points[0][0],points[1][0],ptID
    makeT points[0][1],points[1][1],pbID
    makeT points[0][1],points[1][1],ptID
    makeT points[0][0],points[1][0],pbID

    makeT points[0][0],plID,prID
    makeT points[0][1],plID,prID
    makeT points[1][0],plID,prID
    makeT points[1][1],plID,prID
    makeT points[0][0],points[1][0],plID
    makeT points[0][1],points[1][1],prID
    makeT points[1][0],points[1][1],prID
    makeT points[0][0],points[0][1],plID
    makeT points[1][0],points[1][1],plID
    makeT points[0][0],points[0][1],prID



  examineFaces:()->
    ones="Oo"
    inner="PH"
    for x in ones
      f0=for y in ones
        for z in ones
          "#"+x+y+z
      @makeHut f0,x,0,inner
      inner="ph"

    inner="PH"
    for y in ones
      f0=for z in ones
        for x in ones
          "#"+x+y+z
      @makeHut f0,y,1,inner
      inner="ph"

    inner="PH"
    for z in ones
      f0=for x in ones
        for y in ones
          "#"+x+y+z
      @makeHut f0,z,2,inner
      inner="ph"

  ###
  ###

  # create the fiboTriangles on each of the 12 faces
  createFiboTriangles: (faces)->
    all=[]
    for sa,face of faces
      names = splitIntoNames face
      if names.length == 3
        all.push [ @createTriangle names[0],names[1],names[2],sa ] 
        continue
      itms = [ ...names,...names]
      for i in [0..names.length+1 ]
        for j in [2..3]
          all.push @createTriangle itms[i],itms[i+1],itms[i+j],sa
    all.flat()

  constructor:()->
    @Faces = {}
    @Faces2=
      "#fff-#zzz-#fFF": "#fzF"
      "#fff-#zzz-#FFf": "#fzf"
      "#fff-#zzz-#FfF": "#fFz"
      "#FfF-#zzz-#FFf": "#FzF"
      "#FfF-#zzz-#fFF": "#Fzf"
      "#FFf-#zzz-#fFF": "#fFz"

      "#FFF-#zzz-#Fff": "#zfF"
      "#FFF-#zzz-#ffF": "#zff"
      "#FFF-#zzz-#fFf": "#Ffz"
      "#fFf-#zzz-#ffF": "#zFF"
      "#fFf-#zzz-#Fff": "#zFf"
      "#ffF-#zzz-#Fff": "#Ffz"


    @Faces2= [
     #dodecahedron
     "#ooO-#zfP-#OoO-#Fpz-#fpz",  # Face A
     "#oOo-#zFp-#OOo-#FPz-#fPz",   # Face a
     "#ooo-#fpz-#ooO-#pzF-#pzf",   #Face B
     "#OOo-#FPz-#OOO-#PzF-#Pzf",   #Face b
     "#ooo-#zfp-#Ooo-#Fpz-#fpz",    #Face C
     "#oOO-#zFP-#OOO-#FPz-#fPz",   #Face c
     "#Ooo-#Fpz-#OoO-#PzF-#Pzf",  # Face D
     "#oOo-#fPz-#oOO-#pzF-#pzf"   # Face d
     "#ooo-#pzf-#oOo-#zFp-#zfp",   #Face E
     "#OoO-#PzF-#OOO-#zFP-#zfP",   #Face e
     "#ooO-#pzF-#oOO-#zFP-#zfP",    #Face F
     "#Ooo-#Pzf-#OOo-#zFp-#zfp",  #Face f
     #icosahedron
     "#zOF-#FzO-#OFz",
     "#zOF-#FzO-#fzO",
     "#zoF-#FzO-#fzO",
     "#zoF-#FzO-#Ofz",
     "#FzO-#Ofz-#OFz",

     "#zOF-#fzO-#oFz",
     "#oFz-#zOF-#zOf",
     "#oFz-#zOf-#fzo",
     "#oFz-#ofz-#fzO",
     "#oFz-#ofz-#fzo"
     "#ofz-#fzO-#zoF"
     "#zOF-#zOf-#OFz",
     "#Fzo-#OFz-#Ofz"
     "#Fzo-#OFz-#zOf"
     "#zOf-#Fzo-#fzo"
     "#zof-#zoF-#ofz"
     "#zof-#ofz-#fzo"
     "#zof-#fzo-#Fzo"
     "#zof-#Fzo-#Ofz"
     "#zof-#Ofz-#zoF"
    ]
    ###

      c1=(Math.sqrt(5)-1)/4.0
      menie= (Math.sqrt(5)-1)/4.0
      c2=(Math.sqrt(5)+1)/4.0
      enie= (Math.sqrt(5)+1)/4.0

      s1=(Math.sqrt(10.0+2.0*Math.sqrt(5)) )/4.0
      s2=(Math.sqrt(10.0-2.0*Math.sqrt(5)) )/4.0
  "E": enie (c2)
  "M": menie (c1)
  "e": -enie (-c2)
  "m": -menie (-c1)
  "S": s1
  "L": s2
  "s": -s1
  "l": -s2
      stan=s1
      laurel=s2

    ###
    @Faces3=[

     "#ooO-#zfP-#OoO-#Fpz-#fpz",  # Face A
     "#oOo-#zFp-#OOo-#FPz-#fPz",   # Face a
     "#ooo-#fpz-#ooO-#pzF-#pzf",   #Face B
     "#OOo-#FPz-#OOO-#PzF-#Pzf",   #Face b
     "#ooo-#zfp-#Ooo-#Fpz-#fpz",    #Face C
     "#oOO-#zFP-#OOO-#FPz-#fPz",   #Face c
     "#Ooo-#Fpz-#OoO-#PzF-#Pzf",  # Face D
     "#oOo-#fPz-#oOO-#pzF-#pzf"   # Face d
     "#ooo-#pzf-#oOo-#zFp-#zfp",   #Face E
     "#OoO-#PzF-#OOO-#zFP-#zfP",   #Face e
     "#ooO-#pzF-#oOO-#zFP-#zfP",    #Face F
     "#Ooo-#Pzf-#OOo-#zFp-#zfp",  #Face f

     "@ooO-@zfP-@OoO-@Fpz-@fpz",  # Face A
     "@oOo-@zFp-@OOo-@FPz-@fPz",   # Face a
     "@ooo-@fpz-@ooO-@pzF-@pzf",   #Face B
     "@OOo-@FPz-@OOO-@PzF-@Pzf",   #Face b
     "@ooo-@zfp-@Ooo-@Fpz-@fpz",    #Face C
     "@oOO-@zFP-@OOO-@FPz-@fPz",   #Face c
     "@Ooo-@Fpz-@OoO-@PzF-@Pzf",  # Face D
     "@oOo-@fPz-@oOO-@pzF-@pzf"   # Face d
     "@ooo-@pzf-@oOo-@zFp-@zfp",   #Face E
     "@OoO-@PzF-@OOO-@zFP-@zfP",   #Face e
     "@ooO-@pzF-@oOO-@zFP-@zfP",    #Face F
     "@Ooo-@Pzf-@OOo-@zFp-@zfp",  #Face f
    ]
    @Faces={}
    faceName= (i)->
      i=i.match /(.[oO]{3}).*(.[oO]{3})/
      i[1]+"-"+i[2]
    for i in @Faces3
      @Faces[ faceName i ]=i

    @Polyhedra = 
      Tetrahedron1: @formPointsFrom tetrahedron1, "tetrahedron"
      Octahedron: @formPointsFrom octahedron,"octahedron"
      Cube: @formPointsFrom cube,"cube"
      Icosahedron1: @formPointsFrom icosahedron1, "icosahedron"
      Dodecahedron1: @formPointsFrom dodecahedron1, "dodecahedron"
      Tetrahedron2: @formPointsFrom tetrahedron2, "tetrahedron"
      Icosahedron2: @formPointsFrom icosahedron2, "icosahedron"
      Dodecahedron2: @formPointsFrom dodecahedron2, "dodecahedron"
      DodecahedralPair: @formPointsFrom @Faces3,"dodecahedralPair"

    #@examineFaces()
    # create the fiboTriangles on each of the 12 faces
    @fiboTriangles= @createFiboTriangles @Faces
    {@cliques,@cliqueNames} = createCliques @
    console.log @cliques["#zoz-#smz"]

