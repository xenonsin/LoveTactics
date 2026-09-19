-- Biome logic. Blueprints live in data/biomes/<id>.lua and are auto-discovered
-- by the registry. A biome drives overworld generation knobs (currently the
-- maze `spacing`); models/overworld.lua reads it via Biome.get.

local Registry = require("models.registry")

-- NAMING: THE ID IS THE CATEGORY, THE NAME IS A PLACE.
--
-- A biome's id (`desert`, `swamp`) is what the code and the design docs key on, and it stays a terrain
-- category because that is what generation reasons about. Its `name` is the other thing entirely: the
-- string a player reads. "Desert" is a legend key; a company goes SOMEWHERE, and somewhere has a name.
--
-- WHERE IT IS DRAWN IS CURRENTLY NOWHERE, and that is worth stating plainly rather than leaving the
-- reference to rot. These names were authored for the Bounty Board's Location row
-- (ui/panels/bounty_board.lua), and the board's card is parked -- for the second time, and this time
-- because the rift already posts the work it posted (docs/bounties.md). So the field is authored and
-- unread.
--
-- THE PREMISE THIS PARAGRAPH USED TO CITE IS ITSELF SUPERSEDED, which is the thing to notice: it said
-- the campaign was "a distance run down one stair", and that stopped being true when the rift became a
-- PLACE the company maps and re-enters at its own stair (models/descent.lua). A note about a parked
-- system decays twice -- once when the system moves and once when its reason does.
--
-- WHERE IT BELONGS is the floor's own heading: Descent.biomeAt already gives every floor a biome, and
-- under a run measured in DEPTH the thing the player needs on screen is which place they are in and how
-- far down -- "Meltwater Reach, floor six". A stratum walked past on the way to floor fourteen earns a
-- name far more than a posting spent once did, so nothing here is wasted; it is waiting on the readout.
--
-- The convention is compound + landform, no article -- Ribstone Waste, Meltwater Reach -- which also
-- keeps a place typographically apart from the seven houses, who all take "The X". The two biomes that
-- were already places (the Colosseum, the Underworld) keep the names they had; both are buildings in
-- or under the city rather than country the company travels to, and the article is what says so.
--
-- Battle-tile names are NOT this: ui/tile_tooltip.lua's "Forest" is a tile type on a board and is
-- correctly a category, whatever place the board was rolled for.
local Biome = {}

Biome.defs = Registry.load("data/biomes", "data.biomes")

local DEFAULT = { name = "Thornveil Wood", tileset = "forest", spacing = 4, rivers = 1 }

-- Return the biome def for `id`, falling back to forest / a safe default so an
-- unknown or missing biome never breaks generation.
function Biome.get(id)
    return (id and Biome.defs[id]) or Biome.defs.forest or DEFAULT
end

-- The signature ground a generated battle board seeds for this biome, or nil when it has none.
-- A blueprint declares it as `hazard = { id = "hazard_quicksand", min = 1, max = 2, duration = 20 }`;
-- models/arena.lua's generateLayout rolls that many patches onto open ground.
--
-- Normalized here rather than at the call site so a blueprint can say just `{ id = ... }` and get one
-- patch, and so a def that names no hazard reads as nil rather than as an empty spec the generator has
-- to test twice. Returns nil for a hazard with no id, so a half-written blueprint seeds nothing instead
-- of seeding garbage Combat.new would have to reject.
function Biome.hazardFor(id)
    local spec = Biome.get(id).hazard
    if not (spec and spec.id) then return nil end
    local min = spec.min or 1
    local max = spec.max or min
    if max < min then max = min end
    return { id = spec.id, min = min, max = max, duration = spec.duration }
end

return Biome
