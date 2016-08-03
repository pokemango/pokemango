module.exports.config =
  title: 'Log Traffic'
  type: 'object'
  properties:
    blacklist:
      type: 'string'
      description: 'Actions to ignore separated by whitespace'
      default: 'CheckAwardedBadges DownloadSettings GetHatchedEggs GetInventory GetMapObjects GetPlayer'
    whitelist:
      type: 'string'
      description: 'Whitelist of actions to log'
    useBlacklist:
      type: 'boolean'
      description: 'Whether to use the blacklist or the whitelist'
      default: true
      required: true

skipAction = (action, useBlacklist, whitelist, blacklist) ->
  useBlacklist && blacklist.includes(action) ||
    !useBlacklist && !whitelist.includes(action)

module.exports.apply = (server, options = {}) ->
  blacklist = options.blacklist.split(' ')
  whitelist = options.whitelist.split(' ')

  server.addRequestHandler '*', (data, action) =>
    unless skipAction(action, useBlacklist, whitelist, blacklist)
      console.log("[->] #{action} ", data, "\n")
    data
  server.addResponseHandler '*', (data, action) =>
    unless skipAction(action, useBlacklist, whitelist, blacklist)
      console.log "[<-] #{action} ", JSON.stringify(data, null, 2), "\n"
    data
