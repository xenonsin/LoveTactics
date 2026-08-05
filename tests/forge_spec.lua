-- Tests for the Forge: the three-track bill (a currency track -- TECHNIQUE for anything belonging to a
-- house, keyed on the item's discipline or else its class, and gold only for classless stock -- plus
-- craft stock by the item's own quality and house stock by its class, doubled across both parents for
-- a discipline item) and the ceiling rules (house standing, uncapped). Also covers the material model's
-- two families and the technique ledger: how it is banked per action, capped per battle, and spent off
-- the single strongest holder. Headless.

local Forge = require("models.forge")
local Material = require("models.material")
local Discipline = require("models.discipline")
local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Vendor = require("models.vendor")
local Quest = require("models.quest")

-- A player with unlimited stock, so a test about the BILL is never really a test about the purse. The
-- technique holder is a real roster member with a bottomless ledger: the bill reads earned minus spent
-- off one body (Discipline.techniqueHolder), so a bare number on the player would not be seen at all.
local function richPlayer()
    local p = Player.new()
    p.gold = 100000
    p.materials = setmetatable({}, { __index = function() return 9999 end })
    local deep = Character.instantiate("character_knight")
    deep.technique = setmetatable({}, { __index = function() return 999999 end })
    deep.techniqueSpent = {}
    p.roster = { deep }
    return p
end

