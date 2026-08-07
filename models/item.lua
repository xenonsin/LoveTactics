-- Item logic. Blueprints live in data/items/<id>.lua (pure data, never
-- mutated); `Item.instantiate` builds a mutable runtime copy.

local Registry = require("models.registry")
local Sprite = require("models.sprite")
local Curve = require("models.curve")

local Item = {}

Item.defs = Registry.load("data/items", "data.items")

-- The seven classes. An item's `class` decides which vendor stocks it (see models/vendor.lua);
-- it never gates who may equip the item. Anyone can carry anything -- class only says where
-- you buy it. That is what lets a player build a bespoke class by mixing shelves (a ninja is
-- mage gear on a rogue).
--
-- Deliberately its own field rather than an entry in `tags`: `tags` drives damage scaling and
-- armor `resist` lookups, so a shop taxonomy living there would be one typo away from armor
-- mitigating "rogue" damage.
--
-- One class per deadly sin: each vendor's quest line ends facing its own (see docs/story.md).
--
-- The value is the shelf's BLURB -- its identity and the mechanics it owns, in the words docs/classes.md
-- states the contract in -- not a `true`. Every reader of this table wants either its keys (the seven
-- classes) or a truthiness check, so carrying the sentence here costs nothing and means the set of
-- classes and the sentences describing them can never drift apart the way two parallel tables would.
-- Read it through Item.classDescription; `tests/class_spec.lua` pins that every class has one.
Item.CLASSES = {
    -- wrath
    fighter = "Wrath is what happens directly in front of you. Trades its own health and tempo for "
        .. "damage: front-arc sweeps, stuns, and strikes that cost you something to land.",
    -- lust
    priest = "Zones and wards. Holds ground open and closes it to others -- holy damage, negates and "
        .. "reflects, cleansing, friendly hazards, revival, and the bare fist.",
    -- gluttony
    hunter = "Setup, then payoff, most of it gated on a bow beside it in the grid. Marks, traps, "
        .. "animal companions and shapeshifting, cripples and roots.",
    -- sloth
    knight = "The wall. It does not kill you, it decides where you stand -- taunts, Halts, knockback, "
        .. "and guard redirects that take an ally's hit onto your own plate.",
    -- pride
    mage = "Elements, wind-ups, and remaking the ground itself. Channelled spells, hazards laid on "
        .. "tiles, sigils that reshape whatever is cast beside them, and reserve summons.",
    -- greed
    rogue = "Guile, and taking what is not yours. Conditional multipliers, blinks that return you to "
        .. "where you stood, executes, bleed, and theft.",
    -- envy
    alchemist = "Covets others' power rather than casting its own. Consumables, poison and acid, "
        .. "coatings and elixirs, and grid auras that lend what you are not.",
}

-- nil for a universal item that no class vendor stocks.
function Item.classOf(item)
    return item and item.class
end

-- The player-facing name of a shelf `class` ("fighter" -> "Fighter"), or nil for a class-less item.
-- The single owner of the wording, so every surface that names an item's base shelf -- the tooltip's
-- Class row, the shop and forge detail columns -- capitalizes it the same way. Sits beside
-- Discipline.displayName: a discipline is the locked deeper cut of a shelf, the class is the shelf.
function Item.classDisplayName(class)
    if not class then return nil end
    return (tostring(class):gsub("^%l", string.upper))
end

-- What the shelf `class` IS, in a sentence or two: its identity and the mechanics it owns (the value
-- side of Item.CLASSES above). Nil for a class-less item or an unknown class.
--
-- The shop's own answer to "what am I looking at" -- a vendor's base rack is a class, and until now the
-- only thing a player could read about one was the house's flavor line. Peer of
-- Discipline.description, which answers the same question for the locked cuts under it.
function Item.classDescription(class)
    if not class then return nil end
    local blurb = Item.CLASSES[class]
    return type(blurb) == "string" and blurb or nil
end

