import { Memo } from '$lib/coffee/memo.coffee'
import _ from 'underscore'
import { ONE, ZERO, PHI, PhiBase }  from '$lib/coffee/phiBase.coffee'
import {ThreePhiVector, SixPhiVector, ZERO6 } from '$lib/coffee/sixPhiVector.coffee'

export M = new Memo()
cliques= {}
cliqueNames = []
cnames = []
 #convert a string like "#FPz-#Fpz-..." into an array of point names
splitIntoNames = (longName)->
  value = longName.split /-|<|>/
  return value


# stripName will examine the points of a triangle and 
#   return the point that is not in the segment
# sID is one segment of the triangle tID, it contains two points
# tID is a triangle of three points
#
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

  @normalizeXYZ: (pointsV6) ->
    pointsXYZ = []
    for s in pointsV6
      [x,y,z] = s.sixPhiToCartesianDisplay()
      pointsXYZ.push [x,y,z]
    pointsXYZ 

  
  moveTriangle: (sID,tID) ->
    triangle = M.MM[tID].value
    segment=M.MM[sID].value
    path=@normalizeFrame (tID.split /-|<|>/)
    nickName = segment.vetric.toName()
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

  createCliques: (triangles) ->
    return [] unless triangles.length
    cantidates = triangles.slice 0
    cliques={}
    for  masterTriangle in cantidates
      for s,idx in masterTriangle.value.segments
        sV = (M.theLowdown s).value.vetric
        cliqueName = sV.toName()
        cliqueName2 = sV.negate().toName()
        possiblePoint = stripName s,masterTriangle.value.ID
        data= {"#{masterTriangle.value.ID}": {s,possiblePoint} } 
        if cliques[cliqueName]?
          cliques[cliqueName][masterTriangle.value.ID]=[s,possiblePoint]
        else
          newClique = {"#{masterTriangle.value.ID}":[s,possiblePoint]}
          # tag the clique with the dodecahedral mirror plane(s) it lies in
          newClique.planes = @planesContaining vetricDir3Phi(sV)
          cliques[cliqueName] = newClique
        cliques[cliqueName2] = cliques[cliqueName]

    cnames = for s of cliques
      s
    cliqueNames = cnames.slice()
    return {cliques,cliqueNames}

  # Which of the 15 dodecahedral mirror planes (Ih) contain a 3-D direction:
  # exact test dir·normal == 0 in Z[φ]. Returns the plane labels (e.g. "E+F").
  planesContaining: (dir3) ->
    labels = []
    for plane in @mirrorPlanes
      n = plane.v
      dot = dir3.x.mul(n.x).add(dir3.y.mul(n.y)).add(dir3.z.mul(n.z))
      labels.push plane.label if dot.p == 0 and dot.n == 0
    labels

  # Candidate apex vertices that complete a golden triangle or golden gnomon on
  # the edge (p1, p2), both SixPhiVector vertices. The apex is found by adding
  # each neighbour-star offset to p1 and keeping those whose three side lengths
  # form {s,φs,φs} (golden) or {s,s,φs} (gnomon). All exact in Z[φ].
  # Returns [{ apex: SixPhiVector, cart: {x,y,z}, kind: 'golden'|'gnomon' }].
  goldenApexCandidates: (p1, p2) ->
    c1 = cartesian3Phi p1
    c2 = cartesian3Phi p2
    edgeClass = lengthClass3Phi len2_3Phi(vsub3(c2, c1))
    return [] unless edgeClass
    found = {}
    for star in @neighborStar
      apexCart = vadd3 c1, star.offset
      d2Class = lengthClass3Phi len2_3Phi(vsub3(apexCart, c2))
      continue unless d2Class
      kind = robinsonKind edgeClass, star.lenClass, d2Class
      continue unless kind
      key = vecKey3Phi apexCart
      unless found[key]
        found[key] =
          cart: apexCart
          kind: kind
          apex: SixPhiVector.fromPhiPoint(apexCart.x, apexCart.y, apexCart.z)
    (val for own key, val of found)


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

  ###
  #  These are the points that sixDotter found.
  # they formed an amazing star of golden triangles
  ###
  starSixVector = [
    { name: "-8,-8,0,0,-5,5", vector: (new SixPhiVector([-8,-8,0,0,-5,5])), P:[-18, 0, 0] }
    { name: "-9,-4,-4,-4,-4,4", vector: (new SixPhiVector([-9,-4,-4,-4,-4,4])), P:[-14.5, 0, -9] }
    { name: "-4,-9,4,4,-4,4", vector: (new SixPhiVector([-4,-9,4,4,-4,4])), P:[-14.5, 0, 9] }
    { name: "-4,-4,-4,4,-9,-4", vector: (new SixPhiVector([-4,-4,-4,4,-9,-4])), P:[-9, -14.5, 0] }
    { name: "-4,-4,4,-4,4,9", vector: (new SixPhiVector([-4,-4,4,-4,4,9])), P:[-9, 14.5, 0] }
    { name: "0,0,-5,5,-8,-8", vector: (new SixPhiVector([0,0,-5,5,-8,-8])), P:[0, -18, 0] }
    { name: "-4,4,-9,-4,-4,-4", vector: (new SixPhiVector([-4,4,-9,-4,-4,-4])), P:[0, -9, -14.5] }
    { name: "4,-4,4,9,-4,-4", vector: (new SixPhiVector([4,-4,4,9,-4,-4])), P:[0, -9, 14.5] }
    { name: "-5,5,-8,-8,0,0", vector: (new SixPhiVector([-5,5,-8,-8,0,0])), P:[0, 0, -18] }
    { name: "0,0,0,0,0,0", vector: (new SixPhiVector([0,0,0,0,0,0])), P:[0, 0, 0] }
    { name: "5,-5,8,8,0,0", vector: (new SixPhiVector([5,-5,8,8,0,0])), P:[0, 0, 18] }
    { name: "-4,4,-4,-9,4,4", vector: (new SixPhiVector([-4,4,-4,-9,4,4])), P:[0, 9, -14.5] }
    { name: "4,-4,9,4,4,4", vector: (new SixPhiVector([4,-4,9,4,4,4])), P:[0, 9, 14.5] }
    { name: "0,0,5,-5,8,8", vector: (new SixPhiVector([0,0,5,-5,8,8])), P:[0, 18, 0] }
    { name: "4,4,-4,4,-4,-9", vector: (new SixPhiVector([4,4,-4,4,-4,-9])), P:[9, -14.5, 0] }
    { name: "4,4,4,-4,9,4", vector: (new SixPhiVector([4,4,4,-4,9,4])), P:[9, 14.5, 0] }
    { name: "4,9,-4,-4,4,-4", vector: (new SixPhiVector([4,9,-4,-4,4,-4])), P:[14.5, 0, -9] }
    { name: "9,4,4,4,4,-4", vector: (new SixPhiVector([9,4,4,4,4,-4])), P:[14.5, 0, 9] }
    { name: "8,8,0,0,5,-5", vector: (new SixPhiVector([8,8,0,0,5,-5])), P:[18, 0, 0] }
  ]
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

  # The six basisNormals3Phi are the 5-fold (face-center) axes A–F. They are NOT
  # mirror planes, and reflections perpendicular to them do not close into a
  # finite group. The 15 mirror planes of the icosahedral group Ih have normals
  # nX ± nY: each 2-fold (edge-midpoint) axis is the sum of two adjacent 5-fold
  # axes, giving exactly C(6,2)=15 distinct axes whose reflections close to Ih.
  axisKey3Phi = (v) ->
    comps = [v.x, v.y, v.z]
    i = 0
    i++ while i < 3 and Math.abs(comps[i].toFloat()) < 1e-9
    c0 = comps[i]
    (comps.map (c) -> c.div(c0).toID()).join('|')

  computeMirrorNormals = ->
    letters = ['A', 'B', 'C', 'D', 'E', 'F']
    seen = {}
    out = []
    addAxis = (v, label) ->
      key = axisKey3Phi v
      unless seen[key]
        seen[key] = true
        out.push { v, label }
    for i in [0...6]
      for j in [i + 1...6]
        a = basisNormals3Phi[i]
        b = basisNormals3Phi[j]
        addAxis { x: a.x.add(b.x), y: a.y.add(b.y), z: a.z.add(b.z) }, "#{letters[i]}+#{letters[j]}"
        addAxis { x: a.x.sub(b.x), y: a.y.sub(b.y), z: a.z.sub(b.z) }, "#{letters[i]}-#{letters[j]}"
    out

  # Exact 3-D direction of a segment's six-vector (inverse-map numerators). The
  # common scale factor drops out of the perpendicularity test, so we skip it.
  vetricDir3Phi = (vetric) ->
    [a, b, c, d, e, f] = vetric.v
    {
      x: e.sub(f).add(p(1, 0).mul(a.add(b)))
      y: c.sub(d).add(p(1, 0).mul(e.add(f)))
      z: a.sub(b).add(p(1, 0).mul(c.add(d)))
    }

  # --- Golden-triangle hull primitives ---------------------------------------
  # Robinson tiles use two edge lengths in ratio φ: short s = 2/φ (dodecahedron
  # edge) and long φs = 2 (icosahedron edge). A golden triangle (36-72-72) has
  # sides {s,φs,φs}; a golden gnomon (108-36-36) has {s,s,φs}. The complete set
  # of neighbour offsets at each length is the Ih orbit of one seed edge vector
  # (reflections through individual planes only give fragments of that orbit).
  edgeSeedShort = { x: p(0, 1), y: p(-1, 2), z: p(-1, 1) }   # |·| = 2/φ
  edgeSeedLong  = { x: p(0, 0), y: p(0, 2),  z: p(0, 0) }    # |·| = 2
  goldenShort2  = p(-4, 8)   # s²  = (2/φ)²
  goldenLong2   = p(0, 4)    # φs² = 2²

  vadd3 = (u, w) -> { x: u.x.add(w.x), y: u.y.add(w.y), z: u.z.add(w.z) }
  vsub3 = (u, w) -> { x: u.x.sub(w.x), y: u.y.sub(w.y), z: u.z.sub(w.z) }
  len2_3Phi = (v) -> v.x.mul(v.x).add(v.y.mul(v.y)).add(v.z.mul(v.z))
  vecKey3Phi = (v) -> "#{v.x.toID()}|#{v.y.toID()}|#{v.z.toID()}"

  # reflect a 3-D vector across the plane with the given (any-scale) normal
  reflectVec3Phi = (vec, n) ->
    dot = n.x.mul(vec.x).add(n.y.mul(vec.y)).add(n.z.mul(vec.z))
    nn = n.x.mul(n.x).add(n.y.mul(n.y)).add(n.z.mul(n.z))
    scale = dot.div(nn)
    two = p(0, 2)
    {
      x: vec.x.sub(two.mul(scale).mul(n.x))
      y: vec.y.sub(two.mul(scale).mul(n.y))
      z: vec.z.sub(two.mul(scale).mul(n.z))
    }

  # orbit of a vector under Ih, reached by reflecting through the 15 mirror
  # normals until closure (exact; each golden seed yields 30 vectors)
  orbit3Phi = (vec, normals) ->
    seen = {}
    out = []
    seen[vecKey3Phi vec] = true
    out.push vec
    frontier = [vec]
    while frontier.length
      nextF = []
      for v in frontier
        for n in normals
          r = reflectVec3Phi v, n
          key = vecKey3Phi r
          unless seen[key]
            seen[key] = true
            out.push r
            nextF.push r
      frontier = nextF
    out

  buildNeighborStar = (mirrorPlanes) ->
    normals = (plane.v for plane in mirrorPlanes)
    star = []
    for o in orbit3Phi(edgeSeedShort, normals)
      star.push { offset: o, lenClass: 's' }
    for o in orbit3Phi(edgeSeedLong, normals)
      star.push { offset: o, lenClass: 'L' }
    star

  # exact Cartesian (display frame) of a six-vector point
  cartesian3Phi = (sixVec) ->
    [a, b, c, d, e, f] = sixVec.v
    sr = p(2, 4).mul(sixVec.scaleFactor)
    {
      x: (e.sub(f).add(p(1, 0).mul(a.add(b)))).div(sr)
      y: (c.sub(d).add(p(1, 0).mul(e.add(f)))).div(sr)
      z: (a.sub(b).add(p(1, 0).mul(c.add(d)))).div(sr)
    }

  lengthClass3Phi = (l2) ->
    if l2.equals goldenShort2 then 's'
    else if l2.equals goldenLong2 then 'L'
    else null

  robinsonKind = (a, b, c) ->
    sig = [a, b, c].sort().join('')
    if sig is 'LLs' then 'golden'
    else if sig is 'Lss' then 'gnomon'
    else null

  planeVertices = [
    [decode['z'], decode['f'],decode['P']],
    [decode['F'], decode['p'],decode['z']],
    [decode['f'], decode['p'],decode['z']],
  ]; #// Plane defined by a face of the dodecahedron

  createPointsFromSixVector: (list,shapeName="Star")->
    ## formPointsFromPhi: (shape, shapeName = "") ->
    for k of list
      item = list[k]
      v = item.vector
      v['ID'] = "#"+item.name
      v['d'] = v.magnitude().toFixed(3)
      v['shapeName'] =  shapeName

      # cache it
      M.saveThis("#"+item.name, v)
      v
  ###
  # createPhiPoint: builds a SixPhiVector from a 3-char code with optional reflection suffix
  # side-effect: caches in Memo using canonical key: <base>|<reflections>
  ###
  @createPhiPoint = (ptxt, shapeName = "") ->
    return M.MM[ptxt]?.value unless m = ptxt.match /^#([zZoOpPfF]{3})(?:~([A-F]+))?$/

    baseSym = m[1]
    reflectSeq = (m[2] or "").split('')  # e.g., "ABA" → ['A','B','A']

    # decode base point
    x = decode[baseSym[0]]
    y = decode[baseSym[1]]
    z = decode[baseSym[2]]

    # apply reflections in order
    for face in reflectSeq
      faceIndex = face.charCodeAt(0) - 'A'.charCodeAt(0)
      [x, y, z] = reflect3PhiAcrossPlane [x, y, z], faceIndex

    # create six-basis vector
    v = SixPhiVector.fromPhiPoint(x, y, z)

    # build canonical key
    reflectStr = reflectSeq.join('')
    canonicalKey = "#{baseSym}|#{reflectStr}"
    canonicalKey = ptxt

    # reuse existing if already created
    if existing = M.theLowdown(canonicalKey)?.value
      existing.shapeName[shapeName] = shapeName
      return existing

    # attach metadata
    v.ID = canonicalKey
    v.d = v.magnitude().toFixed(3)
    v.shapeName = { [shapeName]: shapeName }

    # cache it
    M.saveThis(canonicalKey, v)
    return v

  @createPhiRaw = (ID,v,C3,shapeName="Search") ->
    # reuse existing if already created
    if existing = M.theLowdown(ID)?.value
      existing.shapeName[shapeName] = shapeName
      return existing

    v.d = v.magnitude().toFixed(3)
    v.ID=ID
    v.C3=C3
    v.shapeName = { [shapeName]: shapeName }
    M.saveThis(ID,v )
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
        ID=sID
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
        [leg0,leg1]= j.path
        continue if  i.ID== leg0 || i.ID == leg1
        d = @angleBetween i.ID,j.ID
        ID="#{i.ID}<#{leg0}-#{leg1}"
        seg0Vector = leg0
        seg1Vector = leg1
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

  ###
  # Reflects each point name in the dash-joined string across planeIndex (0–5)
  # Returns a new dash-joined string of reflected names.
  ###
  reflect: (names, planeIndex) ->
    planeLetter = String.fromCharCode('A'.charCodeAt(0) + planeIndex)

    # Split and process each point name
    reflectedNames = for pointName in names.split('-')
      match = pointName.match /^#([zZoOpPfF]{3})(?:~([A-F]+))?$/
      continue unless match

      base = match[1]
      prevSeq = (match[2] or '').split('')
      newSeq = prevSeq.concat([planeLetter])
      newSymbolicName = "##{base}~#{newSeq.join('')}"

      # Ensure the reflected point exists in M
      GeoPhi.createPhiPoint(newSymbolicName)

      # Return the new symbolic name for output
      newSymbolicName

    # Join all reflected point names back together
    return reflectedNames.join('-')

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

  # Given an array of SixPhiVector points and a 3-axis triple (e.g. ['A','Y','E']),
  # return a new array of SixPhiVector where each point is reprojected and expanded
  selectAndFlip = (points, axes) ->
    # points: [SixPhiVector], axes: ['A','Y','E'] or ['X','C','D'], etc.
    points.map (p) ->
      three = p.selectTriple axes    # -> ThreePhiVector
      three.toSixPhi()               # -> SixPhiVector

  # Given an array of SixPhiVector points and multiple triples,
  # return a map of tripleName -> array of [u,v,w] coords in that basis
  generateTransformedShapes = (points, triples) ->
    # points: [SixPhiVector], triples: [ ['X','C','D'], ['A','Y','E'], ... ]
    result = {}
    for triple in triples
      key = triple.join ''
      result[key] = points.map (p) ->
        tv = p.selectTriple triple
        tv.coords                        # [u, v, w] in PhiBase or Float for XYZ
    result

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
      Star:          @createPointsFromSixVector( starSixVector, "Star")

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

    ]

    reflectedFaces = for mirror in [0..0]
      for face in @Faces
        @reflect face,mirror
    @Faces = [@Faces,reflectedFaces.flat()].flat()  

    Melements = _(M.MM).filter (item, key) -> key.match /^#([zZoOpPfF]{3})(?:~([A-F]+))?$/
    Melements = Melements.map (item, key) -> item.value
    @allPoints = Melements

    # build segments
    {segmentNames, segmentsByMagnitude} = @createSegments(Melements)
    @segmentNames = segmentNames
    @segmentsByMagnitude = segmentsByMagnitude

    # create the fiboTriangles on each of the 12 faces
    @fiboTriangles= @createFiboTriangles @Faces
    # 15 mirror planes of Ih (normals = nX ± nY of the six face-normal axes)
    @mirrorPlanes = computeMirrorNormals()
    # 60 nearest-neighbour offsets (Ih orbits of the short & long golden edges)
    @neighborStar = buildNeighborStar(@mirrorPlanes)
    {@cliques,@cliqueNames} = @createCliques @fiboTriangles

