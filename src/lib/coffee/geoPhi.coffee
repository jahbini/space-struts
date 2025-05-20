import { Memo } from '$lib/coffee/memo.coffee'
import _ from 'underscore'
import { ONE, ZERO, PHI, PhiBase }  from '$lib/coffee/phiBase.coffee'
import { SixPhiVector, ZERO6 } from '$lib/coffee/sixPhiVector.coffee'

export M = new Memo()
cliques= {}
cliqueNames = []
cnames = []
 #convert a string like "#FPz-#Fpz-..." into an array of point names
splitIntoNames = (longName)->
  value = longName.split /-|<|>/
  return value


stripName=(sID,tID)->
  segParts=sID.split />|-|</g
  rValue=tID.split(/<|>|-/g).join('').replace(segParts[0],'').replace(segParts[1],'')
  return rValue

movedTriangles = 0;

export class GeoPhi
  itemsConstructed =0

  normalizeFrame: (points,bias=null)->
    bias=ZERO6 unless bias instanceof SixPhiVector
    for s in points
      if typeof s == 'string'
          s=GeoPhi.createPhiPoint s
      if s instanceof SixPhiVector
        r=bias.add s
        r.ID=s?.ID
        r
      else
        debugger
        r=bias.copy().add s
        r.ID=s.ID
      r

  normalizeXYZ: (pointsV6) ->
    pointsXYZ = []
    for s in pointsV6
      [x,y,z] = s.sixPhiToCartesianDisplay()
      pointsXYZ.push P(x,y,z)
    pointsXYZ 

  
  moveTriangle: (sID,tID) ->
    triangle = M.MM[tID].value
    segment=M.MM[sID].value
    path=@normalizeFrame (tID.split /-|<|>/)
    nickName = (sID.split 'X')[0]
    offsetSegment = @cliques[nickName][tID][0]
    tMidPointV6 = M.MM[offsetSegment].value.midPoint
    sMidPointV6 = segment.midPoint
    path = path.map( (p) -> p.sub(tMidPointV6).add(sMidPointV6) )
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

  createCliques = (G) ->
    return [] unless G.fiboTriangles.length
    cantidates = G.fiboTriangles.slice 0
    for  masterTriangle in cantidates
      for s,idx in masterTriangle.value.segments
        usedPointNames = {}
        sV = (M.theLowdown s).value.vetric
        sVmS = sV.magnitudeSquared()
        cliques[s] = {"#{masterTriangle.value.ID}": {} }
        for cantidateTriangle in cantidates
          for cc in cantidateTriangle.value.segments
            possiblePoint = stripName cc,cantidateTriangle.value.ID
            #if we have already a triangle that reaches this point, skip this one
            if possiblePoint of usedPointNames
              continue
            cV=(M.theLowdown cc).value.vetric
            if ( cV.equals(sV) || cV.negate().equals(sV) )
              cliques[s][cantidateTriangle.value.ID]=[cc,possiblePoint]
              usedPointNames[possiblePoint] = true

    cnames = for s of cliques
      s
    cliqueNames = cnames.slice()
    return {cliques,cliqueNames}


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
    "o": new PhiBase(0, -1)
    "f": new PhiBase(-1, 1) #  1/phi = phi - 1
    "F": new PhiBase(1, -1) # -1/phi = -(phi - 1) = -phi + 1
    "p": new PhiBase(-1, 0)
    "P": new PhiBase(1, 0)
  }
  p=(a,b) -> new PhiBase(a,b)

  basisNormals3Phi = [
    # Face A
    { x: p(1, 0), y: p(0, 1), z: p(0, 0) },     # (φ, 1, 0)
    # Face B
    { x: p(1, 0), y: p(0, -1), z: p(0, 0) },    # (φ, -1, 0)
    # Face C
    { x: p(0, 1), y: p(0, 0), z: p(1, 0) },     # (1, 0, φ)
    # Face D
    { x: p(0, -1), y: p(0, 0), z: p(1, 0) },    # (-1, 0, φ)
    # Face E
    { x: p(0, 0), y: p(1, 0), z: p(0, 1) },     # (0, φ, 1)
    # Face F
    { x: p(0, 0), y: p(1, 0), z: p(0, -1) }     # (0, φ, -1)
  ]

