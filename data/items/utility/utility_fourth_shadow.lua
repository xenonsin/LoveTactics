-- Miro's bound relic (Ninja). There are four of him, and one is real.
--
-- THE CENSUS IS CLONES STANDING, which makes the shelf both the gate and the ammunition: Mirror Image
-- and Scatterlight put them out, and because the payoff DOUBLES what is up, every clone bought before
-- pressing this is worth two. Substitution spends one to eat a blow -- a real cost against a gate
-- counted in clones, and the most interesting decision on the shelf because of it.
--
-- WHAT IT DOES is double the shadows and then have all of them strike at once, each cutting everything
-- beside it. A clone is a body on the board (Summon), so "each does an AoE within 1" is exactly what
-- it sounds like -- four or six small blasts placed wherever he has been scattering himself.
return {
    name = "The Fourth Shadow",
    description = "Doubles your clones, then every one of them cuts everything beside it.",
    flavor = "Ask which is real and you have already spent the turn you had.",
    sprite = "assets/items/sig_fourth_shadow.png",
    type = "utility",
    tags = { "signature", "shadow" },
    class = "rogue",
    discipline = "ninja",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        description = "Each clone spawns another, then all of them strike their neighbours.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3 },
            text = "3 clones standing",
        },
        effect = function(fx)
            -- Snapshot first: the new shadows must not spawn shadows of their own, and the strike has
            -- to include them, so the list is taken once and then grown once.
            local shadows = {}
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user then shadows[#shadows + 1] = u end
            end
            for _, clone in ipairs(shadows) do
                local tile = fx.openTileNear(clone.x, clone.y)
                if tile then
                    local made = fx.copy(tile.x, tile.y)
                    if made then shadows[#shadows + 1] = made end
                end
            end
            -- Every shadow, old and new, cuts the ring it is standing in.
            for _, clone in ipairs(shadows) do
                for _, near in ipairs(fx.unitsNear(clone.x, clone.y, 1) or {}) do
                    if near.side ~= fx.user.side then fx.damage(near) end
                end
            end
        end,
    },
}
