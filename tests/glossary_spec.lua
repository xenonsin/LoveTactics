-- Tests for the tooltip glossary (models/glossary.lua + models/keyword.lua): the definitions that
-- ride beside an item tooltip for every status it can inflict and every keyword it declares.
--
-- What matters here is COVERAGE and HONESTY -- that a word the tooltip drops has an entry behind it,
-- that no entry is invented for a keyword the item never declared, and that every keyword id the
-- model can name has a data file to name it from. The drawing is ui/glossary_panel.lua's problem and
-- is covered by the in-game verification pass.

local Glossary = require("models.glossary")
local Keyword = require("models.keyword")
local Status = require("models.status")
local Item = require("models.item")

-- Keywords ride behind a preference that ships OFF (models/settings.lua), so a case that means to
-- read the whole list asks for it outright rather than flipping the player's own setting. Statuses
-- need no such flag -- they are never gated.
local function everything(item, actor, out)
    return Glossary.forItem(item, actor, out, { keywords = true })
end

-- The entry for `id`, or nil. Entries are a flat list, so a linear scan is the lookup.
local function find(entries, id)
    for _, e in ipairs(entries) do
        if e.id == id then return e end
    end
    return nil
end

local function ids(entries)
    local out = {}
    for _, e in ipairs(entries) do out[#out + 1] = e.id end
    return out
end

return {
    {
        name = "every keyword the model can name has a data file behind it",
        fn = function()
            -- Reach the ids through the only door there is: build one item declaring every keyword
            -- field at once and ask what it names. A field renamed in models/keyword.lua without a
            -- matching data/keywords file fails here rather than drawing a blank row in game.
            local item = {
                activeAbility = { aoe = { shape = "square", size = 1 }, frenzy = 0.5, lifesteal = 0.5,
                    requiresSight = true, minRange = 2, windup = { min = 1, max = 3 }, steadfast = true },
                aura = { careful = true, twin = true, preserve = true },
            }
            local named = Keyword.forItem(item)
            assert(#named > 0, "an item declaring every keyword field named none")
            for _, id in ipairs(named) do
                local def = Keyword.defs[id]
                assert(def, "no data/keywords file for " .. id)
                assert(def.name and def.name ~= "", id .. " has no name")
                assert(def.description and def.description ~= "", id .. " has no description")
            end
        end,
    },
    {
        name = "an inert keyword field is not a declaration",
        fn = function()
            -- minRange = 1 is every melee weapon in the game and no dead zone at all; a zero share
            -- adds nothing to a swing. None of the three may put a word in the glossary.
            local item = { activeAbility = { minRange = 1, frenzy = 0, lifesteal = 0 } }
            assert(#Keyword.forItem(item) == 0,
                "inert keyword fields were declared: " .. table.concat(Keyword.forItem(item), ", "))
            local real = { activeAbility = { minRange = 2 } }
            assert(#Keyword.forItem(real) == 1, "minRange = 2 is a dead zone and should be named")
        end,
    },
    {
        name = "a plain item names nothing",
        fn = function()
            local entries = Glossary.forItem({ name = "Rock", type = "utility" })
            assert(#entries == 0, "a bare item produced entries: " .. table.concat(ids(entries), ", "))
        end,
    },
    {
        name = "a status the item applies is defined, with its own badge tint",
        fn = function()
            local item = {
                name = "Test Brand",
                type = "weapon",
                activeAbility = {
                    target = "enemy", range = 1,
                    effect = function(fx) fx.applyStatus(fx.target, "status_burn") end,
                },
            }
            local entries = Glossary.forItem(item)
            local burn = find(entries, "status_burn")
            assert(burn, "the applied status was not defined")
            assert(burn.kind == "status", "expected a status entry, got " .. tostring(burn.kind))
            assert(burn.name == Status.defs.status_burn.name, "the entry renamed the status")
            assert(burn.description == Status.defs.status_burn.description, "the entry rewrote the status")
            assert(burn.color == Status.defs.status_burn.color, "the entry dropped the badge tint")
        end,
    },
    {
        name = "a knockback ability surfaces the Knockback keyword off the dry run",
        fn = function()
            -- Knockback is not a declarative field -- it rides inside the effect closure -- so the
            -- glossary reads it off `out.knockback` the dry run records, not off Keyword.forItem.
            local item = {
                activeAbility = {
                    target = "enemy", range = 1,
                    effect = function(fx) fx.knockback(fx.target, 2) end,
                },
            }
            local kb = find(everything(item), "keyword_knockback")
            assert(kb, "a knockback ability did not surface the Knockback keyword")
            assert(kb.kind == "keyword", "Knockback surfaced as " .. tostring(kb.kind))
            assert(kb.name == "Knockback", "the Knockback entry was renamed to " .. tostring(kb.name))
            -- ...and it stays behind the keyword opt-in, exactly like every declared keyword.
            assert(not find(Glossary.forItem(item), "keyword_knockback"),
                "Knockback surfaced with keywords switched off")
        end,
    },
    {
        name = "a status named twice is defined once",
        fn = function()
            local item = {
                activeAbility = {
                    channelStatus = "status_burn",
                    effect = function(fx) fx.applyStatus(fx.target, "status_burn") end,
                },
            }
            local n = 0
            for _, e in ipairs(Glossary.forItem(item)) do
                if e.id == "status_burn" then n = n + 1 end
            end
            assert(n == 1, "status_burn was defined " .. n .. " times")
        end,
    },
    {
        name = "a shield's brace defines Defending",
        fn = function()
            -- Nothing casts here: the status comes from the wait swap, which no ability dry run sees.
            local entries = Glossary.forItem({ waitBehavior = { kind = "defend", defense = 6 } })
            assert(find(entries, "status_defending"), "the brace's status was not defined")
        end,
    },
    {
        name = "an aura's status is defined by the item carrying the aura",
        fn = function()
            local entries = Glossary.forItem(Item.instantiate("consumable_fire_stone"))
            assert(find(entries, "status_burn"), "the fire stone's aura status was not defined")
        end,
    },
    {
        name = "an incense cloud's status is defined by the item that carries the cloud",
        fn = function()
            -- Nothing casts on a censer/banner: the status rides the hazard laid around the bearer
            -- (item.incense), which no ability dry run sees. The Crimson Standard's own description
            -- says "Grants Bloodsong", so the word must have an entry behind it.
            local entries = Glossary.forItem(Item.instantiate("utility_crimson_standard"))
            assert(find(entries, "status_bloodsong"), "the standard's incense status was not defined")
        end,
    },
    {
        name = "an immunity item defines the status it names",
        fn = function()
            -- The Slipchain reads "Immune to Root and Mired" -- it never inflicts either, but the
            -- tooltip drops both nouns, so the glossary defines them.
            local entries = Glossary.forItem(Item.instantiate("utility_slipchain_charm"))
            assert(find(entries, "status_mired"), "the immunity item's named status was not defined")
            assert(find(entries, "status_root"), "the immunity item's second named status was not defined")
        end,
    },
    {
        name = "statuses lead, keywords follow",
        fn = function()
            local item = {
                activeAbility = {
                    minRange = 3,
                    effect = function(fx) fx.applyStatus(fx.target, "status_burn") end,
                },
            }
            local entries = everything(item)
            assert(#entries >= 2, "expected both a status and a keyword")
            assert(entries[1].kind == "status", "a keyword was read out ahead of a status")
            assert(entries[#entries].kind == "keyword", "the keywords did not close the list")
        end,
    },
    {
        name = "keywords are opt-in, and hiding them never hides a status",
        fn = function()
            -- The same item read both ways. Off is the shipped default (models/settings.lua), and the
            -- point of the option is that turning it off costs the player nothing they NEED: the
            -- statuses the thing inflicts must survive the cut untouched.
            local item = {
                activeAbility = {
                    minRange = 3, requiresSight = true,
                    effect = function(fx) fx.applyStatus(fx.target, "status_burn") end,
                },
            }
            local shown = everything(item)
            local hidden = Glossary.forItem(item, nil, nil, { keywords = false })

            local keywordsShown = 0
            for _, e in ipairs(shown) do
                if e.kind == "keyword" then keywordsShown = keywordsShown + 1 end
            end
            assert(keywordsShown == 2, "expected both declared keywords, got " .. keywordsShown)
            for _, e in ipairs(hidden) do
                assert(e.kind ~= "keyword", "keyword " .. e.id .. " survived being switched off")
            end
            assert(#hidden == 1 and hidden[1].id == "status_burn",
                "switching keywords off changed which statuses are defined")
        end,
    },
    {
        name = "the keyword preference ships off",
        fn = function()
            local Settings = require("models.settings")
            local def
            for _, d in ipairs(Settings.defs) do
                if d.key == "tooltip_keywords" then def = d end
            end
            assert(def, "the tooltip_keywords option is gone from Settings.defs")
            assert(def.default == false, "the keyword glossary must default to off")
            -- And an item read with no opts follows the preference rather than some third default.
            local item = { activeAbility = { minRange = 3 } }
            local followed = #Glossary.forItem(item) > 0
            assert(followed == (Settings.get("tooltip_keywords") and true or false),
                "Glossary.forItem ignored the tooltip_keywords preference")
        end,
    },
    {
        name = "every real item's entries carry a name and a description",
        fn = function()
            -- The whole shelf, since a data file is free to name a status or a trap that was renamed
            -- out from under it. A blank entry is a blank row in the panel, so it fails here.
            local checked = 0
            for id in pairs(Item.defs) do
                local item = Item.instantiate(id)
                for _, e in ipairs(everything(item)) do
                    assert(e.name and e.name ~= "", id .. " names " .. e.id .. ", which has no name")
                    assert(e.description and e.description ~= "",
                        id .. " names " .. e.id .. ", which has no description")
                    checked = checked + 1
                end
            end
            assert(checked > 0, "no item in the game named a status or a keyword")
        end,
    },
}
