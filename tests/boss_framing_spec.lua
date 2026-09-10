-- Tests for what tells a BOSS apart from the bodies around it, on both surfaces that have to say so:
--
--   * the board (ui/battle_map.lua) -- the fight's crest in the corner of its tile, a heavier health
--     bar, and the thick token border;
--   * the turn strip (ui/combat_panel.lua) -- the same crest in the name row, and the phase
--     thresholds notched on the card's HP bar.
--
-- The notches live on the STRIP alone. A card's bar is wide enough for a tick to read as a stage still
-- ahead; the board's is 9px, where the same ticks read as the bar having been cut into pieces. Both
-- surfaces still ask one function for the numbers, which is why the threshold cases below sit here.
--
-- All of it asks ONE question, and the question lives in the model (Combat.isBoss) rather than in
-- either widget, because it is a fact about the fight. That is the invariant most worth pinning: two
-- screens keeping their own copy of "who is the boss" is two screens that can come to disagree.
--
-- What is under test is the GATE, the THRESHOLDS and the GEOMETRY, all of which are arithmetic and run
-- headless. The draws are not: they are love.graphics, and a spec that could see them would be a
-- screenshot test.
--
-- The board map is built the awkward way (the real metatable over a stand-in), the same trick and for
-- the same reason as tests/board_rotation_spec.lua: BattleMap.new wants a tileset and a font, and every
-- function under test here has to be the one the game runs.
--
-- The case the whole feature exists for is last: the Demon Champion, which is tier THREE and would be
-- missed by a rung gate alone, reads as a boss in the fight the prologue names it the mark of.

local BattleMap = require("ui.battle_map")
local Combat = require("models.combat")
local Character = require("models.character")

local TILE = 64

-- A board holding `objective`, laid out the way a fight lays one out. Nothing here draws.
local function map(objective)
    local m = setmetatable({
        arena = { cols = 8, rows = 8 },
        size = TILE,
        leftMargin = 264, rightMargin = 320, topMargin = 88,
        rotation = 0,
        combat = { objective = objective },
    }, BattleMap)
    m:layout()
    return m
end

local function unit(id)
    return { char = Character.instantiate(id), x = 1, y = 1, w = 1, h = 1, alive = true }
end

-- The bar's height, which is the whole of what a boss's board bar changes.
local function barH(m, u)
    local _, _, _, h = m:hpBarRect(u, 0, 0)
    return h
end

