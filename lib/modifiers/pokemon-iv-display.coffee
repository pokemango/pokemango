changeCase = require('change-case')

module.exports.apply = (server, options = {}) ->
  server
    # Always get the full inventory
    .addRequestHandler "GetInventory", (data) ->
      data.last_timestamp_ms = 0
      data

    # Append IV% to existing Pokémon names
    .addResponseHandler "GetInventory", (data) ->
      return if not data.inventory_delta
      for item in data.inventory_delta.inventory_items when item.inventory_item_data
        if pokemon = item.inventory_item_data.pokemon_data
          id = changeCase.titleCase pokemon.pokemon_id
          name = pokemon.nickname or id.replace(" Male", "♂").replace(" Female", "♀")
          atk = pokemon.individual_attack or 0
          def = pokemon.individual_defense or 0
          sta = pokemon.individual_stamina or 0
          iv = Math.round((atk + def + sta) * 100/45)
          pokemon.nickname = "#{name} #{iv}%"
      data
