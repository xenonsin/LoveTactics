-- Accuracy authoring pass: run with
--
--     & "E:\LOVE\lovec.exe" . accuracy-author [apply | table]
--
-- Writes `skill` and `luck` into the stats block of every character blueprint that lacks them. Dry run
-- by default; `apply` writes the files, `table` prints the proposed roster and stops.
--
-- WHY A TOOL, GIVEN THE VALUES ARE MEANT TO BE AUTHORED. Because the alternative to a tool is not
-- hand-authoring -- it is a runtime default, and a default is exactly what was rejected: it would make
-- every knight identical, which defeats the point of the stats existing. 153 blueprints need real
-- numbers, and a hand pass over 153 files is a hand pass that leaves a dozen of them at the fallback
-- with nothing to say which dozen.
--
-- What this writes is AUTHORED DATA and not a formula the game consults. Once written the numbers live
-- in the blueprints, are edited there, and this tool never reads them again -- it skips any file that
-- already declares either field. So a hand-tuned body stays hand-tuned across a re-run, and the derived
-- table below is a starting point that gets overwritten by judgement rather than a source of truth
-- competing with it. tests/data_spec.lua is what makes the authoring real: it fails the build over a
-- combatant blueprint still sitting on Character.ACCURACY_STATS.
--
-- ---------------------------------------------------------------------------
-- WHAT THE TWO STATS MEAN (docs/accuracy.md)
--
--   skill  how well the body swings. Worth 2 points of Hit each, and half a point of Crit.
--   luck   how the world treats it. Worth a point of Avoid, and subtracts from every attacker's
--          crit chance outright -- so a lucky body is not hard to hit, it is hard to hit BADLY.
--
-- Both on a 0-10 band. The derivation reads three fields the blueprints already carry -- `kind`,
-- `class` and `archetype` -- plus `tier`, and then ~20 named bodies overrule it outright. That split
-- is deliberate: the derivation is there so a wolf and a bandit are not the same animal, and the
-- override table is there because the bodies with names are the ones a player will actually form an
-- opinion about.

local M = {}

-- ---------------------------------------------------------------------------
-- The houses, for a body with a class. Each is an argument about what that discipline is FOR.
local BY_CLASS = {
    -- The aiming house. Highest skill in the game short of Pride herself: a hunter's whole claim is
    -- that the shot goes where it was sent.
    hunter    = { skill = 8, luck = 4 },
    -- The crit house, and the only one high in both. A rogue wins by the blow nobody was ready for,
    -- which is half precision and half being the sort of person things go well for.
    rogue     = { skill = 7, luck = 7 },
    -- Careful hands, no fortune whatsoever. An alchemist's results come from having measured.
    alchemist = { skill = 6, luck = 3 },
    mage      = { skill = 5, luck = 4 },
    fighter   = { skill = 5, luck = 3 },
    -- The wall does not dodge and was never supposed to. A knight buys survival with plate, and
    -- pricing it in avoid as well would be paying it twice.
    knight    = { skill = 4, luck = 2 },
    -- Blessed, in the only sense the engine can express. A priest is unremarkable with a weapon and
    -- improbably difficult to finish off.
    priest    = { skill = 4, luck = 6 },
}

-- ...and for a body with none, read off what KIND of thing it is. These are the monsters, and the
-- argument each makes is about what it would even mean for that thing to be skilled or lucky.
local BY_KIND = {
    -- Instinct rather than technique, and hard to pin down. A wolf is not a swordsman and does not
    -- need to be.
    beast     = { skill = 3, luck = 5 },
    -- Neither. A corpse has forgotten the trade and fortune has finished with it -- the only kind in
    -- the game at luck 0 by nature, which makes the undead the reliable thing to crit.
    undead    = { skill = 2, luck = 0 },
    -- Machined precision and no luck at all. A construct hits what it was pointed at and nothing ever
    -- goes unexpectedly well for it.
    construct = { skill = 6, luck = 0 },
    -- Practised and favoured, which is most of what makes them frightening.
    demon     = { skill = 6, luck = 5 },
    -- Nothing to aim with, and nothing solid to aim AT. High avoid is the whole body.
    elemental = { skill = 3, luck = 6 },
    -- It does not act and it cannot dodge (Combat.rollsToHit exempts objects outright, so these two
    -- numbers never decide anything -- they are written for completeness, not effect).
    object    = { skill = 0, luck = 0 },
    -- A humanoid with no class: a bandit, a survivor, somebody's driver. Ordinary in both.
    humanoid  = { skill = 4, luck = 4 },
}

