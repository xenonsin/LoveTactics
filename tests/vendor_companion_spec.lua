-- THE COMPANION JOINS AT THE COUNTER (models/vendor_visit.lua's joinCompanion).
--
-- Seven houses, seven bodies, and this is the only way six of them reach a company. You meet the
-- companion underground at that house's OPENER -- the errand lying unasked on a floor, which is also
-- what puts the shop on the board -- and they are standing in the shop the first time you walk in.
--
-- The Crossing's pull dealt 1-of-45 for a token and is gone. What this file pins is the replacement,
-- and the three ways it can be wrong: joining a body whose house is still shut, joining twice across a
-- save, and joining somebody nobody authored.

local Errand = require("models.errand")
local Player = require("models.player")
local Vendor = require("models.vendor")
local VendorVisit = require("models.vendor_visit")
local Character = require("models.character")
local Save = require("models.save")

-- Every house that names a companion, which should be all seven with a `class`.
local function houses()
    local out = {}
    for id, def in pairs(Vendor.defs or {}) do
        if def.companion then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

local function holds(player, charId)
    for _, c in ipairs(player.roster or {}) do
        if c.id == charId then return true end
    end
    return false
end

-- A company whose door at `vendorId` is open (or not). The door IS the opener having been run.
local function company(vendorId, doorOpen)
    local p = Player.new()
    p.completedQuests = {}
    if doorOpen then p.completedQuests[Errand.opener(vendorId)] = true end
    return p
end

return {
    {
        -- THE ROSTER IS THE VENDOR TABLE. Every house that trades names its companion, and every one of
        -- those names a body that can actually be built -- a typo here is a house that opens onto
        -- nobody, and nothing else in the game would say so.
        name = "every trading house names a companion that exists",
        fn = function()
            local ids = houses()
            assert(#ids == 7, "seven houses should each name a companion, got " .. #ids)
            local seen = {}
            for _, vendorId in ipairs(ids) do
                local who = Vendor.get(vendorId).companion
                assert(Character.defs[who],
                    vendorId .. " names " .. tostring(who) .. ", which is not a blueprint")
                assert(not seen[who], who .. " is the companion of two houses")
                seen[who] = true
            end
        end,
    },
    {
        -- THE DOOR GATE IS GONE, and this case is what is left of it.
        --
        -- It used to assert that a house whose opener was unrun handed over nobody however often you
        -- walked in -- knowing somebody is not the same as being welcome in their hall. There are no
        -- house doors any more: the seven companions are met and recruited on a floor
        -- (models/errand.lua), and the city keeps one counter that names no companion at all.
        --
        -- What still has to hold is that this route cannot conjure a body out of a shop that has none,
        -- because it is still called on every first visit to every vendor.
        name = "a shop with no companion hands over nobody, however often it is walked into",
        fn = function()
            for vendorId, def in pairs(Vendor.defs) do
                if not def.companion then
                    local p = Player.new()
                    local before = #p.roster
                    assert(VendorVisit.joinCompanion(p, vendorId) == nil,
                        vendorId .. " named nobody but handed somebody over")
                    assert(#p.roster == before, vendorId .. " grew the roster anyway")
                end
            end
        end,
    },
    {
        name = "running the opener puts the companion in the shop, once",
        fn = function()
            local fresh = Player.new()
            local joinedAny = false
            for _, vendorId in ipairs(houses()) do
                local p = company(vendorId, true)
                local who = Vendor.get(vendorId).companion
                local joined = VendorVisit.joinCompanion(p, vendorId)

                if holds(fresh, who) then
                    -- Already sworn by another route (Rowan). The counter has nothing to hand over, and
                    -- must not hand over a second one.
                    assert(joined == nil,
                        vendorId .. " handed over " .. who .. ", who was already in the company")
                else
                    joinedAny = true
                    assert(joined and joined.id == who,
                        vendorId .. " should hand over " .. who .. " once its door is open")
                end
                assert(holds(p, who), who .. " is in the company")

                -- ...and a second walk through the same door is not a second body. Player.recruit
                -- refuses a duplicate outright, so this is belt and braces on a path the greeting can
                -- only take once anyway (Player.hasVisitedVendor).
                assert(VendorVisit.joinCompanion(p, vendorId) == nil,
                    vendorId .. " handed over a second " .. who)
                local n = 0
                for _, c in ipairs(p.roster) do if c.id == who then n = n + 1 end end
                assert(n == 1, who .. " is in the company " .. n .. " times")
            end
            assert(joinedAny, "no house recruits at all -- the counter has stopped being a door in")
        end,
    },
    {
        -- THE GREETING IS THE JOIN. The step list is what states/markets.lua plays, so the wiring that
        -- matters is that the first-visit scene carries the recruit in its `before` -- the companion has
        -- to be in the company before their own lines can play (the scenes are authored for the full
        -- roster through `when = { has = ... }`).
        name = "the first-visit greeting is the beat the body arrives on",
        fn = function()
            local vendorId = "alchemist"
            local who = Vendor.get(vendorId).companion
            local p = company(vendorId, true)

            local steps = VendorVisit.steps(p, vendorId, 0)
            assert(#steps > 0, "an unvisited house owes a greeting")
            assert(steps[1].id == "conversation_" .. vendorId .. "_vendor_intro",
                "the greeting is the first thing said, got " .. tostring(steps[1].id))
            assert(not holds(p, who), "and nobody has joined merely by asking what the shop owes")

            steps[1].before()
            assert(holds(p, who), who .. " joins as the greeting opens, not after it closes")
        end,
    },
    {
        -- ACROSS A SAVE. The visit flag is what stops the greeting replaying, and the roster is what
        -- stops the body arriving twice; both have to survive, or a reload is a second companion.
        name = "the join survives a save, and does not happen again on the other side",
        fn = function()
            local vendorId = "undercroft"
            local who = Vendor.get(vendorId).companion
            local p = company(vendorId, true)
            local steps = VendorVisit.steps(p, vendorId, 0)
            steps[1].before()

            local restored = Save.restore(Save.snapshot(p))
            assert(holds(restored, who), who .. " comes back in the company")
            assert(Player.hasVisitedVendor(restored, vendorId),
                "and the house remembers having been walked into")
            assert(#VendorVisit.steps(restored, vendorId, 0) == 0,
                "so it owes no second greeting")
        end,
    },
}
