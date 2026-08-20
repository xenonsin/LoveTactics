-- HIRING TOKENS: what a floor hands up, what the Crossing does with one, and what a second copy of
-- somebody is worth.
--
-- The descent used to grow its company by MEETING people: a stop on every floor where a survivor was
-- standing, taken on or walked past, and a hall downstream of it selling back the ones you refused.
-- That latched shut. A company held four, nothing ever left it, and the floors stopped seating the stop
-- the moment it was full -- so from the second floor of the first run the player met nobody, refused
-- nobody, and the hall stayed empty for the rest of the game. Forty-five authored bodies, three of them
-- ever seen.
--
-- So the floors hand up a TOKEN instead of a person, and the rift spends it on a pull.
--
-- A TOKEN HAS NO RANK. Every one is identical, and the rarity is rolled at the moment the player
-- presses the button -- not carried on the ticket. That is the second time this has been simplified and
-- the reasoning is worth keeping, because the first arrangement looked better on paper:
--
--   A token used to be GRADED at the floor it fell on, and the roll banded around that grade -- a deep
--   token mostly dealt deep bodies, with a small chance of overshooting. It made depth do two jobs at
--   once (how MANY tokens, and how GOOD each one), which reads as elegant and plays as arithmetic: the
--   player ends up holding a purse of differently-priced tickets, sorting them, deciding which to spend
--   and which to hold. The crossing stopped being a moment and became a transaction.
--
--   Rankless tokens put the two jobs back where they belong. DEPTH BUYS QUANTITY -- a circle pays two,
--   a spirit stands on every floor, a won fight rolls a tenth -- and THE ROLL BUYS QUALITY, at fixed
--   published-if-anybody-asked odds. Going deeper still makes your company better; it does it by
--   handing you more chances rather than better ones.
--
-- WHAT IS STILL RANKED IS THE BODY. Every one of the forty-five sits on a five-star ladder derived from
-- how deep it stands (Voucher.starsForBody), and that rank is what the reveal strikes in as pips and
-- what the card names. The ticket says nothing; the arrival says everything.
--
-- IT IS A PACING DEVICE WEARING A GACHA'S CLOTHES. Nothing here is sold for money and nothing here ever
-- will be, so none of the genre's scarcity machinery is load-bearing: the rates are generous, the pity
-- is short, and what makes a pull worth watching is the reveal rather than the ache of missing. Tune
-- this module toward "another one already?" and never toward "finally".
--
-- Pure model -- no love.graphics, no love.filesystem -- so it loads under the headless runner.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Recruit = require("models.descent_recruit")

local Voucher = {}

-- ---------------------------------------------------------------------------
-- THE PURSE: how many tokens, and nothing else about them
-- ---------------------------------------------------------------------------

-- `player.vouchers` is a NUMBER. It was a list of `{ floor = n }` while tokens carried a grade, and
-- collapsing it to a count is most of what "a token has no rank" means in storage: there is nothing to
-- tell one from another, so there is nothing to keep a list of. models/save.lua folds the old list into
-- a count on load, so a save written before this reads as however many tickets it was holding.

-- Where tokens come from, and it is deliberately three places with three different rhythms.
--
-- A CIRCLE CLEARED PAYS TWO, graded at nothing and earned on a schedule the player can count toward.
-- A GENERAL'S FLOOR is that circle's last, so both halves land together -- see Voucher.grantForFloor.
Voucher.PER_CIRCLE = 1
Voucher.GENERAL_BONUS = 1

-- ...AND A THIN CHANCE OFF ANY WON FIGHT, which does a different job to the circle payout. A circle is
-- a milestone: it pays on schedule and the purse only moves at seven moments in a run. Between them
-- nothing a company does bears on whether it grows. Ten percent is deliberately low -- it must never
-- become the reason to clear a board, only a thing that occasionally happens on the way.
Voucher.FIGHT_CHANCE = 0.10

-- The default randomness. love.math when there is a LOVE, math.random otherwise, so the headless
-- runner can require this file -- the same fallback models/relic.lua uses for its drop rolls.
local function defaultRand(n)
    if love and love.math and love.math.random then return love.math.random(n) end
    return math.random(n)
end

-- How many tokens `player` is holding.
function Voucher.count(player)
    return math.max(0, math.floor(tonumber((player or {}).vouchers) or 0))