-- How a body FIGHTS adjusts what it is good at, but only ever the skill half -- posture is a choice
-- about where to stand, and fortune does not care where you stood.
local BY_ARCHETYPE = {
    skirmish   = 1,   -- picks its moment, so it picks its shot
    aggressive = 0,
    support    = -1,  -- its hands are full of something other than a weapon
    defensive  = -1,  -- braced, not aiming
    guard      = -1,
    holdGround = -1,
    escort     = 0,
}

-- The ladder (docs/bestiary.md): chaff, line, elite, boss. A rung is a declared label and nothing else
-- derives a stat from it -- except this, which is the point of a ladder: the thing at the top of it is
-- meant to be better at fighting than the thing at the bottom.
--
-- TIER 0 IS NEUTRAL, NOT THE BOTTOM. It means "not on the ladder at all" -- a prop, an escortee, or a
-- shape worn by Wild Shape -- so it is not a rung below 1, it is the absence of a rung, and reading it
-- as a penalty is deriving a stat from a non-position. The first draft of this table had it at -2 and
-- proposed skill 1 for the Dire Bear, which is a Wild Shape form and one of the more dangerous things
-- on the board.
local BY_TIER = {
    [0] = { skill = 0,  luck = 0 },
    [1] = { skill = -1, luck = 0 },
    [2] = { skill = 0,  luck = 0 },
    [3] = { skill = 1,  luck = 0 },
    [4] = { skill = 2,  luck = 1 },
}

-- What a DERIVED body may reach. The band is 0-10, but a template tops out at 8 and the last two
-- points are reserved for the bodies in NAMED below.
--
-- This is the rule that makes the override table mean something. Without it the generic Archer
-- (hunter, skirmish) proposed skill 9 and out-shot Kaya, and the generic Bandit Chief tied Kaen --
-- which reads as the roster having no protagonists. A body with a name should be able to be better at
-- this than the template it was cut from, and this is the cheapest possible way to say so.
local DERIVED_CAP = 8