# Reflect a PhiBase point {x, y, z} across one of the six basis planes
  reflect3PhiAcrossPlane = (point, planeIndex) ->
    [x, y, z] = point
    n = basisNormals3Phi[planeIndex]

    # Dot products
    dotNP = n.x.mul(x).add(n.y.mul(y)).add(n.z.mul(z))
    dotNN = n.x.mul(n.x).add(n.y.mul(n.y)).add(n.z.mul(n.z))

    scale = dotNP.div(dotNN)

    # 2 * projection vector
    dx = n.x.mul(scale).mul(p(0,2))
    dy = n.y.mul(scale).mul(p(0,2))
    dz = n.z.mul(scale).mul(p(0,2))

    [x.sub(dx), y.sub(dy), z.sub(dz)]

  planeVertices = [
    [decode['z'], decode['f'],decode['P']],
    [decode['F'], decode['p'],decode['z']],
    [decode['f'], decode['p'],decode['z']],
  ]; #// Plane defined by a face of the dodecahedron
  ###
  # createPhiPoint: builds a SixPhiVector from a 3-char code
  # side-effect: caches in Memo with key ptxt
  ###
  @createPhiPoint= (ptxt, shapeName = "") ->
    return null unless m = ptxt.match /[@|#](.)(.)(.)$/
    # reuse existing if already created
    if existing = M.theLowdown(ptxt)?.value
      existing.shapeName[shapeName] = shapeName
      return existing

    # decode to phi-base coordinates
    x = decode[m[1]]
    y = decode[m[2]]
    z = decode[m[3]]

    if ptxt[0] == '@'
      [x,y,z]= reflect3PhiAcrossPlane [x,y,z],5

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

  moveSegment: (segmentName,V6Destination,sID=null) ->
    segment = M.MM[segmentName].value
    midPoint =segment.midPoint
    vetric = segment.vetric
    if V6Destination.length != 2
      path = [ segment.path[0].sub(midPoint).add(V6Destination),
               segment.path[1].sub(midPoint).add(V6Destination)]
    else
      path = V6Destination
    midPoint=path[0].add(path[1]).scale 0.5
    if sID
      unlessSegment = M.MM[sID].value
      residual = unlessSegment.midPoint.sub(midPoint).magnitudeSquared()
      if residual.toFloat() > 0.1
        ID=segmentName+"X"+itemsConstructed++
        M.saveThis ID, {ID, v:V6Destination,path,midPoint,vetric}
      else
        ID=null
    else
      ID=segmentName+"X"+itemsConstructed++
      M.saveThis ID, {ID, v:V6Destination,path,midPoint,vetric}

    return ID

  ###
  # createSegment: builds segment entries from two point codes
  ###
  createSegment: (ptxt1, ptxt2) ->
    if typeof ptxt1  == 'object'
      ptxt2=ptxt1[1]
      ptxt1=ptxt1[0]
    # ensure lex order
    if ptxt2 < ptxt1 then [ptxt1, ptxt2] = [ptxt2, ptxt1]
    ID = "#{ptxt1}-#{ptxt2}"
    return ID if M.MM[ID]

    p1 = GeoPhi.createPhiPoint(ptxt1)
    p2 = GeoPhi.createPhiPoint(ptxt2)
    path = [p1,p2]
    vetric=p1.sub(p2)
    midPoint=p1.clone().add(p2).scale( 0.5 )
    M.saveThis ID, {ID,path,vetric,midPoint}
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
      .sortBy (v)->v.vetric.magnitude().toFixed 3
      .groupBy (v)->v.vetric.magnitude().toFixed 3
    keySort = (k, _) -> +k
    segmentNames = segmentsByMagnitude.keys().sort(keySort).value()
    segmentsByMagnitude = segmentsByMagnitude.value()
    {segmentNames, segmentsByMagnitude}

  ###
  # angleBetween: compute angles between two segments at a point
  ###
  angleBetween: (originID, segID) ->
    oVal = M.MM[originID].value
    seg = M.MM[segID].value
    # find points
    pO = oVal
    pA = seg.path[0]
    pB = seg.path[1]
    # vectors
    vA = pA.sub(pO)
    vB = pB.sub(pO)
    aMag = vA.magnitude()
    bMag = vB.magnitude()
    scaleMag = 1.0/(aMag*bMag)
    
    result = vA.dot vB
    #raw= result.toFloat() / (aMag * bMag)
    raw = result.scale(scaleMag).toFloat()
    angleDeg = Math.acos(raw) * 180 / Math.PI;
    angleDeg.toFixed 3

  createAngles: (points, segments)->
    biVectors = {}
    angleNames = []
    anglesByMagnitude = []
    return {angleNames,anglesByMagnitude} if segments.length == 0
    for i in points
      for j in segments
        continue unless j?.ID
        [leg0,leg1]= j.ID.split "-"
        continue if  i.ID== leg0 || i.ID == leg1
        d = @angleBetween i.ID,j.ID
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

  createTriangle: ( p1,p2,p3,face)->
    key = [p1,p2,p3].sort()
    p1=key[0]
    p2=key[1]
    p3=key[2]
    s1= @createSegment p1,p2
    s2= @createSegment p2,p3
    s3= @createSegment p1,p3
    ID= "#{p1}-#{p2}-#{p3}"
    M.saveThis ID,
      ID: ID
      path:[p1,p2,p3]
      segments:[s1,s2,s3]
      face: face


  reflect: (names, planeIndex) ->
    # Reflect across basis plane `planeIndex`
    debugger
    path = for point in names.match /#.../
       vec = M.MM[point].v
       vec = vec.reflect planeIndex
       ID='#{point}_r#{planeIndex}'
       M.saveThis '#{point}_r#{planeIndex}'
       reflectedVec = []

    # Append reflection tag to name
    newName = "#{names}_r#{planeIndex}"
    M.saveThis newName, {ID:newName,path}

  testAngleWithSegment: (originID, pointA_ID, pointB_ID, expectedDeg = null) ->
    seg = createSegment(pointA_ID, pointB_ID)
    segID = seg.ID
    M.MM[segID] = { value: seg }  # Register it if needed by angleBetween

    angle = angleBetween(originID, segID)
    rounded = angle.toFixed(3)

    result = "Angle at #{originID} between #{pointA_ID} and #{pointB_ID}: #{rounded}°"
    if expectedDeg?
      delta = Math.abs(angle - expectedDeg)
      result += " | Expected: #{expectedDeg}° | Δ = #{delta.toFixed(3)}°"
      if delta > 0.01
        console.warn "⚠️ Angle mismatch: #{result}"
      else
        console.log "✅ " + result
    else
      console.log result

    return angle
 
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

    @Faces=[
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

    # build segments
    Melements = _(M.MM).filter (item, key) -> key.match /^#...$/
    Melements = Melements.map (item, key) -> item.value
    {segmentNames, segmentsByMagnitude} =
      @createSegments(Melements)
    @segmentNames = segmentNames
    @segmentsByMagnitude = segmentsByMagnitude
    #@examineFaces()
    # create the fiboTriangles on each of the 12 faces
    @fiboTriangles= @createFiboTriangles @Faces
    {@cliques,@cliqueNames} = createCliques @
    console.log @cliques["#Ooo-#Pzf"]

testing = false
if testing
  testGeo = new GeoPhi()

  # --- Angle testing routine ---
  testAngleWithSegment = (originID, pointA_ID, pointB_ID, expectedDeg = null) ->
    segID = testGeo.createSegment(pointA_ID, pointB_ID)
    GeoPhi.createPhiPoint(originID)

    angle = testGeo.angleBetween(originID, segID)
    rounded = angle

    result = "Angle at #{originID} between #{pointA_ID} and #{pointB_ID}: #{rounded}°"
    if expectedDeg?
      delta = Math.abs(angle - expectedDeg)
      result += " | Expected: #{expectedDeg}° | Δ = #{delta.toFixed(3)}°"
      if delta > 0.01
        ratio=delta/angle
        console.warn "⚠️ Angle mismatch: #{result}, #{ratio}"
      else
        console.log "✅ " + result
    else
      console.log result

    return angle

  testAngleWithSegment "#OOO", "#OoO", "#oOO", 90  # if expecting 90°
  testAngleWithSegment "#OoO", "#oOO", "#OOO", 45
  testAngleWithSegment "#oOO", "#OOO", "#OoO", 45
  testAngleWithSegment "#OOO", "#oOO", "#OoO", 90
