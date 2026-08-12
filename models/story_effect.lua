-- Declarative outcomes for a narrative choice. A "Choose..." event on the overworld is an ordinary
-- branching conversation (ui/dialogue.lua) whose options carry an `effect`; when the player commits
-- a choice, the widget hands that effect here to be applied against the live player.
--
--   effect = { grant = "consumable_healing_potion" }         -- one item into the stash
--   effect = { grant = { "weapon_iron_bow", "utility_torch" } } -- several
--   effect = { gold = 50 }
--   effect = { restore = true }                               -- refill every resource to full
--   effect = { heal = 12 }                                    -- +HP to the active party (capped)
--   effect = { maxHpCost = 7, grant = "utility_torch" }       -- a cost/benefit tradeoff
--   effect = { flag = "met_the_survivor" }                    -- a story flag for later gating
--   effect = { take = "bastion" }                             -- the Crown's offer, accepted
--   effect = { press = "bastion" }                            -- ...and the companion argued into it
--
-- Fields compose: a single effect may cost, grant, and flag at once (the tradeoff shape). Pure
-- logic, no love.graphics -- headless-testable. See tests/story_effect_spec.lua.
--
-- `take` and `press` are the temptation ledger's two axes and are the only keys here that name a
-- VENDOR rather than an item, a number, or a flag id. They exist as a pair because accepting a bargain
-- and talking your companion into it are different acts with different consequences -- see
-- models/temptation.lua and docs/temptation.md for what the counts come to.

local StoryEffect = {}

-- Nudge a resource stat ({ max, current }) by `delta` on its `field`, keeping current within
-- [0, max]. A no-op on a flat/absent stat, so a member without mana never errors.
local function adjustResource(char, stat, field, delta)
    local r = char.stats and char.stats[stat]
    if type(r) ~= "table" then return end
    r[field] = (r[field] or 0) + delta
    if field == "max" and (r.current or 0) > r.max then r.current = r.max end
    if r.current and r.current < 0 then r.current = 0 end
    if r.current and r.max and r.current > r.max then r.current = r.max end
end

local function eachPartyMember(player, fn)
    for _, char in ipairs((player and player.roster) or {}) do fn(char) end
end

-- Apply one effect table to `player`. Order is cost-then-reward so a `maxHpCost` that would drop a
-- member below 1 is clamped before any heal in the same effect tops them back up.
function StoryEffect.apply(effect, player)
    if not (effect and player) then return end
    local Player = require("models.player")

    -- COST: shave max HP off the whole active party (a shared price, like losing max HP in a roguelite).
    if effect.maxHpCost then
        eachPartyMember(player, function(char) adjustResource(char, "health", "max", -effect.maxHpCost) end)
    end

    -- GRANT: item id or list of ids, each instantiated into the stash (stackables merge).
    if effect.grant then
        local ids = type(effect.grant) == "table" and effect.grant or { effect.grant }
        for _, id in ipairs(ids) do Player.grantItem(player, id) end
    end

    if effect.gold then player.gold = (player.gold or 0) + effect.gold end

    -- RESTORE refills every resource on the whole roster (a rest); HEAL tops up only health, and only
    -- what a party member is missing.
    if effect.restore then Player.restore(player) end
    if effect.heal then
        eachPartyMember(player, function(char) adjustResource(char, "health", "current", effect.heal) end)
    end

    if effect.flag then
        player.flags = player.flags or {}
        player.flags[effect.flag] = true
    end

    -- The temptation ledger. Both keys name the VENDOR whose line the offer belongs to, and a single
    -- choice commonly sets both -- taking a bargain your companion came along for is one act with two
    -- consequences, so it records twice rather than needing a third key for the combination.
    if effect.take then require("models.temptation").record(player, effect.take, "take") end
    if effect.press then require("models.temptation").record(player, effect.press, "press") end
end

return StoryEffect
