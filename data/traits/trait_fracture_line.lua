-- FRACTURE LINE: the Unwanted's rule, carried on its organ (data/items/utility/utility_fracture_line.lua). Creature
-- identity pass, 2026-11-19.
--
-- THE CRACK RUNS OUT FROM IT. At each threshold it is cut past (the organ's `cracks`, 66% and 33%), a crack runs
-- out of every side of its body in straight lines, `reach` tiles long and as wide as the body. Every foe standing
-- on a line is cut for `cut`, and every tile of it is left as Glass Shards (data/hazards/hazard_glass_shards.lua),
-- which cut and strip whoever of the company ends a turn there.
--
-- WHY IT CHANGED. It used to shed a pair of glass-motes at each threshold, which is exactly what The Long Winter
-- does with drift-things -- one apex template printed twice (the audit's same-apex row). The Winter's
-- escalation is TEMPO (more bodies, fewer of your turns); this one's is GROUND. The lines run straight off its
-- four sides and never off its corners, so the answer is a place to stand: off the diagonal when it is about to
-- crack, and then never in the glass it leaves. Its health bar is the telegraph -- the cuts come at two-thirds and
-- one-third, and the player can see both coming.
--
-- WHY NOT ALSO HEAL ON THE MOTES' RETURN (the row's other option). That kept the shed, so the Winter and the
-- Unwanted would still have been the same fight with a different follow-up; the crack replaces the shed outright.
--
-- A STAGE, NOT A REFLEX (`notAReaction`), for trait_boss_phases' reason: a body comes apart at its threshold
-- whether or not it has been stunned, or a party could stun it past both cracks.
local function Combat() return require("models.combat") end

local REACH, CUT = 3, 8

local function walkable(combat, x, y)
    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    return cell ~= nil and cell.walkable == true
end

-- Every tile the crack covers: from each cell along each side of the body, straight out, stopping at the first
-- tile nothing could stand on (a crack does not run through a wall).
local function lines(combat, u, reach)
    local w, h = u.w or 1, u.h or 1
    local out = {}
    local function run(x, y, dx, dy)
        for step = 1, reach do
            local cx, cy = x + dx * step, y + dy * step
            if not walkable(combat, cx, cy) then return end
            out[#out + 1] = { x = cx, y = cy }
        end
    end
    for i = 0, w - 1 do
        run(u.x + i, u.y, 0, -1)          -- up, off the top row
        run(u.x + i, u.y + h - 1, 0, 1)   -- down, off the bottom row
    end
    for j = 0, h - 1 do
        run(u.x, u.y + j, -1, 0)          -- left, off the left column
        run(u.x + w - 1, u.y + j, 1, 0)   -- right, off the right column
    end
    return out
end

local function crack(ctx)
    local u, combat = ctx.unit, ctx.combat
    local reach, cut = ctx.param("reach", REACH), ctx.param("cut", CUT)
    local struck = {}
    local cells = lines(combat, u, reach)
    -- Cut first, then lay the glass: a body standing on a line is wounded by the crack opening under it, and the
    -- shards are what is left once it has.
    for _, c in ipairs(cells) do
        local body = Combat().unitAt(combat, c.x, c.y)
        if body and body.alive and body.side ~= u.side and not struck[body] then
            struck[body] = true
            -- Through the armour, as the shards it leaves are: the floor opening under a body is not a blow a coat turns.
            Combat().dealFlatDamage(combat, body, cut, { "physical", "slash" }, "Fracture Line", u, { raw = true })
        end
    end
    for _, c in ipairs(cells) do ctx.placeHazard(c.x, c.y, "hazard_glass_shards") end
    return cells
end

return {
    name = "Fracture Line",
    description = "At 2/3 and 1/3 health, lines of glass run 3 tiles off each side: 8 damage to foes on them, ignoring armor.",
    notAReaction = true,
    -- A boss's stage script, weighed as Demon Ascendant is (0.5). On the def rather than in Grade.TRAIT_GRADE for
    -- trait_ashen_echo's reason.
    grade = 0.5,
    reach = REACH,
    cut = CUT,
    lines = lines, -- exported for the spec, which checks the shape rather than re-deriving it
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        -- Read off the organ's BLUEPRINT: Item.instantiate copies a whitelist, and the thresholds are a fact about
        -- what the piece is (models/gorgon.lua reads its `perseus` flag the same way).
        local def = ctx.item and require("models.item").defs[ctx.item.id]
        local at = (def and def.cracks) or { 0.66, 0.33 }
        local hp = u.char.stats.health
        local max = hp.max or 0
        if max <= 0 then return end
        local fraction = (hp.current or 0) / max
        -- Cross as many thresholds as this one blow spans, each crack in turn (trait_boss_phases' loop).
        while ctx.trait.stacks < #at and fraction <= at[ctx.trait.stacks + 1] do
            ctx.trait.stacks = ctx.trait.stacks + 1
            ctx.log("system", ctx.trait.stacks == 1
                and "A crack runs out of the Unwanted, and the floor around it turns to glass."
                or "The Unwanted cracks again, and more of the floor goes with it.")
            crack(ctx)
            if not u.alive then return end
        end
    end,
}
