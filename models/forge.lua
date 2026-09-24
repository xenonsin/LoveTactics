-- The ladder that raises an item's `level`. Upgrading bakes into the item's scaling magnitudes and
-- its " +n" name (Item.instantiate). Vendors SELL; this UPGRADES -- one bill, one ladder. Pure logic,
-- headless-safe: ui/panels/forge.lua drives it.
--
-- ONE LADDER, TWO ROOMS -- see Forge.WORK. The bill, the ceiling and the rung are the same wherever
-- the player is standing; what differs is who does the work, and a smith does not hone a spell.
--
-- THREE KINDS OF WORK, all raising the same level:
--   gear       weapon / armor / utility, per instance -- you own one and hammer it
--   ability    per instance too. Was the class vendor's Upgrade tab; the bill and gate came here.
--   recipe     consumables, per TYPE -- refine the recipe (Player.recipeLevel) and every copy bought
--              thereafter comes at that tier. Was Vendor.upgradeRecipe.
--
-- THE BILL is three tracks (see models/material.lua for the two material families):
--   technique      what stock belonging to a HOUSE is forged with: the currency a character banks by
--                  playing that house, keyed on the item's discipline if it has one and its class
--                  otherwise (models/class.lua).
--   gold           only for stock belonging to no house at all -- a natural weapon. Never both; the
--                  two are alternatives on one track, not a surcharge.
--   craft stock    the grade the ITEM's own quality draws on, times a count that climbs
--   house stock    the item's class's material -- and for a DISCIPLINE item, every parent class's
--                  material at double the rate. That is the discipline gate: the deep cut of the shelf
--                  costs stock from both lines it descends from, so you must have run them.
--
-- WHY THE BENCH STOPPED TAKING GOLD. Class gear used to cost gold like everything else and be
-- held back by a CEILING of `Class.level + 2` -- so a quest spent playing a ninja bought,
-- eventually and invisibly, the right to pay the same gold a knight pays for a knight thing. That is a
-- permission slip, not a reward, and permission slips are not felt. Billing the play itself closes the
-- loop where the player can see it: fight as a ninja, bank ninja technique, forge the ninja kit.
--
-- That argument was never actually about disciplines -- it is about what a bench should charge for --
-- so it now covers the whole shelf. Fight as a knight, forge the knight kit. Gold and technique end up
-- with a clean division of labour instead of an arbitrary one: GOLD BUYS BREADTH (a vendor hands you a
-- thing you did not have), TECHNIQUE BUYS DEPTH (a bench makes a thing you already carry better). Gold
-- keeps its sinks -- the shelves, the overworld caches, the purse abilities -- and stops being the
-- answer to two different questions.
--
-- THE CEILING is keyed on the item, not on where you stand (the old Vendor.abilityLevelCap gated by
-- whichever shop happened to be open). See Forge.ceilingFor.

local Character = require("models.character") -- MAX_INVENTORY: the cells a body carries a kit in
local Class = require("models.class")
local Errand = require("models.errand") -- how many rungs a house asks for; the ladder the ceiling is laid on
local Item = require("models.item")
local Material = require("models.material")
local Player = require("models.player")
local Quest = require("models.quest")
local Vendor = require("models.vendor")

local Forge = {}

-- What a rung costs in gold -- reached ONLY by classless stock now (see currencyFor). Everything with
-- a house is billed in technique at Class.techniqueCost, which was tuned against this number so
-- the ladder kept its shape when the currency moved.
Forge.GOLD_PER_LEVEL = 40

-- Rungs a class item may climb before its house has been run at all, with the rest of the ladder
-- spread over the errands it asks for after (see Forge.ceilingFor).
--
-- This used to read Vendor.tier -- the four-value wave enum { 0, 3, 6, 10 } -- and by the end the
-- FORGE was its last consumer anywhere in the game: tools/unlock_rescale.lua moved all 339 item gates
-- onto per-quest `unlockLevel` and left the bench behind. So the shelf moved every quest while the
-- bench moved four times a line, which put the ceiling at +2 for a house's first three quests. Against
-- a common weapon curve of +1 power per rung, that is two points of answer at exactly the moment the
-- player has the least of everything else -- the bench was at its least useful where it was most
-- needed, and a lever nobody can pull is not a lever.
--
-- 3, and the rest of the ladder spread over the line, so the bench tops out exactly as a house's work
-- runs out rather than never. Standing still gates it; the granularity still matches the shelf's, so
-- one errand at a house moves both halves of that house's offer.
--
-- IT WAS ONE RUNG PER QUEST, AND THAT WAS A LADDER LENGTH IN DISGUISE. A house ran 12-14 quests then,
-- so +1 apiece cleared the ladder halfway down a line with room to spare. A house asks for SIX errands
-- now (models/errand.lua) and nothing else it sponsors is asked for at all, so the same constant
-- stopped every bench in the game at +9 -- one rung short, on every line, forever. Worse, the shelf did
-- not stop with it: six rungs carry the same span eleven forge levels do (Balance.slotAnchors -- the
-- last slot unforged is the first slot fully forged), so an errand was opening two levels' worth of
-- shelf while raising the bench by one.
--
-- So the ceiling reads the rung as a POSITION on whatever ladder the house is on, which is what
-- Grade.priceFor already had to learn in the same re-cut. Re-cut the shelf again and the size of a step
-- moves; where it starts and where it stops do not.
--
-- Note the ceiling was never the binding constraint at gate 0 -- the BILL is (a new save holds 6 iron
-- scrap, 2 steel ingot, 250 gold and no technique). This makes the early rungs reachable; it does not
-- make them free.
Forge.CEILING_BASE = 3