testing = false
if testing
  testGeo = new GeoPhi()

  cliqueSize = 0
  cliqueMaxKids = -99
  for jj of testGeo.cliques
    cliqueSize++
    cliqueKids = 0
    for kk of testGeo.cliques[jj]
      cliqueKids++
    #console.log jj,cliqueKids
    if cliqueKids>cliqueMaxKids
      cliqueMaxKids= cliqueKids

  console.log cliqueSize,cliqueMaxKids
  console.log testGeo.cliques[testGeo.cliqueNames[2] ]
  console.log testGeo.cliques[testGeo.cliqueNames[20] ]


  writeJsonFile = (filename, data) ->
    json = JSON.stringify(data, null, 2)
    blob = new Blob([json], {type: 'application/json'})
    url = URL.createObjectURL(blob)
    a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)

  # Write a JSON file from a named object
  writeJsonFile2 = (filename, data) ->
    json = JSON.stringify data, null, 2  # Pretty-print with 2-space indent
    fs.writeFileSync filename, json, 'utf8'
    console.log "Wrote JSON to #{filename}"

  cleanData = (rawData) ->
    rawData.map (item) ->
      item.value
  #writeJsonFile 'fiboTriangles.json', cleanData testGeo.fiboTriangles
  #writeJsonFile 'allPoints.json', testGeo.allPoints
  #writeJsonFile 'segments.json', testGeo.segmentsByMagnitude
  #writeJsonFile 'cliques.json', testGeo.cliques

if false
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
