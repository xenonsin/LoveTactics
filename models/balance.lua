-- The shared unit. Combat has exactly one damage formula (Combat.mitigatedDamage) and it is purely
-- subtractive -- `blow - defense - resists` -- which means a weapon's power and a body's armour are
-- quantities in the SAME unit and have to be authored against each other. They never were. Weapon
-- power was authored on a 4-6 scale, innate defense on a 1-22 one, and armour bonuses on a third; the
-- result is that a level-1 avatar swings 18 into 27 points of mitigation and deals the floor of 1.
--
-- This module is the denominator that was missing. It answers three questions, and every other
-- balance surface in the repo (tools/balance_report.lua, tests/balance_spec.lua) is a presentation of
-- the answers:
--
--     what does the player THROW at prestige P          Balance.attackBudget
--     what does this body SUBTRACT from it              Balance.mitigation
--     how many hits is that, in BOTH directions         Balance.exchange
--
-- THE RULE: author the TARGET, derive every NUMBER.
--
-- A target derived from the data being audited is a tautology -- the check would pass by
-- construction and catch nothing. So Balance.TTK, Balance.REFERENCE, Balance.PROBES and
-- Balance.ARMOR_SHARE are authored here and are the only numbers in the file. Everything with an
-- arithmetic result behind it is computed from the live blueprints, because an authored copy of a
-- magnitude is a second source of truth and will drift -- the exact failure models/encounter_battle.lua
-- was extracted to prevent.
--
-- MEASURE THROUGH COMBAT, NEVER BESIDE IT. This module does not reimplement the formula. It builds a
-- real unit, folds its grid with Combat.refreshPassives, and asks Combat.mitigatedDamage. Every number
-- reported therefore comes out of the shipping code, so the report cannot disagree with the game and
-- a change to the formula (the damage floor, say) lands here for free. The one thing that must never
-- appear in this file is a copy of `base - defense - resist`.
--
-- Pure logic (no love.graphics), so it loads under the headless tests. The dependency runs one way,
-- Balance -> Combat: models/combat.lua gains no require from this, and must not.

local Combat = require("models.combat")
local Character = require("models.character")
local Growth = require("models.growth")
local Item = require("models.item")
local Forge = require("models.forge")
local Quest = require("models.quest")

local Balance = {}

-- ---------------------------------------------------------------------------
-- Authored: the target. The only numbers in this file.
-- ---------------------------------------------------------------------------

-- The kit a player who has kept up is assumed to field. Named by BLUEPRINT ID rather than by
-- statline, so the reference reads the real thing and moves when the real thing moves -- a reference
-- loadout written out as numbers would be one more copy to drift.
--
-- The avatar because it is the one body every save has, and the iron sword because docs/weapons.md
-- already names it "the reference weapon the rest of the melee kit is tuned against". This module
-- just makes that sentence executable.
Balance.REFERENCE = {
    charId = "character_avatar",
    weapon = "weapon_iron_sword",
    armor = "armor_leather_armor",
}

-- Hits from ONE reference attacker to fell a body. The design statement, and the thing to argue about
-- when a fight feels wrong -- everything else in the balance system is machinery for enforcing it.
--
-- Keyed by the blueprint's own `tier`, which every one of the 108 bodies already authors and which
-- already means exactly this: 0-1 is chaff (imps, bomblets, summoned props), 2 is the line the avatar
-- itself stands in, 3 is an elite (bandit chief, assassin, battlemage), 4 is a boss (the seven
-- generals and the Demon Lord). Reusing it rather than inventing a second grading is the point --
-- an author who bumps a body's tier has already said what they meant, and there is no way for the
-- two answers to disagree because there is only one.
--
-- Per-quest bands were considered and rejected: they would be 92 more numbers with 92 more chances to
-- drift, and they would let the SAME body be graded differently in two quests, which makes "is this
-- body balanced" a question with no single answer. Four bands is a statement small enough to hold in
-- your head, the same shape as Growth.meetsSurvivabilityFloor being one inequality over every table.
--
-- Snappy on purpose: a line body falls in two to four swings, so a four-strong field is a handful of
-- exchanges rather than an attrition sink, and a mistake costs a body rather than a few percent.
Balance.TTK = {
    chaff = { min = 1, max = 2 },  -- tier 0-1: it is meant to fall to a blow or two
    line = { min = 2, max = 4 },   -- tier 2: the rank the protagonist stands in
    elite = { min = 4, max = 8 },  -- tier 3: a fight's centrepiece
    boss = { min = 6, max = 14 },  -- tier 4: a general, a Lord
}

-- tier -> role. Anything above the table is a boss; a body with no tier at all is line, the
-- commonest grade, so a new blueprint is held to an ordinary bar rather than silently exempted.
--
-- TIER 0 IS ABSENT ON PURPOSE. docs/bestiary.md puts rung 0 off the ladder entirely -- "a prop, an
-- escortee, or a shape worn by Wild Shape" -- and declares it rather than leaving it blank so that
-- "this body does not fight" and "nobody has labelled this body" stay different states. Balance reads
-- that declaration the same way: a tier-0 body has no role and is not judged.
Balance.ROLE_BY_TIER = { [1] = "chaff", [2] = "line", [3] = "elite", [4] = "boss" }

-- The health band each rung claims, and the reason Balance.TTK is keyed by tier at all.
--
-- Authored in tests/bestiary_spec.lua first and moved here so there is ONE owner: the rescale
-- (tools/balance_rescale.lua) has to move health to land a TTK band, and a tool that could not see
-- this contract would cheerfully break it -- as it did, cutting a tier-3 captain to 58 health and
-- straight through the floor of the rung it declares. bestiary_spec now reads these.
--
-- Contiguous by construction, so every health value has exactly one legal rung; the prose bands in
-- docs/bestiary.md left real gaps (nothing covered 31-37, 71-83 or 116-154) and bodies lived in all
-- of them.
Balance.HEALTH_BANDS = {
    [1] = { 1, 30 },          -- chaff: one verb, dies to one blow
    [2] = { 31, 80 },         -- line: a real weapon and one ability; the body a fight is made of
    [3] = { 81, 154 },        -- elite: a signature relic and a rule list that reads
    [4] = { 155, math.huge }, -- boss: a quest's ending
}

-- The tools a body is measured against: one per physical family, plus the magic side.
--
-- Four probes rather than one because a body that walls slash and folds to impact is not "balanced",
-- it is a PUZZLE, and the two have to be distinguishable. A single-probe report would mark the
-- puzzle broken and the genuinely unhittable body merely unlucky.
--
-- A probe is a REAL WEAPON, not a bare tag list, and that distinction is load-bearing. An early
-- version carried only tags, which meant the magic probe measured a spell's tags against the SWORD's
-- power and the wielder's physical Damage -- so every armoured body looked reachable by a spell the
-- reference loadout cannot cast, and the report found nothing wrong with a knight the player was
-- dealing 1 to. Naming the weapon forces each probe to price its own budget honestly: `magical` sends
-- it to magicDamage and magicDefense, and the weapon supplies the power.
--
-- Every one of these is on a gate-0 shelf for under 200 gold (the mace opens one quest in), so each
-- probe is a tool the player can really be holding rather than a hypothetical. Tags are spelled the
-- way the blueprint spells them -- family, damage type, `physical`/`magical`, reach -- because
-- Combat.mitigatedDamage sums resists over EVERY tag on the blow, and a probe that dropped one would
-- under-report armour.
Balance.PROBES = {
    slash = { weapon = "weapon_iron_sword", tags = { "sword", "slash", "physical", "melee" } },
    pierce = { weapon = "weapon_iron_spear", tags = { "spear", "pierce", "physical", "melee" } },
    impact = { weapon = "weapon_iron_mace", tags = { "mace", "impact", "physical", "melee" } },
    magic = { weapon = "weapon_wand", tags = { "wand", "magical", "ranged" }, magical = true },
}

-- Stable probe order, so a report and a spec iterate identically and two runs of either agree.
-- pairs() over PROBES would not.
Balance.PROBE_ORDER = { "slash", "pierce", "impact", "magic" }

