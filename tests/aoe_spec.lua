-- Tests for area-of-effect abilities (models/combat.lua: Combat.aoeCells / Combat.aoeUnits and the
-- fx.aoeUnits helper an AoE effect sweeps with). Fireball is the worked example: a radius-1 square
-- burst (corners included) that damages every unit caught in the footprint. Pure logic, so headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end

-- Place items into specific grid cells: `map` is { [slot] = itemId }. Clears the grid first.
local function equip(char, map)
    char.inventory = {}
    for slot, id in pairs(map) do char.inventory[slot] = Item.instantiate(id) end
end

-- Does `cells` (a Combat.aoeCells result) hold exactly the { {x,y}, ... } in `want`, same count?
local function coversExactly(cells, want)
    if #cells ~= #want then return false end
    for _, w in ipairs(want) do
        local found = false
        for _, c in ipairs(cells) do if c.x == w[1] and c.y == w[2] then found = true break end end
        if not found then return false end
    end
    return true
end

-- The fireball item on a freshly built mage (its inventory carries it by blueprint).
local function fireballOf(mage)
    for _, it in ipairs(mage.char.inventory) do
        if it.activeAbility and it.name == "Fireball" then return it end
    end
end

return {
    {
        name = "aoeCells is a 3x3 square (corners included) and clamps to the arena bounds",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 5, 5) })
            local ab = fireballOf(c.units[1]).activeAbility

            local cells = Combat.aoeCells(c, ab, 5, 5)
            assert(#cells == 9, "radius-1 square is 9 cells, got " .. #cells)
            local corner = false
            for _, cc in ipairs(cells) do if cc.x == 6 and cc.y == 6 then corner = true end end
            assert(corner, "the (6,6) corner is part of the square burst")

            -- A burst centred at the corner (1,1) keeps only its 4 in-bounds cells.
            assert(#Combat.aoeCells(c, ab, 1, 1) == 4, "footprint clamps to the arena edge")
        end,
    },
    {
        name = "a single-target ability (no aoe) covers only the target cell",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 2, 2) }, { unit("character_bandit", 5, 5) })
            local jolt
            for _, it in ipairs(c.units[1].char.inventory) do
                if it.activeAbility and it.name == "Jolt" then jolt = it end
            end
            local cells = Combat.aoeCells(c, jolt.activeAbility, 3, 3)
            assert(#cells == 1 and cells[1].x == 3 and cells[1].y == 3, "no aoe -> just the cell")
        end,
    },
    {
        name = "fireball sweeps every unit in the blast (friendly fire included)",
        fn = function()
            -- Three foes clustered so a burst at (5,5) catches an edge and a corner too, plus an
            -- ally standing in the blast to prove friendly fire.
            local c = Combat.new(arena(8, 8),
                { unit("character_mage", 5, 3), unit("character_knight", 4, 4) },
                { unit("character_bandit", 5, 5), unit("character_bandit", 6, 6), unit("character_bandit", 4, 5) })
            local mage = c.units[1]
            local fireball = fireballOf(mage)

            local swept = Combat.aoeUnits(c, fireball.activeAbility, 5, 5)
            assert(#swept == 4, "3 bandits + the knight ally in range, got " .. #swept)

            -- previewAbility replays the effect, so it reports the same four.
            local prev = Combat.previewAbility(c, mage, fireball, 5, 5)
            assert(#prev.order == 4, "preview reports every swept unit, got " .. #prev.order)

            -- Live cast damages all four.
            mage.char.stats.mana.current = 99
            local victims = { c.units[2], c.units[3], c.units[4], c.units[5] }
            local before = {}
            for _, v in ipairs(victims) do before[v] = v.char.stats.health.current end
            assert(Combat.useItem(c, mage, fireball, 5, 5), "fireball begins channeling")
            assert(Combat.resolveChannel(c, mage), "the wound-up blast lands")
            for _, v in ipairs(victims) do
                assert(v.char.stats.health.current < before[v],
                    "unit at (" .. v.x .. "," .. v.y .. ") took blast damage")
            end
        end,
    },
    {
        name = "a line footprint runs `length` tiles from the aimed cell, away from the caster, and clamps",
        fn = function()
            local c = { arena = arena(8, 8) }
            local ab = { aoe = { shape = "line", length = 4 } }
            local caster = { x = 2, y = 2 }

            -- Aiming east (target one tile to the +x): the line drives on through four tiles.
            assert(coversExactly(Combat.aoeCells(c, ab, 3, 2, caster),
                { { 3, 2 }, { 4, 2 }, { 5, 2 }, { 6, 2 } }), "eastward line covers four tiles in a row")
            -- Aiming south orients the same line down the +y axis.
            assert(coversExactly(Combat.aoeCells(c, ab, 2, 3, caster),
                { { 2, 3 }, { 2, 4 }, { 2, 5 }, { 2, 6 } }), "the line orients off the caster->target facing")
            -- A line that would run off the board keeps only its in-bounds tiles.
            assert(coversExactly(Combat.aoeCells(c, ab, 7, 5, { x = 5, y = 5 }),
                { { 7, 5 }, { 8, 5 } }), "the line clamps at the arena edge")
            -- With no caster there is no facing, so it collapses to just the aimed cell.
            assert(coversExactly(Combat.aoeCells(c, ab, 3, 2), { { 3, 2 } }),
                "no caster -> the directional footprint is just the aimed cell")
        end,
    },
    {
        name = "a cone footprint fans out `length` rows deep, one tile wider to each side per row",
        fn = function()
            local c = { arena = arena(8, 8) }
            local ab = { aoe = { shape = "cone", length = 3 } }
            local caster = { x = 2, y = 4 }

            -- Facing east: row 0 is the aimed cell, row 1 is 3 wide, row 2 is 5 wide (1 + 3 + 5 = 9).
            local cells = Combat.aoeCells(c, ab, 3, 4, caster)
            assert(coversExactly(cells, {
                { 3, 4 },                                  -- row 0: the tip
                { 4, 3 }, { 4, 4 }, { 4, 5 },              -- row 1: three wide
                { 5, 2 }, { 5, 3 }, { 5, 4 }, { 5, 5 }, { 5, 6 }, -- row 2: five wide
            }), "an eastward cone fans out three rows deep")

            -- A depth-1 cone is just the tip -- one row, one tile.
            assert(coversExactly(Combat.aoeCells(c, { aoe = { shape = "cone", length = 1 } }, 3, 4, caster),
                { { 3, 4 } }), "a depth-1 cone is only the aimed cell")

            -- With no caster there is no facing, so the cone collapses to the aimed cell.
            assert(coversExactly(Combat.aoeCells(c, ab, 3, 4), { { 3, 4 } }),
                "no caster -> the cone is just the aimed cell")
        end,
    },
    {
        name = "The First Motion widens from a two-tile line into a cone as it is forged",
        fn = function()
            -- Aim from mid-board (row 4) so the widest cone row stays in bounds.
            local caster = { x = 2, y = 4 }
            local c = { arena = arena(8, 8) }
            local function footprintAt(level)
                local blade = Item.instantiate("weapon_first_motion", 1, level)
                return Combat.aoeCells(c, blade.activeAbility, 3, 4, caster)
            end
            -- Un-forged: a straight line two tiles deep.
            assert(coversExactly(footprintAt(0), { { 3, 4 }, { 4, 4 } }),
                "at +0 the blow is a two-tile line")
            -- Mid-forge: the same line, three tiles deep.
            assert(coversExactly(footprintAt(3), { { 3, 4 }, { 4, 4 }, { 5, 4 } }),
                "at +3 the line lengthens to three tiles")
            -- Fully forged: it opens into a three-row cone (nine tiles).
            assert(#footprintAt(10) == 9, "at +10 the swing is a nine-tile cone")
        end,
    },
    {
        name = "a front footprint is a `width`-wide arc perpendicular to the facing, centred on the aimed cell",
        fn = function()
            local c = { arena = arena(8, 8) }
            local ab = { aoe = { shape = "front", width = 3 } }
            local caster = { x = 2, y = 2 }

            -- Facing south: the arc lies across the row in front (perpendicular to the facing).
            assert(coversExactly(Combat.aoeCells(c, ab, 2, 3, caster),
                { { 1, 3 }, { 2, 3 }, { 3, 3 } }), "a southward swing sweeps the row in front")
            -- Facing east: the arc rotates to lie along the column in front.
            assert(coversExactly(Combat.aoeCells(c, ab, 3, 2, caster),
                { { 3, 1 }, { 3, 2 }, { 3, 3 } }), "an eastward swing sweeps the column in front")
            -- A flank tile off the board is dropped.
            assert(coversExactly(Combat.aoeCells(c, ab, 1, 1, { x = 1, y = 2 }),
                { { 1, 1 }, { 2, 1 } }), "the arc clamps at the arena edge")
        end,
    },
    {
        name = "Cleave needs an adjacent melee weapon, then carves the 3x1 arc in front (hits every unit)",
        fn = function()
            -- Three foes across the row south of the knight; the swing is aimed at the middle one.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) },
                { unit("character_bandit", 2, 4), unit("character_bandit", 3, 4), unit("character_bandit", 4, 4) })
            local k = c.units[1]
            equip(k.char, { [5] = "ability_cleave" })
            k.char.stats.stamina.current = 99
            openTurn(c, k)

            -- No melee weapon beside it: refused, and the reason names the requirement.
            assert(Combat.adjacencyMet(k.char, k.char.inventory[5]) == false, "no melee weapon adjacent")
            local ok, reason = Combat.useItem(c, k, k.char.inventory[5], 3, 4)
            assert(not ok, "the cleave is refused without an adjacent melee weapon")
            assert(reason == "requires adjacent melee",
                "reason names the requirement, got " .. tostring(reason))

            -- Slot a sword adjacent: now it swings, and all three foes in the arc are struck.
            k.char.inventory[4] = Item.instantiate("weapon_iron_sword")
            local before = {}
            for _, b in ipairs({ c.units[2], c.units[3], c.units[4] }) do
                before[b] = b.char.stats.health.current
            end
            local ok2 = Combat.useItem(c, k, k.char.inventory[5], 3, 4)
            assert(ok2, "the cleave swings with an adjacent melee weapon")
            for _, b in ipairs({ c.units[2], c.units[3], c.units[4] }) do
                assert(b.char.stats.health.current < before[b],
                    "the foe at (" .. b.x .. "," .. b.y .. ") is caught in the arc")
            end
        end,
    },
    {
        name = "Power Shot needs an adjacent ranged weapon, then pierces a straight line of foes",
        fn = function()
            -- Two foes down the row east of the archer, one right in front and one three tiles out.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) },
                { unit("character_bandit", 4, 3), unit("character_bandit", 6, 3) })
            local k = c.units[1]
            equip(k.char, { [5] = "ability_powershot" })
            k.char.stats.stamina.current = 99
            openTurn(c, k)

            -- No ranged weapon beside it: refused, with the matching reason.
            local ok, reason = Combat.useItem(c, k, k.char.inventory[5], 4, 3)
            assert(not ok, "the shot is refused without an adjacent ranged weapon")
            assert(reason == "requires adjacent ranged",
                "reason names the requirement, got " .. tostring(reason))

            -- Slot a bow adjacent: the line fires and skewers both foes on it.
            k.char.inventory[4] = Item.instantiate("weapon_iron_bow")
            local before = {}
            for _, b in ipairs({ c.units[2], c.units[3] }) do before[b] = b.char.stats.health.current end
            local ok2 = Combat.useItem(c, k, k.char.inventory[5], 4, 3)
            assert(ok2, "the shot begins its overdraw with an adjacent ranged weapon")
            assert(Combat.resolveChannel(c, k), "the braced arrow looses")
            for _, b in ipairs({ c.units[2], c.units[3] }) do
                assert(b.char.stats.health.current < before[b],
                    "the foe at (" .. b.x .. "," .. b.y .. ") is pierced by the line")
            end
        end,
    },
    {
        name = "a data-file footprint (the Wolfsong Horn's howl) rings both Kaya and her wolf, de-duped and clamped",
        fn = function()
            local c = Combat.new(arena(16, 16),
                { unit("character_archer", 5, 5) }, { unit("character_bandit", 1, 15) })
            local u = c.units[1]
            local horn
            for i = 1, Character.MAX_INVENTORY do
                local it = u.char.inventory[i]
                if it and it.id == "utility_wolfsong_horn" then horn = it end
            end
            local ab = horn.activeAbility

            -- Wolf far from Kaya: two disjoint 5x5 rings, 25 + 25 cells.
            Combat.teleportUnit(c, u.wolfCompanion, 11, 11)
            assert(#Combat.aoeCells(c, ab, 5, 5, u) == 50,
                "two disjoint rings cover 50 cells, got " .. #Combat.aoeCells(c, ab, 5, 5, u))

            -- Wolf beside Kaya: the rings overlap, and the overlap is de-duped below 50.
            Combat.teleportUnit(c, u.wolfCompanion, 6, 5)
            assert(#Combat.aoeCells(c, ab, 5, 5, u) < 50, "the overlap between the two rings is de-duped")

            -- A dead wolf leaves only Kaya's ring (it cannot be resummoned), and it clamps at the corner.
            Combat.dealFlatDamage(c, u.wolfCompanion, 9999, {}, "test")
            assert(#Combat.aoeCells(c, ab, 5, 5, u) == 25, "a dead wolf leaves only Kaya's ring")
            assert(#Combat.aoeCells(c, ab, 1, 1, u) == 9, "and Kaya's ring clamps to the arena corner")
        end,
    },
}
