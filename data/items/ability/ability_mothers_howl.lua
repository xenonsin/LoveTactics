-- MOTHER'S HOWL: the White Wolf's voice, as a thing a person can learn.
--
-- The first entry on her drop list, which is the position reserved for what the fight was built to hand
-- over (docs/drops.md). She howls, the ring flinches, and something arrives -- and this is that, cut
-- down to a size a party can carry.
--
-- WHAT IS CUT. Hers calls an ALPHA, which arrives with a howl of its own and a standing buff on every
-- wolf in the fight (ability_howl.lua). This calls an ordinary wolf, and knows nothing about alphas. A
-- boss's own kit is never handed to the player (docs/bestiary.md): what drops is a rebuild at a scale
-- somebody could actually be given, and the gap between the two is meant to be felt by anyone who has
-- stood in front of her.
--
-- NOT PURCHASABLE, and that is an authoring decision rather than an oversight. Abilities are one of the
-- three kinds of thing that still carry a price (docs/shelf.md), so this could have sat on the Lodge's
-- counter once the company had carried one out -- and it does not. It comes off her body or it does not
-- come at all. `dropTier` is set by the grading pass (`. drop-tier`), which reads worth rather than
-- taste; nothing here picks a depth by hand.
--
-- THE CEILING IS THE COST, exactly as it is on hers: each standing wolf locks away a quarter of the
-- caster's mana for as long as it lives, so the pack a player can hold is bounded by their own pool
-- rather than by a rule they have to be told. ability_summon_wolf already prices a called wolf this way
-- and this is deliberately the same bargain, since the two do the same thing with different voices.
-- Mana rather than the stamina hers reserves: a wolf costs an animal its wind and a person their will.
local RING = 3
local FEAR_TICKS = 10 -- ~2 turns at Status.TICKS_PER_TURN

return {
    name = "Mother's Howl",
    description = "Frightens every foe within three tiles, then calls a wolf. Reserves a quarter of your max mana while it lives.",
    flavor = "You do not sound like her. Nothing does. The wood comes anyway, which is the part nobody expected.",
    sprite = "assets/items/ability_mothers_howl.png",
    type = "ability",
    tags = { "beast", "fear", "summon" },
    class = "hunter",
    unlockLevel = 15,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    activeAbility = {
        target = "self", -- a summon marks nobody: see ability_howl.lua on why it must be enumerated apart
        range = 0,
        support = false, -- the ring paints hostile
        speed = 7,
        cost = { stat = "stamina", amount = 8 },
        reserve = { stat = "mana", percent = 0.25 },
        aoe = {
            cells = function(_, tx, ty)
                local out = {}
                for dx = -RING, RING do
                    for dy = -RING, RING do out[#out + 1] = { x = tx + dx, y = ty + dy } end
                end
                return out
            end,
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_cowering", { duration = FEAR_TICKS })
                end
            end
            -- Hemmed in, nothing arrives and the fear still lands -- the same failure hers takes, and
            -- the same reason to mind where you are standing when you call.
            local tx, ty = fx.openTileNear(fx.user.x, fx.user.y)
            if tx then
                fx.summon("character_wolf_grunt", tx, ty, {
                    scaling = { health = 2, damage = 0.5 },
                    amount = 10 + fx.level, -- base 10, +1 per upgrade level, as ability_summon_wolf scales
                })
            end
        end,
    },
}
