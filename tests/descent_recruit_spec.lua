-- Tests for WHO a descent can put in a company and how deep each one stands -- the census half of
-- recruitment (models/descent_recruit.lua). The other half, the vouchers a floor hands up and the pull
-- that spends one, is tests/voucher_spec.lua.
--
-- SEVERAL CASES HERE PIN AN ABSENCE, and that is deliberate. A descent used to grow its company by
-- meeting people on the floors -- a guaranteed stop, one body, taken on or walked past -- and that stop
-- is removed. The removal is worth specs because it latched shut in a way nothing reported: a company of
-- four never lost anybody, the stop only seated while there was room, so from the second floor of the
-- first run the game silently stopped offering anyone. An absence that used to be a feature needs a case
-- saying so, or it comes back the next time somebody reads the old prose.

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

        -- PARTY_MAX IS THE FIELD AND NOT THE ROSTER, which is the reversal the Hiring Hall's pull was
        -- built on (models/voucher.lua). It used to be both: four held, ever, no bench -- and that made
        -- recruitment latch shut, because nothing ever left a company of four and the floors stopped
        -- offering the moment it filled.
        assert(Descent.PARTY_MAX == Player.MAX_FIELD,
            "the board cap must be the field: " .. Descent.PARTY_MAX .. " vs " .. Player.MAX_FIELD)

        -- ...and the function that used to ask "is there room for one more" is GONE rather than always
        -- returning true. Pinned as an absence because a branch that cannot be false is the shape this
        -- bug took the first time: every caller read it, every caller believed it, and the answer
        -- stopped being a question years before anybody noticed.
        assert(Descent.hasRoom == nil,
            "Descent.hasRoom must not come back: the roster is unbounded and the question has one answer")
    end },

    { name = "a slate reproduces from its seed and offers no body twice", fn = function()
        -- THE STOP OFFERS ONE BODY: somebody is standing there, and you take them on or walk on. Nothing
        -- deals wider than that any more -- the Hiring Hall did, and it is gone -- but the dedup and
        -- reproducibility below are still checked at width 3, because a slate of one cannot fail a dedup
        -- even when the dedup is broken.
        assert(Recruit.OFFER == 1, "a floor puts one body in front of the player, not a shelf")

        local deep = Descent.FLOORS
        local a = Recruit.offer(4242, {}, 3, deep)
        local b = Recruit.offer(4242, {}, 3, deep)
        assert(#a == 3, "a slate is as wide as it was asked for, got " .. #a)
        for i, id in ipairs(a) do
            assert(b[i] == id, "the same seed must deal the same slate on any machine")
        end

        -- A DIFFERENT SEED MUST DEAL A DIFFERENT SLATE, asked over a spread of seeds rather than two.
        -- The roster is SEVEN now, one per house, where it was forty-five: two seeds colliding on the
        -- same first body went from a 0.05% coincidence to a 2% one, and this case was failing on the
        -- coincidence rather than on the shuffle. Asking eight seeds for any difference at all keeps
        -- the property while making the sample honest about the pool it is drawn from.
        local differs = false
        for _, s in ipairs({ 4243, 9999, 17, 88, 1234, 5, 60007, 31 }) do
            if Recruit.offer(s, {}, nil, deep)[1] ~= a[1] then differs = true break end
        end
        assert(differs, "every seed dealt the same body -- the shuffle is not reading the seed")

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

        -- WHAT A RECRUIT ARRIVES AT. The median is resolved on the game's one curve (Experience.STEP),
        -- so a body hired at the gate reads its inherited bank exactly as the veterans it was measured
        -- against read theirs. This assertion used to name a descent-only step; that ladder is gone.
        local mine = Experience.levelFor(100)
        assert(char.level == mine, "a recruit joins at level " .. mine .. ", got " .. tostring(char.level))

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
