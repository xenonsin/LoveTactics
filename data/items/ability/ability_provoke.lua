-- Provoke: the knight half of the Champion (fighter x knight). Plant yourself and dare the line: every
-- adjacent foe is Taunted onto you (data/status/status_taunt.lua -- they must come for the shouter with
-- their default weapon), and you brace for it (status_defending). The setup for the Champion's
-- Riposte-wall: make them swing, and be the wall they swing into. Where Shout reaches a diamond, this
-- is close and personal -- and it braces, which Shout does not.
return {
    name = "Provoke",
    description = "Taunts every adjacent foe onto you and braces you against the blows.",
    flavor = "Come on, then. All of you. That was always the plan.",
    sprite = "assets/items/ability_provoke.png",
    type = "ability",
    tags = { "impact" },
    class = "knight",
    discipline = "champion", -- fighter x knight; the Riposte-wall mechanic's first stock
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.alive and u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "status_taunt")
                    if st then st.taunter = fx.user end
                end
            end
            fx.applyStatus(fx.user, "status_defending", { magnitude = 6 + fx.level })
        end,
    },
}