return {
    -- ----- the gate -----
    {
        name = "the bestiary's top rung reads as a boss whatever the fight is won by",
        fn = function()
            local lord = unit("character_demon_lord")
            assert(lord.char.tier == 4, "the Lord is tier 4 -- if that moves, this spec asks the wrong thing")
            assert(Combat.isBoss({ objective = { type = "killAll" } }, lord),
                "a tier-4 body is a boss even in a fight with no mark")
        end,
    },
    {
        name = "an ordinary line body is not, and neither is a discipline exemplar",
        fn = function()
            local c = { objective = { type = "killAll" } }
            assert(not Combat.isBoss(c, unit("character_demon_grunt")), "a grunt is a grunt")
            -- The exemplars carry `boss = true` -- the immunity marker, not a rung -- which is exactly
            -- the confusion this gate exists to refuse. Fielded as one body in a pack they are line
            -- work, and neither surface may plate them.
            local champ = unit("character_champion")
            assert(champ.char.boss, "the exemplar still carries the immunity flag")
            assert(not Combat.isBoss(c, champ),
                "carrying `boss = true` is not what makes a body a boss on screen")
        end,
    },
    {
        name = "the mark of an assassinate is a boss, and a summoned duplicate of it is not",
        fn = function()
            local c = { objective = { type = "assassinate", target = "character_champion" } }
            assert(Combat.isBoss(c, unit("character_champion")), "the body the fight is named after")
            -- Same `char.id`, and the fight does not end when it falls (Combat.evaluate skips summons
            -- for the same reason), so nothing on screen may call it the boss either.
            local copy = unit("character_champion")
            copy.summoned = true
            assert(not Combat.isBoss(c, copy), "a conjured double is not the mark")
        end,
    },
    {
        name = "a fight with no objective at all still answers, without reaching through a nil",
        fn = function()
            assert(not Combat.isBoss(nil, unit("character_demon_grunt")), "no fight, no mark")
            assert(Combat.isBoss(nil, unit("character_demon_lord")), "the rung clause needs no fight")
            assert(not Combat.isBoss({ objective = { type = "killAll" } }, nil), "no body, no answer")
        end,
    },

    -- ----- the thresholds both bars notch at -----
    {
        name = "the notches are the phase script's own thresholds, in descending order",
        fn = function()
            local marks = Combat.bossThresholds(unit("character_demon_champion"))
            assert(marks and #marks == 2, "the Champion's Sigil scripts two stages")
            assert(marks[1] > marks[2], "descending, so a board hash is stable")
            -- The same numbers the rule fires on, read off the same relic. Pinning the values rather
            -- than only the shape is the point: a re-scripted Sigil must fail this and be looked at,
            -- because the notches are a promise about when the fight changes.
            assert(math.abs(marks[1] - 0.66) < 1e-9 and math.abs(marks[2] - 0.33) < 1e-9,
                "two-thirds arms the Roar, a third enrages")
        end,
    },
    {
        name = "a boss with no phase relic gets the heavy bar and no notches",
        fn = function()
            local m = map({ type = "assassinate", target = "character_bandit_chief" })
            local chief = unit("character_bandit_chief")
            assert(m:isBoss(chief), "the mark is the mark")
            assert(Combat.bossThresholds(chief) == nil,
                "no authored stages means no ticks -- never an evenly-spaced guess")
            assert(barH(m, chief) > 5, "it is still drawn as a boss")
        end,
    },

    -- ----- the board's geometry -----
    {
        name = "the board asks the model, so the two surfaces cannot disagree",
        fn = function()
            local m = map({ type = "assassinate", target = "character_champion" })
            local mark = unit("character_champion")
            assert(m:isBoss(mark) == Combat.isBoss(m.combat, mark), "one question, one answer")
        end,
    },
    {
        name = "a boss's bar is heavier, and the badge row is pushed up by exactly that much",
        fn = function()
            local m = map({ type = "assassinate", target = "character_champion" })
            local mark, rank = unit("character_champion"), unit("character_demon_grunt")
            local plain, heavy = barH(m, rank), barH(m, mark)
            assert(plain == 5, "an ordinary body keeps the 5px sliver")
            assert(heavy > plain, "a boss's bar is drawn as an instrument, not a sliver")
            -- Both bars end on the same line along the footprint's bottom edge, so the heavy one grows
            -- UPWARD -- which is the whole reason the badge row asks hpBarRect instead of keeping its
            -- own copy of the arithmetic. Were it not to, a boss's badges would draw inside its bar.
            local _, plainY = m:hpBarRect(rank, 0, 0)
            local _, heavyY = m:hpBarRect(mark, 0, 0)
            assert(plainY + plain == heavyY + heavy, "the two bars sit on the same bottom line")
            assert(heavyY < plainY, "so the heavier one takes its extra height off the top")
        end,
    },

    -- ----- the case the feature exists for -----
    {
        name = "the Demon Champion reads as a boss in the fight the prologue names it the mark of",
        fn = function()
            -- conversation_flight_champion opens this fight promising the scale resets -- "every fight
            -- before this has been a horde, this one has a NAME" -- and the Champion is tier 3, so a
            -- rung gate alone would have left both surfaces saying nothing at the one moment the
            -- script says everything.
            local champ = unit("character_demon_champion")
            assert(champ.char.tier == 3, "Elite by rung; it is the FIGHT that makes it a boss")
            assert(not Combat.isBoss({ objective = { type = "killAll" } }, champ),
                "fielded as one body in a sweep, it is Elite")
            local m = map({ type = "assassinate", target = "character_demon_champion" })
            assert(m:isBoss(champ), "standing as the flight leg's mark, it is the boss")
            assert(barH(m, champ) > 5, "and the board draws it like one")
            assert(#Combat.bossThresholds(champ) == 2, "and the strip card notches at its two stages")
        end,
    },
}
