-- Wild Growth: the Hamadryad calls the grove on, and every thorn patch and hedge of hers grows a tile.
--
-- It spends nothing she has not already spent: the growth is only where her line has grown something,
-- so a company that cut the hedges down and burned the briar off has already answered it. Each patch
-- and each hedge puts out one new tile onto the first free neighbour it has (orthogonal, in board order,
-- so it is deterministic), and a board that cannot hold another tile simply grows nothing there.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Wild Growth",
    description = "Every thorn patch and hedge of hers grows one tile.",
    flavor = "Nobody tends a churchyard yew. It tends itself, and it takes its time, and then it doesn't.",
    sprite = "assets/items/wild_growth.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false, -- aimed at her own feet, and grown against the company (items_spec)
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        ai = {
            { priority = "normal", act = "cast", when = { subject = "any_foe", test = "within", value = 5 } },
        },
        effect = function(fx)
            local combat, side = fx.combat, fx.user.side
            local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
            local Combat = require("models.combat")
            local Wall = require("models.wall")
            local function freeFor(x, y) return Combat.footprintFree(combat, 1, 1, x, y) end
            -- Snapshot first, so what grows this cast does not grow again inside the same cast.
            local patches, hedges = {}, {}
            for _, h in ipairs(combat.hazards or {}) do
                if h.alive and h.id == "hazard_briarfloor" and h.side == side then patches[#patches + 1] = h end
            end
            for _, w in ipairs(combat.walls or {}) do
                if w.alive and w.id == "hedge" and w.side == side then hedges[#hedges + 1] = w end
            end
            for _, h in ipairs(patches) do
                for _, d in ipairs(DIRS) do
                    local x, y = h.x + d[1], h.y + d[2]
                    local covered = false
                    for _, z in ipairs(fx.hazardsAt(x, y)) do
                        if z.id == "hazard_briarfloor" then covered = true end
                    end
                    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
                    if not covered and row and row[x] and row[x].walkable then
                        fx.placeHazard(x, y, "hazard_briarfloor", { amount = h.amount })
                        break
                    end
                end
            end
            for _, w in ipairs(hedges) do
                for _, d in ipairs(DIRS) do
                    local x, y = w.x + d[1], w.y + d[2]
                    if freeFor(x, y) and not Wall.at(combat, x, y) then
                        fx.placeWall(x, y, "hedge", { health = 12 + fx.level, duration = 18 + fx.level })
                        break
                    end
                end
            end
            fx.log("action", string.format("%s calls the grove on.", fx.user.char.name or "She"))
        end,
    },
}
