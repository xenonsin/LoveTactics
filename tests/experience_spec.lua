-- Tests for models/experience.lua -- what levels a body in the descent.
--
-- Two things are worth pinning here and they pull in opposite directions. One is that experience WORKS:
-- acting earns it, it converts to levels through the growth tables, and the curve lands the seventh
-- circle near the level the seventh circle is built for. The other is that it stays OUT OF THE CAMPAIGN:
-- a campaign roster levels off prestige and always has, and the safety of that arrangement rests entirely
-- on the campaign never resolving a body's xp into a level. The last case is the one that fails if
-- somebody later "tidies up" by calling Experience.resolve from Player.syncLevels.

local Experience = require("models.experience")
local Growth = require("models.growth")
local Character = require("models.character")
local Player = require("models.player")
local Descent = require("models.descent")

return {
    { name = "the curve is a ladder, not a wall or a slide", fn = function()
        -- Level 1 is free and every rung after it costs strictly more than the one below: a flat curve
        -- would level a company faster the longer a floor ran, and a curve that ever dipped would make
        -- some level cheaper to reach than the one under it.
        assert(Experience.totalFor(1) == 0, "everybody starts at level 1 having earned nothing")
        local previousStep
        for level = 2, 20 do
            local step = Experience.totalFor(level) - Experience.totalFor(level - 1)
            assert(step > 0, "level " .. level .. " must cost something")
            if previousStep then
                assert(step > previousStep, "level " .. level .. " must cost more than the one below")
            end
            previousStep = step
        end
    end },

    { name = "the level a body has is a pure function of what it has earned", fn = function()
        -- Total lifetime experience, never a per-level remainder -- so there is no second number that
        -- can drift out of step with the first, and retuning the curve migrates nothing.
        assert(Experience.levelFor(0) == 1, "nothing earned is level 1")
        assert(Experience.levelFor(Experience.totalFor(5)) == 5, "exactly enough is the level")
        assert(Experience.levelFor(Experience.totalFor(5) - 1) == 4, "one short is the level below")
        assert(Experience.levelFor(Experience.totalFor(5) + 1) == 5, "and one over is not the level above")
    end },

    { name = "the cap is the growth tables' cap, not a second opinion", fn = function()
        -- A character the growth tables have no row for is a crash waiting for a long enough run.
        assert(Experience.levelFor(math.huge) == Growth.LEVEL_CAP, "experience cannot outrun the tables")
        assert(Experience.intoLevel(Experience.totalFor(Growth.LEVEL_CAP)) == nil,
            "the cap has no next level, so it fills no bar")
        local into, span = Experience.intoLevel(Experience.totalFor(4) + 2)
        assert(into == 2 and span > 0, "and below it, a bar reads how far into the rung it is")
    end },

    { name = "acting earns it, and the felling blow is worth more than a swing", fn = function()
        local char = Character.instantiate("character_knight")
        assert((char.xp or 0) == 0, "a fresh body has earned nothing")
        Experience.award(char, Experience.PER_ACTION)
        assert(char.xp == Experience.PER_ACTION, "an action banks its own worth")
        Experience.award(char, Experience.PER_FELLING)
        assert(char.xp == Experience.PER_ACTION + Experience.PER_FELLING, "and a kill banks on top of it")
        assert(Experience.PER_FELLING > Experience.PER_ACTION, "finishing a fight is worth taking")

        -- Nothing and nonsense are both no-ops rather than errors: this is called from the middle of
        -- combat, where a zero is an ordinary outcome.
        Experience.award(char, 0)
        Experience.award(char, -5)
        Experience.award(nil, 10)
        assert(char.xp == Experience.PER_ACTION + Experience.PER_FELLING, "a nil or empty award changes nothing")
    end },

    { name = "resolving turns banked experience into real growth", fn = function()
        local char = Character.instantiate("character_knight")
        local health = char.stats.health.max
        assert(Experience.resolve(char) == nil, "a body that has earned nothing does not advance")

        Experience.award(char, Experience.totalFor(4))
        local summary = Experience.resolve(char)
        assert(summary, "four levels' worth of experience advances the body")
        assert(summary.fromLevel == 1 and summary.toLevel == 4, "and it advances all the way, not one rung")
        assert(char.stats.health.max > health, "the growth tables actually applied")

        -- Idempotent: this is called after every won fight, so a body that earned nothing since the last
        -- one must cost a comparison and nothing else.
        assert(Experience.resolve(char) == nil, "resolving again advances nobody")
    end },

    { name = "a company resolves together and reports only who moved", fn = function()
        local a = Character.instantiate("character_knight")
        local b = Character.instantiate("character_mage")
        Experience.award(a, Experience.totalFor(3))
        local advanced = Experience.resolveParty({ a, b })
        assert(#advanced == 1, "only the body that earned a level is reported")
        assert(advanced[1].char == a, "and it is the one that earned it")
        assert(b.level == nil or b.level == 1, "the one that did nothing stays where it was")
    end },

    { name = "the seventh circle is reached at about the level it is built for", fn = function()
        -- THE CURVE'S ONE REAL CLAIM. Descent.floorLevel fights floor 7 at LEVEL_PER_FLOOR x 6 + 1, and a
        -- clean run musters at level 1 with no prestige behind it -- so if the curve is wrong the bottom
        -- of the descent is either a walk or a wall. Anchored against the ladder rather than a literal,
        -- so retuning LEVEL_PER_FLOOR fails here instead of silently desyncing the two.
        local run = Descent.new(nil, 1)
        run.floor = 7
        local wanted = Descent.floorLevel(run)

        -- What a body actually earns getting there: seven floors of roughly six fights, in which it acts
        -- about seven times and takes a little over one kill. Deliberately spelled out in those units
        -- rather than as a total, so the assumption is arguable rather than a magic number.
        local floors, fightsPerFloor, actionsPerFight, killsPerFight = 7, 6, 7, 1.25
        local earned = floors * fightsPerFloor *
            (actionsPerFight * Experience.PER_ACTION + killsPerFight * Experience.PER_FELLING)

        local reached = Experience.levelFor(earned)
        assert(math.abs(reached - wanted) <= 2,
            "a company that fights its way down should arrive near level " .. wanted ..
            ", not " .. reached)
    end },

    { name = "banked experience survives a save, so a resumed run keeps its progress", fn = function()
        -- A descent persists mid-run and is resumed from disk. Without xp in the character snapshot a
        -- resume would silently reset every body to its last WHOLE level -- the progress lost being
        -- exactly the part the player cannot see, which is the worst kind to lose.
        local Save = require("models.save")
        local char = Character.instantiate("character_knight")
        Experience.award(char, Experience.totalFor(3) + 5)
        Experience.resolve(char)

        local back = Save.restoreCharacter(Save.snapshotCharacter(char))
        assert(back.xp == char.xp, "experience must round-trip through the save")
        assert(Experience.levelFor(back.xp) == Experience.levelFor(char.xp), "and read as the same level")
        assert(back.level == char.level, "with the level it already resolved to intact")
    end },

    { name = "the campaign never spends what combat banks for it", fn = function()
        -- THE BOUNDARY. Combat awards experience in every mode, because a mode check in the middle of a
        -- swing is a branch that can be wrong; what keeps the two ladders apart is that only the descent
        -- ever RESOLVES it. A campaign roster carrying experience must still level off prestige alone.
        local player = Player.new()
        local char = player.roster[1]
        assert(char, "the opening roster has a body to test with")

        Experience.award(char, Experience.totalFor(9))
        local before = char.level or 1
        Player.syncLevels(player)
        assert((char.level or 1) == before,
            "a campaign sync must not read xp: levels there come from prestige (Growth.levelForPrestige)")
    end },
}