-- The first upgradable item on the shelf carrying a real discipline, as `id, def`.
local function anyDisciplineItem()
    local ids = {}
    for itemId, d in pairs(Item.defs) do
        if d.discipline and Discipline.defs[d.discipline] and Item.isUpgradable(Item.instantiate(itemId)) then
            ids[#ids + 1] = itemId
        end
    end
    table.sort(ids) -- pairs() order is not promised across builds; the spec must pick the same item twice
    return ids[1], ids[1] and Item.defs[ids[1]]
end

return {
    -- -----------------------------------------------------------------------
    -- Materials: two families
    -- -----------------------------------------------------------------------
    {
        name = "craft stock grades on the item's own price, not on how deep the forge rung is",
        fn = function()
            assert(Material.gradeFor({ price = 60 }) == "material_iron_scrap", "cheap stock is scrap")
            assert(Material.gradeFor({ price = 320 }) == "material_steel_ingot", "mid-shelf is steel")
            assert(Material.gradeFor({ price = 900 }) == "material_mythril", "the top of the shelf is mythril")
            -- The grade is a property of the ITEM, so it does not drift as the ladder climbs. This is
            -- what the retired Material.TIER_BY_LEVEL got wrong.
            local sword = Item.instantiate("weapon_iron_sword")
            local deep = Item.instantiate("weapon_iron_sword", 1, 9)
            assert(Material.gradeFor(sword) == Material.gradeFor(deep), "the same blade draws the same stock at +9")
            assert(Material.TIER_BY_LEVEL == nil and Material.forLevel == nil, "the depth ladder is retired")
        end,
    },
    {
        name = "every class has a house stock, and only house stock carries a class",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local id = Material.houseFor(class)
                assert(id, class .. " has no house material")
                assert(Material.get(id), "and its blueprint exists: " .. tostring(id))
                assert(Material.isHouse(id), "which reads as house stock")
            end
            assert(Material.houseFor(nil) == nil, "a classless item wants no house stock")
            for _, m in ipairs(Material.list()) do
                assert(Material.isHouse(m.id) == (m.class ~= nil), m.id .. " must be one family or the other")
            end
        end,
    },

    -- -----------------------------------------------------------------------
    -- The bill
    -- -----------------------------------------------------------------------
    {
        name = "a plain class item bills craft stock by quality plus its own house's stock",
        fn = function()
            local p = richPlayer()
            local sword = Item.instantiate("weapon_iron_sword") -- knight, price 60
            local cost = Forge.upgradeCost(p, sword)
            -- The currency track is its HOUSE's technique, not gold -- a knight blade is forged by
            -- having fought as a knight (models/forge.lua's header).
            assert(cost.level == 1 and cost.gold == 0, "+1 costs no gold")
            assert(cost.technique == Discipline.techniqueCost(1) and cost.techniqueId == "knight",
                "+1 costs a rung of knight technique")
            assert(cost.materials.material_iron_scrap == 2, "and 2 of the grade its price draws on")
            assert(cost.materials[Material.houseFor("knight")] == 1, "plus 1 of the Bastion's stock")
            -- The counts climb with the rung: craft is target+1, house is ceil(target/2).
            local deep = Item.instantiate("weapon_iron_sword", 1, 5)
            local cost6 = Forge.upgradeCost(p, deep)
            assert(cost6.materials.material_iron_scrap == 7, "craft stock is target+1")
            assert(cost6.materials[Material.houseFor("knight")] == 3, "house stock is ceil(target/2)")
        end,
    },
    {
        name = "a discipline item bills EVERY parent house, at double the plain rate",
        fn = function()
            local p = richPlayer()
            -- A multiclass item pays both lines it descends from -- the discipline gate, expressed as a
            -- bill rather than a lock: you cannot forge it deep without having run both houses.
            local id, def
            for itemId, d in pairs(Item.defs) do
                if d.discipline and Discipline.arity(d.discipline) == 2 and d.price
                    and Item.isUpgradable(Item.instantiate(itemId)) then
                    id, def = itemId, d
                    break
                end
            end
            assert(id, "the shelf has at least one upgradable multiclass item")

            local cost = Forge.upgradeCost(p, Item.instantiate(id))
            local parents = Discipline.parents(def.discipline)
            assert(#parents == 2, "a multiclass has two parents")
            for _, parent in ipairs(parents) do
                assert(cost.materials[Material.houseFor(parent)] == 1,
                    id .. " must bill " .. parent .. "'s stock at the plain-class rate x2 (target=1)")
            end
            assert(cost.materials[Material.houseFor(def.class)] == nil
                or Material.houseFor(def.class) == Material.houseFor(parents[1])
                or Material.houseFor(def.class) == Material.houseFor(parents[2]),
                "and bills its own class only through the parent list, never twice over")
        end,
    },
    {
        name = "a classless item bills craft stock only -- no house wants a torch",
        fn = function()
            local p = richPlayer()
            local id
            for itemId, d in pairs(Item.defs) do
                if not d.class and not d.discipline and d.price and Item.isUpgradable(Item.instantiate(itemId)) then
                    id = itemId
                    break
                end
            end
            if not id then return end -- no upgradable classless stock in data
            local cost = Forge.upgradeCost(p, Item.instantiate(id))
            for matId in pairs(cost.materials) do
                assert(not Material.isHouse(matId), id .. " should want no house stock, wanted " .. matId)
            end
        end,
    },

    -- -----------------------------------------------------------------------
    -- The ceiling
    -- -----------------------------------------------------------------------
    {
        name = "a class item's ceiling is the standing of the house that sells it",
        fn = function()
            local p = richPlayer()
            local sword = Item.instantiate("weapon_iron_sword") -- knight -> the Bastion
            assert(Forge.houseVendorFor("knight") == "bastion", "the knight's house is the Bastion")
            assert(Forge.ceilingFor(p, sword) == Vendor.tier(0) + 1, "no quests done -> the opening ceiling")

            -- Run that house's line and the ceiling climbs with it. Only the SPONSORING house counts.
            local done = 0
            for questId, qdef in pairs(Quest.defs) do
                if qdef.sponsor == "bastion" and done < Vendor.TIERS[#Vendor.TIERS] then
                    p.completedQuests[questId] = true
                    done = done + 1
                end
            end
            assert(Quest.sponsorProgress(p, "bastion") == done, "the standing counts this house's quests")
            assert(Forge.ceilingFor(p, sword) > Vendor.tier(0) + 1, "and the ceiling rose with it")
        end,
    },
    {
        name = "discipline stock is billed in TECHNIQUE, not gold, and carries no ceiling",
        fn = function()
            local p = richPlayer()
            local id, def = anyDisciplineItem()
            assert(id, "the shelf has at least one upgradable discipline item")
            local item = Item.instantiate(id)

            -- No ceiling: the price is the brake, and charging a lock on top would be charging twice.
            assert(Forge.ceilingFor(p, item) == Item.MAX_LEVEL, "a discipline item forges to the top")
            assert(Forge.DISCIPLINE_HEAD_START == nil, "the old head-start ceiling is retired")

            local cost = Forge.upgradeCost(p, item)
            assert(cost.gold == 0, "and it costs no gold at all")
            assert(cost.technique == Discipline.techniqueCost(cost.level), "the currency track is technique")
            assert(cost.techniqueId == def.discipline, "billed in its OWN discipline")
            assert(not cost.locked, "never locked -- only unaffordable")

            -- Plain class stock rides the same track, billed to its CLASS instead. The discipline is
            -- preferred where an item has both: a Ninja blade is rogue stock too, and billing it as
            -- rogue would let generic rogue play pay for the deep cut.
            local plain = Item.instantiate("weapon_iron_sword")
            local plainCost = Forge.upgradeCost(p, plain)
            assert(plainCost.gold == 0, "plain stock costs no gold either")
            assert(plainCost.techniqueId == "knight", "it is billed to its own house")
            assert(def.class and def.class ~= def.discipline, "the discipline item carries a class too")
            assert(cost.techniqueId ~= def.class, "and its bill went to the discipline, not that class")
        end,
    },
    {
        name = "technique is billed to the strongest holder alone -- four part-timers cannot pool it",
        fn = function()
            local p = richPlayer()
            local id, def = anyDisciplineItem()
            local item = Item.instantiate(id)
            local cost = Forge.upgradeCost(p, item)
            local need = cost.technique
            -- A second body, because the rule under test is about how a bill reads ACROSS the roster
            -- and a one-character roster cannot express it. Player.new() starts with the avatar alone.
            p.roster[2] = p.roster[2] or require("models.character").instantiate("character_knight")
            assert(p.roster[2], "this test needs two roster bodies")

            -- Split the bill's worth across two characters: each falls short, so the forge refuses --
            -- even though the roster TOTAL is more than enough. This is the whole point of the rule.
            p.roster[1].technique = { [def.discipline] = need - 1 }
            p.roster[1].techniqueSpent = {}
            p.roster[2].technique = { [def.discipline] = need - 1 }
            p.roster[2].techniqueSpent = {}
            assert(Discipline.technique(p, def.discipline) == need - 1, "the read is the max, not the sum")
            local ok, why = Forge.upgrade(p, item)
            assert(ok == nil and why == "technique", "a pooled bill is refused: " .. tostring(why))

            -- Commit one body instead and it pays, off that body only.
            p.roster[1].technique = { [def.discipline] = need + 5 }
            local newItem = Forge.upgrade(p, item)
            assert(newItem and newItem.level == cost.level, "the specialist's bank forges the rung")
            -- Booked as SPENDING, not as a decrement: the earned figure is also the career title and the
            -- level-up reading, so a bill that lowered it would charge growth for gear.
            assert(p.roster[1].technique[def.discipline] == need + 5, "the earned ledger is untouched")
            assert(p.roster[1].techniqueSpent[def.discipline] == need, "the bill was recorded as spent")
            assert(Character.techniqueAvailable(p.roster[1], def.discipline) == 5,
                "and what is left to spend fell by exactly the bill")
            assert(Character.techniqueAvailable(p.roster[2], def.discipline) == need - 1,
                "the other body is untouched")
            assert(p.gold == 100000, "no gold was spent")
        end,
    },
    {
        name = "a classless item has no ceiling at all -- only the materials gate it",
        fn = function()
            local p = richPlayer()
            local id
            for itemId, d in pairs(Item.defs) do
                if not d.class and not d.discipline and Item.isUpgradable(Item.instantiate(itemId)) then
                    id = itemId
                    break
                end
            end
            if not id then return end
            assert(Forge.ceilingFor(p, Item.instantiate(id)) == Item.MAX_LEVEL, id .. " should reach the top")
        end,
    },
    {
        name = "the ceiling never exceeds Item.MAX_LEVEL, whatever the standing or the level",
        fn = function()
            local p = richPlayer()
            for questId in pairs(Quest.defs) do p.completedQuests[questId] = true end
            for _, char in ipairs(p.roster) do
                char.growthBy = {}
                for disciplineId in pairs(Discipline.defs) do char.growthBy[disciplineId] = 99 end
            end
            for id, d in pairs(Item.defs) do
                if Item.isUpgradable(Item.instantiate(id)) then
                    local ceiling = Forge.ceilingFor(p, Item.instantiate(id))
                    assert(ceiling <= Item.MAX_LEVEL, id .. " ceiling " .. ceiling .. " is past the top")
                    assert(ceiling >= 0, id .. " ceiling went negative")
                end
            end
            -- And at the very top there is no bill left to quote.
            local maxed = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            assert(Forge.upgradeCost(p, maxed) == nil, "a fully forged item has no next rung")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Every forgeable thing must actually be payable
    -- -----------------------------------------------------------------------
    {
        name = "every upgradable item quotes a complete bill at every rung it can reach",
        fn = function()
            local p = richPlayer()
            for id in pairs(Item.defs) do
                local probe = Item.instantiate(id)
                if Forge.canWork(probe) then
                    for level = 0, Item.MAX_LEVEL - 1 do
                        local cost = Forge.upgradeCost(p, Item.instantiate(id, 1, level))
                        assert(cost, id .. " quotes no cost at +" .. level)
                        -- EXACTLY ONE currency track, always: gold for plain stock, technique for
                        -- discipline stock. Both would be charging twice for one rung; neither would
                        -- be a free ladder. Pinned over the whole catalogue because the branch that
                        -- picks between them reads `item.discipline`, and a typo'd discipline id on a
                        -- data file would silently fall through to the gold side.
                        assert(cost.gold > 0 or cost.technique > 0, id .. " is free at +" .. level)
                        assert((cost.gold > 0) ~= (cost.technique > 0),
                            id .. " bills two currencies at +" .. level)
                        assert(next(cost.materials), id .. " bills no materials at +" .. level)
                        for matId, n in pairs(cost.materials) do
                            assert(Material.get(matId), id .. " bills an unknown material: " .. tostring(matId))
                            assert(n > 0, id .. " bills a zero count of " .. matId)
                        end
                    end
                end
            end
        end,
    },

    -- -----------------------------------------------------------------------
    -- The batch: several rungs in one commit
    -- -----------------------------------------------------------------------
    {
        name = "a one-rung batch bills exactly what the single-rung bill bills",
        fn = function()
            local p = richPlayer()
            -- The panel prices every climb through costTo, including the ordinary next-rung case, so
            -- the two must not be allowed to drift apart on any item in the catalogue.
            for id in pairs(Item.defs) do
                local probe = Item.instantiate(id)
                if Forge.canWork(probe) then
                    local item = Item.instantiate(id, 1, 3)
                    local one = Forge.upgradeCost(p, item)
                    local batch = Forge.costTo(p, item, 4)
                    assert(batch, id .. " prices no one-rung batch")
                    assert(batch.levels == 1, id .. " counts a one-rung batch as " .. batch.levels)
                    for _, field in ipairs({ "level", "gold", "technique", "techniqueId",
                        "techniqueHeld", "locked", "ceiling" }) do
                        assert(one[field] == batch[field],
                            id .. " disagrees on " .. field .. " between upgradeCost and costTo")
                    end
                    for matId, n in pairs(one.materials) do
                        assert(batch.materials[matId] == n, id .. " disagrees on " .. matId)
                    end
                end
            end
        end,
    },
    {
        name = "a batch costs the sum of the rungs it buys -- convenience, never a discount",
        fn = function()
            local p = richPlayer()
            local item = Item.instantiate("weapon_first_motion", 1, 3)
            local batch = Forge.costTo(p, item, 6)
            assert(batch.levels == 3, "three rungs from +3 to +6, got " .. batch.levels)
            assert(batch.level == 6, "the batch lands at +6")

            local technique, materials = 0, {}
            for lvl = 4, 6 do
                local rung = Forge.upgradeCost(p, Item.instantiate("weapon_first_motion", 1, lvl - 1))
                technique = technique + rung.technique
                for matId, n in pairs(rung.materials) do materials[matId] = (materials[matId] or 0) + n end
            end
            assert(batch.technique == technique,
                "batch technique " .. batch.technique .. " vs summed " .. technique)
            for matId, n in pairs(materials) do
                assert(batch.materials[matId] == n,
                    matId .. ": batch " .. tostring(batch.materials[matId]) .. " vs summed " .. n)
            end
        end,
    },
    {
        name = "technique sums across a batch, but the BANK is not added up with it",
        fn = function()
            local id = anyDisciplineItem()
            if not id then return end
            local p = richPlayer()
            local item = Item.instantiate(id, 1, 0)
            local one = Forge.upgradeCost(p, item)
            local batch = Forge.costTo(p, item, 3)
            assert(batch.technique > one.technique, "three rungs of technique cost more than one")
            -- techniqueHeld is what the strongest holder HAS. Accumulating it per rung would claim
            -- the player is sitting on three times their actual bank and let an unaffordable climb
            -- through the pre-check.
            assert(batch.techniqueHeld == one.techniqueHeld, "the bank is read, not summed")
            assert(batch.gold == 0, "discipline stock never bills gold, batched or not")
        end,
    },
    {
        name = "a batch reaching past the standing ceiling is locked, and names where the wall is",
        fn = function()
            local p = richPlayer()
            local item = Item.instantiate("weapon_first_motion", 1, 0)
            local ceiling = Forge.ceilingFor(p, item)
            assert(ceiling < Item.MAX_LEVEL, "a fresh player has not earned the whole ladder")

            local ok = Forge.costTo(p, item, ceiling)
            assert(not ok.locked, "a climb that stops at the ceiling is payable")
            assert(ok.blockedAt == nil, "and names no wall")

            local over = Forge.costTo(p, item, ceiling + 1)
            assert(over.locked, "one rung past the ceiling is locked")
            assert(over.blockedAt == ceiling + 1,
                "the wall is the first rung past the ceiling, got " .. tostring(over.blockedAt))
        end,
    },
    {
        name = "an unaffordable batch spends NOTHING -- the whole climb is refused before any of it is paid",
        fn = function()
            -- The one failure mode a multi-rung commit introduces that a single rung cannot have:
            -- looping upgrade() and letting it refuse partway leaves gold and materials gone on a
            -- climb the player never got.
            local p = richPlayer()
            local item = Item.instantiate("weapon_first_motion", 1, 0)
            local target = Forge.ceilingFor(p, item)
            assert(target >= 2, "need at least a two-rung climb to test a partial spend")

            local full = Forge.costTo(p, item, target)
            -- Afford every rung but the last. A real ledger rather than the bottomless probe, since
            -- what is under test is the refusal.
            p.roster[1].technique = { [full.techniqueId] = full.technique - 1 }
            p.roster[1].techniqueSpent = {}

            local out, reason = Forge.upgradeTo(p, item, target)
            assert(out == nil, "an unaffordable batch forges nothing")
            assert(reason == "technique", "and says why: " .. tostring(reason))
            assert(Character.techniqueAvailable(p.roster[1], full.techniqueId) == full.technique - 1,
                "and the bank is untouched")
            assert((item.level or 0) == 0, "and the item never moved")
        end,
    },
    {
        name = "an affordable batch lands the item at the target and charges the summed bill once",
        fn = function()
            local p = richPlayer()
            local item = Item.instantiate("weapon_first_motion", 1, 0)
            local target = math.min(3, Forge.ceilingFor(p, item))
            local cost = Forge.costTo(p, item, target)

            -- A real, finite ledger so the charge can be measured against it.
            p.roster[1].technique = { [cost.techniqueId] = cost.technique + 100 }
            p.roster[1].techniqueSpent = {}
            local heldBefore = Character.techniqueAvailable(p.roster[1], cost.techniqueId)

            local out, reason = Forge.upgradeTo(p, item, target)
            assert(out, "the batch forged: " .. tostring(reason))
            assert(reason == nil, "and stopped nowhere short")
            assert(out.level == target, "landing at +" .. target .. ", got +" .. tostring(out.level))
            assert(out.id == item.id, "and it is still the same blade")
            local charged = heldBefore - Character.techniqueAvailable(p.roster[1], cost.techniqueId)
            assert(charged == cost.technique, "charged " .. charged .. ", billed " .. cost.technique)
        end,
    },
    {
        name = "costTo refuses to climb below where the item already stands",
        fn = function()
            local p = richPlayer()
            local item = Item.instantiate("weapon_first_motion", 1, 5)
            assert(Forge.costTo(p, item, 5) == nil, "aiming at the current level buys nothing")
            assert(Forge.costTo(p, item, 3) == nil, "and the ladder does not run backwards")
            local maxed = Item.instantiate("weapon_first_motion", 1, Item.MAX_LEVEL)
            assert(Forge.costTo(p, maxed, Item.MAX_LEVEL) == nil, "a fully forged piece prices nothing")
            local out, reason = Forge.upgradeTo(p, maxed, Item.MAX_LEVEL)
            assert(out == nil and reason == "max level", "and refuses with 'max level'")
        end,
    },
}
