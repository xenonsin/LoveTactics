-- The Lent Aegis: the bearer gives their own armour away for a while. An ally is braced; the bearer
-- stands there in nothing much.
--
-- A BUFF PAID FOR OUT OF THE CASTER'S OWN BODY, which nothing else in this game does. Every other
-- support item is priced in mana and a turn -- abstract currencies that do not change where anybody
-- can stand. This is priced in DEFENSE, on the person casting it, for as long as it lasts, which makes
-- it the rare support decision that is also a positioning decision: the knight who lends their plate
-- to the archer has to spend the next two turns not being hit.
--
-- Which is exactly the trade sloth should be selling. The knight's shelf does not kill you, it decides
-- where you stand (docs/classes.md) -- and this decides it from both ends at once. It is at its best
-- lending to somebody who is about to be focused and standing somewhere nobody can reach; it is at its
-- worst, and genuinely bad, cast in the middle of a melee.
--
-- ADJACENCY: an `armor` item beside it, and the gate is doing real work rather than gesturing. You
-- cannot lend what you have not got -- and mechanically, the size of what is lent scales off the
-- neighbours, so a knight in a grid of plate lends a great deal more (and is left far more exposed)
-- than one carrying a single buckler. The item reads the loadout twice: once for permission, once for
-- the number.
return {
    name = "The Lent Aegis",
    description = "Braces an ally by stripping the bearer's own guard for as long as it holds.",
    flavor = "The Bastion's third oath, and the one nobody quotes: what I am wearing is not mine.",
    sprite = "assets/items/utility_lent_aegis.png",
    type = "utility",
    tags = { "structure" },
    class = "knight",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "ally",
        range = 4,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        support = true,
        requiresAdjacent = { type = "armor" },
        effect = function(fx)
            -- The plate around it in the grid decides how much there is to lend. Both halves read the
            -- same number, which is what makes the trade legible: whatever the ally gains, the bearer
            -- loses, exactly.
            local plates = fx.adjacentMatching({ type = "armor" })
            local lent = 4 + 3 * plates + fx.level
            local dur = 12 + fx.level
            if fx.target ~= fx.user then
                fx.applyStatus(fx.target, "status_lent_guard", { magnitude = lent, duration = dur })
                fx.applyStatus(fx.user, "status_given_guard", { magnitude = -lent, duration = dur })
                fx.log("status", string.format("%s hands their guard to %s (%d).",
                    fx.user.char and fx.user.char.name or "Unit",
                    fx.target.char and fx.target.char.name or "an ally", lent), { fx.user, fx.target })
            end
        end,
    },
}
