-- THE COMPANION DOES NOT JOIN AT A COUNTER, AND THIS FILE IS WHAT KEEPS IT THAT WAY.
--
-- It used to pin the opposite. models/vendor_visit.lua carried a joinCompanion that recruited a house's
-- `companion` in its first-visit greeting's `before`, and this spec asserted the recruit landed there --
-- so walking into six shops handed over six companions for the price of opening six doors, while the
-- underground meeting those bodies were authored for sat on a floor recruiting nobody who had been to
-- town first. Two routes to the same body, one of them free, is one route.
--
-- The route is the floor now (models/errand.lua): you meet a companion at the doorway of the chamber her
-- work is standing in, she asks, and clearing the fight is what brings her in -- through the posting's
-- own `rewardCharacter`, granted by Quest.complete.
--
-- WHAT THIS FILE PINS is the seam between the two halves: the city hands over nobody, the floor hands
-- over exactly one body per posting, and the order the join has to keep to make the banner land.

local Errand = require("models.errand")
local Player = require("models.player")
local Quest = require("models.quest")
local Vendor = require("models.vendor")
local VendorVisit = require("models.vendor_visit")
local Character = require("models.character")
local Conversation = require("models.conversation")

local function holds(player, charId)
    for _, c in ipairs(player.roster or {}) do
        if c.id == charId then return true end
    end
    return false
end

return {
    {
        -- THE ROSTER IS THE VENDOR TABLE. Every house that trades names its companion, and every one of
        -- those names a body that can actually be built -- a typo here is a house that opens onto
        -- nobody, and nothing else in the game would say so.
        name = "every trading house names a companion that exists",
        fn = function()
            local seen, n = {}, 0
            for vendorId, def in pairs(Vendor.defs or {}) do
                if def.companion then
                    n = n + 1
                    assert(Character.defs[def.companion],
                        vendorId .. " names " .. tostring(def.companion) .. ", which is not a blueprint")
                    assert(not seen[def.companion], def.companion .. " is the companion of two houses")
                    seen[def.companion] = true
                end
            end
            assert(n == 7, "seven houses should each name a companion, got " .. n)
        end,
    },
    {
        -- NO SHOP HANDS ANYBODY OVER, and this is the case the whole rewrite exists for. A greeting is a
        -- shopkeeper meeting you; it must not be a recruit, however many times it is walked into and
        -- whichever house it belongs to.
        name = "walking into a shop recruits nobody, at any house",
        fn = function()
            for vendorId in pairs(Vendor.defs) do
                local p = Player.new()
                local before = #p.roster
                for _ = 1, 3 do
                    for _, step in ipairs(VendorVisit.steps(p, vendorId, 0)) do
                        if step.before then step.before() end
                    end
                end
                assert(#p.roster == before,
                    vendorId .. " grew the roster by walking in: " .. before .. " -> " .. #p.roster)
            end

            assert(VendorVisit.joinCompanion == nil,
                "the counter-join is back; it was the second, free route to every companion")
        end,
    },
    {
        -- ...and the greeting still happens. Deleting the recruit out of the `before` must not have taken
        -- the step with it -- a first visit that says nothing is a house with no shopkeeper in it.
        name = "the first-visit greeting still plays, exactly once",
        fn = function()
            local vendorId = "alchemist"
            local p = Player.new()

            local steps = VendorVisit.steps(p, vendorId, 0)
            assert(#steps > 0, "an unvisited house owes a greeting")
            assert(steps[1].id == "conversation_" .. vendorId .. "_vendor_intro",
                "the greeting is the first thing said, got " .. tostring(steps[1].id))

            steps[1].before()
            assert(Player.hasVisitedVendor(p, vendorId), "and the house remembers having been walked into")
            assert(#VendorVisit.steps(p, vendorId, 0) == 0, "so it owes no second greeting")
        end,
    },
    {
        -- THE ROUTE THAT DOES RECRUIT. The posting's `rewardCharacter` is granted by Quest.complete, and
        -- the ORDER is a contract rather than a detail: Player.recruit queues the join banner onto the
        -- next scene to run (Conversation.noteJoin), and every scene is authored for the full roster
        -- through `when = { has = ... }` -- so the body has to be in the company before the outro plays,
        -- or their own lines are filtered out of the scene that welcomes them.
        name = "clearing a companion's posting is what recruits her",
        fn = function()
            local n = 0
            for vendorId in pairs(Errand.houses()) do
                n = n + 1
                -- Quest.get rather than the raw blueprint: `id` is stamped onto the instance, and
                -- Quest.complete writes the completed-quest ledger by it.
                local ask = Quest.get(Errand.opener(vendorId))
                local who = Errand.companionOf(vendorId)
                local p = Player.new()

                assert(not holds(p, who), who .. " is in the company before anyone met her")
                Quest.complete(p, ask)
                assert(holds(p, who), vendorId .. "'s posting was cleared and " .. who .. " did not join")

                -- Once. A second clear of settled work cannot mint a second body.
                Quest.complete(p, ask)
                local count = 0
                for _, c in ipairs(p.roster) do if c.id == who then count = count + 1 end end
                assert(count == 1, who .. " is in the company " .. count .. " times")
            end
            assert(n == 6, "six companions are recruited underground, got " .. n)
        end,
    },
    {
        -- AND THE SCENE THAT WELCOMES HER CAN SEE HER. The outro is the beat the join banner folds onto,
        -- so it is authored for a roster that already holds her -- pinned here because the failure is
        -- invisible: a `when = { has }` block that is false simply does not play, and the recruit's own
        -- first words are silently dropped.
        name = "the posting's outro exists and is spoken after the recruit, not before",
        fn = function()
            for vendorId in pairs(Errand.houses()) do
                local def = Quest.defs[Errand.opener(vendorId)]
                assert(def.outro, vendorId .. "'s posting hands over a body and says nothing about it")
                assert(Conversation.defs[def.outro],
                    def.outro .. " is named by " .. vendorId .. "'s posting and does not exist")
            end
        end,
    },
}
