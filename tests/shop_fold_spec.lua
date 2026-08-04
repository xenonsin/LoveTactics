-- The vendor shelf's FOLDS: ui/panels/shop.lua bands its Buy list per discipline, and each band opens
-- and shuts. A locked path starts shut (its stock is unbuyable to the last row, and a shelf listing
-- every path its house touches runs many screens deep), but shut is a default and not a verdict -- the
-- locked stock is the whole argument for earning the path, so the player must be able to open one and
-- read it. This pins both halves: the default, and that a hand-set fold overrides it either way.
--
-- Only the row-building half is exercised. Shop.new bakes fonts, so panels are built straight through
-- the metatable with the fields buildBuyRows actually reads -- the same trick loadout_filter_spec uses.

local Shop = require("ui.panels.shop")
local Vendor = require("models.vendor")
local Discipline = require("models.discipline")

-- A shelf built for `vendorId` as seen by a player who has finished nothing: no quests, so every
-- discipline this house touches is still locked.
local function shelf(vendorId, folded)
    local panel = setmetatable({
        player = { completedQuests = {}, recipes = {}, gold = 0, stash = {} },
        vendorId = vendorId,
        def = Vendor.get(vendorId) or {},
        questsDone = 0,
        folded = folded or {},
        rows = {},
    }, Shop)
    panel:buildBuyRows()
    return panel
end

-- The rows grouped the way the list reads them: each header with the item rows that follow it.
local function sections(panel)
    local out, current = {}, nil
    for _, row in ipairs(panel.rows) do
        if row.header then
            current = { header = row, rows = {} }
            out[#out + 1] = current
        elseif current then
            current.rows[#current.rows + 1] = row
        end
    end
    return out
end

-- The first vendor whose shelf carries a locked discipline band, so the test names no content by hand
-- and cannot rot when a house's stock is re-cut.
local function vendorWithLockedPath()
    for _, def in ipairs(Vendor.list()) do
        for _, s in ipairs(sections(shelf(def.id))) do
            if s.header.discipline and not Discipline.isUnlocked({ completedQuests = {} }, s.header.discipline) then
                return def.id, s.header.discipline
            end
        end
    end
end

return {
    {
        name = "a locked path folds shut by default: its header shows, its stock does not",
        fn = function()
            local vendorId, disciplineId = vendorWithLockedPath()
            assert(vendorId, "no shipped vendor bands a locked discipline -- the fixture has rotted")

            for _, s in ipairs(sections(shelf(vendorId))) do
                if s.header.discipline == disciplineId then
                    assert(s.header.collapsed, disciplineId .. ": a locked path should start shut")
                    assert(#s.rows == 0, disciplineId .. ": a shut path shows no rows, got " .. #s.rows)
                    assert(s.header.total > 0, disciplineId .. ": the header still counts what is behind it")
                    return
                end
            end
            error(disciplineId .. " lost its band on the second build")
        end,
    },
    {
        name = "the player can open a locked path and read every row behind it",
        fn = function()
            local vendorId, disciplineId = vendorWithLockedPath()
            local opened = shelf(vendorId, { [disciplineId] = false })

            for _, s in ipairs(sections(opened)) do
                if s.header.discipline == disciplineId then
                    assert(not s.header.collapsed, "an opened path draws its caret down")
                    assert(#s.rows == s.header.total,
                        "an opened path shows all " .. s.header.total .. " of its rows, got " .. #s.rows)
                    for _, r in ipairs(s.rows) do
                        assert(r.locked, "every row behind a locked path is still unbuyable")
                    end
                    return
                end
            end
            error(disciplineId .. " lost its band once opened")
        end,
    },
    {
        name = "an open section can be shut by hand -- the fold works both ways",
        fn = function()
            local vendorId = vendorWithLockedPath()
            local before = sections(shelf(vendorId))[1]
            assert(not before.header.collapsed, "the base rack starts open")
            assert(#before.rows > 0, "and shows its stock")

            local after = sections(shelf(vendorId, { __base = true }))[1]
            assert(after.header.collapsed, "a hand-shut section reports itself shut")
            assert(#after.rows == 0, "and hides its stock")
            assert(after.header.total == before.header.total, "without losing count of it")
        end,
    },
    {
        name = "unlocking a path opens it, even though it was shut while locked",
        fn = function()
            -- The fold state records only what the PLAYER set, so the default is re-read every build:
            -- a path that opens mid-session must not stay shut because it happened to be locked when
            -- the shelf was first drawn.
            local vendorId, disciplineId = vendorWithLockedPath()
            local panel = shelf(vendorId)
            assert(panel:isFolded(disciplineId), "locked and untouched: shut")

            local def = Discipline.defs[disciplineId]
            for _, q in ipairs(def.requiredQuests or {}) do panel.player.completedQuests[q] = true end
            if Discipline.isUnlocked(panel.player, disciplineId) then
                assert(not panel:isFolded(disciplineId), "unlocked and untouched: open")
            end
        end,
    },
    {
        -- The detail pane is the only room a shut band has to say anything, so a header without a blurb
        -- is a heading the player cannot read -- and a locked band's heading is the entire pitch for the
        -- gate behind it. class_spec and discipline_spec pin that the sentences exist; this pins that
        -- the shelf actually picks them up, for every band of every house.
        name = "every band on every shelf carries the blurb its detail pane prints",
        fn = function()
            local checked = 0
            for _, def in ipairs(Vendor.list()) do
                local panel = shelf(def.id)
                for _, s in ipairs(sections(panel)) do
                    -- The general store has no class, so its base rack is not a shelf with a point of
                    -- view and has nothing to say about itself; every other band does.
                    if s.header.discipline or def.class then
                        assert(type(s.header.blurb) == "string" and s.header.blurb ~= "",
                            def.id .. ": band '" .. tostring(s.header.label) .. "' has no blurb")
                        checked = checked + 1
                    end
                end
            end
            assert(checked > 0, "no vendor banded its shelf -- the fixture has rotted")
        end,
    },
    {
        name = "the base rack is not a path and folds under its own key",
        fn = function()
            local vendorId = vendorWithLockedPath()
            local panel = shelf(vendorId)
            assert(not panel:isFolded(nil), "the base rack starts open")
            panel.folded.__base = true
            assert(panel:isFolded(nil), "and answers to __base, not to a discipline id")
        end,
    },
}
