-- Reachability guard for the campaign, riding on the progression ledger (tools/progression_report).
--
-- The tool exists to MEASURE step 7 of docs/progression.md -- how often something arrives, so the
-- campaign's length can be decided against evidence. This spec uses it for the sharper thing it found
-- on its first run: `quest_cathedral_slot_03` required 3 of the Cathedral's quests when only 2 could
-- precede it, so the line was unfinishable from slot 3 down, and with it slot 10 -- one of the Gate
-- Below's seven keys. The campaign had no ending, and nothing failed. That is the class of bug this
-- guards: a gate whose own line cannot satisfy it.
--
-- Reachability is asserted under BOTH play policies, because a quest order is the player's and a gate
-- can be satisfiable depth-first and not breadth-first (or the reverse). Anything reachable in neither
-- is dead content; anything reachable in only one is a trap for half the players.
--
-- Pure data + models: the walk drives a throwaway player table and touches no love.graphics, so this
-- runs headless like the rest.

local Report = require("tools.progression_report")
local Quest = require("models.quest")

local function questCount()
    local n = 0
    for _ in pairs(Quest.defs) do n = n + 1 end
    return n
end

local function unreached(policy)
    local seen = {}
    for _, row in ipairs(Report.walk(policy)) do seen[row.id] = true end

    local missing = {}
    for id in pairs(Quest.defs) do
        if not seen[id] then missing[#missing + 1] = id end
    end
    table.sort(missing)
    return missing
end

return {
    {
        name = "every quest is reachable playing one house at a time",
        fn = function()
            local missing = unreached("committed")
            assert(#missing == 0, string.format(
                "%d quest(s) unreachable depth-first -- a gate its own line cannot satisfy: %s",
                #missing, table.concat(missing, ", ")))
        end,
    },
    {
        name = "every quest is reachable round-robinning the houses",
        fn = function()
            local missing = unreached("breadth")
            assert(#missing == 0, string.format(
                "%d quest(s) unreachable breadth-first: %s", #missing, table.concat(missing, ", ")))
        end,
    },
    {
        name = "the campaign can be finished -- the Gate Below is walked, and walked last",
        fn = function()
            -- The Gate needs all seven slot-10 quests, so it can only be the final row. If it ever
            -- lands earlier, its key list has stopped meaning what it says.
            for _, policy in ipairs({ "committed", "breadth" }) do
                local rows = Report.walk(policy)
                local last = rows[#rows]
                assert(last and last.id == "quest_the_gate_below", string.format(
                    "%s ends on %s, not the Gate Below", policy, last and last.id or "nothing"))
            end
        end,
    },
    {
        name = "the walk is deterministic (no RNG, so two runs agree)",
        fn = function()
            local a, b = Report.walk("committed"), Report.walk("committed")
            assert(#a == #b, "same length")
            for i = 1, #a do
                assert(a[i].id == b[i].id, string.format(
                    "row %d differs between runs: %s vs %s", i, a[i].id, b[i].id))
            end
        end,
    },
    {
        name = "every quest hands over something -- no silent quest in either order",
        fn = function()
            -- The step-7 finding, pinned so a future cut cannot quietly reintroduce a dead stretch:
            -- levels, shelf rows, disciplines, companions and item grants between them cover all 92
            -- quests. Gold is deliberately not counted (every quest pays it); see the tool's header.
            for _, policy in ipairs({ "committed", "breadth" }) do
                local silent = {}
                for _, row in ipairs(Report.walk(policy)) do
                    if row.silent then silent[#silent + 1] = string.format("#%d %s", row.n, row.id) end
                end
                assert(#silent == 0, string.format("%s: %d silent quest(s): %s",
                    policy, #silent, table.concat(silent, ", ")))
            end
        end,
    },
    {
        name = "the walk covers the whole board, not a prefix of it",
        fn = function()
            local total = questCount()
            assert(total == 92, "quest count changed (" .. total ..
                ") -- if that was deliberate, retune docs/progression.md step 7 with it")
            assert(#Report.walk("committed") == total, "committed walk is short")
        end,
    },
}
