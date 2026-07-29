-- The universal item contract: a sweep that fires EVERY shipped item and asserts the handful of
-- things that must hold for all of them, whatever the item happens to do.
--
-- This is the other half of tests/item_coverage_spec.lua. That file counts items with a bespoke
-- test; this one gives all 515 a floor nobody has to write by hand. A bespoke case says "Second
-- Wind rises at half health"; these cases say "no item, anywhere, corrupts the board when fired,
-- lies in its preview, or blows up at max forge level" -- claims that are worth far more swept
-- across the whole roster than written out 515 times.
--
-- The invariants, and why each is here:
--
--   1. INSTANTIATION -- every blueprint builds at level 0 and at MAX_LEVEL. A per-level curve with a
--      short row silently resolves to nil and only bites at the forge.
--   2. DRY-RUN PURITY -- previewing an item (aim preview + inventory hover) never changes the board.
--      This class of bug has already shipped once: Fury's preview spent the caster's real health.
--      Swept, it can never come back on any other item.
--   3. FIRING SAFELY -- a cast either happens or is refused with a legible reason; it never raises,
--      never leaves a unit's health outside [0, max], and never loses a unit off the board.
--   4. COST HONESTY -- an item that declares a cost cannot fire for free.
--   5. PASSIVES FOLD -- armor/charms with bonus, resist, or traits attach to a holder without error.
--
-- Pure logic, headless. Fixtures come from tests/support/fixture.lua.

local Item = require("models.item")
local Combat = require("models.combat")
local Character = require("models.character")
local Fixture = require("tests.support.fixture")

