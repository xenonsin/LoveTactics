-- Beat the Bounds: the hunter half of the Warden (knight x hunter). Every enemy standing in a hazard --
-- ANY hazard, whoever laid it -- is Rooted where it stands and takes the toll for being there.
--
-- The "whoever laid it" is the whole item, and it was a deliberate revision: the first draft only
-- collected on ground the warden had placed itself, which made this a second Warden's Writ with extra
-- steps. Read against every hazard on the field, it becomes something the shelf did not otherwise have
-- -- a reason to fight ON bad ground. An enemy pyromancer's fire is now the warden's fence. A burning
-- village is a warden's best turn of the fight.
--
-- Rooted rather than Halted, so it does not simply repeat the Writ: the Writ takes the turn of whoever
-- ENTERS, this one pins whoever is ALREADY THERE. Enter and you lose the turn; linger and you lose the
-- ability to leave. Together they are a border; separately they are two different threats.
--
-- Field-wide rather than aimed, which is why it costs what it does and why its damage is small: it is a
-- collection, not a strike. Against a line that has kept out of the weather it does nothing at all, and
-- that is the counterplay -- the answer to a warden is dry ground.
return {
    name = "Beat the Bounds",
    description = "Every enemy standing in any hazard is Rooted and takes damage.",
    flavor = "Once a year the parish walks its own edges, striking them, so that everyone remembers where they are.",
    sprite = "assets/items/ability_beat_the_bounds.png",
    type = "ability",
    tags = { "control", "physical" },
    class = "hunter",
    discipline = "warden",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 9 },
        damage = { 4, 5, 5, 6, 6, 7, 8, 8, 9, 9, 10 },
        description = "Roots and damages every enemy standing in a hazard, wherever it is and whoever laid it.",
        effect = function(fx)
            local Hazard = require("models.hazard")
            local caught = 0
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side ~= fx.user.side and Hazard.at(fx.combat, u.x, u.y) then
                    fx.damage(u)
                    fx.applyStatus(u, "status_root")
                    caught = caught + 1
                end
            end
            if caught == 0 then
                fx.log("action", "The bounds are walked, and nobody is standing on them.")
            end
        end,
    },
}
