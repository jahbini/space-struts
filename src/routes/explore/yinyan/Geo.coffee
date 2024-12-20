import { Memo } from './memo.coffee'
import _ from 'underscore'
import * as seenModule from '$lib/seen.m.coffee'

export M = new Memo()
fe= (Math.sqrt(5)-1)/2.0
Phi= (1+Math.sqrt 5)/2

#  "Z": 0
decode = 
  "z": 0
  "O": 1
  "o": -1
  "f": -1/Phi
  "F": 1/Phi
  "G": Phi+1/Phi
  "g": -Phi-1/Phi
  "H": 1-1/Phi
  "h": -1+1/Phi
  "p": -Phi
  "P": Phi

###
  Memo API
  saveThis: (key, value)->
  theLowdown: (key)=> returns current info on value at key
  waitFor: (aList,andDo)=> wait for updates to ANY of the aList and call andDo via promise
  notifyMe: (n,andDo)=>
###
 
#convert a string like "#FPz-#Fpz-..." into an array of point names
splitName = (longName)->
  value = longName.split /-|<|>/
  return value

# create the fiboTriangles on each of the 12 faces
createFiboTriangles= (faces,G)->
  all=[]
  for sa,face of faces
    names = splitName sa
    if names.length == 3
      all.push [ G.createTriangle names[0],names[1],names[2], sa ] 
      continue
    itms = [ ...names,...names]
    for i in [0..names.length+1 ]
      for j in [2..3]
        all.push G.createTriangle itms[i],itms[i+1],itms[i+j],sa
  all.flat()

cliques= {}
cliqueNames = []
cnames = []

