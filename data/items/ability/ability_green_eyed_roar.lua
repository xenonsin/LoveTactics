-- GREEN-EYED ROAR: the Green-Eyed Monster's own (data/characters/character_green_eyed_monster.lua; "Envy's
-- Bestiary", round 2). It hates closeness: every pair of the company standing side by side, wherever on the board,
-- is shoved apart -- each body 1 tile straight away from the other, so the pair ends 2 tiles further apart. A body
-- in two pairs is shoved once, away from the first partner found. A collision bruises as any shove does.
--
-- Its planner roars whenever there is a pair to part (models/envy_oneoffs.lua); the cooldown keeps it a roar
-- rather than a turn spent every turn.
return {
    name = "Green-Eyed Roar",
    description = "Every pair of foes standing side by side is shoved 2 tiles apart.",
    flavor = "It does not need to hear what you two were saying. It already hates it.",
    sprite = "assets/items/ability_green_eyed_roar.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "fear" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cooldown = 10, -- two turns between roars
        support = false, -- a shove into the company: hostile, though it lands no damage of its own
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local Envy = require("models.envy_oneoffs")
            local board = fx.combat
            if not (board and board.units) then return end
            local foeSide
            for _, u in ipairs(board.units) do
                if u.alive and u.side ~= fx.user.side then foeSide = u.side break end
            end
            if not foeSide then return end
            local moved = {}
            for _, pair in ipairs(Envy.pairsOf(board, foeSide)) do
                local a, b = pair[1], pair[2]
                for _, step in ipairs({ { a, b }, { b, a } }) do
                    local body, partner = step[1], step[2]
                    if not moved[body] then
                        moved[body] = true
                        local dest = Envy.awayFrom(body, partner, 1)
                        if dest then fx.knockback(body, 1, { dest = dest }) end
                    end
                end
            end
        end,
    },
}
