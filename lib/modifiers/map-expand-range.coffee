changeCase = require 'change-case'
moment = require 'moment'
LatLon = require('geodesy').LatLonSpherical

module.exports.config =
  title: 'Map - Expand Range'
  type: 'object'
  properties:
    pokemon_visible_range:
      type: 'number'
      default: 1500
    poke_nav_range_meters:
      type: 'number'
      default: 1500
    encounter_range_meters:
      type: 'number'
      default: 1500
    interaction_range_meters:
      type: 'number'
      default: 1500
    max_total_deployed_pokemon:
      type: 'number'
      default: 50

module.exports.apply = (server, options = {}) ->
  server.addResponseHandler "DownloadSettings", (data) ->
    if data.settings
      data.settings.map_settings.pokemon_visible_range = 1500
      data.settings.map_settings.poke_nav_range_meters = 1500
      data.settings.map_settings.encounter_range_meters = 1500
      data.settings.fort_settings.interaction_range_meters = 1500
      data.settings.fort_settings.max_total_deployed_pokemon = 50
    data
