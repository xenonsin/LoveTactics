-- Scatterlight: the Ninja's sixth item, and the one that admits the discipline is about confusion rather
-- than control. Three doubles are thrown onto nearby tiles at random, and the ninja ends up in one of
-- their places -- also at random.
--
-- Six items rather than five on this shelf, which the subclasses have precedent for (they run five to
-- eight, docs/classes.md). It is here because the author asked for it by name, and because it is the one
-- item on the shelf where the ninja gives up knowing where they will be.
--
-- The randomness is chosen, which is the distinction worth drawing: `fx.random` draws from the battle's
-- own sequence (Combat.roll), so a replay scatters identically and two machines watching one fight agree.
-- A player who casts this has decided that being unpredictable to themselves is worth being
-- unpredictable to the enemy AI, which reads three fresh bodies and has no way to tell which is real.
--
-- It feeds the rest of the shelf: three clones is three Substitutions banked, and three places Shadow
-- Step can take you. This is the mana dump that stocks the other two.
return {
    name = "Scatterlight",
    description = "Throws three doubles onto random nearby tiles, and swaps you into one of their places.",
    flavor = "Ask which one is the real one and you have already lost the minute it takes to be wrong.",
    sprite = "assets/items/ability_scatterlight.png",
    type = "ability",
    tags = { "illusion", "utility" },
    class = "mage",
    discipline = "ninja",
    price = 480,
    unlockQuests = 9,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        description = "Plants three fragile doubles on random tiles within two, then swaps you with one.",
        effect = function(fx)
            local planted = {}
            -- Ten draws for three tiles: a scatter, not a survey. Tiles that cannot hold a double are
            -- simply lost, so a ninja casting this in a corridor gets fewer than three and that is the
            -- corridor's answer to the spell.
            for _ = 1, 10 do
                if #planted >= 3 then break end
                local dx, dy = fx.random(5) - 3, fx.random(5) - 3
                if not (dx == 0 and dy == 0) then
                    local double = fx.copy(fx.user.x + dx, fx.user.y + dy,
                        { fragile = true, control = "none", decoy = true, noClaim = true })
                    if double and double.alive then planted[#planted + 1] = double end
                end
            end
            if #planted == 0 then
                fx.log("action", "The light scatters and finds nowhere to stand.")
                return
            end
            fx.swap(planted[fx.random(#planted)])
        end,
    },
}
