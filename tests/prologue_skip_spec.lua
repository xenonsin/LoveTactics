-- Tests the DEBUG SKIP of Act 0 (states/prologue.lua's `skip`, reached from the debug column in
-- states/menu.lua). The skip exists so the city can be opened without playing the prologue, which means
-- its only job is to leave the player holding what the prologue would have handed them -- so what is
-- pinned here is the agreement between the two, not the mechanics of either.
--
-- Most of the grant is DERIVED (the route's own stops, the encounter blueprints' rescue purses) and
-- cannot drift. The two authored pieces can, and each has a source to be checked against: the scene
-- gifts against the conversations that carry them, the experience against models/experience.lua's
-- curve. Both are checked below.
--
-- Headless and pure: the skip touches no love.graphics (Player.applyAvatarBody goes through
-- models/sprite.lua, which resolves a missing image to its path).

local Player = require("models.player")
local Item = require("models.item")
local Experience = require("models.experience")
local Conversation = require("models.conversation")
local prologue = require("states.prologue")

-- Every item id a branch of `sceneId` grants, as a set. A choice's effect may name one id or a list
-- (models/story_effect.lua).
local function grantsIn(sceneId)
    local out = {}
    local def = Conversation.defs[sceneId]
    for _, node in ipairs((def and def.script) or {}) do
        for _, choice in ipairs(node.choices or {}) do
            local grant = choice.effect and choice.effect.grant
            if type(grant) == "string" then out[grant] = true end
            for _, id in ipairs(type(grant) == "table" and grant or {}) do out[id] = true end
        end
    end
    return out
end

-- The stash as a map of item id -> total quantity held.
local function stashCounts(player)
    local counts = {}
    for _, item in ipairs(player.stash or {}) do
        counts[item.id] = (counts[item.id] or 0) + (item.quantity or 1)
    end
    return counts
end

-- A fresh player with Act 0 skipped -- the state the debug button drops into the hub with.
local function skipped()
    local player = Player.new()
    prologue.skip(player)
    return player
end