end

-- Hand `player` `n` tokens (default one). Returns the new count.
function Voucher.grant(player, n)
    if not player then return 0 end
    player.vouchers = Voucher.count(player) + math.max(1, math.floor(tonumber(n) or 1))
    return player.vouchers
end

-- Take one out of the purse. Returns true if there was one to take.
function Voucher.spend(player)
    if Voucher.count(player) <= 0 then return false end
    player.vouchers = Voucher.count(player) - 1
    return true
end

-- WHAT A FLOOR PAYS, WITHOUT PAYING IT. Split off from grantForFloor below because the victory screen
-- has to NAME the tokens on the same beat as the body's own piece, and it draws that screen before the
-- grant runs -- so the count has to be askable twice and land once. Pure: reads a floor number, touches
-- no profile.
--
-- Takes no player on purpose. What a floor pays is a property of where the floor sits in its circle and
-- of nothing about the company standing on it, so a signature that could not consult one is the honest
-- one -- and it is what makes the preview and the grant incapable of disagreeing.
function Voucher.forFloor(floor)
    if not floor then return 0 end
    -- The LAST floor of a circle is the one that pays: a circle cleared, not a floor walked.
    -- Descent.isGeneralFloor is exactly that test -- she stands on the last floor of her stratum -- so
    -- the two constants below are one floor paying twice rather than two different floors.
    if not Descent.isGeneralFloor(floor) then return 0 end
    return Voucher.PER_CIRCLE + Voucher.GENERAL_BONUS
end

-- What a cleared floor is worth, granted straight onto the profile. Called once per floor cleared, and
-- it decides for itself whether this floor pays at all -- the caller has a floor number and nothing
-- else to reason with, and the answer is a property of where the floor sits in its circle.
--
-- Returns the number granted (0 or 2), so a caller can say so on the landing.
function Voucher.grantForFloor(player, floor)
    if not (player and floor) then return 0 end
    local n = Voucher.forFloor(floor)
    if n > 0 then Voucher.grant(player, n) end
    return n
end

-- Roll a won fight for a token. Returns true for the one time in ten that something falls.
--
-- `rand(n)` is a 1..n integer source, defaulted above and injectable so a spec can force either
-- outcome without running the roll a thousand times and hoping.
--
-- The CALLER decides what counts as a fight (states/game.lua's grantSideSpoils, the one seam every won
-- fight passes through -- road fight, walked-off fight and guardian alike). This function does not know
-- what a battle is and must not learn: it is a chance and a grant.
function Voucher.rollFromFight(player, rand)
    if not player then return false end
    rand = rand or defaultRand
    local pct = math.floor(Voucher.FIGHT_CHANCE * 100 + 0.5)
    if rand(100) > pct then return false end
    Voucher.grant(player, 1)
    return true
end

-- ---------------------------------------------------------------------------
-- RANKS: the ladder the BODIES sit on
-- ---------------------------------------------------------------------------

-- Five ranks over the descent's fifteen floors, three floors to a rank. Derived from how deep a body
-- stands, never stored, so a rank cannot disagree with the depth it came from -- and if Descent.FLOORS
-- ever moves, the ranks re-spread themselves rather than going stale.
--
--   *      floors 1-3     the seven base classes, and the shallowest subclasses
--   **     floors 4-6
--   ***    floors 7-9
--   ****   floors 10-12
--   *****  floors 13-15   the deepest cut in the game
Voucher.MAX_STARS = 5

-- What a body standing at `floor` is worth, 1..MAX_STARS.
function Voucher.starsOf(floor)
    local span = math.max(1, math.ceil(Descent.FLOORS / Voucher.MAX_STARS))
    local n = math.ceil((math.max(1, floor or 1)) / span)
    return math.max(1, math.min(Voucher.MAX_STARS, n))
end

-- The shallowest and deepest floor a rank covers, for a caller that wants to say what a rank IS.
function Voucher.starRange(stars)
    local span = math.max(1, math.ceil(Descent.FLOORS / Voucher.MAX_STARS))
    local hi = math.min(Descent.FLOORS, stars * span)
    return (stars - 1) * span + 1, hi
end

-- How many stars `charId` wears -- the body's own rank, read off the depth it stands at. What the
-- reveal strikes in as pips and what the card names.
function Voucher.starsForBody(charId)
    return Voucher.starsOf(Recruit.floorFor(charId))