-- ---------------------------------------------------------------------------
-- THE NAMED BODIES, which outrule everything above. A player forms opinions about these and about
-- almost none of the rest, so they are the ones worth an argument rather than a formula.
local NAMED = {
    -- THE SEVEN COMPANIONS ------------------------------------------------
    -- The wall, the bodyguard, and the one who teaches the trade. Skill well above her house because
    -- she is the mentor -- she knows how it is done and says so. Luck near the floor: Rowan's whole
    -- character is that she keeps the oath rather than that things go well for her.
    character_rowan = { skill = 6, luck = 2, why = "the mentor: knows the trade, is owed nothing by fortune" },
    -- The player. Deliberately unremarkable with a weapon and absurdly hard to finish -- which is the
    -- honest description of a protagonist, and it makes the avatar's survival read as the story's
    -- doing rather than the build's.
    character_avatar = { skill = 4, luck = 8, why = "unremarkable technique, improbable survival" },
    -- Both sit a point above what their house's template reaches (DERIVED_CAP), which is the whole
    -- reason that cap exists: the generic Archer and the generic Bandit Chief are excellent, and the
    -- companions the player learns the names of are better.
    character_kaya = { skill = 9, luck = 5, why = "the hunter, above what her house teaches" },
    character_kaen = { skill = 9, luck = 7, why = "the assassin proper: both halves of the rogue" },
    character_clem = { skill = 6, luck = 8, why = "reckless and gets away with it" },
    character_gyeom = { skill = 6, luck = 4, why = "a disciplined mage" },
    -- The witness. The lowest skill of the seven and the highest luck: Amana survives things rather
    -- than winning them, which is the whole shape of the Lust line.
    character_amana = { skill = 3, luck = 9, why = "the witness -- survives what she cannot fight" },
    character_ren = { skill = 6, luck = 3, why = "kindness with measured hands" },
    -- The arena champion the player fights and can then recruit. character_saber_bout inherits this
    -- by shallow copy and must not be written to separately.
    character_saber = { skill = 8, luck = 4, why = "the bout's champion: technique is her claim" },

    -- THE SEVEN GENERALS --------------------------------------------------
    -- The Unequalled. Skill 10 is the only 10 in the game, and it is hers because it is literally her
    -- epithet -- Pride's claim is not that she is strong but that nobody is better.
    character_general_pride = { skill = 10, luck = 3, why = "the Unequalled: the only 10, and it is the point" },
    -- The Ever-Owed. Luck 10, the mirror of Pride's: Greed's domain IS fortune, so she is nearly
    -- impossible to crit and every attacker gives up their upside against her.
    character_general_greed = { skill = 5, luck = 10, why = "fortune itself is the domain" },
    -- The Unborn covets what others have, fortune included.
    character_general_envy = { skill = 6, luck = 8, why = "covets the luck as well" },
    character_general_lust = { skill = 7, luck = 7, why = "practised and favoured in equal measure" },
    character_general_gluttony = { skill = 5, luck = 4, why = "appetite is not aim" },
    -- The Unrelieved does the minimum, and that is a stat line as much as a personality.
    character_general_sloth = { skill = 3, luck = 3, why = "does the least that will do" },
    -- Fury is not precision, and it is certainly not luck. Ira hits constantly and badly.
    character_general_wrath = { skill = 6, luck = 1, why = "relentless, not accurate" },
    character_general_wrath_demon = { skill = 8, luck = 1, why = "unbound: the fury finally lands" },
    character_demon_lord = { skill = 8, luck = 5, why = "the Hollow Crown" },

    -- PRIDE'S LINE, which reads as a descending ladder of the one stat: the general at 10, her apex at
    -- 9, her mini sin at 8, each of them low on luck. Nothing else in the game is arranged this way,
    -- and that is the circle stating itself -- Pride is the sin whose claim is specifically to be
    -- BETTER, so it is the sin that should own the top of a skill column. Derived from `kind humanoid`
    -- these two came out at 5, which is Pride's apex being averagely good at fighting.
    character_the_peerless = { skill = 9, luck = 2, why = "Pride's apex: duels, and does not need luck" },
    character_marginalia = { skill = 8, luck = 2, why = "Pride's mini sin: the same claim, one rank down" },
}

-- ---------------------------------------------------------------------------

local function clamp(v, hi) return math.max(0, math.min(hi or 10, v)) end

-- The proposed pair for one blueprint, and where it came from.
function M.propose(id, def)
    local named = NAMED[id]
    if named then return named.skill, named.luck, "named: " .. named.why end

    local base = (def.class and BY_CLASS[def.class]) or BY_KIND[def.kind] or BY_KIND.humanoid
    local source = (def.class and BY_CLASS[def.class]) and ("class " .. def.class) or ("kind " .. tostring(def.kind))

    -- An object is an object whatever else it declares: it neither swings nor dodges, and letting a
    -- tier or an archetype nudge it off 0 would be arithmetic on a number that means nothing.
    if def.kind == "object" then return 0, 0, "object" end

    local skill = base.skill + (BY_ARCHETYPE[def.archetype] or 0) + (BY_TIER[def.tier or 2] or BY_TIER[2]).skill
    local luck = base.luck + (BY_TIER[def.tier or 2] or BY_TIER[2]).luck
    return clamp(skill, DERIVED_CAP), clamp(luck, DERIVED_CAP), source
end

-- Insert `skill` / `luck` into the stats block of `src`, returning the new source or nil if the block
-- could not be found. Anchored on the CLOSING brace of the block rather than on any particular stat
-- line: blueprints vary in which stats they declare and in what order, and the one thing every stats
-- block has is an end.
local function insert(src, skill, luck)
    local lines = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end

    local start
    for i, line in ipairs(lines) do
        if line:find("stats%s*=%s*{") then start = i break end
    end
    if not start then return nil end

    -- Walk braces from the opening line to find where the block closes. Counting both directions on
    -- every line handles a nested table on one line and a `},` that closes two at once.
    local depth = 0
    local stop
    for i = start, #lines do
        local _, opens = lines[i]:gsub("{", "")
        local _, closes = lines[i]:gsub("}", "")
        depth = depth + opens - closes
        if depth <= 0 then stop = i break end
    end
    if not stop then return nil end

    -- Match the indentation the block's own entries use, so the insertion is invisible in a diff
    -- except for what it says.
    local indent = (stop > start and lines[stop - 1]:match("^(%s*)")) or "        "
    local added = string.format(
        "%s-- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an\n"
        .. "%s-- attacker's crit. Authored, and never grown -- these are what this body IS.\n"
        .. "%sskill = %d, luck = %d,", indent, indent, indent, skill, luck)

    table.insert(lines, stop, added)
    return table.concat(lines, "\n")
