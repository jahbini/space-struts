

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
      debugger
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
    ID


  createSegments: (points)->
    for i,p1 in points
      for j,p2 in points
          continue if i.ID == j.ID
          createSegment i.ID,j.ID
    segmentsByMagnitude=_.chain(M.MM)
      .filter((item,key)->key.match(/#...-#.../))
      .map (v)->v.value
      .groupBy('d')
      .value()
    segmentMagnitudes = for k of segmentsByMagnitude
       k

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

