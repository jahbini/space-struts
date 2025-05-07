import { Memo } from '$lib/coffee/memo.coffee'
import _ from 'underscore'
import { ONE, ZERO, PHI, PhiBase }  from '$lib/coffee/phiBase.coffee'
import { SixPhiVector } from '$lib/coffee/sixPhiVector.coffee'

M = new Memo()

export class GeoPhi
  # Encoded shape definitions (same as Geo)
  square        = "#ffz-#Ffz-#FFz-#fFz"
  pentagon      = "#zFP-#OOO-#PzF-#OoO-#zfP"
  octahedron    = "#O00-#o00-#0o0-#0O0-#00o-#00O"
  cube          = "#OOO-#oOO-#OoO-#ooO-#OOo-#oOo-#Ooo-#ooo"
  tetrahedron1  = "#ooo-#oOO-#OoO-#OOo"
  tetrahedron2  = "#OOO-#Ooo-#oOo-#ooO"
  icosahedron1  = "#zOF-#zoF-#zof-#zOf-#oFz-#ofz-#OFz-#Ofz-#FzO-#fzO-#Fzo-#fzo"
  icosahedron2  = "#zFO-#zFo-#zfo-#zfO-#Foz-#foz-#FOz-#fOz-#OzF-#Ozf-#ozF-#ozf"
  dodecahedron1 = "#ooo-#ooO-#oOo-#oOO-#Ooo-#OoO-#OOo-#OOO-#zfp-#zFp-#zfP-#zFP-#pzf-#Pzf-#pzF-#PzF-#fpz-#Fpz-#fPz-#FPz"
  dodecahedron2 = "#ooo-#oOo-#ooO-#oOO-#Ooo-#OOo-#OoO-#OOO-#zpf-#zpF-#zPf-#zPF-#fzp-#fzP-#Fzp-#FzP-#pfz-#pFz-#Pfz-#PFz"

  # Decode map: symbol -> PhiBase(p, n) representing p*phi + n
  decode = {
    "z": new PhiBase(0, 0)
    "0": new PhiBase(0, 0)
    "O": new PhiBase(0, 1)
    "o": new PhiBase(0, -1) # -1/phi = -(phi - 1) = -phi + 1
    "f": new PhiBase(-1, 1) #  1/phi = phi - 1
    "F": new PhiBase(1, -1)
    "p": new PhiBase(-1, 0)
    "P": new PhiBase(1, 0)
  }

  ###
  # createPhiPoint: builds a SixPhiVector from a 3-char code
  # side-effect: caches in Memo with key ptxt
  ###
  @createPhiPoint= (ptxt, shapeName = "") ->
    return null unless m = ptxt.match /#(.)(.)(.)$/
    # reuse existing if already created
    if existing = M.theLowdown(ptxt)?.value
      existing.shapeName[shapeName] = shapeName
      return existing

    # decode to phi-base coordinates
    x = decode[m[1]]
    y = decode[m[2]]
    z = decode[m[3]]

    # convert to six-basis vector
    v = SixPhiVector.fromPhiPoint(x, y, z)
    # attach metadata
    v.ID = ptxt
    v.d = v.magnitude().toFixed(3)
    v.shapeName = { [shapeName]: shapeName }
    # cache
    M.saveThis(ptxt, v)
    v

  ###
  # formPointsFromPhi: splits an encoded shape string or array and creates points
  ###
  formPointsFromPhi: (shape, shapeName = "") ->
    if Array.isArray(shape)
      return shape.map (pt) -> GeoPhi.createPhiPoint(pt, shapeName)
    if typeof shape is 'string'
      return shape.split('-').map (pt) -> GeoPhi.createPhiPoint(pt, shapeName)
    []

  ###
  # createSegment: builds segment entries from two point codes
  ###
  createSegment: (ptxt1, ptxt2) ->
    # ensure lex order
    if ptxt2 < ptxt1 then [ptxt1, ptxt2] = [ptxt2, ptxt1]
    ID = "#{ptxt1}-#{ptxt2}"
    return ID if M.MM[ID]

    p1 = GeoPhi.createPhiPoint(ptxt1)
    p2 = GeoPhi.createPhiPoint(ptxt2)
    dVector = p1.clone().sub(p2)
    d = dVector.magnitude().toFixed(3)
    M.saveThis(ID, {ID, path: [p1, p2], d})
    ID

  ###
  # createSegments: iterates points to build all unique segments
  ###
  createSegments: (points) ->
    theSegments = {}
    for p1,i in points
      for p2,j in points
        continue if p1.ID is p2.ID
        tag = @createSegment(p1.ID, p2.ID)
        theSegments[tag] = M.MM[tag]
    segmentsByMagnitude = _.chain(theSegments)
      .map (v) -> v.value
      .sortBy 'd'
      .groupBy 'd'
    keySort = (k, _) -> +k
    segmentNames = segmentsByMagnitude.keys().sort(keySort).value()
    segmentsByMagnitude = segmentsByMagnitude.value()
    {segmentNames, segmentsByMagnitude}

  ###
  # angleBetween: compute angles between two segments at a point
  ###
  angleBetween: (originID, segID0, segID1) ->
    oVal = M.MM[originID].value
    s0 = M.MM[segID0].value.path
    s1 = M.MM[segID1].value.path
    # find points
    pO = oVal
    [pA] = if s0[0].ID is originID then [s0[1]] else [s0[0]]
    [pB] = if s1[0].ID is originID then [s1[1]] else [s1[0]]
    # vectors
    vA = pA.copy().subtract(pO)
    vB = pB.copy().subtract(pO)
    angle = vA.angleTo(vB)
    angleName = angle.toFixed(3)
    M.saveThis("#{segID0}-#{originID}-#{segID1}", {angleName, angle})
    angleName

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

  constructor: ->
    # initialize polyhedra points
    @Polyhedra =
      Tetrahedron1: @formPointsFromPhi(tetrahedron1, "tetrahedron")
      Octahedron:    @formPointsFromPhi(octahedron,    "octahedron")
      Cube:          @formPointsFromPhi(cube,          "cube")
      Icosahedron1:  @formPointsFromPhi(icosahedron1,  "icosahedron")
      Dodecahedron1: @formPointsFromPhi(dodecahedron1, "dodecahedron")
      Tetrahedron2:  @formPointsFromPhi(tetrahedron2,  "tetrahedron")
      Icosahedron2:  @formPointsFromPhi(icosahedron2,  "icosahedron")
      Dodecahedron2: @formPointsFromPhi(dodecahedron2, "dodecahedron")

    # build segments
    Melements = _(M.MM).filter (item, key) -> key.match /^#...$/
    {segmentNames, segmentsByMagnitude} =
      @createSegments(_.mapObject(Melements, (item, key) -> item.value))
    @segmentNames = segmentNames
    @segmentsByMagnitude = segmentsByMagnitude

