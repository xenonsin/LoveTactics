-- THE CALL: the whole of what the Unseeing does before he turns.
--
-- He has no weapon (data/characters/character_the_unseeing.lua). This is his turn, every turn: more of
-- the clan out of the tree line, and the clan is the only thing in phase one that touches you. The
-- fight is not him -- it is the lanes his children commit to, and he is the reason there keep being
-- more of them.
--
-- WHAT THE CALL BINDS. Each boar arrives carrying trait_curse_bearer, handed to it by `opts.traits` --
-- Summon.spawn's seam for rules that belong to the BARGAIN rather than to the body ("the same blueprint
-- summoned by a different ability owes nothing"). So his boars leave curse on the tile they die on and a
-- roadside Wild Boar does not, and data/characters/character_boar.lua never learns this fight exists.
-- They arrive with their own Gore, because they are ordinary boars in every other respect -- which is
-- the point: you already know what they do, and he is about to make five of them.
--
-- `noClaim` IS LOAD-BEARING. fx.summon normally stamps `item.activeSummon`, which is what makes a
-- summoning relic fall silent while its creature stands -- correct for a player's bound wolf, fatal for
-- a boss whose entire turn is this. The flag is the one weapon_marching_standard already uses, for the
-- same reason: the summon is not what the item IS.
--
-- AIMED AT HIMSELF, and that is a fact about the planner rather than about the fiction. AI.candidates
-- enumerates a cast by the BODIES it could be aimed at; a summon marks nobody, so a tile-aimed one would
-- be offered no marks at all and would sit in the kit entering no plan ever. A `self` cast has exactly
-- one legal mark and is enumerated apart, which is the road ability_muster_rift takes for the same
-- reason. The creatures are placed on open ground beside him by fx.openTileNear.
--
-- THE CEILING IS THE RULE, NOT THE ABILITY. Uncapped, this fight never ends -- a body that makes two
-- boars a turn against four party members outruns any clear rate, and the skirmish budget would be
-- right to fail it. `count_at_most` says the thing that could not be said before: keep calling until
-- there are enough of them. Allies INCLUDE the caller, so 4 is the lord plus three, and a call of two
-- settles the standing clan at roughly three to five. Kill them faster than that and he simply refills;
-- kill HIM and the refilling stops, which is the sentence the whole phase is written to make obvious.
return {
    name = "The Call",
    description = "Calls one of the clan onto open ground beside him.",
    flavor = "He does not look up. He has not looked up in a long time. The tree line answers anyway.",
    sprite = "assets/items/ability_the_call.png",
    type = "ability",
    tags = { "summon" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        -- SLOW, and the number is the fight. He refills the clan; the party clears it; whichever is
        -- faster decides whether there is a fight here at all. Measured: with the call at speed 4 the
        -- refill matched the clear rate exactly and the fight could not be won from any of six boards
        -- -- the party ground boars for 200-plus unit-turns and never once touched him (with the call
        -- removed entirely, the same boards won 6 for 6 in under sixty). A summoner is only a fight if
        -- you can out-kill it, so the call is a ponderous animal's whole turn and then some.
        speed = 8,
        support = true, -- calling your own is a kindness: preview green, and the planner offers it allied marks
        cost = { stat = "stamina", amount = 6 },
        -- THE CEILING THAT ACTUALLY HOLDS. Each standing boar locks away a fifth of his pool for as
        -- long as it lives (Combat.reserve, released by Combat.releaseHeldBy the moment it falls) --
        -- the summoner's bargain ability_summon_fire_elemental strikes in mana, struck here in the
        -- only pool a beast has. Four of the clan and he cannot afford the call at all; kill one and
        -- he can, which is the fight saying out loud that clearing the clan is tempo rather than
        -- progress.
        --
        -- IT IS ON THE ABILITY BECAUSE A RULE IS NOT A GATE, and that cost a whole fight to learn. The
        -- `ai` block below already said `count_at_most`, and it was obeyed and irrelevant: when no
        -- authored rule matches, AI.plan falls through to the POSTURE, which simply scores the kit and
        -- takes the best thing in it -- and this is the only thing in his kit. Measured, he called 25
        -- boars into a forest, gridlocked the arena, and was never reached; the fight could not be won
        -- or lost. A ceiling has to be something the caster CANNOT AFFORD to break, not something its
        -- rules decline to do.
        -- A THIRD OF HIM PER BOAR, measured across six boards rather than judged. At a fifth the clan
        -- stood four or five deep and the party broke through on three boards of six -- on the other
        -- three it ground boars for 220 unit-turns and never touched him. At a half the call stopped
        -- mattering: the fights finished in the same 38-70 the lord alone takes, which is a summoner
        -- whose summons are decoration. A third wins from every board and still costs something --
        -- 64 to 204 unit-turns against the 27 to 53 he takes with no clan at all.
        reserve = { stat = "stamina", percent = 0.34 },
        ai = { priority = "high", act = "support",
               when = { subject = "any_ally", test = "count_at_most", value = 4 } },
        effect = function(fx)
            -- ONE, not a pair -- see `speed` above on why the rate is the whole fight. Open ground
            -- beside him; hemmed in, the tile comes back nil and nothing arrives at all, which is the
            -- right failure and the reason cornering him is worth doing.
            local tx, ty = fx.openTileNear(fx.user.x, fx.user.y)
            if tx then
                fx.summon("character_boar", tx, ty, {
                    traits = { "trait_curse_bearer" },
                    noClaim = true, -- the call is not what this item IS; it must not fall silent
                })
            end
        end,
    },
}