end

function M.run(args)
    args = args or {}
    local apply, tableOnly = false, false
    for _, a in ipairs(args) do
        if a == "apply" then apply = true elseif a == "table" then tableOnly = true end
    end

    local Character = require("models.character")

    local rows, skipped = {}, {}
    for _, name in ipairs(love.filesystem.getDirectoryItems("data/characters")) do
        if name:sub(-4) == ".lua" then
            local id = name:sub(1, -5)
            local path = "data/characters/" .. name
            local src = love.filesystem.read(path)
            local def = Character.defs[id]
            if not (src and def) then
                skipped[#skipped + 1] = { id = id, why = "unreadable or unregistered" }
            elseif src:find("\n%s*skill%s*=") or src:find("\n%s*luck%s*=") then
                -- Already authored: never touched again, so hand tuning survives a re-run.
                skipped[#skipped + 1] = { id = id, why = "already authored" }
            elseif src:find('require%("data%.characters%.') then
                -- A DERIVED blueprint -- character_saber_bout, which shallow-copies the recruitable
                -- Saber and overrides three fields. It inherits skill and luck with everything else,
                -- and writing them here would be the exact drift its own header warns about: the boss
                -- and the companion are supposed to be one body fought two ways.
                --
                -- Detected by the require rather than by the absence of a stats block, which was the
                -- first attempt and was wrong -- it builds `bout.stats = {}` and copies into it, so the
                -- pattern matched and it very nearly got written a fighter's numbers over an authored
                -- champion's.
                skipped[#skipped + 1] = { id = id, why = "derived from another blueprint (inherits)" }
            elseif not src:find("stats%s*=%s*{") then
                skipped[#skipped + 1] = { id = id, why = "no stats block" }
            else
                local skill, luck, source = M.propose(id, def)
                local body = insert(src, skill, luck)
                if body then
                    rows[#rows + 1] = { id = id, path = path, skill = skill, luck = luck,
                                        source = source, body = body, name = def.name }
                else
                    skipped[#skipped + 1] = { id = id, why = "could not locate the stats block" }
                end
            end
        end
    end

    table.sort(rows, function(a, b) return a.id < b.id end)

    print(string.format("ACCURACY AUTHORING -- %s",
        apply and "APPLYING" or (tableOnly and "roster" or "dry run (pass `apply` to write)")))
    print("")
    print(string.format("  %-34s %-22s %5s %5s  %s", "id", "name", "skill", "luck", "from"))
    for _, r in ipairs(rows) do
        print(string.format("  %-34s %-22s %5d %5d  %s",
            r.id, (r.name or ""):sub(1, 22), r.skill, r.luck, r.source))
    end
    print("")
    print(string.format("  %d to write, %d skipped", #rows, #skipped))
    for _, s in ipairs(skipped) do print(string.format("    skip %-32s %s", s.id, s.why)) end
    print("")

    if tableOnly then return end
    if not apply then
        print("  Nothing written. Re-run with `apply`.")
        return
    end

    -- love.filesystem writes to the SAVE directory, not the project, so the write goes through io.
    -- Same route tools/day_migrate.lua takes for the same reason.
    local written, failed = 0, {}
    for _, r in ipairs(rows) do
        local fh = io.open(r.path, "wb")
        if fh then
            fh:write(r.body)
            fh:close()
            written = written + 1
        else
            failed[#failed + 1] = r.path
        end
    end
    print(string.format("  wrote %d files", written))
    for _, p in ipairs(failed) do print("  COULD NOT WRITE: " .. p) end
end

return M
