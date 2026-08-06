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

-- What a WEAPON or damaging ABILITY contributes, as a share of the attack stat of the body swinging
-- it, at the gate that opens it.
--
-- The rule this exists to hold: **an item's magnitude scales with its gate, because the body does.**
-- A character's attack stat grows every level, so a magnitude authored flat across the campaign is a
-- magnitude that quietly stops mattering -- and the audit found exactly that. Damage contributed
-- ~0.45 of the wielder's stat at gate 0 and ~0.20 by gate 11, so the four-hundred-gold weapon on the
-- last shelf was a smaller step than the sixty-gold one on the first. That is the shop ceasing to be
-- a reward, which is the whole thing docs/progression.md is trying to fix.
--
-- 0.45 is where gates 0-4 already sit, chosen so the EARLY game does not move: that end was verified
-- by hand and plays correctly, and a target drawn from the late end would have dragged it with it.
-- The late shelf comes up to meet it.
--
-- BAND, not a point, because riders are real: weapon_quietus is a gate-6 dagger at 330 gold whose
-- number is deliberately small because what it sells is a kill that cannot be revived. An item paying
-- for an effect is allowed to sit low; tests/balance_spec.lua names those.
--
-- PER FAMILY, NOT ACROSS THEM. This is the correction that matters: docs/weapons.md gives each
-- archetype its own power level, paid for with tempo and hands -- a greatsword "winds up a turn, then
-- lands the heaviest hit in the game" and weapon_iron_greatsword really does carry four times a
-- dagger's power. A single share across all weapons proposed cutting it 24 -> 5 and would have
-- deleted the entire archetype system tests/weapon_spec.lua exists to defend. So the share is
-- measured against the family's OWN early exemplars, and what is held constant is each family's
-- level across the gates -- not one level for every weapon in the game.
--
-- There is deliberately no global fallback share. A family with too few early exemplars to read a
-- level from gets NO judgement rather than an invented one -- see Balance.FAMILY_MIN_SAMPLE. (A
-- `Balance.ITEM_SHARE = 0.45` constant lived here briefly and was deleted unused, which is the same
-- mistake Vendor.tier was: a knob nothing reads is a knob that drifts.)
Balance.ITEM_SHARE_BAND = { min = 0.55, max = 1.8 } -- as a RATIO to the family's own target

-- Gates counted as "early" when reading the ABILITY group's level, which has no single base weapon to
-- read from and 32 exemplars to take a median over.
Balance.EARLY_GATES = 4

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

-- Drop the memos. Only a tool that rewrites blueprints between walks needs this.
function Balance.reset()
    refCache = {}
    facedCache = nil
    familyCache = nil
end

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

-- The standing an ITEM should be judged at: the earlier of its shelf gate and when it is first faced.
function Balance.itemPrestige(id, def)
    def = def or Item.defs[id]
    local prestige = math.max(1, (def and def.unlockQuests) or 0)
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
    local prestige = math.max(1, def.unlockQuests or 0)
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

