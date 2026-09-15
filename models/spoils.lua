-- Battle spoils: the coin, loot and salvage a won fight hands over. The payout is still COMPUTED from
-- the size of the roster that was beaten and the company's prestige -- richer fights the deeper the
-- run. An encounter may override either half (rewardGold / loot on its blueprint), mirroring how a
-- treasure cache authors its own `loot` list (data/encounters/encounter_treasure.lua).
--
--   local s = Spoils.roll({ enemyUnits = battle.enemyUnits, prestige = 3, kind = "combat" })
--   -- s = { gold = 71, loot = { "consumable_healing_potion" },
--   --       materials = { material_iron_scrap = 1 } }
--
-- ONE PURSE AND A PILE. `gold` is what a fight pays -- rolled for an ordinary one, authored for an end,
-- and with an END PURSE on top of either (Spoils.endPurse) when the fight was one of the ends the
-- campaign's income is weighted onto. There were two other kinds of money here and both are deleted:
-- scrip, the run's own weightless coin that died at the surface, and VALUABLES -- priced objects with
-- no use, carried out of the rift and sold at a counter. The valuables were the mule's and the
-- bloodstain's freight, and both of those systems are gone; what was left was an object standing in
-- for a number, so an end pays the number now. See Spoils.endPurse for the arithmetic that replaced
-- them, and Spoils.roll for why there is one purse.
--
-- The third field is the FLOOR, and unlike the other two it is not a roll -- see "Salvage" below.
--
-- The same price band also stocks the road's one shop, the Merchant (Spoils.shelf) -- what a run can
-- turn up is one question whether the goods are taken off a body or bought off a cart.
--
-- LOOT COMES OFF THE BODIES FIRST. It used to be a price-banded random draw over every item in the
-- game, with no connection at all to the roster that was beaten -- there was no drop-table
-- authoring, so there was nothing to connect it to. That was invisible while enemies carried
-- interchangeable stock (nobody covets a bandit's iron sword), and stops being invisible the moment
-- the bestiary lands: the whole pitch of a discipline Elite is "I want the thing he just used," and
-- answering that with a rolled healing potion is the wrong answer to a question the fight itself
-- asked (docs/bestiary.md).
--
-- THAT ANSWER IS NOW HALF OF A TWO-STEP DRAW rather than a pool of its own. The floor picks a RANK
-- first and the body picks WHICH ITEM OF THAT RANK second -- see "THE DRAW" below for why deciding
-- how good a thing is and what a thing is in one weighted draw was the defect under every tuning pass
-- this file has had. What a body was carrying is still a preferred answer at its own rank, so "you
-- took his axe" survives; what does not survive is a rusted axe being the likeliest thing to fall out
-- of the deepest fight in the game.
--
-- `bound` and `noSteal` are refused throughout, which is what keeps a boss's phase machinery
-- (utility_demon_sigil and its trait_boss_phases) and a beast's fangs out of the player's hands.
--
-- Pure logic, no love.graphics at require time -- loads under the headless test runner. RNG falls
-- back to math.random when love.math is unavailable, so the roll is exercisable outside a window.

local Item = require("models.item")
local Character = require("models.character")
local Material = require("models.material")

local Spoils = {}

-- WHAT A FIGHT PAYS, and why it is no longer mostly a head-count.
--
-- Gold used to be `GOLD_PER_ENEMY * count * prestige` -- purely linear in how many bodies stood there.
-- That was survivable while every fight was a set-piece of nine, and became wrong the moment an
-- ordinary road stop dropped to a skirmish of three (Arena.SKIRMISH_CAP): the same fight, taking the
-- same health and the same consumables and carrying the same risk to the run, would have paid a third
-- of what it used to. Cutting the bodies without moving this is not a rebalance, it is a pay cut.
--
-- So a fight pays for BEING a fight, plus a little for its size. The flat half is the larger half at
-- skirmish scale, which is the point: what a stop costs the player is mostly the fact of stopping --
-- the attrition, the turns, the risk -- and only partly how many bodies were on it.
local GOLD_PER_FIGHT = 30   -- what clearing a stop is worth at all, before anything is counted
local GOLD_PER_ENEMY = 8    -- ...and what each body standing on it adds
local ELITE_GOLD_MULT = 1.8 -- an elite fight pays out richer than a like-sized common one

-- HOW MUCH RICHER A FLOOR GETS FOR BEING DEEPER, per level of depth. Not the raw multiplier prestige
-- is, and the difference is the whole reason this constant exists.
--
-- Prestige is FIXED for the length of a quest -- the company walks in at 13 and walks out at 13 -- so
-- multiplying by it prices one run against another and nothing within a run compounds. A descent's
-- floor level is not fixed: it climbs two per stair (Descent.LEVEL_PER_FLOOR), eight times in a long
-- run. Reusing prestige's slope there would have the seventh floor paying thirteen times the first,
-- and MEASURED -- the whole floor walked, caches included -- that is a floor handing over eleven
-- thousand gold against a shelf whose dearest row is authored at a few hundred (Grade.priceFor). Gold
-- would stop being a decision somewhere on floor three.
--
-- So depth pays a shallow slope instead: floor 1 pays flat, and each level after adds a fifth. Floor 7
-- comes out around three and a half times floor 1 -- materially richer, which is the greed the landing
-- question needs, and still inside the band where one cleared floor buys roughly one thing off a shelf.
local GOLD_DEPTH_SLOPE = 0.2

-- THE END PURSE: what an end hands over on top of what its fight was worth, and the whole of what the
-- valuables used to be.
--
-- The campaign's income was objects for a while -- priced loot with no use, dropped only by ends and
-- sold at a counter in the city. Objects were the point: they took mule slots, so treasure competed
-- with the gear you found, and they rode in the pack, so a wipe dropped the takings where the company
-- fell. Both of those systems are deleted. Everything the weight was for went with them, and what was
-- left was an inventory step between winning a fight and being paid for it -- carry the idol home,
-- open a shop, click sell -- with no decision anywhere in it.
--
-- So an end pays coin. WHAT DID NOT CHANGE is the shape the valuables gave the economy, because that
-- shape is the reason the descent has a direction:
--
--   LUMPY, NOT LITTER  only an end pays one -- an elite, an objective, a general -- never an ordinary
--                      body. The grind funds spending; the work you chose to walk to funds the
--                      campaign. Paying every fight a share of this instead would flatten the two
--                      incomes into one and make the whole floor worth the same to walk.
--   IT CLIMBS STEEPLY  much steeper than GOLD_DEPTH_SLOPE, which is deliberate. An ordinary fight's
--                      gold is a wage and rises gently; this is the thing that makes floor eleven
--                      worth the risk of floor eleven, so it is what the greed in the landing question
--                      is actually weighing.
--
-- THE NUMBERS ARE THE OLD LADDER'S, measured rather than re-invented: the valuable pool ran from a
-- 110-gold thurible on floor 1 to a 1,500-gold reliquary on floor 11, drawn twice with the dearer kept,
-- which came out at ~150 gold on the first floor and ~850 on the eleventh. A base of 130 on a slope of
-- 0.55 tracks that within a few gold at every rung the old pool had, so every measurement taken against
-- the object economy still reads.
local END_PURSE = 130       -- what an end's takings are worth on floor 1
local END_PURSE_SLOPE = 0.55 -- ...and what each level of depth after the first adds
-- WHERE THE CLIMB STOPS, and it is the top rung of the ladder above rather than a round number: the
-- old pool held nothing deeper than floor 11, so its expected haul went flat there. A campaign road
-- passes its DAY in as depth (Spoils.roll) and the calendar runs to 40 -- without this, a late road
-- elite would pay four times what the deepest floor in the game does.
local END_PURSE_CAP = 11
-- HOW MANY SHARES EACH KIND OF END PAYS. The old ladder's own counts: an elite is a fight the player
-- could have walked around, an objective is the one they came down for, and a general closes a circle
-- and pays double.
local END_PURSE_SHARES = { elite = 1, objective = 1, general = 2 }

-- HOW MUCH RARER EACH RUNG OF DEPTH MAKES AN ENTRY ON ITS OWN BODY'S LIST. A list is not a flat bag:
-- the whole point of a named body is that it carries one thing worth going back for, and a uniform
-- draw makes its best piece exactly as common as its worst.
--


-- HOW FAST A FIND BELOW THE FLOOR'S OWN TIER STOPS BEING WORTH PAYING. Every rung of gap between an
-- item's depth and the floor's tier divides its weight; this is how many rungs of gap halve it.
--
-- TWO, so a floor pays mostly within a rung or two of itself: on floor 8 a depth-8 find weighs 1, a
-- depth-6 one a half, a depth-4 one a quarter, and floor-one stock about a twelfth. Shallow gear is
-- still reachable -- it has to be, or a deep floor whose own band happens to be thin would pay nothing
-- at all -- but it stops being the likeliest thing in the pool.
--
-- IT DOES NOT TOUCH CONSUMABLES, which are priced and weighed on the branch above. That is deliberate:
-- a potion is supply rather than a find, the restock has to stay available at every depth, and the
-- thing being corrected here is a floor handing over GEAR that belongs to a floor it is nowhere near.
Spoils.DEPTH_MATCH_SPREAD = 2

-- love.math.random when running under LÖVE, else math.random. Same call signatures: () -> [0,1),
-- (m) -> [1,m], (m,n) -> [m,n]. Kept behind one helper so the whole module is engine-agnostic.
local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- Gold for beating `count` enemies at `depth`, scaled by the encounter's difficulty tier (`scale`,
-- default 1) so a tougher side-fight pays materially more -- the risk/reward that makes engaging a
-- fight before the boss worth the attrition. An override short-circuits the whole computation (it is
-- an exact, authored payout and is never rescaled).
--
-- `mult` is HOW FAR IN this fight is, already resolved to a multiplier by the caller (Spoils.roll),
-- because the game has two shapes of run and they read depth differently -- prestige straight in the
-- campaign, a shallow slope over the floor level in a descent. See GOLD_DEPTH_SLOPE for why they are
-- not the same slope, and Spoils.roll for which one a given call gets.
local function rollGold(count, mult, kind, override, scale)
    if override then return math.max(0, math.floor(override)) end
    local base = (GOLD_PER_FIGHT + GOLD_PER_ENEMY * math.max(1, count)) * math.max(1, mult)
    local jitter = 0.85 + rnd() * 0.30 -- +/-15% so two identical fights don't pay identically
    local gold = base * jitter * (scale or 1)
    if kind == "elite" then gold = gold * ELITE_GOLD_MULT end
    return math.max(1, math.floor(gold + 0.5))
