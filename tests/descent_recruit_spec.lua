-- Tests for how a descent's company is raised: one body in at the gate, three found on the floors.
--
-- This replaced tests/descent_muster_spec.lua, which pinned the opposite arrangement -- a shelf, a purse
-- and a company of eight bought before a tile was walked. What is worth pinning changed with it. The
-- muster's cases were all about never handing a player something unplayable off a screen; these are about
-- a run being ABLE to raise a company at all, which is a property of the boards it walks rather than of a
-- widget: if a floor stops seating the stop, a run is one body deep forever and nothing else says so.

local Descent = require("models.descent")
local Recruit = require("models.descent_recruit")
local Character = require("models.character")
local Discipline = require("models.discipline")
local Encounter = require("models.encounter")
local Experience = require("models.experience")
local Overworld = require("models.overworld")
local Player = require("models.player")
local Quest = require("models.quest")

-- The params states/game.lua builds for a descent floor, so these cases roll the board a run actually
-- walks rather than a hand-written approximation of one. Only the fields the generator reads.
local function floorParams(quest, seed)
    local mp = quest.map
    return {
        biome = mp.biome, cols = mp.cols, rows = mp.rows,
        keyCount = mp.keyCount, cacheCount = mp.cacheCount,
        objective = mp.objective, ascent = mp.ascent,
        encounterCount = { min = mp.encounters.min, max = mp.encounters.max },
        encounters = Descent.floorPool({ day = 1, biome = mp.biome }),
        combatShare = mp.combatShare,
        guaranteeKinds = mp.guaranteeKinds,
        guarantee = mp.guarantee,
        seed = seed,
    }
end

local function kindCounts(grid)
    local counts = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid:get(x, y).encounter
            if e then counts[e.kind] = (counts[e.kind] or 0) + 1 end
        end
    end
    return counts
end

