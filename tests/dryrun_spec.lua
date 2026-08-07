-- Every item's effect must SURVIVE both dry runs.
--
-- Combat.abilityOutput (the shop/inventory tooltip) and Combat.previewAbility (the board preview you
-- see while aiming) each replay the real effect(fx) against a table of inert helpers. Both wrap it in
-- pcall, which is right -- a data quirk must never crash a hover -- but it also means a MISSING helper
-- is silent: the effect throws while it is still assembling its arguments, the dry run returns what it
-- had built so far, and the ability describes itself as doing nothing at all. Nothing goes red. The
-- tooltip just goes quiet, and only for the items that use the helper nobody added.
--
-- That has now happened twice. fx.dispelUnit was live-only, and Sentence and The Question previewed as
-- nothing until it was noticed. This spec is the standing answer: it calls both dry runs on every item
-- in the game with the pcall PEELED OFF, so the next helper somebody forgets fails here, by name,
-- instead of in a shop three months later.

local Item = require("models.item")
local Combat = require("models.combat")

-- The same stand-ins the dry runs build for themselves, near enough to drive an effect.
local function standIn(side)
    return {
        char = { name = "stand-in", stats = { health = { max = 100, current = 100 },
            damage = 10, magicDamage = 10, defense = 0, magicDefense = 0 }, inventory = {} },
        x = 0, y = 0, alive = true, side = side or "party", initiative = 0, statuses = {},
        bonus = {}, resist = {},
    }
end

-- Run `effect` against the helper table the dry run WOULD hand it, without the pcall, and report the
-- error rather than swallowing it. Reaches the table by calling the real dry run first (so the two can
-- never drift), then replaying the effect against the fx it built.
local function faults(runner, item)
    local ok, err = true, nil
    local ab = item.activeAbility
    if not (ab and ab.effect) then return nil end

    -- Peel the pcall: temporarily stand in for it so the dry run's own call reports rather than eats.
    local realPcall = pcall
    local caught
    _G.pcall = function(fn, ...)
        local r = { realPcall(fn, ...) }
        if not r[1] then caught = r[2] end
        return unpack(r)
    end
    realPcall(runner)
    _G.pcall = realPcall
    return caught
end

return {
    {
        name = "every item's effect survives the tooltip dry run (Combat.abilityOutput)",
        fn = function()
            local broken = {}
            for id in pairs(Item.defs) do
                local item = Item.instantiate(id, 1, 0)
                if item and item.activeAbility and item.activeAbility.effect then
                    local err = faults(function()
                        Combat.abilityOutput(standIn("party"), item)
                    end, item)
                    if err then broken[#broken + 1] = id .. ": " .. tostring(err) end
                end
            end
            table.sort(broken)
            assert(#broken == 0, #broken .. " item effect(s) fault in the tooltip dry run:\n         "
                .. table.concat(broken, "\n         "))
        end,
    },
    {
        name = "every item's effect survives the board preview (Combat.previewAbility)",
        fn = function()
            local Fixture = require("tests.support.fixture")
            local broken = {}
            for id in pairs(Item.defs) do
                local item = Item.instantiate(id, 1, 0)
                if item and item.activeAbility and item.activeAbility.effect then
                    local combat = Fixture.combat({
                        { id = "character_avatar", x = 1, y = 1, side = "party" },
                        { id = "character_bandit", x = 2, y = 1, side = "enemy" },
                    })
                    local caster = combat.units[1]
                    local err = faults(function()
                        Combat.previewAbility(combat, caster, item, 2, 1)
                    end, item)
                    if err then broken[#broken + 1] = id .. ": " .. tostring(err) end
                end
            end
            table.sort(broken)
            assert(#broken == 0, #broken .. " item effect(s) fault in the board preview:\n         "
                .. table.concat(broken, "\n         "))
        end,
    },
}
