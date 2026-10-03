-- GORGON'S GAZE: Medusa's stare, lifted off her for a shaman (data/characters/character_medusa.lua; "Envy's
-- Bestiary", row md_body, approved word for word). Every foe in a line of 4 gains Stone, and three Stone petrify a
-- body for 2 turns -- the rule lives in the Stone status itself (data/status/status_stone.lua), so this petrifies
-- exactly as her gaze does.
--
-- A lane cast, aimed at the adjacent tile as every lane cast in this engine is. The Shaman MANIPULATES what is laid
-- on a body; this lays a count a company has to watch climb. An unstocked trophy on the approach's rung.
return {
    name = "Gorgon's Gaze",
    description = "Foes in a line of 4 gain Stone. At 3 Stone a body is petrified for 2 turns.",
    flavor = "Look at it the way she would. Then look away quickly, before you learn how.",
    sprite = "assets/items/ability_gorgons_gaze.png",
    type = "ability",
    tags = { "earth", "magical" },
    class = "shaman",
    unlockLevel = 11,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 8 },
        aoe = { shape = "line", length = 4 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.applyStatus(u, "status_stone") end
            end
        end,
    },
}
