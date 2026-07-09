-- Tests for inventory-grid adjacency effects (models/character.lua grid helpers + the
-- Combat.* adjacency layer): 3x3 neighbor math, Omnislash scaling off adjacent weapons (with a
-- preview/live match), Rain of Arrows' adjacent-bow requirement gate, a Fire Stone aura granting
-- the fire tag + Burn to a neighboring cast, and the UI connector-link descriptor. Pure logic,
-- headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Place items into specific grid cells: `map` is { [slot] = itemId }. Clears the grid first.
local function equip(char, map)
    char.inventory = {}
    for slot, id in pairs(map) do
        char.inventory[slot] = Item.instantiate(id)
    end
end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function hasLink(links, from, to, kind)
    for _, l in ipairs(links) do
        if l.from == from and l.to == to and l.kind == kind then return true end
    end
    return false
end

return {
    {
        name = "adjacentIndices covers the 8-neighborhood (diagonals included) and clamps at edges",
        fn = function()
            assert(#Character.adjacentIndices(1) == 3, "a corner cell has 3 neighbors")
            assert(#Character.adjacentIndices(2) == 5, "an edge cell has 5 neighbors")
            assert(#Character.adjacentIndices(5) == 8, "the center cell has 8 neighbors")
            assert(contains(Character.adjacentIndices(1), 5), "the diagonal (1->5) counts as adjacent")
            assert(contains(Character.adjacentIndices(1), 2), "the orthogonal (1->2) counts as adjacent")
            assert(not contains(Character.adjacentIndices(1), 6), "a non-neighbor (1->6) is excluded")
        end,
    },
    {
        name = "Omnislash damage scales per adjacent weapon, and the preview matches the live cast",
        fn = function()
            -- Base cast: no adjacent weapons -> 1x power.
            local c0 = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local k0 = c0.units[1]
            equip(k0.char, { [5] = "ability_omnislash" })
            k0.char.stats.stamina.current = 99
            openTurn(c0, k0)
            local ok0, r0 = Combat.useItem(c0, k0, k0.char.inventory[5], 3, 4)
            assert(ok0, "omnislash lands with no adjacent weapons")

            -- Two adjacent weapons -> 3x power (1x base + 1x each). Every weapon adds `power` (6)
            -- pre-mitigation, so two weapons is exactly +12 damage over the base cast.
            local c2 = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local k2, b2 = c2.units[1], c2.units[2]
            equip(k2.char, { [5] = "ability_omnislash", [4] = "iron_sword", [6] = "iron_sword" })
            k2.char.stats.stamina.current = 99
            openTurn(c2, k2)

            local preview = Combat.previewAbility(c2, k2, k2.char.inventory[5], 3, 4)
            local predicted = preview.entries[b2].damage
            local ok2, r2 = Combat.useItem(c2, k2, k2.char.inventory[5], 3, 4)
            assert(ok2, "omnislash lands with adjacent weapons")
            assert(r2.damageDealt == predicted,
                "preview (" .. predicted .. ") matches the live hit (" .. r2.damageDealt .. ")")
            assert(r2.damageDealt == r0.damageDealt + 12,
                "two adjacent weapons add 12 damage, got " .. r2.damageDealt .. " vs base " .. r0.damageDealt)
        end,
    },
    {
        name = "Rain of Arrows requires an adjacent bow to fire, then hits its 3x3 area",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 5) })
            local k = c.units[1]
            equip(k.char, { [5] = "ability_rain_of_arrows" })
            k.char.stats.stamina.current = 99
            openTurn(c, k)

            assert(Combat.adjacencyMet(k.char, k.char.inventory[5]) == false, "no bow adjacent")
            local ok, reason = Combat.useItem(c, k, k.char.inventory[5], 3, 5)
            assert(not ok, "the cast is refused without an adjacent bow")
            assert(reason == "requires adjacent bow", "reason names the requirement, got " .. tostring(reason))

            -- Slot a bow adjacent to the ability: now it fires.
            k.char.inventory[4] = Item.instantiate("bow")
            assert(Combat.adjacencyMet(k.char, k.char.inventory[5]) == true, "an adjacent bow satisfies it")
            local ok2, r2 = Combat.useItem(c, k, k.char.inventory[5], 3, 5)
            assert(ok2, "the volley fires with an adjacent bow")
            assert(r2.damageDealt > 0, "it deals area damage to the target cell")
        end,
    },
    {
        name = "itemBlockReason names why an ability can't be activated (the gate the UI grays on)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 5) })
            local k = c.units[1]
            equip(k.char, { [5] = "ability_rain_of_arrows" })
            k.char.stats.stamina.current = 99
            openTurn(c, k)
            local rain = k.char.inventory[5]

            -- Affordable, in stock, but the bow it requires isn't beside it: blocked on adjacency,
            -- and the reason is the one useItem reports so the slot and the cast can't disagree.
            local blocked = Combat.itemBlockReason(k, rain)
            assert(blocked, "rain of arrows is blocked with no adjacent bow")
            assert(blocked.kind == "adjacency", "the missing bow blocks it, got " .. tostring(blocked.kind))
            assert(blocked.reason == select(2, Combat.useItem(c, k, rain, 3, 5)),
                "the block reason is what useItem refuses the cast with")
            assert(blocked.text:find("adjacent bow"), "the player-facing text names the bow: " .. blocked.text)

            -- Bow in place, so only the cost can stop it. An empty pool blocks it on cost instead,
            -- naming the resource that fell short.
            k.char.inventory[4] = Item.instantiate("bow")
            assert(Combat.itemBlockReason(k, rain) == nil, "an adjacent bow unblocks the volley")
            k.char.stats.stamina.current = 0
            local broke = Combat.itemBlockReason(k, rain)
            assert(broke and broke.kind == "cost" and broke.stat == "stamina",
                "an empty pool blocks it on cost")

            -- A passive item is inert, not blocked -- it never grays out.
            assert(Combat.itemBlockReason(k, Item.instantiate("leather_armor")) == nil,
                "a passive item reports no block reason")
        end,
    },
    {
        name = "a Fire Stone infuses an adjacent weapon: it gains the fire tag and inflicts Burn",
        fn = function()
            -- Augmented: sword adjacent to the Fire Stone. The target has fire resist 3, so the
            -- fire tag being applied shaves 3 off the hit; and Burn is inflicted.
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local k, b = c.units[1], c.units[2]
            equip(k.char, { [5] = "fire_stone", [4] = "iron_sword" })
            k.char.stats.stamina.current = 99
            b.resist = { fire = 3 }
            openTurn(c, k)
            local ok, r = Combat.useItem(c, k, k.char.inventory[4], 3, 4)
            assert(ok, "the infused sword strikes")
            assert(Status.has(b, "burn"), "an adjacent Fire Stone sets the target alight")

            -- Control: identical sword + target, but no Fire Stone adjacent -> no fire tag, no Burn.
            local cc = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local kk, bb = cc.units[1], cc.units[2]
            equip(kk.char, { [1] = "iron_sword" })
            kk.char.stats.stamina.current = 99
            bb.resist = { fire = 3 }
            openTurn(cc, kk)
            local ok2, r2 = Combat.useItem(cc, kk, kk.char.inventory[1], 3, 4)
            assert(ok2, "the control sword strikes")
            assert(not Status.has(bb, "burn"), "no adjacent Fire Stone -> no Burn")
            assert(r.damageDealt == r2.damageDealt - 3,
                "the fire tag applies: fire resist 3 shaves 3 off the infused hit ("
                .. r.damageDealt .. " vs " .. r2.damageDealt .. ")")
        end,
    },
    {
        name = "a water-tagged weapon and a non-adjacent weapon both resist the Fire Stone aura",
        fn = function()
            -- Water weapon adjacent to the Fire Stone: exempt from the infusion.
            local cw = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local kw, bw = cw.units[1], cw.units[2]
            kw.char.inventory = {}
            kw.char.inventory[5] = Item.instantiate("fire_stone")
            local wsword = Item.instantiate("iron_sword")
            wsword.tags[#wsword.tags + 1] = "water"
            kw.char.inventory[4] = wsword
            kw.char.stats.stamina.current = 99
            openTurn(cw, kw)
            assert(Combat.useItem(cw, kw, kw.char.inventory[4], 3, 4), "the water sword strikes")
            assert(not Status.has(bw, "burn"), "a water-tagged weapon resists the infusion")

            -- Sword NOT adjacent to the Fire Stone (opposite corner): no infusion.
            local cn = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local kn, bn = cn.units[1], cn.units[2]
            equip(kn.char, { [1] = "fire_stone", [9] = "iron_sword" })
            kn.char.stats.stamina.current = 99
            openTurn(cn, kn)
            assert(Combat.useItem(cn, kn, kn.char.inventory[9], 3, 4), "the distant sword strikes")
            assert(not Status.has(bn, "burn"), "a non-adjacent weapon is not infused")
        end,
    },
    {
        name = "adjacencyLinks reports aura / boost / requirement relationships (and none when apart)",
        fn = function()
            local knight = Character.instantiate("knight")
            knight.inventory = {}
            knight.inventory[5] = Item.instantiate("fire_stone")           -- aura source (center)
            knight.inventory[4] = Item.instantiate("iron_sword")           -- infused neighbor
            knight.inventory[1] = Item.instantiate("ability_omnislash")    -- scales off weapons
            knight.inventory[2] = Item.instantiate("iron_sword")           -- feeds Omnislash
            knight.inventory[7] = Item.instantiate("ability_rain_of_arrows") -- needs a bow
            knight.inventory[8] = Item.instantiate("bow")                  -- satisfies the requirement

            local links = Combat.adjacencyLinks(knight)
            assert(hasLink(links, 5, 4, "aura"), "Fire Stone (5) auras the adjacent sword (4)")
            assert(hasLink(links, 1, 2, "boost"), "Omnislash (1) scales off the adjacent weapon (2)")
            assert(hasLink(links, 7, 8, "requirement"), "Rain of Arrows (7) requirement met by the bow (8)")

            -- Items placed apart form no relationship.
            local apart = Character.instantiate("knight")
            apart.inventory = {}
            apart.inventory[1] = Item.instantiate("fire_stone")
            apart.inventory[9] = Item.instantiate("iron_sword")
            assert(#Combat.adjacencyLinks(apart) == 0, "opposite-corner items are not adjacent")
        end,
    },
}
