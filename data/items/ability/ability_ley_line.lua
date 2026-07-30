-- Ley Line: the Totemist's payoff (hunter x priest). Two of your standing totems are joined, and the
-- ground between them takes the same sanctified charge -- every tile on the straight line, however far
-- apart they are.
--
-- The item that turns three emplacements into a shape. Before it, a Totemist planted posts and each one
-- held its own 3x3 square: the discipline was a set of independent zones with no relationship, and
-- planting the second one was worth exactly as much as planting the first. This makes the SECOND totem
-- retroactively about the first, which is the only thing that could make a totem's position a decision
-- rather than a convenience.
--
-- It plants nothing itself and calls nothing: it needs two posts already standing, so it is the third
-- action of a plan rather than the first. A Totemist who has not done the work gets a refusal and keeps
-- the mana.
--
-- The line is drawn tile by tile with a simple stepping walk rather than a proper Bresenham, and the
-- corners are cut generously (the walk moves diagonally where it can). A line that hugged the geometry
-- exactly would look correct on paper and read as arbitrary on a square grid, where what a player wants
-- is "the tiles between the two posts".
return {
    name = "Ley Line",
    description = "Joins two of your standing totems: the ground on the line between them is sanctified.",
    flavor = "The stones were always in a line. Someone simply had to say so out loud.",
    sprite = "assets/items/ability_ley_line.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "totemist",
    price = 420,
    unlockQuests = 10,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        description = "Sanctifies every tile between two of your totems. Needs two already standing.",
        effect = function(fx)
            -- The bearer's own posts only: a Totemist does not get to draw a line through somebody
            -- else's work, and an enemy totem is a target rather than an anchor.
            local posts = {}
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.summoner == fx.user and u.char and u.char.name == "Totem" then
                    posts[#posts + 1] = u
                end
            end
            if #posts < 2 then
                fx.log("action", "There is only one stone. A line wants two.")
                return
            end
            local a, b = posts[1], posts[2]
            local x, y = a.x, a.y
            -- Step toward the far post one tile at a time, moving on both axes where both still differ.
            -- Bounded by the board's own size so a bad state can never spin here.
            for _ = 1, 64 do
                if x == b.x and y == b.y then break end
                if x < b.x then x = x + 1 elseif x > b.x then x = x - 1 end
                if y < b.y then y = y + 1 elseif y > b.y then y = y - 1 end
                fx.placeHazard(x, y, "hazard_sacred", { amount = 4 + fx.level, owner = a, duration = 9999 })
            end
            fx.log("action", "The line between the stones takes light.")
        end,
    },
}
