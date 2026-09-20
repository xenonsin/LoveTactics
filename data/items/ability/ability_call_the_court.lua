-- CALL THE COURT: the King puts two more subjects on the board.
--
-- AN ABILITY AND NOT A HOOK, which is the whole design decision in this file. The King's rule is that
-- its court is its life (data/traits/trait_court_of_bone.lua), so the thing that REFILLS the court is
-- the most important move in the fight -- and a refill that fired from a hidden trait would read as the
-- boss cheating. As an active cast it goes through the intent telegraph like everything else: the
-- player sees it wind up, gets the beat to decide whether to spend the turn closing on the King instead,
-- and learns the fight's actual clock. That is the difference between a boss that is hard and a boss
-- that is unfair, and it is one field.
--
-- WHAT IT COSTS IT: a long cooldown and a slow speed, which together are the window. Kill the court,
-- and you have until the next call to put the King down -- so the fight has a rhythm rather than a
-- wall, and a company that bursts well is rewarded for holding its big turn until the room is empty.
--
-- SUMMONED AND NOT RAISED, deliberately, though `fx.raise` was the obvious first reach and is the
-- better fiction. A raise consumes a CORPSE, and a party member whose downed window has run out is a
-- corpse -- so the necromantic version of this quietly acquires the power to eat a roster member
-- permanently, off a rule the player was never told about. That is a large, unadvertised consequence
-- hanging off a boss's ordinary turn, and no amount of flavour pays for it. The King conjures its own.
--
-- Creature stock: unpriced, classless to every shelf, `noSteal`. Nothing deals a king's prerogative.
return {
    name = "Call the Court",
    description = "Summons two Skeleton Knights beside the caster.",
    flavor = "He does not raise them so much as remind them.",
    sprite = "assets/items/ability_call_the_court.png",
    type = "ability",
    tags = { "summon", "dark" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        -- Self-centred: the court arrives around the King, which is what makes clearing it a positional
        -- problem rather than an arithmetic one. A party that has fought its way to the King is now
        -- standing in the middle of the answer.
        range = 1,
        speed = 7, -- the slowest thing it does; the telegraph is the fight's clock
        cost = { stat = "stamina", amount = 12 },
        cooldown = 8,
        effect = function(fx)
            -- Two, placed on the caster's own flanks, trying the four orthogonals in turn. Summon.spawn
            -- refuses an occupied or illegal tile on its own, so a King backed into a corner calls
            -- fewer -- which is a reason to corner him, and exactly the kind of thing a player should be
            -- able to find out without being told.
            local u = fx.user
            if not u then return end
            local placed = 0
            for _, at in ipairs({
                { x = u.x - 1, y = u.y }, { x = u.x + 1, y = u.y },
                { x = u.x, y = u.y - 1 }, { x = u.x, y = u.y + 1 },
            }) do
                if placed >= 2 then break end
                -- `noClaim`, and it is the load-bearing option here. An ordinary summon ability HOLDS
                -- its creature (item.activeSummon) and falls silent until that creature dies -- right
                -- for a relic whose whole content is the thing it called, and wrong here twice over: it
                -- would let this place only one body, and it would gag the King for as long as any
                -- subject stood, which is the exact opposite of the pressure this ability exists to
                -- apply. The cooldown is the limiter instead, and it is visible.
                local called = fx.summon("character_skeleton_knight", at.x, at.y, { noClaim = true })
                if called then placed = placed + 1 end
            end
        end,
    },
}