end

-- ---------------------------------------------------------------------------
-- THE ROLL
-- ---------------------------------------------------------------------------

-- THE ODDS, as whole percents, one per rank. They sum to 100 and a spec pins that they do -- a table
-- that drifted to 99 would silently make the last rank unreachable, which is the failure nobody sees.
--
-- Shaped so the bottom two ranks are most of what a player collects (they are the base classes and the
-- shallow subclasses, and a company needs bodies before it needs deep ones) while the top is genuinely
-- scarce. Two percent means a five-star is a handful of pulls a playthrough rather than a thing you
-- work toward, which is the correct weight for the deepest cut in the game.
Voucher.RANK_ODDS = { 45, 30, 15, 8, 2 }

-- Pulls without a three-star-or-better before one is guaranteed. Short, because there is no money in
-- this: pity here is a promise that a bad streak ends, not a lever that makes one hurt first.
Voucher.PITY = 10
Voucher.PITY_RANK = 3

-- Pick a rank, 1..MAX_STARS. `rand(n)` is a 1..n integer source. `forcePity` throws away everything
-- below PITY_RANK and reweights what is left, so a pity pull can still land the rarest rank -- the
-- guarantee must never cost the player the best outcome.
function Voucher.rollRank(rand, forcePity)
    rand = rand or defaultRand
    local first = forcePity and Voucher.PITY_RANK or 1
    local total = 0
    for i = first, Voucher.MAX_STARS do total = total + (Voucher.RANK_ODDS[i] or 0) end
    if total <= 0 then return first end

    local pick = rand(total)
    for i = first, Voucher.MAX_STARS do
        pick = pick - (Voucher.RANK_ODDS[i] or 0)
        if pick <= 0 then return i end
    end
    return Voucher.MAX_STARS
end

