import { Memo } from './memo.coffee'
import _ from 'underscore'

M = new Memo()

###
  Memo API
  saveThis: (key, value)->
  theLowdown: (key)=> returns current info on value at key
  waitFor: (aList,andDo)=> wait for updates to ANY of the aList and call andDo via promise
  notifyMe: (n,andDo)=>
###

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
    
  menuItems= ()=>
    for key of @Polyhedra
      key
  
  ###
  # createSegment:
  # creates two seenpoints from the two ID's
  # the resulting seenpoints are stored into the Memo as an array
  # with attributes ID, d for magnitude (to 3 digits) 
  #
  ###
  createSegment: (ptxt1,ptxt2)->
    (t=ptxt1; ptxt1=ptxt2; ptxt2=t) if ptxt2<ptxt1
    ID= "#{ptxt1}-#{ptxt2}"
    return ID if M.MM[ID]
    p1=@createSeenPoint ptxt1
    p2=@createSeenPoint ptxt2
    path = [p1,p2]
    d=p1.copy().subtract(p2).magnitude()
    d=d.toFixed 3
    M.saveThis ID, {ID,path,d}
    ID

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
      .sortBy 'd'
      .groupBy('d')
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
    

  createAngles: (points, segments)->
    biVectors = {}
    debugger
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
      Square: @formPointsFrom square,"square"
      Pentagon: @formPointsFrom pentagon,"pentagon"
      Tetrahedron1: @formPointsFrom tetrahedron1, "tetrahedron"
      Tetrahedron2: @formPointsFrom tetrahedron2, "tetrahedron"
      Octahedron: @formPointsFrom octahedron,"octahedron"
      Cube: @formPointsFrom cube,"cube"
      Icosahedron1: @formPointsFrom icosahedron1, "icosahedron"
      Icosahedron2: @formPointsFrom icosahedron2, "icosahedron"
      Dodecahedron1: @formPointsFrom dodecahedron1, "dodecahedron"
      Dodecahedron2: @formPointsFrom dodecahedron2, "dodecahedron"

    Melements=  _(M.MM).filter (item,key)-> key.match /^#...$/
    {segmentNames,segmentsByMagnitude} =
      @createSegments _.mapObject Melements, (item,key)->item.value

