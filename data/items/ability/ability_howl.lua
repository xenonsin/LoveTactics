-- THE WHITE WOLF'S HOWL: the fear, and the pack it brings.
--
-- Her turn, most turns. Two clauses, and they are one idea: everyone in the ring stops being able to
-- get away from her, and another alpha arrives to help with that. Where the pack's own howl only
-- frightens (ability_howl_lesser.lua), hers is the reason there keep being more wolves -- and the
-- reason her teeth get worse while you deal with them.
--
-- IT IS HER DAMAGE, NOT HER DECORATION. That is the whole design and it is what separates her from
-- every other summoner in the game. weapon_white_wolf_fangs strikes once for EACH wolf standing within
-- two of her, so a body that spends its turn calling one more alpha has spent its turn raising its own
-- blow -- and a party that ignores the pack to focus the god is choosing to be bitten five times a
-- round. The Unseeing's clan is a wall you have to get through (character_the_unseeing.lua); hers is a
-- number on her attack. Kill order is not advice here, it is arithmetic.
--
-- SHE CALLS ALPHAS, NOT GRUNTS, and that is a deliberate escalation over every other call in the game.
-- Each one arrives with the pack's howl and the presence aura in its own grid, so what lands is not a
-- body, it is a second source of Cowering and a standing buff on everything else she has -- which is
-- also the thing to watch when this fight is measured. Statuses refresh rather than stack
-- (Status.apply keeps the longer remaining), so two alphas cannot pile Cowering deeper; what they can
-- do is make sure it never lapses. If that reads as misery rather than as pressure in play, the dial is
-- the reserve below, not the blueprint that arrives.
--
-- THE CEILING IS THE COST, NEVER A RULE, and that lesson was paid for once already. Each standing alpha
-- locks away a third of her stamina for as long as it lives (Combat.reserve, released by
-- Combat.releaseHeldBy the moment it falls) -- so at two alphas she cannot afford to howl at all, and
-- killing one is what buys the next. ability_the_call.lua spends four paragraphs on why this cannot be
-- an `ai` count rule instead: when no authored rule matches, AI.plan falls through to the POSTURE,
-- which scores the kit and takes the best thing in it. The Unseeing obeyed his count rule, ignored it,
-- called twenty-five boars, gridlocked the arena and could not be reached. A ceiling has to be
-- something the caster CANNOT AFFORD to break.
--
-- THE RING IS THREE, where the pack's is two, so a player who has met both knows which animal howled
-- by how far the badge spread. Standing off an alpha is an answer. Standing off her is not -- she is
-- movement 6 on a 2x2 body, and getting out of three tiles costs you more than it costs her.
--
-- `noClaim` IS LOAD-BEARING. fx.summon normally stamps `item.activeSummon`, which is what makes a
-- summoning relic fall silent while its creature stands -- correct for a player's bound wolf, fatal for
-- a body whose entire turn is this. The flag weapon_marching_standard and ability_the_call already
-- wear, for the same reason: the summon is not what the item IS.
--
-- `class = "creature"` and no price: it carries no axis, so the pool cannot mint it and her fight can
-- never be handed to the player as-is (docs/bestiary.md). What she drops is a rebuild
-- (ability_mothers_howl.lua), which calls an ordinary wolf and knows nothing about alphas.
local RING = 3          -- tiles; the pack's lesser howl reaches 2, and the gap is meant to be read
local FEAR_TICKS = 10   -- ~2 turns at Status.TICKS_PER_TURN: the turn you read it on, and the turn it buys

return {
    name = "The White Wolf's Howl",
    description = "Frightens every foe within three tiles, then calls an alpha to her side.",
    flavor = "Every wolf in the wood stops what it is doing. So, for a moment, does everything else.",
    sprite = "assets/items/ability_howl.png", -- shares the pack's icon: it is the same voice, louder
    type = "ability",
    tags = { "beast", "fear", "summon" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self", -- see ability_howl_lesser.lua: a summon marks nobody, so it must be enumerated apart
        range = 0,
        support = false, -- the ring paints hostile; the arrival is not what the planner is aiming
        -- SLOW, AND THE NUMBER IS THE FIGHT. She refills the pack; the party clears it; whichever is
        -- faster decides whether there is a fight here. Pitched a tick under The Call's 8 because her
        -- teeth are what the pack feeds, so a howl she throws is a turn she does not spend biting --
        -- the trade the player is meant to watch her make.
        speed = 7,
        cost = { stat = "stamina", amount = 8 },
        -- A THIRD OF HER PER ALPHA. The same share ability_the_call settled on across six measured
        -- boards, against a stronger body: two standing alphas and the howl is unaffordable, one falls
        -- and it is affordable again. If the fight measures as a grind, this is the dial.
        reserve = { stat = "stamina", percent = 0.34 },
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
            -- The fear first, because it is the half that always happens: a hemmed-in howl still
            -- frightens, and the arrival is allowed to come up short (see below).
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_cowering", { duration = FEAR_TICKS })
                end
            end
            -- ONE, not a pair -- the rate is the fight (see `speed` above). Open ground beside her;
            -- hemmed in, the tile comes back nil and nothing arrives at all, which is the right failure
            -- and half the reason cornering her is worth the trouble.
            local tx, ty = fx.openTileNear(fx.user.x, fx.user.y)
            if tx then
                fx.summon("character_wolf_alpha", tx, ty, {
                    noClaim = true, -- the call is not what this item IS; it must not fall silent
                })
            end
        end,
    },
}
