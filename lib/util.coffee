fs = require('fs')
path = require('path')

module.exports.listFiles = (dir) ->
  fs.readdirSync(dir).reduce ((list, file) ->
    name = path.join(dir, file)
    isDir = fs.statSync(name).isDirectory()
    list.concat if isDir then fileList(name) else [ name ]
  ), []

module.exports.merge = (dest, objs...) ->
  for obj in objs
    dest[k] = v for k, v of obj
  dest
