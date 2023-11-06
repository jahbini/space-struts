export class Memo
  constructor: ()->
    @MM={}

  memoLog: (key)=>
    console.log "Snapping #{key}",@MM[key]

  saveThis: (key, value)->
    return @MM[key] if @MM[key] != undefined && value == @MM[key].value
    oldResolver = @MM[key]?.resolver ? null
    breaker = null
    maybe= new Promise (resolve,reject)=>
      breaker =resolve
    @MM[key] =
      value: value
      notifier: maybe
      resolver:  breaker
    oldResolver @MM[key] if oldResolver   #notify subscribers of new cache value
    @MM[key]

  theLowdown: (key)=>
    return @MM[key] if @MM[key] != undefined
    @saveThis key,null

  waitFor: (aList,andDo)=>
    unfound = []
    dependants= for key in aList
        d=@theLowdown key
        unfound.push d.notifier if d.value == null
        d.notifier
    if unfound.length>0
      Promise.allSettled(unfound).then andDo
    Promise.any(dependants).then andDo

  notifyMe: (n,andDo)=>
    newValue=(@theLowdown n).value
    while true
      currentValue = newValue
      andDo newValue
      while currentValue == newValue
        newValue = (await @MM[n].notifier).value

