-- THE FIRST WOUND IS TAUGHT ON THE MAP; EVERY ONE AFTER IT IS NOT, AND A WIPE IS NOT EITHER.
--
-- A wound (models/wound.lua) leaves a mark the player has never seen before -- the dark cap on that
-- body's health bar in the overworld party strip -- and from then on the rest of the expedition is
-- being routed by a company that is short of that much. The toast says WHO; it does not say what the
-- mark is. So the very first time anybody is carried out of a fight, states/game.lua pins a coach
-- bubble to that member's row in the strip (game:inflictWounds -> game.drawCoach's "wound" branch).
--
-- A WIPE SKIPS IT, and by construction rather than by a flag: every wipe path wounds and then leaves
-- the map inside the same function, so a bubble pinned to an overworld that is already gone draws
-- nothing. There is nothing left for it to point at either -- a wiped company is standing in a town,
-- and reaching a town sets every bone (models/wound.lua's Wound.clear), so the mark the bubble teaches
-- is not on any bar to be taught. The lesson waits for the first body carried out of a fight the
-- company survives, which is the fight where it means something.
--
-- None of that is reachable from a headless spec -- drawCoach is a love.graphics path hanging off a
-- state that mints fonts at require-time -- so what is pinned here is the three things a rename or a
-- layout change could break silently, each in the place it CAN be checked: the anchor the bubble hangs
-- on, the line it draws, and the gate that arms it once.

local PartyStatus = require("ui.party_status")
local Locale = require("models.locale")
local Conversation = require("models.conversation")

local CONV = "conversation_tutorial_wound"

local function roster(...)
    local out = {}
    for _, id in ipairs({ ... }) do out[#out + 1] = { id = id, name = id, stats = {} } end
    return { roster = out }
end

local function nodeById(def, wanted)
    for _, node in ipairs(def.script or {}) do
        if node.id == wanted then return node end
    end
    return nil
end

return {
    {
        -- THE ANCHOR. The bubble names a BODY, so it hangs off that body's row rather than off the
        -- strip's corner -- which means the strip has to be able to say where a row is, at the origin
        -- the caller drew it at. Stated against PartyStatus.stripHeight rather than against the row
        -- pitch, so a strip laid out differently still passes as long as its rows and its height agree.
        name = "the party strip can point at one member's row, at the origin it was drawn at",
        fn = function()
            local player = roster("character_rowan", "character_kaen", "character_ren")
            local first = PartyStatus.rowRect(player, "character_rowan", 16, 60)
            local second = PartyStatus.rowRect(player, "character_kaen", 16, 60)
            local third = PartyStatus.rowRect(player, "character_ren", 16, 60)
            assert(first and second and third, "every marching member has a row")

            assert(first.x == 16 and first.y == 60, "the first row opens at the origin it was given")
            assert(first.w > 0 and first.h > 0, "a row is a rect the bubble can point at")
            local pitch = second.y - first.y
            assert(pitch > 0, "rows stack downward in roster order")
            assert(third.y - second.y == pitch, "and stack evenly")

            local height = PartyStatus.stripHeight(#player.roster)
            assert(third.y + third.h <= 60 + height,
                "the last row sits inside the height the strip reserves for it")

            -- Somebody who is not in the company has no row, and the caller draws nothing rather than
            -- pointing at whatever happened to be first.
            assert(PartyStatus.rowRect(player, "character_amana", 16, 60) == nil,
                "a body that is not marching has no row")
            assert(PartyStatus.rowRect(player, nil, 16, 60) == nil, "and neither has nobody")
        end,
    },
    {
        -- THE LINE. drawCoach resolves it by node id and draws nothing if the lookup misses, so a
        -- renamed id is a lesson that silently stops happening. Pinned from both ends: the node exists
        -- and resolves through Locale, and the state still asks for it by that name.
        name = "the first-wound coach line exists, and the overworld still asks for it by id",
        fn = function()
            local def = Conversation.defs[CONV]
            assert(def, CONV .. " is missing -- the first wound has nothing to say")
            local node = nodeById(def, "wound_hint")
            assert(node, CONV .. " no longer carries a `wound_hint` node")
            local text = Locale.text(CONV, node)
            assert(type(text) == "string" and #text > 0, "the hint resolves to real text")

            -- IT TEACHES THE MARK, NOT A ROOM. It used to be careful not to name the Inn, which could
            -- not be reached from the map; there is no Inn now and no building anywhere that sets a
            -- bone (models/wound.lua), so a line pointing at one would be sending the player to a door
            -- that does not exist. The rule is unchanged and the reason got stronger.
            assert(not text:lower():find("inn", 1, true),
                "the map's line must not send the player to a door they cannot walk to")
            -- ...and it must say what a wound actually is now, which is a thing with an END: held until
            -- the company is above ground, or until a camp is spent binding it. A line that still reads
            -- "nothing will fill it again" is describing the permanent ledger this design replaced.
            assert(text:lower():find("above ground", 1, true) or text:lower():find("bind", 1, true),
                "the line no longer tells the player how a wound ends")

            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            assert(src:find('hintNode("' .. CONV .. '", "wound_hint")', 1, true),
                "states/game.lua no longer draws the first-wound hint by that id")
        end,
    },
    {
        -- THE GATE. One lesson, ever: armed off Wound.everWounded read BEFORE the ledger moves, since
        -- Wound.inflict is what writes that one-way mark. Read against the source because the arming
        -- lives in a state method that cannot be loaded headless.
        name = "the wound coach is armed once, off the mark that is only unset the first time",
        fn = function()
            local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")
            local from = src:find("function game:inflictWounds", 1, true)
            assert(from, "nothing inflicts wounds on the map any more -- retarget this case")
            local to = src:find("\nfunction ", from + 1)
            local body = src:sub(from, to or #src)

            assert(body:find('game.coach = "wound"', 1, true),
                "the first wound no longer arms the overworld lesson")
            local mark = body:find("Wound.everWounded", 1, true)
            assert(mark, "the lesson is no longer gated on the ever-wounded mark -- it would fire every fight")
            assert(mark < body:find('game.coach = "wound"', 1, true),
                "the mark must be read before Wound.inflict writes it, or the answer is never 'never'")
        end,
    },
}