-- Everybody who wears exactly `stars`, as character ids.
--
-- Sorted, and filtered through Save.known, for the reason Recruit.pool does both: a pull has to deal
-- the same body from the same seed on any machine, and a discipline whose hero blueprint has not landed
-- yet must be skipped rather than offered as a name that cannot be built.
--
-- NOT filtered against the roster. That is the mechanic: a body you already hold is a legal result and
-- a good one (see BONDS).
function Voucher.candidatesAt(stars)
    local Save = require("models.save")
    local out = {}
    for _, id in ipairs(Recruit.roster()) do
        if Voucher.starsForBody(id) == stars and Save.known(Character.defs, id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

-- Roll a rank and then a body inside it, as (id, stars). Pure: it takes its randomness in and mutates
-- nothing, so a caller can dry-run it and a spec can pin it.
--
-- A RANK WITH NOBODY IN IT WALKS DOWN rather than re-rolling: rank 1 always has the seven base classes
-- in it, so the fallback terminates. This can only happen while a rank's blueprints are unlanded.
function Voucher.rollWith(rand, forcePity)
    rand = rand or defaultRand
    local stars = Voucher.rollRank(rand, forcePity)
    for s = stars, 1, -1 do
        local ids = Voucher.candidatesAt(s)
        if #ids > 0 then return ids[rand(#ids)], s end
    end
    return nil, stars
end

-- The per-profile salt every pull is seeded off, minted once and then kept.
--
-- WHY A PULL IS SEEDED DIFFERENTLY TO EVERYTHING ELSE DOWN HERE. The descent pins its randomness to a
-- cell (the merchant's stock, the reliquary's slate) so walking off a tile and back on cannot reroll
-- it. A pull needs that same property -- opening and closing the rift must not deal a new body -- and
-- the opposite one as well: a player who reloads the save must not be able to fish for a better result.
-- So the seed is (salt, pull count), the count advances when a token is SPENT, and the salt is minted
-- per profile rather than fixed, because a fixed one would give every playthrough the same sequence and
-- a player would learn which pull number is the good one.
local function saltOf(player)
    if not player.pullSalt then
        local r = (love and love.math and love.math.random) or math.random
        player.pullSalt = r(1, 2 ^ 24)
    end
    return player.pullSalt
end

-- What the next pull WOULD deal, without spending anything. The reveal opens on the result, so the
-- panel needs it before the player has committed to watching -- and pinning it here rather than rolling
-- at the end of the animation is what stops a closed panel from rerolling.
function Voucher.peek(player)
    if not player then return nil end
    local rand = Combat.newRandom(saltOf(player) + (player.pulls or 0) * 7919)
    return Voucher.rollWith(rand, (player.pity or 0) >= Voucher.PITY - 1)
end
-- ---------------------------------------------------------------------------
-- BONDS: what the second copy is worth
-- ---------------------------------------------------------------------------

-- EVERY ONE OF THE FORTY-FIVE CARRIES EXACTLY ONE BOUND ITEM, and that is not a coincidence this
-- module is relying on by luck -- it is the shape the roster was authored in. Saber's First Motion,
-- Rowan's Sworn Aegis, Fen's Ground Given, Pim's Bag of Holding: one object per body, welded to its
-- cell by Item.isBound, the thing that body is built around. tests/voucher_spec.lua pins the invariant,
-- so a hero authored later without one fails the build rather than quietly pulling a dupe that pays
-- nothing.
--
-- A DUPLICATE LEVELS THAT ONE OBJECT, and it is now the ONLY thing that levels it: the bench refuses a
-- bound item outright (models/forge.lua's Forge.canWork). Gold and technique buy breadth and depth
-- across the shelf; the one item that is a body's identity is bought with the body turning up again.
--
-- FRONT-LOADED, because a ladder ten rungs long paid a tenth at a time is a ladder nobody feels
-- climbing. The FIRST bond is the one that lands: a rung on the relic AND a step on the body itself.
-- Every bond after it is a rung, which is the long tail and is meant to read as one.
Voucher.BOND_MAX = Item.MAX_LEVEL

-- What the first bond puts on the BODY, on top of the relic rung it also buys.
--
-- Flat points rather than a share, and small ones. This rides the same seam a level-up's growth rides
-- (Character.instantiate's `progress.growth`), so it is the same kind of quantity the player already
-- reads on the sheet -- and it has to stay small, because it is granted per body and never taken away:
-- a company thirty pulls deep must not be a company of statistically different people.
Voucher.BOND_GROWTH = { health = 8, damage = 2, defense = 1 }

-- How many duplicates of `id` this profile has taken. 0 for a body held once, and 0 for one not held
-- at all -- "how many spare copies" rather than "how many copies".
function Voucher.bondOf(player, id)
    return ((player and player.bonds) or {})[id] or 0
end

-- The level `id`'s bound relic stands at: one rung per bond, capped. Read rather than stored on the
-- item, so a roster rebuilt from a save re-derives it instead of carrying a number that could disagree
-- with the ledger.
function Voucher.relicLevel(player, id)
    return math.min(Voucher.BOND_MAX, Voucher.bondOf(player, id))
end

-- Is this body's ladder finished? Past it a duplicate pays out sideways (see Voucher.pull).
function Voucher.bondMaxed(player, id)
    return Voucher.bondOf(player, id) >= Voucher.BOND_MAX
end

-- The one bound item in `char`'s grid, as (item, cell), or nil. THE definition of "this body's relic"
-- for every reader, so a body that somehow carries two has the first cell win rather than each caller
-- picking differently.
function Voucher.relicOf(char)
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory and char.inventory[cell]
        if item and Item.isBound(item) then return item, cell end
    end
    return nil
end

-- Bring `char`'s bound relic up to the level the ledger says it stands at, in place.
--
-- RE-STAMPED ONTO THE LIVE BODY, never rebuilt around it: the party panel and the inventory grid key
-- their side tables by table identity, so a character swapped out from under them reads as an arrival
-- and loses its selection. The ITEM is re-instantiated (Item.instantiate is how a level change is
-- realized anywhere -- Forge.upgrade does exactly this) and dropped back into the cell it came from,
-- which is a change to the grid's contents and not to the body holding it.
--
-- Idempotent, and called on every recruit as well as on every dupe: a body that joins already bonded
-- (pulled, released, pulled again) must arrive at the level its ledger says rather than at zero.
function Voucher.applyRelic(player, char)
    if not (player and char) then return nil end
    local item, cell = Voucher.relicOf(char)
    if not item then return nil end
    local want = Voucher.relicLevel(player, char.id)
    if (item.level or 0) == want then return item end
    local fresh = Item.instantiate(item.id, item.quantity, want)
    char.inventory[cell] = fresh
    return fresh
end

-- What the first bond adds to the body, applied once and only once.
--
-- IT GOES INTO `char.growth`, NOT ONTO `char.stats`, and that is the whole reason this function is
-- five lines longer than it looks like it should be. A roster is not saved as a set of stat lines --
-- models/save.lua stores each body's ACCUMULATED GROWTH and rebuilds it through Character.instantiate,
-- which re-bakes that growth onto the blueprint's base. So a bump written straight onto the live stats
-- is a bump that survives exactly until the next save, and a player who reloaded would find their
-- bonded veteran quietly back to base.
--
-- Written into the growth table it also has to go onto the live stats, because the body standing in
-- the roster right now was baked before this ran and nothing is going to rebuild it (a rebuilt object
-- reads as an arrival to every view keying off table identity).
--
-- `char.bonded` is the guard and it is persisted beside the growth: it records how many bonds' worth of
-- growth this body's table already contains, so a save/load cycle cannot pay the packet twice. A body
-- released and pulled back is a fresh instance with no mark and fresh stats, which is the correct
-- reading of both.
function Voucher.applyGrowth(player, char)
    if not (player and char) then return false end
    if (char.bonded or 0) >= 1 then return false end
    if Voucher.bondOf(player, char.id) < 1 then return false end

    char.growth = char.growth or {}
    for stat, amount in pairs(Voucher.BOND_GROWTH) do
        char.growth[stat] = (char.growth[stat] or 0) + amount
        local live = char.stats and char.stats[stat]
        if type(live) == "table" then
            live.max = (live.max or 0) + amount
            live.current = live.max
        elseif type(live) == "number" then
            char.stats[stat] = live + amount
        end
    end
    char.bonded = 1
    return true
end

-- Both halves, for a body that is in the company right now. The one call every other path makes.
function Voucher.applyBond(player, char)
    Voucher.applyGrowth(player, char)
    Voucher.applyRelic(player, char)
    return char
end

-- The live roster instance of `id`, or nil.
local function held(player, id)
    for _, char in ipairs((player and player.roster) or {}) do
        if char.id == id then return char end
    end
    return nil
end
-- ---------------------------------------------------------------------------
-- THE PULL: one token, spent
-- ---------------------------------------------------------------------------

-- Spend a token and take what it deals. THE one door -- tokens are not consumed anywhere else and
-- bodies do not join anywhere else.
--
-- Takes no token ARGUMENT any more, because there is nothing to choose between: every token is the
-- same token. The panel used to hand in the deepest of a graded purse; now it presses a button and
-- this decides everything.
--
-- Returns a result table, or nil plus a reason ("empty", "nobody"):
--
--   { id, name, stars, dupe, char, bond, relic, relicLevel, overflow }
--
--   stars       the rank rolled, 1..MAX_STARS -- what the reveal strikes in and the card names
--   dupe        the body was already in the company, so this pull was a bond rather than a join
--   char        the live roster instance either way -- the reveal draws the body that is now yours
--   bond        the bond count AFTER this pull
--   relic       the bound item at its new level, or nil for a body that somehow has none
--   overflow    true when the ladder was already finished and the pull paid out sideways instead
--
-- ORDERED SO THE LEDGER MOVES BEFORE THE BODY DOES. The bond count is written first and the relic is
-- stamped off the count, so the two can never disagree -- and a crash between them leaves a ledger a
-- later Voucher.applyBond will settle, rather than a relic claiming a rung nothing paid for.
function Voucher.pull(player)
    if not player then return nil, "empty" end
    if not Voucher.spend(player) then return nil, "empty" end

    local id, stars = Voucher.peek(player)
    -- Advance the counter whatever happened: a pull that dealt nothing still spent a token, and a seed
    -- that did not move would deal the same nothing again.
    player.pulls = (player.pulls or 0) + 1
    if not id then return nil, "nobody" end

    -- Pity: cleared by anything at PITY_RANK or better, ticked by anything under it.
    player.pity = (stars >= Voucher.PITY_RANK) and 0 or ((player.pity or 0) + 1)

    local existing = held(player, id)
    local result = { id = id, name = Recruit.nameOf(id) or id, stars = stars, dupe = existing ~= nil }

    if existing then
        player.bonds = player.bonds or {}
        local was = Voucher.bondOf(player, id)
        if was >= Voucher.BOND_MAX then
            -- THE LADDER IS FINISHED AND THE PULL STILL HAS TO PAY. A late copy of a maxed body
            -- reading as nothing is the one failure this genre makes over and over, so it converts:
            -- the token comes straight back. It cost a pull and the pity moved, so this is not a
            -- perpetual motion machine -- it is the roll refusing to charge you for an outcome it had
            -- nothing left to give you.
            result.overflow = true
            Voucher.grant(player, 1)
        else
            player.bonds[id] = was + 1
        end
        result.bond = Voucher.bondOf(player, id)
        result.char = existing
        Voucher.applyBond(player, existing)
    else
        local Player = require("models.player")
        result.char = Player.recruit(player, id)
        result.bond = Voucher.bondOf(player, id)
        -- A body pulled back after being released arrives at the level its ledger already holds.
        if result.char then Voucher.applyBond(player, result.char) end
    end

    if result.char then
        result.relic = Voucher.relicOf(result.char)
        result.relicLevel = Voucher.relicLevel(player, id)
    end
    return result
end

-- ---------------------------------------------------------------------------
-- The sponsor's token
-- ---------------------------------------------------------------------------

-- SOMEBODY ELSE'S COIN, ONCE. Iselle's terms open with the hirelings being on her
-- (conversation_prologue_sponsor), and a company of two walking down a stair that has swallowed four
-- companies is her staking the fifth as badly as the last four -- so there is a token waiting before
-- the party has walked to the rift, and the tutorial spends it (states/hub.lua's hubIntro).
--
-- IT IS RIGGED, and every game in this genre rigs this one. `player.riggedPull` names the body the next
-- pull deals whatever the odds say, which is how the opening hire is a person the story picked rather
-- than a roll the story then has to accommodate. Spent by the pull that reads it.
--
-- Idempotent: staking twice does not put two tokens in a purse that was meant to hold one gift.
function Voucher.stake(player, id)
    if not player then return nil end
    if player.staked then return nil end
    player.staked = true
    player.riggedPull = id
    return Voucher.grant(player, 1)
end

-- Read the rig, if there is one. Wrapped around the roll rather than checked by the panel, so no
-- surface has to know the opening pull is special -- it deals a body exactly as every pull after it
-- does, and it reports the body's OWN rank rather than a fixed one, because the rank is a fact about
-- Saber rather than about the rig.
local peek = Voucher.peek
function Voucher.peek(player)
    local rigged = player and player.riggedPull
    if rigged and Character.defs[rigged] then return rigged, Voucher.starsForBody(rigged) end

    -- A DEVELOPMENT RIG, and it is the only way to see a five-star crossing on purpose: the odds put
    -- one at two percent, so tuning that reveal against the real roll means watching fifty pulls to
    -- catch one. `player.debugRank` is set by the dev row in ui/panels/hiring.lua and is spent by the
    -- pull that reads it, exactly like the sponsor's rig above.
    --
    -- Gated on models/debug.lua, which is a BUILD constant: a shipping build cannot set the field
    -- (there is no dev row) and would not honour it if a hand-edited save carried one.
    local rank = player and player.debugRank
    if rank and require("models.debug").enabled then
        local ids = Voucher.candidatesAt(rank)
        if #ids > 0 then
            local rand = Combat.newRandom((player.pulls or 0) * 31 + rank)
            return ids[rand(#ids)], rank
        end
    end
    return peek(player)
end

local pull = Voucher.pull
function Voucher.pull(player)
    local rigged = player and player.riggedPull
    local result, err = pull(player)
    if rigged and result then
        -- MARKED AS RIGGED so the reveal can stay quiet about where she came from. The rank on the
        -- result is honest -- it is Saber's own -- but a tutorial crossing is not a roll, and a card
        -- that presented it as one would be teaching the player a rule from the one pull that does not
        -- follow it.
        result.rigged = true
        -- Cleared on the way out rather than inside the roll: the roll is a dry run everywhere else,
        -- and a dry run that spent the rig would leave the real pull dealing something the reveal did
        -- not show.
        player.riggedPull = nil
    end
    -- The dev rig is spent the same way and for the same reason -- one press, one rigged crossing.
    if player and player.debugRank and result then player.debugRank = nil end
    return result, err
end

return Voucher
