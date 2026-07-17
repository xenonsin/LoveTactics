-- Colosseum rank-4. The axe drinks what it spills, and it means that literally: a third of everything
-- the arc opens goes back into the arm that swung it. The masters do not say where the crimson comes
-- from -- the first hint that the arena's patron sin is Wrath, and that Wrath feeds on blood.
--
-- Its EXTRA over the plain iron axe (data/items/weapon/weapon_iron_axe.lua), which cleaves the same 3-wide
-- arc, is the `lifesteal` keyword (docs/weapons.md): the wielder heals a share of the whole swing, and
-- since a cleave lands on up to three bodies at once, the axe heals most exactly when it is most
-- outnumbered. It is the sustain weapon for a fighter who intends to stand in the middle of the arena
-- and not leave it -- which is what the crowd is paying for.
--
-- Its opposite number is data/items/weapon/weapon_butchers_wedge.lua, the same family's `frenzy` axe: that one
-- hits a crowd HARDER, this one LIVES through one. The Colosseum sells the fantasy either way.
--
-- Lifesteal ADDS to a Vampiric Strike charm (data/items/utility/utility_vampiric_strike.lua) sitting beside it
-- in the grid, rather than overriding it -- a hungry weapon charmed hungrier drinks at 83%.
return {
    name = "Crimson Greataxe",
    description = "Cleaves the arc in front, healing you for a share of everything it opens.",
    flavor = "The masters do not say where the crimson comes from. Wrath feeds on blood, and the arena is paying.",
    sprite = "assets/items/crimson_greataxe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    hands = 2, -- a greataxe: two-handed (Dual Wield can pair it only once forged to +5)
    class = "fighter",
    price = 800,
    repRank = 4,
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,  -- the tile in front may hold a foe -- it's the centre of the arc
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 6, -- ponderous: you pay for the damage in turn order
        cost = { stat = "stamina", amount = 16 },
        damage = { 18, 20, 22, 23, 25, 27, 29, 31, 32, 34, 36 },
        aoe = { shape = "front", width = 3 }, -- axes cleave innately: a 3-wide arc in front
        lifesteal = 0.33, -- the wielder drinks a third of everything the arc opens (a keyword)
        effect = function(fx)
            -- Nothing here about the drinking: `lifesteal` is a keyword the model folds into every hit
            -- this cast lands (Combat.adjacencyAura -> mods.lifesteal), so the effect stays the plain
            -- cleave and the damage PREVIEW shows the heal without this file lifting a finger.
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
