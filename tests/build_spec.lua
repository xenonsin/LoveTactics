-- Tests for models/build.lua: freezing a player's team and the tactics they wrote for it, so it can
-- be fought while its author is offline.
--
-- The load-bearing claim is that the GAMBITS survive. A build that brings back the right bodies with
-- the right gear and none of the rules is a target dummy wearing somebody's name, so most of what is
-- checked here is that char.aiRules comes back intact and that AI.rulesFor still reads it ahead of
-- the blueprint's own tactics once the character has been rebuilt from data.
--
-- Pure logic, runs headless.

local Build = require("models.build")
local Character = require("models.character")
local Item = require("models.item")
local AI = require("models.ai")

-- A knight with a hand-authored opening: reach for the potion when badly hurt, otherwise swing.
local function authoredKnight()
    local char = Character.instantiate("character_knight")
    char.name = "Vasska"
    char.archetype = "defensive"
    char.autoBattle = true
    char.inventory = {}
    Character.addItem(char, Item.instantiate("weapon_iron_sword"))
    Character.addItem(char, Item.instantiate("consumable_healing_potion"))
    char.aiRules = {
        { enabled = true, priority = "emergency", act = "support",
          item = "consumable_healing_potion", targetPref = "self",
          when = { subject = "self", test = "hp_pct_below", value = 0.4 } },
        { enabled = true, priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "nearest_foe", test = "exists" } },
    }
    return char
end

local function roundTrip(party, meta)
    local snap = Build.from(party, meta)
    local source = Build.encode(snap)
    local decoded = Build.decode(source)
    assert(decoded, "an encoded build should decode")
    return decoded, source
end