-- ---------------------------------------------------------------------------
-- WHICH BENCH -- one ladder, two rooms
-- ---------------------------------------------------------------------------

-- THE FORGE IS THE BASTION'S AND THE STUDY IS THE ARCANUM'S, and the line between them is what the
-- work is DONE WITH. A weapon, a coat and a piece of kit are hammered: heat, stock, a hand that has
-- made one before. An ability and the recipe behind a draught are written down: they are honed by
-- reading them more exactly, which is a library's trade and not a smith's.
--
-- It was one bench holding all five, and the tell was that its own panel could not describe itself in
-- one sentence -- five tabs, three verbs, two houses' worth of subject matter behind a door the knights
-- keep. A player looking for where a spell gets better had no reason to try the armoury.
--
-- NOTHING ABOUT THE LADDER MOVED. The bill (technique, gold, craft stock, house stock), the ceiling and
-- the rung are this file's, and both rooms ask this file for all three -- so an ability costs at the
-- Arcanum exactly what it cost at the Bastion yesterday. The split is about who you walk to, which is
-- the only thing a room is.
Forge.FORGE = "forge" -- the Bastion's
Forge.STUDY = "study" -- the Arcanum's

-- The room that takes an item, keyed by type. A type absent here is on no bench at all.
Forge.BENCH = {
    weapon = Forge.FORGE,
    armor = Forge.FORGE,
    utility = Forge.FORGE,
    ability = Forge.STUDY,
    consumable = Forge.STUDY,
}

-- The kinds of work each room does, in the order its tabs stand (ui/panels/forge.lua draws its
-- category strip straight off this, so a room cannot offer a tab this table does not give it).
--
-- MEND AND BREAK STAY WITH THE SMITH, and neither is a rung. Mending only ever reaches a weapon or a
-- coat (Item.WEARS), so it could not follow the abilities anywhere. Breaking is the odd one: Salvage
-- will take an ability or a draught as readily as a blade, so the Break tab at the forge lists things
-- the forge cannot RAISE. That is right -- breaking a thing down into stock is the opposite of raising
-- it, and stock is what a forge is for. The Study reads and writes; it does not smash.
Forge.WORK = {
    [Forge.FORGE] = { "gear", "mend", "break" },
    [Forge.STUDY] = { "ability", "recipe" },
}

-- Which room raises this piece, or nil for something no room touches. Asked by the panel so that what
-- a tab lists and what the split says are one answer.
function Forge.benchFor(item)
    if not item then return nil end
    return Forge.BENCH[item.type]
end

-- THE ROAD KEEPS THE SAME LINE, one wayside stop per room: the Cold Forge is the forge's coals left
-- burning (data/encounters/encounter_cold_forge.lua) and the Cold Lectern is the study's book left
-- chained open (encounter_cold_lectern.lua). Each gives ONE free rung on the half of the kit its city
-- room works, and nothing out here does both -- a single stop that hammered a blade and honed a spell
-- would be the thing the split just took apart, rebuilt underground where nobody could see it.
--
-- Keyed by ENCOUNTER KIND, because states/game.lua's branch is what reads it: one branch for both
-- stops, so neither can be given the other's list by a copy-paste.
Forge.WAYSIDE = {
    anvil = Forge.FORGE,
    lectern = Forge.STUDY,
}

-- Is this item worked at the bench per INSTANCE? Weapons, armor, utility gear and abilities all are.
-- Consumables are not: they refine per-type through Forge.recipeCost/refineRecipe instead, because a
-- stack of five potions is not five things to hammer.
--
-- A BOUND ITEM IS, AND THAT IS THIS FILE'S ORIGINAL READING RESTORED RATHER THAN A NEW ONE. `bound`
-- blocks MOVING and SELLING an item and has never meant anything else: a signature relic is welded to
-- its bearer, and it is forged in place like any other gear, which is the whole point of a build-around.
--
-- IT WAS CLOSED ONCE, FOR A LADDER THAT NO LONGER EXISTS. While the Hiring Hall dealt bodies, a
-- duplicate levelled the relic of the body it dealt twice, and leaving the bench open beside that would
-- have put two ladders on one object -- one bought with technique, one with luck -- with the cheaper of
-- the two deciding what the relic was worth. The pull is gone and the bond ledger with it, so the
-- second ladder is gone and the first one comes back.
--
-- WHICH LEAVES THE DIVISION OF LABOUR AT TWO TERMS, where it started. Gold buys BREADTH -- a vendor
-- hands you a thing you did not have. Technique buys DEPTH -- a bench makes a thing you already carry
-- better. A companion's own relic is technique's deepest sink again, which is what it was built to be.
function Forge.canWork(item)
    if not item or not Item.isUpgradable(item) then return false end
    return item.type == "weapon" or item.type == "armor"
        or item.type == "utility" or item.type == "ability"
