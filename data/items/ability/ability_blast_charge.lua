-- Blast Charge: the alchemist buries a sealed powder pot under a nearby tile
-- (data/traps/blast_charge.lua). The first enemy to cross it sets it off, and the blast catches
-- everything in the 3x3 around it -- the only trap in the game with an area, and the reason to set one
-- in a doorway rather than on a path.
--
-- It is data/items/ability/ability_powder_keg.lua's powder put underground instead of out in the open,
-- and the pair is worth reading together: a keg is a bomb somebody has to SHOOT, aimed by the party
-- and detonated on the party's own timing; this is a bomb the enemy detonates for you, on theirs. One
-- spends a second action to choose the moment, the other spends nothing and takes whatever moment
-- walks over it. Both are the Crucible getting other people to do the work, which is the shelf's whole
-- disposition (docs/classes.md).
--
-- The powder is nobody's friend: the burst catches allies standing beside the tile exactly as readily
-- as enemies (only the trigger is sided). Setting one behind your own line and then retreating through
-- it is a mistake the item will absolutely let you make.
return {
    name = "Blast Charge",
    description = "Buries powder on a nearby tile: the first enemy across it detonates, wounding everything adjacent.",
    flavor = "The Crucible's contribution to siege warfare is patience, sold by the pot.",
    sprite = "assets/items/ability_blast_charge.png",
    type = "ability",
    tags = { "trap", "fire" },
    class = "alchemist",
    price = 400,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            -- Forging packs the pot tighter: base 9 per body, +1 per upgrade level. The RADIUS does not
            -- scale, on the censer's rule (models/item.lua) -- an upgrade buys a harder blast, never a
            -- wider one, or the item would quietly outgrow the rooms it is set in.
            fx.placeTrap(fx.tx, fx.ty, "blast_charge", { amount = 9 + fx.level })
        end,
    },
}