-- family -> the share it is held to across every gate, so a greatsword stays a greatsword and a dagger
-- stays a dagger while both stop drifting as the campaign goes on.
--
-- A weapon family reads its BASE (Balance.FAMILY_BASE). Abilities have no archetype and no single
-- base -- "the ability shelf" is not one thing the way "the axe" is -- so that group keeps a median,
-- which it can afford at 32 early exemplars. Memoized.
local familyCache
function Balance.familyShares()
    if familyCache then return familyCache end
    familyCache = {}

    for fam, baseId in pairs(Balance.FAMILY_BASE) do
        local share = Balance.itemShare(baseId)
        if share then familyCache[fam] = share end
    end

    local abilities = {}
    for id, def in pairs(Item.defs) do
        if def.price and def.type == "ability" and (def.unlockQuests or 0) <= Balance.EARLY_GATES
            and Balance.familyOf(def) == "ability" then
            local share = Balance.itemShare(id)
            if share then abilities[#abilities + 1] = share end
        end
    end
    if #abilities > 0 then
        table.sort(abilities)
        local n = #abilities
        familyCache.ability = (n % 2 == 1) and abilities[(n + 1) / 2]
            or (abilities[n / 2] + abilities[n / 2 + 1]) / 2
    end

    return familyCache
end

-- The level-0 magnitude an item SHOULD carry for its gate, and what it currently does carry.
-- Returns `want, have, ratio` -- `ratio` being how far off its family's level it sits, so 1.0 is
-- exactly right whatever family it belongs to. Nil when there is no magnitude to judge.
function Balance.itemMagnitude(id)
    local share, have, stat = Balance.itemShare(id)
    if not share then return nil end
    local fam = Balance.familyOf(id)
    -- No trusted level for this family -> no judgement. Returning the global fallback here would be
    -- inventing a target for exactly the families whose levels are least understood.
    local target = fam and Balance.familyShares()[fam]
    if not target then return nil end
    local want = math.max(1, math.floor(stat * target + 0.5))
    return want, have, have / math.max(1, want), target
end

-- Markers that say "this item sells something other than its number". Matched against the
-- blueprint's declared fields AND its source text.
--
-- The source scan is not laziness -- it is the only thing that works. Most riders are arguments to
-- `fx.damage` INSIDE the effect closure (`fx.damage(fx.target, { knockback = { distance = 4 } })`),
-- and a closure can only be inspected by calling it, which needs a live board. Reading the blueprint
-- fields alone reported weapon_long_fall as a plain 2-power mace and proposed a sevenfold buff -- a
-- weapon whose own header says "a damage curve so low that the shove is not merely the point, it is
-- the entire weapon", and that hitting for a mace's damage as well "would simply be the best knight
-- weapon in the game". The prose was right and the field list could not see it.
local RIDER_FIELDS = {
    "inflicts", "hits", "stun", "healing", "restore", "summon",
    "waitBehavior", "requiresAdjacent", "raw", "reviveHealth",
    -- The censer family's whole mechanic: ground that walks with the bearer (Combat.layIncense). Every
    -- censer carries one and its strike is feeble by the family contract, so without this the two
    -- late censers read as plain 4-power sticks.
    "incense",
}

-- Ways an item can beat its family's BASE on reach or handling. Buying one of these is buying
-- something, and an item that has paid for it may sit low on damage -- weapon_harriers_bow is the
-- case that found this: range 4 against the iron bow's 3, its own header saying "under the iron bow:
-- the freedom is the price", and slower speed on top. A rider is not always an effect; sometimes it
-- is a restriction the base has and this one does not.
local REACH_AXES = {
    { key = "range", better = function(a, b) return a > b end },
    { key = "minRange", better = function(a, b) return a < b end },
}
-- Rather than a keyword list, the source test is STRUCTURAL: an item is plain only if its effect does
-- exactly one thing -- a single unqualified `fx.damage(fx.target)` and no other fx call. Anything
-- else is selling something.
--
-- A keyword list was tried and kept under-reaching, three times over: it missed `knockback` (an
-- argument inside the closure), then `fx.spendChi` (ability_asura_strike's 6 is a FLOOR, the real
-- damage is +6 per chi), then a loop applying `fx.damage` to every enemy in a hazard. Each miss
-- proposed buffing a weapon whose own header explains why the number is small. Enumerating what a
-- rider can be is a losing game; recognising what PLAIN looks like is one line.
local PLAIN_EFFECT = "fx%.damage%(%s*fx%.target%s*%)"

local sourceCache = {}
local function itemSource(id)
    if sourceCache[id] ~= nil then return sourceCache[id] end
    local text = false
    for _, dir in ipairs({ "weapon", "armor", "utility", "consumable", "ability" }) do
        local path = "data/items/" .. dir .. "/" .. id .. ".lua"
        if love and love.filesystem and love.filesystem.getInfo(path) then
            text = love.filesystem.read(path) or false
            break
        end
    end
    sourceCache[id] = text
    return text
end

-- Does this item sell something other than its number? Items that carry a rider are allowed to sit
-- low in the share band, because the number is not what the player is buying.
function Balance.hasRider(idOrDef)
    local def, id = idOrDef, nil
    if type(idOrDef) == "string" then id, def = idOrDef, Item.defs[idOrDef] end
    if not def then return false end
    if def.traits and #def.traits > 0 then return true end

    -- Checked on the ITEM as well as on its ability: `waitBehavior` (a staff's Focus swap, and where
    -- the Warding Staff's whole ward lives) is a top-level field, and looking only inside
    -- activeAbility reported a 560-gold relic as a plain 4-power stick.
    local ab = def.activeAbility
    for _, key in ipairs(RIDER_FIELDS) do
        if def[key] ~= nil or (ab and ab[key] ~= nil) then return true end
    end

    -- Does it out-reach or out-handle its own family's base?
    local fam = Balance.familyOf(def)
    local baseId = fam and Balance.FAMILY_BASE[fam]
    if baseId and baseId ~= id then
        local base = Item.defs[baseId]
        local bab = base and base.activeAbility
        if ab and bab then
            for _, axis in ipairs(REACH_AXES) do
                local mine, theirs = ab[axis.key], bab[axis.key]
                if mine and theirs and axis.better(mine, theirs) then return true end
            end
            if bab.requiresSight and not ab.requiresSight then return true end
        end
        if base and base.hands and def.hands and def.hands < base.hands then return true end
    end

    local text = id and itemSource(id)
    if not text then return false end

    -- Strip comments AND string literals first: these blueprints are two-thirds prose, and a header
    -- explaining what the weapon does not do -- or a `description` reading "Inflicts Root" -- would
    -- otherwise register as the mechanic it is describing.
    local code = text:gsub("%-%-%[%[.-%]%]", " "):gsub("%-%-[^\n]*", " ")
    code = code:gsub('"[^"]*"', '""'):gsub("%[%[.-%]%]", '""')

    -- Count fx calls. Exactly one, and it a plain strike at the target, is a plain weapon.
    local fxCalls, plain = 0, 0
    for _ in code:gmatch("fx%.%a+%s*%(") do fxCalls = fxCalls + 1 end
    for _ in code:gmatch(PLAIN_EFFECT) do plain = plain + 1 end
    return not (fxCalls == 1 and plain == 1)
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

return Balance