end

-- COLD IRON: a hexed piece the bench cannot touch (models/curse.lua, docs/curses.md). One curse in the
-- rift costs no stat at all and costs the FORGE instead -- the piece fights exactly as well as it did
-- yesterday and always will, until somebody lifts the hex.
--
-- ITS OWN REASON RATHER THAN "not forgeable", because the two are different facts and the panel says
-- different things about them. "Not forgeable" is a property of the KIND of thing -- a potion was never
-- going on the bench -- and is permanent and uninteresting. This is a property of THIS COPY, it is
-- temporary, and there is somewhere to go about it. A row greyed with the wrong word sends the player
-- to the wrong building.
--
-- Asked by all three commit paths AND by Forge.upgradeCost, so the row the panel greys and the call it
-- refuses are decided by one clause -- the rule this file states at Forge.grantRefusal and has already
-- been burned by once.
function Forge.hexRefusal(item)
    if require("models.curse").blocksForge(item) then return "cursed" end
    return nil
end

-- IS `class` AN EARNED CLASS NOBODY ON THE ROSTER HAS UNLOCKED? Then its gear cannot be forged.
--
-- A found piece is full strength in any hand (anyone can carry anything), and that is what keeps a drop
-- worth picking up: a Ninja blade off floor four is a real blade today. What it cannot be is made BETTER
-- until somebody is trained as a Ninja -- the depth half of the piece waits on the unlock, which is what
-- gives an unlock something to hand over besides a shelf.
--
-- Mostly implied already, since nobody can bank the technique that pays the bill without standing in
-- the class (Class.techniqueFor). Stated anyway, for two reasons: a save carries technique banked under
-- the old split rule, and "not enough technique" is the wrong thing to tell a player whose problem is
-- that the class is shut. A root is never untrained -- every body holds the seven from the first morning.
--
-- NOT a ceiling. Forge.ceilingFor is read by the balance tools against a fake player that unlocks
-- nothing, and folding this into it would silently flatten every earned class they measure.
function Forge.untrained(player, class)
    return class ~= nil and Class.isEarned(class) and not Class.isUnlocked(player, class)
end

-- What a bench says about an untrained piece -- one sentence, so the Forge and the Anvil cannot word
-- the same refusal two ways. It names the unlock rather than the technique, because the unlock is what
-- is missing.
function Forge.untrainedText(class)
    local name = Class.displayName(class) or class or "that class"
    return "Nobody is trained as a " .. name .. " yet. Unlock the class to forge its gear."
end

-- ---------------------------------------------------------------------------
-- The ceiling
-- ---------------------------------------------------------------------------