-- The melee answer set, and the one the TTK bands are judged against.
--
-- Judging a body by the best of ALL FOUR probes is too generous, and the difference is the whole
-- reported bug: an armoured knight that every sword, spear and mace in the game floors against still
-- passes if a wand can hurt it, so the report finds nothing while the player deals 1. Judging by the
-- reference weapon alone is too strict -- carrying a different blade is the point of a weapon roster.
--
-- Between those, the honest bar is "the best thing a melee company could bring". The starting
-- company IS two melee bodies (the avatar and Rowan), every house's gate-0 shelf is pinned to sell a
-- melee weapon (tests/class_spec.lua), and no companion who casts arrives before slot 2 of a line. A
-- body that needs a wand at prestige 2 is therefore a body the player cannot answer, whatever the
-- magic column says. Magic is still measured -- it is how the report can say "this is walled to
-- steel specifically" rather than just "this is hard".
Balance.PHYSICAL_PROBES = { "slash", "pierce", "impact" }

-- A probe by name, or a bare tag list passed straight through (so a caller with tags in hand -- a
-- real item's -- can use every function here without inventing a probe for it).
function Balance.probe(nameOrTags)
    if type(nameOrTags) == "string" then return Balance.PROBES[nameOrTags] end
    if nameOrTags and nameOrTags.tags then return nameOrTags end
    return { tags = nameOrTags or {} }
end

-- The most one piece of armour may take off one weapon, as a share of the reference attack budget at
-- the prestige that armour's own `unlockQuests` names.
--
-- This is where the resist-stacking problem is enforced, and it is enforced as an AUTHORING rule
-- rather than a code one. Combat.mitigatedDamage sums resists across every tag on the blow, and
-- essentially every physical weapon carries both a family tag and `physical` -- so an armour written
-- as `slash 3, physical 2` ships as -5 against a sword and its author had no way to see that. Rather
-- than change the summing (which would silently redefine what every existing resist number means),
-- the rule is stated on the TOTAL: defense bonus plus summed matching resists, measured per probe,
-- may not exceed this share. An author can still layer resists; they just cannot add up to a wall.
Balance.ARMOR_SHARE = 0.40

-- THE SLOT IS THE GRADE. What a WEAPON or damaging ABILITY contributes is decided by ONE thing: the
-- slot it unlocks from (`unlockQuests`, the count of its house's quests you have finished). Later slot,
-- bigger number. Nothing else earns a discount.
--
-- WHY THE SHARE-BASED RULE WAS REPLACED. The old target was a constant share of the wielder's attack
-- stat, held per family. Two properties made it unable to hold a ladder:
--
--   it could not climb far enough   the attack stat only grows 12 -> 27 across the campaign, so a
--                                   constant share could only ever grow 2.25x. Six families' entire
--                                   slot-0-to-slot-12 range came out NARROWER than one forge ladder
--                                   (staff spanned 4 -> 8 against a forge climb of 10), so a fully
--                                   forged starter cleared the whole family by construction.
--   riders exempted themselves      the floor was waived for any item selling an effect, and an item
--                                   is "plain" only if its effect is one bare fx.damage. Exactly FOUR
--                                   items in the game qualify, all at slot 0. So the floor applied to
--                                   four items and the other 279 were bounded only from above.
--
-- Measured together: 439 of 472 same-family slot pairs had the earlier item, fully forged, beating the
-- later item unforged. Every shelf was a downgrade wearing an effect.
--
-- THE LADDER. A family's target ramps from its base weapon's UNFORGED power at slot 0 to that same
-- base weapon's FULLY FORGED power at the last slot. Two consequences worth stating, because both are
-- deliberate:
--
--   the last slot unforged equals the first slot fully forged. Forging a starter buys you a late-slot
--   NUMBER and never a late-slot EFFECT, which is what keeps the shelf worth walking to.
--   two items at the same slot in the same family get the SAME number. That is the point -- the slot
--   sets the magnitude and the effect is the whole of what distinguishes them.
--
-- Read off the base's own ramp rather than authored fresh, so a family that declares itself heavy
-- stays heavy: weapon_iron_greatsword ramps 24 -> 50 and its ladder inherits that, where the staff's
-- 4 -> 14 inherits the staff's. docs/weapons.md gives each archetype its own power level and this
-- reads that statement rather than overruling it -- a single ladder across all families proposed
-- cutting the greatsword to a dagger's weight and would have deleted the archetype system
-- tests/weapon_spec.lua exists to defend.
--
-- Abilities have no base to read (there is no "iron ability"), so that group keeps a median over its
-- early exemplars for slot 0 and doubles it at the top -- Curve.ramp's own one-argument meaning,
-- "twice as good, fully forged".

-- How far off its slot's target a magnitude may sit. Tight on purpose: with no rider discount there is
-- nothing left for a band to absorb except authoring slack and rounding, and a wide one would let the
-- ladder sag by a whole slot at every rung. The floor is the point -- the ceiling exists so an item
-- cannot leapfrog its own shelf either.
--
-- Stated as a share of the target with a one-point minimum, because the narrow families deal in single
-- digits: 10% of a censer's 4 is nothing at all, and a rule that rounds to zero tolerance would fail an
-- item for being one point off a number it can only hit exactly.
Balance.SLOT_TOLERANCE = { share = 0.15, floor = 1 }

-- Magnitudes that stay small against the ladder, each with the reason. WAIVED, NOT EXEMPT -- the entry
-- is the argument, and an item with no entry is judged.
--
-- The bar is that the item's own blueprint makes the case in prose, and that raising the number would
-- delete what the item IS rather than merely strengthen it. Three qualify. Everything else that reads
-- low reads low because nobody ever checked it, which is exactly what the ladder is for.
--
-- Distinct from the ALLY-TARGETED exclusion below, which is not a waiver at all: those items are not
-- being let off a damage rule, they have no damage to rule on.
Balance.MAGNITUDE_WAIVERS = {
    weapon_long_fall = "docs/weapons.md's mace S4: four tiles of shove and almost no damage. Its own"
        .. " header argues that mace damage on top of the shove 'would simply be the best knight"
        .. " weapon in the game', and the party has to be built to collect -- the number is the price"
        .. " of the displacement, not an oversight.",
    ability_gilded_wound = "the coin IS the blow: it deals no authored damage and bills fx.flatDamage"
        .. " against gold spent at cast time (see the purse kit). Its damage field is 0 because the"
        .. " magnitude lives in the spend, so a ladder target has nothing to attach to.",
    weapon_swineherds_wand = "polymorph removes the body from the fight outright (status_polymorph:"
        .. " it can move and do nothing else). Its header says the damage is 'nearly nothing on"
        .. " purpose' -- a weapon that both removed a body AND hurt it would be two purchases.",
    weapon_long_bout = "a BOUND signature relic (Elio's), so it is not on any ladder to be a rung of:"
        .. " nobody buys it, nobody unlocks it, and its slot reads 0 only because an unpriced item has"
        .. " no gate to derive one from. It is priced as a duelling sword because that is what it is --"
        .. " see docs/weapons.md's sword contract, which it also keeps (trait_parry). The hall's other"
        .. " thirty-seven relics escape this check by not being weapons; this one cannot.",
    ability_self_destruct = "the same 12 trait_bomblet throws, and it has to stay the same 12: the"
        .. " Bomblet promises the damage only ever comes from the burst however the burst is triggered,"
        .. " so a player who learned the number off one they shot is not surprised by one that jumped"
        .. " them. tests/demon_champion_spec.lua pins the two together -- this figure is a cross-item"
        .. " promise rather than a rung on a shelf.",
    ability_bolas = "the throw is the delivery, not the purchase: the Poacher's whole shelf is paid out"
        .. " by the Root it lands (weapon_poachers_kris puts half its swing again through a Rooted body,"
        .. " utility_quarrys_end opens on the snare), so the weight itself is nearly nothing on purpose."
        .. " It is also the only Root that needs no weapon beside it -- a slot-10 blow on top of a"
        .. " weaponless range-3 Root at speed 4 would make it strictly the better Pinning Shot (slot 7,"
        .. " bow-gated, same status), folding the discipline's setup half into its shooting half.",
}

-- (Balance.EARLY_GATES -- "how many gates count as the opening shelf" -- lived here to bound the median
-- the ability group's target used to be read from. Balance.ABILITY_BASE replaced that median and nothing
-- read the constant afterwards, so it is deleted rather than kept: a knob with no callers is exactly how
-- Vendor.tier drifted, and the note on slotAnchors records why the median had to go.)
--
-- (Balance.hasRider went the same way, and it is worth a sentence because it was 100 lines. It answered
-- "does this item sell something other than its number" -- declared rider fields, a reach comparison
-- against the family base, and a structural scan of the blueprint's own source for anything that was not
-- a single bare fx.damage. Its only purpose was to WAIVE the magnitude floor for such items, and under
-- the slot ladder nothing is waived for having an effect: the slot sets the number and the effect is what
-- distinguishes two items that share one. Deliberate outliers are named in Balance.MAGNITUDE_WAIVERS with
-- their reasons instead, which is three entries rather than a heuristic that exempted 279 of 283 items.)

-- THE BASE ABILITY: what the ability group's ladder is read off, exactly as each weapon family reads
-- Balance.FAMILY_BASE. There is no "iron ability", so one has to be named, and the same three things
-- qualify it that qualify a family base: it sits at slot 0, it is on a shelf for real money, and its
-- damage is the whole of what it does -- a Fire Bolt is the plainest damaging spell the Arcanum sells.
--
-- Named rather than derived because a level read off the group is a level that moves when the group
-- does; Balance.slotAnchors carries the full account of the run where that failed.
Balance.ABILITY_BASE = "ability_fire_bolt"

-- THE BASE WEAPON OF EACH FAMILY -- the item whose power level the rest of that family is held to.
--
-- These are docs/weapons.md's own S1 rows, the entries that document calls "the base": the iron kit,
-- plus the three caster families whose base carries no metal in its name. Reading the level off the
-- BASE rather than off a median is the correction that made this rule usable at all. A median needs a
-- sample, eight of the thirteen families have one or two priced early exemplars, and a level read off
-- two items is simply one of the two items -- with an even count it took the lower, so a family's
-- level became its weaker member and the solver proposed halving weapon_iron_greatsword, the heaviest
-- hit in the game by that same document's design.
--
-- A base is a deliberate authored statement of what an archetype costs and returns; a median is an
-- accident of how many of them happen to be cheap. tests/balance_spec.lua checks each one still
-- exists, is priced, and really belongs to the family it is named for.
Balance.FAMILY_BASE = {
    sword = "weapon_iron_sword",
    greatsword = "weapon_iron_greatsword",
    axe = "weapon_iron_axe",
    spear = "weapon_iron_spear",
    mace = "weapon_iron_mace",
    hammer = "weapon_iron_hammer",
    dagger = "weapon_iron_dagger",
    bow = "weapon_iron_bow",
    longbow = "weapon_iron_longbow",
    wand = "weapon_wand",
    staff = "weapon_staff",
    censer = "weapon_censer",
}

-- ---------------------------------------------------------------------------
-- Derived: the player's side
-- ---------------------------------------------------------------------------

-- A throwaway player at global prestige P having finished `sponsorDone` of `vendorId`'s quests.
-- Deliberately the same three fields tools/progression_report.lua's newPlayer() keeps: those are all
-- Forge.ceilingFor and Vendor.stock actually read, and a fuller fake would imply the rest was
-- meaningful. `completedQuests` is filled with synthetic ids because Quest.sponsorProgress counts
-- entries whose blueprint names the sponsor -- so real quest ids of that house are what it needs.
function Balance.playerAt(prestige, vendorId, sponsorDone)
    local player = { prestige = prestige or 1, completedQuests = {}, roster = {} }
    if vendorId and (sponsorDone or 0) > 0 then
        local n = 0
        -- Sorted, so the same (vendor, count) always names the same quests and two runs agree.
        local ids = {}
        for id, def in pairs(Quest.defs) do
            if def.sponsor == vendorId then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if n >= sponsorDone then break end
            player.completedQuests[id] = true
            n = n + 1
        end
    end
    return player
end

-- The forge level a reference player may take `item` to. Accepts a blueprint id or an item table.
-- DELEGATES to Forge.ceilingFor rather than mirroring its rules, so a change to the ceiling (and
-- there is one -- it used to read the retired Vendor.tier wave enum) lands here without this file
-- being touched.
function Balance.forgeCeiling(item, prestige, sponsorDone)
    if type(item) == "string" then item = Item.defs[item] end
    if not item then return 0 end
    local class = Item.classOf(item)
    local vendorId = class and Forge.houseVendorFor(class) or nil
    local player = Balance.playerAt(prestige, vendorId, sponsorDone or prestige)
    return Forge.ceilingFor(player, item)
end

-- The forge level the bands are measured at: ZERO. Gear as bought, straight off the shelf.
--
-- THE RULE THIS ENCODES: a piece of gear is balanced for the content it unlocks into, unforged.
-- Something the shelf opens after slot 1 must carry slot 2 on its own; forging is HEADROOM, the thing
-- that puts the player ahead of the curve, not the toll that gets them level with it.
--
-- The first version of this measured at the forge CEILING, on the reasoning that the reference should
-- be "a player who has kept up". That quietly made the bench mandatory: a body could sit inside its
-- band on paper while anyone who had not visited the Forge faced a wall, and the verification run
-- caught it -- an unforged avatar took 8 swings to fell a Grey Knight the band had passed at 5.
-- Baking the bench into the yardstick also hides the question of whether the materials for it are
-- even earnable (see the report's FORGE ECONOMY section), because the budget assumes the answer.
--
-- Forging is still measured, just not assumed: Balance.forgeCeiling reports the reachable rung and
-- tools/balance_report.lua prints it beside the budget, so the headroom is visible as headroom.
Balance.FORGE_BASELINE = 0

-- The pre-mitigation power the reference loadout throws at prestige P: the wielder's attack stat plus
-- the weapon's power AS BOUGHT (Balance.FORGE_BASELINE), not as forged.
--
-- Returns `budget, parts`, where parts is shaped like Combat.damageBreakdown's rows
-- ({ label, value }) so the report's arithmetic and the in-game hover receipt read identically -- a
-- designer comparing the two should not have to translate.
--
-- `opts.probe` (a probe name or table) is the usual way in: it supplies both the weapon and which
-- side of the stat sheet to read, so a magic probe is priced with magicDamage and a wand rather than
-- being handed the sword's power. Explicit `weapon`/`magical` override it.
--
-- opts: { probe, weapon, charId, forgeLevel, sponsorDone, magical }
function Balance.attackBudget(prestige, opts)
    opts = opts or {}
    local probe = opts.probe and Balance.probe(opts.probe) or nil
    local charId = opts.charId or Balance.REFERENCE.charId
    local weaponId = opts.weapon or (probe and probe.weapon) or Balance.REFERENCE.weapon
    local magical = opts.magical
    if magical == nil then magical = (probe and probe.magical) or false end

    local level = Growth.levelForPrestige(prestige)
    local char
    if charId == Balance.REFERENCE.charId then
        -- Grown into what it swings, and memoized, via the one owner of that rule.
        char = Balance.refChar(prestige, Balance.growthClassFor(probe or { weapon = weaponId }))
    else
        char = Character.instantiate(charId)
        Growth.resolve(char, level)
    end

    local forgeLevel = opts.forgeLevel or Balance.FORGE_BASELINE
    local weapon = Item.instantiate(weaponId, 1, forgeLevel)

    local statName = magical and "magicDamage" or "damage"
    local stat = char.stats[statName] or 0
    local power = (weapon and weapon.activeAbility and weapon.activeAbility.damage) or 0

    local parts = {
        { label = (weapon and weapon.name) or weaponId, value = power },
        { label = magical and "Magic damage" or "Damage", value = stat },
    }
    return stat + power, parts
end

-- The deepest weapon of `family` a player at prestige P could actually have bought, or nil if that
-- family sells nothing they can reach yet.
--
-- WHY THIS EXISTS, and it is the gap the slot ladder opened. Every number on the player's side of this
-- module is priced through Balance.REFERENCE -- the avatar with an iron sword -- and that is the right
-- yardstick for grading BODIES, because a fixed yardstick is the only kind that can catch a body drifting.
-- But it is a slot-0 weapon, and the ladder just raised 141 magnitudes above it. So `Balance.TTK` passing
-- means "a body is fair against the opening shelf" and says NOTHING about a player carrying the shelf they
-- have actually earned -- which, at the deep end, now hits several times harder than the reference does.
--
-- That is a real question and it needed a real instrument rather than an assumption in either direction.
-- Read the deepest reachable weapon rather than a hand-named "late reference" for the usual reason: a
-- second authored loadout would be one more thing to drift, and this one moves the day the shelf does.
--
-- `unlockQuests <= prestige` is the gate, since prestige is a flat count of quests finished
-- (Quest.PRESTIGE_PER_QUEST) and a shelf gate counts the sponsoring house's. That conflates "eleven quests
-- anywhere" with "eleven of this house's", which is generous -- it assumes a player who committed to one
-- line. Generous is the correct direction here: this is measuring the CEILING of what a player could be
-- swinging, and a floor would answer a question nobody asked.
function Balance.progressedWeapon(prestige, family)
    local best, bestSlot = nil, -1
    for id, def in pairs(Item.defs) do
        if def.price and def.type == "weapon" and Balance.familyOf(def) == family then
            local slot = def.unlockQuests or 0
            if slot <= (prestige or 1) and slot > bestSlot and Balance.gradesOnMagnitude(def) then
                best, bestSlot = id, slot
            end
        end
    end
    return best, bestSlot
end

-- The exchange as a player who has KEPT UP would really fight it: the same body, measured against the
-- deepest weapon of the probe's family they could be holding at that standing.
--
-- Returns nil when the family sells nothing deeper than the probe's own base, in which case the ordinary
-- Balance.exchange already answered the question and a second identical row would just be noise.
function Balance.progressedExchange(prestige, charOrId, probeName, opts)
    local probe = Balance.probe(probeName or "slash")
    local weaponId = Balance.progressedWeapon(prestige, Balance.familyOf(probe.weapon))
    if not weaponId or weaponId == probe.weapon then return nil end

    -- The probe's TAGS, not the progressed weapon's: what is being varied is the weapon's POWER, and
    -- swapping the tag list too would change which resists apply and make the two rows incomparable.
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.budget = (Balance.attackBudget(prestige, { probe = probe, weapon = weaponId,
        sponsorDone = o.sponsorDone, forgeLevel = o.forgeLevel }))
    local ex = Balance.exchange(prestige, charOrId, probe, o)
    ex.weapon = weaponId
    return ex
end

-- ---------------------------------------------------------------------------
-- Derived: the body's side
-- ---------------------------------------------------------------------------

-- A body ready to be measured: a character instance grown to `level`, its grid folded onto a unit
-- the way Combat does it at setup. Not a full combat unit -- it has no board position and never takes
-- a turn -- but it carries exactly the two fields (unit.bonus, unit.resist) that mitigation reads.
function Balance.unitFor(charOrId, level)
    local char = charOrId
    if type(charOrId) == "string" then
        char = Growth.spawn(charOrId, level or 1)
    end
    local unit = { char = char }
    Combat.refreshPassives(unit)
    return unit
end

-- A body that is off the ladder: docs/bestiary.md's rung 0, "a prop, an escortee, or a shape worn by
-- Wild Shape". The transform shapes (character_dire_bear, character_pig) author `health = 1` with a
-- comment saying nothing reads it, because models/transform.lua carries the original's pools across.
--
-- Reads the DECLARED tier rather than sniffing the health, because the bestiary already made that
-- declaration explicit for exactly this reason -- "this body does not fight" and "nobody has labelled
-- this body" are different states, and a heuristic cannot tell them apart. The health check survives
-- only as a backstop for a blueprint that has not been labelled yet.
--
-- They are excluded from every balance judgement -- a 1-health body reads as instantly killable and
-- would drag any rescale toward nonsense -- but NOT quietly. Several are also named directly in quest
-- compositions, which means those fights really do spawn a one-health bear. That is a content bug
-- this module can detect and must not hide: see tools/balance_report.lua's PLACEHOLDER section.
function Balance.isPlaceholder(charOrId)
    local def = charOrId
    if type(charOrId) == "string" then def = Character.defs[charOrId] end
    if not def then return false end
    if def.tier == 0 then return true end
    local hp = (def.stats or {}).health
    if type(hp) == "table" then hp = hp.max end
    return (hp or 0) <= 1
end

-- Bodies whose numbers are LOAD-BEARING SOMEWHERE ELSE, and which no automated pass may touch.
--
-- Distinct from a spec waiver, which only says "do not judge this". This says "do not TOUCH this",
-- and it has to live here rather than in tests/balance_spec.lua because tools/balance_rescale.lua
-- cannot require a spec -- which is exactly how the demon grunt got quietly retuned: the spec waived
-- it, the rescale never saw the waiver, its defense went 4 -> 1, and two prologue tests failed
-- because the tutorial's authored script depends on the grunt surviving an exact number of blows.
--
-- The bar for an entry is that some OTHER file would break, or some other lesson stop being true.
Balance.FROZEN = {
    -- data/tutorials/village.lua quotes this body's arithmetic line by line -- the parry beat is built
    -- on the grunt landing a specific blow and surviving a specific answer. It also declares
    -- `scaling = false`, so it is blueprint-exact wherever it appears and there is nowhere for a
    -- rescale to hide.
    character_demon_grunt = "prologue: the parry lesson is written against these exact numbers",
}

function Balance.isFrozen(id) return Balance.FROZEN[id] ~= nil end

-- Is this body one the player ends up OWNING -- the avatar, a starting companion, or anyone a quest
-- grants through `rewardCharacter`?
--
-- These are tuned as PLAYER units and must never be retuned as enemies, even though several are
-- fought once before they join (Rowan at the Cathedral's slot 5, Amana at its slot 2, Saber at the
-- Colosseum's first bout). Balancing Rowan's defense down because she is briefly an opponent would
-- weaken the knight the player fights the rest of the campaign with -- the same blueprint is both.
--
-- Derived from the campaign rather than listed, so a new companion is covered the day its quest names
-- it. Memoized; the roster does not change at runtime.
local companionCache
function Balance.isCompanion(id)
    if not companionCache then
        companionCache = { [Balance.REFERENCE.charId] = true }
        for _, cid in ipairs(require("data.player").startingRoster or {}) do
            companionCache[cid] = true
        end
        for _, def in pairs(Quest.defs) do
            if def.rewardCharacter then companionCache[def.rewardCharacter] = true end
        end
    end
    return companionCache[id] == true
end

-- A body that is not meant to trade blows, and whose blueprint says so itself.
--
-- Two self-declaring signals, no list:
--   no offensive statline at all   `damage = 0, magicDamage = 0` IS the statement "this does not
--                                  attack" -- the straw sentry and the gaunt vigil are standing
--                                  objects that never strike, and that is their entire design.
--   archetype = "support"          the AI posture for a body whose job is not damage. Amana's
--                                  blueprint annotates her damage stat "feeble on purpose: she does
--                                  not kill".
--
-- This matters because the mirror rule -- every body must be able to hurt the player back -- assumes
-- every body is an attacker, and this game has walls, objects and support units whose low damage is
-- authored intent stated in prose. Holding those to a damage floor would arm a scarecrow.
--
-- It does NOT cover the summoned constructs (the Golem, the Homunculus, the sentries), which carry
-- real weapons and a real posture and are simply tuned low on purpose. Those are named waivers in
-- tests/balance_spec.lua, because "this one is deliberately feeble" is a claim that deserves a
-- sentence rather than a rule.
function Balance.isNonCombatant(charOrId)
    local def = charOrId
    if type(charOrId) == "string" then def = Character.defs[charOrId] end
    if not def then return false end
    if def.archetype == "support" then return true end
    local s = def.stats or {}
    return (s.damage or 0) <= 0 and (s.magicDamage or 0) <= 0
end

-- The maximum health of a body, resource stats being stored as { max, current } after instantiation.
function Balance.healthOf(char)
    local hp = char and char.stats and char.stats.health
    if type(hp) == "table" then return hp.max or 0 end
    return hp or 0
end

-- A probe base big enough that nothing in the game can floor it, so mitigation is measured as a
-- DIFFERENCE rather than read off the blueprint. Anything above the largest conceivable wall works;
-- this is deliberately absurd so no future armour quietly clips it.
local PROBE_BASE = 100000

-- What a grown, equipped body subtracts from a blow carrying `tags`.
--
-- Measured, not copied: hand Combat.mitigatedDamage a base too large to floor and take the shortfall.
-- That means this reports whatever the shipping formula actually does -- including any future term
-- nobody thought to mirror here -- rather than what this file believes it does.
--
-- The itemised fields (defense/equipment/resist) ARE read off the unit, because a total alone cannot
-- tell an author which number to change. They are reported for attribution only; `total` is the one
-- the arithmetic uses, and it is the measured one.
function Balance.mitigation(charOrUnit, tags)
    local unit = charOrUnit
    if not unit.bonus then unit = Balance.unitFor(charOrUnit) end
    tags = tags or {}

    local landed = Combat.mitigatedDamage(unit, PROBE_BASE, tags)
    local total = PROBE_BASE - landed

    local magical = false
    for _, t in ipairs(tags) do
        if t == "magical" then magical = true end
    end
    local statName = magical and "magicDefense" or "defense"
    local base = (unit.char and unit.char.stats and unit.char.stats[statName]) or 0
    local equipment = (unit.bonus and unit.bonus[statName]) or 0

    local resist, byTag = 0, {}
    for _, t in ipairs(tags) do
        local r = (unit.resist and unit.resist[t]) or 0
        if r ~= 0 then
            byTag[t] = r
            resist = resist + r
        end
    end

    return {
        total = total,
        defense = base,
        equipment = equipment,
        resist = resist,
        byTag = byTag,
    }
end

-- ---------------------------------------------------------------------------
-- The exchange
-- ---------------------------------------------------------------------------

-- Hits to fell `charOrUnit` with a `budget`-power blow carrying `tags`, in ONE direction.
--
-- `perHit` is Combat.mitigatedDamage's own answer -- the number the player would see in the log --
-- and `floored` says whether mitigation drove the blow to the minimum, which is the difference
-- between "this armour is working" and "you cannot hurt this".
function Balance.ttk(budget, charOrUnit, tags)
    local unit = charOrUnit
    if not unit.bonus then unit = Balance.unitFor(charOrUnit) end

    local mit = Balance.mitigation(unit, tags)
    local perHit = Combat.mitigatedDamage(unit, budget, tags)
    local hp = Balance.healthOf(unit.char)

    return {
        budget = budget,
        perHit = perHit,
        hp = hp,
        hits = perHit > 0 and math.ceil(hp / perHit) or math.huge,
        -- The pre-floor result: what the arithmetic wanted before the minimum caught it.
        floored = (budget - mit.total) < perHit,
        mitigation = mit.total,
        mit = mit,
    }
end

-- The blow a BODY throws: the power of the hardest-hitting weapon on its grid, plus whichever attack
-- stat that weapon's tags route to. Mirrors Balance.attackBudget for a unit the player did not build,
-- so both sides of an exchange are priced the same way.
--
-- Returns `budget, tags, weapon`. The TAGS matter as much as the number: the return blow has to be
-- measured with the weapon the body actually swings, not with whatever probe the outgoing direction
-- happened to use. Measuring a ghost's spell against physical armour reported a whole column of
-- casters as harmless when they were nothing of the kind.
--
-- A body with an empty grid falls back to its unarmed weapon -- the hidden fist every character
-- carries (Character.DEFAULT_UNARMED) -- because that is genuinely what it swings, and scoring it at
-- zero would report an unarmed brawler as no threat.
function Balance.bodyBudget(charOrUnit)
    local unit = charOrUnit
    if not unit.bonus then unit = Balance.unitFor(charOrUnit) end

    local items = Character.eachItem(unit.char)
    if unit.char.unarmed then items[#items + 1] = unit.char.unarmed end

    local power, weapon = 0, nil
    for _, item in ipairs(items) do
        local ab = item.activeAbility
        local d = ab and ab.damage
        if type(d) == "number" and d > power then
            power, weapon = d, item
        end
    end

    local tags = (weapon and weapon.tags) or {}
    local magical = false
    for _, t in ipairs(tags) do
        if t == "magical" then magical = true end
    end

    local statName = magical and "magicDamage" or "damage"
    local stat = (unit.char.stats[statName] or 0) + ((unit.bonus and unit.bonus[statName]) or 0)
    return stat + power, tags, weapon
end

-- BOTH directions of a matchup, because a body the player cannot hurt and a body that cannot hurt the
-- player back are the same authoring failure wearing opposite signs -- and a report that only looked
-- one way would fix the first by creating the second.
--
-- `outclasses` is the raw three-axis comparison: this body beats the reference loadout on attack AND
-- on mitigation AND on health. Whether that is a DEFECT depends on the body's rank, so the judgement
-- itself lives in Balance.measure, which knows the role -- an elite or a boss is supposed to outclass
-- you, and flagging that would be flagging the entire idea of an elite. What must never happen is a
-- body of the protagonist's OWN rank being strictly better than the protagonist. That is the shape of
-- the Grey Knight at prestige 2 -- a tier-2 line body with more attack, more armour and equal health
-- -- and it is why the campaign's second line opened with the player dealing 1.
function Balance.exchange(prestige, charOrId, probeOrTags, opts)
    opts = opts or {}
    local probe = Balance.probe(probeOrTags or "slash")
    local tags = probe.tags

    local level = opts.level or Growth.levelForPrestige(prestige)
    local unit = Balance.unitFor(charOrId, level)
    -- The same reference the budget was priced from, grown the same way -- a caster measured with a
    -- fighter-grown body's armour would be comparing two different people.
    local refUnit = Balance.unitFor(Balance.refChar(prestige, Balance.growthClassFor(probe)), level)

    local budget = opts.budget
    if not budget then
        local o = { probe = probe, sponsorDone = opts.sponsorDone, forgeLevel = opts.forgeLevel }
        budget = (Balance.attackBudget(prestige, o))
    end

    local out = Balance.ttk(budget, unit, tags)

    -- Coming back: the body's own blow, carrying ITS weapon's tags rather than the probe's. What
    -- comes back at the player is whatever that body actually holds, and pricing it against the
    -- outgoing probe's tags mis-sorts every caster on the roster.
    local backBudget, backTags = Balance.bodyBudget(unit)
    local back = Balance.ttk(backBudget, refUnit, backTags)

    -- The reference is compared on the SAME probe the body was measured with, so "more armour than
    -- the protagonist" means more against the same blow rather than across two different ones.
    local refMit = Balance.mitigation(refUnit, tags).total
    local refHp = Balance.healthOf(refUnit.char)

    return {
        out = out,
        back = back,
        probe = probe,
        backTags = backTags,
        outclasses = backBudget >= budget and out.mitigation >= refMit and out.hp >= refHp,
        reference = { budget = budget, mitigation = refMit, hp = refHp },
    }
end

-- The reference character as a grown instance, carrying its authored starting grid, GROWN INTO THE
-- THING IT SWINGS.
--
-- `growthClass` seeds the technique ledger so the level-ups credit that class's table, which is
-- exactly what the game does to a real player: growth is apportioned across whatever they have been
-- casting (Character.recordTechnique), and models/growth.lua's whole thesis is "a knight you keep
-- casting Fireball with grows into a battlemage".
--
-- Without it the reference is grown under Growth.NEUTRAL_CLASS -- fighter, whose table has no magic
-- side at all -- so its magicDamage sits at its level-1 value forever while every enemy's
-- magicDefense climbs. The magic probe then reported that the Arcanum's own Fireball could not hurt a
-- mage, which is not a fact about the Arcanum's shelf but about a yardstick that had never cast
-- anything. A caster reference must have cast.
--
-- Memoized per (level, class): the walk asks for this once per body per probe, and instantiating a
-- character 108 x 4 times is not free.
local refCache = {}
function Balance.refChar(prestige, growthClass)
    local level = Growth.levelForPrestige(prestige)
    local key = level .. "/" .. tostring(growthClass)
    if refCache[key] then return refCache[key] end

    local char = Character.instantiate(Balance.REFERENCE.charId)
    if growthClass and Growth.defs[growthClass] then
        -- Any positive amount under one key is a 100% share -- Growth.shares normalizes -- so this
        -- says "everything this body did, it did as a <class>" without inventing a rate.
        char.technique = { [growthClass] = 1 }
    end
    Growth.resolve(char, level)
    refCache[key] = char
    return char
end

-- The growth class the reference is grown under for a given probe.
--
-- NOT the probe weapon's own class, which was the first attempt and is too strong a claim. A sword is
-- knight stock, and the knight table is `health 6, defense 2, damage 1` -- so growing the reference
-- 100% knight gives it +1 attack a level, and every armoured body in the back half of the campaign
-- reads unhittable. That is a real property of a player who commits ENTIRELY to one house, and it may
-- be worth looking at on its own, but it is not the yardstick: growth here is apportioned across
-- everything a character casts, and nobody casts one thing.
--
-- So the physical probes take the neutral default -- what Growth.resolve gives an avatar with no cast
-- history, which is the honest "unspecialized player" this is measuring for. The magic probe cannot:
-- the neutral table (fighter) has no magic side AT ALL, so magicDamage would sit at its level-1 value
-- forever while every enemy's magicDefense climbed, and the report would claim the Arcanum's own
-- Fireball could not hurt a mage. A caster reference has to have cast something.
function Balance.growthClassFor(probe)
    return (probe and probe.magical) and "mage" or nil
end

-- (Balance.reset lives at the FOOT of this file, not here. Every cache it drops is declared further
-- down, and a function written above those declarations closes over the GLOBALS of the same name
-- instead -- so the version that used to sit here silently cleared nothing but refCache. The one
-- caller is tools/balance_rescale.lua, which rewrites blueprints between walks and would otherwise
-- solve pass 2 against pass 1's stale numbers.)

-- ---------------------------------------------------------------------------
-- Roles and verdicts
-- ---------------------------------------------------------------------------

-- What band a body is held to: its blueprint's own `tier`, and nothing else.
--
-- Deliberately NOT influenced by how a given quest uses the body. An earlier draft promoted a quest's
-- assassination mark to boss, which meant the same blueprint was graded elite in one fight and boss
-- in another -- so "is this body balanced" had two answers and the sweep's dedup had to pick one
-- arbitrarily. A quest that wants a harder mark should field a harder body.
--
-- (Growth's `floorLevel` was the first candidate for this signal and is not usable: it reads as "a
-- named thing" but no character blueprint in the game authors it, so every body would have graded
-- line and the bands would have caught nothing.)
-- Returns nil for a tier-0 body, which docs/bestiary.md places off the ladder altogether.
function Balance.roleFor(id)
    local def = Character.defs[id]
    local tier = def and def.tier
    if not tier then return "line" end
    if tier == 0 then return nil end
    return Balance.ROLE_BY_TIER[tier] or "boss"
end

-- Does this body being strictly better than the reference loadout count as a defect?
--
-- Only for bodies of the player's OWN rank and below. A tier-3 elite or a tier-4 general with more
-- attack, more armour and more health than one avatar is not a bug, it is the definition of an elite
-- -- what holds those in check is the TTK band, not this. Applying the test to them produced absurd
-- corrections (a Champion's greatsword damage driven to 0 for out-hitting an iron sword), which is
-- how the rank condition was found.
function Balance.dominates(ex, role)
    if not ex.outclasses then return false end
    return role == "line" or role == "chaff"
end

-- Whether an exchange landed where its role says it should, and if not, which way it missed.
--
-- Order matters: dominance outranks everything, because a dominating body is not a TTK problem and
-- reporting it as "too slow" would send an author to tune the wrong number.
function Balance.verdict(ex, role)
    local band = Balance.TTK[role or "line"] or Balance.TTK.line
    if Balance.dominates(ex, role) then return "dominates" end
    if ex.out.floored then return "floors" end
    if ex.back.floored then return "harmless" end
    if ex.out.hits > band.max then return "too slow" end
    if ex.out.hits < band.min then return "too fast" end
    return "ok"
end

-- ---------------------------------------------------------------------------
-- What a quest actually fields
-- ---------------------------------------------------------------------------

-- Every quest that must be finished before `questId` can be taken -- the TRANSITIVE closure of
-- `requiredQuests`, as a set. Memoized, and cycle-safe.
local prereqCache = {}
local function prereqsOf(questId, seen)
    if prereqCache[questId] then return prereqCache[questId] end
    seen = seen or {}
    if seen[questId] then return {} end
    seen[questId] = true

    local out = {}
    local def = Quest.defs[questId]
    for _, req in ipairs((def and def.requiredQuests) or {}) do
        if Quest.defs[req] and not out[req] then
            out[req] = true
            for id in pairs(prereqsOf(req, seen)) do out[id] = true end
        end
    end
    seen[questId] = nil
    prereqCache[questId] = out
    return out
end

-- The standing a player actually has when they reach `questId`, as a prestige number.
--
-- NOT `requiredPrestige`, which is only the gate onto a LINE -- every quest of the Bastion's ten
-- carries the same 2. Read literally it measures a slot-10 general at the standing of the tutorial and
-- reports it as an impossible wall, and it puts a capstone that costs a CROSSING of two lines at
-- prestige 2 as well. Three sources, and the deepest wins:
--
--   requiredPrestige         the line's own entry gate.
--   the prerequisite count   prestige is a flat count of quests finished (Quest.PRESTIGE_PER_QUEST),
--                            so a quest with eleven quests transitively behind it cannot be reached
--                            below prestige twelve. This is what catches the crossings, which is
--                            where the worst measurement errors were.
--   Quest.floorLevelFor      the SLOT_FLOOR ladder guarantees slot 10 is fought at level 13 whoever
--                            walks in. Inverting Growth.levelForPrestige turns that back into a
--                            standing (level = 1 + floor((p-1)/2), so p = 2L-1).
function Balance.prestigeFor(questId)
    local def = Quest.defs[questId]
    if not def then return 1 end

    local base = def.requiredPrestige or 1

    local n = 0
    for _ in pairs(prereqsOf(questId)) do n = n + 1 end
    base = math.max(base, n + 1)

    local floorLevel = Quest.floorLevelFor(def, questId)
    if floorLevel then
        base = math.max(base, (floorLevel * Growth.PRESTIGE_PER_LEVEL) - 1)
    end
    return base
end

-- How many of the sponsoring house's quests a player has run on arriving here -- what the forge
-- ceiling and the shelf both key off, and deliberately NOT global prestige (a player who spreads has
-- high prestige and shallow standing everywhere).
--
-- Counted from the same prerequisite closure, so a crossing capstone is credited only with the quests
-- of its OWN house that it actually required. A numbered slot answers itself and wins when higher:
-- reaching slot 7 means seven of that house's quests, whatever the closure says.
function Balance.sponsorDoneFor(questId)
    local def = Quest.defs[questId]
    if not def then return 0 end

    local done = 0
    for id in pairs(prereqsOf(questId)) do
        local d = Quest.defs[id]
        if d and d.sponsor == def.sponsor then done = done + 1 end
    end

    local slot = tonumber(tostring(questId or ""):match("_slot_(%d+)$") or "")
    if slot then done = math.max(done, slot - 1) end

    -- `requiredSponsorQuests` is { vendor = id, count = n } (models/quest.lua's meetsSponsorQuestGate),
    -- and only counts toward THIS number when the house it names is this quest's own sponsor -- a gate
    -- on someone else's line says nothing about standing here.
    local gate = def.requiredSponsorQuests
    if gate and gate.vendor == def.sponsor then done = math.max(done, gate.count or 0) end
    return done
end

-- Every enemy body a quest can put on a board, grown to the level that quest puts it at.
--
-- A composition is a CLOSURE reading ctx.prestige (see data/quests/bastion/quest_bastion_slot_01.lua),
-- so this invokes it with a real ctx rather than trying to read a list that is not there. Both the
-- objective and the guaranteed trail encounters are walked; the weighted random pool is not, because
-- what it contributes is a roll rather than a property of the quest.
--
-- Returns { { id, role, source } } -- deduplicated by id, keeping the strongest role, since a body
-- that appears twice is one authoring decision and should be reported once.
function Balance.bodiesFor(questId, opts)
    opts = opts or {}
    local def = Quest.defs[questId]
    if not def then return {} end

    local prestige = opts.prestige or Balance.prestigeFor(questId)
    local ctx = { prestige = prestige, quest = questId }

    local seen, out = {}, {}

    local function add(id, source)
        if not Character.defs[id] then return end
        if seen[id] then return end
        local row = { id = id, role = Balance.roleFor(id), source = source }
        seen[id] = row
        out[#out + 1] = row
    end

    local function walkComposition(comp, source)
        if type(comp) == "function" then
            local ok, list = pcall(comp, ctx)
            if not ok or type(list) ~= "table" then return end
            comp = list
        end
        if type(comp) ~= "table" then return end
        for _, id in ipairs(comp) do
            if type(id) == "string" then add(id, source) end
        end
    end

    local map = def.map or {}
    local obj = map.objective
    if obj then walkComposition(obj.composition, "objective") end

    local Encounter = require("models.encounter")
    for _, encId in ipairs((map.encounters and map.encounters.always) or {}) do
        local encDef = Encounter.get(encId)
        if encDef then walkComposition(encDef.composition, encId) end
    end

    return out
end

-- One body, fully measured: every probe, which one answers it best, and the verdict.
--
-- THE single entry point for "how does this body read", so tools/balance_report.lua and
-- tests/balance_spec.lua cannot drift into judging the same body two different ways -- which is
-- exactly how a report ends up green while the game is not.
--
--   probes    every probe by name
--   best      the best of all four, diagnostic only
--   physical  the best MELEE probe -- the one the bands judge (see PHYSICAL_PROBES)
--   ex        an alias for `physical`, the exchange the verdict was taken from
--   magicOnly steel floors but a spell does not: walled to a damage type, not simply tough
function Balance.measure(prestige, id, role, opts)
    local probes, best, physical = {}, nil, nil
    for _, name in ipairs(Balance.PROBE_ORDER) do
        local ex = Balance.exchange(prestige, id, name, opts)
        probes[name] = ex
        if not best or ex.out.perHit > probes[best].out.perHit then best = name end
    end
    for _, name in ipairs(Balance.PHYSICAL_PROBES) do
        if not physical or probes[name].out.perHit > probes[physical].out.perHit then
            physical = name
        end
    end

    role = role or Balance.roleFor(id)
    return {
        id = id,
        role = role,
        prestige = prestige,
        sponsorDone = opts and opts.sponsorDone,
        probes = probes,
        best = best,
        physical = physical,
        ex = probes[physical],
        magicOnly = probes[physical].out.floored and not probes.magic.out.floored,
        dominates = Balance.dominates(probes[physical], role),
        verdict = Balance.verdict(probes[physical], role),
    }
end

-- item id -> the earliest standing at which it is actually FACED, by any body that carries it.
--
-- An item's shelf gate says when the PLAYER may buy it, and that is not when they first meet it.
-- armor_oathkeeper_shield is gated at quest 11 and costs 800 gold -- endgame plate -- and
-- character_forsworn_captain wears it into a fight reached at prestige 2. Judging it against a
-- prestige-11 budget declared it fine, which is how a captain ended up carrying 24 points of
-- mitigation in front of a company that could muster 30.
--
-- Memoized: the walk is over every quest's whole cast and both the report and the guard want it.
local facedCache
function Balance.facedAt()
    if facedCache then return facedCache end
    local earliest = {}
    for _, questId in ipairs(Balance.questOrder()) do
        local prestige = Balance.prestigeFor(questId)
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            local def = Character.defs[body.id]
            for _, entry in ipairs((def and def.startingItems) or {}) do
                local itemId = type(entry) == "table" and entry.id or entry
                if type(itemId) == "string" then
                    if not earliest[itemId] or prestige < earliest[itemId] then
                        earliest[itemId] = prestige
                    end
                end
            end
        end
    end
    facedCache = earliest
    return earliest
end

-- THE STANDING A SLOT IS BOUGHT AT, which is not the slot number and stopped being able to pretend it
-- was the day the shelves were re-cut.
--
-- A slot used to be one finished quest, so "slot 7" and "prestige 7" were the same statement and every
-- reference body in this file was grown by passing the gate straight in. Then the shelves went from
-- twelve rungs to six or eight (models/errand.lua's ladder, one rung per job a house asks for) -- and
-- the same reading turned the TOP of a shelf into a company seven quests old. Every magnitude in the
-- game is measured against the body that would swing it, so the whole ladder quietly dropped about a
-- third: `balance-rescale` proposed cutting 108 items and was right to, given what it had been told.
--
-- So the slot is read as a POSITION ON ITS LADDER and mapped onto the standing a company really has by
-- the time it is buying there. The span is what the old twelve-rung shelf implied end to end, kept as a
-- constant rather than re-derived, because it describes the CAMPAIGN -- how much a company grows over a
-- full run -- and not the shelf, which is now free to be cut into as many rungs as the work supports.
Balance.PRESTIGE_SPAN = 12

function Balance.prestigeForSlot(slot)
    local top = Balance.maxSlot()
    if top <= 0 then return 1 end
    local f = math.min(1, math.max(0, (slot or 0) / top))
    return math.max(1, math.floor(1 + f * (Balance.PRESTIGE_SPAN - 1) + 0.5))
end

-- The standing an ITEM should be judged at: the earlier of its shelf gate and when it is first faced.
function Balance.itemPrestige(id, def)
    def = def or Item.defs[id]
    local prestige = Balance.prestigeForSlot(def and def.unlockQuests)
    local faced = Balance.facedAt()[id]
    if faced and faced < prestige then prestige = faced end
    return prestige
end

-- The attack stat a body swinging `item` would have at the gate that opens it -- the denominator the
-- item's magnitude is judged against. Magic items are measured against magicDamage on a mage-grown
-- reference, for the same reason the magic probe is (see Balance.growthClassFor).
function Balance.wielderStatFor(idOrItem)
    local def = idOrItem
    if type(idOrItem) == "string" then def = Item.defs[idOrItem] end
    if not def then return 0 end

    local magical = false
    for _, t in ipairs(def.tags or {}) do
        if t == "magical" then magical = true end
    end
    local prestige = Balance.prestigeForSlot(def.unlockQuests) -- the standing its rung is bought at, not the rung
    local ref = Balance.refChar(prestige, magical and "mage" or nil)
    return (magical and ref.stats.magicDamage or ref.stats.damage) or 0
end

-- The share of its wielder's stat an item's level-0 magnitude currently is, or nil if it has no
-- damaging magnitude to judge. Consumables are excluded: a one-shot is priced on being one-shot, and
-- a healing potion legitimately restores several times what a blow deals.
function Balance.itemShare(id)
    local def = Item.defs[id]
    if not def or def.type == "consumable" then return nil end
    local item = Item.instantiate(id, 1, 0)
    local ab = item.activeAbility
    if not (ab and type(ab.damage) == "number") then return nil end
    local stat = Balance.wielderStatFor(def)
    if stat <= 0 then return nil end
    return ab.damage / stat, ab.damage, stat
end

-- The grouping an item's power level is read within: its weapon family (Item.archetype), or its item
-- type for anything that declares none. An ability is not a weapon and has no archetype, so all
-- damaging abilities are read as one group.
function Balance.familyOf(idOrDef)
    local def = idOrDef
    if type(idOrDef) == "string" then def = Item.defs[idOrDef] end
    if not def then return nil end
    return Item.archetype(def) or def.type
end

-- The top rung of the shelf ladder: the deepest slot any priced item actually unlocks from.
--
-- DERIVED, not typed. A house's slot count is not the answer -- each line is ten numbered slots but
-- Quest.sponsorProgress counts every quest naming that sponsor, side quests included, so the reachable
-- ceiling runs 12 to 14 and differs per house (arcanum and undercroft stop at 12, the cathedral and the
-- Lodge reach 14). Reading the data's own deepest gate keeps the ladder as long as the shelf really is,
-- and moves it the day a slot is added. Memoized.
local maxSlotCache
function Balance.maxSlot()
    if maxSlotCache then return maxSlotCache end
    local m = 0
    for _, def in pairs(Item.defs) do
        if def.price and (def.unlockQuests or 0) > m then m = def.unlockQuests end
    end
    maxSlotCache = m
    return m
end

-- family -> { base, top }: the two ends of that family's ladder, read off its base weapon's own forge
-- ramp. `base` is the base weapon unforged, `top` is the same weapon at Item.MAX_LEVEL.
--
-- This is where "the last slot unforged equals the first slot fully forged" comes from -- it is not an
-- extra rule, it is what reading these two numbers MEANS. Memoized.
local anchorCache
function Balance.slotAnchors()
    if anchorCache then return anchorCache end
    anchorCache = {}

    local function powerOf(id, level)
        local item = Item.instantiate(id, 1, level)
        local ab = item and item.activeAbility
        return (ab and type(ab.damage) == "number") and ab.damage or nil
    end

    for fam, baseId in pairs(Balance.FAMILY_BASE) do
        local base, top = powerOf(baseId, 0), powerOf(baseId, Item.MAX_LEVEL)
        if base and top and top > base then anchorCache[fam] = { base = base, top = top } end
    end

    -- The ability group reads a NAMED BASE too (Balance.ABILITY_BASE), for the same reason the weapon
    -- families do -- and this one was learned the hard way.
    --
    -- It first took a MEDIAN of the early ability shelf, on the reasoning that 32 exemplars is a sample
    -- no single weapon family has. That is a target derived from the data being audited, which is the
    -- exact tautology the header of this file warns about, and it does not merely fail to catch things:
    -- it CANNOT CONVERGE. tools/balance_rescale.lua raised 70 abilities to the median, which raised the
    -- median, which raised the target above every one of them again -- the pass ran, wrote 141 files,
    -- and the spec came back with the same 70 abilities still under a target that had moved up to meet
    -- them. A ladder has to be anchored to something that does not move when the rungs do.
    local base, top = powerOf(Balance.ABILITY_BASE, 0), powerOf(Balance.ABILITY_BASE, Item.MAX_LEVEL)
    if base and top and top > base then anchorCache.ability = { base = base, top = top } end

    return anchorCache
end

-- The magnitude a `fam` item unlocking at `slot` should carry, unforged. A straight line between the
-- family's two anchors -- the same shape Curve.ramp lays over the forge levels, laid over the slots.
-- Nil for a family with no readable anchors, which gets no judgement rather than an invented one.
function Balance.slotTarget(fam, slot)
    local a = fam and Balance.slotAnchors()[fam]
    if not a then return nil end
    local span = Balance.maxSlot()
    local f = span > 0 and math.min(1, math.max(0, (slot or 0) / span)) or 0
    return math.max(1, math.floor(a.base + f * (a.top - a.base) + 0.5))
end

-- The same target expressed as a SHARE of the attack stat of the body that would swing it at that slot.
-- Only tools/balance_report.lua wants this -- its pace table is authored in share space -- and it is
-- derived from Balance.slotTarget rather than kept beside it, so the report and the rule cannot
-- disagree. (A second constant here is exactly how the two halves of a house's offer drifted onto
-- different granularities the last time.)
function Balance.familyShareAt(fam, slot)
    local want = Balance.slotTarget(fam, slot)
    if not want then return nil end
    local baseId = Balance.FAMILY_BASE[fam]
    local def = baseId and Item.defs[baseId]
    local stat = Balance.wielderStatFor({ tags = (def and def.tags) or {}, unlockQuests = slot or 0 })
    if stat <= 0 then return nil end
    return want / stat
end

-- Is this item's damage a thing the ladder has any business grading?
--
-- Three self-declaring exclusions, no list:
--   no numeric damage        nothing to compare. A curve is resolved by then, so this really means
--                            "this item does not deal authored damage".
--   a consumable             priced on being one-shot; a potion legitimately outdoes a blow.
--   target = "ally"          THE ONE THAT MATTERS. Four weapons are aimed at a friend and deal zero on
--                            purpose -- weapon_shepherds_crook hooks an ally two tiles,
--                            weapon_sealed_ward_wand and weapon_reflecting_wand lay a ward on one,
--                            weapon_second_utterance_wand pays somebody else's wind-up. Raising those
--                            to a slot target would not strengthen them, it would make each one WOUND
--                            THE ALLY IT IS POINTED AT. They are not low; they have no damage to rule
--                            on, and a waiver would have implied otherwise.
function Balance.gradesOnMagnitude(idOrDef)
    local def = idOrDef
    if type(idOrDef) == "string" then def = Item.defs[idOrDef] end
    if not def then return false end
    if def.type ~= "weapon" and def.type ~= "ability" then return false end
    local ab = def.activeAbility
    if not ab then return false end
    if ab.target == "ally" or ab.support then return false end
    local d = ab.damage
    if type(d) ~= "number" and type(d) ~= "table" then return false end
    return true
end

-- The unforged magnitude an item SHOULD carry for the slot it unlocks from, and what it does carry.
-- Returns `want, have, ratio, target` -- `ratio` being how far off its slot it sits, so 1.0 is exactly
-- right whatever family it belongs to. Nil when there is nothing to judge.
--
-- No `def.price` condition, deliberately. The quest-reward shelf is 70 items the player is HANDED for
-- finishing a line, and gating the rule on a price left every one of them unmeasured in both directions
-- -- which is how weapon_deadfall_bow shipped at a fifth of its slot's number.
function Balance.itemMagnitude(id)
    local def = Item.defs[id]
    if not Balance.gradesOnMagnitude(def) then return nil end
    local item = Item.instantiate(id, 1, 0)
    local ab = item and item.activeAbility
    local have = ab and ab.damage
    if type(have) ~= "number" then return nil end

    local fam = Balance.familyOf(def)
    local want = Balance.slotTarget(fam, def.unlockQuests or 0)
    if not want then return nil end
    return want, have, have / math.max(1, want), fam
end

-- How far off its slot an item sits, as a verdict: "ok", "low" or "high". Honors the waivers, so a
-- caller does not have to remember to.
function Balance.magnitudeVerdict(id)
    local want, have = Balance.itemMagnitude(id)
    if not want then return nil end
    if Balance.MAGNITUDE_WAIVERS[id] then return "ok", want, have end
    local tol = math.max(Balance.SLOT_TOLERANCE.floor, want * Balance.SLOT_TOLERANCE.share)
    if have < want - tol then return "low", want, have end
    if have > want + tol then return "high", want, have end
    return "ok", want, have
end

-- Every quest, ordered the way a player meets them -- by the prestige they require, then by name so
-- two runs agree. The report and the spec both walk this, so "the earliest offender" means the same
-- thing in each.
function Balance.questOrder()
    local ids = {}
    for id in pairs(Quest.defs) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local pa, pb = Balance.prestigeFor(a), Balance.prestigeFor(b)
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return ids
end

-- Drop the memos. Only a tool that rewrites blueprints between walks needs this. Placed here, below
-- every cache it names, so the assignments reach the locals rather than inventing globals.
function Balance.reset()
    refCache = {}
    facedCache = nil
    anchorCache = nil
    maxSlotCache = nil
end

return Balance