-- Every item blueprint as sorted { id, def } pairs, so a failure names the same item every run.
local function eachItem()
    local out = {}
    for id, def in pairs(Item.defs) do out[#out + 1] = { id = id, def = def } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- A board with a caster who can afford anything, a foe, and an ally -- one fixture that can satisfy
-- every `target` kind an ability declares. The caster's grid is emptied and the item under test put
-- in cell 1, so nothing else it happens to carry can answer for it.
--
-- Resources are set absurdly high because this sweep is not about affordability: an item refused for
-- "not enough mana" would be untested rather than tested, and the cost rule has its own case below.
local function bench(itemId)
    local caster = Fixture.unit("character_rowan", 4, 4, {
        isolate = "bare",
        stats = { health = 500, mana = 500, stamina = 500 },
    })
    -- Regen is switched off so a spend cannot be masked by the tick that follows it: a pool sitting
    -- at max would be topped straight back up and every cost would read as free. Mirrors the same
    -- isolation in tests/combat_spec.lua.
    caster.char.stats.staminaRegen = 0
    local foe = Fixture.unit("character_bandit", 4, 5, { isolate = "bare", stats = { health = 500 } })
    local ally = Fixture.unit("character_mage", 3, 4, { isolate = "bare", stats = { health = 500 } })

    local item = Item.instantiate(itemId)
    caster.char.inventory[1] = item

    local combat = Combat.new(Fixture.new(9, 9), { caster, ally }, { foe })
    return combat, combat.units[1], combat.units[3], combat.units[2], item
end

-- Where to aim `ab`, given the bench above. A tile cast is pointed at open ground rather than at a
-- body, since a point placement refuses an occupied cell.
local function aimFor(ab, caster, foe, ally)
    local kind = ab.target
    if kind == "self" then return caster.x, caster.y end
    if kind == "ally" then return ally.x, ally.y end
    if kind == "tile" then return caster.x + 1, caster.y + 1 end
    return foe.x, foe.y -- "enemy", "unit", and anything unlabelled
end

-- A snapshot of everything a dry run must leave alone.
local function snapshot(combat)
    local shot = { clock = combat.clock, units = {} }
    for i, u in ipairs(combat.units) do
        local s = u.char.stats
        shot.units[i] = {
            x = u.x, y = u.y, alive = u.alive, initiative = u.initiative,
            health = s.health and s.health.current,
            mana = s.mana and s.mana.current,
            stamina = s.stamina and s.stamina.current,
            statuses = u.statuses and #u.statuses or 0,
            items = Character.itemCount(u.char),
        }
    end
    return shot
end

-- The first field on which two snapshots disagree, or nil when they match.
local function firstDrift(before, after)
    if before.clock ~= after.clock then
        return "the battle clock moved (" .. tostring(before.clock) .. " -> " .. tostring(after.clock) .. ")"
    end
    for i, b in ipairs(before.units) do
        local a = after.units[i]
        if not a then return "unit " .. i .. " vanished" end
        for _, field in ipairs({ "x", "y", "alive", "initiative", "health", "mana", "stamina",
                                "statuses", "items" }) do
            if b[field] ~= a[field] then
                return "unit " .. i .. "'s " .. field .. " moved ("
                    .. tostring(b[field]) .. " -> " .. tostring(a[field]) .. ")"
            end
        end
    end
    return nil
end

return {
    {
        name = "every item instantiates at level 0 and at max forge level",
        fn = function()
            local items = eachItem()
            assert(#items > 0, "the registry found some items at all")
            for _, it in ipairs(items) do
                for _, level in ipairs({ 0, Item.MAX_LEVEL }) do
                    local ok, err = pcall(Item.instantiate, it.id, 1, level)
                    assert(ok, it.id .. " fails to build at level " .. level .. ": " .. tostring(err))
                end
                local forged = Item.instantiate(it.id, 1, Item.MAX_LEVEL)
                local ab = forged.activeAbility
                if ab and it.def.activeAbility and it.def.activeAbility.damage then
                    assert(type(Combat.abilityMagnitude(ab)) == "number",
                        it.id .. " loses its magnitude when forged to " .. Item.MAX_LEVEL)
                end
            end
        end,
    },
    {
        -- Every per-level row must have one entry per forge level, MAX_LEVEL + 1 of them.
        --
        -- This needs its own case because a short row does NOT raise and does NOT read as nil:
        -- Item.resolveLevel clamps the index to #v, so a truncated curve quietly returns its LAST
        -- entry forever. The item keeps working, the forge keeps taking the player's gold, and the
        -- numbers simply stop climbing partway up -- the kind of bug that is invisible until someone
        -- counts. Counting it is cheap, so it is counted.
        name = "every per-level row covers all forge levels, so no curve stops paying out early",
        fn = function()
            local want = Item.MAX_LEVEL + 1
            local checked = 0
            -- The fields authored as per-level rows, by where they live on a blueprint.
            local function scan(id, where, tbl)
                for key, value in pairs(tbl or {}) do
                    if type(value) == "table" and #value > 0 and type(value[1]) == "number" then
                        checked = checked + 1
                        assert(#value == want, id .. "'s " .. where .. "." .. key .. " has "
                            .. #value .. " entries, expected " .. want .. " (one per forge level)"
                            .. " -- a short row silently repeats its last value forever")
                    end
                end
            end
            for _, it in ipairs(eachItem()) do
                local def = it.def
                scan(it.id, "activeAbility", def.activeAbility)
                scan(it.id, "bonus", def.bonus)
                scan(it.id, "resist", def.resist)
                scan(it.id, "maxBonus", def.maxBonus)
                scan(it.id, "unarmedBonus", def.unarmedBonus)
                scan(it.id, "waitBehavior", def.waitBehavior)
            end
            assert(checked > 100, "only " .. checked .. " per-level rows found -- the scan is wrong")
        end,
    },
    {
        -- The Fury bug, generalised: a preview is a question, not an action.
        name = "previewing any item never changes the board",
        fn = function()
            local swept = 0
            for _, it in ipairs(eachItem()) do
                local ab = it.def.activeAbility
                if ab then
                    swept = swept + 1
                    local combat, caster, foe, ally, item = bench(it.id)
                    local tx, ty = aimFor(ab, caster, foe, ally)

                    local before = snapshot(combat)
                    -- Both dry runs a player can trigger: aiming at a tile, and hovering the slot.
                    pcall(Combat.previewAbility, combat, caster, item, tx, ty)
                    pcall(Combat.abilityOutput, caster, item)
                    local drift = firstDrift(before, snapshot(combat))

                    assert(not drift, it.id .. " changes the board when merely previewed: " .. tostring(drift)
                        .. " -- a preview must be a dry run (see the Fury case in tests/items_spec.lua)")
                end
            end
            assert(swept > 300, "the sweep only reached " .. swept
                .. " active items -- a filter is wrong and this case is passing vacuously")
        end,
    },
    {
        name = "every active item either fires or is refused with a reason, and never corrupts the board",
        fn = function()
            local swept = 0
            for _, it in ipairs(eachItem()) do
                local ab = it.def.activeAbility
                if ab then
                    swept = swept + 1
                    local combat, caster, foe, ally, item = bench(it.id)
                    local tx, ty = aimFor(ab, caster, foe, ally)

                    Fixture.openTurn(combat, caster)
                    local ran, ok, why = pcall(Combat.useItem, combat, caster, item, tx, ty)
                    assert(ran, it.id .. " raised when fired at its own declared target ("
                        .. tostring(ab.target) .. "): " .. tostring(ok))
                    -- A refusal is fine -- plenty of items need conditions this bench cannot stage --
                    -- but it has to SAY why, or the UI has nothing to grey the slot with.
                    if ok == false then
                        assert(type(why) == "string" and why ~= "",
                            it.id .. " refused the cast without giving a reason")
                    end

                    -- Whatever happened, the board must still be coherent.
                    for i, u in ipairs(combat.units) do
                        local hp = u.char.stats.health
                        assert(hp.current >= 0,
                            it.id .. " drove unit " .. i .. " to negative health (" .. hp.current .. ")")
                        assert(hp.current <= Combat.unreservedMax(u.char, "health"),
                            it.id .. " pushed unit " .. i .. " above its health ceiling ("
                                .. hp.current .. " > " .. Combat.unreservedMax(u.char, "health") .. ")")
                        assert(u.x and u.y, it.id .. " left unit " .. i .. " with no position")
                    end
                end
            end
            assert(swept > 300, "the sweep only reached " .. swept
                .. " active items -- a filter is wrong and this case is passing vacuously")
        end,
    },
    {
        -- The claim is that a declared cost is ENFORCED, tested by trying to fire one short of it.
        --
        -- Deliberately not "the pool went down after firing": several items legitimately end the cast
        -- richer than they started. The Cutpurse Knife drains more stamina out of its victim than the
        -- swing costs, on purpose -- "a rogue that keeps knifing the same guard is funded by the man
        -- it is bankrupting". Measuring the net pool would call that a bug. Affordability is the rule
        -- the player actually meets, and no refund or steal can hide it.
        name = "an item that declares a cost cannot be fired without paying it",
        fn = function()
            local swept = 0
            for _, it in ipairs(eachItem()) do
                local ab = it.def.activeAbility
                local cost = ab and ab.cost
                if cost and cost.stat and (cost.amount or 0) > 0 then
                    swept = swept + 1
                    local combat, caster, foe, ally, item = bench(it.id)
                    local tx, ty = aimFor(ab, caster, foe, ally)
                    local pool = caster.char.stats[cost.stat]
                    if type(pool) == "table" then
                        pool.max = math.max(pool.max, cost.amount)
                        pool.current = cost.amount - 1 -- one short: the cast must be refused
                        Fixture.openTurn(combat, caster)
                        local ran, ok, why = pcall(Combat.useItem, combat, caster, item, tx, ty)
                        assert(ran, it.id .. " raised when fired one short of its cost: " .. tostring(ok))
                        assert(ok == false, it.id .. " fired on " .. pool.current .. " "
                            .. cost.stat .. " despite declaring a cost of " .. cost.amount)
                        assert(type(why) == "string" and why ~= "",
                            it.id .. " refused an unaffordable cast without giving a reason")
                    end
                end
            end
            assert(swept > 100, "the sweep only reached " .. swept
                .. " costed items -- a filter is wrong and this case is passing vacuously")
        end,
    },
    {
        name = "every passive item folds onto its holder without error",
        fn = function()
            local swept = 0
            for _, it in ipairs(eachItem()) do
                local def = it.def
                if def.bonus or def.resist or def.traits or def.maxBonus or def.unarmedBonus then
                    swept = swept + 1
                    local holder = Fixture.unit("character_rowan", 2, 2, { isolate = "bare" })
                    holder.char.inventory[1] = Item.instantiate(it.id)
                    local foe = Fixture.unit("character_bandit", 5, 5, { isolate = "bare" })
                    local ran, result = pcall(Fixture.combat, Fixture.new(6, 6), holder, foe)
                    assert(ran, it.id .. " raises when its passive is folded in: " .. tostring(result))

                    local u = result.units[1]
                    assert(u.bonus and u.resist, it.id .. " left the holder with no passive tables")
                    for stat, amount in pairs(u.bonus) do
                        assert(type(amount) == "number",
                            it.id .. " folded a non-number into bonus." .. stat
                                .. " -- a per-level row that never resolved?")
                    end
                    for tag, amount in pairs(u.resist) do
                        assert(type(amount) == "number",
                            it.id .. " folded a non-number into resist." .. tag)
                    end
                end
            end
            assert(swept > 100, "the sweep only reached " .. swept
                .. " passive items -- a filter is wrong and this case is passing vacuously")
        end,
    },
}
