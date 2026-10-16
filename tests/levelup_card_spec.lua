-- The Fire Emblem level-up card (ui/levelup_card.lua) and the mid-fight resolve it plays on
-- (Experience.resolveOnBoard, called from states/battle.lua's settle seam). Nothing here draws: the
-- card's rows, its reveal/dismiss machine, its queue, the auto-battle skip and the hand-off to the
-- post-fight seam are all draw-free.

local LevelupCard = require("ui.levelup_card")
local Experience = require("models.experience")
local Character = require("models.character")

local function silent() end

-- A one-body company standing on a fake board, its experience banked just past the next level.
local function boardWithLevelUp()
    local char = Character.instantiate("character_knight")
    char.level = 1
    char.xp = 0
    local roster = { char }
    local unit = { char = char, side = "party", control = "player", alive = true }
    -- Wounded, so "current rises by the gain" is a different claim from "refilled to max".
    char.stats.health.current = char.stats.health.max - 10
    Experience.award(char, Experience.totalFor(2))
    return char, roster, { unit }, unit
end

return {
    { name = "rows: every stat in order, and a chip only on a stat that grew", fn = function()
        local rows = LevelupCard.rows({ health = 30, damage = 9 }, { health = 3, damage = 0, speed = -1 })
        assert(#rows == #LevelupCard.STAT_ORDER, "one row per stat")
        for i, stat in ipairs(LevelupCard.STAT_ORDER) do
            assert(rows[i].stat == stat, "order follows STAT_ORDER")
            assert(rows[i].label == LevelupCard.STAT_LABEL[stat], "labelled")
        end
        assert(rows[1].gain == 3 and rows[1].value == 30, "health grew by 3")
        for i = 2, #rows do assert(rows[i].gain == 0, rows[i].stat .. " carries no chip") end
    end },

    { name = "first press reveals and skips the animation, second dismisses", fn = function()
        local played = 0
        local card = LevelupCard.forLevel(Character.instantiate("character_knight"),
            { fromLevel = 3, toLevel = 4, class = "knight", gains = { health = 2, defense = 1 } },
            { playSound = function() played = played + 1 end })
        assert(card.chipCount == 2, "two stats grew, two chips")
        assert(not card.revealed and not card.done)
        card:update(0.05)
        assert(not card.revealed, "still animating")
        assert(card:press() == "revealed" and card.revealed and not card.done)
        assert(card.t >= card.finish, "the reveal jumps to the end of the animation")
        assert(played == 1, "the chime still plays once when the animation is skipped")
        assert(card:press() == "dismissed" and card.done)
        assert(played == 1, "and never twice")
    end },

    { name = "the animation reveals on its own; the chime plays as the chips start", fn = function()
        local played = {}
        local card = LevelupCard.forLevel(Character.instantiate("character_knight"),
            { fromLevel = 1, toLevel = 2, gains = { damage = 1 } },
            { playSound = function(id) played[#played + 1] = id end })
        card:update(LevelupCard.CHIP_AT - 0.01)
        assert(#played == 0, "silent until the first chip")
        card:update(0.02)
        assert(played[1] == "quest.levelup")
        card:update(5)
        assert(card.revealed and not card.done, "revealed, waiting for the dismissing press")
    end },

    { name = "every input verb presses, and the card eats them all", fn = function()
        local card = LevelupCard.forLevel(Character.instantiate("character_knight"),
            { fromLevel = 1, toLevel = 2, gains = {} }, { playSound = silent })
        assert(card:keypressed("w") == true and not card.revealed, "a stray key is swallowed, not a press")
        assert(card:mousepressed(10, 10, 1) == true and card.revealed)
        assert(card:gamepadpressed(nil, "a") == true and card.done)
        local c2 = LevelupCard.forLevel(Character.instantiate("character_knight"),
            { fromLevel = 1, toLevel = 2, gains = {} }, { playSound = silent })
        c2:keypressed("return"); c2:keypressed("space")
        assert(c2.done, "confirm, then confirm again")
    end },

    { name = "the queue plays one card per body, in order", fn = function()
        local q = LevelupCard.queue()
        assert(not q:active())
        local a = LevelupCard.forLevel({ name = "A", stats = {} }, { fromLevel = 1, toLevel = 2, gains = {} },
            { playSound = silent, values = {} })
        local b = LevelupCard.forLevel({ name = "B", stats = {} }, { fromLevel = 4, toLevel = 5, gains = {} },
            { playSound = silent, values = {} })
        q:push(a); q:push(b)
        assert(q:current() == a)
        q:mousepressed(0, 0, 1); q:mousepressed(0, 0, 1)
        assert(q:current() == b, "the second card follows the first")
        q:keypressed("return"); q:keypressed("return")
        assert(not q:active(), "idle once the last is dismissed")
        assert(q:keypressed("return") == false, "an idle queue claims no input")
    end },

    { name = "the unlock ceremony: banner kind, class title, chips are the boost", fn = function()
        local char = Character.instantiate("character_knight")
        local card = LevelupCard.showUnlock(char, "knight", { damage = 2, health = 4 }, { playSound = silent })
        assert(card.kind == "unlock" and card.classId == "knight")
        assert(type(card.classTitle) == "string" and card.classTitle ~= "")
        assert(card.chipCount == 2)
        for _, row in ipairs(card.rows) do
            local want = ({ damage = 2, health = 4 })[row.stat] or 0
            assert(row.gain == want, row.stat)
            assert(row.value == Character.statTotal(char, row.stat), "shows the sheet's figure")
        end
    end },

    { name = "mid-fight: the level lands on the live body, current HP rises by the gain", fn = function()
        local char, roster, units = boardWithLevelUp()
        local maxBefore, curBefore = char.stats.health.max, char.stats.health.current
        local ups = Experience.resolveOnBoard(units, roster)
        assert(#ups == 1 and ups[1].summary.toLevel == 2 and char.level == 2)
        local gain = ups[1].summary.gains.health or 0
        assert(gain > 0, "a knight's level grows health")
        assert(char.stats.health.max == maxBefore + gain, "the ceiling rose")
        assert(char.stats.health.current == curBefore + gain, "and the wounded body rose by the same")
    end },

    { name = "mid-fight: a pool above its base max (gear) does not lose health by levelling", fn = function()
        local char, roster, units = boardWithLevelUp()
        char.maxBonus = { health = 20 }
        char.stats.health.current = char.stats.health.max + 15
        local was = char.stats.health.current
        local ups = Experience.resolveOnBoard(units, roster)
        local gain = ups[1].summary.gains.health or 0
        assert(char.stats.health.current == was + gain, "current kept its overhang and took the gain")
    end },

    { name = "mid-fight: summons and bodies off the roster are not levelled", fn = function()
        local char, _, units = boardWithLevelUp()
        assert(#Experience.resolveOnBoard(units, {}) == 0, "not on the roster")
        units[1].summoned = true
        assert(#Experience.resolveOnBoard(units, { char }) == 0, "a summon")
        assert(char.level == 1)
    end },

    { name = "auto-battle applies the level and shows no card", fn = function()
        local char, roster, units = boardWithLevelUp()
        local ups = Experience.resolveOnBoard(units, roster)
        local cards = LevelupCard.cardsFor(ups, function() return true end, { playSound = silent })
        assert(#cards == 0, "no card")
        assert(char.level == 2, "the level still landed")
        local char2, roster2, units2 = boardWithLevelUp()
        local hand = LevelupCard.cardsFor(Experience.resolveOnBoard(units2, roster2),
            function() return false end, { playSound = silent })
        assert(#hand == 1 and hand[1].char == char2 and hand[1].toLevel == 2, "a hand-played body gets one")
    end },

    { name = "the post-fight seam finds nothing left for a body levelled mid-fight", fn = function()
        local char, roster, units = boardWithLevelUp()
        assert(#Experience.resolveOnBoard(units, roster) == 1)
        local health = char.stats.health.max
        assert(#Experience.resolveParty(roster) == 0, "nobody to toast")
        assert(char.stats.health.max == health and char.level == 2, "and nothing applied twice")
        assert(#Experience.resolveOnBoard(units, roster) == 0, "the seam itself is idempotent")
    end },
}