-- The fifteen weapon families. A weapon carries exactly one of these among its `tags`, and that tag
-- names the base mechanics the weapon inherits -- an axe cleaves, a hammer stuns, a dagger bleeds.
-- See docs/weapons.md for the contract each family owes.
--
-- Unlike `class` above this DOES live in `tags`, because a family is a real property of the swing:
-- it sits beside the damage school (physical/magical), the hit tag (slash/pierce/impact), and the
-- reach tag (melee/ranged) that scaling and armor `resist` already read. All of them are peers in one
-- flat list -- membership is what identifies the family, never position, so re-ordering an item's
-- tags can never change what it is.
Item.ARCHETYPES = {
    shield = true, staff = true, greatsword = true, axe = true,
    mace = true, dagger = true, sword = true, hammer = true,
    wand = true, spear = true, bow = true, longbow = true, unarmed = true,
    -- The censer: a focus that carries its ground with it (`incense`, see Combat.layIncense). The one
    -- family whose weapon is not the strike -- a banner is ground that stays and a trail is ground you
    -- leave behind, and this is ground that walks. See docs/weapons.md.
    censer = true,
    -- The fifteenth, and the only one no player ever shops for: a creature's own body -- a wolf's
    -- fangs, a zombie's claws, an elemental's burning hands. Granted by a blueprint's startingItems,
    -- never sold and never stolen (`noSteal`), and owing no shared mechanic beyond that, since what a
    -- monster's body does is the monster's business. It is a family so that every weapon in the game
    -- answers "which family?" -- an unfamilied weapon is an authoring slip, not a natural weapon.
    --
    -- Distinct from `unarmed`, which is the PLAYER's bare fist: that one is a single hidden instance
    -- (char.unarmed) and the fist charms find it by identity, not by tag (see combat.lua's
    -- unarmedDamageBonus). Tagging a creature's fists `unarmed` would not feed them those bonuses --
    -- it would only make them undisarmable by accident.
    natural = true,
}

-- The archetype tag on `item`, or nil if it declares none (an ability, a charm, a consumable -- none
-- of which belong to a weapon family). A weapon carrying two archetype tags is authoring error: this
-- returns whichever comes first, and tests/weapon_spec.lua fails the build over it.
function Item.archetype(item)
    if not item then return nil end
    for _, tag in ipairs(item.tags or {}) do
        if Item.ARCHETYPES[tag] then return tag end
    end
    return nil
end

-- An ability's declared resource costs, ALWAYS as a list of `{ stat, amount }` -- empty for a free
-- ability. `activeAbility.cost` may be authored either way:
--
--   cost = { stat = "stamina", amount = 8 }                     -- one pool (the common case)
--   cost = { { stat = "mana", amount = 4 },                     -- several pools, all paid together
--            { stat = "stamina", amount = 5 } }
--
-- The single form is sugar, not a second shape: everything downstream of here prices, gates, spends
-- and draws a LIST, so a weapon that draws on two pools can never be affordable in one place and
-- unaffordable in another. Distinguished by looking for `stat` on the table itself -- a list never
-- carries one. Returns a fresh list, so callers may sort or scale it in place.
--
-- Costs are per-pool and never merged: two entries naming the same stat would be an authoring slip,
-- and are left alone rather than quietly summed, so the mistake stays visible in the tooltip.
function Item.costs(ab)
    return Item.costList(ab and ab.cost)
end

-- The same normalization for a BARE cost value rather than an ability's -- a trait def's own `cost`,
-- or the price Trait.answerCost quotes for a swing. Both shapes reach the pay path from there too,
-- so they are unpacked by the same three lines and there is exactly one place that knows what a
-- cost may look like.
function Item.costList(cost)
    if not cost then return {} end
    if cost.stat then return { { stat = cost.stat, amount = cost.amount } } end
    local out = {}
    for i, c in ipairs(cost) do out[i] = { stat = c.stat, amount = c.amount } end
    return out
end

