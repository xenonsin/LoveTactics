-- Tests for narrative-choice outcomes (models/story_effect.lua): the declarative `effect` a
-- "Choose..." event applies when a choice is committed. Pure logic, headless. The dialogue-side
-- firing (ui/dialogue.lua's onEffect) is exercised in-window; here we test the applier and that the
-- flight events' authored effects are well-formed.

local StoryEffect = require("models.story_effect")
local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")
local Conversation = require("models.conversation")

-- A fresh player with one character in both the roster (what `restore` walks) and the active party
-- (what `heal`/`maxHpCost` touch), so every effect has a body to act on.
local function freshPlayer()
    local p = Player.new()
    local char = Character.instantiate("character_knight")
    p.roster = { char }
    p.party = { char }
    return p
end

local function health(char) return char.stats.health end

return {
    {
        name = "grant puts an item in the stash (single id and list)",
        fn = function()
            local p = freshPlayer()
            local before = #(p.stash or {})
            StoryEffect.apply({ grant = "consumable_healing_potion" }, p)
            StoryEffect.apply({ grant = { "weapon_iron_bow", "utility_torch" } }, p)
            local ids = {}
            for _, it in ipairs(p.stash) do ids[it.id] = true end
            assert(ids["consumable_healing_potion"], "the single grant landed in the stash")
            assert(ids["weapon_iron_bow"] and ids["utility_torch"], "the list grant landed too")
            assert(#p.stash > before, "the stash grew")
        end,
    },
    {
        name = "gold adds to the purse",
        fn = function()
            local p = freshPlayer()
            local g = p.gold or 0
            StoryEffect.apply({ gold = 50 }, p)
            assert(p.gold == g + 50, "gold was added")
        end,
    },
    {
        name = "restore refills every resource to full",
        fn = function()
            local p = freshPlayer()
            local hp = health(p.party[1])
            hp.current = 1
            StoryEffect.apply({ restore = true }, p)
            assert(hp.current == hp.max, "restore topped health back to max")
        end,
    },
    {
        name = "heal tops up current health but never past max",
        fn = function()
            local p = freshPlayer()
            local hp = health(p.party[1])
            hp.current = hp.max - 5
            StoryEffect.apply({ heal = 3 }, p)
            assert(hp.current == hp.max - 2, "healed by 3")
            StoryEffect.apply({ heal = 999 }, p)
            assert(hp.current == hp.max, "heal clamps at max")
        end,
    },
    {
        name = "maxHpCost shaves the ceiling and drags current down with it",
        fn = function()
            local p = freshPlayer()
            local hp = health(p.party[1])
            local max0 = hp.max
            hp.current = hp.max
            StoryEffect.apply({ maxHpCost = 7 }, p)
            assert(hp.max == max0 - 7, "max health dropped by the cost")
            assert(hp.current <= hp.max, "current is clamped under the new max")
        end,
    },
    {
        name = "flag records a story bit on the player",
        fn = function()
            local p = freshPlayer()
            StoryEffect.apply({ flag = "met_the_survivor" }, p)
            assert(p.flags and p.flags.met_the_survivor == true, "the flag was set")
        end,
    },
    {
        name = "a nil player or nil effect is a safe no-op",
        fn = function()
            StoryEffect.apply(nil, freshPlayer()) -- must not error
            StoryEffect.apply({ gold = 5 }, nil)   -- must not error
        end,
    },
    {
        name = "the flight events' choice effects are well-formed and grant real items",
        fn = function()
            for _, id in ipairs({ "flight_event_shrine", "flight_event_survivor" }) do
                local def = Conversation.defs[id]
                assert(def, "event conversation exists: " .. id)
                local sawEffect = false
                for _, node in ipairs(def.script) do
                    for _, choice in ipairs(node.choices or {}) do
                        if choice.effect then
                            sawEffect = true
                            local e = choice.effect
                            if e.grant then
                                local ids = type(e.grant) == "table" and e.grant or { e.grant }
                                for _, itemId in ipairs(ids) do
                                    assert(Item.instantiate(itemId), id .. ": grant '" .. itemId .. "' is a real item")
                                end
                            end
                            if e.flag then assert(type(e.flag) == "string", id .. ": flag is a string") end
                        end
                    end
                end
                assert(sawEffect, id .. ": at least one choice carries an effect")
            end
        end,
    },
}
