# PokemonGoMITM = require('pokemon-go-mitm')

PokemonGoMITM = require('./lib/pokemon-go-mitm')
modifiers = require('./modifiers')
server = new PokemonGoMITM port: 8081
modifiers['log-traffic'].apply(server, ['ReleasePokemon' ,'GetPlayer', 'DownloadSettings', 'GetGymDetails', 'FortDetails', 'CheckAwardedBadges', 'GetMapObjects', 'GetInventory', 'GetHatchedEggs']);
require('./modifiers/pokemon-iv-display')(server);
# require('./modifiers/map-radar')(server);

require('./modifiers/map-expand-range')(server);
# new wild pokemon


'CheckAwardedBadges DownloadSettings GetHatchedEggs GetInventory GetMapObjects GetPlayer'
