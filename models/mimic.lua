-- A chest that is a monster, and the one field that makes it one.
--
-- THE PREMISE, IN ONE SENTENCE: some fraction of the lids on a floor are not lids. The board says
-- treasure, the marker says treasure, the gloss says "an unguarded cache -- nothing stands over it";
-- and then the company puts a hand in and the cache stands up.
--
-- WHY IT SPRINGS ON *OPEN* RATHER THAN ON ARRIVAL. A fight that begins the instant the token lands on
-- the tile is a toll, not a decision -- the player is handed a bill for having walked somewhere, with
-- nothing they could have done differently. Pressing Open is a decision, and it is ALREADY the
-- decision this stop asks: a wired lid is answered on the same screen with the same two answers (open
-- it anyway, or leave it and come back better kitted), and a company carrying no charm is never
-- offered the choice because it cannot read the lid. This is that arrangement with teeth in it. The
-- seam is the panel's `onOpen`, the out is the panel's own Cancel, and the cell is left uncleared --
-- so a mimic left alone is still standing there on the next trip down, exactly as a chest is
-- (Descent.keepFloor).
--
-- WHAT IT CARRIES IS WHAT IT DROPS, and that is ONE LIST read twice rather than two lists kept in
-- step. `encounter.carried` arms the body (models/growth.lua's Growth.spawn folds the ids into its
-- grid, where the fight reads them like any other kit -- the weapon swings, the coat mitigates, the
-- ability gets cast) and the same field is paid out on the win (models/encounter_battle.lua's
-- EncounterBattle.spoils). There is no second ledger to go stale, and the sentence a player would say
-- about the fight -- "it was hitting me with the axe it was sitting on" -- is a fact about the data
-- rather than a coincidence of tuning.
--
-- WHAT IT IS WORTH. The chest's contents are paid GUARANTEED, on top of what an elite fight rolls of
-- its own -- so springing a mimic is a better outcome than opening the chest would have been, not a
-- tax on having opened it. That is the economy's own law rather than generosity (docs/the-count.md,
-- docs/economy.md): the game prices decisions and never prices failure or need, and a stop that
-- punished the player for taking the reward it advertised is exactly the shape that law forbids.
--
-- AND IT DOES NOT RE-ARM. Descent.rearmFloor wakes every cleared `combat`/`elite` on a kept board --
-- the monsters re-arm and the places do not -- and a mimic is both. It is settled as the PLACE, on
-- what it pays: a chest pays once, and a body that hands over a chest's contents every time the
-- company walks back down to it is a printing press. The `mimic` flag rides the sprung encounter for
-- exactly that one clause.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Mimic = {}

-- The body, and the fight it stands in. Both are ordinary content -- data/characters/character_mimic
-- .lua and data/encounters/encounter_mimic.lua -- named here so the one place that springs one
-- (states/game.lua) never spells either out.
--
-- The encounter blueprint carries `weight = 0`, so the floor generator's pool can never deal this
-- fight onto a tile of its own. The ONLY way to meet it is to open the wrong chest, which is the
-- whole premise: a mimic that could turn up as a plain marked fight would be a monster that is
-- sometimes disguised, and the disguise is the monster.
Mimic.BODY = "character_mimic"
Mimic.ENCOUNTER = "encounter_mimic"

-- HOW MANY LIDS ARE ALIVE, as a percent (Overworld:placeTraps' third half, Descent.MIMIC_CHEST_CHANCE).
--
-- A FIFTH, against the wired lid's third, and the gap between the two numbers is the difference
-- between a cost and a fight. A wire is a few points of health and a toast; it can afford to be the
-- common case because answering it wrong is survivable and the question is cheap to re-ask. A mimic
-- is a set-piece -- a body, a board, a deployment, several minutes -- and a stop that expensive wants
-- to be rare enough that meeting one is a story rather than a rate.
--
-- ...AND A LID IS EITHER WIRED OR ALIVE, NEVER BOTH (the pass in models/overworld.lua skips a mimic
-- when it wires chests). Not for balance: a trap that springs on `onCollect` would simply never fire,
-- because a mimic never reaches the collect -- so a wired mimic would be a flag that silently did
-- nothing, which is the one outcome worth ruling out by construction rather than by luck.
Mimic.CHANCE = 20

-- ...AND THE ONE THING IT PAYS THAT A CHEST NEVER COULD: its own gullet, on a flat percent, on top of
-- everything else the win hands over (data/items/utility/utility_still_hungry.lua).
--
-- A THIRD DROP ROUTE, AND IT IS A THIRD ONE ON PURPOSE. The two the game already has answer different
-- questions. A body's `drops` list feeds STEP 2 of the rank draw (docs/drops.md): the piece competes
-- for the fight's one or two slots and only when the floor happens to draw its rank, which is exactly
-- right for "what this body is known for" and useless for "and sometimes it gives you THE thing".
-- Descent.DROPS is a general's authored queue -- guaranteed, no roll, paid down in order. Neither can
-- say "a percent, outside the roll", and that is the shape a chase piece wants.
--
-- FORTY. There are only about three mimics in a whole playthrough -- one chest a floor, fifteen floors,
-- a fifth of them alive -- and they do not re-arm, so this cannot be farmed the way a body on a kept
-- floor can. At forty percent, four playthroughs in five see one and the fifth does not, which is a
-- chase you usually complete. At a quarter it would be a coin flip on whether the item exists in your
-- game at all, which is not scarcity, it is absence.
--
-- SKIPPED ONCE THE COMPANY HOLDS ONE, the rule Descent.dropFor already keeps: the bonus is best-not-sum
-- (Descent.haulBonus) so a second copy is dead weight, and dealing dead weight in place of an elite's
-- ordinary roll would make beating the second mimic worth LESS than beating an ordinary body.
Mimic.TROPHY = { id = "utility_still_hungry", chance = 40 }

-- Is this stop a chest with something in it that is awake? Asked of the CELL'S encounter (the plain
-- table the board serializes), like Encounter.opensBattle, because that is what every caller holds.
function Mimic.lurks(enc)
    return enc ~= nil and enc.kind == "treasure" and enc.mimic == true
