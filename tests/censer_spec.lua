-- Tests for the censer family and the `incense` mechanic (Combat.layIncense, docs/weapons.md).
--
-- The weapon_spec sweep asserts every censer DECLARES smoke; this asserts the smoke behaves. All four
-- cases pin something that would break silently -- a cloud that stops following, a blessing that stops
-- lifting, two censers folding into one zone, or ground outliving the body carrying it. The family's
-- whole claim is "a banner is ground that stays; a censer is ground that walks", and only the first
-- case here is that claim.
--
-- Pure logic, headless. Fixture style mirrors tests/hazard_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")

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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- A character with an EMPTY grid, so a case controls exactly what its units carry (mirrors
-- tests/weapon_spec.lua's plainChar). Critical here: the priest's own default kit would otherwise
-- bring ground of its own to the party.
local function plainChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function give(char, id)
    local item = Item.instantiate(id)
    Character.addItem(char, item)
    return item
end

-- Every live hazard of `id` on the board, as a set of "x,y" keys.
local function cloudCells(c, id)
    local out = {}
    for _, h in ipairs(c.hazards or {}) do
        if h.alive and h.id == id then out[h.x .. "," .. h.y] = true end
    end
    return out
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

return {
    {
        name = "a censer's smoke follows its bearer: laid where they are, gone from where they were",
        fn = function()
            local priest = plainChar("character_priest")
            give(priest, "weapon_censer")
            local c = Combat.new(arena(10, 10), { unit(priest, 3, 3) }, { unit("character_bandit", 9, 9) })
            local bearer = c.units[1]

            -- Construction routes through Combat.rebase, so the cloud is already up before any turn.
            local before = cloudCells(c, "hazard_incense")
            assert(count(before) == 9, "a radius-1 cloud is the 3x3 the bearer stands in the middle of")
            assert(before["3,3"] and before["2,2"] and before["4,4"], "centred on the bearer")

            openTurn(c, bearer)
            assert(Combat.moveUnit(c, bearer, 6, 3), "the bearer walks three tiles east")

            local after = cloudCells(c, "hazard_incense")
            assert(count(after) == 9, "still exactly one cloud -- it moved, it did not accumulate")
            assert(after["6,3"], "the smoke is where the bearer now stands")
            -- The whole mechanic in one assertion: the old ground is GONE. Without the lift in
            -- Combat.layIncense this cloud would be a wake, which is what `trail` already is.
            assert(not after["2,2"] and not after["2,3"] and not after["2,4"],
                "the ground it left is clear: a censer walks, it does not trail")
        end,
    },
    {
        name = "the blessing is a leash: it holds inside the smoke and lifts outside it",
        fn = function()
            local priest = plainChar("character_priest")
            give(priest, "weapon_censer")
            local ally = plainChar("character_knight")
            local c = Combat.new(arena(12, 12),
                { unit(priest, 3, 3), unit(ally, 4, 3) },
                { unit("character_bandit", 11, 11) })
            local bearer, friend = c.units[1], c.units[2]

            assert(Status.has(friend, "status_blessing"), "an ally beside the priest stands in the smoke")

            -- Walk the ALLY out of the cloud. Blessing declares no `lingers`, so it is zone-bound: it
            -- is stamped with hazard_incense as its source and Hazard.reap ends it the moment no such
            -- zone sits under the bearer. This is what makes the censer a position, not a gift.
            openTurn(c, friend)
            assert(Combat.moveUnit(c, friend, 7, 3), "the ally walks away from the priest")
            assert(not Status.has(friend, "status_blessing"),
                "out of the smoke, the blessing lifts")

            -- And the reverse: walking back into it grants it again, with no re-cast.
            openTurn(c, friend)
            assert(Combat.moveUnit(c, friend, 4, 3), "the ally returns to the priest's side")
            assert(Status.has(friend, "status_blessing"), "back in the smoke, blessed again")

            -- The bearer is blessed by its OWN cloud -- the deliberate difference from a banner, which
            -- is an object holding ground for other people and does not rally itself.
            assert(Status.has(bearer, "status_blessing"), "the priest stands in its own smoke")
        end,
    },
    {
        name = "two censers keep their own zones, and one going out does not take the other's ground",
        fn = function()
            -- The failure banners already document: a zone-bound status remembers the id that granted
            -- it, so zones keyed only by id would let one censer's cloud hold another's blessing alive.
            -- Here the ids differ (incense vs choking), and both must coexist on shared tiles.
            local priest = plainChar("character_priest")
            give(priest, "weapon_censer")
            -- The Cathedral's other censer, carried here by a MAGE -- legal precisely because `class` is
            -- a shop taxonomy and never an equip gate (docs/classes.md). Two different zone ids on two
            -- different bodies is the case: it is the shape banners already warn about.
            local alch = plainChar("character_mage")
            give(alch, "weapon_censer_of_ashes")

            local c = Combat.new(arena(12, 12),
                { unit(priest, 4, 4), unit(alch, 5, 4) },
                { unit("character_bandit", 11, 11) })

            local holy = cloudCells(c, "hazard_incense")
            local fumes = cloudCells(c, "hazard_choking")
            assert(count(holy) == 9 and count(fumes) == 9, "each censer lays its own 3x3")
            -- Their squares overlap; the shared tiles carry BOTH zones rather than folding into one.
            assert(holy["5,4"] and fumes["4,4"], "the two clouds overlap without merging")

            -- The priest walks off (3 tiles: its whole movement budget). Its ground goes with it; the
            -- other bearer's stays exactly where it was.
            openTurn(c, c.units[1])
            assert(Combat.moveUnit(c, c.units[1], 4, 7), "the priest leaves")
            local fumesAfter = cloudCells(c, "hazard_choking")
            assert(count(fumesAfter) == 9, "the other censer's cloud is untouched")
            assert(fumesAfter["5,4"] and fumesAfter["4,4"],
                "lifting one censer's smoke never lifts another's")
        end,
    },
    {
        name = "the smoke answers to the body carrying it: kill the bearer and the ground goes",
        fn = function()
            local priest = plainChar("character_priest")
            give(priest, "weapon_censer")
            local c = Combat.new(arena(10, 10), { unit(priest, 3, 3) }, { unit("character_bandit", 8, 8) })
            local bearer = c.units[1]

            assert(count(cloudCells(c, "hazard_incense")) == 9, "the cloud is up")

            -- Killed through the real damage path, so the real death path runs. The zone is OWNED by
            -- the bearer, so the ordinary owned-zone rules end it -- the same ones that drop a banner's
            -- square when the banner is cut down. Nothing censer-specific runs here.
            Combat.dealFlatDamage(c, bearer, 9999)
            assert(not bearer.alive, "the bearer is down")
            assert(count(cloudCells(c, "hazard_incense")) == 0,
                "a censer with nobody to carry it holds no ground")
        end,
    },
}
