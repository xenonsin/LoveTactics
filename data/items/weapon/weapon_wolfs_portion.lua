-- An axe, so it cleaves (docs/weapons.md) -- and it is the one axe in the game that does not want you to.
-- Its arc lands hardest on a LONE body and falls off sharply for every extra thing it catches: inverted
-- frenzy.
--
-- Quest-only: `class` with no `price`.
--
-- A DELIBERATE DEVIATION, in the sense docs/weapons.md means it -- said out loud here rather than left
-- to be discovered. The family contract is that an axe is what you carry when there is more than one
-- thing in front of you, and data/items/weapon/weapon_butchers_wedge.lua is the pure expression of that:
-- every extra body raises what all of them take. This is that keyword with the sign flipped.
--
-- Why it is worth breaking the rule for: the axe family has a real hole in it, which is that all of it
-- is worthless in a duel. A fighter who buys into axes has bought a loadout that does nothing on the
-- boss turn, and the honest fix is not to make crowd weapons secretly fine against one target -- it is
-- to put ONE axe on the rack that is the duel, and let the shape of the family stay sharp everywhere
-- else. It still cleaves; it simply hates doing it.
--
-- It keeps the arc rather than becoming a single-target swing, and that matters: the footprint is what
-- makes the drop-off a decision the player makes with their feet. Line the swing up so it catches only
-- the champion and it is the heaviest one-handed blow on the shelf. Get sloppy and catch two of his
-- guards with him and you have thrown the turn away.
return {
    name = "Wolf's Portion",
    description = "Cleaves a wide arc -- devastating against a lone foe, and weaker for every extra body it catches.",
    flavor = "The wolf that eats first eats everything. The pack is the part that goes wrong.",
    sprite = "assets/items/wolfs_portion.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 11 },
        -- Well ABOVE the iron axe's -- this is the lone-target number, and it is what the weapon is for.
        damage = { 11, 12, 13, 15, 16, 17, 19, 20, 21, 23, 24 },
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            local caught = fx.aoeUnits()
            -- -35% per body past the first, floored at a quarter so a botched swing is a bad swing
            -- rather than a wasted turn. Counts BODIES, not enemies -- an ally in the arc spoils the
            -- portion exactly as a foe does, which is the same rule `frenzy` runs on (docs/weapons.md).
            local share = math.max(0.25, 1 - 0.35 * (#caught - 1))
            local scaled = math.max(1, math.floor((fx.amount or 0) * share))
            for _, u in ipairs(caught) do
                fx.damage(u, { amount = scaled })
            end
        end,
    },
}