return {
    {
        -- THE SKIP HAS TO DEAL THE WOUND, AND THEN IT WALKS IT THROUGH THE INN. The Demon Champion
        -- fells Rowan at its last stage, and that one mark is what grows the INN on the plaza
        -- (models/building.lua's `unlockWound`) -- and Xin is standing inside it. A skip that arrives
        -- whole opens a city with no inn, no healer, and a party of two against an expedition of four,
        -- which is the "broken city rather than a skipped prologue" the whole grant exists to prevent.
        -- Reported from a real play-through of the debug button, not from reading the code.
        --
        -- So the order is the thing this pins, and it is not a formality: INFLICT, then mend. The mark
        -- the door is hung on is one-way (Wound.everWounded) and survives the mending, which is what
        -- lets the button hand over a company that is both whole and standing in a city that has an
        -- inn. Skipping the inflict would shut the door on the room the company just came through.
        name = "a skipped Act 0 takes Rowan's wound through the Inn: door open, bone set, Xin met",
        fn = function()
            local Wound = require("models.wound")
            local Building = require("models.building")
            local p = skipped()

            local rowan, xin
            for _, char in ipairs(p.roster) do
                if char.id == "character_rowan" then rowan = char end
                if char.id == "character_xin" then xin = char end
            end
            assert(rowan, "the skip recruits Rowan")
            assert(Wound.count(p, rowan.id) == 0, "and the Inn sets the bone she was carried out on")
            assert(Wound.everWounded(p), "but the one-way mark the door is hung on outlives the mending")
            assert(xin, "and the room's own scene hands over the healer standing in it")

            local open
            -- The PLAYER, not a prestige number: every deed gate reads the player, and a bare figure
            -- answers none of them (models/building.lua's Building.list).
            for _, b in ipairs(Building.list(p)) do
                if b.id == "the_ward" then open = not b.locked end
            end
            assert(open, "so the Inn stands on the plaza the skip lands in")

            -- The visit is recorded on both of the room's ledgers, so walking in does not replay a
            -- scene the button already spent -- and cannot hand Xin over twice.
            assert(p.flags["intro_the_ward"], "the first-visit scene is marked played")
            assert(Building.seenDoor(p, "the_ward"), "and the card is marked walked into")
        end,
    },
    {
        -- THE ROOM'S SCENE IS NOT THE CARD'S ANNOUNCEMENT, and this pins the bug that conflating them
        -- caused. hub.enter seeds `seenDoors` wholesale on the first visit -- every door already open is
        -- recorded as announced, so nothing standing is ever coached as news (Building.seedSeen). The
        -- Ward is open on that very first frame, because Rowan is hurt before the city exists. So a
        -- first-visit scene keyed on seenDoor was consumed before anyone could walk through the door,
        -- and Xin was never met by ANY player, skipped prologue or played one.
        --
        -- THE PLAYED ARRIVAL IS WHAT THIS STANDS ON NOW, built by hand rather than by skipped(): the
        -- debug button walks the Inn's door itself and spends the scene deliberately (states/prologue.lua),
        -- so it can no longer stand in for a company that has one still owed. The mark is all the
        -- precondition needs -- it is what opens the card that gets seeded.
        name = "seeding the city's doors does not spend the Ward's first-visit scene",
        fn = function()
            local Building = require("models.building")
            local p = Player.new()
            p.wounded = true
            Building.seedSeen(p)
            assert(Building.seenDoor(p, "the_ward"),
                "precondition: the seed does mark it announced, which is what broke this")
            assert(not (p.flags or {})["intro_the_ward"],
                "but the scene is a separate ledger and is still owed")

            local def = Building.defs["the_ward"]
            assert(def.intro and def.grants == "character_xin",
                "...and it is the scene that hands the companion over, so spending it early loses her")
        end,
    },
    {
        name = "the skip's experience is the level the prologue's four fights pay",
        fn = function()
            -- models/experience.lua states it in prose from the other end: "around eighty a head, which
            -- is level 4 here". If the curve is ever retuned, this is what says the skip moved with it.
            local level = Experience.levelFor(prologue.SKIP_XP)
            assert(level == 4, "Act 0 pays a body to level 4, got " .. level)
        end,
    },
    {
        name = "every scene gift is an item a branch of the scene it names really grants",
        fn = function()
            assert(#prologue.SCENE_GIFTS == 2, "the flight has two Choose... stops, listed "
                .. #prologue.SCENE_GIFTS)
            for _, gift in ipairs(prologue.SCENE_GIFTS) do
                assert(Item.defs[gift.item], "unknown gift item " .. tostring(gift.item))
                assert(Conversation.defs[gift.from], "unknown scene " .. tostring(gift.from))
                assert(grantsIn(gift.from)[gift.item],
                    gift.from .. " has no branch granting " .. gift.item)
            end
        end,
    },
    {
        name = "skipping Act 0 leaves the company the prologue would have walked into the city",
        fn = function()
            local player = skipped()

            -- The avatar, Rowan met on the first job, and Xin out of the Inn's door -- which Act 0
            -- does not itself contain, but the two clicks after it do (see the first case).
            assert(#player.roster == 3, "the skip lands a company of three, got " .. #player.roster)
            assert(player.roster[1].id == "character_avatar", "the avatar leads the roster")
            assert(player.roster[2].id == "character_rowan", "Rowan is the second body")
            assert(player.roster[3].id == "character_xin", "and Xin joins out of the Inn")
            for _, char in ipairs(player.roster) do
                assert(char.level == 4, char.name .. " reaches the gate at level 4, got "
                    .. tostring(char.level))
            end

            -- The join banner Player.recruit queues is dropped: the scene it belonged to was skipped,
            -- and left standing it would fold onto whatever the city opens first.
            assert(#Conversation.pendingJoins == 0, "the skipped join is not left queued")

            -- Every stop's authored loot is in the stash.
            local counts = stashCounts(player)
            for _, stop in ipairs(prologue.FLIGHT_QUEST.map.encounters.always) do
                for _, id in ipairs(stop.loot or {}) do
                    assert((counts[id] or 0) > 0, "the road's " .. id .. " is missing from the stash")
                end
            end
            -- ...and so are the two scene gifts.
            for _, gift in ipairs(prologue.SCENE_GIFTS) do
                assert((counts[gift.item] or 0) > 0, gift.item .. " is missing from the stash")
            end
            -- The teaching chest's three potions, plus one per survivor walked out of the valley
            -- (data/encounters/encounter_survivors_defend.lua prices its purse per head).
            assert((counts.consumable_healing_potion or 0) >= 5,
                "the chest's three potions and the two rescued survivors' one each, got "
                .. tostring(counts.consumable_healing_potion))

            -- ...and what Rowan hands over during the village fight is on the AVATAR'S GRID, not in the stash:
            -- the village lesson grants straight into the inventory and the abilities stay there
            -- after the fight (data/tutorials/village.lua, states/battle.lua's grantLessonItem).
            local Tutorial = require("models.tutorial")
            local Character = require("models.character")
            local grid = {}
            for _, item in ipairs(Character.eachItem(player.roster[1])) do grid[item.id] = true end
            local granted = 0
            for _, step in ipairs(Tutorial.defs[prologue.VILLAGE_MAP.tutorial].steps) do
                if step.grant and step.actor == "character_avatar" then
                    granted = granted + 1
                    assert(grid[step.grant], "the village lesson's " .. step.grant
                        .. " is not in the avatar's grid")
                    assert((counts[step.grant] or 0) == 0, step.grant
                        .. " was filed in the stash instead of handed over")
                end
            end
            assert(granted == 2, "the village lesson hands the avatar two abilities, found " .. granted)

            -- The flag the survivor's scene sets on either branch.
            assert(player.flags.met_the_survivor, "the survivor was met")

            -- The road's purse: the rescue's 40 a head on top of what three fights rolled. Still gold,
            -- and this is the case that says so -- the prologue is campaign ground, not a descent floor,
            -- and a fight pays the purse of the place it was fought in (models/spoils.lua). If the
            -- rolled half ever moved to scrip here, the prologue's three fights would hand over a number
            -- with nothing to spend it on and no exit to burn it at, and this assertion is what would
            -- catch it: the total would land on exactly the rescue's 80 and go no further.
            assert(player.gold > Player.defaults.gold + 80,
                "the road pays more than the rescue alone, got " .. player.gold)

            -- ...and the city opens in free play rather than on the arrival's two scenes.
            assert(player.hubIntro == nil, "the skip does not stage the hub's first-visit intro")
        end,
    },
    {
        name = "the skip's technique opens the two houses Act 0 is fought in, and no others",
        fn = function()
            local player = skipped()
            local Class = require("models.class")
            local Building = require("models.building")
            local Character = require("models.character")

            -- The company arrives having SWUNG two houses: Rowan is declared knight and the avatar's
            -- starting sword is the Bastion's shelf, while the avatar's own badge is fighter
            -- (Growth.NEUTRAL_CLASS -- it declares no class). Level 1 is what a house door asks for.
            for _, class in ipairs({ "knight", "fighter" }) do
                assert(Class.rosterLevel(player, class) >= 1,
                    "Act 0 is fought in " .. class .. ", and the company arrives at class level "
                    .. Class.rosterLevel(player, class))
            end

            -- The road hands over an opener for all seven classes, which is not the same as having cast
            -- them: the other five houses are still shut, exactly as a PLAYED Act 0 leaves them.
            local open = 0
            for _, def in pairs(Building.defs) do
                if def.unlockClassLevel then
                    local vendor = require("models.vendor").defs[def.vendor]
                    local class = vendor and vendor.class
                    if class and Class.rosterLevel(player, class) >= def.unlockClassLevel then
                        open = open + 1
                    end
                end
            end
            assert(open == 2, "two of the seven houses open on a skipped Act 0, got " .. open)

            -- Nothing is banked above what the fights could physically have paid: the per-fight ceiling
            -- a real fight enforces, over the four fights the road holds.
            local ceiling = 4 * Class.TECHNIQUE_PER_BATTLE
            for _, char in ipairs(player.roster) do
                for key, amount in pairs(char.technique or {}) do
                    assert(amount <= ceiling, char.name .. " banked " .. amount .. " " .. key
                        .. ", over what four fights can pay (" .. ceiling .. ")")
                end
                -- The level already landed, so the level-up reading is caught up rather than sitting on
                -- a fight's worth of progress the company has not made since (Growth.resolve's snapshot).
                for key in pairs(char.technique or {}) do
                    assert(Character.techniqueSinceLevel(char, key) == 0,
                        char.name .. " reaches the city owing a level-up in " .. key)
                end
            end
        end,
    },
}
