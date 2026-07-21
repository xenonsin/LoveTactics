-- Tests for the class contract (docs/classes.md). A class is a vendor SHELF, so everything here asks
-- questions about shelves: does every class have one, does it hold enough to arm somebody, and does it
-- read as a kind of armed person rather than a leftover pile.
--
-- This is what makes that doc enforced rather than aspirational, in the same way tests/weapon_spec.lua
-- does for the family contract -- and it is the specific drift it exists to catch: fighter had
-- accumulated 10 of the 19 classed weapons and seven families, while knight and alchemist had none,
-- because nothing ever asked. The contract table below lives HERE rather than in models/, exactly as
-- weapon_spec's does: it is a statement about the authored catalog, not a rule the engine enforces.
--
-- Deliberately NOT asserted here: which resource pool a class spends. The doc names one per class, but
-- it is a characterization rather than a law -- knight is hybrid by design, and the rogue pays mana for
-- two of its ten abilities. A test that pinned it would be asserting a tidier game than the one that
-- exists. Growth tables are covered by tests/growth_spec.lua, and "every item names a known class" by
-- tests/progression_spec.lua; neither is repeated.
--
-- Pure logic, headless.

local Item = require("models.item")
local Vendor = require("models.vendor")

-- The shelf each class carries, as declared by docs/classes.md.
--
--   families -- the weapon archetypes that belong on this shelf. A class is a family CLUSTER: the
--               reason fighter is axes-and-hammers rather than "all melee" is that "melee" and
--               "fighter" are not the same idea, and nothing noticed the difference for a long time.
--   floor    -- the minimum sellable weapons. A floor, not a quota: fighter and knight carry more
--               because they are the armed shelves, and the catalog may grow unevenly. What it forbids
--               is a shelf with nothing on it.
local CONTRACT = {
    fighter   = { families = { "axe", "hammer", "greatsword" } },
    knight    = { families = { "sword", "spear", "mace" } },
    rogue     = { families = { "dagger" } },
    hunter    = { families = { "bow", "longbow" } },
    mage      = { families = { "wand", "staff" } },
    -- `censer` is the Cathedral's alone -- a liturgical object, and nobody else's to swing. And no
    -- `sword`, nor any other edge: the taboo is absolute. The Cathedral consecrates weapon_demon_bane
    -- but the Bastion sells it, which is the rule stated from the other side rather than an exception
    -- to it -- the faithful forge an edge, they just never carry one.
    priest    = { families = { "staff", "censer" } },
    alchemist = { families = { "dagger", "wand" } },
}

local WEAPON_FLOOR = 3

-- Every weapon a class actually sells, as { id, def } pairs. SELLABLE is the operative word: `class`
-- means "sold by", so a weapon with no price rightly names no class -- weapon_parasitic_staff is issued
-- to the mage and the priest both, and stamping it with either one would make the OTHER grow wrong
-- (class drives the growth tally -- Character.recordUse). Unpriced gear belongs to no shelf.
local function weaponsOf(class)
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.type == "weapon" and def.price and def.class == class then
            out[#out + 1] = { id = id, def = def }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return {
    {
        name = "every class has a declared shelf, and every declared shelf is a real class",
        fn = function()
            for class in pairs(Item.CLASSES) do
                assert(CONTRACT[class], "class '" .. class .. "' has no shelf in docs/classes.md")
            end
            for class in pairs(CONTRACT) do
                assert(Item.CLASSES[class], "docs/classes.md describes unknown class '" .. class .. "'")
            end
        end,
    },
    {
        name = "every class names weapon families that exist",
        fn = function()
            for class, c in pairs(CONTRACT) do
                assert(#c.families > 0, class .. " claims no weapon families")
                for _, family in ipairs(c.families) do
                    assert(Item.ARCHETYPES[family],
                        class .. " claims unknown weapon family '" .. family .. "'")
                end
            end
        end,
    },
    {
        name = "every class stocks at least three weapons -- no shelf is an empty rack",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local weapons = weaponsOf(class)
                assert(#weapons >= WEAPON_FLOOR,
                    class .. " sells only " .. #weapons .. " weapon(s); the floor is " .. WEAPON_FLOOR
                        .. " -- see docs/classes.md")
            end
        end,
    },
    {
        name = "a class's weapons come from its own family cluster, and nowhere else",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local allowed = {}
                for _, family in ipairs(CONTRACT[class].families) do allowed[family] = true end
                for _, w in ipairs(weaponsOf(class)) do
                    local family = Item.archetype(w.def)
                    assert(family, w.id .. " declares no family")
                    assert(allowed[family],
                        w.id .. " is a '" .. family .. "' on the " .. class .. " shelf, which carries "
                            .. table.concat(CONTRACT[class].families, "/")
                            .. " -- either it is on the wrong shelf, or docs/classes.md changed its mind")
                end
            end
        end,
    },
    {
        name = "every class vendor can arm a newcomer: a rank-1 weapon on every shelf",
        fn = function()
            -- The shelf-side reading of the ladder: progression_spec asserts each vendor has SOMETHING
            -- at rank 1, which a torch would satisfy. This asks for a weapon -- a class you cannot buy
            -- a weapon from at entry rank is a class you cannot start playing.
            for class in pairs(Item.CLASSES) do
                local entry = false
                for _, w in ipairs(weaponsOf(class)) do
                    if (w.def.repRank or 1) <= 1 then entry = true end
                end
                assert(entry, class .. " sells no rank-1 weapon: nothing to start with")
            end
        end,
    },
    {
        name = "every weapon a vendor stocks is one its class's shelf claims",
        fn = function()
            -- The same cluster rule asked through the vendor rather than the blueprint, so a shelf that
            -- derives its stock (Vendor.stock reads `class`, it is never authored) cannot drift apart
            -- from the table above.
            for id, def in pairs(Vendor.defs) do
                -- The general store (the Market) is not a class shelf: it sells classless goods and
                -- no weapons at all, so the family-cluster contract does not apply to it.
                if not def.general then
                    local families = CONTRACT[def.class] and CONTRACT[def.class].families
                    assert(families, id .. " sells for unknown class '" .. tostring(def.class) .. "'")
                    local allowed = {}
                    for _, family in ipairs(families) do allowed[family] = true end
                    for _, entry in ipairs(Vendor.stock(id, 4)) do
                        local blueprint = Item.defs[entry.id]
                        if blueprint.type == "weapon" then
                            local family = Item.archetype(blueprint)
                            assert(allowed[family],
                                id .. " stocks " .. entry.id .. " (" .. tostring(family) .. "), which the "
                                    .. def.class .. " shelf does not claim")
                        end
                    end
                end
            end
        end,
    },
}
