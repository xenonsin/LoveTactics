-- ONE SENTENCE PER KIND OF STOP (models/encounter.lua's Encounter.GLOSS), and every kind has one.
--
-- The board tells twenty-two kinds of mark apart with a hue and a fourteen-pixel silhouette. Nothing
-- put either beside a word until the hover readout did (ui/encounter_tooltip.lua), and the modal a step
-- onto a stop opens (ui/panels/encounter.lua) had six sentences of its own for six of the kinds. A
-- coverage hole here is not a crash: it is a card that heads itself with a name and then says nothing,
-- on the exact stop a player has never met before.
--
-- THE COVERAGE IS MEASURED AGAINST A DECLARED LIST, not against the blueprints. Half the kinds a player
-- meets are minted by a generator and never appear in data/encounters at all -- both ways off the
-- floor, the hole through it, the day's ends, the pack a dead company left -- so a set derived from
-- disk would report itself complete while the commonest marks on the board went unglossed. The
-- blueprints are then checked AGAINST that list, so a new kind reaching disk fails here rather than
-- shipping mute.

local Encounter = require("models.encounter")

-- Every kind in the declared list, as a set.
local function declared()
    local set = {}
    for _, kind in ipairs(Encounter.MARKER_KINDS) do set[kind] = true end
    return set
end

return {
    {
        name = "every kind of stop the board can mark has a sentence saying what it is",
        fn = function()
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                local line = Encounter.GLOSS[kind]
                assert(type(line) == "string" and #line > 0,
                    "kind '" .. kind .. "' has no gloss: its card would head a name and say nothing")
                -- A flat declarative sentence, which is the register every other piece of interface
                -- copy in the game is written in. The stop between is a full stop, so a line that
                -- trails off unfinished is caught here rather than on the screen.
                assert(line:sub(-1) == "." or line:sub(-1) == "?",
                    "the gloss for '" .. kind .. "' does not finish its sentence: " .. line)
            end
        end,
    },
    {
        name = "no two kinds of stop are described in the same words",
        fn = function()
            local seen = {}
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                local line = Encounter.GLOSS[kind]
                -- Two kinds sharing a sentence is the failure the old table shipped in miniature: the
                -- point of the line is to separate marks that a hue and a silhouette cannot, so a
                -- duplicate is a kind that has been glossed as something it is not.
                assert(not seen[line],
                    "'" .. kind .. "' is described in the same words as '" .. tostring(seen[line]) .. "'")
                seen[line] = kind
            end
        end,
    },
    {
        name = "a blueprint kind that reached disk is a kind the list knows about",
        fn = function()
            local known = declared()
            for id, def in pairs(Encounter.defs) do
                assert(def.kind, "encounter blueprint '" .. id .. "' carries no kind at all")
                assert(known[def.kind], "'" .. id .. "' is a " .. def.kind ..
                    ", which Encounter.MARKER_KINDS has never heard of -- add it there and gloss it")
            end
        end,
    },
    {
        name = "an end, a house's errand and a ward are three different stops to the words as well as the plate",
        fn = function()
            -- The three share one model kind (`objective`) and nothing downstream may split them -- the
            -- arena's cap, the salvage and the payout all want them to be one set-piece. The split is
            -- made for the READING, in one place, so the map's plate and the hover card cannot disagree
            -- about which tile holds the boss.
            assert(Encounter.markerKind({ kind = "objective" }) == "objective",
                "the floor's own end is not read as an end")
            assert(Encounter.markerKind({ kind = "objective", questId = "quest_x" }) == "quest",
                "a house's posted work is not read as posted work")
            -- The ward is asked FIRST: she is an objective like every other end, so the questId clause
            -- would swallow her if the order ever flipped.
            assert(Encounter.markerKind({ kind = "objective", wardFor = 4 }) == "ward",
                "the lieutenant holding the stair is not read as a ward")
            assert(Encounter.markerKind({ kind = "objective", wardFor = 4, questId = "quest_x" }) == "ward",
                "a ward carrying a quest id is read as ordinary posted work")

            local a, b, c = Encounter.gloss({ kind = "objective" }),
                Encounter.gloss({ kind = "objective", questId = "quest_x" }),
                Encounter.gloss({ kind = "objective", wardFor = 4 })
            assert(a and b and c and a ~= b and b ~= c and a ~= c,
                "the three ends are glossed as fewer than three things")
        end,
    },
    {
        name = "the stop modal reads the shared gloss rather than keeping its own copy",
        fn = function()
            -- READ THE OTHER SURFACE, not the constant. Asserting that the model holds the sentences
            -- proves nothing about the panel, where a re-inlined copy would agree for exactly as long
            -- as nobody edited either side -- so this walks the panel's source, the way
            -- tests/wait_note_spec.lua walks the item tooltip's.
            local src = assert(love.filesystem.read("ui/panels/encounter.lua"),
                "ui/panels/encounter.lua is readable")
            assert(src:find("EncounterModel.gloss", 1, true),
                "the stop modal no longer reads the shared gloss")
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                local line = Encounter.GLOSS[kind]
                assert(not src:find(line, 1, true),
                    "the stop modal has its own copy of the '" .. kind .. "' sentence again")
            end
        end,
    },
}
