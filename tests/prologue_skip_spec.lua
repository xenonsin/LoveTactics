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

-- A loose list (`player.pack` or `player.stash`) as a map of item id -> total quantity held.
local function listCounts(list)
    local counts = {}
    for _, item in ipairs(list or {}) do
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
        -- THE SKIP HAS TO DEAL THE INJURY, AND THEN IT WALKS IT THROUGH THE INN. The Demon Champion
        -- fells Rowan at its last stage, and that one mark is what grows the INN on the plaza
        -- (models/building.lua's `unlockInjury`) -- and Xin is standing inside it. A skip that arrives
        -- whole opens a city with no inn, no healer, and a party of two against an expedition of four,
        -- which is the "broken city rather than a skipped prologue" the whole grant exists to prevent.
        -- Reported from a real play-through of the debug button, not from reading the code.
        --
        -- So the order is the thing this pins, and it is not a formality: INFLICT, then mend. The mark
        -- the door is hung on is one-way (Injury.everInjured) and survives the mending, which is what
        -- lets the button hand over a company that is both whole and standing in a city that has an
        -- inn. Skipping the inflict would shut the door on the room the company just came through.
        name = "a skipped Act 0 takes Rowan's injury through the Inn: door open, bone set, Xin met",
        fn = function()
            local Injury = require("models.injury")
            local Building = require("models.building")
            local p = skipped()

            local rowan, xin
            for _, char in ipairs(p.roster) do
                if char.id == "character_rowan" then rowan = char end
                if char.id == "character_xin" then xin = char end
            end
            assert(rowan, "the skip recruits Rowan")
            assert(Injury.count(p, rowan.id) == 0, "and the Inn sets the bone she was carried out on")
            assert(Injury.everInjured(p), "but the one-way mark the door is hung on outlives the mending")
            assert(xin, "and the room's own scene hands over the healer standing in it")

            local open
            -- The PLAYER, not a prestige number: every deed gate reads the player, and a bare figure
            -- answers none of them (models/building.lua's Building.list).
            for _, b in ipairs(Building.list(p)) do
                if b.id == "cathedral" then open = not b.locked end
            end
            assert(open, "so the Inn stands on the plaza the skip lands in")

            -- The visit is recorded on the room's own ledger, so walking in does not replay a scene
            -- the button already spent -- and cannot hand Xin over twice. (It used to be marked on the
            -- city's shown-door ledger as well; that ledger went with the plaza's coach bubbles.)
            assert(p.flags["intro_cathedral"], "the first-visit scene is marked played")
        end,
    },
    {
        name = "the skip's experience is the level the prologue's four fights pay",
        fn = function()
            -- TWO CLAIMS, AND THEY ARE ABOUT DIFFERENT THINGS. It asked for level 4, which was the
            -- prose in models/experience.lua read off the old triangular table -- whose first levels
            -- cost 10, 20 and 30, so eighty experience bought three of them. The curve is flat now
            -- (FFT's arrangement: a level costs what a floor pays), so what the FIGHTING pays and
            -- what the company LEAVES ON are two questions.
            --
            --   the income   SKIP_XP stands in for what a played Act 0 earns, so the skip cannot
            --                drift off the road it is standing in for.
            --   the exit     prologue.EXIT_LEVEL is the level the Champion leaves the company on,
            --                topped up rather than earned, because four fights land within a whisker
            --                of the line either side of it and a tutorial that never levels anybody
            --                is a tutorial that never shows the level-up panel.
            --
            -- HELD, NOT MEASURED (2026-10-22): every Act 0 fight banks under prologue.xpCap's ceiling,
            -- and a played road (48 to 84 a head) always reaches it -- so the road's income IS the
            -- ceiling, one short of the exit, and the Champion's win is the level-up.
            local level = Experience.levelFor(prologue.SKIP_XP)
            local cap = prologue.xpCap()
            local played = Experience.levelFor(math.min(48, cap.ceiling))
            assert(prologue.SKIP_XP == cap.ceiling and cap.exit == Experience.totalFor(prologue.EXIT_LEVEL),
                "the skip banks the hold, and the hold sits one short of the exit level")
            assert(level == prologue.EXIT_LEVEL - 1, "Act 0's fighting stops a level short of its exit")
            assert(level == played, string.format(
                "the skip lands level %d where a played Act 0 lands %d -- SKIP_XP has drifted off "
                .. "what the road actually pays", level, played))
            assert(prologue.EXIT_LEVEL >= level, string.format(
                "Act 0 ends on level %d, under the %d its own fighting already pays -- the top-up "
                .. "would be taking something away", prologue.EXIT_LEVEL, level))
        end,
    },
    {
        -- THE PLAYED ROAD PAYS THE SAME EXIT, and this is the half the skip cases cannot reach: a
        -- walked Act 0 leaves through prologue.next, which calls prologue.payExit on its way to the
        -- city. What is under test is the payer -- that it tops a company UP to Act 0's exit level
        -- without ever taking anything off one that got there on its own.
        name = "Act 0 leaves every body on its exit level, however the fighting went",
        fn = function()
            local Experience = require("models.experience")

            -- A company that earned nothing at all -- the floor case.
            local green = { roster = {
                { id = "a", name = "Stranger", level = 1, xp = 0 },
                { id = "b", name = "Rowan", level = 1, xp = 0 },
            } }
            prologue.payExit(green)
            for _, char in ipairs(green.roster) do
                assert(Experience.levelFor(char.xp) == prologue.EXIT_LEVEL, string.format(
                    "%s leaves Act 0 at level %d, not the %d the Champion ends on",
                    char.name, Experience.levelFor(char.xp), prologue.EXIT_LEVEL))
            end

            -- IDEMPOTENT, because the skip pays it after its own award and a re-entered prologue
            -- must not hand out a second level.
            local twice = green.roster[1].xp
            prologue.payExit(green)
            assert(green.roster[1].xp == twice, "paying the exit twice paid twice")

            -- ...AND IT IS A FLOOR, NOT A SETTING. A body that out-earned it keeps what it earned --
            -- topping DOWN would make finishing the fights worse than skipping them.
            local rich = Experience.totalFor(prologue.EXIT_LEVEL + 2)
            local veteran = { roster = { { id = "c", name = "Veteran", level = 1, xp = rich } } }
            prologue.payExit(veteran)
            assert(veteran.roster[1].xp == rich,
                "the exit level took experience away from a body that had already passed it")
            assert(veteran.roster[1].level > prologue.EXIT_LEVEL,
                "and it must resolve what that body earned into the levels it bought")
        end,
    },

    {
        -- XIN JOINS ON THE LEVEL ACT 0 ENDS ON, by both doors, and this is a pin rather than a
        -- description: nothing in the game says so directly. It falls out of two rules that are each
        -- true for their own reasons -- Player.recruit seats a newcomer on the roster's MEDIAN
        -- experience, and the company standing there has just been topped up to prologue.EXIT_LEVEL --
        -- and it holds only while the two happen in that order.
        --
        -- WHICH IS AN ORDER ONE EDIT COULD LOSE. `prologue.skip` pays the exit and then walks the Inn's
        -- door (the recruit is the last thing it does); move the door up, above `payExit`, and the
        -- median she inherits is a pair of level-1 bodies and the healer arrives a level down on the
        -- company she is meant to walk out of the gate with -- silently, with every other assertion in
        -- this file still green. The played road has the same shape: the Champion's death pays the exit
        -- (states/game.lua's openExitRoad), and the Inn is two clicks later in the city.
        name = "the healer joins on Act 0's exit level, by the skip and by the played road alike",
        fn = function()
            local Building = require("models.building")
            local Character = require("models.character")

            local xin = Building.defs["cathedral"].grants
            assert(xin, "the Inn is the door she is handed over at")

            -- THE SKIP, exactly as the debug button leaves it.
            local skippedXin
            for _, char in ipairs(skipped().roster) do
                if char.id == xin then skippedXin = char end
            end
            assert(skippedXin, "the skip walks the Inn's door, so she is on the roster")
            assert(skippedXin.level == prologue.EXIT_LEVEL, string.format(
                "the skip seats her at level %d against a company on %d",
                skippedXin.level, prologue.EXIT_LEVEL))

            -- THE PLAYED ROAD: a company off the Champion, meeting her in the city.
            local played = Player.new()
            played.roster = { Character.instantiate("character_avatar") }
            Player.recruit(played, "character_rowan")
            prologue.payExit(played)
            local joined = Player.recruit(played, xin)
            assert(joined and joined.level == prologue.EXIT_LEVEL, string.format(
                "walking into the Inn seats her at level %s, not %d",
                tostring(joined and joined.level), prologue.EXIT_LEVEL))
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
            -- THE LEVEL ACT 0 ENDS ON, read off the prologue rather than named here: the Champion
            -- leaves the company a level up (prologue.EXIT_LEVEL), and the skip owes the same.
            -- Naming the number pinned this case to a curve it has no opinion about, and it did --
            -- it read 4 off the old triangular table.
            for _, char in ipairs(player.roster) do
                assert(char.level == prologue.EXIT_LEVEL, string.format(
                    "%s reaches the gate at level %s, where Act 0 ends on %d",
                    char.name, tostring(char.level), prologue.EXIT_LEVEL))
            end

            -- The join banner Player.recruit queues is dropped: the scene it belonged to was skipped,
            -- and left standing it would fold onto whatever the city opens first.
            assert(#Conversation.pendingJoins == 0, "the skipped join is not left queued")

            -- Every stop's authored loot is in the BAG, as a played road leaves it (Player.findsToPack),
            -- and none of it on the town shelf.
            local counts = listCounts(player.pack)
            local shelved = listCounts(player.stash)
            for _, list in ipairs({ prologue.FLIGHT_QUEST.map.encounters.always,
                                    prologue.FLIGHT_QUEST.map.encounters.prowl or {} }) do
                for _, stop in ipairs(list) do
                    for _, id in ipairs(stop.loot or {}) do
                        assert((counts[id] or 0) > 0, "the road's " .. id .. " is missing from the pack")
                        assert((shelved[id] or 0) == 0, "the road's " .. id .. " was filed in the stash")
                    end
                end
            end
            -- ...and so are the two scene gifts.
            for _, gift in ipairs(prologue.SCENE_GIFTS) do
                assert((counts[gift.item] or 0) > 0, gift.item .. " is missing from the pack")
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
                    assert((counts[step.grant] or 0) == 0 and (shelved[step.grant] or 0) == 0, step.grant
                        .. " was filed loose instead of handed over")
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
        name = "the skip banks no class, and arrives owing the avatar's first pick",
        fn = function()
            -- IT USED TO ESTIMATE ACT 0's TECHNIQUE and file it in the two houses the road is fought in.
            -- Act 0 teaches no class now (2026-10-23: `classCredit = false` on every prologue fight), so
            -- a skip that banked any would be a company the played road never produces.
            local player = skipped()
            local Class = require("models.class")
            for _, char in ipairs(player.roster) do
                for key, amount in pairs(char.technique or {}) do
                    assert(amount == 0, char.name .. " banked " .. amount .. " " .. key .. " in a skipped Act 0")
                end
                for key, n in pairs(char.deeds or {}) do
                    assert(n == 0, char.name .. " banked the deed " .. key .. " in a skipped Act 0")
                end
            end
            -- ...and Rowan's recommendation is owed, exactly as the played road owes it from the arrival
            -- scene on: the city opens on the forced pick (states/hub.lua's openFirstPick).
            assert(player.classPick == true, "the skip must owe the first pick")
            local avatar
            for _, char in ipairs(player.roster) do
                if char.id == Class.AVATAR_ID then avatar = char end
            end
            assert(avatar and Class.pickOwed(player, avatar), "and owe it to the avatar")

            -- No shelf takes trip 0 until it is made; then the picked class's house does.
            local Offer = require("models.offer")
            assert(not Offer.admitted(player, "bastion.shelf"), "trip 0's shelf waits for the pick")
            assert(Class.unlock(player, avatar, "hunter"))
            assert(Offer.openedOn(player, "hunters_lodge.shelf") == 0, "the pick's house opens first")
        end,
    },
}
