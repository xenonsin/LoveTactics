-- Calla's bound relic (Inquisitor). She names you first. After that it is procedure.
--
-- JUDGMENT SCALES WITH HOW MANY ARE ACCUSED, which is the whole of it: four names is a far worse day
-- than four separate ones, because the charge is read against all of them together. That is what makes
-- this a relic rather than a bigger Sentence.
--
-- THE CENSUS IS FOUR MARKED, so the shelf is the gate: Mark of Heresy and Anathema put the names down,
-- and Sentence and The Question each spend a single mark -- which means they COMPETE with this for the
-- same bodies. Marking widely and holding the marks, against cashing them one at a time, is the
-- decision the discipline is built on.
--
-- The Pyre burns every Marked enemy at a flat rate; this beats it once the count is high, which is the
-- right way round for the piece that cannot be bought.
return {
    name = "The Written Charge",
    description = "Every Marked foe is judged at once, and each blow grows with the number accused.",
    flavor = "She writes the whole list before she reads any of it. It saves going back.",
    sprite = "assets/items/sig_written_charge.png",
    type = "utility",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "inquisitor",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 14 },
        description = "Holy damage to every Marked foe, scaling with how many are Marked.",
        unlock = {
            field = { of = "unit", side = "foe", status = "status_mark", count = 4 },
            text = "4 foes Marked",
        },
        effect = function(fx)
            local accused = {}
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side and fx.hasStatus(u, "status_mark") then
                    accused[#accused + 1] = u
                end
            end
            -- Counted before any of it lands: a blow that killed one of the accused must not make the
            -- next blow smaller, or the order the list was written in would change the sentence.
            local weight = (fx.amount or 0) + 5 + #accused * 5
            for _, u in ipairs(accused) do
                fx.damage(u, { amount = weight, tags = { "holy" } })
            end
        end,
    },
    -- judging every Marked foe at once is the payoff the Lodge sets up
    bonus = { skill = 2 },
}
