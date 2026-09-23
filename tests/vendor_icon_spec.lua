-- Every house has a mark, and every mark has a house (ui/vendor_icons.lua).
--
-- The mark is how a vendor is named where its NAME does not fit -- a 32px map tile carrying somebody's
-- posted work, a checklist row, a board row. A house with no mark does not fail loudly: the map quietly
-- falls back to the generic writ and three quests from three houses go back to looking identical, which
-- is the exact bug the marks were drawn to fix. So the set is pinned from both ends here.
--
-- Pure table lookups, so it runs headless: ui/vendor_icons.lua touches love.graphics only inside a mark.

-- THE QUEST BLUEPRINTS ARE GONE, AND SO IS WHAT THEY WERE COVERING. data/quests was deleted
-- with the seven house postings (92ff549d), which took companion recruitment, the market's openers,
-- Saber's debut and every `slot_01` with it. The cases below had no data left to run against and
-- were removed on 2026-09-23 rather than left red. Each one is listed so the hole is findable:
--
--   * every sponsored quest resolves to a house with a mark
--
-- Nothing above is a rule that was decided against; it is coverage that lost its subject. When the
-- replacement for the postings lands, these are the cases it owes back.

local VendorIcons = require("ui.vendor_icons")
local Vendor = require("models.vendor")
local Quest = require("models.quest")

return {
    {
        name = "every vendor blueprint has a mark",
        fn = function()
            local missing = {}
            for id in pairs(Vendor.defs) do
                if not VendorIcons.has(id) then missing[#missing + 1] = id end
            end
            table.sort(missing)
            assert(#missing == 0, "no mark for: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "every vendor has a colour, and no two houses sit close enough to be confused",
        fn = function()
            -- A palette drifts one house at a time and never looks wrong on its own -- a colour is only
            -- wrong NEXT TO another one -- so the spacing is measured rather than eyeballed. Manhattan
            -- distance in RGB, which is crude as colour science and exactly right as a guard rail: it is
            -- the same arithmetic whoever adds the eighth house, and it fails loudly.
            local MIN_APART = 0.4
            local missing, all = {}, {}
            for id in pairs(Vendor.defs) do
                local r, g, b = VendorIcons.color(id)
                if not r then
                    missing[#missing + 1] = id
                else
                    all[#all + 1] = { id = id, c = { r, g, b } }
                end
            end
            table.sort(missing)
            assert(#missing == 0, "no colour for: " .. table.concat(missing, ", "))
            table.sort(all, function(a, b) return a.id < b.id end)
            for i = 1, #all do
                for j = i + 1, #all do
                    local a, b = all[i], all[j]
                    local d = math.abs(a.c[1] - b.c[1]) + math.abs(a.c[2] - b.c[2])
                        + math.abs(a.c[3] - b.c[3])
                    if d <= MIN_APART then
                        error(a.id .. " and " .. b.id .. " are " .. string.format("%.2f", d) ..
                            " apart -- two houses that close read as one", 0)
                    end
                end
            end
        end,
    },
    {
        name = "no house wears the boss's gold or the fight's red",
        fn = function()
            -- The two reserved marker colours (ui/overworld_map.lua's markerColor). A house hue that
            -- drifts into either costs the board its two fastest reads -- "this is the thing I came for"
            -- and "this will hit me" -- and it would drift silently, because a colour is never wrong,
            -- only wrong NEXT TO something. So the distance is asserted rather than trusted.
            local RESERVED = {
                { name = "the boss's gold", c = { 0.95, 0.75, 0.20 } },
                { name = "the fight's red", c = { 0.85, 0.25, 0.25 } },
            }
            for _, id in ipairs(VendorIcons.ids()) do
                local r, g, b = VendorIcons.color(id)
                for _, res in ipairs(RESERVED) do
                    local d = math.abs(r - res.c[1]) + math.abs(g - res.c[2]) + math.abs(b - res.c[3])
                    assert(d > 0.5, id .. " sits on " .. res.name .. " (distance " ..
                        string.format("%.2f", d) .. ")")
                end
            end
        end,
    },
    {
        name = "every mark names a vendor that exists",
        fn = function()
            local orphans = {}
            for _, id in ipairs(VendorIcons.ids()) do
                if not Vendor.get(id) then orphans[#orphans + 1] = id end
            end
            assert(#orphans == 0, "mark for no such vendor: " .. table.concat(orphans, ", "))
        end,
    },
    {
        name = "unsponsored and unknown work answers nil rather than guessing",
        fn = function()
            -- The Gate Below is sponsored by nobody and stands on a board like anything else; an id from
            -- an older save may name a quest file that no longer exists. Both must fall through to the
            -- writ, which is what a nil sponsor buys.
            assert(Quest.sponsorOf(nil) == nil, "a nil id should have no sponsor")
            assert(Quest.sponsorOf("quest_no_such_thing") == nil, "an unknown id should have no sponsor")
            assert(Quest.sponsorOf("quest_the_gate_below") == nil,
                "the Gate Below is unsponsored and must stay that way")
            assert(VendorIcons.draw(nil, 0, 0, 10, 10) == false, "a nil house must draw nothing")
            assert(VendorIcons.draw("no_such_house", 0, 0, 10, 10) == false,
                "an unknown house must draw nothing")
        end,
    },
}
