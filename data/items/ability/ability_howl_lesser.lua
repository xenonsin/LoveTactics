-- THE PACK'S HOWL: the half of the call that only frightens.
--
-- The Alpha Wolf's whole contribution beyond its own teeth, and the reason it is worth reaching past.
-- data/encounters/encounter_wolf_pack.lua has claimed since it was written that the alpha gives that
-- fight a kill order -- "the pack is worth more with it alive, so the correct play is to reach past the
-- teeth in front of you" -- and until this file the alpha was a grunt with bigger numbers, so that
-- sentence was true of nothing on the board. This is what makes it true, with the presence aura beside
-- it (data/items/utility/utility_pack_presence.lua).
--
-- COWERING, AND THAT IS THE WHOLE EFFECT (data/status/status_cowering.lua): everyone in the ring moves
-- two fewer spaces for about two turns. It forbids nothing. It is not a stun and it must never be read
-- as one -- what it takes is the ability to CLOSE, which is the only thing the party wants against a
-- line of animals whose every bite ends in a step backwards (weapon_wolf_fangs). The pack's game is the
-- gap; this is the pack taking your half of that argument.
--
-- A RING OF TWO, WHERE THE WHITE WOLF'S IS THREE (ability_howl.lua). The lesser howl is lesser in reach
-- as well as in kind, so a player who has met both can tell which animal just howled by how far the
-- badge spread -- and so that standing off an alpha is a real answer, where standing off her is not.
--
-- IT CALLS NOTHING. The summoning clause belongs to her alone: a grunt that could make more wolves
-- turns every roadside pack into an unbounded fight, and the boss's turn stops reading as the boss's
-- turn. See ability_howl.lua for the ceiling that makes the call safe on the one body that has it.
--
-- `class = "creature"` and no price, like every other thing a beast is born with: it carries no axis,
-- so the drop pool cannot mint it and a boss's fight can never be handed to the player as-is
-- (docs/bestiary.md). The player's version of a howl is an authored rebuild, not this
-- (data/items/ability/ability_mothers_howl.lua).
local RING = 2          -- tiles; hers is 3 (ability_howl.lua), and the difference is meant to be read
local FEAR_TICKS = 10   -- ~2 turns at Status.TICKS_PER_TURN: the turn you read it on, and the turn it buys

return {
    name = "Howl",
    description = "Frightens every foe within two tiles: they move fewer spaces.",
    flavor = "Not a warning. Wolves do not warn. It is the pack telling each other where you are.",
    sprite = "assets/items/ability_howl.png",
    type = "ability",
    tags = { "beast", "fear" },
    class = "creature",
    noSteal = true, -- born with, not carried: a pickpocket cannot lift a voice
    activeAbility = {
        -- AIMED AT ITSELF, and that is a fact about the planner rather than about the fiction.
        -- AI.candidates enumerates a cast by the BODIES it could be aimed at, so a tile-aimed ring
        -- would be offered no marks and would sit in the kit entering no plan ever. A `self` cast has
        -- exactly one legal mark and is enumerated apart -- the road ability_the_call takes, for the
        -- same reason.
        target = "self",
        range = 0,
        support = false, -- a fear is not a kindness: the ring paints hostile, and foes are its marks
        speed = 5,       -- a turn, but not a ponderous one -- the alpha still bites on the turns between
        cost = { stat = "stamina", amount = 5 },
        -- Declared rather than computed inside the effect, so the red ring the player sees and the
        -- bodies that actually flinch are one and the same set (Combat.aoeCells de-dups and clamps).
        aoe = {
            cells = function(_, tx, ty)
                local out = {}
                for dx = -RING, RING do
                    for dy = -RING, RING do out[#out + 1] = { x = tx + dx, y = ty + dy } end
                end
                return out
            end,
        },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            -- Sweep the very footprint aoeCells drew and frighten every foe on it. Allies and the
            -- howler stand on those tiles too, so they are filtered out here rather than in the shape.
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_cowering", { duration = FEAR_TICKS })
                end
            end
        end,
    },
}