-- Does `ab` draw on `stat`? The membership question the sorcery/silence gates ask ("is any part of
-- this paid for in mana?"), asked once so a dual-cost spell counts as sorcery on the strength of its
-- mana half rather than on whichever pool happened to be authored first.
function Item.costsStat(ab, stat)
    for _, c in ipairs(Item.costs(ab)) do
        if c.stat == stat then return true end
    end
    return false
end

-- The WIND-UP an ability commits to before it lands, normalized to (min, max) ticks -- the single
-- reader for a duration that used to be assembled from two fields in two different units.
--
-- It was `channel` (a tick count) PLUS `windup = { min, max }` (a count of ticks *on top of* the
-- channel), which meant an ability reading `windup = { min = 2, max = 5 }` actually told for four to
-- seven ticks, and the effect was handed only the second number -- so the base wind-up was a tax that
-- scaled nothing and every reader had to re-add the two halves by hand. One field now, in TOTAL
-- ticks, and "not chargeable" is simply `min == max`.
--
-- Two authored shapes, because 40 of the 44 wind-ups in the game are a fixed tell and should not
-- have to grow a table to say so:
--   * `windup = 4`              -- a fixed four-tick wind-up (Meteor Storm, an iron greatsword)
--   * `windup = { min, max }`   -- chargeable: the caster picks the depth at cast (The First Motion)
-- A missing `windup` is (0, 0): the ability resolves at once and never takes the channel path.
-- `max` below `min` is clamped up rather than refused -- a bad range should shorten a tell, never
-- make an ability uncastable.
--
-- NOTE this is the ABILITY's field. The pending payload on a unit mid-cast is still `unit.channel`,
-- and Combat.interruptChannel / status_channeling keep their names: "a channel in progress" is a
-- different thing from "how long this ability winds up", and only the latter folded.
function Item.windupRange(ab)
    local wu = ab and ab.windup
    if not wu then return 0, 0 end
    if type(wu) == "number" then return math.max(0, wu), math.max(0, wu) end
    local lo = math.max(0, wu.min or 0)
    return lo, math.max(lo, wu.max or lo)
end

-- Is this ability chargeable -- does the caster get to choose how long to hold it? The question the
-- battle UI's +/- control and the AI's optional `windup` rule both ask, so a fixed tell and a
-- chargeable one are never told apart by poking at the field's type in two places.
function Item.isChargeable(ab)
    local lo, hi = Item.windupRange(ab)
    return hi > lo
end

-- Does `ab` let the caster BUY its effect at cast -- pay gold, in a confirm-time chooser, to size the
-- blow (The Gilded Wound: gold in, damage out)? The parallel of Item.isChargeable for the spend chooser
-- (ui/panels/spend_chooser.lua): a purchasable ability declares `purchase = { perDamage = 10, max = N }`,
-- and the battle UI raises the money slider on confirm instead of committing the swing at once.
function Item.isPurchasable(ab)
    return ab ~= nil and ab.purchase ~= nil
end

-- A purchasable ability's exchange rate and ceiling, normalized: `perDamage` gold buys one point of
-- damage (default 10), `max` caps how many points a single cast may buy (default 25) -- so a fat purse
-- cannot dial an unbounded blow, and the chooser stays a slider rather than a mile-long ladder. Returns
-- (perDamage, max), or nil for an ability that is not purchasable.
function Item.purchaseRate(ab)
    local p = ab and ab.purchase
    if not p then return nil end
    return math.max(1, p.perDamage or 10), math.max(1, p.max or 25)
end

-- Is this a two-stage THROW (Heave): grab an adjacent target, THEN choose where it lands? Such an
-- ability aims twice -- the battle UI runs a grab phase and a destination phase instead of the one
-- aim every other ability takes. A tile-target ability without this flag stays single-aim.
function Item.isThrow(ab)
    return ab ~= nil and ab.throw == true
end

-- Stacking: only consumables occupy a single inventory slot as a countable stack (a bundle of
-- health potions with a finite number of uses). Every other type is one-per-slot. A stack can
-- grow up to `maxStack` (the blueprint may override Item.DEFAULT_MAX_STACK), so "limited uses"
-- is just the running `quantity` on the instance. Character.addItem merges same-id stacks and
-- Combat.useItem decrements a stack on a consuming use, removing the slot only at 0.
Item.DEFAULT_MAX_STACK = 9

-- Is this item (instance or def) allowed to stack? Consumables only.
function Item.isStackable(item)
    return item ~= nil and item.type == "consumable"
end

-- The maximum count a stack of this item may hold (1 for anything non-stackable).
function Item.maxStack(item)
    if not Item.isStackable(item) then return 1 end
    return item.maxStack or Item.DEFAULT_MAX_STACK
end

-- Is this item bound to its holder? A bound item (a character's signature relic) can never be moved
-- within the grid, stowed, given away, sold, or stolen -- only upgraded in place. It's a reusable
-- flag: any item can set `bound = true` and every mutation path (the grid editor, the party panel,
-- the vendor, combat theft) refuses to move it. The one thing that reads it, so they all agree.
function Item.isBound(item)
    return item ~= nil and item.bound == true
end

-- Recursively copy a blueprint value so a runtime instance never mutates the immutable
-- def. Tables are copied; every non-table value (numbers, strings, and crucially the
-- ability `effect` *function*) is carried by reference -- functions aren't mutated, so
-- sharing the reference is correct (and the only option).
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = deepCopy(v) end
    return out
end

-- The highest upgrade level a forgeable item can reach. Every item carries a `level` from 0 (base) to
-- MAX_LEVEL, and that level -- not any derived rating -- is the single number every stat scales with.
-- Derived from models/curve.lua's LEVELS (which counts level 0) rather than written out again, so the
-- generators and the ceiling they generate up to cannot drift apart.
Item.MAX_LEVEL = Curve.LEVELS - 1

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- Sorted keys of a map, so pairs-driven rows (armor bonuses/resists) chart deterministically.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

-- Resolve one authored magnitude to its value at `level`. A TUNED magnitude is a list over the levels
-- 0..MAX_LEVEL (element 1 = level 0, element 2 = level 1, ...); a level past the authored length
-- clamps to the last entry, so a short list holds flat once it runs out. A plain NUMBER is a flat
-- magnitude that does not scale -- the same at every level (the form most items still carry). This is
-- the single rule the whole model reads: "what is this magnitude worth at this upgrade level?"
local function resolveLevel(v, level)
    if type(v) ~= "table" then return v end
    local idx = math.max(1, math.min(#v, (level or 0) + 1))
    return v[idx]
end
Item.resolveLevel = resolveLevel

-- An ability names its magnitude for what it does: a weapon/spell's `damage`, a potion's `healing`,
-- a draught's `restore`, or a scroll's `reviveHealth`. Exactly one is authored per ability. Each entry
-- is { key, label } -- the label heads the tooltip/shop row. A summon or a placed hazard/trap declares
-- no such magnitude: it scales off the item's upgrade level (fx.level) instead, so it has no headline.
local ABILITY_MAGNITUDES = {
    { "damage", "Damage" },
    { "healing", "Healing" },
    { "restore", "Restore" },
    { "reviveHealth", "Revive" },
    -- A ward's magnitude is COVERAGE: how many blows it swallows before it is spent (the barriers,
    -- which pass it to the status as its `magnitude`). The odd one out in kind but not in shape --
    -- an ability that negates a hit outright has no number to make bigger, so the only axis an
    -- upgrade can move it along is how many hits it does that to.
    { "hits", "Hits" },
}

-- An ability's SECONDARY magnitudes: authored, tuned per level exactly like the headline above, but
-- never the headline itself. A spell whose payload is not its damage needs somewhere to put the
-- payload's number, and deriving it from the damage (which is what Jolt used to do) welds two stats
-- that want different curves together -- a Jolt is deliberately a feeble hit selling TEMPO, so the
-- delay it buys has no business being pinned to how little it hurts.
--
-- Excluded from ABILITY_MAGNITUDES on purpose: `primaryStat` leads the tooltip with the number that
-- says what the item IS, and for an offensive spell that is still its damage.
local ABILITY_SECONDARY_MAGNITUDES = {
    "stun", -- ticks a Jolt adds to its target's initiative (data/items/ability/ability_jolt.lua)
}

-- The `waitBehavior` payoffs that scale with the granting item's level -- what the swapped Wait pays
-- out: defend's brace (`defense`) and the share it lends adjacent allies (`covers`), focus's mana,
-- overwatch's per-shot stamina, and perform's air (`duration` -- how long it holds -- and `amount`,
-- the magnitude handed to whichever status the air lays).
--
-- Deliberately NOT here: `speed`, which is what the swap COSTS rather than what it pays (see below),
-- and a perform's `earshot`, on the censer's principle -- an upgrade buys a longer, stronger song,
-- never one that carries further.
--
-- `power` is Gather's payoff (Combat.gather feeds it to the Empowered status as its magnitude), the
-- offensive twin of Defend's `defense` -- so a forged charm coils a heavier blow, exactly as a forged
-- shield braces harder. `covers` already rides this list and does double duty as Gather's lent share.
local WAIT_BEHAVIOR_MAGNITUDES = { "defense", "power", "mana", "stamina", "covers", "duration", "amount" }

-- Every place an item carries a scaling magnitude, as get/set pairs, so one walk resolves them all at
-- instantiate. This is the definition of "a derived magnitude": an ability's damage/healing/etc.,
-- armor's stat bonuses and resists, a resource ceiling, a wait-swap's payoff, and an aura's
-- amount/range/status magnitude.
local function eachMagnitude(item, fn)
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do
            local key = m[1]
            if ab[key] ~= nil then fn(ab[key], function(x) ab[key] = x end) end
        end
        for _, key in ipairs(ABILITY_SECONDARY_MAGNITUDES) do
            if ab[key] ~= nil then fn(ab[key], function(x) ab[key] = x end) end
        end
        -- A directional blast footprint can widen with the forge: `shape` and `length` (and the
        -- centred shapes' `width`/`radius`) may each be authored as a per-level list, resolved here
        -- to this level's entry exactly as a numeric magnitude is. That lets a weapon open from a
        -- straight line into a cone as it is forged (data/items/weapon/weapon_first_motion.lua), and
        -- keeps the preview footprint and the effect's fx.aoeUnits reading one baked-in shape.
        local aoe = ab.aoe
        if aoe then
            for _, key in ipairs({ "shape", "length", "width", "radius" }) do
                if aoe[key] ~= nil then fn(aoe[key], function(x) aoe[key] = x end) end
            end
        end
    end
    if item.bonus then for k, v in pairs(item.bonus) do fn(v, function(x) item.bonus[k] = x end) end end
    if item.resist then for k, v in pairs(item.resist) do fn(v, function(x) item.resist[k] = x end) end end
    if item.maxBonus then for k, v in pairs(item.maxBonus) do fn(v, function(x) item.maxBonus[k] = x end) end end
    if item.unarmedBonus then for k, v in pairs(item.unarmedBonus) do fn(v, function(x) item.unarmedBonus[k] = x end) end end
    -- A wait-swap's payoff scales with its item's level too, so a forged shield braces harder and a
    -- forged staff meditates deeper: `defense` (Combat.defend feeds it to the Defending status as its
    -- magnitude), `mana` (Combat.focus restores it), `stamina` (Combat.overwatch's per-shot budget).
    -- Deliberately NOT `speed`: that is what the swap costs the timeline, not what it pays out, and an
    -- upgrade should never buy back tempo.
    local wb = item.waitBehavior
    if wb then
        for _, key in ipairs(WAIT_BEHAVIOR_MAGNITUDES) do
            if wb[key] ~= nil then fn(wb[key], function(x) wb[key] = x end) end
        end
    end
    -- A censer's smoke thickens with its level: `amount` rides in as the granted status's magnitude,
    -- exactly as a wait-swap's payoff does. Deliberately NOT `radius` -- that is the censer's reach,
    -- and an upgrade buys a stronger blessing, never a wider one. Same line the wait swap draws above.
    local inc = item.incense
    if inc and inc.amount ~= nil then fn(inc.amount, function(x) inc.amount = x end) end
    local aura = item.aura
    if aura then
        if aura.amountBonus ~= nil then fn(aura.amountBonus, function(x) aura.amountBonus = x end) end
        if aura.rangeBonus ~= nil then fn(aura.rangeBonus, function(x) aura.rangeBonus = x end) end
        -- The tempo discount (Quickened Sigil), authored as a negative curve. Every NUMERIC aura field
        -- belongs here; the flags (`careful`, `twin`, `preserve`) do not, because there is no curve to
        -- resolve on a boolean and an upgrade has nothing to buy on one.
        if aura.speedBonus ~= nil then fn(aura.speedBonus, function(x) aura.speedBonus = x end) end
        if aura.lifesteal ~= nil then fn(aura.lifesteal, function(x) aura.lifesteal = x end) end
        local st = aura.status
        if st and st.opts and st.opts.magnitude ~= nil then
            fn(st.opts.magnitude, function(x) st.opts.magnitude = x end)
        end
    end
end

-- The item's primary stat -- the one the tooltip/shop headline leads with -- as `value, label, key`.
-- The priority reads off the stat that defines the item: an ability's own magnitude (damage / healing
-- / etc.), then armor's defense / magic defense, then the largest of any remaining bonus / resource /
-- aura magnitude. Resolved at the item's level, so it quotes the current (leveled) number. `key` is the
-- raw bonus key (or nil) so a caller can suppress that same row elsewhere. nil when the item grants no
-- magnitude at all.
function Item.primaryStat(item)
    if not item then return nil end
    local lvl = item.level or 0
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do
            if ab[m[1]] ~= nil then return resolveLevel(ab[m[1]], lvl), m[2], nil end
        end
    end
    if item.bonus then
        if item.bonus.defense ~= nil then return resolveLevel(item.bonus.defense, lvl), "Defense", "defense" end
        if item.bonus.magicDefense ~= nil then return resolveLevel(item.bonus.magicDefense, lvl), "Magic Defense", "magicDefense" end
    end
    local best, bestLabel, bestKey
    local function consider(v, label, key)
        v = resolveLevel(v, lvl)
        if v and v ~= 0 and (not best or math.abs(v) > math.abs(best)) then best, bestLabel, bestKey = v, label, key end
    end
    if item.bonus then for k, v in pairs(item.bonus) do consider(v, titleCase(k), k) end end
    if item.maxBonus then for k, v in pairs(item.maxBonus) do consider(v, "Max " .. titleCase(k)) end end
    if item.unarmedBonus then for k, v in pairs(item.unarmedBonus) do consider(v, "Fist " .. titleCase(k)) end end
    local aura = item.aura
    if aura then
        -- The status's own NAME, not its registry id: a header reading "STATUS_BURN" is the id leaking
        -- into the tooltip, and the registry is the one place that word belongs. Falls back to the
        -- title-cased id only for a status with no blueprint, which is a data error worth seeing.
        if aura.status and aura.status.opts then
            local def = require("models.status").defs[aura.status.id]
            consider(aura.status.opts.magnitude, (def and def.name) or titleCase(aura.status.id or "effect"))
        end
        consider(aura.amountBonus, "Aura Amount")
        consider(aura.rangeBonus, "Aura Range")
    end
    if best then return best, bestLabel, bestKey end
    return nil
end

-- Whether an item can be leveled up at all: it can, as long as some magnitude actually MOVES with the
-- level. WHERE it is leveled is a routing question the forge/vendor answer (weapons/armor/utility at
-- the smithy, abilities at their class vendor, consumables at the alchemist); this only asks whether
-- there is anything for a level to buy. An item with no magnitude (a plain torch) can't be upgraded --
-- and neither can one whose every magnitude is FLAT, which is the whole-ladder version of the dead
-- forge level: the Shepherd's Crook deals nothing by design, so a bench offering to sharpen it was
-- selling the player ten upgrades of nothing.
--
-- Read off the BLUEPRINT, not the instance: an instance has had its curves resolved to this level's
-- numbers already (applyLevel), so by then a curve and a flat magnitude look identical. Deliberately
-- counts the aoe footprint too -- a line that opens into a cone is something a level buys.
function Item.isUpgradable(item)
    if item == nil then return false end
    local def = Item.defs[item.id]
    if not def then return false end
    -- The escape hatch for an item whose gain is computed INSIDE its effect off fx.level rather than
    -- authored as a magnitude -- the warding wands, whose forge buys their ward more ticks (`duration =
    -- 12 + 2 * fx.level`). Nothing here can see that, so the blueprint says so out loud.
    if def.scalesWithLevel then return true end
    local moves = false
    eachMagnitude(def, function(v)
        if type(v) == "table" and #v > 1 and v[#v] ~= v[1] then moves = true end
    end)
    return moves
end

-- primaryStat's companion: where that names the ONE headline magnitude, this names ALL of an item's
-- scaling stats, as an ordered list of { label, key, value }. It reads the very fields eachMagnitude
-- bakes (so it can never chart a stat the forge doesn't actually raise), quoting each at the given
-- instance's level. `value` is always a NUMBER here. The aoe footprint is deliberately left out --
-- its geometry is shown as a drawn shape (ui/footprint_diagram.lua), not a number -- and so are the
-- pure flags (careful/twin/preserve), which have no magnitude for a level to move.
local function statBreakdown(item)
    local out = {}
    local function add(label, key, value)
        if type(value) == "number" then out[#out + 1] = { label = label, key = key, value = value } end
    end
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do add(m[2], m[1], ab[m[1]]) end
        for _, key in ipairs(ABILITY_SECONDARY_MAGNITUDES) do add(titleCase(key), key, ab[key]) end
    end
    if item.bonus then
        -- Lead with defense / magic defense (the armor headline), then the rest alphabetically.
        add("Defense", "defense", item.bonus.defense)
        add("Magic Defense", "magicDefense", item.bonus.magicDefense)
        for _, k in ipairs(sortedKeys(item.bonus)) do
            if k ~= "defense" and k ~= "magicDefense" then add(titleCase(k), k, item.bonus[k]) end
        end
    end
    if item.resist then
        for _, tag in ipairs(sortedKeys(item.resist)) do add("Resist " .. tag, "resist:" .. tag, item.resist[tag]) end
    end
    if item.maxBonus then
        for _, k in ipairs(sortedKeys(item.maxBonus)) do add("Max " .. titleCase(k), "max:" .. k, item.maxBonus[k]) end
    end
    if item.unarmedBonus then
        for _, k in ipairs(sortedKeys(item.unarmedBonus)) do add("Fist " .. titleCase(k), "fist:" .. k, item.unarmedBonus[k]) end
    end
    local wb = item.waitBehavior
    if wb then
        add("Brace", "wb:defense", wb.defense)
        -- Gather's payoff, the offensive twin of Brace (Combat.gather hands it to Empowered as its
        -- magnitude). It was the one WAIT_BEHAVIOR_MAGNITUDES entry with no row here, which left the
        -- Centering Charm -- whose `power` is the only thing its forge raises -- charting an empty
        -- ladder while the bench still offered the upgrade.
        add("Gather Power", "wb:power", wb.power)
        add("Focus Mana", "wb:mana", wb.mana)
        add("Overwatch Stamina", "wb:stamina", wb.stamina)
        add("Covers", "wb:covers", wb.covers)
        add("Air Duration", "wb:duration", wb.duration)
        add("Air Amount", "wb:amount", wb.amount)
    end
    if item.incense then add("Incense", "incense", item.incense.amount) end
    local aura = item.aura
    if aura then
        add("Aura Amount", "aura:amount", aura.amountBonus)
        add("Aura Range", "aura:range", aura.rangeBonus)
        add("Aura Tempo", "aura:speed", aura.speedBonus)
        add("Lifesteal", "aura:lifesteal", aura.lifesteal)
        if aura.status and aura.status.opts then add("Aura Effect", "aura:status", aura.status.opts.magnitude) end
    end
    return out
end

-- Chart every stat's whole forge path, level 0..MAX_LEVEL, for the Forge's growth sheet. It bakes
-- a fresh instance at each level -- so every number is exactly what a forge would produce, never an
-- estimate -- and reads its scaling stats off statBreakdown. Accepts an item instance or a bare blueprint
-- id; returns nil for an unknown id. Pure logic (Item.instantiate is headless-safe), so the sheet is
-- fully testable without a window. Shape:
--   {
--     id, maxLevel, primaryLabel,
--     stats = { { label, key, primary, numeric = true, min, max,
--                 values  = { [0..maxLevel] = n },      -- the value at each level
--                 changed = { [1..maxLevel] = true } }, -- levels where it stepped UP from the one below
--               ... },                                  -- ONLY stats that move; primary first when it moves
--     flat  = { { label, value }, ... },  -- magnitudes present but identical at every level (a movement penalty)
--     footprint = nil | {
--       levels    = { [0..maxLevel] = { shape, length, width, radius } },  -- the aoe form at each level
--       changedAt = { levels },  -- level 0 plus every level whose footprint differs from the one below
--     },
--   }
function Item.growth(idOrItem)
    local id = type(idOrItem) == "table" and idOrItem.id or idOrItem
    if not Item.defs[id] then return nil end
    local max = Item.MAX_LEVEL

    -- One baked instance per level, plus the stat labels in the order they first appear.
    local perLevel, order, seen = {}, {}, {}
    for lvl = 0, max do
        local inst = Item.instantiate(id, 1, lvl)
        local map = {}
        for _, s in ipairs(statBreakdown(inst)) do
            map[s.label] = s.value
            if not seen[s.label] then seen[s.label] = true; order[#order + 1] = { label = s.label, key = s.key } end
        end
        perLevel[lvl] = { map = map, aoe = inst.activeAbility and inst.activeAbility.aoe }
    end

    local _, primaryLabel = Item.primaryStat(Item.instantiate(id, 1, 0))

    local stats, flat = {}, {}
    for _, o in ipairs(order) do
        local values, changed, moved, lo, hi = {}, {}, false, nil, nil
        for lvl = 0, max do
            local v = perLevel[lvl].map[o.label]
            values[lvl] = v
            if v ~= nil then
                lo = (lo == nil or v < lo) and v or lo
                hi = (hi == nil or v > hi) and v or hi
            end
            if lvl > 0 and values[lvl] ~= values[lvl - 1] then changed[lvl] = true; moved = true end
        end
        if moved then
            stats[#stats + 1] = { label = o.label, key = o.key, primary = (o.label == primaryLabel),
                numeric = true, min = lo, max = hi, values = values, changed = changed }
        else
            flat[#flat + 1] = { label = o.label, value = values[0] }
        end
    end

    -- The footprint's whole life, when the ability lays one. Its shape/length/width/radius are per-level
    -- lists the forge resolves, so a line that opens into a cone reads the exact form at each step. Only
    -- the levels where the footprint actually changes (level 0 always included) need a filmstrip thumbnail.
    local footprint
    local baseAoe = perLevel[0].aoe
    if baseAoe and (baseAoe.shape or baseAoe.radius or baseAoe.length) then
        local levels, changedAt, prev = {}, {}, nil
        for lvl = 0, max do
            local a = perLevel[lvl].aoe or {}
            local f = { shape = a.shape, length = a.length, width = a.width, radius = a.radius }
            levels[lvl] = f
            if not prev or f.shape ~= prev.shape or f.length ~= prev.length
                or f.width ~= prev.width or f.radius ~= prev.radius then
                changedAt[#changedAt + 1] = lvl
            end
            prev = f
        end
        footprint = { levels = levels, changedAt = changedAt }
    end

    return { id = id, maxLevel = max, primaryLabel = primaryLabel, stats = stats, flat = flat, footprint = footprint }
end

-- Bake `item.level` into every magnitude (resolving each per-level list to this level's tuned value)
-- and append " +n" to the display name. Called once at instantiate; an upgrade re-instantiates from
-- the blueprint at the new level (see models/forge.lua), so this never compounds onto a leveled instance.
local function applyLevel(item)
    local lvl = math.max(0, math.min(item.level or 0, Item.MAX_LEVEL))
    item.level = lvl
    eachMagnitude(item, function(v, set) set(resolveLevel(v, lvl)) end)
    if lvl > 0 then
        -- "+n" rides on the name, so it shows everywhere the name does (grid, tooltip, combat log).
        item.name = (item.name or "?") .. " +" .. lvl
    end
end

-- Build a fresh, mutable item instance from a blueprint id. `quantity` seeds a stack (clamped to
-- the item's maxStack) and defaults to 1; it is only meaningful for stackable (consumable) items.
-- `level` is the upgrade level (default 0), baked into the scaling stats and the " +n" name suffix.
function Item.instantiate(id, quantity, level)
    local def = Item.defs[id]
    assert(def, "unknown item id: " .. tostring(id))

    local item = {
        id = id,
        name = def.name,
        description = def.description,         -- what it does: mechanical, one sentence (docs/item-text.md)
        flavor = def.flavor,                   -- what it means: the story line, italic at the tooltip's foot
        sprite = Sprite.load(def.sprite),
        type = def.type,                       -- weapon | armor | consumable | ability | utility
        tags = deepCopy(def.tags),             -- descriptive tags: scaling + armor mitigation
        activeAbility = deepCopy(def.activeAbility), -- { target, range, speed, cost, effect }
        aura = deepCopy(def.aura),             -- adjacency: grants tags/statuses to neighboring casts
        bonus = deepCopy(def.bonus),           -- armor: flat stat bonuses folded in at setup
        resist = deepCopy(def.resist),         -- armor: tag -> flat damage reduction
        unarmedBonus = deepCopy(def.unarmedBonus), -- "fist" charms: buff the bare-handed strike
        maxBonus = deepCopy(def.maxBonus),     -- resource passives: raise a max health/stamina/mana ceiling
        healthReserve = deepCopy(def.healthReserve), -- guard charm: { percent } of max health locked away at setup for the armor its `bonus` buys (Combat.applyReservations)
        waitBehavior = deepCopy(def.waitBehavior), -- swaps this holder's Wait -> Focus / Defend
        moveBehavior = deepCopy(def.moveBehavior), -- swaps this holder's walk -> teleport (Blink)
        terrainEase = def.terrainEase,         -- the most the GROUND may charge its wearer per tile (Trackless Boots)
        escortsMovement = def.escortsMovement, -- ...the same cap, granted to ALLIES stepping past the bearer (Surveyor's Chain)
        charge = deepCopy(def.charge),         -- { key, from, max, resetOn }: a named pool this item banks (Combat.chargeDef)
        ephemeral = def.ephemeral,             -- field-brewed: real for this fight, gone at the gate (Combat.releaseClaims)
        trail = deepCopy(def.trail),           -- { hazard, duration } | { trap }: ground left behind every tile walked
        incense = deepCopy(def.incense),       -- { hazard, radius, amount }: ground that follows the bearer (a censer)
        visionRadius = def.visionRadius,       -- overworld vision boost (e.g. torch); nil for most
        detectRadius = def.detectRadius,       -- combat: reveals traps within this radius (detectors)
        maxStack = def.maxStack,               -- stackable (consumable) items: per-slot cap override
        noSteal = def.noSteal,                 -- a pickpocket can never lift this (a beast's fangs)
        hitAndRun = def.hitAndRun,             -- weapons: tiles the bearer gives ground after an ANSWER (Combat.answerStrike)
        hands = def.hands,                     -- weapons: 1 (default, nil) or 2 -- what Dual Wield reads
        stealPriority = def.stealPriority,     -- a pickpocket takes the highest first (decoy bait)
        noCopy = def.noCopy,                   -- a summoned copy of the holder never carries this
        bound = def.bound,                     -- bound to its holder: never moved, stowed, sold, or stolen (a signature relic)
        traits = deepCopy(def.traits),         -- combat reactions granted to whoever carries it
        -- Tunables for those traits, named by THIS item (Trait.param). What lets one trait blueprint
        -- serve two items that agree on the rule and disagree only about a figure -- the golem's guard
        -- waiting nine ticks where a knight's waits six, Sublimitas answering a spell sooner and for
        -- less. Copied beside `traits` because it is meaningless without them.
        traitParams = deepCopy(def.traitParams),
        manaShield = deepCopy(def.manaShield), -- { ratio }: wounds paid out of mana (Combat.soakIntoMana)
        statusImmunity = deepCopy(def.statusImmunity), -- status ids this carrier simply cannot be given
        phases = deepCopy(def.phases),         -- a boss relic's health-threshold script, read by trait_boss_phases
        class = def.class,                     -- which class vendor sells it; nil = sold by none
        discipline = def.discipline,           -- shop taxonomy: the locked discipline this item belongs to (docs/classes.md)
        price = def.price,                     -- vendor gold cost; nil means it is never sold
        unlockQuests = def.unlockQuests,       -- how many of the vendor's quests must be done before it is on sale (default 0)
        level = math.max(0, level or 0),       -- upgrade level; 0 = a base, un-forged item
    }

    -- Stack count: consumables carry a `quantity` (clamped to the item's cap); everything else is
    -- pinned to 1 so a non-stackable slot can never claim to hold more than one.
    if Item.isStackable(item) then
        item.quantity = math.max(1, math.min(quantity or 1, Item.maxStack(item)))
    else
        item.quantity = 1
    end

    applyLevel(item) -- fold the upgrade into the scaling stats and the display name
    return item
end

return Item