end

-- What an end leaves on top of its fight's own gold, in coin. Nought for an ordinary fight, which is
-- the point rather than an omission (see END_PURSE).
--
-- FLAT, WHERE THE FIGHT'S GOLD JITTERS. The old valuables varied because a draw from a pool varies,
-- not because anybody wanted an end's takings to be a surprise -- and the surprise was in WHICH object
-- turned up, which a number cannot offer anyway. What is left is a figure the player can plan a descent
-- against, which is what the greed decision at the landing wants: "one more floor is worth this much"
-- is only a decision if the much is knowable.
--
-- Public because two callers need it and they are not both inside this file: Spoils.roll folds it into
-- a rolled fight, and models/encounter_battle.lua pays it to the general, whose fight rolls nothing.
function Spoils.endPurse(kind, depth)
    local shares = END_PURSE_SHARES[kind or ""] or 0
    if shares <= 0 then return 0 end
    depth = math.min(END_PURSE_CAP, math.max(1, math.floor(tonumber(depth) or 1)))
    return math.floor(shares * END_PURSE * (1 + END_PURSE_SLOPE * (depth - 1)) + 0.5)
end

-- The ceiling of the ROAD BAND on `day`: how dear a thing a run can turn up at all. One number,
-- because the road turns goods up two ways -- off a beaten body and off the Merchant's shelf
-- (Spoils.shelf) -- and a market carrying gear the same road could never drop would be a second,
-- silent answer to a question this already answers.
--
-- IT USED TO READ PRESTIGE, and the band got narrower when it moved. Prestige ran to 93 over a
-- campaign, so the deepest road could drop a 5,620-gold piece; the calendar runs to 40, which tops out
-- near 2,440. That is a real cut to what the road can hand over and it is the right one -- a campaign
-- with a deadline is shorter, the shelves are shallower for the same reason (docs/overworld.md), and a
-- road that out-dropped the shops it is supposed to feed was already the wrong shape.
local function bandPrice(day)
    return 40 + math.max(1, day or 1) * 60
end

-- THE SHALLOWEST TIER THE RIFT MAY GIVE A THING UP AT, on the 1..CLASS_LEVEL_CAP ladder the finds are
-- banded along (tools/drop_tier.lua) and the one a fight reads its own depth off (rollLoot).
--
-- TWO NUMBERS, AND THE ANSWER IS THE DEEPER OF THEM, because an item is held back by two different
-- things and either one alone lets the other through:
--
--   ITS RANK          what the thing is worth. A find wears it as `dropTier` outright; a priced item
--                     wears it as `unlockQuests`, the grade rank that IS its shelf slot (docs/shelf.md).
--                     The two are one ladder a rung apart -- Vendor.foundPrice already reads a find's
--                     rank as `dropTier - 1` -- so `unlockQuests + 1` here is that identity read
--                     backwards and not a second mapping anybody has to keep in step.
--
--   ITS CLASS'S GATE  what had to be played for before anybody may hold it. Warden asks knight 8 and
--                     hunter 8 (data/classes/warden.lua); a vendor greys a crossing's stock until that
--                     is paid (models/vendor.lua) and this pool had no such rule at all.
--
-- THE SECOND HALF IS THE BUG THIS ANSWERS. Rank is measured worth (models/grade.lua) and worth is the
-- wrong instrument for "who is allowed it" -- deliberately so, since a grade that read a gate would be
-- reading its own output. So a Warden charm whose numbers are small graded shallow, and the deepest-
-- gated kit in the game fell out of floor one: 26 earned-class items sat at tier 1 or 2, one of them
-- behind an eight-rung gate. A gate is not a magnitude, and the pool has to ask for it separately.
--
-- THE GOLD BAND IS UNTOUCHED AND STILL APPLIES ON TOP for a priced item. How dear a thing is and how
-- deep it belongs are different questions; the band answers what the road can afford, this answers what
-- the road is allowed to have, and neither stands in for the other (docs/economy.md).
function Spoils.depthOf(def)
    if not def then return 0 end
    local Class = require("models.class") -- lazy: class -> item -> here at require time
    local rank = def.dropTier or ((def.unlockQuests or 0) + 1)
    return math.max(rank, Class.gateLevel(def.class))
end

