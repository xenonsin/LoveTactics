-- SCRIP: the coin a descent pays itself in, and the half of the economy that never comes home.
--
-- THE PROBLEM IT EXISTS TO FIX. There was one purse. The company walked down the stair with the
-- campaign's gold in it (models/gate.lua), and then every merchant stop, every crossroads wager and
-- every money ability spent out of the same number the Forge and the seven shelves bill against. So a
-- 200g relic on floor three was not priced against the rest of the floor -- it was priced against a
-- forge rung, and the player either declined every shop underground on principle or bankrupted the
-- progression they came back up to spend on. Both readings are correct play. That is the tell: a
-- decision where the sensible answer is "never engage with this system" is not a decision.
--
-- SO THE TWO ECONOMIES GET TWO CURRENCIES, and they are separated by PHYSICS rather than by a rule the
-- player has to be told twice:
--
--   scrip      weightless, spent below, and GONE at the surface (Scrip.clear). Rides nothing, occupies
--              no slot, cannot be carried out, cannot be converted.
--   gold       heavy. It arrives as valuables (models/valuable.lua) that occupy mule slots and have to
--              be carried home and sold. Nothing underground accepts it.
--
-- One sentence, learned once: **the run's money is weightless and dies at the surface; the campaign's
-- money is heavy and has to be carried.** Non-fungible by construction -- there is no exchange rate to
-- reason about, because there is no exchange.
--
-- WHY IT EVAPORATES RATHER THAN CONVERTING AT A BAD RATE. A conversion re-opens the valve the split was
-- built to close: at any rate above zero, scrip is gold with a haircut, and every purchase underground
-- goes back to being priced against a forge rung -- just at a discount. Evaporation is what makes an
-- unspent purse a LOSS, which is the thing that flips the merchant from a stop you walk past into a
-- stop you had better use. Darkest Dungeon's provisions do exactly this and for exactly this reason:
-- what you did not use is destroyed, so the question is never "can I afford it" but "will I need it".
--
-- The one-way valve that IS allowed runs the other direction -- a valuable sold to an underground
-- merchant for scrip (Valuable.fenceValue), at a rate bad enough to hurt. That converts progression
-- into in-run power, which is a greed decision worth having, and it can never run backwards.
--
-- WHAT PAYS IT. Bodies and ordinary fights -- the ambient income (models/spoils.lua's `scrip` field,
-- which is the payout that used to be the fight's gold, renamed and not rescaled). Ends pay gold
-- instead. So the grind funds in-run power and only the work the player CHOSE to walk to funds the
-- campaign, which is the decision the descent is built to ask.
--
-- WHAT SPENDS IT. The road's Merchant (states/game.lua), the Crossroads wagers (models/crossroads.lua),
-- and the money kit inside a fight (Combat.spendPurse, injected by states/battle.lua). That last one is
-- the one that got BETTER for the move: a money ability used to bill a forge rung to size a blow, and
-- now it bills the merchant two rooms away. Local, legible, and paid inside the run that spent it.
--
-- A NUMBER ON THE PLAYER, deliberately -- `player.scrip`, exactly as `player.gold` is. It is the shape
-- every existing purse seam already knows, and it is the precise opposite of what a valuable is, which
-- is the whole point of the pair: one of these two things is weightless because the other one is not.
--
-- Pure model: no love.graphics, so it loads under the headless runner.

local Scrip = {}

-- WHAT A COMPANY WALKS IN WITH. Inherited from Descent.OPENING_GOLD, which is the number this replaces
-- and was chosen for the same reason it is kept: small on purpose, because the descent's economy is
-- what its floors pay out, and an opening purse that could buy its way past floor one would settle the
-- run before a tile of it was walked.
Scrip.OPENING = 50

-- The label, in one place, because five surfaces print it and a currency that is called two things is
-- two currencies to the player. Lower-case: it reads inside a sentence ("48 scrip") more often than it
-- heads a column.
Scrip.UNIT = "scrip"

-- ...and the mark a PRICE wears, where gold wears "g" (a shelf's "495g"). Two letters rather than one
-- because a lone "s" reads as a plural on the number in front of it -- "120s" is a duration everywhere
-- else in this game, and the hourglass convention makes that collision a real one.
--
-- A mark is taught beside its name: every surface that prints a price in it also prints the purse as
-- "Your scrip: 120" in the same panel, so the two letters are never the only place the word appears.
Scrip.SUFFIX = "sc"

-- How much `player` is carrying. Nil-tolerant and zero-defaulting for the same reason Mule.capacity is:
-- a headless caller, a pre-scrip save and a campaign player with no run open all have the same honest
-- answer, and it is not an error.
function Scrip.get(player)
    return (player and player.scrip) or 0
end

-- Hand over `n`. Negative amounts are refused rather than quietly working as a spend: a payout seam
-- that computed a negative is a bug, and the one place allowed to take scrip away is Scrip.spend, where
-- the affordability check lives.
function Scrip.add(player, n)
    if not player then return 0 end
    n = math.max(0, math.floor(tonumber(n) or 0))
    player.scrip = Scrip.get(player) + n
    return player.scrip
end

-- Can `player` cover `n`?
function Scrip.canAfford(player, n)
    return Scrip.get(player) >= math.max(0, math.floor(tonumber(n) or 0))
end

-- Spend `n`. All-or-nothing: returns false and takes NOTHING when the purse will not cover it, which is
-- the contract Player.spendGold keeps and the one every caller here already expects -- a merchant that
-- half-charged for a relic it then refused to hand over would be worse than one that refuses.
--
-- Combat.spendPurse is the deliberate exception and does not come through here: a money ability is
-- specified to spend what is on hand and land soft, so it calls Scrip.take instead.
function Scrip.spend(player, n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    if not player or not Scrip.canAfford(player, n) then return false end
    player.scrip = Scrip.get(player) - n
    return true
end

-- Take up to `n` (all of it when nil) and report what was ACTUALLY taken. The clamping half of the
-- pair, for the money kit: a broke party spends its last coppers and the blow lands small, rather than
-- the ability refusing. Same shape as Combat.spendChi, which is what the effects already scale off.
function Scrip.take(player, n)
    local have = Scrip.get(player)
    local took = n and math.max(0, math.min(math.floor(n), have)) or have
    if took > 0 then player.scrip = have - took end
    return took
end

-- THE SURFACE. Everything left in the purse is gone, and this is called from every exit a descent has
-- -- the stair up, the Hollow Crown, and a wipe (states/game.lua). Returns what was burned so the exit
-- can name it: a resource that vanishes silently reads as a bug the first time a player notices, and
-- reads as theft the second.
--
-- CALLED ON THE WIPE PATH TOO, which is not a second punishment. A wipe already takes the pack
-- (Descent.dropPack) and the ore (Player.loseHaul); the scrip goes because the RUN ended, the same as
-- it goes when you walk out having won. There is no exit that keeps it, which is what makes the rule
-- one sentence instead of a table.
function Scrip.clear(player)
    local had = Scrip.get(player)
    if player then player.scrip = 0 end
    return had
end

-- Open a run's purse. Distinct from Scrip.add so the seam that starts a descent says what it means, and
-- so a resumed run cannot be topped up a second time by a path that meant to initialise.
function Scrip.open(player)
    if not player then return 0 end
    player.scrip = Scrip.OPENING
    return player.scrip
end

return Scrip