createCliques = (G) ->
  return [] unless G.fiboTriangles.length
  cantidates = G.fiboTriangles.slice 0
  for  masterTriangle in cantidates
    for s,idx in masterTriangle.value.segments
      sV = (M.theLowdown s).value.vetric
      sVmS = sV.magnitudeSquared()
      cliques[s] = {"#{masterTriangle.value.ID}": s }
      for cantidateTriangle in cantidates
        for cc in cantidateTriangle.value.segments
          cV=(M.theLowdown cc).value.vetric
          # cross product detects parallel segments
          zz=sV.copy().cross cV
          cVmS = cV.magnitudeSquared()
          lDiff = Math.abs cVmS-sVmS
          if lDiff < 0.1  and zz.magnitudeSquared() < 0.1
            cliques[s][cantidateTriangle.value.ID]=cc
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
    return null if ! xyz=ptxt.match '#(.)(.)(.)$'
    if null != p=(M.theLowdown ptxt).value
      p.shapeName[shapeName] = shapeName
      return (M.theLowdown ptxt).value
    p = seen.P decode[xyz[1]],decode[xyz[2]],decode[xyz[3]]
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
    shapePoints = for i in shape.split '-'
      @createSeenPoint i,shapeName
    (M.saveThis shapeName,shapePoints).value
    
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
        bias.copy().add s
      else
        bias.copy().add @createSeenPoint s

  moveTriangle: (sID,tID) ->
    triangle = M.MM[tID].value
    segment=M.MM[sID].value
    path=@normalizeFrame (tID.split /-|<|>/)
    nickName = (sID.split 'X')[0]
    offsetSegment = @cliques[nickName][tID]
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
        [leg0,leg1]= j.ID.split "-"
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

  constructor:()->
    @Polyhedra = 
      Tetrahedron1: @formPointsFrom tetrahedron1, "tetrahedron"
      Octahedron: @formPointsFrom octahedron,"octahedron"
      Cube: @formPointsFrom cube,"cube"
      Icosahedron1: @formPointsFrom icosahedron1, "icosahedron"
      Dodecahedron1: @formPointsFrom dodecahedron1, "dodecahedron"
      Tetrahedron2: @formPointsFrom tetrahedron2, "tetrahedron"
      Icosahedron2: @formPointsFrom icosahedron2, "icosahedron"
      Dodecahedron2: @formPointsFrom dodecahedron2, "dodecahedron"

    debugger
    @Faces2 = {
           ###
           "#ooo-#fzp-#oOo-#pFz-#pfz": name: "Dod2 Face E"
           "#ooo-#pzf-#oOo-#zFp-#zfp": name: "Face E"
           "#ooO-#zfP-#OoO-#Fpz-#fpz": name: "Face A"
           "#ooO-#zpF-#OoO-#FzP-#fzP": name: "Dod2 Face A"
           "#oOo-#zFp-#OOo-#FPz-#fPz": name: "Face a"
           "#oOo-#zPf-#OOo-#Fzp-#fzp": name: "Dod2 Face a"
           "#ooo-#fpz-#ooO-#pzF-#pzf": name: "Face B"
           "#ooo-#pfz-#ooO-#zpF-#zpf": name: "Dod2 Face B"
           "#OOo-#PFz-#OOO-#zPF-#zPf": name: "Dod2 Face b"
           "#OOo-#FPz-#OOO-#PzF-#Pzf": name: "Face b"
           "#ooo-#zfp-#Ooo-#Fpz-#fpz": name: "Face C"
           "#ooo-#zpf-#Ooo-#Fzp-#fzp": name: "Dod2 Face C"
           "#oOO-#zFP-#OOO-#FPz-#fPz": name: "Face c"
           "#oOO-#zPF-#OOO-#FzP-#fzP": name: "Dod2 Face c"
           "#Ooo-#Fpz-#OoO-#PzF-#Pzf": name: "Face D"
           "#Ooo-#Pfz-#OoO-#zpF-#zpf": name: "Dod2 Face D"
           "#oOo-#fPz-#oOO-#pzF-#pzf": name: "Face d"
           "#oOo-#pFz-#oOO-#zPF-#zPf": name: "Dod2 Face d"
           "#OoO-#PzF-#OOO-#zFP-#zfP": name: "Face e"
           "#OoO-#FzP-#OOO-#PFz-#Pfz": name: "Dod2 Face e"
           "#ooO-#pzF-#oOO-#zFP-#zfP": name: "Face F"
           "#ooO-#fzP-#oOO-#pFz-#pfz": name: "Dod2 Face F"
           "#Ooo-#Pzf-#OOo-#zFp-#zfp": name: "Face f"
           "#Ooo-#Fzp-#OOo-#PFz-#Pfz": name: "Dod2 Face f"
           ###
           "#fff-#zzz-#fFF": name: "0"
           "#fff-#zzz-#FFf": name: "1"
           "#fff-#zzz-#FfF": name: "2"
           "#FfF-#zzz-#FFf": name: "3"
           "#FfF-#zzz-#fFF": name: "4"
           "#FFf-#zzz-#fFF": name: "5"
           "#GGG-#zzz-#fFF": name: "0"
           "#GGG-#zzz-#FFf": name: "1"
           "#GGG-#zzz-#FfF": name: "2"
           ###
           "#FFF-#zzz-#Fff": name: "Tet 0"
           "#FFF-#zzz-#ffF": name: "Tet 1"
           "#FFF-#zzz-#fFf": name: "Tet 2"
           "#fFf-#zzz-#ffF": name: "Tet 3"
           "#fFf-#zzz-#Fff": name: "Tet 4"
           "#ffF-#zzz-#Fff": name: "Tet 5"
           ###
           }
    @Faces = {
# #oOO - #ooO -#ooo - #oOo
# #OOo - #OOO - #OoO - #Ooo

             "#ooO-#OoO-#fzP": name: "lala"
             "#oOO-#OOO-#fzP": name: "lala"
             "#OoO-#FzP-#fzP": name: "Hut p"
             "#OOO-#FzP-#fzP": name: "Hut p"
             "#OOO-#FzP-#OoO": name: "Hut p"
             "#OOO-#fzP-#OoO": name: "Hut p"

             "#ooO-#FzP-#fzP": name: "Hut p"
             "#oOO-#FzP-#fzP": name: "Hut p"
             "#Ooo-#FzP-#fzP": name: "Hut p"
             "#oOO-#FzP-#ooO": name: "Hut p"
             "#oOO-#fzP-#ooO": name: "Hut p"
             "#OOO-#FzP-#oOO": name: "Hut p"
             "#OoO-#fzP-#ooO": name: "Hut p"
             

             "#OoO-#zFH-#zfH": name: "Hut p"
             "#OOO-#zFH-#zfH": name: "Hut p"
             "#OOO-#zFH-#OoO": name: "Hut p"
             "#OOO-#zfH-#OoO": name: "Hut p"

             "#ooO-#zFH-#zfH": name: "Hut p"
             "#oOO-#zFH-#zfH": name: "Hut p"
             "#oOO-#zFH-#ooO": name: "Hut p"
             "#oOO-#zfH-#ooO": name: "Hut p"
             "#OOO-#zFH-#oOO": name: "Hut p"
             "#OoO-#zfH-#ooO": name: "Hut p"
             



             "#oOo-#fHz-#oOO": name: "Hut h"
             "#OOO-#fHz-#FHz": name: "Hut h"
             "#OOo-#FHz-#OOO": name: "Hut h"
             "#OOo-#fHz-#oOo": name: "Hut h"
             "#OOo-#FHz-#fHz": name: "Hut h"
             "#oOO-#zHF-#OOO": name: "bla bla"

             "#OOo-#zPf-#oOO": name: "Hut p"
             "#oOO-#zPf-#OOO": name: "hut P"
             "#oOo-#zPf-#oOO": name: "Hut p"
             "#OOO-#zPf-#zPF": name: "Hut p"
             "#oOO-#zPf-#zPF": name: "Hut p"
             "#OOo-#zPf-#OOO": name: "Hut p"
             "#OOo-#zPf-#oOo": name: "Hut p"
             "#oOO-#zPF-#OOO": name: "bla bla"

             "#oOo-#fHz-#oOO": name: "Hut h"
             "#OOO-#fHz-#FHz": name: "Hut h"
             "#oOO-#fHz-#OOO": name: "Hut h"
             "#OOo-#FHz-#OOO": name: "Hut h"
             "#OOo-#fHz-#oOo": name: "Hut h"
             "#OOo-#FHz-#fHz": name: "Hut h"

             "#ooo-#zpf-#ooO": name: "Hut p"
             "#OoO-#zpf-#zpF": name: "Hut p"
             "#ooO-#zpf-#zpF": name: "Hut p"
             "#Ooo-#zpf-#OoO": name: "Hut p"
             "#Ooo-#zpf-#ooo": name: "Hut p"
             "#Ooo-#zpf-#ooo": name: "Hut p"
             "#ooO-#zpF-#OoO": name: "hut P"

             "#ooo-#fhz-#ooO": name: "Hut h"
             "#OoO-#fhz-#Fhz": name: "Hut h"
             "#ooO-#fhz-#OoO": name: "Hut h"
             "#Ooo-#Fhz-#OoO": name: "Hut h"
             "#Ooo-#fhz-#ooo": name: "Hut h"
             "#Ooo-#Fhz-#fhz": name: "Hut h"

             "#ooo-#fzp-#oOo": name: "Hut P"
             "#OOo-#fzp-#Fzp": name: "Hut P"
             "#oOo-#fzp-#Fzp": name: "Hut P"
             "#Ooo-#Fzp-#OOo": name: "Hut P"
             "#Ooo-#fzp-#ooo": name: "Hut P"
             "#Ooo-#fzp-#ooo": name: "Hut P"
             "#oOo-#Fzp-#OOo": name: "Hut P"

             "#oOo-#zfh-#zFh": name: "Hut H"
             "#ooo-#zfh-#oOo": name: "Hut H"
             "#oOo-#zFh-#OOo": name: "Hut H"
             "#Ooo-#zFh-#OOo": name: "Hut H"
             "#Ooo-#zfh-#ooo": name: "Hut H"
             "#Ooo-#zFh-#zfh": name: "Hut H"


             "#ooO-#fzP-#oOO": name: "Hut P"
             "#OOO-#fzP-#FzP": name: "Hut P"
             "#oOO-#fzP-#FzP": name: "Hut P"
             "#OoO-#FzP-#OOO": name: "Hut P"
             "#OoO-#fzP-#ooO": name: "Hut P"
             "#OoO-#fzP-#ooO": name: "Hut P"
             "#oOO-#FzP-#OOO": name: "Hut P"

             "#oOO-#zfH-#zFH": name: "Hut H"
             "#ooO-#zfH-#oOO": name: "Hut H"
             "#oOO-#zFH-#OOO": name: "Hut H"
             "#OoO-#zFH-#OOO": name: "Hut H"
             "#OoO-#zfH-#ooO": name: "Hut H"
             "#OoO-#zFH-#zfH": name: "Hut H"



             "#oOO-#pFz-#ooO": name: "Hut Top"
             "#oOo-#pFz-#ooo": name: "Hut Top"
             "#ooO-#pfz-#ooo": name: "Hut Top"
             "#oOo-#pfz-#pFz": name: "Hut Top"
             "#pFz-#pfz-#ooo": name: "Hut Top"
             "#pFz-#pfz-#oOO": name: "Hut Top"
             "#pFz-#pfz-#ooO": name: "Hut Top"

             "#oOO-#hzF-#ooO": name: "Hut Top"
             "#oOo-#hzF-#ooo": name: "Hut Top"
             "#ooO-#hzf-#ooo": name: "Hut Top"
             "#oOo-#hzf-#hzF": name: "Hut Top"
             "#hzF-#hzf-#ooo": name: "Hut Top"
             "#hzF-#hzf-#oOO": name: "Hut Top"
             "#hzF-#hzf-#ooO": name: "Hut Top"

             "#OOO-#PFz-#OoO": name: "Hut Top"
             "#OOo-#PFz-#Ooo": name: "Hut Top"
             "#OoO-#Pfz-#Ooo": name: "Hut Top"
             "#OOo-#Pfz-#PFz": name: "Hut Top"
             "#PFz-#Pfz-#Ooo": name: "Hut Top"
             "#PFz-#Pfz-#OOO": name: "Hut Top"
             "#PFz-#Pfz-#OoO": name: "Hut Top"

             "#OOO-#HzF-#OoO": name: "Hut Top"
             "#OOo-#HzF-#Ooo": name: "Hut Top"
             "#OoO-#Hzf-#Ooo": name: "Hut Top"
             "#OOo-#Hzf-#HzF": name: "Hut Top"
             "#HzF-#Hzf-#Ooo": name: "Hut Top"
             "#HzF-#Hzf-#OOO": name: "Hut Top"
             "#HzF-#Hzf-#OoO": name: "Hut Top"

             ###

             "#ooO-#zfP-#OoO-#Fpz-#fpz": name: "Face A"
             "#oOO-#zFP-#OOO-#FPz-#fPz": name: "Face c"
             "#OoO-#zfP-#zFP-#OOO": name: "XX"
             "#oOo-#zFp-#OOo-#FPz-#fPz": name: "Face a"
             "#ooo-#fpz-#ooO-#pzF-#pzf": name: "Face B"
             "#OOo-#FPz-#OOO-#PzF-#Pzf": name: "Face b"
             "#ooo-#zfp-#Ooo-#Fpz-#fpz": name: "Face C"
             "#oOO-#zFP-#OOO-#FPz-#fPz": name: "Face c"
             "#Ooo-#Fpz-#OoO-#PzF-#Pzf": name: "Face D"
             "#oOo-#fPz-#oOO-#pzF-#pzf": name: "Face d"
             "#ooo-#pzf-#oOo-#zFp-#zfp": name: "Face E"
             "#OoO-#PzF-#OOO-#zFP-#zfP": name: "Face e"
             "#ooO-#pzF-#oOO-#zFP-#zfP": name: "Face F"
             "#Ooo-#Pzf-#OOo-#zFp-#zfp": name: "Face f"
             ###
           }
    {faceNames,facePaths} = @createSegments _.mapObject @Faces, (item,key)->key
    @faceNames = faceNames
    @facePaths = facePaths
    # create the fiboTriangles on each of the 12 faces
    @fiboTriangles=createFiboTriangles @Faces,this
    {@cliques,@cliqueNames} = createCliques @
 