end

-- The fight `enc` turns into, carrying `loot` -- the chest's resolved contents, which become both the
-- body's kit and the win's guaranteed payout.
--
-- IT IS AN `elite`, AND THE KIND IS LOAD-BEARING IN THREE PLACES rather than a label. Arena.enemyCap
-- reads it and seats a set-piece rather than a skirmish (immaterial for a cast of one, but the tier is
-- what a floor-wide ceiling may not cut -- Arena.UNCAPPED_KINDS -- so an opening floor's two-body cap
-- cannot quietly delete the only body in the fight); Spoils.SEALED_CHANCE prices an elite's husk at
-- 0.50, which is exactly what a `treasure` was already paying, so springing the lid neither gains nor
-- loses the company a sealed find; and the gold and the drop roll are an elite's, which is the risk
-- paid for.
--
-- The tier rides across from the chest (models/overworld.lua stamps one on every stop), so a mimic
-- found on hard ground is paid at that ground's rate like anything else standing on it.
function Mimic.spring(enc, loot)
    enc = enc or {}
    local carried = {}
    -- Copied rather than aliased: this list is about to be written into a cell that is saved, armed
    -- into a character's grid and paid out on a win, and the caller's table is the chest's own.
    for _, id in ipairs(loot or {}) do carried[#carried + 1] = id end
    return {
        id = Mimic.ENCOUNTER,
        kind = "elite",
        -- Named here rather than left to the blueprint because the encounter table on the cell is what
        -- every readout in the stack reads -- the battle's title bar, the summary panel, the marker's
        -- hover card -- and a sprung mimic that walked around calling itself "Treasure Chest" would be
        -- the disguise outliving the reveal.
        name = "Mimic",
        -- The flag, kept on the sprung fight for the one clause that reads it: Descent.rearmFloor
        -- leaves this cell cleared when it wakes the floor's other fights. See the header.
        mimic = true,
        tier = enc.tier,
        -- ONE LIST, TWICE. Keyed by the body's id rather than by seat index, because a seat is a
        -- position in a composition that Arena.clampComposition may re-cut and an id is not -- and
        -- because keyed this way the field says what it means: a body of this kind, in this fight, is
        -- holding these.
        --
        -- A grid holds nine and the body's own bite takes one, so a chest of more than eight pieces is
        -- carried in part and paid in full. That is the right way round: what it is HOLDING is a
        -- question about the fight, and what it OWES is a question about the chest.
        carried = { [Mimic.BODY] = carried },
        -- ...and the chance at its own gullet, stamped onto the cell rather than looked up off the body
        -- at payout time. On the ENCOUNTER because that is the table that survives into the save: a
        -- fight the player walked away from and came back to two trips later must offer the same odds
        -- at the same piece, and a constant read at the till would silently re-price every open fight
        -- on disk the day somebody tunes it.
        trophy = { id = Mimic.TROPHY.id, chance = Mimic.TROPHY.chance },
    }
end

-- Every item id owed by a fight's `carried` table, flattened. The win pays these on top of whatever it
-- rolled (EncounterBattle.spoils), and nothing else in the stack has to know which body was holding
-- what -- the payout is the chest's contents, however many mouths it was divided between.
--
-- WALKED IN SORTED KEY ORDER, which is not fussiness: this list becomes a payout, a payout is written
-- into a save, and `pairs` over a keyed table is in whatever order this Lua build happens to hash the
-- strings in. Two machines resolving the same fight would otherwise bank the same items in a different
-- sequence -- the identical failure Encounter.pool's sort exists to prevent one layer up.
function Mimic.owed(enc)
    local keys, out = {}, {}
    for id in pairs((enc and enc.carried) or {}) do keys[#keys + 1] = id end
    table.sort(keys)
    for _, key in ipairs(keys) do
        for _, id in ipairs(enc.carried[key]) do out[#out + 1] = id end
    end
    return out
end

return Mimic
