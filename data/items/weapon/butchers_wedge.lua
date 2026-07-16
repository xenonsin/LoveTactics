-- Colosseum rank-3. A broad, ugly wedge of an axe with no edge worth the name -- it does not cut so
-- much as barge through. The Colosseum's masters put it in the hands of whoever they mean to send
-- against a mob, because it is the one weapon in the armoury that gets BETTER the worse the odds are.
--
-- Its EXTRA over the plain iron axe (data/items/weapon/iron_axe.lua), which cleaves the same 3-wide
-- arc, is the `frenzy` keyword (docs/weapons.md): every body the arc catches beyond the first adds a
-- third of the swing to what each of them takes. One foe is a mediocre axe -- deliberately worse than
-- an iron sword, which is the price. Two is a good one. Three is the hardest single swing at its rank.
--
-- That inversion IS the weapon: every other item on the board asks you to avoid being surrounded, and
-- this one asks you to arrange it. Walk into the middle, aim at the thickest part, and let the crowd
-- pay for itself. Its opposite number is data/items/weapon/crimson_greataxe.lua, the rank-4 `lifesteal`
-- axe: that one LIVES through a crowd, this one deletes it.
--
-- Frenzy counts bodies, not enemies -- the arc has never cared whose side it sweeps. An ally standing
-- in it feeds the swing exactly as a foe would, and takes the boosted hit for the privilege.
return {
    name = "Butcher's Wedge",
    description = "A crude, heavy axe. The more bodies its arc catches, the harder it hits every one of them.",
    sprite = "assets/items/butchers_wedge.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    hands = 2, -- a two-handed wedge (Dual Wield can pair it only once forged to +5)
    class = "fighter",
    price = 420,
    repRank = 3,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,  -- the tile in front may hold a foe -- it's the centre of the arc
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 5,
        cost = { stat = "stamina", amount = 13 },
        -- Deliberately poor for its rank against a lone target: the crowd is the damage stat.
        damage = { 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 },
        aoe = { shape = "front", width = 3 }, -- axes cleave innately: a 3-wide arc in front
        frenzy = 0.33, -- each EXTRA body in the arc adds a third of the swing to all of them (a keyword)
        effect = function(fx)
            -- Nothing here about the frenzy: it is a keyword the model folds into the cast's magnitude
            -- (Combat.castAmount), so this stays the plain cleave and the damage PREVIEW already reads
            -- the crowd before the player commits to the swing.
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
