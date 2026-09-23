-- Compline: the last office of the day, and the Alraune Anchoress keeps it. Every Mandrake on the board
-- screams at once, and none of them has to die to do it.
--
-- THE SHRIEK WITHOUT THE DEATH. The scream a Mandrake gives when it comes up (trait_mandrake_shriek) is
-- a Stun on every body within two tiles, both sides; this rings it from every Mandrake of hers at once,
-- and reads the radius off that trait so the two cannot drift. The mandrakes stay in the floor.
--
-- TELEGRAPHED A TURN AHEAD, because a board-wide stun that could not be seen coming would be a tax, not
-- a fight. The wind-up is the tell (`windup`): a company has one turn to walk out of the Mandrakes'
-- reach, cut enough of them down (each one it cuts screams on its own, which is the price), or break
-- her channel. She does not stun herself -- an anchoress keeps the hours; she does not hear them.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). models.trait is required
-- inside the effect, never at load: items load while models.character is still being built, and the
-- trait module requires it back.
return {
    name = "Compline",
    description = "Channeled: every Mandrake of hers shrieks at once, Stunning all within 2 of it.",
    flavor = "The bell for the last office. In the Anchorhold it is not a bell.",
    sprite = "assets/items/compline.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false, -- aimed at her own feet, and it is still a blow at the company (items_spec)
        range = 0,
        windup = 6, -- one turn's tell
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "exists" } },
        },
        effect = function(fx)
            local shriek = require("models.trait").defs.trait_mandrake_shriek
            local radius = (shriek and shriek.radius) or 2
            local rang = 0
            for _, m in ipairs(fx.combat.units) do
                if m.alive and m.side == fx.user.side and m.char and m.char.id == "character_mandrake" then
                    rang = rang + 1
                    fx.burst(m.x, m.y, { "nature" })
                    for _, u in ipairs(fx.unitsNear(m.x, m.y, radius)) do
                        if u ~= m and u ~= fx.user and u.alive then fx.applyStatus(u, "status_stun") end
                    end
                end
            end
            fx.log("action", rang > 0
                and string.format("%s keeps the hours, and the garden answers.", fx.user.char.name or "She")
                or string.format("%s keeps the hours, and nothing in the floor answers.", fx.user.char.name or "She"))
        end,
    },
}
