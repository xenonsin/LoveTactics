-- Tests for the hiring loop: the vouchers a floor hands up, the pull the Hiring Hall spends one on,
-- and what a second copy of somebody buys (models/voucher.lua).
--
-- THIS REPLACED tests/hall_slate_spec.lua, which pinned the opposite arrangement -- a hall stocked
-- ONLY by the bodies a player had walked past on a floor, and empty until one was refused. What is
-- worth pinning changed with it. That file's cases were about a consequence being recorded honestly;
-- these are about a loop being able to run at all, which is the thing the old one could not do: a
-- company of four never lost anybody, the floor stop only seated while there was room, so the supply
-- of refusals ran dry on the second floor of the first run and the hall was empty for the rest of
-- the save.
--
-- ONE CASE IS INHERITED WHOLE and it is the most important one here: every body the hall can deal
-- carries exactly one bound relic. The old file asserted it to keep generic class templates out of
-- the pool; this one leans on it much harder, because the bound relic is what a DUPLICATE levels and
-- a body without one would pull as a reward that pays nothing.

local Character = require("models.character")
local Descent = require("models.descent")
local Item = require("models.item")
local Recruit = require("models.descent_recruit")
local Voucher = require("models.voucher")

-- A profile with nothing in it. Plain tables rather than Player.new, so a case can say exactly what
-- this player has and nothing else can drift in behind it.
local function profile()
    return { roster = {}, vouchers = 0, bonds = {}, pulls = 0, pity = 0, gold = 0 }
end

-- A deterministic 1..n source, so a case can steer the roll instead of asking it nicely. `seq` is read
-- round-robin and each value is clamped into range, which means `always(1)` picks the first rank and
-- the first candidate every time.
local function always(v)
    return function(n) return math.max(1, math.min(n, v)) end
end

local function has(list, id)
    for _, entry in ipairs(list or {}) do
        if (type(entry) == "table" and entry.id or entry) == id then return true end
    end
    return false
end

