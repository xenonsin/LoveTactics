-- FACELESS RETINUE: the Mask-Maker's drop, on the summoner's shelf. Reviewed 2026-10-01..03 ("Envy's Bestiary"); the
-- author did not like the first two drops, and named this one.
--
-- The Mask-Maker's trade at a person's size: summon a Faceless soldier (character_faceless, the line body) and hand
-- it a mask -- the face of a foe you can see, its stats and its whole kit, worn on the soldier's own health pool.
-- Locked, so it never Reshapes: it is what you made it. Priced as every standing summon is, by what it holds back,
-- and one at a time.
--
-- Which foe: the nearest one in the caster's sight when it is called, so the face it wears is the one already in
-- the fight beside it.
local SOLDIER = "character_faceless"

return {
    name = "Faceless Retinue",
    description = "Summon a Faceless soldier wearing the face of a foe you can see. It reserves a fifth of your mana.",
    flavor = "It asks for nothing but a face, and it does not mind whose.",
    sprite = "assets/items/ability_faceless_retinue.png",
    type = "ability",
    tags = { "summon" },
    class = "summoner",
    unlockLevel = 12,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 6,
        reserve = { stat = "mana", percent = 0.2 },
        effect = function(fx)
            if not require("models.character").defs[SOLDIER] then return end
            local s = fx.summon(SOLDIER, fx.tx, fx.ty)
            -- A dry run hands back a stand-in with no id, on a stand-in board with no ground to see across;
            -- only a real body on a real board puts a face on.
            if not (s and s.alive and s.char and s.char.id) then return end
            s.faceLocked = true
            -- The face: the nearest foe the caster can see.
            local Combat = require("models.combat")
            local face, gap
            for _, u in ipairs(fx.combat.units or {}) do
                if u.alive and u.side ~= fx.user.side and not u.summoned
                    and Combat.hasLineOfSight(fx.combat, fx.user.x, fx.user.y, u.x, u.y) then
                    local d = Combat.unitGap(fx.user, u)
                    if not gap or d < gap then face, gap = u, d end
                end
            end
            if not face then return end
            require("models.faces").wear(fx.combat, s, require("models.masks").exactCopy(face.char))
        end,
    },
}
