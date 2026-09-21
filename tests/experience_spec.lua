-- Tests for models/experience.lua -- what levels a body, in the one mode there is.
--
-- Two things are worth pinning here and they meet in the middle. One is that experience WORKS: acting
-- earns it, it converts to levels through the growth tables, and the curve lands the bottom floor near
-- the level the bottom floor is built for. The other is that there is exactly ONE curve -- the split
-- into a campaign step and a descent step is gone, and the cases below hold both ends of what replaced
-- it: the Hollow Crown at the deep end, and what Act 0 pays at the shallow one.

local Experience = require("models.experience")
local Growth = require("models.growth")
local Character = require("models.character")
local Player = require("models.player")
local Descent = require("models.descent")

return {
    { name = "the curve is a ladder, not a wall or a slide", fn = function()
        -- Level 1 is free, every rung after it costs the same, and none of them costs nothing.
        --
        -- IT USED TO DEMAND A RISING CURVE and that demand is what is gone. Both rising shapes were
        -- tried and both failed against the LINEAR danger ladder down here: triangular is out-earned
        -- by farming, and geometric diverges from the ramp so badly that honest play ran six levels
        -- over its own ground by floor two. models/experience.lua's THE CURVE IS FLAT records the
        -- measurement that retired each. The control moved wholesale into the award
        -- (Experience.rewardScale), which is FFT's arrangement, and tests/reward_scale_spec is where
        -- the anti-farming claim is now made -- by simulation rather than by the shape of this table.
        assert(Experience.totalFor(1) == 0, "everybody starts at level 1 having earned nothing")
        local first = Experience.totalFor(2) - Experience.totalFor(1)
        assert(first > 0, "a level must cost something")
        for level = 3, 20 do
            local step = Experience.totalFor(level) - Experience.totalFor(level - 1)
            assert(step == first, string.format(
                "level %d costs %d against %d -- the curve is flat, and a rising one re-opens the "
                .. "divergence models/experience.lua records", level, step, first))
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

    { name = "the world's ladder outruns a descending company, and by how much", fn = function()
        -- THE CURVE'S ONE REAL CLAIM, anchored on the BOTTOM. A clean company musters at level 1 with no
        -- prestige behind it and fights its way down every floor, so if the curve is wrong the Hollow
        -- Crown is either a walk or a wall. Read off Descent.floorLevel at the last floor rather than a
        -- literal, so retuning LEVEL_PER_FLOOR or FLOORS_PER_CIRCLE fails HERE instead of silently
        -- desyncing the two ladders -- which is exactly what lengthening a circle into a stratum did.
        local run = Descent.new(nil, 1)
        run.floor = Descent.FLOORS
        local wanted = Descent.floorLevel(run)

        -- What a body actually earns getting there: every floor of the descent at roughly six fights, in
        -- which it acts about seven times and takes a little over one kill. Deliberately spelled out in
        -- those units rather than as a total, so the assumption is arguable rather than a magic number --
        -- and driven off the real floor count, so a deeper descent re-derives instead of going stale.
        --
        -- THE FIGHT COUNT IS THE MEASURED ONE, NOT Descent.floorFights, and that swap is the whole of
        -- what this paragraph is for. This case used to sum the budget -- which is the honest-looking
        -- choice and is wrong, because that pair is read by no code in the game and is about DOUBLE
        -- what a floor costs. Descent.FLOOR_FIGHTS' own header now carries the measurement and says
        -- so: the ordinary fight is dealt off the prowl meter as the company WALKS, so a floor's cost
        -- is a property of the route, and greedy nearest-unvisited tours of real rolled floors run 6.9
        -- fights on floor one rising to 8.6 at the Crown.
        --
        -- Anchoring on the budget made this case certify a curve against a descent half the length of
        -- the one the player walks. Eight a floor is the measurement's mean, rounded, and is the same
        -- figure tests/reward_scale_spec simulates the ramp at.
        local actionsPerFight, killsPerFight = 7, 1.25
        local fights = Descent.FLOORS * 8
        local earned = fights *
            (actionsPerFight * Experience.PER_ACTION + killsPerFight * Experience.PER_FELLING)

        -- ON THE ONE STEP THERE IS. This case used to name a descent-only constant, because the mode
        -- kept a ladder of its own against a campaign anchored on a forty-day budget. That campaign is
        -- retired (models/building.lua's RETIRED) and so is its curve; the descent's anchor is now the
        -- game's, and this case is what pins it.
        local reached = Experience.levelFor(earned)

        -- ---------------------------------------------------------------------------
        -- AND THE TWO LADDERS NO LONGER MEET, WHICH IS THE POINT NOW RATHER THAN THE BUG.
        -- ---------------------------------------------------------------------------
        --
        -- This asserted the two were within two levels of each other, on the premise that a company
        -- fighting its way down should arrive at the bottom ready for it -- correct when one descent WAS
        -- the campaign and the bottom was an ending you were meant to reach.
        --
        -- IT WAS 5-9 AND IT IS 2-6, BECAUSE THE GAP STOPPED BEING A CLOCK. Under the distance run the
        -- world outrunning the company WAS the design -- "you descend until the floor outruns you, and
        -- the only thing you have to close it with is the snowball you picked up on the way." A run
        -- ended when the gap beat you, so a wide gap was the point.
        --
        -- The maze is a place now (Descent.keepFloor). There is no clock to be outrun by: you go down,
        -- you come back to the Ward and the Touchstone, and you walk in again at the stair you opened
        -- (Descent.entryFloor). So a company is not meant to arrive at the bottom underlevelled and
        -- lose -- it is meant to arrive when it is ready, which is many trips later.
        --
        -- WHAT CLOSES THE REMAINING GAP IS RE-TREADING, and that is why this is a small positive number
        -- rather than zero. The figure above is ONE PASS down a fifteen-floor stack; a re-walked floor
        -- re-arms its fights and pays them in full (Descent.rearmFloor's header states this and argues
        -- for it), so the company's real ladder is one pass plus however much of the shallow end it
        -- chooses to walk again. A gap of a few levels is exactly the amount of re-treading the loop is
        -- asking for. Zero would mean one pass suffices and the dungeon need never be re-entered, which
        -- is the Wizardry loop deleted.
        --
        -- WHAT IS NOT CLAIMED: that four is the right gap. Nobody has played it. The number to watch is
        -- how many trips a real company takes to reach the bottom, not this arithmetic.
        -- ---------------------------------------------------------------------------
        -- AND THEN THE TWO LADDERS STOPPED BEING ABLE TO DRIFT APART AT ALL.
        -- ---------------------------------------------------------------------------
        --
        -- Everything above is the reasoning that produced a band of 2-6, and it is kept because the
        -- question it was answering is still live -- how much re-treading does the loop ask for. What
        -- changed is that the answer is no longer a number anybody tunes.
        --
        -- The cost curve is flat and the AWARD is scaled by how far the company stands above the
        -- ground it is fighting (Experience.rewardScale, FFT's arrangement). That loop is
        -- self-correcting: pull ahead and you earn less, fall behind and you earn full. So a company
        -- cannot arrive at the bottom five levels under the world however it plays -- it tracks. The
        -- gap this case measures is now structurally near zero, and a band demanding it be 2-6 would
        -- be demanding the loop be broken.
        --
        -- WHAT THAT COSTS, AND IT IS WORTH NAMING: re-treading is no longer REQUIRED. Under the old
        -- arrangement a company had to re-walk the shallow end to close a level deficit before it
        -- could go deeper, and that was the Wizardry loop expressed as arithmetic. It is expressed as
        -- CONTENT now -- the haul you left on the floor you died on, the stair you have not opened,
        -- the piece a body is known for -- and never as a level deficit, because grinding one shut no
        -- longer works (tests/reward_scale_spec).
        local gap = wanted - reached
        assert(math.abs(gap) <= 3, string.format(
            "one pass down should leave a company within three levels of the world at floor %d " ..
            "(it wants %d, one pass earns %d, gap %d) -- the award scaling makes the two ladders " ..
            "track, so a wide gap either way means one of them was retuned out from under it",
            Descent.FLOORS, wanted, reached, gap))
    end },

    { name = "there is one curve, and no call site can name a second", fn = function()
        -- WHAT THE SPLIT COST. Two constants meant every seam had to pick, the pick was written as
        -- `game.descent and DESCENT_STEP or nil`, and every seam standing outside a run got the cheap
        -- ladder by default -- Act 0 among them (see the case below) and the load-time catch-up in
        -- Player.resolveLevels with it. So the second constant is gone rather than merely unused, and
        -- the curve reads the same however a caller tries to qualify it.
        assert(Experience.DESCENT_STEP == nil, "the descent's separate ladder is gone, not deprecated")
        assert(Experience.totalFor(10, 3) == Experience.totalFor(10),
            "a stray second argument must not buy a second curve")
        assert(Experience.levelFor(Experience.totalFor(10), 3) == 10,
            "and nor must one handed to the reading")
    end },

    { name = "what Act 0 pays lands the company where the first floor fights", fn = function()
        -- THE OTHER END OF THE SAME LADDER, and the regression this file exists to hold. The prologue
        -- banks its experience before any descent exists, so under the old split it cashed out on the
        -- campaign's cheap curve and delivered a company at level 8 to a floor that fights at 3 -- every
        -- marker on it reading as beneath them (Muster.WALK_OVER), and then four floors during which
        -- nobody gained a level at all, because Growth.resolve never levels a body down.
        --
        -- Act 0 is four fights -- the village, the two survivor stops, the champion (states/prologue.lua)
        -- -- and a two-body company takes all of them. Simulated through models/autobattle.lua that pays
        -- about 48 a head; real play, with its longer fights, its reinforcement waves and a retry or two,
        -- lands nearer 84. Both are checked, because the claim is about the BAND the prologue exits in,
        -- not about a single number nobody can hit twice.
        -- AGAINST WHAT STANDS ON THE FLOOR, not against the floor's dial. This asked for a level
        -- within one of Descent.OPENING_DANGER, which is the number the floor is GROWN from -- and
        -- ordinary stock is lagged under it (Growth.ENEMY_LEVEL_LAG), so the body a company actually
        -- meets on the first stair is a level below the dial. The comparison has to be with the body.
        --
        -- AND ACT 0 NO LONGER HANDS OVER FOUR LEVELS, which is the flat curve arriving rather than a
        -- regression. Four was an artifact of the triangular table: its first levels cost 10, 20, 30,
        -- so eighty experience bought three of them. On a flat curve a level costs what a FLOOR pays
        -- (Experience.STEP), and Act 0 is four fights -- about a floor's worth of fighting, and
        -- therefore about a level's worth. A tutorial that paid three levels was a tutorial paying
        -- three floors, which is the thing that made the opening floor a formality in the first place.
        local stock = Growth.combatantLevel({}, Descent.dangerLevel({ floor = 1 }),
            Descent.floorLevel({ floor = 1 }))
        for _, banked in ipairs({ 48, 84 }) do
            local level = Experience.levelFor(banked)
            assert(level >= stock - 2 and level <= stock + 1, string.format(
                "a body leaving Act 0 with %d experience is level %d, and the first stair is held by "
                .. "stock at %d -- the company has to arrive able to fight it",
                banked, level, stock))
        end
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

    { name = "the campaign spends what combat banks for it -- there is one ladder now", fn = function()
        -- THE BOUNDARY IS GONE, AND ITS REMOVAL IS THE POINT. This case used to assert the opposite:
        -- combat awarded experience in every mode, and only the descent ever resolved it, because a
        -- campaign roster levelled off the player's global prestige instead. Prestige no longer sets
        -- anybody's level, so the gate came out and this is now the only ladder in the game.
        local player = Player.new()
        local char = player.roster[1]
        assert(char, "the opening roster has a body to test with")

        Experience.award(char, Experience.totalFor(9))
        local advanced = Player.resolveLevels(player)
        assert(char.level == 9,
            "a campaign body levels off what it earned, got " .. tostring(char.level))
        assert(#advanced == 1 and advanced[1].char == char,
            "and the member that advanced is reported, for the toast that announces it")

        -- Idempotent, which is what lets the overworld call it after every fight.
        assert(#Player.resolveLevels(player) == 0, "a second resolve on the same bank advances nobody")
    end },

    { name = "a body that never fights never levels", fn = function()
        -- The other half of the same rule, and the one that makes the bench share necessary: nothing
        -- but experience moves a level now, so a member who sat out the whole campaign sits at 1.
        local player = Player.new()
        local char = player.roster[1]
        Player.resolveLevels(player)
        assert((char.level or 1) == 1, "no experience, no level")
    end },

    { name = "the bench is paid a share of what the field earned, and the field is not paid twice", fn = function()
        local a, b, c = { xp = 0 }, { xp = 0 }, { xp = 0 }
        local roster = { a, b, c }
        local earned = { [a] = 40, [b] = 20 } -- a and b stood on the board; c did not
        local share = Experience.payBench(roster, { a, b }, earned)

        assert(share == math.floor(30 * Experience.BENCH_SHARE),
            "the share is taken off the FIELD's average (30), got " .. share)
        assert(a.xp == 0 and b.xp == 0,
            "combat already paid the field as it acted -- paying again here would double it")
        assert(c.xp == share, "the benched body is paid, got " .. c.xp)

        -- Averaged over the field rather than the roster, so a tenth companion does not quietly
        -- halve what everybody on the bench is paid.
        local d = { xp = 0 }
        Experience.payBench({ a, b, c, d }, { a, b }, earned)
        assert(d.xp == share, "growing the company must not shrink the share")
    end },

    { name = "a fight nobody stood in pays no bench", fn = function()
        local c = { xp = 0 }
        assert(Experience.payBench({ c }, {}, {}) == 0, "no field, no average, no share")
        assert(c.xp == 0)
    end },

    { name = "the fight's report says where each bar starts, ends and crosses a level", fn = function()
        -- The victory panel's bars fill from these rows (ui/panels/battle_summary.lua). Everything a
        -- bar needs has to come out of the report, because the panel has no other view of the fight.
        local rowan = { name = "Rowan", xp = Experience.totalFor(4) + 9 }
        local xin = { name = "Xin", xp = 40 }
        local rows = Experience.report({ [rowan] = 5, [xin] = 40 })

        assert(#rows == 2, "one row per body that banked something, got " .. #rows)
        assert(rows[1].char == xin, "the body that took the most heads the list")
        assert(rows[1].from == 0 and rows[1].to == 40, "a bar fills from where the fight found it")
        assert(rows[2].from == rowan.xp - 5,
            "the start is the total MINUS the fight, since combat already banked it")
        assert(rows[2].fromLevel == 4 and rows[2].toLevel == 4,
            "a body that gained without crossing stays on its level")

        -- A crossing is the whole reason the bar animates rather than jumping, so the report has to
        -- report it rather than leaving the panel to compare two totals it was not given.
        local leveller = { name = "Clem", xp = Experience.totalFor(5) }
        local crossed = Experience.report({ [leveller] = 5 })[1]
        assert(crossed.fromLevel == 4 and crossed.toLevel == 5, "the row names both ends of the climb")

        assert(#Experience.report(nil) == 0, "a fight that paid nobody reports nothing")
        assert(#Experience.report({ [rowan] = 0 }) == 0, "and a body that banked nothing is not a row")
    end },

    { name = "a recruit joins on the company's median, so it is fieldable but not a free ride", fn = function()
        local roster = { { xp = 0 }, { xp = 600 }, { xp = 1200 } }
        assert(Experience.medianOf(roster) == 600, "the middle body, not the mean and not the best")
        assert(Experience.medianOf({}) == 0, "joining nobody earns nothing -- the avatar's case")
        -- An even company takes the LOWER middle: a recruit should arrive a shade behind the company
        -- rather than a shade ahead of half of it.
        assert(Experience.medianOf({ { xp = 90 }, { xp = 10 } }) == 10,
            "an even company takes the lower middle rather than failing to pick")
    end },
}