return {
    {
        name = "every body the hall can deal carries exactly one bound relic",
        fn = function()
            -- THE INVARIANT THE WHOLE BOND MECHANIC RESTS ON. A duplicate levels "the bound relic" of
            -- the body that came up, so a hero carrying none would pull as a reward that pays nothing,
            -- and one carrying two would have the reward land on whichever cell happened to be first.
            --
            -- It also keeps generic class templates out of the pool, which is what this case was
            -- originally written for: a template is exactly the base a named body sharpens, and what it
            -- lacks is the relic (see character_rogue's own header). The seven base classes are dealt as
            -- Saber and Clem, who have one, and never as Fighter and Rogue, who do not.
            --
            -- NOT `boss`, which was the obvious test and is the wrong one: Amana is a companion the
            -- Cathedral fields against you before she joins, so she carries the flag and is still very
            -- much somebody.
            local pool = Recruit.pool(1000)
            assert(#pool > 0, "somebody is down there")
            for _, id in ipairs(pool) do
                local def = Character.defs[id]
                assert(def, id .. ": the pool names a body that does not exist")

                local relics = {}
                for _, entry in ipairs(def.startingItems or {}) do
                    local itemId = type(entry) == "table" and entry.id or entry
                    local item = type(itemId) == "string" and Item.defs[itemId]
                    if item and item.bound then relics[#relics + 1] = itemId end
                end
                assert(#relics == 1, id .. ": carries " .. #relics .. " bound relics, not one -- a bond"
                    .. " levels exactly one object and this body has no unambiguous answer")
            end

            -- And the templates by name, because that is the instruction in its plainest form.
            local held = {}
            for _, id in ipairs(pool) do held[id] = true end
            for _, id in ipairs({ "character_fighter", "character_knight", "character_rogue",
                "character_mage", "character_priest", "character_alchemist", "character_archer" }) do
                assert(not held[id], id .. " is a generic class template and must never be dealt")
            end
        end,
    },
    {
        name = "every floor sits on a rank, the ranks cover the descent, and nobody sees a floor number",
        fn = function()
            -- THE PLAYER NEVER MEETS A FLOOR NUMBER. Ranks are what every surface prints, and they are
            -- DERIVED from the depth rather than authored beside it -- so a rank can never disagree
            -- with the floor it came from, and moving Descent.FLOORS re-spreads them instead of
            -- leaving a stale table.
            for floor = 1, Descent.FLOORS do
                local s = Voucher.starsOf(floor)
                assert(s >= 1 and s <= Voucher.MAX_STARS,
                    "floor " .. floor .. " ranked " .. s .. ", outside 1.." .. Voucher.MAX_STARS)
            end

            -- Monotonic: deeper is never worth less. The one property the whole scale rests on.
            for floor = 2, Descent.FLOORS do
                assert(Voucher.starsOf(floor) >= Voucher.starsOf(floor - 1),
                    "rank fell going from floor " .. (floor - 1) .. " to " .. floor)
            end

            -- Both ends are reachable, or the scale is narrower than it claims: a five-star nobody can
            -- ever be dealt is a promise the game does not keep.
            assert(Voucher.starsOf(1) == 1, "the shallowest floor is one star")
            assert(Voucher.starsOf(Descent.FLOORS) == Voucher.MAX_STARS,
                "the bottom floor must be worth the top rank")

            -- Every rank has floors in it, and its range agrees with starsOf. A rank covering nothing
            -- would be a gap in the ladder that only shows up as a body nobody can pull.
            for stars = 1, Voucher.MAX_STARS do
                local lo, hi = Voucher.starRange(stars)
                assert(lo and hi and lo <= hi, "rank " .. stars .. " covers no floors")
                assert(Voucher.starsOf(lo) == stars and Voucher.starsOf(hi) == stars,
                    "rank " .. stars .. " range (" .. lo .. ".." .. hi .. ") disagrees with starsOf")
            end

            -- ...and a body's own rank is read off the depth it stands at, so the card and the token
            -- are quoting one number.
            local id = Recruit.pool(1)[1]
            assert(id, "somebody stands on the first floor")
            assert(Voucher.starsForBody(id) == Voucher.starsOf(Recruit.floorFor(id)),
                "a body's rank must be its depth's rank")
        end,
    },
    {
        name = "a beaten circle pays two tokens, and an ordinary floor pays none",
        fn = function()
            -- The unit is the CIRCLE, not the floor: a per-floor drop paid fifteen a run and made any
            -- single one worth nothing to look at. Descent.isGeneralFloor is the same test the run's own
            -- circle tally uses, so the two can never disagree about what a circle is.
            local p = profile()
            local paid = 0
            for floor = 1, Descent.FLOORS do
                local n = Voucher.grantForFloor(p, floor)
                paid = paid + n
                if Descent.isGeneralFloor(floor) then
                    assert(n == Voucher.PER_CIRCLE + Voucher.GENERAL_BONUS,
                        "floor " .. floor .. " is a general's and paid " .. n)
                else
                    assert(n == 0, "floor " .. floor .. " is not a circle's last and paid " .. n)
                end
            end
            assert(Voucher.count(p) == paid, "the purse holds what was granted")
            assert(paid > 0, "a full descent pays something")
        end,
    },
    {
        name = "a won fight rolls a thin chance of a token",
        fn = function()
            -- The other half of the supply, and the half a player can feel between circles. Driven with
            -- an injected roll rather than by running it a thousand times: what needs pinning is that the
            -- boundary is where FIGHT_CHANCE says it is, and a probability test that hopes is a test that
            -- goes red on a Tuesday.
            local pct = math.floor(Voucher.FIGHT_CHANCE * 100 + 0.5)
            assert(pct > 0 and pct < 100, "the fight chance is a chance, not a certainty either way")

            local p = profile()
            assert(Voucher.rollFromFight(p, always(pct)), "a roll of " .. pct .. " must drop")
            assert(not Voucher.rollFromFight(p, always(pct + 1)), "a roll past the chance must not drop")
            assert(not Voucher.rollFromFight(p, always(100)), "the worst roll never drops")
            assert(Voucher.rollFromFight(p, always(1)), "the best roll always drops")
            assert(Voucher.count(p) == 2, "only the two winning rolls granted")
        end,
    },
    {
        name = "a token is a count and nothing else, and the purse never goes negative",
        fn = function()
            -- THE WHOLE OF WHAT "A TOKEN HAS NO RANK" MEANS IN STORAGE. There is nothing to tell one
            -- from another, so the purse is a number -- and every path that hands one over or takes one
            -- away has to agree about that or the count drifts.
            local p = profile()
            assert(Voucher.count(p) == 0, "an empty purse reads zero")
            assert(not Voucher.spend(p), "an empty purse has nothing to spend")
            assert(Voucher.count(p) == 0, "...and spending nothing does not go below zero")

            Voucher.grant(p, 3)
            assert(Voucher.count(p) == 3, "three granted, three held")
            assert(Voucher.spend(p), "a held token spends")
            assert(Voucher.count(p) == 2, "and the count falls by exactly one")

            Voucher.grant(p)
            assert(Voucher.count(p) == 3, "granting with no number hands over one")
        end,
    },
    {
        name = "the rank odds are a whole hundred, and every rank is reachable",
        fn = function()
            -- A TABLE THAT DRIFTED TO 99 would silently make the last rank unreachable, which is the
            -- failure nobody sees: the game keeps working, five-stars just stop existing, and the only
            -- symptom is a player who never gets one.
            local total = 0
            for i = 1, Voucher.MAX_STARS do
                local pct = Voucher.RANK_ODDS[i]
                assert(pct and pct > 0, "rank " .. i .. " has no odds, so nobody can ever roll it")
                total = total + pct
            end
            assert(total == 100, "the odds must sum to 100, got " .. total)
            assert(#Voucher.RANK_ODDS == Voucher.MAX_STARS,
                "one entry per rank: " .. #Voucher.RANK_ODDS .. " vs " .. Voucher.MAX_STARS)

            -- Rarer as it climbs. Not strictly required by anything, but a ladder whose middle was
            -- scarcer than its top would make the five-star mean nothing.
            for i = 2, Voucher.MAX_STARS do
                assert(Voucher.RANK_ODDS[i] <= Voucher.RANK_ODDS[i - 1],
                    "rank " .. i .. " is commoner than rank " .. (i - 1))
            end

            -- ...and every rank has somebody standing in it, or the roll walks down and the odds are a
            -- fiction.
            for stars = 1, Voucher.MAX_STARS do
                assert(#Voucher.candidatesAt(stars) > 0,
                    "rank " .. stars .. " has nobody in it, so a roll of it deals a lesser body")
            end
        end,
    },
    {
        name = "the roll picks a rank by the odds, and deals a body that wears it",
        fn = function()
            -- always(1) takes the first rank in the table and the first candidate in it; always(100)
            -- walks to the far end of the weights. Between them they pin that the table is being read
            -- as a cumulative range rather than sampled some other way.
            local id, stars = Voucher.rollWith(always(1), false)
            assert(stars == 1, "the lowest roll takes the first rank, got " .. tostring(stars))
            assert(id and Voucher.starsForBody(id) == 1, "and deals a body that actually wears it")

            local topId, topStars = Voucher.rollWith(always(100), false)
            assert(topStars == Voucher.MAX_STARS,
                "the highest roll takes the last rank, got " .. tostring(topStars))
            assert(topId and Voucher.starsForBody(topId) == Voucher.MAX_STARS,
                "and deals a body that wears the top rank")
        end,
    },
    {
        name = "pity refuses the bottom ranks without costing the best one",
        fn = function()
            -- The guarantee is "PITY_RANK or better", not "exactly PITY_RANK" -- a pity pull that could
            -- no longer reach the top would take the best outcome away from exactly the player it is
            -- apologising to.
            local sawTop = false
            for pick = 1, 200 do
                local _, stars = Voucher.rollWith(always(pick), true)
                assert(stars >= Voucher.PITY_RANK,
                    "a pity pull dealt rank " .. stars .. ", under " .. Voucher.PITY_RANK)
                if stars == Voucher.MAX_STARS then sawTop = true end
            end
            assert(sawTop, "pity closed the top rank off entirely")
        end,
    },
    {
        name = "a pull spends a token, advances the seed, and does not reroll on a second look",
        fn = function()
            -- THE SAVE-SCUM GUARD. Every other roll in a descent is pinned to a cell so walking away and
            -- back cannot reroll it; a pull needs that AND the opposite -- a reload must not fish for a
            -- better body. The seed is (salt, pull count) and the count moves on the SPEND.
            local p = profile()
            Voucher.grant(p, 1)

            local peekedA = Voucher.peek(p)
            local peekedB = Voucher.peek(p)
            assert(peekedA == peekedB, "looking twice dealt two different bodies")

            local result = Voucher.pull(p)
            assert(result, "a held token pulls")
            assert(result.id == peekedA, "the pull dealt somebody other than what the reveal was shown")
            assert(result.stars == Voucher.starsForBody(result.id), "the result carries the body's rank")
            assert(Voucher.count(p) == 0, "the token was spent")
            assert(p.pulls == 1, "the pull counter advanced")

            -- And an empty purse pulls nothing.
            local again, why = Voucher.pull(p)
            assert(not again and why == "empty", "an empty purse pulled anyway")
        end,
    },
    {
        name = "a first copy joins the company and a second bonds instead",
        fn = function()
            local p = profile()
            Voucher.grant(p, 1)
            local first = Voucher.pull(p)
            assert(first and not first.dupe, "the first copy of somebody is a join")
            assert(has(p.roster, first.id), "...and they are in the company")
            assert(Voucher.bondOf(p, first.id) == 0, "a body held once has no spare copies")

            -- Force the same body again by rigging, which is the seam the tutorial uses and the only
            -- honest way to make a random pull land on a chosen id.
            Voucher.grant(p, 1)
            p.riggedPull = first.id
            local second = Voucher.pull(p)
            assert(second and second.dupe, "the second copy must read as a duplicate")
            assert(Voucher.bondOf(p, first.id) == 1, "the bond was recorded")
            assert(#p.roster == 1, "a duplicate must not put a second body in the company")
        end,
    },
    {
        name = "a bond levels the bound relic in place, one rung at a time, to a ceiling",
        fn = function()
            local p = profile()
            Voucher.grant(p, 1)
            p.riggedPull = "character_saber"
            local joined = Voucher.pull(p)
            assert(joined and joined.char, "Saber joined")

            local relic, cell = Voucher.relicOf(joined.char)
            assert(relic and cell, "she carries a bound relic")
            assert((relic.level or 0) == 0, "a first copy arrives at the base level")

            for want = 1, 3 do
                Voucher.grant(p, 1)
                p.riggedPull = "character_saber"
                local again = Voucher.pull(p)
                assert(again.dupe, "copy " .. (want + 1) .. " is a duplicate")
                local now, atCell = Voucher.relicOf(joined.char)
                assert((now.level or 0) == want,
                    "bond " .. want .. " left the relic at " .. (now.level or 0))
                assert(atCell == cell, "the relic moved cell: a bound item is welded where it sits")
                -- The BODY is the same table throughout. A pull that rebuilt the character would read as
                -- an arrival to every view keying its side tables off table identity.
                assert(again.char == joined.char, "the bonded body was rebuilt rather than re-stamped")
            end

            -- ...and the ladder has a top, past which a duplicate pays out sideways instead.
            p.bonds["character_saber"] = Voucher.BOND_MAX
            Voucher.grant(p, 1)
            p.riggedPull = "character_saber"
            local over = Voucher.pull(p)
            assert(over.overflow, "a copy past the ceiling must say so")
            assert(Voucher.bondOf(p, "character_saber") == Voucher.BOND_MAX, "the ceiling held")
            assert(Voucher.count(p) == 1,
                "a maxed body hands the token straight back rather than charging for nothing")
        end,
    },
    {
        name = "the first bond's growth is paid once and rides the table a save rebuilds from",
        fn = function()
            -- A ROSTER IS NOT SAVED AS STAT LINES. models/save.lua stores each body's accumulated
            -- growth and rebuilds it through Character.instantiate, so a bump written straight onto
            -- char.stats survives exactly until the next save. The packet goes into char.growth (which
            -- persists and is re-baked) AND onto the live stats (which nothing is going to rebuild), and
            -- char.bonded is the mark that stops the next applyBond paying it a second time.
            local p = profile()
            Voucher.grant(p, 1)
            p.riggedPull = "character_saber"
            local joined = Voucher.pull(p)
            local char = joined.char
            assert((char.bonded or 0) == 0, "a first copy has no bond growth")
            local baseHealth = char.stats.health.max
            local baseGrowth = (char.growth or {}).health or 0

            Voucher.grant(p, 1)
            p.riggedPull = "character_saber"
            Voucher.pull(p)
            assert(char.bonded == 1, "the first bond marked the body")
            assert(char.stats.health.max == baseHealth + Voucher.BOND_GROWTH.health,
                "the live pool did not move")
            assert((char.growth.health or 0) == baseGrowth + Voucher.BOND_GROWTH.health,
                "the growth table a save rebuilds from did not move")

            -- Applying it again pays nothing, which is what a load-then-pull must not be able to do.
            Voucher.applyBond(p, char)
            Voucher.applyBond(p, char)
            assert(char.stats.health.max == baseHealth + Voucher.BOND_GROWTH.health,
                "the bond packet was paid twice")
        end,
    },
    {
        name = "the sponsor's stake is one voucher, once, and it calls the body the story picked",
        fn = function()
            -- The opening pull is rigged and every game in this genre rigs it: what the tutorial is
            -- teaching is what a pull LOOKS like, and a lesson delivered by a roll teaches a different
            -- thing to every player.
            local p = profile()
            assert(Voucher.stake(p, "character_saber"), "the sponsor stakes a token")
            assert(Voucher.count(p) == 1, "one token")
            assert(not Voucher.stake(p, "character_saber"), "staking twice is refused")
            assert(Voucher.count(p) == 1, "...and puts no second token in the purse")

            local id = Voucher.peek(p)
            assert(id == "character_saber", "the staked token calls the body the story picked")

            local result = Voucher.pull(p)
            assert(result.id == "character_saber", "and the pull deals her")
            assert(p.riggedPull == nil, "the rig is spent by the pull that read it")

            -- The next pull is an honest roll again.
            Voucher.grant(p, 1)
            local next = Voucher.peek(p)
            assert(next ~= nil, "the hall deals normally once the stake is spent")
        end,
    },
    {
        name = "a bench refuses a bound relic, and takes everything else it always did",
        fn = function()
            -- THE OTHER HALF OF THE BOND. A duplicate is the only ladder onto a bound relic now, so the
            -- bench has to be shut: two ladders onto one object and the cheaper one decides what it is
            -- worth. This file asserts it rather than tests/forge_spec.lua because the reason lives
            -- here -- the bench's own header now points at models/voucher.lua for it.
            local Forge = require("models.forge")
            local saber = Character.instantiate("character_saber")
            local relic = Voucher.relicOf(saber)
            assert(relic, "Saber carries a bound relic")
            assert(not Forge.canWork(relic), "the bench must refuse a bound relic")

            -- ...and an ordinary piece off the same body still works, so this is a rule about `bound`
            -- rather than a bench that stopped taking anything.
            local ordinary
            for cell = 1, Character.MAX_INVENTORY do
                local item = saber.inventory and saber.inventory[cell]
                if item and not Item.isBound(item) and Item.isUpgradable(item)
                    and (item.type == "weapon" or item.type == "armor"
                        or item.type == "utility" or item.type == "ability") then
                    ordinary = item
                end
            end
            if ordinary then
                assert(Forge.canWork(ordinary),
                    "the bench stopped taking ordinary gear: the lock is too wide")
            end
        end,
    },
}
