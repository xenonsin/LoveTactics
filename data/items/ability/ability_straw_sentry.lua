-- Straw Sentry: the knight stands a dummy up in the mud -- a jacket, a helm, a bundle of straw
-- (data/characters/character_straw_sentry.lua) -- and shouts the enemy onto it. Every foe within two
-- tiles of where it is planted is Taunted toward the DUMMY rather than toward the caster, so the turns
-- they spend obeying are turns spent hacking apart something that was never alive.
--
-- It is data/items/ability/ability_shout.lua's idea with the knight taken out of the middle. Shout is
-- the honest version of Sloth's answer -- draw the blows onto the one built to take them -- and this is
-- the dishonest one: draw them onto nothing at all. The trade between the two is real and worth
-- reading before buying either. Shout costs nothing but the turn and pulls the enemy onto a body that
-- can hold; this costs more, needs open ground, and pulls them onto a body that cannot -- but the
-- knight is not the one being hit while it works, and the taunt lands where the dummy was planted
-- rather than where the knight is standing. It is the reach that is being bought.
--
-- One at a time: the ability holds the item's summon claim (Combat.itemBlockReason), so there is no
-- second sentry while the first still stands. Cut it down -- and the enemy will, quickly -- and the
-- knight may stand another.
--
-- Two failure modes are deliberate rather than guarded against:
--   * A sentry planted on a trap or in a fire can die on arrival (models/summon.lua). It arrives dead,
--     the turn is spent, and nothing is taunted -- so look at the ground first.
--   * The taunt outlives the dummy. A foe that smashes the sentry on its first swing is still Taunted
--     for the rest of the duration, and Combat.planEnemyAction simply finds nothing to obey. That is a
--     confused enemy rather than a bug, and it is a perfectly good outcome for ten stamina.
return {
    name = "Straw Sentry",
    description = "Plants a lifeless dummy and Taunts nearby foes onto it instead of you.",
    flavor = "It cannot fight, cannot move, and cannot be reasoned with. Two of those are shared with the men attacking it.",
    sprite = "assets/items/ability_straw_sentry.png",
    type = "ability",
    tags = { "decoy", "taunt" },
    class = "knight",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "tile", -- aim an empty tile; the dummy is stood up there
        range = 3,
        speed = 5,
        support = true, -- not a blow: it reads green, and the AI treats it as one of its own
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            -- Forging the item makes the dummy harder to pull down (+2 health per level) and nothing
            -- else -- it has nothing else to make better. `amount` is the level itself, so a level-0
            -- sentry is the blueprint's own straw.
            local dummy = fx.summon("character_straw_sentry", fx.tx, fx.ty, {
                control = "none", timeless = true,
                scaling = { health = 2 }, amount = fx.level,
            })
            -- Stood up on a trap or in a fire, it can be gone before anyone looks at it. Nothing left
            -- to draw the eye, so nothing to taunt toward.
            if not (dummy and dummy.alive) then return end
            for _, u in ipairs(fx.unitsNear(fx.tx, fx.ty, 2)) do
                if u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "status_taunt")
                    -- The dummy, not the caster: this is the whole difference from a Shout.
                    if st then st.taunter = dummy end
                end
            end
        end,
    },
}
