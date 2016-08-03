module.exports.apply = (server, options = {}) ->
  server.addRequestHandler "CatchPokemon", (data) ->
    data.normalized_reticle_size = 1.950
    data.spin_modifier = 0.850
    if data.hit_pokemon
      data.normalized_hit_position = 1.0

    data
