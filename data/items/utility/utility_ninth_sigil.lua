-- Nio's bound relic (Elementalist). He writes on the floor before he casts, and this is the line that
-- makes the writing walk.
--
-- WHAT A SIGIL IS FOR is standing beside it, which is also its weakness: a circle cut in the floor
-- waits for somebody to come to it. The ninth one does not wait. Every working he has laid is copied
-- under every foe on the board -- the ground he chose, arriving where they chose to stand.
--
-- THE CENSUS IS THREE WORKINGS ON THE GROUND, counted as hazards his side laid, so it reads whatever
-- he has been casting rather than a named list: Graven Circle, the storms, the Cinderstride and
-- Tidewalker Boots laying element behind every step. More ground down is more copies made, which is
-- the whole build.
--
-- Copies carry the ORIGINAL's id, so each arrives as exactly the thing he cast -- element, duration
-- and every reading of it identical. No new hazard, no special case: it is fx.placeHazard, aimed by
-- what is already on the board.
return {
    name = "The Ninth Sigil",
    description = "Copies every working you have laid beneath every foe on the field.",
    flavor = "Eight of them wait where he cut them. The ninth is the one that goes looking.",
    sprite = "assets/items/sig_ninth_sigil.png",
    type = "utility",
    tags = { "signature", "arcane" },
    class = "mage",
    discipline = "elementalist",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 14 },
        description = "Every working you laid is copied under every foe.",
        unlock = {
            field = { of = "hazard", side = "party", count = 3 },
            text = "3 workings on the ground",
        },
        effect = function(fx)
            -- Snapshot both lists before placing: the copies are hazards too, and a loop that walked
            -- them would copy its own copies until the board was nothing but ground.
            local laid, marks = {}, {}
            for _, h in ipairs((fx.combat and fx.combat.hazards) or {}) do
                if h.alive and h.side == fx.user.side then laid[#laid + 1] = h end
            end
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side then marks[#marks + 1] = u end
            end
            for _, h in ipairs(laid) do
                for _, u in ipairs(marks) do
                    fx.placeHazard(u.x, u.y, h.id, { side = fx.user.side })
                end
            end
        end,
    },
    -- every working you laid, under every foe at once
    bonus = { magicDamage = 3 },
}
