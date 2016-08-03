glob = require('glob')
path = require('path')
util = require('./util')

files = glob.sync(path.join(__dirname, 'modifiers/*.?(coffee|js)'))

modifiers = []

for file in files
  id = path.basename(path.basename(file, '.coffee'), '.js')
  modifier = require(file)

  modifiers.push({
    id: id,
    apply: modifier.apply
    config: modifier.config || { title: modifier.id, type: 'object', properties: {} }
  })

schema =
  title: 'Modifiers'
  type: 'object'
  properties: {}

for modifier in modifiers
  # Add enable option to modifier
  enabledProp =
    type: 'boolean'
    default: false
    required: true
  modifier.config.properties = util.merge({enabled: enabledProp }, modifier.config.properties)



  # Add to full config
  schema.properties[modifier.id] = modifier.config
  module.exports[modifier.id] = modifier
module.exports.schema = schema
