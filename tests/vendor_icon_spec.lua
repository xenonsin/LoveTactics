-- Every house has a mark, and every mark has a house (ui/vendor_icons.lua).
--
-- The mark is how a vendor is named where its NAME does not fit -- a 32px map tile carrying somebody's
-- posted work, a checklist row, a board row. A house with no mark does not fail loudly: the map quietly
-- falls back to the generic writ and three quests from three houses go back to looking identical, which
-- is the exact bug the marks were drawn to fix. So the set is pinned from both ends here.
--
-- Pure table lookups, so it runs headless: ui/vendor_icons.lua touches love.graphics only inside a mark.

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
        name = "every sponsored quest resolves to a house with a mark",
        fn = function()
            -- The board's own path, end to end: a cell carries a quest id and nothing else, so the
            -- marker asks Quest.sponsorOf and then asks the icons. Both hops have to answer for every
            -- piece of work in the data, or a writ somewhere draws the generic scroll.
            local unmarked, checked = {}, 0
            for id, def in pairs(Quest.defs) do
                if def.sponsor then
                    checked = checked + 1
                    assert(Quest.sponsorOf(id) == def.sponsor,
                        "sponsorOf disagrees with the blueprint for " .. id)
                    if not VendorIcons.has(def.sponsor) then unmarked[def.sponsor] = true end
                end
            end
            assert(checked > 0, "no sponsored quests were found to check")
            local ids = {}
            for id in pairs(unmarked) do ids[#ids + 1] = id end
            table.sort(ids)
            assert(#ids == 0, "sponsoring house with no mark: " .. table.concat(ids, ", "))
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