return {
    {
        name = "a build carries the team, its gear, and the rules its author wrote",
        fn = function()
            local decoded = roundTrip({ authoredKnight() }, { name = "Keno", prestige = 7 })
            local chars = assert(Build.restore(decoded))

            assert(#chars == 1, "one body in, one body out")
            local char = chars[1]
            assert(char.id == "character_knight", "the right blueprint")
            assert(char.name == "Vasska", "the name its author gave it")
            assert(char.archetype == "defensive", "and the posture they picked")

            assert(char.aiRules and #char.aiRules == 2, "both authored rules survive")
            assert(char.aiRules[1].priority == "emergency", "in their authored order")
            assert(char.aiRules[1].item == "consumable_healing_potion", "naming the item by id")
            assert(char.aiRules[1].when.test == "hp_pct_below", "with the condition intact")
            assert(char.aiRules[1].when.value == 0.4, "and its threshold")
            assert(char.aiRules[2].targetPref == "lowest_hp", "and the second rule's preference")
        end,
    },
    {
        -- The point of the whole feature: the restored body has to actually FIGHT the way it was
        -- taught. AI.rulesFor ranks a player's rules above the blueprint's and the posture's, and
        -- that ranking has to hold for a character rebuilt from data exactly as it does for a live
        -- roster member -- otherwise a build is only cosmetically its author's.
        name = "a restored build's authored rules outrank the blueprint's when the AI reads them",
        fn = function()
            local decoded = roundTrip({ authoredKnight() })
            local char = assert(Build.restore(decoded))[1]

            local merged = AI.rulesFor({ char = char })
            assert(#merged > 0, "the rebuilt character should offer the AI something to read")

            -- The authored emergency rule is the highest-priority thing this character knows, so it
            -- has to come out first however the posture and blueprint layers sort themselves.
            local first = merged[1]
            assert(first.rule.priority == "emergency",
                "the authored emergency rule should lead, got " .. tostring(first.rule.priority))
            assert(first.rule.when.test == "hp_pct_below", "and be the one that was written")

            -- It named an item by id; resolveItem should have found the real one in the kit.
            assert(first.item and first.item.id == "consumable_healing_potion",
                "the named item should resolve against the rebuilt inventory")
            assert(not first.missing, "the item is carried, so the rule is live rather than inert")
        end,
    },
    {
        name = "gear keeps its exact grid cell, because placement is gameplay",
        fn = function()
            local char = Character.instantiate("character_mage")
            char.inventory = {}
            char.inventory[3] = Item.instantiate("weapon_iron_sword")
            char.inventory[7] = Item.instantiate("consumable_healing_potion", 2)

            local decoded = roundTrip({ char })
            local back = assert(Build.restore(decoded))[1]
            assert(back.inventory[3] and back.inventory[3].id == "weapon_iron_sword",
                "cell 3 holds what it held")
            assert(back.inventory[7] and back.inventory[7].id == "consumable_healing_potion",
                "and cell 7 likewise")
            assert(back.inventory[7].quantity == 2, "with its stack size")
        end,
    },
    {
        -- A save salvages what it can, because it is the player's own history. A build is somebody
        -- else's team, and dropping the item their whole opening hung on does not make a slightly
        -- worse opponent -- it makes a different one, still wearing their name.
        name = "an unknown id refuses the build outright rather than quietly leaving it out",
        fn = function()
            local decoded = roundTrip({ authoredKnight() })
            decoded.party[1].inventory[1] = { id = "item_that_was_deleted", quantity = 1 }

            local chars, why = Build.restore(decoded)
            assert(chars == nil, "the build should be refused")
            assert(why and why:find("item_that_was_deleted"),
                "and say which id it could not read: " .. tostring(why))

            local gone = roundTrip({ authoredKnight() })
            gone.party[1].id = "character_who_left"
            local ok2, why2 = Build.restore(gone)
            assert(ok2 == nil and why2 and why2:find("character_who_left"),
                "a missing character is refused the same way")
        end,
    },
    {
        name = "a build from a future version is refused, not guessed at",
        fn = function()
            local decoded = roundTrip({ authoredKnight() })
            decoded.version = Build.VERSION + 1
            local chars, why = Build.restore(decoded)
            assert(chars == nil, "an unreadable version should be refused")
            assert(why and why:find("version"), "and say so: " .. tostring(why))

            local empty = roundTrip({ authoredKnight() })
            empty.party = {}
            assert(Build.restore(empty) == nil, "a build with nobody in it is not a build")
        end,
    },
    {
        -- autoBattle is a preference about who drives YOUR units. Every unit in a restored build is
        -- run by the AI, so carrying the flag across would be meaningless at best.
        name = "the author's auto-battle preference does not travel with their build",
        fn = function()
            local decoded = roundTrip({ authoredKnight() })
            local char = assert(Build.restore(decoded))[1]
            assert(not char.autoBattle, "a restored build never asks to drive itself")
        end,
    },
    {
        -- The encoder is the save file's, which errors rather than writing a function. An authored
        -- rule is scalars all the way down; anything that is not has no business travelling.
        name = "a build refuses to encode anything that is not plain data",
        fn = function()
            local char = authoredKnight()
            char.aiRules[1].whenFn = function() return true end
            local snap = Build.from({ char })
            local ok = pcall(Build.encode, snap)
            assert(not ok, "a closure in a rule should stop the build being written")
        end,
    },
    {
        -- The id is what stops a player being matched against themselves; the name is only for the
        -- card. They are separate fields because over Steam the id wants to be an account, not a
        -- display name somebody can change or share.
        name = "a build knows who made it, so it can be kept away from them",
        fn = function()
            local decoded = roundTrip({ authoredKnight() },
                { author = { id = "steam:76561198000000000", name = "Keno" }, prestige = 7 })
            assert(decoded.author.id == "steam:76561198000000000", "the author's stable id")
            assert(decoded.author.name == "Keno", "and their display name")
            assert(decoded.prestige == 7, "prestige rides along for the card")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Normalization
    --
    -- The only fairness rule: everyone is rebuilt at one level with gear clamped to one ceiling.
    -- There is no prestige bracket, so what a build must NOT carry onto the board is how long its
    -- author has been playing.
    -- -----------------------------------------------------------------------
    {
        name = "a long-played team arrives at the duelling level, not the one it had climbed to",
        fn = function()
            local veteran = authoredKnight()
            veteran.level = 40
            veteran.classUse = { fighter = 30 }

            local chars = assert(Build.restore(roundTrip({ veteran })))
            assert(chars[1].level == Build.NORMAL_LEVEL,
                "expected level " .. Build.NORMAL_LEVEL .. ", got " .. tostring(chars[1].level))
        end,
    },
    {
        name = "an over-forged weapon is clamped, and lesser gear is left as its owner brought it",
        fn = function()
            local char = Character.instantiate("character_knight")
            char.inventory = {}
            char.inventory[1] = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            char.inventory[2] = Item.instantiate("weapon_iron_sword", 1, 1)

            local back = assert(Build.restore(roundTrip({ char })))[1]
            assert(back.inventory[1].level == Build.NORMAL_ITEM_LEVEL,
                "a +10 blade should come down to +" .. Build.NORMAL_ITEM_LEVEL
                    .. ", got +" .. tostring(back.inventory[1].level))
            assert(back.inventory[2].level == 1,
                "a +1 blade is a choice, not a shortfall to be topped up")
        end,
    },
    {
        -- Levels are erased; HOW the character was played is not. The class tally decides which
        -- growth table the rebuild climbs, so two identical blueprints played differently should
        -- arrive at the same level as different characters.
        name = "the class tally survives normalization, so how you played still shows",
        fn = function()
            local function played(tally)
                local c = Character.instantiate("character_knight")
                c.level, c.classUse = 30, tally
                return assert(Build.restore(roundTrip({ c })))[1]
            end
            local brawler = played({ fighter = 25 })
            local scholar = played({ mage = 25 })

            assert(brawler.level == scholar.level, "both arrive at the duelling level")
            local a, b = brawler.stats, scholar.stats
            local differs = a.damage ~= b.damage or a.magicDamage ~= b.magicDamage
                or a.defense ~= b.defense or a.magicDefense ~= b.magicDefense
            assert(differs, "a knight played as a mage should not rebuild identically to a brawler")
        end,
    },
    {
        -- Normalization and cross-machine agreement are the same mechanism: growth is RNG-free and
        -- dominantClass settles ties by name, so (id, classUse, level) is a complete description.
        name = "normalizing the same build twice produces the same character",
        fn = function()
            local snap = roundTrip({ authoredKnight() })
            local a = assert(Build.restore(snap))[1]
            local b = assert(Build.restore(snap))[1]
            for _, stat in ipairs({ "damage", "magicDamage", "defense", "magicDefense", "movement" }) do
                assert(a.stats[stat] == b.stats[stat],
                    stat .. " should rebuild identically (" .. tostring(a.stats[stat])
                        .. " vs " .. tostring(b.stats[stat]) .. ")")
            end
            assert(a.stats.health.max == b.stats.health.max, "and so should the pools")
        end,
    },
    {
        -- The local player's own team gets the identical treatment, or "normalized" would only mean
        -- "the opponent was weakened".
        name = "your own party is flattened on the same terms as the build it faces",
        fn = function()
            local mine = Character.instantiate("character_knight")
            mine.level, mine.classUse = 40, { fighter = 30 }
            mine.inventory = {}
            mine.inventory[1] = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)

            local flat = Build.normalizeParty({ mine })
            assert(flat[1].level == Build.NORMAL_LEVEL, "same level as the opponent")
            assert(flat[1].inventory[1].level == Build.NORMAL_ITEM_LEVEL, "same gear ceiling")

            -- And it is genuinely the same code path: an identical character on either side of the
            -- board should come out identical.
            local theirs = assert(Build.restore(roundTrip({ (function()
                local c = Character.instantiate("character_knight")
                c.level, c.classUse = 40, { fighter = 30 }
                c.inventory = {}
                c.inventory[1] = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
                return c
            end)() })))[1]
            assert(flat[1].stats.damage == theirs.stats.damage,
                "the same character should not fight better from one side of the board")
            assert(flat[1].stats.health.max == theirs.stats.health.max, "nor be tougher")
        end,
    },
}
