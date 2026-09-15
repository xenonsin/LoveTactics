-- Provoke: the knight half of the Champion (fighter x knight). Plant yourself and dare the line: every
-- adjacent foe is Taunted onto you (data/status/status_taunt.lua -- they must come for the shouter with
-- their default weapon), and you brace for it (status_defending). The setup for the Champion's
-- Riposte-wall: make them swing, and be the wall they swing into. Where Shout reaches across a room,
-- this is close and personal -- and it braces, which Shout does not.
--
-- AIMED EXACTLY AS CLEAR OUT IS (data/items/ability/ability_clear_out.lua), because it is the same
-- gesture -- a ring centred on the body standing in the middle of it -- and three lines say so. `aoe`
-- makes the eight cells a DECLARED footprint, so the board lights them and the card draws them rather
-- than leaving the reach buried in the effect's own radius. `support = false` overrides the guess that
-- a self-target is a kindness, so the ring previews red like the blow it sets up. And the sweep below
-- reads that footprint back through fx.aoeUnits, so the tiles shown and the foes taunted are one set.
-- Answering Blow, the other half of the wall, already takes the same box: a taunt that skipped the
-- corners would be asking for the fight in one shape and answering it in another.
return {
    name = "Provoke",
    description = "Taunts every adjacent foe onto you and braces you against the blows.",
    flavor = "Come on, then. All of you. That was always the plan.",
    sprite = "assets/items/ability_provoke.png",
    type = "ability",
    tags = { "impact" },
    class = "champion", -- fighter x knight; the Riposte-wall mechanic's first stock
    price = 165,
    unlockQuests = 1,
    activeAbility = {
        target = "self",
        range = 0,
        -- THE EIGHT TILES AROUND YOU, CORNERS INCLUDED -- the whole box, not the plus, and the same
        -- one Clear Out and Answering Blow take. The foe a taunt most exists to turn around is the one
        -- that has worked its way round your shoulder, and that foe is standing on a diagonal.
        aoe = { radius = 1, shape = "square" },
        -- Not a kindness. Combat.isSupportAbility reads a self-target as friendly and would paint the
        -- ring green; what happens inside it is done TO them, and only the brace lands on you.
        support = false,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            -- The declared footprint, read back rather than re-measured: fx.aoeUnits hands back exactly
            -- the bodies standing on the cells the preview lit (and narrows them as a Careful Sigil
            -- beside it allows), so the promise and the taunt can never come apart.
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive and u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "status_taunt")
                    if st then st.taunter = fx.user end
                end
            end
            fx.applyStatus(fx.user, "status_defending", { magnitude = 6 + fx.level })
        end,
    },
}
