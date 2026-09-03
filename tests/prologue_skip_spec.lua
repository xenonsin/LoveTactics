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

            -- The avatar, alone until Bellmere burns, and Rowan sworn in the ash.
            assert(#player.roster == 2, "the prologue ends with a company of two, got " .. #player.roster)
            assert(player.roster[1].id == "character_avatar", "the avatar leads the roster")
            assert(player.roster[2].id == "character_rowan", "Rowan is the second body")
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

            -- The road's purse: the rescue's 40 a head on top of what three fights rolled.
            assert(player.gold > Player.defaults.gold + 80,
                "the road pays more than the rescue alone, got " .. player.gold)

            -- ...and the city opens in free play rather than on the arrival's two scenes.
            assert(player.hubIntro == nil, "the skip does not stage the hub's first-visit intro")
        end,
    },
}