return {
    { name = "a run walks in with nobody, and the company holds the field", fn = function()
        -- THE PLAYER IS A TACTICIAN AND STANDS IN NO COMPANY (models/descent.lua). There is no body
        -- that is theirs, so a descent opens EMPTY and the first member is hired at the gate off the
        -- same authored slate the floors offer.
        --
        -- This replaced a created avatar, and the reason it had to is worth pinning: every answer to
        -- "what happens when your character dies" was bad. Lost outright ends the mode on one fight;
        -- left recoverable means minting a SECOND body with the same id to go and fetch the first, and
        -- identity here is the id; protected specially makes one member unkillable. A company with no
        -- avatar in it has none of those questions.
        local company = Descent.startingCompany()
        assert(#company == 0, "a descent opens with nobody, got " .. #company)
        assert(Descent.STARTING_BODY == nil,
            "there is no starting body constant: a body that is YOURS is what was removed")

        -- The cap IS the field: a descent has no bench, so every body found fights. Mirrored in
        -- models/descent.lua rather than required, which is exactly why it needs pinning here.
        assert(Descent.PARTY_MAX == Player.MAX_FIELD,
            "the company cap must be the field: " .. Descent.PARTY_MAX .. " vs " .. Player.MAX_FIELD)
        assert(Descent.hasRoom({ roster = { {}, {}, {} } }), "three of four has room for one more")
        assert(not Descent.hasRoom({ roster = { {}, {}, {}, {} } }), "a full company has none")
    end },

    { name = "a floor seats the stop that grows the company, and stops once it is full", fn = function()
        local run = Descent.new(nil, 77)
        local short = Descent.floorQuest(run, { roster = { {} } })
        local full = Descent.floorQuest(run, { roster = { {}, {}, {}, {} } })

        local function names(list)
            local set = {}
            for _, k in ipairs(list or {}) do set[k] = true end
            return set
        end
        local a, b = names(short.map.guaranteeKinds), names(full.map.guaranteeKinds)
        assert(a.recruit, "a floor walked by a short company must guarantee somewhere to grow")
        assert(not b.recruit, "a full company must not be sent to a stop that can only refuse")
        -- Naming a third kind REPLACES the generator's default pair rather than adding to it, so a floor
        -- that forgot to restate them would quietly lose its reliquary and its rest.
        for _, kind in ipairs({ "relic_cache", "rest" }) do
            assert(a[kind] and b[kind], "a floor must still guarantee its " .. kind)
        end
    end },

    { name = "the stop is really on the board, and the floor is still a floor", fn = function()
        -- THE CASE THAT EARNS THIS FILE. Everything above is a descriptor agreeing with itself; this
        -- rolls the actual board. A descent floor is an `ascent` map, and models/overworld.lua's
        -- placeEncounters takes an entirely different route through those -- so "the descriptor asked for
        -- a recruit stop" and "a recruit stop is standing on the floor" are two facts, and only the
        -- second one is the feature.
        local run = Descent.new(nil, 5150)
        local quest = Descent.floorQuest(run, { roster = { {} } })
        for _, seed in ipairs({ 3, 17, 404, 8888 }) do
            local grid = Overworld.generate(floorParams(quest, seed))
            local counts = kindCounts(grid)
            assert((counts.recruit or 0) >= 1,
                "seed " .. seed .. ": a company of one was given no way to grow")
            assert((counts.rest or 0) >= 1, "seed " .. seed .. ": the floor lost its rest")
            assert((counts.relic_cache or 0) >= 1, "seed " .. seed .. ": the floor lost its reliquary")
            -- ...and the floor is still mostly fighting. A guarantee that swallowed the weighted fill
            -- would pass every assertion above and leave a board of three stops.
            assert((counts.combat or 0) + (counts.elite or 0) >= 4,
                "seed " .. seed .. ": a floor is fights with texture between them, not the texture alone")
        end
    end },

    { name = "the blueprint the guarantee resolves is authored-only and one of a kind", fn = function()
        -- The guarantee resolves a KIND to a blueprint off the registry in sorted id order, so a second
        -- `recruit` blueprint would silently decide which one every floor seats. And the weight must be
        -- zero: a positive one would put wanderers on rolled CAMPAIGN boards, where nothing recruits.
        local found = {}
        for id, def in pairs(Encounter.defs) do
            if def.kind == "recruit" then found[#found + 1] = id end
        end
        assert(#found == 1, "expected exactly one recruit blueprint, found " .. #found)
        assert(Encounter.defs[found[1]].weight == 0, found[1] .. " must be authored-only (weight 0)")
    end },

    { name = "every discipline names the hero the floors offer for it", fn = function()
        -- The roster is one authored line per discipline (`hire`, beside the `exemplar` it already
        -- named), so a discipline that landed without one is a hole in the pool that nothing else
        -- reports. The two must also be different bodies: the exemplar is the boss you FIGHT in that
        -- discipline's quest, and offering it as a recruit would put a boss stat line in the company.
        local seen = {}
        for id, def in pairs(Discipline.defs) do
            local hire = def.hire
            assert(hire, id .. " names no hire, so nobody of that discipline is ever met on a floor")
            assert(Character.defs[hire], id .. ": hire " .. tostring(hire) .. " has no blueprint")
            assert(hire ~= def.exemplar, id .. ": the hire must not be the boss body of the same name")
            assert(Character.defs[hire].discipline == id,
                hire .. " is offered as the " .. id .. " but its blueprint says otherwise")
            assert(not seen[hire], hire .. " is the hire of two disciplines")
            seen[hire] = true
        end
    end },

    { name = "heroes are met in the order their disciplines are normally unlocked", fn = function()
        -- WHAT THE CAMPAIGN DECIDES IS THE ORDER: a subclass names a numbered slot in its house's line
        -- and Quest.floorLevelFor turns that into the level a party is expected to hold there. A
        -- discipline earned earlier up top is met no deeper down here than one earned later -- which is
        -- the whole of "when those classes are normally unlocked", and the only thing read off the
        -- campaign. The SPACING is the descent's own (see the case below).
        local function levelOf(id, def)
            if Discipline.arity(id) >= 2 then return math.huge end -- past every subclass by construction
            local level = 1
            for _, questId in ipairs(def.requiredQuests or {}) do
                level = math.max(level, Quest.floorLevelFor(Quest.defs[questId] or {}, questId) or 1)
            end
            return level
        end

        local ranked = {}
        for id, def in pairs(Discipline.defs) do
            local floor = Recruit.floorFor(def.hire)
            assert(floor >= 1 and floor <= Descent.FLOORS,
                id .. " stands on floor " .. floor .. ", which is not a floor of this descent")
            ranked[#ranked + 1] = { id = id, level = levelOf(id, def), floor = floor }
        end

        for _, a in ipairs(ranked) do
            for _, b in ipairs(ranked) do
                if a.level < b.level then
                    assert(a.floor <= b.floor, a.id .. " is earned before " .. b.id ..
                        " in the campaign but is met deeper: floor " .. a.floor .. " vs " .. b.floor)
                end
            end
        end

        -- A multiclass is earned advancement -- its capstone opens only once a subclass of EACH parent
        -- is held (models/discipline.lua) -- so none of them may be met in the first circles, where a
        -- company is still picking up its second and third bodies.
        for _, entry in ipairs(ranked) do
            if entry.level == math.huge then
                assert(entry.floor > Descent.FLOORS_PER_CIRCLE * 2,
                    entry.id .. " is a multiclass met on floor " .. entry.floor ..
                    ", inside the first two circles")
            end
        end
    end },

    { name = "the first floor is the base classes, and every floor under it opens two or three", fn = function()
        -- THE FIRST FLOOR IS THE PLAIN CLASSES. A discipline is earned off a house's line; the class
        -- under it is what a player has from the beginning, so the seven stand at the mouth and nothing
        -- specialized stands beside them.
        local counts = {}
        for _, id in ipairs(Recruit.roster()) do
            local floor = Recruit.floorFor(id)
            counts[floor] = (counts[floor] or 0) + 1
        end

        local first = Recruit.pool(1)
        for _, id in ipairs(first) do
            assert(not Character.defs[id].discipline,
                id .. " is a specialization standing on the first floor, beside the plain classes")
        end
        local classes = {}
        for _, id in ipairs(first) do classes[Character.defs[id].class] = true end
        local n = 0
        for _ in pairs(classes) do n = n + 1 end
        assert(n == #first, "the first floor is one body per class, not two of anything")

        -- AND THE SPACING BELOW IT, which is the reason the campaign's levels are read as an order
        -- rather than as depths. Mapped level-for-level, all twenty-one multiclass heroes arrive on one
        -- floor -- the campaign has no opinion about which of them comes first, and the lump is that
        -- absence showing through. Then eleven of the fifteen floors open nobody at all, and going one
        -- deeper is worth nothing on most of them.
        local specialists = #Recruit.roster() - #first
        local even = specialists / (Descent.FLOORS - 1)
        for floor = 2, Descent.FLOORS do
            local opened = counts[floor] or 0
            assert(opened > 0, "floor " .. floor .. " opens nobody new -- going deeper buys nothing there")
            assert(opened <= math.ceil(even) + 1, "floor " .. floor .. " opens " .. opened ..
                " bodies at once, which is a tier rather than a share")
        end
    end },

    { name = "the pool opens with depth and is whole at the bottom", fn = function()
        -- The first circle offers the plain end of the roster and the deep floors offer all of it, which
        -- is the half of the rule a player actually feels. Monotonic, because the pool is cumulative: a
        -- floor offers everything standing at its depth or above it, never a band.
        local first, bottom = Recruit.pool(1), Recruit.pool(Descent.FLOORS)
        assert(#first > 0, "floor one has somebody standing on it")
        assert(#bottom > #first, "and the bottom of the descent has considerably more")

        assert(#bottom == #Recruit.roster(),
            "every base class and every discipline's hero is on the table by the bottom floor")

        local above = first
        for floor = 2, Descent.FLOORS do
            local pool = Recruit.pool(floor)
            local here = {}
            for _, id in ipairs(pool) do here[id] = true end
            for _, id in ipairs(above) do
                assert(here[id], id .. " stood on floor " .. (floor - 1) .. " and is gone by " .. floor)
            end
            above = pool
        end

        -- The stop asks through Recruit.offer, so the gate has to hold on that path too -- it is the one
        -- states/game.lua actually calls, and a first floor that deals Aldo the Champion is the bug.
        for seed = 1, 30 do
            for _, id in ipairs(Recruit.offer(seed, {}, #first, 1)) do
                assert(not Character.defs[id].discipline,
                    "seed " .. seed .. " put " .. id .. " on a first-floor slate")
            end
        end
    end },

    { name = "a slate reproduces from its seed and offers no body twice", fn = function()
        -- THE STOP OFFERS ONE BODY: somebody is standing there, and you take them on or walk on. The
        -- slate is still a slate underneath -- the Hiring Hall deals three off it -- so the dedup and
        -- reproducibility below are checked at a width where they can actually fail.
        assert(Recruit.OFFER == 1, "a floor puts one body in front of the player, not a shelf")

        -- Dealt from the bottom, where the whole roster is standing: a shallow floor's pool is a couple
        -- of bodies wide by design, which is too narrow for a dedup to fail on even when it is broken.
        local deep = Descent.FLOORS
        local a = Recruit.offer(4242, {}, 3, deep)
        local b = Recruit.offer(4242, {}, 3, deep)
        assert(#a == 3, "a slate is as wide as it was asked for, got " .. #a)
        for i, id in ipairs(a) do
            assert(b[i] == id, "the same seed must deal the same slate on any machine")
        end
        assert(Recruit.offer(4243, {}, nil, deep)[1] ~= a[1]
            or Recruit.offer(9999, {}, nil, deep)[1] ~= a[1],
            "and a different seed must deal a different one")

        local seen = {}
        for _, id in ipairs(a) do
            assert(not seen[id], id .. " is on the slate twice, so it offers fewer bodies than it says")
            seen[id] = true
            assert(Character.defs[id], id .. " is not a real blueprint")
            assert(Recruit.nameOf(id), "and a card must be able to name it")
            assert(#Recruit.describe(id) > 0, "...and to say what it is")
        end
    end },

    { name = "a slate never offers somebody already in the company", fn = function()
        -- Player.recruit refuses a duplicate outright, so an id already on the roster would draw a card
        -- that does nothing when pressed -- which is the one refusal a stop cannot explain.
        local deep = Descent.FLOORS
        local pool = Recruit.pool(deep)
        assert(#pool > Recruit.OFFER + 2, "the pool must be able to fill a slate around exclusions")
        local roster = {}
        for i = 1, 3 do roster[i] = { id = pool[i] } end
        local taken = {}
        for _, char in ipairs(roster) do taken[char.id] = true end

        -- Every seed, not one: an exclusion that only usually holds is a bug that reproduces rarely.
        for seed = 1, 40 do
            for _, id in ipairs(Recruit.offer(seed, roster, nil, deep)) do
                assert(not taken[id], "seed " .. seed .. " offered " .. id .. ", who is already in the company")
            end
        end
        -- Ids or characters: the stop passes a roster, a spec may pass either.
        for _, id in ipairs(Recruit.offer(7, { pool[1], pool[2] }, nil, deep)) do
            assert(id ~= pool[1] and id ~= pool[2], "a list of ids must exclude the same way")
        end
    end },

    { name = "joining lands the body at the company's level, on the descent's ladder", fn = function()
        -- A company that already exists, since a descent's now starts empty: one hire, then a second.
        local profile = Descent.newProfile(Descent.startingCompany())
        Recruit.join(profile, Recruit.offer(99, profile.roster)[1])
        profile.roster[1].xp = 100 -- a body that has fought its way down a couple of floors

        local id = Recruit.offer(1, profile.roster)[1]
        local char = Recruit.join(profile, id)
        assert(char, "the body joined")
        assert(#profile.roster == 2, "and is in the company")
        assert(char.xp == 100, "carrying the company's median experience, not starting from nothing")

        -- THE REASON Recruit.join exists rather than a bare Player.recruit call: the two modes level on
        -- different curves, and resolving descent experience against the campaign's hands a recruit more
        -- levels than the veterans it was measured against.
        local mine = Experience.levelFor(100, Experience.DESCENT_STEP)
        assert(char.level == mine, "a recruit joins at level " .. mine .. ", got " .. tostring(char.level))
        assert(mine < Experience.levelFor(100), "precondition: the two ladders disagree at this xp")

        assert(Recruit.join(profile, id) == nil, "and the same body cannot join twice")
        assert(#profile.roster == 2, "a refused join must not grow the company")
    end },

    { name = "the body the stop draws is the body that joins", fn = function()
        -- The stop shows ONE body whole -- portrait, figures, the kit in its grid (ui/panels/recruit.lua)
        -- -- so the preview it draws has to BE the join, not a level-1 sketch of it. A panel promising 68
        -- health over a body that walks away with 74 is a lie the player can check.
        local profile = Descent.newProfile(Descent.startingCompany())
        Recruit.join(profile, Recruit.offer(99, profile.roster)[1])
        profile.roster[1].xp = 260 -- far enough up the ladder that the median buys levels

        local id = Recruit.offer(1, profile.roster)[1]
        local shown = Recruit.preview(profile, id)
        assert(shown, "somebody is standing there")
        assert(#profile.roster == 1, "and looking at them does not recruit them")

        local joined = Recruit.join(profile, id)
        assert(joined.level == shown.level,
            "the panel showed level " .. shown.level .. ", " .. id .. " joined at " .. joined.level)
        assert(joined.stats.health.max == shown.stats.health.max, "...and the same body under it")
        assert(shown.level > 1, "precondition: the median has to be worth a level or this proves nothing")

        -- What the panel actually lays out: a face, and the kit it will fight from. Neither is optional --
        -- an empty grid would draw a body carrying nothing, which no blueprint in this pool is.
        assert(shown.name and shown.sprite, "a body the player is asked to read needs a name and a face")
        local carried = 0
        for cell = 1, 9 do if shown.inventory[cell] then carried = carried + 1 end end
        assert(carried > 0, id .. " is drawn carrying nothing, so the kit says nothing about them")

        assert(Recruit.preview(profile, "character_nobody_at_all") == nil,
            "and an id no longer naming a blueprint draws nobody rather than crashing the floor")
    end },
}
