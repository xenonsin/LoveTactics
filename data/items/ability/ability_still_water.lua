-- STILL WATER: the Water Mirror's drop. Reviewed 2026-10-01..03 ("Envy's Bestiary"); round 3 moved it from the mage
-- to the summoner.
--
-- The pool's trick turned round: a copy of one of yours that the foe you name cannot touch. A cast aims one thing,
-- so the foe is what you aim at, and the copy is of your body standing nearest it -- the one it was about to hit.
-- The copy is fragile (any other blow unmakes it) and lasts 2 turns, and it KNOWS the named foe (Masks.ward), so
-- nothing that foe throws lands on it. One at a time, like every double.
--
-- The approved text read "evades"; the corpus verb for a blow that lands for nothing is Deflect
-- (item_text_style_spec), so the card says that.
return {
    name = "Still Water",
    description = "Make a fragile copy of an ally for 2 turns. It deflects every attack from the foe you name.",
    flavor = "The water shows them who they are fighting, and lets them keep swinging at it.",
    sprite = "assets/items/ability_still_water.png",
    type = "ability",
    tags = { "summon", "water", "magical" },
    class = "summoner",
    unlockLevel = 12,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 4,
        requiresSight = true,
        cooldown = 15,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            local foe = fx.target
            if not (foe and fx.combat) then return end
            local Combat = require("models.combat")
            -- Your body nearest the named foe (the caster included), never a summon.
            local ally, gap
            for _, u in ipairs(fx.combat.units or {}) do
                if u.alive and u.side == fx.user.side and not u.summoned then
                    local d = Combat.unitGap(foe, u)
                    if not gap or d < gap then ally, gap = u, d end
                end
            end
            if not ally then return end
            local x, y = fx.openTileNear(ally.x, ally.y)
            if not x then return end
            local copy = fx.copyOf(ally, x, y, { fragile = true, duration = 10, side = fx.user.side })
            if copy and copy.alive and copy.char and copy.char.id then
                require("models.masks").copyTactics(copy.char, ally.char)
                copy.knows = foe
            end
        end,
    },
}
