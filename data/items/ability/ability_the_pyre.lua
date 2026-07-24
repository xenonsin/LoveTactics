-- The Pyre: the Inquisitor's payoff (rogue x priest). Every Marked enemy on the field burns at once,
-- wherever it is standing.
--
-- The item that makes marking a PLAN rather than a prelude. Mark of Heresy, the Confessor's Needle,
-- Sentence and The Question all read one accusation at a time, so an Inquisitor's marks were a queue of
-- single targets. This collects on all of them together, which rewards spreading accusations across a
-- line instead of hoarding one -- and turns the discipline's setup turns into a number the player is
-- watching go up.
--
-- Field-wide and unaimed, so its damage is modest and its cost is not: against a board with one mark on
-- it this is a bad Fireball, and against a board the Inquisitor has been working for three turns it is
-- the end of the fight. That spread is the whole design.
--
-- It leaves the marks in place. Burning them off would make the Pyre and Sentence compete for the same
-- setup, and the shelf is meant to read as one escalation rather than two exits.
return {
    name = "The Pyre",
    description = "Every Marked enemy on the field takes holy fire at once.",
    flavor = "The accusations were collected over some days. The fire is very quick.",
    sprite = "assets/items/ability_the_pyre.png",
    type = "ability",
    tags = { "holy", "fire" },
    class = "priest",
    discipline = "inquisitor",
    price = 460,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 18 },
        damage = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },
        description = "Burns every Marked enemy, wherever it stands.",
        effect = function(fx)
            local burned = 0
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side ~= fx.user.side and fx.hasStatus(u, "status_mark") then
                    fx.damage(u)
                    burned = burned + 1
                end
            end
            if burned == 0 then
                fx.log("action", "Nobody here has been accused of anything.")
            end
        end,
    },
}
