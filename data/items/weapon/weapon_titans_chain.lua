-- TITAN'S CHAIN: the Titan's trophy (data/characters/character_titan.lua), on the Barbarian's shelf. Approved
-- 2026-09-30 on Pride's bestiary review, where the author combined two pitches into one piece: "Sweeps every foe
-- within reach 2 and shoves each 1 tile. A body shoved into another body or a wall takes the hit again. Below half
-- health: +2 movement, +4 damage, and shoves go 2 tiles."
--
-- A MACE, because a chain swung at a crowd is a displacement weapon (docs/weapons.md: the Morning Star and the
-- Whip of Flame are maces for the same reason): every body it strikes is shoved, and a collision deals the swing's
-- magnitude again (Combat.knockback's `amount`, as the Iron Mace's). The sweep is a diamond of 2 around the
-- WIELDER wherever it is aimed (`aoe.cells`), and it hits foes only, as the Horned Twin's Sweep does.
--
-- AIMED AT A TILE WITHIN 2, NOT AT SELF, and the reason is a neighbour: Clear Out spins as wide as the melee
-- weapon beside it (`radiusFromAdjacent`, read off `range`), so a chain that reaches 2 has to SAY range 2 -- a
-- self-cast's 0 would give the ring nothing to spin (tests/tactics_ability_spec.lua). Any tile in reach is a
-- legal aim, and the battle screen's dry run reads a sweep that catches nobody as a step (docs/weapons.md).
--
-- Below half health it is The Chains Break (+2 movement, +4 damage, a live passive) and the shove goes 2. An
-- unstocked trophy on Pride's approach rung: it is only ever found, on the Titan.
local Curve = require("models.curve")

local REACH = 2

local function broken(u)
    return require("models.trait").defs["trait_the_chains_break"].broken(u)
end

-- Every board cell within REACH of the wielder (Manhattan), whatever tile was aimed at.
local function sweep(combat, tx, ty, unit)
    local cx, cy = unit and unit.x or tx, unit and unit.y or ty
    local cells = {}
    for dx = -REACH, REACH do
        for dy = -REACH, REACH do
            if math.abs(dx) + math.abs(dy) <= REACH then cells[#cells + 1] = { x = cx + dx, y = cy + dy } end
        end
    end
    return cells
end

return {
    name = "Titan's Chain",
    description = "Hits every foe within 2 and shoves it 1; a collision deals the hit again. Below half: +2 move, +4 damage, shoves 2.",
    flavor = "It took a god to make it and a titan to break it. Swinging it only takes a grudge.",
    sprite = "assets/items/weapon_titans_chain.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    hands = 2,
    class = "barbarian",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_the_chains_break" },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = REACH,
        speed = 5,
        cost = { stat = "stamina", amount = 14 },
        damage = Curve.ramp(9, 19), -- per foe: the Labrys's weight, and it may hit several (Balance waiver)
        aoe = { cells = sweep },
        effect = function(fx)
            local u = fx.user
            local reach = broken(u) and 2 or 1
            for _, t in ipairs(fx.aoeUnits()) do
                if t.alive and t ~= u and t.side ~= u.side then
                    fx.damage(t, { knockback = { distance = reach, amount = fx.amount } })
                end
            end
        end,
    },
}