-- How far `player` may take `item` up the ladder right now. Three rules, in order of how specific the
-- item is about where it came from:
--
--   earned class      NO ceiling. It used to be `Class.level + 2`; the technique price replaced
--                     it, and keeping both would be charging twice for the same permission -- you
--                     cannot buy a rung you have not played for, because the currency IS the playing.
--                     A brake the player watches fill beats a lock that silently opens.
--   root class        the standing of the house that sells it -- Quest.sponsorProgress, laid across the
--                     rungs that house asks for, the same ladder its shelf opens on. This SURVIVED the
--                     move to a technique price, and is not the double-charge the earned ceiling
--                     was: that one measured play, which is exactly what the price now measures, while
--                     this one measures campaign standing. Two different axes, one of each.
--   classless         no ceiling. Nothing gates it but the materials.
--
-- THE EARNED BRANCH IS FIRST AND EXPLICIT, not a fall-through, and it is now the only thing keeping
-- those two apart. It used to test `item.discipline`, which worked because earned stock carried a
-- `class` too (a Ninja blade was rogue stock) and the second field was the tell. The fold deleted that
-- second field, so the tell is the class itself: a root is a house, and anything above one is earned
-- (docs/class-fold.md). Read the predicate as the sentence it always was -- "did you play for this, or
-- did the city sell it to you" -- and note that swapping it back to a truthiness check on a field that
-- no longer exists would silently hand every item in the game an unlimited ceiling.
--
-- WHAT A CLASS ITEM'S STANDING BUYS is the rest of the ladder above CEILING_BASE, divided by the number
-- of errands the house has to ask (Forge.CEILING_BASE's note). Both ends are fixed -- an unworked house
-- opens three rungs, a finished line opens all ten -- and the rung count decides only how big a step is.
-- A house with more errands therefore climbs in smaller steps rather than further, which is what keeps
-- the Lodge's eight-rung line and the Arcanum's six worth the same bench.
--
-- The standing is CLAMPED to the rung count before it is scaled. Standing counts every completed quest
-- naming the sponsor, not just the asked ones, so a save carrying a side quest the current ladder no
-- longer asks for would otherwise scale past the top and be caught only by the min() below -- arriving
-- at the ceiling early and silently, which is the failure this whole function is here to avoid.
--
-- Returns Item.MAX_LEVEL at most, always.
function Forge.ceilingFor(player, item)
    if not item then return 0 end
    if item.class and Class.defs[item.class] and not Class.isRoot(item.class) then
        return Item.MAX_LEVEL
    end
    local class = Item.classOf(item)
    if class then
        -- HOW FAR THE COMPANY HAS GOT IN THIS ITEM'S OWN CLASS, on the 0..CLASS_LEVEL_CAP ladder
        -- (Class.classLevel), read as the roster's best holder for the same reason every other
        -- company-facing reading of it is: specializing one body opens the deep end, and spreading the
        -- same tally over four does not.
        --
        -- IT USED TO COUNT THAT HOUSE'S FINISHED QUESTS against the rung count of its errand line, and
        -- both of those are gone -- the houses do not post work any more and there is no line to run.
        -- What the ceiling was asking has not changed at all, which is why this is a re-point rather
        -- than a new rule: how deep into this house are you, and may you forge its gear that far.
        --
        -- Worth knowing that this function has already shipped one silent failure of exactly this kind:
        -- it divided by a rung count measured off a line nobody could run, and stopped every bench in
        -- the game at +9 without saying so. Reading a ladder that is always populated -- every body has
        -- a class level in everything it has ever swung, even if it is nought -- is what closes that
        -- whole family of bug.
        local rungs = Class.CLASS_LEVEL_CAP
        local held = math.min(Class.rosterLevel(player, class), rungs)
        local climb = Item.MAX_LEVEL - Forge.CEILING_BASE
        return math.min(Item.MAX_LEVEL, Forge.CEILING_BASE + math.floor(held * climb / rungs + 0.5))
    end
    return Item.MAX_LEVEL
end

-- The vendor id of the house that sells `class`, or nil. Kept as a name the Forge's own call sites read
-- naturally; the index itself moved to Vendor.forClass, which is the one owner of the class -> house
-- mapping now that the shop asks the same question.
function Forge.houseVendorFor(class)
    return Vendor.forClass(class)
end

-- ---------------------------------------------------------------------------
-- The bill
-- ---------------------------------------------------------------------------

-- The material half of a bill for taking something of quality `price` and class `class` up to
-- `target`. Split out because a recipe bills off a blueprint and an instance bills off an item, but
-- both pay the same three tracks.
--
-- IT TOOK TWO TAXONOMY ARGUMENTS and now takes one. Under the old pair of fields an earned item
-- carried both -- a Ninja blade was `class = "rogue", discipline = "ninja"` -- and the house branch
-- read the second while the plain branch read the first. The fold left one field (docs/class-fold.md),
-- and passing it as the old `discipline` argument would have been fine while passing it as the old
-- `class` argument silently billed NOTHING: Material.houseFor("ninja") is nil, `add` ignores a nil id,
-- and a crossing's gear would have forged with no house stock at all. One argument cannot be given to
-- the wrong parameter.
-- THE RUNG AT WHICH A HOUSE'S OWN GEAR STARTS DEMANDING A PART OFF ITS APEX. Eight of ten, so the
-- last three rungs are the ones that cost something no shop can sell -- and everything below stays
-- reachable by a company that has never gone apex hunting at all, which is what keeps the trophy a
-- ceiling-raiser rather than a wall across the middle of the bench.
Forge.TROPHY_RUNG = 8

local function materialsFor(target, price, class)
    local materials = {}
    local function add(id, n)
        if id then materials[id] = (materials[id] or 0) + n end
    end

    -- Craft stock: the grade is the item's own quality, the count is the depth.
    add(Material.gradeFor({ price = price }), target + 1)

    -- House stock. An EARNED class's gear pays every parent house at double the plain rate -- both
    -- lines, steeply, which is what makes the deep cut something you had to go and earn. A root's gear
    -- pays its own house at half.
    if class and Class.defs[class] and not Class.isRoot(class) then
        for _, parent in ipairs(Class.parents(class)) do
            add(Material.houseFor(parent), target)
        end
    elseif class then
        add(Material.houseFor(class), math.ceil(target / 2))
    end

    -- APEX TROPHY, at the deep rungs only. What the top of a ladder costs is a part off the top of a
    -- HOUSE -- a body you had to go and put down twice, because the first kill paid the piece and only
    -- the ones after it pay this (models/bounty.lua).
    --
    -- WHY IT IS THE RIGHT SINK. A trophy with nothing to spend it on is a trophy, and this game already
    -- has enough of those; the last three rungs of a house's own gear is the one bill in the game that
    -- should cost something no shop can sell. It also closes the loop the board opened: the posting
    -- names a piece, the repeat run pays the part, and the part is what makes the piece better.
    --
    -- Split the same way the house stock above is, and for the same reason: a discipline is a deep cut
    -- of two lines, so it pays both their houses.
    if target >= Forge.TROPHY_RUNG and class then
        local function trophyOf(c)
            return Material.trophyFor(Vendor.forClass(c))
        end
        if Class.defs[class] and not Class.isRoot(class) then
            for _, parent in ipairs(Class.parents(class)) do add(trophyOf(parent), 1) end
        else
            add(trophyOf(class), 1)
        end
    end

    return materials
end

-- The currency half of a bill. TECHNIQUE for anything that belongs to a class, and gold only for stock
-- that belongs to none at all. Never both. Returns the whole set the panel needs to draw the row and
-- say who would pay it:
--   gold, technique, techniqueId, techniqueHolder, techniqueHeld
--
-- IT USED TO PICK BETWEEN TWO FIELDS -- the discipline if there was one, else the class -- because a
-- Ninja blade was rogue stock as well, and billing it as rogue would have let generic rogue play pay
-- for the deep cut. The fold made that choice impossible to get wrong: there is one field, and it
-- already names the most specific claim (docs/class-fold.md).
local function currencyFor(player, target, class)
    local key = class and Class.defs[class] and class or nil
    if key then
        local holder, held = Class.techniqueHolder(player, key)
        return 0, Class.techniqueCost(target), key, holder, held
    end
    -- Classless stock (a natural weapon) has no house to have played for, so there is nothing to bill
    -- but coin. The last thing gold buys at this bench.
    return Forge.GOLD_PER_LEVEL * target, 0, nil, nil, 0
end

-- The cost to take `item` one level, for `player`. Returns nil once the item is at Item.MAX_LEVEL.
--   { level, gold, technique, techniqueId, techniqueHolder, techniqueHeld,
--     materials = { [id] = count }, locked, ceiling, cursed }
-- `locked` means the target is past the ceiling this player has earned -- the bill is still shown, so
-- the panel can say what it would cost and why it cannot be paid yet. A discipline item is never
-- `locked` (it has no ceiling); what stops it is simply not holding the technique, which is an
-- affordability failure like any other and reads as one.
function Forge.upgradeCost(player, item)
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    local ceiling = Forge.ceilingFor(player, item)
    local gold, technique, techId, holder, held =
        currencyFor(player, target, Item.classOf(item))
    return {
        level = target,
        gold = gold,
        technique = technique,
        techniqueId = techId,
        techniqueHolder = holder,
        techniqueHeld = held,
        materials = materialsFor(target, item.price, Item.classOf(item)),
        locked = target > ceiling,
        ceiling = ceiling,
        -- ...AND WHETHER ITS CLASS IS SHUT (Forge.untrained). On the bill for the same reason as the hex
        -- below: the panel greys the row off this table, so the refusal has to be readable here.
        untrained = Forge.untrained(player, Item.classOf(item)),
        -- ...AND WHETHER A HEX IS SITTING ON IT (Forge.hexRefusal). Carried on the bill rather than
        -- only refused at the commit, because the panel draws its rows off THIS table -- a piece that
        -- priced normally and then refused at the press is the exact "greyed for one reason, refused
        -- for another" failure Forge.grantRefusal is written against. The bill is still quoted, like
        -- `locked`, so the row can say what it would cost once the hex is lifted.
        cursed = Forge.hexRefusal(item) ~= nil,
    }
end

-- Perform an upgrade on `item` owned by `player`: verify the bench, the ceiling, the gold and the
-- materials, spend them, and return a FRESH instance at the new level (the caller swaps it into the
-- grid or stash it came from -- baking a clean instance from the blueprint is why the level math never
-- double-applies). Returns the new item, or nil + a reason:
--   "not forgeable" | "cursed" | "max level" | "untrained" | "locked" | "gold" | "technique" | "materials"
function Forge.upgrade(player, item)
    if not Forge.canWork(item) then return nil, "not forgeable" end
    local hexed = Forge.hexRefusal(item)
    if hexed then return nil, hexed end
    local cost = Forge.upgradeCost(player, item)
    if not cost then return nil, "max level" end
    if cost.untrained then return nil, "untrained" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    if cost.technique > 0 and cost.techniqueHeld < cost.technique then return nil, "technique" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    Player.spendGold(player, cost.gold)
    -- Comes off ONE body -- the strongest holder, the same one the bill named. See
    -- Class.spendTechnique for why it is never pooled across the roster.
    if cost.technique > 0 then
        Class.spendTechnique(player, cost.techniqueId, cost.technique)
    end
    Player.spendMaterials(player, cost.materials)
    return Item.instantiate(item.id, item.quantity, cost.level)
end

-- ---------------------------------------------------------------------------
-- The batch: several rungs in one commit
-- ---------------------------------------------------------------------------

-- The summed bill for taking `item` from where it stands up to `target`, as one transaction. Same
-- shape as Forge.upgradeCost plus `levels` (how many rungs are being bought) and `blockedAt` (the
-- first rung past the ceiling, or nil) -- so a panel that lets the player aim at a rung further up
-- the ladder can price the whole climb before charging for any of it.
--
-- Every rung is billed exactly as it would be alone, then added up: the craft-stock count climbs per
-- level, so three rungs cost three separate counts rather than one at the top level. Buying the climb
-- in one commit is a convenience, never a discount.
--
-- `technique` sums across the rungs, but `techniqueHeld` is the BANK and so is taken as-is rather than
-- accumulated -- it is the same number at every level, and adding it up would claim the player holds
-- three times what they do. Returns nil when there is nothing left to buy.
function Forge.costTo(player, item, target)
    local from = item.level or 0
    target = math.min(target or (from + 1), Item.MAX_LEVEL)
    if target <= from then return nil end

    local ceiling = Forge.ceilingFor(player, item)
    local class = Item.classOf(item)
    local gold, technique, techId, holder, held = 0, 0, nil, nil, 0
    local materials, blockedAt = {}, nil

    for lvl = from + 1, target do
        local g, t, id, h, bank = currencyFor(player, lvl, class)
        gold = gold + g
        technique = technique + t
        techId, holder, held = id, h, bank
        for mid, n in pairs(materialsFor(lvl, item.price, class)) do
            materials[mid] = (materials[mid] or 0) + n
        end
        if not blockedAt and lvl > ceiling then blockedAt = lvl end
    end

    return {
        level = target,
        levels = target - from,
        gold = gold,
        technique = technique,
        techniqueId = techId,
        techniqueHolder = holder,
        techniqueHeld = held,
        materials = materials,
        locked = blockedAt ~= nil,
        blockedAt = blockedAt,
        ceiling = ceiling,
        untrained = Forge.untrained(player, class),
    }
end

-- Forge `item` all the way to `target` in one commit. Returns a fresh instance at the new level, or
-- nil + one of Forge.upgrade's reasons.
--
-- THE WHOLE BATCH IS PRICED AND REFUSED BEFORE ANY OF IT IS PAID FOR. Looping Forge.upgrade and
-- letting it refuse partway would leave the player having spent gold and materials on a climb they
-- did not get -- the one failure mode a multi-rung commit introduces that a single rung cannot have.
--
-- If the loop somehow breaks anyway (it cannot, given the pre-check, but a silently swallowed rung
-- would cost the player real materials) the item reached so far is returned ALONGSIDE the reason, so
-- the caller still has something to put back in the slot. A non-nil second return therefore means
-- "this is not what you asked for", not "nothing happened".
function Forge.upgradeTo(player, item, target)
    if not Forge.canWork(item) then return nil, "not forgeable" end
    local hexed = Forge.hexRefusal(item)
    if hexed then return nil, hexed end
    local from = item.level or 0
    target = math.min(target or (from + 1), Item.MAX_LEVEL)
    if target <= from then return nil, "max level" end

    local cost = Forge.costTo(player, item, target)
    if not cost then return nil, "max level" end
    if cost.untrained then return nil, "untrained" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    if cost.technique > 0 and cost.techniqueHeld < cost.technique then return nil, "technique" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    local current = item
    for _ = from + 1, target do
        local stepped, reason = Forge.upgrade(player, current)
        if not stepped then
            return (current ~= item) and current or nil, reason
        end
        current = stepped
    end
    return current
end

-- ---------------------------------------------------------------------------
-- A rung given rather than sold
-- ---------------------------------------------------------------------------

-- Everything the company is CARRYING that a level can improve: one entry per occupied grid cell across
-- the roster, `{ item, char, cell, where }`, in roster order and then cell order.
--
-- The stash is deliberately not in it, which is the one way this differs from the bench's own collector
-- (ui/panels/forge.lua's ForgePanel:collect). Standing at a bench in the city is a moment with the whole
-- inventory open; a stop on the road is not. What a wayside forge can reach is what somebody walked in
-- wearing, so the offer is a question about the LOADOUT -- the kit the player has already committed to
-- for this floor -- rather than about the pile back home.
--
-- `room` narrows it to one bench's half (Forge.WAYSIDE hands the stop's own), and nil is every piece
-- the ladder touches. The two callers on the road both name one: the coals take gear and the book
-- takes abilities, which is the city's own line held out here.
function Forge.equipped(player, room)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory and char.inventory[cell]
            if item and Forge.canWork(item)
                and (room == nil or Forge.benchFor(item) == room) then
                out[#out + 1] = { item = item, char = char, cell = cell, where = char.name or "?" }
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Mending: the other thing a forge is for
-- ---------------------------------------------------------------------------

-- WHAT A FULL MEND COSTS, in gold, or nil for a piece that needs none.
--
-- GOLD AND NOTHING ELSE, which is what separates mending from the ladder above it. Every other bill on
-- this bench spends TECHNIQUE and STOCK because it buys DEPTH -- a rung is standing you played for.
-- Mending buys nothing: it puts a thing back the way it was. Charging technique for it would price
-- an hour at the anvil against a rung of a discipline, and a company that had to choose between
-- mending its armour and climbing its shelf would simply stop mending.
--
-- SO IT IS THE GOLD SINK. One currency, and the campaign has few places that take real money off a
-- company between trips (docs/economy.md) -- this is one, it recurs, and it scales with how good the
-- gear is, which is exactly the shape a sink wants: the richer the company, the more it costs to keep
-- what makes it rich.
--
-- A FIXED RATE PER POINT OF WEAR, AND NOT A SHARE OF WHAT THE PIECE IS WORTH. The smith charges for
-- the hour, not for the blade: a full bar costs the same to fill whether it is a starter axe or a
-- relic off a general. One number the player learns once -- so many gold a point -- and no table.
--
-- IT USED TO BE A SHARE OF `item.price` AND THAT QUIETLY STOPPED WORKING. The argument was good: a
-- tenth of what the thing is worth, so the richer the company the more it costs to keep what makes it
-- rich, which is the shape a sink wants. Then the shelf recut took `price` off everything above a
-- house's opener (docs/shelf.md) and this read `(item.price or 0)`, so for most of the catalogue the
-- bill collapsed onto the `math.max(1, ...)` floor. MEASURED: a fully destroyed Frostfall Hammer
-- mended for ONE GOLD, and so did a broken Leather Armor, while a priced iron sword cost 8. The sink
-- had not been tuned down, it had evaporated -- and nothing said so, because a formula that reads a
-- field almost nobody carries still returns a number.
--
-- SCALED BY WHAT IS MISSING, which the share version also did and which is worth keeping: half a bar
-- is half the bill. A flat fee per visit would make topping up a scratch as dear as a full mend, and
-- the only sane play would be to run every piece to nought before walking to the bench -- a rule that
-- rewards neglect and sends companies underground in gear about to die.
--
-- A BROKEN PIECE COSTS NO MORE THAN A NEARLY-BROKEN ONE, deliberately. There is no penalty rung for
-- letting it go to zero: the piece is already unusable, which is the cost, and a surcharge on top
-- would be a price on having been caught out.
--
-- TWO IS MEASURED, NOT PICKED. It puts a full weapon bar (30) at 60 gold and a full armour bar (40) at
-- 80, either side of the Ward's 40g wound -- the one other recurring between-trips bill, so the two
-- sit in a neighbourhood a player already knows. Against measured descent income (an ordinary fight
-- pays 54g on floor one and 208g on floor fifteen), a fielded four keeping a dozen pieces whole runs
-- roughly a fifth to a third of a trip's take.
--
-- WHAT A FIXED RATE GIVES UP, stated because the share version's own argument is the thing being
-- overruled: it does not climb with the campaign. Income roughly quadruples across a descent and this
-- does not, so the sink is heaviest in the first floors and thinnest at the bottom -- the opposite of
-- "the richer the company, the more it costs to keep what makes it rich". If that is the wrong trade,
-- the fix is one line rather than a redesign: price it off `Vendor.foundPrice(item)`, which is the
-- function that already answers "what is this unpriced found ware worth" and is what the share
-- version should have been reading all along.
Forge.MEND_PER_POINT = 2

function Forge.mendCost(item)
    local Item = require("models.item")
    local max = Item.durabilityMax(item)
    if not (max and item.durability and item.durability < max) then return nil end
    -- POINTS, not a fraction: the bill is the work, and the work is how much bar there is to fill.
    local missing = max - item.durability
    return math.max(1, math.floor(missing * Forge.MEND_PER_POINT + 0.5))
end

-- Mend it. Returns true, or false + "whole" | "cannot" | "poor".
--
-- IN PLACE, never as a fresh instance. Forge.upgrade hands back a new item because a rung re-bakes
-- every scaling magnitude off the blueprint; a mend changes one number and must not disturb anything
-- else -- a husk stays sealed, a bag keeps its contents, a charge item keeps its count.
function Forge.mend(player, item)
    local Item = require("models.item")
    local max = Item.durabilityMax(item)
    if not max then return false, "cannot" end
    if (item.durability or max) >= max then return false, "whole" end
    local cost = Forge.mendCost(item)
    if (player.gold or 0) < cost then return false, "poor" end
    player.gold = player.gold - cost
    item.durability = max
    return true
end

-- (THERE IS NO SCRAP VERB HERE, AND THAT IS DELIBERATE. "A broken piece turns to scrap material" is
-- already a thing this game does: models/salvage.lua breaks a piece into its own house's stock AND its
-- own quality's craft stock, stamps the discovery ledger on the way so a first copy broken underground
-- is not lost to the counter, and reads the BLUEPRINT rather than the instance's level to refuse a
-- forge-up/break-down arbitrage. It is pinned by tests/salvage_spec.lua and it is already a row on the
-- bench's panel.
--
-- A second scrap path beside it would pay a different number for the same gesture and one of the two
-- would go stale. What durability adds is the REASON to break something -- a piece too dear to mend --
-- not a new way to do it.)

-- Raise `item` one rung for FREE: no gold, no technique, no craft or house stock. Returns a fresh
-- instance at the new level -- the caller swaps it into the cell it came from, exactly as Forge.upgrade
-- does -- or nil + one of "not forgeable" | "max level" | "locked".
--
-- THE BILL IS WAIVED AND THE CEILING IS NOT, and that split is the whole of what this function decides.
-- Gold and technique are a PRICE: a thing the player pays, and a thing a gift is entitled to cover. The
-- ceiling is a STANDING -- how far into this item's own class the company has actually climbed
-- (Forge.ceilingFor) -- and no stop on the road may hand that over, because a rung past it is depth
-- nobody played for. That is the one rule this file exists to hold (see the header: gold buys breadth,
-- technique buys depth); a boon that broke it would be the road quietly selling the bench's job.
--
-- So a free rung is worth exactly what the bench's next rung is worth, and never more. An item already
-- standing at its ceiling is refused with "locked" and the caller says so out loud, rather than the
-- gift silently landing on something else.
--
-- ONE RUNG, never a batch. Forge.upgradeTo exists for a climb somebody is buying; a gift that could be
-- scrubbed up the track would make the size of the boon a thing the player picks, and a boon you set
-- the magnitude of is not a boon.
--
-- Split in two so the LIST and the COMMIT cannot disagree. A panel offering free rungs has to grey out
-- the pieces that cannot take one and say why (ui/panels/anvil.lua), and a second copy of these three
-- clauses living in the drawing code is exactly how a row ends up greyed for one reason and refused for
-- another -- or, worse, drawn bright and refused anyway. Forge.grantRefusal is the only place that
-- decides; Forge.grant is that decision plus the instance.
function Forge.grantRefusal(player, item)
    if not Forge.canWork(item) then return "not forgeable" end
    local hexed = Forge.hexRefusal(item)
    if hexed then return hexed end
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return "max level" end
    if Forge.untrained(player, Item.classOf(item)) then return "untrained" end
    if target > Forge.ceilingFor(player, item) then return "locked" end
    return nil
end

function Forge.grant(player, item)
    local reason = Forge.grantRefusal(player, item)
    if reason then return nil, reason end
    return Item.instantiate(item.id, item.quantity, (item.level or 0) + 1)
end

-- ---------------------------------------------------------------------------
-- Consumable recipes (per type)
-- ---------------------------------------------------------------------------

-- Which consumables the Study refines: any upgradable one. Unlike the old vendor rule there is no
-- "whose house is this" check -- a recipe is refined in one room, wherever the draught was bought.
function Forge.canRefine(item)
    return item ~= nil and item.type == "consumable" and Item.isUpgradable(item)
end

-- The cost to raise `itemId`'s recipe one tier for `player`. Same three tracks as an instance, billed
-- off the blueprint (a recipe has no instance to read a price from). Returns nil at Item.MAX_LEVEL.
function Forge.recipeCost(player, itemId)
    local def = Item.defs[itemId]
    if not def then return nil end
    local target = Player.recipeLevel(player, itemId) + 1
    if target > Item.MAX_LEVEL then return nil end
    local probe = { class = def.class, type = def.type }
    local ceiling = Forge.ceilingFor(player, probe)
    local gold, technique, techId, holder, held =
        currencyFor(player, target, def.class)
    return {
        level = target,
        gold = gold,
        technique = technique,
        techniqueId = techId,
        techniqueHolder = holder,
        techniqueHeld = held,
        materials = materialsFor(target, def.price, def.class),
        locked = target > ceiling,
        ceiling = ceiling,
        untrained = Forge.untrained(player, def.class),
    }
end

-- Refine the recipe for consumable `itemId` one tier: verify it refines here, that the tier is within
-- the ceiling, and that the currency and materials are there; spend them and bump Player.recipeLevel.
-- Returns the new tier, or nil + a reason ("not forgeable" | "max level" | "locked" | "gold" |
-- "technique" | "materials") -- the same reason set as Forge.upgrade, so the panel needs one
-- message table.
function Forge.refineRecipe(player, itemId)
    local def = Item.defs[itemId]
    -- A blueprint probe rather than a real instance: isUpgradable reads the blueprint off `id` anyway,
    -- so instantiating a potion just to ask whether it refines would be a wasted bake.
    if not (def and Forge.canRefine({ id = itemId, type = def.type })) then
        return nil, "not forgeable"
    end
    local cost = Forge.recipeCost(player, itemId)
    if not cost then return nil, "max level" end
    if cost.untrained then return nil, "untrained" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    if cost.technique > 0 and cost.techniqueHeld < cost.technique then return nil, "technique" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    Player.spendGold(player, cost.gold)
    if cost.technique > 0 then
        Class.spendTechnique(player, cost.techniqueId, cost.technique)
    end
    Player.spendMaterials(player, cost.materials)
    Player.setRecipeLevel(player, itemId, cost.level)
    return cost.level
end

return Forge