-- The drop pool: every PRICED item within a prestige-scaled price band. Price is the "shoppable"
-- marker -- natural weapons, bound relics and quest items have none, so they can never drop. Cheaper
-- items (and consumables) weight heavier, so the common reward is a potion, not the best sword you
-- could theoretically afford.
-- ...AND EVERY UNPRICED ONE THE RIFT IS DEEP ENOUGH TO GIVE UP.
--
-- The second half of the pool, and it is what the shelf's own retirement made necessary. An item with a
-- class and no price used to be quest-only by construction -- the shops read price, this pool read
-- price, so the only way one ever reached a player was a quest's `rewardItems`. The houses stopped
-- posting quests and thirty-five of them were deleted, and every unpriced item in the game lost its
-- single source at once.
--
-- What decides whether one falls out here is its `dropTier` (tools/drop_tier.lua): the same grade that
-- would have set a priced item's shelf slot, spread along DEPTH instead, because an item with no shelf
-- to sit on still has a place it belongs. So the strong half of the equipment in this game is found
-- rather than bought, which is the whole of what the one market left room for.
--
-- WEIGHTED LIKE THE BAND ABOVE, on tier rather than on price -- a find well inside the company's depth
-- is common, one at the edge of it is rare -- so the two halves of the pool behave the same way and a
-- floor does not suddenly start raining its deepest finds the moment it can reach them.
--
-- `bound` is still refused outright, and so is a signature: those ride one body's grid and are nobody's
-- to find (tools/drop_tier.lua assigns neither).
--
-- AND NOTHING DEEPER THAN THE FLOOR REACHES, on either half. See Spoils.depthOf: the tier gate used to
-- be read off `dropTier` alone, which meant the priced half was gated by GOLD and by nothing else and
-- the found half could not see a class gate at all.
--
-- `pricedOnly` drops the found half for a caller that is stocking a COUNTER rather than a floor
-- (Spoils.shelf). It is a parameter and not a second function because the two want the same band, the
-- same weighting and the same gate -- what a cart may sell is a subset of what the road may turn up,
-- and the subset is "somebody wrote a price on it". Before the gate landed this happened by accident:
-- the shelf passed no tier at all, so the found half fell out of a `dropTier <= 0` test on its own.
local function lootCandidates(maxPrice, tier, pricedOnly)
    local pool = {}
    tier = tier or 0
    for id, def in pairs(Item.defs) do
        local priced = def.price and def.price > 0
        if def.bound then -- nailed to one grid; never earned, bought, stolen or found
        -- A BODY PART IS NOT LOOT. `noSteal` is the blueprint's own declaration that this cannot be
        -- taken off the body wearing it (a beast's fangs, a wyrm's breath), and a thing a pickpocket
        -- cannot lift mid-fight is not a thing that falls off the corpse afterwards.
        --
        -- THIS USED TO BE ENFORCED BY ACCIDENT AND STOPPED BEING. docs/bestiary.md still claims "the
        -- engine already enforces this economically ... models/spoils.lua uses `price` as the shoppable
        -- marker, so an unpriced natural weapon can never enter the drop pool." That was true until
        -- tools/drop_tier.lua started handing every unpriced item a `dropTier` -- which is the second
        -- half of the `or` below, and which let all 92 of them straight back in. A proxy gate is only as
        -- good as the thing it is a proxy for, and this one's meaning changed underneath it.
        elseif def.noSteal then
        elseif not (priced or (def.dropTier and not pricedOnly)) then -- nothing this caller may hand over
        elseif Spoils.depthOf(def) > tier then -- ranked or gated deeper than this floor reaches
        elseif priced then
            if def.price <= maxPrice then
                local weight = 1 + math.max(0, maxPrice - def.price) / maxPrice -- ~1 (dear) .. ~2 (cheap)
                if def.type == "consumable" then weight = weight * 2 end
                pool[#pool + 1] = { id = id, weight = weight }
            end
        else
            -- WEIGHTED TOWARD THE FLOOR'S OWN TIER, and this ran the other way until it was measured.
            --
            -- It was `1 + (tier - depth) / tier`, on the argument that "a find well inside the company's
            -- depth is common, one at the edge of it is rare -- so a floor does not suddenly start
            -- raining its deepest finds the moment it can reach them." The intent is right and the
            -- formula is its own opposite: the further BELOW the floor an item sits the heavier it got,
            -- so floor one stock was the likeliest thing to fall out of the deepest fight in the game.
            --
            -- MEASURED before the change, over 4,400 drops a floor: floor 8 averaged depth 1.98, and
            -- 7.6% of what it paid was anywhere near its own tier. A floor fought at level 16 was
            -- handing over rung-2 gear nine times in ten.
            --
            -- So the curve peaks at the floor's tier and falls away beneath it. The edge is still not
            -- rained -- `tier` is a hard ceiling a line above, and depth CANNOT exceed it -- but what a
            -- floor pays now reads as belonging to that floor.
            local gap = math.max(0, tier - Spoils.depthOf(def))
            local weight = 1 / (2 ^ (gap / Spoils.DEPTH_MATCH_SPREAD))
            if def.type == "consumable" then weight = weight * 2 end
            pool[#pool + 1] = { id = id, weight = weight }
        end
    end
    return pool
end

-- The carried pool: every priced, unbound item in the beaten roster's grids. One entry per item
-- CARRIED rather than per distinct id, so four bandits with iron swords make an iron sword four
-- times as likely to fall out -- "what you defeat" includes how much of it there was.
--
-- Tolerant about the shape it is handed, because the callers differ: a live battle passes real
-- units, and a test or a headless caller may pass bare `{ char = { id = ... } }` stand-ins with no
-- grid at all. A body with no inventory contributes nothing instead of erroring.

local function carriedCandidates(enemyUnits)
    local pool = {}
    if not enemyUnits then return pool end
    for _, unit in ipairs(enemyUnits) do
        local char = unit and unit.char
        if char and char.inventory then
            for _, item in ipairs(Character.eachItem(char)) do
                local def = item.id and Item.defs[item.id]
                if def and def.price and def.price > 0 and not def.bound then
                    pool[#pool + 1] = { id = item.id, weight = 1 }
                end
            end
        end
    end
    return pool
end

-- Does this company already hold `itemId`? The same question models/descent.lua's own `ownsItem` asks
-- of a boss list, asked here for the same reason and answered the same way: "already got this" means
-- held anywhere in the company, so a relic worn by the knight is not one they are missing, and selling
-- one makes it droppable again. Duplicated rather than exported because the two callers are on
-- opposite sides of a require cycle (descent -> spoils), and eight lines is cheaper than the seam.
local function companyOwns(player, itemId)
    if not (player and itemId) then return false end
    for _, item in ipairs(player.stash or {}) do
        if (type(item) == "table" and item.id or item) == itemId then return true end
    end
    for _, char in ipairs(player.roster or {}) do
        for _, item in pairs(char.inventory or {}) do
            if type(item) == "table" and item.id == itemId then return true end
        end
    end
    return false
end


-- Weighted draw of one ENTRY from a { id, weight, ... } pool, or nil for an empty pool. Split out of
-- `pick` because the authored route needs the whole row it drew (see `draw`), not just its id.
local function pickEntry(pool)
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local r = rnd() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e end
    end
    return pool[#pool] -- float slop guard: the last entry mops up the remainder
end

-- Weighted draw of one id from a { id, weight } pool, or nil for an empty pool.
local function pick(pool)
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local r = rnd() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e.id end
    end
    return pool[#pool].id -- float slop guard: the last entry mops up the remainder
end

-- 0-2 loot ids. An override list is used verbatim (unknown ids dropped so a typo can't crash the
-- later Item.instantiate). Otherwise: a likely first drop and an unlikely second, both richer and
-- more probable for an elite.
-- `scale` (default 1) is the difficulty-tier bump. A gentler curve than gold uses -- sqrt(scale) --
-- widens the price band and lifts both drop chances, so a tier-3 fight tends to pay a richer, likelier
-- drop without a low-prestige map suddenly raining top-shelf gear.
-- ---------------------------------------------------------------------------
-- THE DRAW: the floor picks the rank, the body picks which item of that rank
-- ---------------------------------------------------------------------------
--
-- ONE DRAW IN TWO STEPS, IN THAT ORDER, and the order is the whole design.
--
-- What replaced: three pools -- an authored list, the beaten bodies' grids, and a price band -- blended
-- by two independent probabilities. That arrangement decided an item's RANK (how good) and its
-- IDENTITY (what it is) in the same weighted draw, and those are different questions with different
-- right answers. Rank belongs to WHERE YOU ARE; identity belongs to WHAT YOU KILLED. Deciding them
-- together is why every tuning pass over this landed on one and left the other alone -- most sharply
-- when correcting the band's inverted weight, which was unambiguously a bug fix and moved the
-- measurement 7.6% to 9.6%, because the band was a quarter of the drops and the other three quarters
-- had no depth relationship at all.
--
--   STEP 1  the floor picks a RANK, before anything looks at who died (Spoils.rankBand). A floor can
--           no longer pay gear that does not belong to it, by construction rather than by weighting.
--   STEP 2  the body picks WHICH item of that rank -- from what it is known for, what it was holding,
--           and its own class's stock at that rank, with the first two preferred.
--
-- SIX CONSTANTS CAME OUT: AUTHORED_BIAS, CARRIED_BIAS, AUTHORED_FALLOFF, AUTHORED_STANDOUT_SHARE,
-- DEPTH_MATCH_SPREAD and CARRIED_DEPTH_REACH. Three go in (RANK_SPREAD, RANK_FALLOFF,
-- BODY_PREFERENCE), and unlike the six they compose into a sentence rather than into whatever they
-- happen to produce.
--
-- WHAT SURVIVES UNTOUCHED, because none of it was about the blend: salvage, the husk track and its
-- pity, the bestiary, the rank-at-the-drop readout, the `noSteal` gate, and the authored `drops` lists
-- themselves -- which are now Step 2's first preference rather than a pool of their own.

-- HOW FAR UNDER ITS OWN RUNG A FLOOR ALSO REACHES. One: a floor pays its own rank and the one below
-- it, so a run's ladder reads as a climb rather than as eight closed boxes. Zero would make every
-- floor a single rank and the catalogue's shape visible; two spans three rungs, which at eight floors
-- is most of the ladder and stops meaning anything.
--
-- DOWNWARD ONLY -- see Spoils.rankBand for the law that makes it one-sided.
-- HOW MUCH OF WHAT A FIGHT PAYS IS SUPPLY rather than a find. A fifth, which is what the consumable
-- share measured at before the split -- carried across rather than re-chosen, so the restock does not
-- move merely because the gear rules did.
--
-- IT SHARES THE FIGHT'S DROP BUDGET, IT DOES NOT ADD TO IT, and the first cut got that wrong: rolled
-- as an extra chance on top, a fight paid 1.05 items against the 0.73 it paid before and consumables
-- came out at 40% of drops. R3-6 asks that a potion not compete for a RANK SLOT -- which it no longer
-- does, since it is drawn off price rather than off the rank band -- and says nothing about a fight
-- suddenly paying half again as much.
--
-- So each of the two drop slots below is EITHER a find or supply. Gear is unchanged in volume, the
-- restock is unchanged in share, and the only thing that moved is that a consumable no longer occupies
-- a slot the rank draw wanted for gear.
Spoils.SUPPLY_SHARE = 0.2

Spoils.RANK_SPREAD = 1

-- ...and how much rarer each step away from the centre is. Two, so a floor's own rung is twice as
-- likely as either neighbour -- which is what keeps the TOP of a band (the deep, dear end) the
-- uncommon half of what a floor pays, and therefore keeps a body's best piece a chase rather than a
-- routine.
Spoils.RANK_FALLOFF = 2

-- HOW MUCH A BODY'S OWN STOCK IS PREFERRED over its class's general stock at the same rank. Four, so
-- roughly four in five drops at a rank the body has something at are THAT BODY'S -- its authored list
-- or what it was carrying -- and the rest are its house's.
--
-- A PREFERENCE AND NOT A PRIORITY, deliberately. Strict priority (the list, else the class, else
-- anything) reads better in a design document and is wrong in play: a body with a single rank-8 entry
-- would pay that entry EVERY time the floor drew rank 8, which on a deep floor is most draws, and the
-- thing it is known for stops being rare the moment you are deep enough to want it. A weight keeps the
-- connection loud and the standout scarce at once.
Spoils.BODY_PREFERENCE = 4

-- THE FLOOR'S RANK BAND: lo, hi, centre, on the 1..CLASS_LEVEL_CAP ladder `dropTier` is banded along.
--
-- SPREAD ACROSS THE WHOLE STACK rather than climbing two rungs a floor. `floorLevel` climbs by
-- Descent.LEVEL_PER_FLOOR and the ladder caps at CLASS_LEVEL_CAP, so reading it directly pinned the
-- band at the cap from FLOOR FOUR -- five of the eight floors sharing one rank, the back half of a run
-- unable to differentiate what it paid at all. `. drop-sample` is what found that; nothing in the
-- source says it.
--
-- So a floor's centre is its PROGRESS through the stack, mapped onto the ladder: floor 1 centres on
-- rung 1, floor 8 on rung 8, and every floor between gets its own. Derived from Descent.FLOORS and
-- Class.CLASS_LEVEL_CAP rather than from a step, so re-cutting either restretches the ramp instead of
-- silently re-pricing one end (the rule Descent.FLOOR_FIGHTS_DEEP records for the same reason).
--
-- THE CAMPAIGN READS ITS OWN CLOCK. It passes no `floorLevel`; its progress is the day against the
-- calendar, which is the same question asked of a different ladder. A caller with neither answers the
-- bottom rung, which is what an unstamped fixture should get.
function Spoils.rankBand(opts)
    opts = opts or {}
    local Class = require("models.class")
    local cap = Class.CLASS_LEVEL_CAP
    local progress

    if opts.floorLevel then
        local Descent = require("models.descent")
        local floor = (opts.floorLevel or 0) / math.max(1, Descent.LEVEL_PER_FLOOR)
        progress = floor / math.max(1, Descent.FLOORS)
    else
        local Calendar = require("models.calendar")
        progress = (opts.day or 1) / math.max(1, Calendar.DAYS or 40)
    end

    progress = math.max(0, math.min(1, progress))
    local centre = math.max(1, math.min(cap, math.ceil(progress * cap)))
    -- An elite reaches one rung deeper, exactly as it always has and for the same reason it reaches a
    -- richer price band: it is the fight the player could have walked around.
    if opts.kind == "elite" then centre = math.min(cap, centre + 1) end

    -- IT REACHES DOWN AND NEVER UP. docs/shelf.md states it as a law -- "a floor hands over nothing
    -- ranked or gated deeper than it reaches" -- and a sealed chest is its ONE authored exception,
    -- because a chest exists to reach past the band it stands in. A symmetric band broke that on the
    -- shallow floors, where clamping pushed the centre up and floor one started paying rank 2.
    --
    -- So the floor's own rung is the CEILING of what it pays, and the spread is how far under it the
    -- floor also reaches. That is also the more honest reading of "the floor picks the rank": it picks
    -- one, and the band beneath is the slack.
    return math.max(1, centre - Spoils.RANK_SPREAD), centre, centre
end

-- Draw one rank out of the band, weighted toward its centre.
local function pickRank(lo, hi, centre)
    local pool = {}
    for r = lo, hi do
        pool[#pool + 1] = { id = r, weight = 1 / (Spoils.RANK_FALLOFF ^ math.abs(r - centre)) }
    end
    local entry = pickEntry(pool)
    return entry and entry.id or centre
end

-- WHAT THE BODIES STANDING HERE CAN PAY AT RANK `r`, as a weighted pool.
--
-- Three sources, all at the SAME rank, so nothing here decides how good the drop is -- Step 1 already
-- did. What they decide is what it is:
--
--   its list     what the body is KNOWN for (`drops` on the blueprint, docs/drops.md)
--   its grid     what it was actually holding -- "you took his axe", the connection worth keeping
--   its house    its class's stock at that rank, for a body nobody wrote a list for
--
-- The first two are the body's own and are preferred (Spoils.BODY_PREFERENCE); the third is the
-- fallback that makes a list optional rather than load-bearing, which is what took the coverage bill
-- from thirty-five character blueprints to nothing.
--
-- A HELD ENTRY IS DROPPED FROM THE POOL RATHER THAN DECLINING THE WHOLE DRAW. Under the old three-pool
-- arrangement a held entry had to decline, because the authored pool was a route and re-picking inside
-- it would have made the standout a countdown. Here the pool is everything at one rank, so removing a
-- held entry simply leaves the rest of that rank -- the class's other stock, another body's list -- and
-- the draw stays at the rank the floor chose. A farmed body still goes quiet without the floor going
-- quiet with it.
local function rankCandidates(enemyUnits, r, player)
    local Class = require("models.class")
    local own, house = {}, {}
    local seenOwn, classes = {}, {}

    local function add(into, id, seen)
        local def = Item.defs[id]
        if not def or def.bound or def.noSteal then return end
        -- SUPPLY IS NOT A FIND, so it never occupies a rank slot (R3-6, Spoils.SUPPLY_SHARE). Without
        -- this a consumable reached the player through BOTH tracks, and because consumables sit at the
        -- shallow end of the ladder that landed hardest exactly where the gear pool is thinnest: floor
        -- one measured 41% consumables against the 20% the supply share asks for.
        if def.type == "consumable" then return end
        if Spoils.depthOf(def) ~= r then return end
        if seen[id] then return end
        seen[id] = true
        if companyOwns(player, id) then return end
        into[#into + 1] = { id = id }
    end

    -- THE DEEPEST ENTRY ON A BODY'S LIST IS ITS PRIZE, AND A PRIZE IS NOT HANDED OVER PREFERENTIALLY.
    --
    -- Preference says "this is its kit" and is right for a body's ordinary stock. Applied to the
    -- standout as well it made the piece a body is KNOWN for the likeliest thing it pays on the one
    -- floor that can pay it -- measured at 26% of fights, which is an errand rather than a chase. So
    -- the standout competes on equal terms with its house's other stock at that rank, and the body's
    -- commons keep the preference.
    local prize = {}
    for _, unit in ipairs(enemyUnits or {}) do
        local def = unit and unit.char and unit.char.id and Character.defs[unit.char.id]
        local top = nil
        for _, id in ipairs((def or {}).drops or {}) do
            local d = Item.defs[id]
            if d then
                local depth = Spoils.depthOf(d)
                if not top or depth > top then top = depth end
            end
        end
        if top == r then
            for _, id in ipairs((def or {}).drops or {}) do
                local d = Item.defs[id]
                if d and Spoils.depthOf(d) == r then prize[id] = true end
            end
        end
    end

    for _, unit in ipairs(enemyUnits or {}) do
        local char = unit and unit.char
        local def = char and char.id and Character.defs[char.id]
        if def then
            for _, id in ipairs(def.drops or {}) do add(own, id, seenOwn) end
            -- Tolerant about the shape it is handed, exactly as the pool this replaced was: a live
            -- battle passes real units, and a headless caller may pass bare `{ char = { id = ... } }`
            -- stand-ins with no grid at all. A body with no inventory contributes nothing rather than
            -- erroring.
            if char.inventory then
                for _, item in ipairs(Character.eachItem(char) or {}) do
                    if item and item.id then add(own, item.id, seenOwn) end
                end
            end
            local lootClass = Spoils.lootClassOf(def, unit)
            if lootClass then classes[lootClass] = true end
        end
    end

    local seenHouse = {}
    for id, def in pairs(Item.defs) do
        if def.class and classes[def.class] then add(house, id, seenHouse) end
    end

    local pool = {}
    for _, e in ipairs(own) do
        pool[#pool + 1] = { id = e.id, weight = prize[e.id] and 1 or Spoils.BODY_PREFERENCE }
    end
    for _, e in ipairs(house) do
        if not seenOwn[e.id] then pool[#pool + 1] = { id = e.id, weight = 1 } end
    end
    return pool
end

-- ...and anything at all at that rank, for a rank at which nothing standing here has stock. Not a
-- legacy path: the class ladders are deliberately incomplete (the Cathedral has nothing at ranks 3, 7
-- or 8), so this is a designed outcome and a measured one -- `. drop-sample`'s class-match column is
-- how often the draw gets this far.
local function anyAtRank(r, player)
    local pool = {}
    for id, def in pairs(Item.defs) do
        if not def.bound and not def.noSteal and def.type ~= "consumable" and def.dropTier
            and Spoils.depthOf(def) == r and not companyOwns(player, id) then
            pool[#pool + 1] = { id = id, weight = 1 }
        end
    end
    return pool
end

-- WHICH CLASS'S STOCK A BODY PAYS. Its own where it declares one, and otherwise the house of the
-- CIRCLE it is standing in.
--
-- 48 of the placed bodies declare no `class`, and deliberately -- character_bandit's own header
-- explains that naming it `rogue` would put it on the rogue growth table, where +2 damage cancels +2
-- defense and a level-20 bandit stops being able to hurt an armoured party. That is a GROWTH question;
-- this is a LOOT one, and they only share a word. Reading the circle keeps the growth tables untouched
-- and gives a bandit met on Greed's floor the Undercroft's stock rather than a draw over everything.
function Spoils.lootClassOf(def, unit)
    if def and def.class and def.class ~= "creature" then return def.class end
    local sin = unit and (unit.sin or (unit.char and unit.char.sin))
    if not sin then return nil end
    local Registry = require("models.registry")
    local vendors = Registry.load("data/vendors", "data.vendors")
    for _, v in pairs(vendors) do
        if v.sin == sin and v.class then return v.class end
    end
    return nil
end

local function rollLoot(day, kind, override, enemyUnits, scale, floorLevel, player)
    if override then
        local out = {}
        for _, id in ipairs(override) do
            if Item.defs[id] then out[#out + 1] = id end
        end
        return out
    end
    local bump = math.sqrt(scale or 1)
    local elite = kind == "elite"

    -- STEP 1. Before anything looks at who died.
    local lo, hi, centre = Spoils.rankBand({ floorLevel = floorLevel, day = day, kind = kind })

    -- STEP 2, per drop, so a two-drop fight can pay two different ranks.
    local function draw()
        local r = pickRank(lo, hi, centre)
        local pool = rankCandidates(enemyUnits, r, player)
        if #pool == 0 then pool = anyAtRank(r, player) end
        return pick(pool)
    end

    -- THE SUPPLY TRACK. A potion is not a find: it wants to be available at every depth, and it is
    -- priced precisely because the stock decision before a descent has to be makeable (docs/shelf.md).
    -- Drawn off PRICE, never off the rank band -- which is what keeps Step 1's sentence true with no
    -- exception clause, and what stops a rank the catalogue happens to be thin at quietly starving the
    -- restock.
    local function supply()
        local pool = {}
        local maxPrice = bandPrice(day) * (elite and 1.5 or 1) * bump
        for id, def in pairs(Item.defs) do
            -- THE LAW BINDS SUPPLY TOO. A potion is drawn off PRICE rather than off the rank band,
            -- which is the whole of R3-6 -- but "a floor hands over nothing ranked or gated deeper
            -- than it reaches" (docs/shelf.md) is about what the company has EARNED, not about which
            -- track paid it, and `Spoils.depthOf` folds a class gate into that number. Without this a
            -- floor-one fight handed over rank-2 stock through the one door that was not looking.
            if def.type == "consumable" and def.price and def.price > 0 and def.price <= maxPrice
                and not def.bound and Spoils.depthOf(def) <= centre then
                pool[#pool + 1] = { id = id, weight = 1 + (maxPrice - def.price) / maxPrice }
            end
        end
        return pick(pool)
    end

    -- Each slot is either a find or supply. See Spoils.SUPPLY_SHARE for why it shares the budget
    -- rather than adding to it.
    local function fill()
        if rnd() < Spoils.SUPPLY_SHARE then return supply() end
        return draw()
    end

    local out = {}
    if rnd() < math.min(0.95, (elite and 0.90 or 0.55) * bump) then
        local id = fill(); if id then out[#out + 1] = id end
    end
    if rnd() < math.min(0.80, (elite and 0.45 or 0.18) * bump) then
        local id = fill(); if id then out[#out + 1] = id end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- What a floor's own gear arrives at
-- ---------------------------------------------------------------------------

-- HOW HIGH A PLAIN FOUND PIECE MAY READ, and it is deliberately a rung under what a husk may.
--
-- A husk read on a deep floor comes out +1 to +3 off an authored curve (Identify.capFor / rollLevel);
-- a plain axe off the same floor arrived +0. Same rift, same floor, two different rules -- and the
-- second one made depth something the player OBEYED (it decides which item) without ever FEELING it
-- (it says nothing about the copy). Levelling a find by its floor is the cheapest way to close that,
-- and it opens no balance surface: every magnitude already resolves per level off models/curve.lua,
-- the " +n" already rides the name, and a save already carries it. A found +2 axe is indistinguishable
-- from a bought one hammered twice, because it IS one.
--
-- THREE RUNGS PER LEVEL AND NO FLOOR OF ONE, against the husk's two and its guaranteed +1. Both halves
-- keep the counter worth walking to: a husk is the richer outcome at the ceiling AND in expectation
-- (~1.8 against ~0.5), so paying a fee still buys the better object. Most found gear is +0; the deep
-- end occasionally is not.
Spoils.FOUND_RUNGS_PER_LEVEL = 3
Spoils.FOUND_CLIMB = 0.35

-- The level a found piece arrives at, for a fight on `floorLevel`. Nought without one, which is how the
-- CAMPAIGN opts out: its roads are stocked by their houses rather than by depth, and it seals nothing
-- either (Spoils.rollSealed). One rule, both halves of the same argument.
function Spoils.foundLevel(floorLevel)
    if not floorLevel then return 0 end
    local Item_ = Item
    local cap = math.min(Item_.MAX_LEVEL or 10,
        math.floor(math.max(1, floorLevel) / Spoils.FOUND_RUNGS_PER_LEVEL))
    local level = 0
    while level < cap and rnd() < Spoils.FOUND_CLIMB do level = level + 1 end
    return level
end

-- ---------------------------------------------------------------------------
-- Sealed drops: what the rift hands up unread
-- ---------------------------------------------------------------------------

-- HOW OFTEN A STOP PAYS SOMETHING NOBODY CAN READ (models/identify.lua).
--
-- The shape mirrors the voucher purse's: the ordinary stop still reads as the ordinary stop -- six
-- fights in seven pay what they always paid and nothing else -- and the two places worth going out of
-- your way for pay one in three. Across a twelve-stop floor that comes to two or three: enough that the
-- walk to the counter is a decision about which to read first, and not enough that it becomes a queue.
--
-- THE STAIR GUARDIAN IS ABSENT and that is a decision, not an omission. A general already pays an
-- authored piece off Descent.DROPS -- the thing her fight was built to hand over. Rolling a husk on top
-- would put two rewards on one body and quietly make the authored one the consolation prize.
-- `secret` IS ONE, AND IT IS THE ONLY KIND THAT IS. Everything else here is a roll, because everything
-- else is a stop the board dealt you. A sealed room is not dealt: it is behind a door that reads as wall
-- until somebody stands beside it and looks, and a player who does that and finds a fatter pile of the
-- same ore has been taught that looking is pointless. So the one stop on a floor that costs a verb pays
-- every time. See Spoils.SECRET_ABOVE for what it pays out of.
-- `offer` is the other certainty, and it is certain for the opposite reason to `secret`. A crossroads
-- option that says "take the box" has already told the player what it is paying; rolling a 35% behind
-- that sentence would make the option a lie about a third of the time. It draws from a chest's ordinary
-- pool, not a vault's slice -- what a dilemma hands over is a find, not a reward for searching.
Spoils.SEALED_CHANCE = { combat = 0.15, elite = 0.35, treasure = 0.35, secret = 1.0, offer = 1.0 }

-- HOW FAST A DRY FLOOR STOPS BEING DRY. Each stop that pays no husk lifts the next stop's chance by
-- this much of the base rate, and a stop that pays one resets it (Descent.sealedDrought).
--
-- FIVE FOURTHS, and the arithmetic is the whole argument rather than a feel. An ordinary fight is 15%,
-- so reaching certainty on the Nth dry stop wants (1/0.15 - 1)/N; at N = 5 that is 1.13 and at N = 4 it
-- is 1.42. A floor holds eight fights at the top of the stack and eleven at the bottom
-- (Descent.FLOOR_FIGHTS), so certainty by the fifth dry stop clears the shortest floor in the game with
-- three fights to spare -- and 1.25 is the round number inside that window.
--
-- (The first cut of this was 2/3 and the header claimed certainty by the fourth dry fight. It reaches
-- 0.65 there. Nothing in the reachable range of a floor would ever have hit 1, which the spec caught
-- and the prose did not -- the number was chosen to sound moderate rather than derived from the rate it
-- was modifying.)
--
-- Deliberately a SHARE of each kind's own rate rather than a flat addition: an elite starts at 35% and
-- reaches certainty on its second dry stop, which is right, because a player who beat one and got
-- nothing has a louder complaint than one who cleared a wolf pack.
Spoils.SEALED_PITY = 1.25

-- How far above the road's own band a CHEST may reach, as a multiple of it. See sealedCandidates.
Spoils.SEALED_ABOVE = 2.5

-- The same reach read on the RANK ladder instead of on gold: how many rungs above the floor's own tier a
-- sealed piece may come from. Two, which is what SEALED_ABOVE already buys in practice -- floor one's
-- band is 100 and its ceiling 250, and the price ladder puts rank 2 at 245 -- so this is the gold bound
-- said in the unit that can also see a class gate, not a second, tighter rule.
Spoils.SEALED_REACH = 2

-- WHAT A SEALED ROOM DRAWS FROM, and it is a SLICE rather than a taller ceiling.
--
-- Raising the reach was the obvious answer and it is inert, which a spec caught on its first run: a
-- vault at 4x the band and a chest at 2.5x both topped out at exactly 740 on floor six, because the
-- CATALOGUE runs out long before the band does. There is no sealable item dear enough for the extra
-- headroom to contain, so the constant was doing nothing while its comment claimed otherwise.
--
-- The lever that works is which part of the same band a vault is allowed to draw from. A chest rolls
-- anywhere above the road's price; a vault rolls only in the dearer half of what a chest could have had.
-- That is never empty while the chest pool is not, it scales with depth for free because the band does,
-- and it says the true thing: what is behind the door is better than what is in the open, rather than
-- reaching for a tier the game has not authored yet.
--
-- Half, and not a tenth. The point is that a vault pays WELL, not that it pays one specific object --
-- a slice thin enough to be predictable would make the search a vending machine.
Spoils.SECRET_SLICE = 0.5

-- The pool a sealed drop is drawn from, and it is TWO POOLS depending on where the piece came from.
-- The split is the honest reading of this file's own doctrine rather than an exception to it:
--
--   off a body    the carried pool, exactly as an ordinary drop. A fight against somebody wielding a
--                 thing is its own answer to what it should pay -- you took his axe, you simply cannot
--                 read it yet -- so the seal hides the QUALITY and the connection survives intact. A
--                 roster carrying nothing sealable (a wolf pack, whose fangs are unpriced) pays no husk,
--                 which needs no special case: the pool comes back empty and the draw comes back nil.
--
--   out of a chest  ABOVE the band. A cache has no body behind it to connect to, so there is nothing for
--                 a carried draw to preserve -- and that is exactly the room this feature needed. What a
--                 chest seals is dearer than anything the road could otherwise hand over, which is what
--                 makes identification the way the rift pays above its own price band, and what makes
--                 the fee worth paying rather than a toll on a thing you already had.
--
-- Bounded above as well as below. An unbounded draw would let the first floor's first chest hand over
-- the dearest object in the game, and a ceiling that a run can raise by descending is the whole point.
--
-- ...AND BOUNDED ON THE RANK AXIS TOO, by Spoils.SEALED_REACH rather than by the ordinary drop's flat
-- tier gate. A chest exists to reach ABOVE what the floor pays, so gating it at the floor's own rung
-- would delete the feature: the pool is everything priced above the band, and on floor one there is
-- nothing at rank 0 dearer than rank 0. What a seal may NOT do is reach past a gate nobody has opened,
-- which is a different bound and the one that was missing -- floor one's chests were sealing Warden
-- casts. See Spoils.depthOf.
local function sealedCandidates(floor, kind, enemyUnits)
    local Identify = require("models.identify") -- lazy: identify -> player -> save -> descent -> here
    local pool = {}
    if kind == "treasure" or kind == "secret" or kind == "offer" then
        local band = bandPrice(floor)
        local top = band * Spoils.SEALED_ABOVE
        local Class = require("models.class")
        local reach = math.min(Class.CLASS_LEVEL_CAP, math.max(1, floor or 1) + Spoils.SEALED_REACH)
        local priced = {}
        for id, def in pairs(Item.defs) do
            if def.price and def.price > band and def.price <= top
                and Spoils.depthOf(def) <= reach and Identify.canSeal(def) then
                priced[#priced + 1] = { id = id, weight = 1, price = def.price }
            end
        end
        -- Sorted by price and then by id, so the cut is reproducible: `pairs` above is unordered, and a
        -- slice taken off an unordered list would hand two machines different vaults from one seed.
        table.sort(priced, function(a, b)
            if a.price ~= b.price then return a.price < b.price end
            return a.id < b.id
        end)
        local from = 1
        if kind == "secret" and #priced > 1 then
            from = math.max(1, math.floor(#priced * (1 - Spoils.SECRET_SLICE)) + 1)
        end
        for i = from, #priced do pool[#pool + 1] = priced[i] end
    else
        -- NO DEPTH CUTOFF ON THE SEALED PATH, deliberately. A husk's whole point is that the fee reads
        -- the FLOOR and never the piece (docs/identification.md) -- it is drawn richer than the band
        -- allows and its value comes from the reading, not from the blueprint underneath. Filtering by
        -- the blueprint's own rung here would quietly make a deep floor seal nothing off a modest body,
        -- which is the opposite of what the feature is for.
        for _, entry in ipairs(carriedCandidates(enemyUnits)) do
            if Identify.canSeal(entry.id) then pool[#pool + 1] = entry end
        end
    end
    return pool
end

-- The sealed half of a stop's takings: a list of `{ id, floor }`, almost always empty.
--
-- NIL `floorLevel` PAYS NOTHING, WHICH IS HOW THE CAMPAIGN OPTS OUT. Identification is a thing the RIFT
-- does: the descent's gear comes off its floors, and a husk is the floors reaching above the band they
-- are otherwise capped at. The campaign's roads are stocked by their houses instead, and a mystery blade
-- on a quest whose shop is three stops away would be a delayed reward with nowhere to collect it.
--
-- At most one per stop. Two husks off one fight would make the counter a chore rather than a choice, and
-- the second is never the one the player remembers.
--
-- ...AND NEVER A WHOLE FLOOR OF NOTHING. `opts.drought` is how many stops on this floor have already
-- paid no husk, and it lifts the chance until one does (Spoils.SEALED_PITY). A dry floor is survivable
-- at a thousand kills an hour and is not survivable at eight to eleven fights: at the bare 15% a floor
-- paying nothing at all is common enough to be a regular experience, and it is the experience that ends
-- runs.
--
-- The gamble stays where it is already good -- the READING, at the Touchstone, which has a floor of one
-- and no duds for exactly this reason (docs/identification.md). What is being removed here is the roll
-- for whether anything happened today, which is the boring half.
--
-- A LIFT RATHER THAN A HARD GUARANTEE, because nothing here knows which stop is the floor's last. By
-- the fifth dry ordinary fight the chance is past certainty, so the shortest floor in the game reaches
-- it with three fights to spare; a floor whose pool is empty still pays nothing, and must, or the
-- guarantee would invent an item the depth gate had already refused.
function Spoils.rollSealed(opts)
    opts = opts or {}
    local floor = opts.floorLevel
    if not floor then return {} end
    local kind = opts.kind or "combat"
    local chance = Spoils.SEALED_CHANCE[kind]
    if not chance then return {} end
    chance = chance * (1 + Spoils.SEALED_PITY * math.max(0, opts.drought or 0))
    if rnd() >= chance then return {} end
    local id = pick(sealedCandidates(floor, kind, opts.enemyUnits))
    if not id then return {} end
    return { { id = id, floor = floor } }
end

-- ---------------------------------------------------------------------------
-- The Merchant's shelf: the same band, bought instead of taken
-- ---------------------------------------------------------------------------

-- `count` DISTINCT item ids for the wandering Merchant to stock (data/encounters/encounter_merchant.lua),
-- drawn out of the very band a fight's loot rolls in: priced, unbound, and no dearer than the road pays
-- at this prestige. The weighting comes along with it, so a shelf leans the way the drop table does --
-- mostly supplies, the occasional piece of gear worth the detour.
--
-- Ids only. What each COSTS is the item's own shelf price, which belongs to the item and not to a roll:
-- the Merchant charges what the houses charge, since a markup the player cannot compare against a hub
-- they are three stops from is a tax rather than a decision.
--
-- `exclude` is an optional bare set of ids to keep off the shelf. Returns fewer than `count` (or
-- nothing) when the band is too thin to fill it, which the caller must handle -- a market with an empty
-- shelf is a stop with nothing on it.
--
-- `floorLevel` IS HOW DEEP THE CART IS STOCKED, and it is the same field Spoils.roll takes and means
-- the same thing by. Without one the depth comes off `day`, which is what the campaign's roads want and
-- what the descent's cart emphatically does not: a run's day is a borrowed number (Descent.poolDay) and
-- the thing a player has actually done is walk down a stair. The caller passes the DEEPEST floor the
-- company has ever stood on, so the cart carries what the far end of its own experience drops.

-- ---------------------------------------------------------------------------
-- The ceiling: what the rift is allowed to ask for anything
-- ---------------------------------------------------------------------------

-- THE FENCE THAT REPLACED THE SECOND PURSE. There were two currencies for a while (models/scrip.lua,
-- deleted): the run spent its own weightless coin so that nothing bought underground was ever priced
-- against a permanent upgrade. The shelf recut took the gear off the houses and so off this cart
-- (tools/drop_tier.lua), leaving that currency with one and a half sinks, and one purse is what is
-- left. Which brings back the objection the split was built to answer:
--
--     a 200g relic on floor three is not priced against the rest of the floor -- it is priced
--     against a forge rung, and the player either declines every shop underground on principle
--     or bankrupts the progression they came back up to spend on.
--
-- A COMPARISON ONLY BITES AT COMPARABLE SIZES, which is the whole of the answer. Cap what the rift may
-- ask at the price of a house's OPENING RUNG -- the cheapest purchase the campaign ever asks anybody to
-- make -- and no underground buy can be weighed against a permanent upgrade, because it is always the
-- smaller decision by construction. "Can I afford this" stops being the question and "will I need it"
-- becomes it, which is the question the split was trying to produce in the first place.
--
-- ANCHORED TO Grade.PRICE_BASE RATHER THAN TYPED, so a re-cut of the shelf moves this with it. It is
-- deliberately NOT anchored to a forge rung: the bench bills TECHNIQUE for anything with a class and
-- only bills coin for classless stock (models/forge.lua's currencyFor), so a rung is not a gold figure
-- to measure anything against.
function Spoils.priceCeiling()
    return require("models.grade").PRICE_BASE
end

-- Clamp one asking price to the ceiling. Every seam that puts a price in front of the player
-- underground runs through this -- the Merchant's gear, its relic slate -- so there is one rule and not
-- one per counter.
function Spoils.askingPrice(n)
    return math.max(1, math.min(math.floor(tonumber(n) or 0), Spoils.priceCeiling()))
end

function Spoils.shelf(opts)
    opts = opts or {}
    local count = math.max(0, opts.count or 3)
    local taken = {}
    for id in pairs(opts.exclude or {}) do taken[id] = true end

    -- THE SAME DEPTH THE ROAD'S OWN DROPS READ, and it has to be passed now that the pool gates on one
    -- (Spoils.depthOf). It used to be left nil, which said the right thing by accident twice over: no
    -- tier meant no found stock, and it also meant no gate, so the cart was free to sell a crossing's
    -- cast to a company eight rungs short of the crossing. Read off the day, exactly as rollLoot reads
    -- it off the floor -- and `pricedOnly`, because a cart sells what somebody priced and the rest of
    -- the catalogue is found or not had at all (docs/shelf.md).
    local Class = require("models.class")
    local day = math.max(1, opts.day or 1)
    local depth = math.max(1, opts.floorLevel or day)
    local pool = lootCandidates(bandPrice(day), math.min(Class.CLASS_LEVEL_CAP, depth), true)
    local out = {}
    for _ = 1, count do
        local available = {}
        for _, entry in ipairs(pool) do
            if not taken[entry.id] then available[#available + 1] = entry end
        end
        local id = pick(available)
        if not id then break end
        taken[id] = true
        out[#out + 1] = id
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Salvage: the floor under every won fight
-- ---------------------------------------------------------------------------

-- EVERY won fight hands over forging material, whatever else it does or does not roll. Gold and loot
-- are both chances -- loot especially, whose first drop lands a little over half the time, so nearly
-- half of all common fights used to pay a number on a panel and nothing you could carry home. A fight
-- costs HP, consumables and a real chance of losing the run; paying out nothing is the one outcome the
-- board cannot justify having walked into.
--
-- So this half is COMPUTED, never rolled: no RNG, no zero case, and (deliberately) no per-encounter
-- override to author it away. It is also the SMALLEST payout in the economy, because a cache still
-- pays 1-4 craft and 1-3 house stock (Overworld:placeCaches) and leaving the path is meant to stay the
-- thing that stocks the Forge (docs/progression.md, "Materials as a reason to leave the path"). This
-- is a floor, not a rival: one ingot for clearing a stop, two for an elite or a general.
--
-- HELD, NOT MOVED, when the gold beside it was rebased for the skirmish tier -- and measured rather
-- than assumed, because the arithmetic points the wrong way until the caches are counted. A whole
-- descent floor walked stop by stop pays around six craft and six house, against a Forge rung billing
-- four-to-six craft and two-to-three house (models/forge.lua): one floor, one rung, which is the rule
-- the rebase was against. Head-count never fed this half, so shrinking the fights could not cut it.
--
-- What DOES move it is the number of caches, which is derived from the stop count (Overworld.generate,
-- about one per two stops) -- except on a descent floor, which pins it (Descent.FLOOR_CACHES) for
-- exactly this reason, so the fight budget can move without the material income following it. Measured
-- across the cut from eleven rolled fights to five, cache craft held at 16.7 against 17.4. See
-- Descent.FLOOR_FIGHTS, where the number is a one-line change and this is what it is checked against.
local SALVAGE_CRAFT = { combat = 1, elite = 2, objective = 2 }
-- House stock -- the GATE half of the economy, the one that decides which house's bench a haul feeds
-- -- is the reward for the fights you could have walked around, and for the one you came for. A common
-- fight on the road never pays it; an elite and the objective pay one apiece.
local SALVAGE_HOUSE = { elite = 1, objective = 1 }

-- Which craft grade falls out of a fight: its DIFFICULTY TIER (1..3, stamped on the encounter by
-- models/overworld.lua -- the same tell the fog shows before you commit), bumped a grade for an elite
-- or an objective. What you beat decides what it leaves behind, which is exactly what the tier is
-- already there to say. Never forge depth: that mapping died with Material.TIER_BY_LEVEL, and the
-- reasoning is in models/material.lua.
local function craftGradeFor(kind, tier)
    local grades = Material.craftGrades()
    local i = math.max(1, math.min(#grades, math.floor(tonumber(tier) or 1)))
    if kind == "elite" or kind == "objective" then i = math.min(#grades, i + 1) end
    return grades[i]
end

-- The materials a won fight hands over, as { [id] = count }. NEVER EMPTY -- that is the whole point.
--   opts.kind          "combat" | "elite" | "objective" (anything else is treated as common)
--   opts.tier          the encounter's difficulty tier, 1..3 (default 1)
--   opts.houseMaterial the run's house stock -- the quest sponsor's, resolved by the caller exactly as
--                      the map's caches resolve it (states/game.lua). Absent on an unsponsored leg
--                      (the prologue), where the fight simply pays craft stock alone.
--
-- Exposed separately from Spoils.roll because the objective fight takes this half and not the other:
-- a quest's gold and loot flow through Quest.complete, but the general still has to leave something on
-- the sand like everything else on the road did.
function Spoils.materials(opts)
    opts = opts or {}
    local kind = opts.kind or "combat"
    local out = {}
    out[craftGradeFor(kind, opts.tier)] = SALVAGE_CRAFT[kind] or SALVAGE_CRAFT.combat
    local house = SALVAGE_HOUSE[kind] or 0
    -- An id no longer in data/materials is dropped rather than granted, the same rule the loot
    -- override follows -- a stale save or a removed house must not mint a phantom resource.
    if house > 0 and opts.houseMaterial and Material.get(opts.houseMaterial) then
        out[opts.houseMaterial] = (out[opts.houseMaterial] or 0) + house
    end
    return out
end

-- Roll the spoils for a won fight.
--   opts.enemyUnits  the beaten roster (its length is the count); or pass opts.count directly
--   opts.day    the company's prestige (default 1)
--   opts.floorLevel  a descent floor's level, if this fight is on one. Its presence SWITCHES how the
--                    gold reads depth -- a shallow slope over the floor instead of a straight multiple
--                    of prestige (GOLD_DEPTH_SLOPE) -- so nothing moves in the campaign, which has
--                    never passed one
--   opts.kind        "combat" | "elite" (elite pays richer); anything else treated as common
--   opts.rewardGold  encounter override: exact gold, skipping the computation
--   opts.loot        encounter override: an explicit id list, skipping the roll
--   opts.rewardScale difficulty-tier multiplier (default 1); scales the gold and, gentler, the loot.
--                    Absent/1 reproduces the pre-tier payout exactly. Overrides ignore it.
--   opts.tier        the encounter's difficulty tier 1..3, for the salvage grade (see Spoils.materials)
--   opts.houseMaterial the run's house stock, for an elite's salvage (see Spoils.materials)
--   opts.player      OPTIONAL, and only the authored `drops` route reads it: a body with something new
--                    the company already holds is dropped from the rank's candidate pool, so a farmed
--                    body goes quiet without the floor going quiet with it (rankCandidates). Absent,
--                    nothing is owned -- so a caller that has not been taught to pass one behaves as it
--                    did, and a headless test needs no fixture to get a drop
--
-- `enemyUnits` now feeds BOTH rolled halves: its length sets the gold, and its grids are the drop
-- table. Passing `count` alone still works and still pays gold, it just has no bodies to loot, so the
-- roll falls back to the price band entirely.
--
-- The salvage draws no RNG, so a caller seeding the generator to compare two gold rolls still gets
-- the same numbers it did before this field existed.
function Spoils.roll(opts)
    opts = opts or {}
    local count = opts.count or (opts.enemyUnits and #opts.enemyUnits) or 1
    local day = opts.day or 1
    local kind = opts.kind or "combat"
    local scale = opts.rewardScale or 1
    -- HOW FAR IN this fight is, as the multiplier the gold is scaled by. A BRANCH rather than a max of
    -- the two, because the two numbers are not the same kind of thing (see GOLD_DEPTH_SLOPE): prestige
    -- is a fixed per-run standing and scales straight, a floor level climbs within the run and scales
    -- on a shallow slope. Taking the larger would let the descent inherit prestige's slope the moment a
    -- strong company went down, which is precisely the compounding this avoids.
    --
    -- On a descent the company's prestige is deliberately NOT consulted: floor 1 pays what floor 1 is
    -- worth however decorated the party that walks it, which is what stops a strong company farming the
    -- shallows instead of descending.
    local mult = opts.floorLevel
        and (1 + GOLD_DEPTH_SLOPE * (math.max(1, opts.floorLevel) - 1))
        or math.max(1, day)
    -- ONE PURSE. Scrip is deleted (models/scrip.lua, gone) and every payout is the campaign's coin.
    --
    -- WHY THE SPLIT WENT. It existed so that nothing bought underground was priced against a forge
    -- rung, and it worked -- but the shelf recut took the gear off the houses (tools/drop_tier.lua), so
    -- the road's Merchant no longer deals the thing scrip was invented to keep affordable. What was
    -- left was a currency with one and a half sinks, which is a scoreboard rather than a money.
    --
    -- WHAT REPLACES THE FENCE IS MAGNITUDE, not a second purse: nothing underground may ask more than a
    -- fraction of the cheapest forge rung (models/merchant.lua's ceiling), so the comparison the split
    -- was built to prevent never gets close enough to bite.
    --
    -- THE ARITHMETIC DID NOT MOVE. A rolled fight pays what it always paid, into the field it paid into
    -- before the split -- `gold`, at the same number -- so every measurement taken against either
    -- version still reads.
    local authored = opts.rewardGold and math.max(0, math.floor(opts.rewardGold)) or nil
    local rolled = authored and 0 or rollGold(count, mult, kind, nil, scale)
    -- WHAT THE CAMPAIGN ACTUALLY EARNS, and only an end pays any (Spoils.endPurse). An ordinary fight
    -- adds nought, which is the point rather than an omission: the grind pays a wage and the work you
    -- chose to walk to pays the campaign.
    --
    -- NOT ON TOP OF AN AUTHORED PURSE, and that is this file's oldest rule rather than a new exception:
    -- `rewardGold` short-circuits the whole computation, because it is an exact figure somebody wrote
    -- down for THIS fight. The valuables it replaces did land on top of one -- they were objects and
    -- the fight's gold was a number, so neither could speak for the other -- and now that both are coin
    -- an authored payout can say the whole of what an end pays, which is what authoring one is for.
    local purse = authored and 0 or Spoils.endPurse(kind, opts.floorLevel or day)
    return {
        gold = (authored or rolled) + purse,
        loot = rollLoot(day, kind, opts.loot, opts.enemyUnits, scale, opts.floorLevel, opts.player),
        -- The unread piece, on the rare stop that pays one. A SEPARATE field from `loot` rather than an
        -- entry in it, because the two are granted differently and by different code: loot is a list of
        -- ids that Player.grantItem instantiates in the clear, and this is a list of finds that
        -- Identify.grant husks. Folding them together would mean every reader of `loot` -- the summary
        -- panel, the reveal, the tutorial's grants -- having to ask which kind each entry was.
        sealed = Spoils.rollSealed(opts),
        materials = Spoils.materials({
            kind = kind, tier = opts.tier, houseMaterial = opts.houseMaterial,
        }),
    }
end

return Spoils
