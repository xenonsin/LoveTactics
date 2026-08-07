-- Item POWER GRADE: what a thing is worth, read without looking at where it sits on a shelf.
--
-- THE PROBLEM THIS EXISTS TO FIX. Every shelf gate in the game was written by one pass
-- (tools/unlock_rescale.lua), which ranked each house's stock by `(retired wave enum, PRICE, id)` and
-- spread it evenly by COUNT. Price is a cost, not a grade, and it does not even sort by power -- it
-- sorts by CATEGORY, because the types are priced on different scales for reasons that have nothing to
-- do with strength (a consumable is cheap for being one-shot, a passive dear for being permanent).
-- Measured across the 484 priced items, the last third of every shelf came out 35% passive utilities
-- and 2% consumables. That is the ranking, not a coincidence.
--
-- It stopped being cosmetic when the slot became the grade: Balance.slotTarget reads `unlockQuests` and
-- GRANTS an item its magnitude. So the power ladder is anchored on a field that was assigned by price,
-- and Balance.itemMagnitude cannot notice, because it derives the target it checks from the same field.
--
-- SO THE GRADE MAY NEVER READ `unlockQuests` OR `price`. Not as a hint, not as a tiebreak. Both are
-- downstream of it now (grade -> slot -> price), and a grader that peeked at either would be the same
-- tautology this file was written to break -- the one Balance.slotAnchors' header already describes,
-- where a target read off the audited data raises itself to meet whatever it was supposed to judge.
-- The rule has a second payoff: 166 quest rewards carry NEITHER field, and a grade that leaned on
-- them could not have graded a single one. (Those items all read as slot 0 to Balance today, which is
-- why a reward handed over at the end of a line is held to opening-shelf magnitude.)
--
-- THE UNIT IS DAMAGE, against the reference body, at one fixed standing (Grade.PRESTIGE). Everything
-- converts through Grade.turnValue() -- what one body's turn is worth in damage -- so a stun and a
-- fireball and a +3 charm are quoted on one scale. Authored knobs below are in TURNS and PERCENT,
-- which is what a designer can argue about; the arithmetic that turns those into damage stays here.
--
-- IT IS A MARGIN, NOT A TOTAL. An active item is graded on what it adds to the turn it is spent on,
-- NET of the swing it replaces (Grade.turnValue), because spending your action on it means not
-- swinging. A passive is graded on what it adds to every turn, with nothing subtracted -- it costs no
-- action. That is what makes a charm and a greataxe comparable at all: both answer "how much better is
-- this turn for having brought it", and neither answer needs the other item's slot.
--
-- A GRADE MAY COME OUT NEGATIVE, and that is a reading rather than a fault. Netting off the turn an
-- active costs means an ability that spends the whole turn to do less than a swing scores below zero,
-- which is the correct thing to say about it (ability_pull -- one body hauled one tile, no damage --
-- is the standing example). Nothing is clamped, because clamping would pile every weak item at zero
-- and take the ranking away exactly where it is most useful.
--
-- WHAT IT DOES NOT PRICE, said out loud. A consumable is graded per ACTIVATION, exactly like an
-- ability -- the fact that you only get one is a PRICE matter (Vendor pricing applies the one-shot
-- discount), not a power matter. Grading the one-shot-ness here as well would bill it twice and drain
-- every consumable back to slot 0, which is the mirror of the bug above rather than a fix for it.
--
-- WHERE THE NUMBERS COME FROM. An item's effect is a Lua function, so it is not read by scanning
-- source -- it is DRY-RUN through Combat.abilityOutput, the same inert replay the inventory tooltip
-- uses. That is the game's own answer to "what does this do", it already handles AoE, carried
-- statuses, summons and placed ground, and it is preview-safe by construction. Statuses are then
-- valued off their OWN blueprint fields (duration, magnitude, the disable flags), so a status retuned
-- in data/status moves every item that inflicts it. Traits cannot be derived -- they are hook
-- functions -- so they carry an authored `grade`, in turns, and fall back to a shape-based estimate
-- until one is written.

local Balance = require("models.balance")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")

local Grade = {}

-- ---------------------------------------------------------------------------
-- Authored: the knobs. In turns and percent -- the only numbers in this file.
-- ---------------------------------------------------------------------------

-- The ONE standing every item in the game is read at. Fixed on purpose: a grade evaluated at each
-- item's own gate would be reading the slot through the back door, and the whole point is a ruler that
-- does not move when the thing it measures does. Mid-campaign, so neither the opening shelf nor the
-- capstone is measured at the far end of a curve it never really fights at.
Grade.PRESTIGE = 6

-- A reference fight, in turns. What a persistent thing gets to do before the fight is over -- a
-- summon's lifetime, a hazard's occupancy, the horizon a per-turn passive is worth anything over.
-- docs/balance.md's TTK bands put a four-strong field at "a handful of exchanges"; this is that.
Grade.FIGHT_TURNS = 8

-- Bodies an area effect actually catches. NOT the footprint's cell count -- a field is four a side
-- (docs/deployment.md), they do not stand in a block, and a grader that multiplied by nine cells would
-- rate every radius-1 spell as the best item in the game. These are what a competent cast lands.
Grade.EXPECTED_BODIES = {
    [1] = 1,     -- single target
    small = 2.1, -- radius 1 / a 3-wide arc / a 2-long line: the common case
    large = 2.8, -- radius 2+ / a long line: worth more, but the field is still only four deep
}

-- The most one APPLICATION of a status may be worth, in turns, however many of the fields above it
-- happens to set. The components are additive and several statuses set four or five of them: Frozen
-- shoves initiative, disables reactions, interrupts a channel AND opens a vulnerability, which summed
-- to better than two turns off one cast. That made a single-target bolt out-rank an area spell, which
-- is the wrong answer to a question the anchor pairs already settle -- so the ceiling is stated here
-- rather than by quietly shaving whichever component was most convenient.
Grade.STATUS_VALUE_CAP = 1.5

-- What one application of a status is worth, in TURNS of the body it lands on, by what the status
-- DOES. Read off the status blueprint's own fields (models/status.lua's contract), so retuning a
-- status in data/status moves every item that inflicts it and nothing has to be restated here.
--
-- Durations scale these, except where noted: a disable is worth its share of every turn it covers.
Grade.STATUS_TURNS = {
    disablesActions = 1.0,  -- the whole turn: it cannot act
    blocksMove = 0.35,      -- it may still act, it just cannot go anywhere
    stopsMovement = 0.35,
    untargetable = 0.5,     -- defensive: half a turn's worth of blows go nowhere
    disablesWeapon = 0.5,   -- half a kit
    silencesMana = 0.5,
    deniesMagic = 0.5,
    disablesTraits = 0.25,
    disablesReactions = 0.15,
    interruptsChannel = 0.2, -- one-shot, not per turn: it drops what was being held
    preventsDeath = 1.5,    -- one-shot, and the largest single thing a status can be
    reflects = 0.6,
    lifesteal = 0.3,
}

-- One-shot entries above: valued once, not multiplied by how long the badge lingers.
Grade.STATUS_ONESHOT = { interruptsChannel = true, preventsDeath = true }

-- The most turns a status is paid for, however long its badge runs. A duration multiplier with no
-- ceiling says a 30-tick Invisible is worth six turns of not being shot at, which priced three rogue
-- items at four times anything else on their shelf. It is not worth six turns because the fight does
-- not stand still for it: the body gets cleansed, or killed, or simply walks out of relevance.
Grade.STATUS_MAX_TURNS = 3

-- A vulnerability window is worth the matching hits that land in it, and nothing at all to a party
-- carrying the wrong damage type. Hits are capped because a window is a window -- the field is four
-- deep and they do not all reach the same body.
Grade.VULNERABLE_MAX_HITS = 1.5
Grade.VULNERABLE_TAG_MATCH = 0.6

-- Putting a fallen body back on the board, in turns. The largest single verb an ability has: it is a
-- body's remaining turns, plus the ones the party does not spend covering the hole where it stood.
Grade.REVIVE_TURNS = 3.5

-- STATUSES WHOSE MECHANIC IS NOT IN A FIELD, in turns, authored one by one.
--
-- Everything above this reads a status blueprint and derives. These 31 cannot be derived by anything,
-- because what they do does not live in data at all -- Taunt is an AI redirect in models/ai.lua, Charm
-- flips a side, Knell is a branch in Status.tick, Wild Shape swaps the whole body. A grader that only
-- read fields scored every one of them at zero, which read the Bastion's entire control kit -- the
-- house whose whole trade is deciding where you stand -- as worth nothing, and buried it at slot 0.
--
-- Authored in TURNS, the same unit as everything else here, and stated as a judgement rather than
-- measured, because there is nothing to measure. A blueprint may override with its own `grade` field.
-- Zero is a real entry and not an omission: Channeling and Given Guard are COSTS their bearer pays,
-- and a grader that scored them as gains would pay an item for its own downside.
Grade.STATUS_GRADE = {
    -- Control: the turn belongs to somebody else now.
    status_charm = 2.2,          -- it fights for you: their turn denied and yours gained
    -- A pig, for the twelve ticks it lasts. The disable is not in any field and cannot be: what the
    -- victim loses is everything data/characters/character_pig.lua does not have, which is items and
    -- fangs. The derivation saw only the two flags the badge does carry (a channel dropped, reactions
    -- off) and read the strongest removal spell on the shelf at half a turn -- second-worst item in the
    -- Arcanum. Valued instead at STATUS_TURNS.disablesActions for every turn it covers, because that is
    -- exactly what it is: 12 ticks is 2.4 turns in which the body can walk and do nothing else.
    -- Balance.MAGNITUDE_WAIVERS already says the same thing from the other end -- the Swineherd's Wand
    -- is excused its damage because "polymorph removes the body from the fight outright".
    status_polymorph = 2.4,
    status_taunt = 1.3,          -- must swing at the taunter, wherever that leaves it
    status_knell = 3.0,          -- a kill on a clock, if the clock is allowed to run out
    status_downed = 2.5,         -- a body off the board, short of a corpse
    status_interred = 1.0,       -- every heal lands as a wound: it cannot be saved
    status_unclosing_wound = 0.9,-- cannot be healed at all
    status_sealed_hour = 0.6,    -- damage and healing held, then settled at once
    status_conjoined = 1.2,      -- wounds shared across the binding
    status_blind = 0.6,          -- range cut to arm's length
    status_limned = 0.4,         -- lit up however well it hid
    status_struck_ledger = 0.5,  -- lit up, and worth coin when it falls
    status_bleed = 0.7,          -- it pays to move, so it stops moving
    status_rimebitten = 0.8,     -- extra cold on every hit that lands

    -- Tempo and reach, on your own side.
    status_hasted = 1.4,         -- costs halved for four turns
    status_empowered = 0.5,      -- one stored blow
    status_graven = 0.7,         -- cheaper inside your own circle
    status_second_utterance = 1.0, -- one channel resolves at once: a wind-up refunded
    status_open_account = 1.2,   -- wounds settled out of the purse instead of the body
    status_intercession = 1.5,   -- their blows heal you

    -- Guard, lent and taken.
    status_defending = 0.5,      -- braced until your next turn
    status_lent_guard = 0.6,     -- wearing somebody else's plate
    status_shared_burden = 0.9,  -- half of every wound borne by the one who swore it
    status_given_guard = 0.0,    -- the COST half of lending it: the giver stands thinner

    -- Wearing another body: a whole second kit for a while. The `transform` verb prices the swap
    -- itself (Grade.VERB_TURNS), so these price only what the shape is worth once worn.
    status_wild_shape_bear = 1.2,
    status_wild_shape_wolf = 1.2,
    status_wild_shape_raven = 1.2,

    -- Bodies the player fights rather than buys. Graded so a bestiary sweep reads the same scale.
    status_enraged = 1.5,
    status_wrath = 1.5,
    status_roaring = 0.8,
    status_sworn = 0.6,
    status_channeling = 0.0,     -- a wind-up in progress: the cost, not the payoff
}

-- A stat point, in damage per turn, for the stats a status or an item bonus can move. An attack stat
-- is worth its face value every swing; defence is worth what it stops; a point of speed or move is
-- worth a slice of a turn. Authored rather than derived because a derivation would have to assume a
-- body, and these are the same for every body by design.
Grade.STAT_VALUE = {
    damage = 1.0,
    magicDamage = 1.0,
    defense = 0.9,
    magicDefense = 0.9,
    health = 0.12,       -- a point of health is a fraction of a blow
    speed = 0.06,        -- ticks; a turn is Status.TICKS_PER_TURN of them
    movement = 0.55,     -- a tile of reach every turn, and the commonest bonus on the shelf
    range = 0.15,
    stamina = 0.05,
    mana = 0.05,
}

-- Trait value when the blueprint has not authored one, in turns per fight, by the hook it hangs on.
-- A floor and an honest admission: a trait is a Lua function and nothing here can read what it does.
-- The report marks every trait still riding this estimate so the authored weights can land where they
-- actually change a ranking, rather than all 114 up front.
--
-- SCALED OFF THE ABILITY, not guessed. These were first written as fractions of a turn, and because
-- every utility on the shelf is a trait in a wrapper, that one number decided the rank of a whole item
-- type -- it buried all 67 of them below every weapon in the game, which is not a finding, it is the
-- default leaking. The band comes from what a trait IS instead: a passive mini-ability that fires a few
-- times a fight without being cast. An ability's margin is worth roughly a turn and a half; a trait
-- that fires two or three times for about half an ability's effect is therefore two to three turns
-- across a fight, and that is the range below.
--
-- It is still an estimate and the report still marks every item riding one. What this buys is that the
-- estimate is now the right ORDER OF MAGNITUDE, so a ranking built on it is worth arguing with.
Grade.TRAIT_DEFAULT_TURNS = {
    onDamaged = 3.2,       -- fires when hit, which in a real fight is often
    onCombatStart = 2.4,   -- once, but it shapes the whole fight
    onCast = 2.0,
    onAnyCast = 2.0,
    onStatusApplied = 2.0,
    onAnyDeath = 1.6,
    onDeath = 1.2,
    countersSpell = 2.8,
    revivesOnLethal = 5.5,  -- a body that does not fall is the largest thing a trait does
    default = 2.0,
}

-- A cooldown caps how often a trait can pay out. Ticks -> triggers per reference fight.
Grade.TRAIT_COOLDOWN_FLOOR = 0.35

-- Authored trait weights, in TURNS OF ADVANTAGE PER FIGHT -- the unit every knob in this file is
-- quoted in. A trait is a hook function, so this is the one input models/grade.lua cannot derive:
-- each number here is a judgement, weighed on the bench and stated rather than measured.
-- Grade.traitValue reads this before it falls back to the shape estimate above.
--
-- WHERE THE ESTIMATE WAS WORST, for the record, because it says what the shape estimate cannot see.
-- Alchemist's Reservoir and Overchannel both seeded at the floor -- their blueprints are a name and a
-- flag, with the behaviour living in models/combat.lua -- and both were judged at 4.5: "cast anyway
-- when the pool is dry" is a rule about the whole fight, and nothing in the trait file says so. The
-- inverse happened too: Demon Ascendant and Contagion seeded reactive and were judged at 0.5.
Grade.TRAIT_GRADE = {
    trait_blood_price =                 0.5,  -- Blood Price
    trait_boss_phases =                 0.5,  -- Demon Ascendant
    trait_contagion =                   0.5,  -- Contagion
    trait_devotion_unbidden =           0.5,  -- Unbidden
    trait_jealous_resin =               0.5,  -- Jealous Resin
    trait_arcane_conduit =              1.0,  -- Arcane Conduit
    trait_second_utterance =            1.0,  -- Second Utterance
    trait_battle_casting =              2.0,  -- Battle Casting
    trait_breakers_harness =            3.0,  -- Breaker's Harness
    trait_cutpurse_tally =              3.0,  -- Cutpurse's Tally
    trait_dampening_oath =              3.0,  -- Dampening Oath
    trait_deaths_dividend =             3.0,  -- Death's Dividend
    trait_gaunt_vigil =                 3.0,  -- Gaunt Vigil
    trait_quarrys_due =                 3.0,  -- Quarry's Due
    trait_skirmishers_momentum =        3.0,  -- Skirmisher's Momentum
    trait_spell_eater =                 3.0,  -- Spell Eater
    trait_substitution =                3.0,  -- Substitution
    trait_unrelieved =                  3.0,  -- The Unrelieved
    trait_vow_marked =                  3.0,  -- Vow-Marked
    trait_wardens_parry =               3.0,  -- Warden's Parry
    trait_wardens_writ =                3.0,  -- Warden's Writ
    trait_alchemists_reservoir =        4.5,  -- Alchemist's Reservoir
    trait_battleborn =                  4.5,  -- Battleborn
    trait_falconers_hawk =              4.5,  -- Falconer's Hawk
    trait_magic_denial =                4.5,  -- Magic Denial
    trait_overchannel =                 4.5,  -- Overchannel
    trait_watching_the_shoulder =       4.5,  -- Watching the Shoulder
    trait_whirl_answer =                4.5,  -- Whirl Answer
    trait_wolf_companion =              4.5,  -- Wolf Companion
    trait_wrath_rising =                6.0,  -- Rising Wrath

    -- ADOPTED FROM THE SEED, not individually weighed. These are the classifier's own numbers, taken
    -- as authored on the designer's instruction rather than argued one by one. They are real weights
    -- and the grader treats them as such -- but Grade.TRAIT_ADOPTED below keeps the provenance, because
    -- the seed's accuracy against the thirty that WERE judged was four exact matches out of thirty,
    -- wrong in both directions. When a shelf ranking later reads wrong, this is the first block to
    -- suspect, and it should stay findable.
    trait_arcane_reservoir =            0.5,  -- Arcane Reservoir
    trait_sanctified_presence =         0.5,  -- Sanctified Presence
    trait_against_the_odds =            1.0,  -- Against The Odds
    trait_breakers_wedge =              1.0,  -- Breaker's Wedge
    trait_cleansing_ward =              1.0,  -- Cleansing Ward
    trait_covetous_reflection =         1.0,  -- Covetous Reflection
    trait_formation_fighter =           1.0,  -- Formation Fighter
    trait_gleaning =                    1.0,  -- Gleaning
    trait_grave_cold =                  1.0,  -- Grave-Cold
    trait_kept_faith =                  1.0,  -- Kept Faith
    trait_martyrs_vow =                 1.0,  -- Martyr's Vow
    trait_meal_bottomless_pot =         1.0,  -- The Bottomless Pot
    trait_meal_heroics =                1.0,  -- Heroics
    trait_oathward =                    1.0,  -- Oathward
    trait_oathward_declared =           1.0,  -- Oathward Declared
    trait_resonant_grip =               1.0,  -- Resonant Grip
    trait_saviors_watch =               1.0,  -- Savior's Watch
    trait_skimmers_cut =                1.0,  -- Skimmer's Cut
    trait_smoke_mantle =                1.0,  -- Smoke Mantle
    trait_smoke_screen =                1.0,  -- Smoke Screen
    trait_still_standing =              1.0,  -- Still Standing
    trait_thrill_of_the_hunt =          1.0,  -- Thrill of the Hunt
    trait_unyielding =                  1.0,  -- Unyielding
    trait_vigil_beads =                 1.0,  -- Vigil Beads
    trait_zealots_mercy =               1.0,  -- Zealot's Mercy
    trait_ancestor_mask =               2.0,  -- Ancestor Mask
    trait_beastlords_bond =             2.0,  -- Beastlord's Bond
    trait_blood_fever =                 2.0,  -- Blood Fever
    trait_brawlers_bandolier =          2.0,  -- Brawler's Bandolier
    trait_cullers_kit =                 2.0,  -- Culler's Kit
    trait_executioners_eye =            2.0,  -- Executioner's Eye
    trait_field_still =                 2.0,  -- Field Still
    trait_ghost_wind =                  2.0,  -- Ghost-Wind
    trait_guardians_blessing =          2.0,  -- Guardian's Blessing
    trait_intercession =                2.0,  -- Intercession
    trait_ledger_diligence =            2.0,  -- Diligence
    trait_meal_the_wake =               2.0,  -- The Wake
    trait_muster_roll =                 2.0,  -- The Muster
    trait_opportunist =                 2.0,  -- Opportunist
    trait_rapture =                     2.0,  -- Rapture
    trait_ravenous =                    2.0,  -- Ravenous
    trait_round_for_the_house =         2.0,  -- Round for the House
    trait_second_wind =                 2.0,  -- Second Wind
    trait_shared_ledger =               2.0,  -- The Shared Ledger
    trait_stillshade =                  2.0,  -- Stillshade
    trait_stripped_plate =              2.0,  -- Stripped Plate
    trait_totem_carvers_kit =           2.0,  -- Totem-Carver's Kit
    trait_adrenal_surge =               3.0,  -- Adrenal Surge
    trait_binding_parry =               3.0,  -- Binding Parry
    trait_counter_magic =               3.0,  -- Counter Magic
    trait_dodge =                       3.0,  -- Dodge
    trait_follow_up =                   3.0,  -- Follow-Up
    trait_hollow_crown =                3.0,  -- The Hollow Crown
    trait_keen_senses =                 3.0,  -- Keen Senses
    trait_last_stand =                  3.0,  -- Last Stand
    trait_melee_counter =               3.0,  -- Melee Counter
    trait_outriders_harness =           3.0,  -- Outrider's Harness
    trait_parry =                       3.0,  -- Parry
    trait_ranged_counter =              3.0,  -- Ranged Counter
    trait_riposte =                     3.0,  -- Riposte
    trait_salvage_rig =                 3.0,  -- Salvage Rig
    trait_shield_bash =                 3.0,  -- Shield Bash
    trait_shield_shove =                3.0,  -- Shield Shove
    trait_slipstep =                    3.0,  -- Slipstep
    trait_spiteful_ichor =              3.0,  -- Spiteful Ichor
    trait_splitglass_parry =            3.0,  -- Splitglass Parry
    trait_stayed_hand =                 3.0,  -- The Stayed Hand
    trait_sundering_parry =             3.0,  -- Sundering Parry
    trait_survivors_reflex =            3.0,  -- Survivor's Reflex
    trait_the_long_wait =               3.0,  -- The Long Wait
    trait_thorns =                      3.0,  -- Thorns
    trait_unclosing_parry =             3.0,  -- Unclosing Parry
    trait_unspent_heart =               3.0,  -- Unspent Heart
    trait_vanishing_act =               3.0,  -- Vanishing Act
    trait_duelists_poise =              4.5,  -- Duelist's Poise
    trait_empty_vessel =                4.5,  -- Empty Vessel
    trait_marksmans_lens =              4.5,  -- Marksman's Lens
    trait_meal_finish_the_plate =       4.5,  -- Finish the Plate
    trait_rot_fume =                    4.5,  -- Rot-Fume
    trait_sealed_reliquary =            4.5,  -- Sealed Reliquary
    trait_volatile =                    4.5,  -- Volatile
}

-- Which of the weights above were ADOPTED from the classifier's seed rather than weighed one by
-- one. Changes no grade -- it is provenance, so a later reader can tell a decision from a default.
-- The thirty absent from this set are the judged ones.
Grade.TRAIT_ADOPTED = {
    trait_adrenal_surge = true,
    trait_against_the_odds = true,
    trait_ancestor_mask = true,
    trait_arcane_reservoir = true,
    trait_beastlords_bond = true,
    trait_binding_parry = true,
    trait_blood_fever = true,
    trait_brawlers_bandolier = true,
    trait_breakers_wedge = true,
    trait_cleansing_ward = true,
    trait_counter_magic = true,
    trait_covetous_reflection = true,
    trait_cullers_kit = true,
    trait_dodge = true,
    trait_duelists_poise = true,
    trait_empty_vessel = true,
    trait_executioners_eye = true,
    trait_field_still = true,
    trait_follow_up = true,
    trait_formation_fighter = true,
    trait_ghost_wind = true,
    trait_gleaning = true,
    trait_grave_cold = true,
    trait_guardians_blessing = true,
    trait_hollow_crown = true,
    trait_intercession = true,
    trait_keen_senses = true,
    trait_kept_faith = true,
    trait_last_stand = true,
    trait_ledger_diligence = true,
    trait_marksmans_lens = true,
    trait_martyrs_vow = true,
    trait_meal_bottomless_pot = true,
    trait_meal_finish_the_plate = true,
    trait_meal_heroics = true,
    trait_meal_the_wake = true,
    trait_melee_counter = true,
    trait_muster_roll = true,
    trait_oathward = true,
    trait_oathward_declared = true,
    trait_opportunist = true,
    trait_outriders_harness = true,
    trait_parry = true,
    trait_ranged_counter = true,
    trait_rapture = true,
    trait_ravenous = true,
    trait_resonant_grip = true,
    trait_riposte = true,
    trait_rot_fume = true,
    trait_round_for_the_house = true,
    trait_salvage_rig = true,
    trait_sanctified_presence = true,
    trait_saviors_watch = true,
    trait_sealed_reliquary = true,
    trait_second_wind = true,
    trait_shared_ledger = true,
    trait_shield_bash = true,
    trait_shield_shove = true,
    trait_skimmers_cut = true,
    trait_slipstep = true,
    trait_smoke_mantle = true,
    trait_smoke_screen = true,
    trait_spiteful_ichor = true,
    trait_splitglass_parry = true,
    trait_stayed_hand = true,
    trait_still_standing = true,
    trait_stillshade = true,
    trait_stripped_plate = true,
    trait_sundering_parry = true,
    trait_survivors_reflex = true,
    trait_the_long_wait = true,
    trait_thorns = true,
    trait_thrill_of_the_hunt = true,
    trait_totem_carvers_kit = true,
    trait_unclosing_parry = true,
    trait_unspent_heart = true,
    trait_unyielding = true,
    trait_vanishing_act = true,
    trait_vigil_beads = true,
    trait_volatile = true,
    trait_zealots_mercy = true,
}

-- Two mechanics in the game are conferred by a bare TAG on an item rather than by any field: Combat
-- .isFlying reads "flying" and Combat.ignoresTraps reads "ignore traps", both by scanning the grid.
-- An item can therefore carry a large rule while its blueprint holds nothing but a name and a sprite
-- (utility_zephyr_striders is exactly that), and a grader reading only fields scores it at zero.
-- Valued in turns per fight, like a trait.
Grade.TAG_TURNS = {
    ["flying"] = 2.6,        -- "the ground stops mattering": it declines the map's whole argument
    ["ignore traps"] = 0.5,  -- real, but it only pays on a board that was trapped
}

-- What a placed thing is worth, in turns. A summon is a body that takes turns; ground is turns of
-- denied or improved footing. Both are scaled by how long they last against Grade.FIGHT_TURNS.
Grade.PLACED_TURNS = {
    summon = 1.0,  -- per turn it survives: a body acting is a body acting
    hazard = 0.30, -- per turn it sits there: ground the enemy would rather not cross
    trap = 0.55,   -- one-shot, but it is a whole turn's worth when it springs
    wall = 0.40,   -- per turn: it re-routes a lane
}

-- Board verbs that Combat.abilityOutput records as flags rather than numbers, in turns.
Grade.VERB_TURNS = {
    extraAction = 1.0,  -- per action granted: definitionally a turn
    knockback = 0.18,   -- per tile shoved
    charge = 0.12,      -- per tile closed
    pull = 0.20,
    steal = 0.45,
    reveal = 0.10,
    cleanse = 0.55,     -- a debuff stripped is the debuff's own value, handed back
    dismiss = 0.90,     -- a summon sent away is a body off the board
    transform = 1.30,   -- wearing another shape for a while: a whole second kit
    prop = 0.45,        -- furniture left standing
    grants = 0.35,      -- an item handed over, to be spent later
    wall = 1.60,        -- a lane closed, and it stays closed
    swap = 0.60,        -- two bodies trade places: a rescue, or a body dragged out of position
    teleport = 0.55,    -- a body put where walking could not have put it
    recall = 0.75,      -- hauled back to where it started
}

-- A restored or drained pool, per point, in damage-equivalent. A pool is not health -- refilling
-- stamina buys the swings that stamina pays for, at a discount, because you were going to have some
-- of it anyway.
Grade.POOL_POINT = 0.35

-- Ticks of initiative bought or taken, against a turn's worth of them.
Grade.HASTEN_PER_TICK = 0.2

-- WHAT A SWING COSTS TO THROW, now that its damage no longer distinguishes it. Once the blow is
-- normalized to the family base, two weapons of a family are told apart only by what rides along --
-- and `speed` and `cost` ride along on nearly every ability in the game (449 and 392 of them). A
-- ponderous, expensive axe and a quick, cheap one are not the same item, and before these were read
-- the grader said they were.
--
-- Speed is in TICKS against a reference swing: faster than the sword comes round sooner and is worth
-- the difference, slower pays it. Cost is against a reference outlay, and is a discount rather than a
-- credit -- an ability you can afford three times in a fight does less than the same one at half the
-- price, however hard each cast hits.
Grade.REFERENCE_SPEED = 4   -- an iron sword's swing, the thing every other tempo is read against
Grade.TICK_VALUE = 0.06     -- a tick of initiative, in turns
Grade.REFERENCE_COST = 10   -- a middling outlay; dearer than this discounts, cheaper credits
Grade.COST_SWING = 0.25     -- how much of the total the full spread of costs is allowed to move

-- The wielder drinks a share of everything the blow opens. A keyword rather than an effect, so the
-- dry run never sees it -- and it is the whole difference between the Crimson Greataxe and the iron
-- axe it is supposed to tower over.
Grade.LIFESTEAL_VALUE = 1.0 -- health returned is worth damage dealt, point for point

-- Discounts, as multipliers on the whole. A wind-up is paid in tempo before anything lands; a
-- two-handed weapon costs the grid cell a second item would have used.
Grade.WINDUP_TURN_DISCOUNT = 0.15 -- per turn of hold, off the total
Grade.TWO_HANDED_DISCOUNT = 0.88

-- An ability that keeps your turn is worth the turn it did not spend. The mirror of the margin rule:
-- an ordinary cast has one turn's swing netted off it, and a free one does not.
Grade.FREE_ACTION_TURNS = 1.0

-- ---------------------------------------------------------------------------
-- Derived: the reference
-- ---------------------------------------------------------------------------

local cache = {}

-- The body every blow in this file is measured against, and the budget the reference loadout throws.
-- Balance owns both; this file only asks at ONE prestige so nothing here can drift per item.
local function reference(magical)
    local key = magical and "magic" or "phys"
    if cache[key] then return cache[key] end
    local probe = magical and "magic" or "slash"
    local body = Balance.unitFor(Balance.REFERENCE.charId,
        require("models.growth").levelForPrestige(Grade.PRESTIGE))
    local budget = Balance.attackBudget(Grade.PRESTIGE, { probe = probe })
    cache[key] = { body = body, budget = budget, tags = Balance.probe(probe).tags }
    return cache[key]
end

-- Damage-equivalent of ONE turn: what the reference loadout actually lands on the reference body after
-- mitigation. The exchange rate between every "turns" knob above and the damage scale everything else
-- is quoted in. Never zero -- a floored reference would divide the whole model by nothing.
--
-- Takes the SCHOOL, because the two sides of the stat sheet are not the same size. A magical item is
-- dry-run with a mage's magicDamage behind it (see `caster` below, and Balance.growthClassFor, which
-- makes the same distinction for the same reason); netting a fighter's slash turn off that would bill
-- a spell for a swing it never had, and every spell in the game read as a bargain against it.
function Grade.turnValue(magical)
    local key = magical and "turnMagic" or "turnPhys"
    if cache[key] then return cache[key] end
    local ref = reference(magical)
    cache[key] = math.max(1, Combat.mitigatedDamage(ref.body, ref.budget, ref.tags))
    return cache[key]
end

-- Damage an item's raw output lands after the reference body's armour, so a blow is priced through
-- Combat.mitigatedDamage rather than beside it (docs/balance.md's rule, and the reason a resist-tagged
-- weapon does not read the same as an untagged one of equal power).
local function landed(raw, tags)
    if (raw or 0) <= 0 then return 0 end
    local ref = reference(false)
    return Combat.mitigatedDamage(ref.body, raw, tags or ref.tags)
end

-- A table of stat deltas, in damage-equivalent PER TURN. The one owner of that arithmetic, so a status
-- and an item bonus can never price the same +5 Defense two different ways.
--
-- SUMMED SIGNED, then made positive. Reckless is `damage +12, defense -10, magicDefense -10`: one
-- status that BUYS power with guard, and valuing each entry's magnitude separately scored all three as
-- upside and made a slot-3 stance the strongest item in the game. Netting them is what it actually is;
-- the absolute at the end is because the sign only says who WANTS it -- a pure malus is worth its
-- weight to whoever inflicts it exactly as a pure boon is to whoever wears it.
--
-- CAPPED AT A TURN, and that is the other half. Mitigation in this game is SUBTRACTIVE and floors at 1
-- (Combat.mitigatedDamage), so a point of guard stops a point of damage right up until there is no
-- damage left to stop -- after which it stops nothing. Valuing it linearly said Hollowed's `defense =
-- 40` was worth 36 damage a turn, four times what the reference blow even carries, and floated a quest
-- weapon to 141 -- five times anything on a shelf. Nothing can prevent, or add, more than a turn's
-- worth of damage in a turn.
function Grade.statSwing(bonus)
    local net = 0
    for stat, amount in pairs(bonus or {}) do
        if type(amount) == "number" then
            net = net + amount * (Grade.STAT_VALUE[stat] or 0.4)
        end
    end
    return math.min(math.abs(net), Grade.turnValue())
end

-- ---------------------------------------------------------------------------
-- Statuses
-- ---------------------------------------------------------------------------

local TICKS = 5 -- Status.TICKS_PER_TURN, read below; held here so a nil Status cannot break the math

-- How many turns a status covers. `duration` is authored in ticks throughout data/status.
local function statusTurns(def)
    local ticks = tonumber(def.duration) or 0
    local perTurn = (Status and Status.TICKS_PER_TURN) or TICKS
    -- Capped: see Grade.STATUS_MAX_TURNS. An `inf`/999 duration (a boss's standing rage) would
    -- otherwise multiply straight to infinity and take the whole ranking with it.
    return math.max(0, math.min(Grade.STATUS_MAX_TURNS, ticks / math.max(1, perTurn)))
end

-- What one application of `id` is worth, in damage-equivalent. Positive whichever side it lands on:
-- a debuff on a foe and a buff on an ally both buy you the same thing.
--
-- Every branch reads a field the status blueprint already authors, so this is a translation of
-- models/status.lua's contract into the grade's unit -- not a second opinion about what a status is.
function Grade.statusValue(id)
    local def = Status.defs[id]
    if not def then return 0 end
    local turn = Grade.turnValue()
    local turns = statusTurns(def)

    -- An authored judgement wins outright, and is the whole answer rather than a bonus on top of the
    -- derivation -- these are the statuses the derivation cannot see, so there is nothing to add it to.
    -- The blueprint's own `grade` beats the table here, so a status can carry its number beside its
    -- behaviour if an author prefers that.
    local authored = tonumber(def.grade) or Grade.STATUS_GRADE[id]
    if authored then return authored * turn end

    local value = 0

    -- Disables and their kin: a share of every turn they cover.
    for field, weight in pairs(Grade.STATUS_TURNS) do
        if def[field] then
            local span = Grade.STATUS_ONESHOT[field] and 1 or math.max(1, turns)
            value = value + weight * span * turn
        end
    end

    -- An initiative shove is a one-shot delay, and it is authored in ticks: it buys exactly the
    -- fraction of a turn it pushes the target down the order.
    if def.shovesInitiative then
        local ticks = def.shovesInitiative == "magnitude" and (tonumber(def.magnitude) or 0)
            or (tonumber(def.shovesInitiative) or 0)
        value = value + (ticks / math.max(1, (Status and Status.TICKS_PER_TURN) or TICKS)) * turn
    end

    -- Damage (or healing) on the clock. `magnitude` on a ticking status is quoted PER TURN -- see the
    -- header of data/status/status_burn.lua -- so it multiplies straight by the turns it runs.
    if def.onTick and def.magnitude then
        value = value + math.abs(tonumber(def.magnitude) or 0) * math.max(1, turns)
    end

    -- Stat swings, for their whole duration.
    --
    -- SUMMED SIGNED, then made positive -- not each stat absolute-valued on its own. Reckless is
    -- `damage +12, defense -10, magicDefense -10`: one status that BUYS power with guard, and taking
    -- each entry's magnitude separately scored all three as upside and made a slot-3 stance the single
    -- strongest item in the game. Netting them is what the status actually is. The absolute at the end
    -- is because the sign only says who wants it -- a pure malus is worth its weight to whoever
    -- inflicts it, exactly as a pure boon is worth its weight to whoever wears it.
    if def.statBonus then
        value = value + Grade.statSwing(def.statBonus) * math.max(1, turns)
    end

    -- A vulnerability is a FLAT pre-mitigation bonus to hits carrying one tag, not a multiplier --
    -- `vulnerable = { slash = 8 }` means eight more damage per slashing blow (Combat.mitigatedDamage
    -- folds it in). Reading it as a multiplier priced Vulnerable: Slash at eight turns and made Rend
    -- the best ability in the game.
    --
    -- Only the BEST tag counts: the entries are alternatives, and a party does not carry two damage
    -- types into the same window. Scaled by the hits that actually land inside it, and discounted
    -- because the window is worth nothing at all unless the party's loadout matches the tag -- which
    -- is the whole design of the family (docs/vulnerability.md).
    if type(def.vulnerable) == "table" then
        local best = 0
        for _, amount in pairs(def.vulnerable) do
            best = math.max(best, math.abs(tonumber(amount) or 0))
        end
        local hits = math.min(Grade.VULNERABLE_MAX_HITS, math.max(1, turns))
        value = value + best * hits * Grade.VULNERABLE_TAG_MATCH
    end

    -- Immunity is the WHOLE blow, and it has to be priced in the same unit the resistance above is.
    -- A `vulnerable` bag is worth the damage points it subtracts (8); an immunity subtracts all of
    -- them, so its per-hit worth is the reference blow itself -- Grade.turnValue, which is exactly
    -- "what one blow lands after mitigation". Quoting it instead as a hardcoded 0.45 of a turn priced
    -- a voided hit at half a partial one and stood the ward line on its head: every Immunity: <Type>
    -- graded BELOW the Resistant: <Type> it is meant to sit four quests deeper than.
    --
    -- Scaled by landing hits and discounted the same way a resistance is, for the same reason: an
    -- immunity that names tags is worth nothing at all unless the blow coming in carries one.
    if type(def.immune) == "table" and next(def.immune) then
        local hits = math.min(Grade.VULNERABLE_MAX_HITS, math.max(1, turns))
        value = value + turn * hits * Grade.VULNERABLE_TAG_MATCH
    end

    -- Negation is a different shape and keeps its own read: `negates` is a CHARGE bag -- `magnitude`
    -- blows eaten and then gone (status_physical_barrier) -- so what it is worth is a count, not a
    -- window, and the duration it is quoted against here is the wrong axis. Left as it was rather
    -- than corrected in passing, so the six barriers do not move on a change that is about the wards.
    if def.negates then
        value = value + 0.45 * math.max(1, turns) * turn
    end

    -- Capped, see Grade.STATUS_VALUE_CAP: the components above are additive and a status that sets
    -- four of them summed past two turns off one cast.
    return math.min(value, Grade.STATUS_VALUE_CAP * turn)
end

-- ---------------------------------------------------------------------------
-- Traits
-- ---------------------------------------------------------------------------

-- What a trait is worth per fight, in damage-equivalent, plus whether the number was AUTHORED.
--
-- A trait is a hook function, so nothing here can read what it does -- the honest options were an
-- authored weight or a guess, and this returns both so a caller can tell them apart. `grade` on the
-- blueprint is the authored one, in turns per fight; everything else is shaped off the hook it hangs
-- on and its cooldown, and is explicitly a placeholder.
function Grade.traitValue(id)
    local def = Trait.defs[id]
    if not def then return 0, false end
    local turn = Grade.turnValue()

    -- A judgement wins outright over any shape estimate: the blueprint's own `grade` first, so a trait
    -- can carry its number beside its behaviour, then the authored table above.
    local authored = tonumber(def.grade) or Grade.TRAIT_GRADE[id]
    if authored then return authored * turn, true end

    local turns = nil
    for hook, weight in pairs(Grade.TRAIT_DEFAULT_TURNS) do
        if hook ~= "default" and def[hook] then
            turns = math.max(turns or 0, weight)
        end
    end
    turns = turns or Grade.TRAIT_DEFAULT_TURNS.default

    -- A cooldown caps the payouts: ticks between triggers against the reference fight's length.
    if tonumber(def.cooldown) then
        local perTurn = (Status and Status.TICKS_PER_TURN) or TICKS
        local triggers = (Grade.FIGHT_TURNS * perTurn) / math.max(1, def.cooldown)
        turns = turns * math.max(Grade.TRAIT_COOLDOWN_FLOOR,
            math.min(1, triggers / Grade.FIGHT_TURNS))
    end

    -- A trait that names its own magnitude scales with it, against a nominal 1.
    if tonumber(def.magnitude) then
        turns = turns * math.max(0.5, math.min(2, math.abs(def.magnitude) / 4))
    end

    return turns * turn, false
end

-- ---------------------------------------------------------------------------
-- The grade
-- ---------------------------------------------------------------------------

-- Bodies an area footprint catches, off the small closed set of shapes data/items actually uses.
local function expectedBodies(ab)
    local aoe = ab and ab.aoe
    if not aoe then return Grade.EXPECTED_BODIES[1] end
    local radius = tonumber(aoe.radius) or 0
    local length = tonumber(aoe.length) or 0
    local width = tonumber(aoe.width) or 0
    if radius >= 2 or length >= 3 then return Grade.EXPECTED_BODIES.large end
    if radius >= 1 or length >= 2 or width >= 3 then return Grade.EXPECTED_BODIES.small end
    return Grade.EXPECTED_BODIES[1]
end

-- The wielder the dry run casts as: the reference body grown to Grade.PRESTIGE, so an item's damage
-- carries the same attack stat every other item's does and the difference between two grades is the
-- ITEMS. Deliberately NOT Balance.wielderStatFor, which reads `unlockQuests`.
local function caster(magical)
    local key = magical and "casterMagic" or "casterPhys"
    if cache[key] then return cache[key] end
    local char = Balance.refChar(Grade.PRESTIGE, magical and "mage" or nil)
    cache[key] = { char = char, x = 0, y = 0, alive = true, side = "party",
        initiative = 0, statuses = {}, bonus = {}, resist = {} }
    return cache[key]
end

local function isMagical(def)
    for _, t in ipairs(def.tags or {}) do
        if t == "magical" then return true end
    end
    return false
end

-- What ACTIVE use of the item puts on the board, in damage-equivalent, before the turn it costs is
-- netted off. Runs the real effect through Combat.abilityOutput -- the inventory tooltip's inert
-- replay -- so AoE, carried statuses, placed ground and summons are all reported by the game itself.
local function activeValue(def, item, rows)
    local ab = item and item.activeAbility
    if not ab or not ab.effect then return 0 end

    local magical = isMagical(def)

    -- THE ITEM'S OWN MAGNITUDE IS OVERWRITTEN BEFORE THE DRY RUN, and this is the line that keeps the
    -- grade honest. Since the slot became the grade, every item on a rung SHARES a magnitude -- so an
    -- item's damage number says which rung it is on and nothing whatever about the item. Reading it
    -- closed the loop: grade set the slot, the slot granted the magnitude, and the magnitude fed the
    -- next grade. It converged only because it was damped, which is not the same as being right.
    --
    -- So the blow is normalized to the FAMILY BASE's own unforged power (Balance.slotAnchors, pinned at
    -- slot 0) before the effect is replayed. Two plain weapons of a family then grade identically,
    -- which is exactly the design's claim: "two items sharing a slot share a magnitude -- the effect is
    -- the whole of what distinguishes them." What survives the normalization is everything that is
    -- really the ITEM: how many bodies the blow reaches, what it inflicts, what it leaves behind, what
    -- it multiplies itself by (Omnislash's per-weapon stacking, the Hornbow's distance scaling), and
    -- what it costs in tempo.
    local fam = Balance.familyOf(def)
    local anchor = fam and Balance.slotAnchors()[fam]
    if anchor and type(ab.damage) == "number" then ab.damage = anchor.base end

    local out = Combat.abilityOutput(caster(magical), item)
    if not out then return 0 end

    -- TWO TURNS, on purpose. Effects are valued in the CANONICAL turn (the physical one) so a stun is
    -- worth the same wherever it is bought and the grades stay one currency. The margin below nets off
    -- the caster's OWN turn, because the opportunity cost of casting is whatever that body would
    -- otherwise have done -- and for a mage that is a spell, not a sword.
    local turn = Grade.turnValue(false)
    local ownTurn = Grade.turnValue(magical)
    local bodies = expectedBodies(ab)
    local total = 0

    -- A DRY RUN CAN MISS THE BLOW. The replay has no board, so an effect that picks its victims off
    -- the map -- Meteor Storm walking random cells through fx.unitAt, which answers only the one
    -- stand-in cell -- finds nobody and reports zero damage, and the item grades as if it were a
    -- flavour text. Fall back to the ability's own authored magnitude, plus the wielder's stat, which
    -- is exactly what the blow would carry if any of those cells had held a body.
    local raw = out.damage
    if (raw or 0) <= 0 and type(ab.damage) == "number" and ab.damage > 0 then
        local stats = caster(magical).char.stats
        raw = ab.damage + ((magical and stats.magicDamage or stats.damage) or 0)
    end

    -- ...and the ordinary blow nets itself off, because THE MARGIN BELOW ALREADY IS THE PLAIN BLOW.
    -- `ownTurn` is what the reference loadout lands in one turn, which is exactly what a normalized
    -- single-target swing now delivers -- so a plain weapon scores its blow, pays a turn for it, and
    -- comes out at nothing. No second subtraction: netting the baseline off here as well would bill
    -- the same swing twice and put every plain item deep in the negative.
    local dmg = landed(raw, def.tags) * bodies
    if dmg > 0 then rows[#rows + 1] = { "damage", dmg }; total = total + dmg end

    local heal = (out.heal or 0) * bodies
    if heal > 0 then rows[#rows + 1] = { "heal", heal }; total = total + heal end

    for _, entry in ipairs(out.statuses or {}) do
        local v = Grade.statusValue(entry.id) * bodies
        if v > 0 then rows[#rows + 1] = { "status:" .. entry.id, v }; total = total + v end
    end

    -- Things left standing on the board when the cast is over.
    if out.summon then
        local turns = math.min(Grade.FIGHT_TURNS,
            (out.summonDuration or (Grade.FIGHT_TURNS * 5)) / 5)
        local v = Grade.PLACED_TURNS.summon * turns * turn
        rows[#rows + 1] = { "summon:" .. tostring(out.summon), v }; total = total + v
    end
    if out.hazard then
        local turns = math.min(Grade.FIGHT_TURNS, (out.hazardDuration or 15) / 5)
        local v = Grade.PLACED_TURNS.hazard * turns * turn
        rows[#rows + 1] = { "hazard:" .. tostring(out.hazard), v }; total = total + v
    end
    if out.trap then
        local v = Grade.PLACED_TURNS.trap * turn
        rows[#rows + 1] = { "trap:" .. tostring(out.trap), v }; total = total + v
    end
    if out.revives then
        local v = Grade.REVIVE_TURNS * turn
        rows[#rows + 1] = { "revives a fallen ally", v }; total = total + v
    end

    -- Pools moved, and tempo bought.
    local pool = ((out.restore or 0) + (out.drain or 0)) * Grade.POOL_POINT
    if pool > 0 then rows[#rows + 1] = { "pool restored", pool }; total = total + pool end
    if (out.hasten or 0) > 0 then
        local v = (out.hasten / 5) * Grade.HASTEN_PER_TICK * turn
        rows[#rows + 1] = { "hastened", v }; total = total + v
    end

    -- Board verbs the dry run flags rather than measures.
    local verbs = {
        { out.extraActions, "extraAction", "extra action" },
        { out.knockback, "knockback", "knockback" },
        { out.charge, "charge", "charge" },
        { out.pull and 1 or nil, "pull", "pull" },
        { out.steal and 1 or nil, "steal", "steal" },
        { out.reveal and 1 or nil, "reveal", "reveal" },
        { out.cleanse and 1 or nil, "cleanse", "cleanse" },
        { out.dismiss and 1 or nil, "dismiss", "dismiss" },
        { out.transform and 1 or nil, "transform", "transform:" .. tostring(out.transform) },
        { out.prop and 1 or nil, "prop", "prop:" .. tostring(out.prop) },
        { out.grants and 1 or nil, "grants", "grants:" .. tostring(out.grants) },
        { out.wall and 1 or nil, "wall", "wall" },
        { out.swap and 1 or nil, "swap", "swap" },
        { out.teleport and 1 or nil, "teleport", "teleport" },
        { out.recall and 1 or nil, "recall", "recall" },
    }
    for _, v in ipairs(verbs) do
        local n, key, label = v[1], v[2], v[3]
        if n and n > 0 then
            local val = Grade.VERB_TURNS[key] * n * turn
            rows[#rows + 1] = { label, val }; total = total + val
        end
    end

    -- The blood it drinks back. A keyword folded into Combat.dealDamage, never an fx call, so the dry
    -- run cannot report it -- read off the ability and priced against what the blow actually landed.
    if tonumber(ab.lifesteal) and ab.lifesteal > 0 then
        local v = landed(raw, def.tags) * bodies * ab.lifesteal * Grade.LIFESTEAL_VALUE
        rows[#rows + 1] = { "lifesteal", v }; total = total + v
    end

    -- Tempo: how far this swing sits from an ordinary one on the clock.
    local speed = tonumber(ab.speed)
    if speed and speed ~= Grade.REFERENCE_SPEED then
        local v = (Grade.REFERENCE_SPEED - speed) * Grade.TICK_VALUE * turn
        rows[#rows + 1] = { "tempo", v }; total = total + v
    end

    -- THE MARGIN. Spending the action means not swinging, so an ordinary cast is worth what it beats
    -- the reference swing by. An ability that keeps the turn (`free`) hands that turn back.
    if ab.free then
        local v = Grade.FREE_ACTION_TURNS * ownTurn
        rows[#rows + 1] = { "free action", v }
        total = total + v
    else
        rows[#rows + 1] = { "less the turn spent", -ownTurn }
        total = total - ownTurn
    end

    -- A hold is paid before anything lands.
    local windup = tonumber(ab.windup)
    if windup and windup > 0 then
        local held = windup / 5
        total = total * math.max(0.4, 1 - Grade.WINDUP_TURN_DISCOUNT * held)
    end

    -- ...and what it costs to throw at all. A discount on the whole rather than a subtraction, because
    -- a price limits how OFTEN the thing happens rather than how much it does when it does.
    local outlay = ab.cost and tonumber(ab.cost.amount)
    if outlay and outlay > 0 and total > 0 then
        local ratio = Grade.REFERENCE_COST / math.max(1, outlay)
        total = total * (1 + Grade.COST_SWING * (math.min(2, ratio) - 1))
    end

    return total
end

-- What the item is worth WITHOUT being used: everything it does for standing in the grid.
--
-- PER TURN, like everything else. This is the half that has to be got right or the whole ranking tilts,
-- and the first cut got it wrong: it multiplied every passive by Grade.FIGHT_TURNS, valuing a charm
-- over a whole fight while an ability was valued over the one turn it is cast on. That is an eightfold
-- thumb on the scale, and it showed -- plain armour graded above capstone weapons, and the audit came
-- back saying the late shelf's passives were the strongest things in the game. Which is the exact
-- opposite of the complaint that started this, and a good sign the units were the bug rather than the
-- shelf.
--
-- So a stat bonus is worth what it is worth ON A TURN, and an authored trait or tag weight -- which is
-- naturally quoted per FIGHT, because that is how a designer thinks about a reaction that fires a few
-- times -- is divided down to the turn. One unit, one scale, one ranking.
--
-- Reads the INSTANTIATED item, not the blueprint. A blueprint's `bonus` and `resist` hold unresolved
-- Curve tables (`defense = Curve.ramp(4, 14)`); Item.instantiate is what collapses those to the number
-- for a level, and grading the raw table is both meaningless and a crash.
local function passiveValue(def, rows, item)
    local src = item or def
    local turn = Grade.turnValue()
    local total, estimated = 0, false

    if src.bonus then
        local v = Grade.statSwing(src.bonus)
        if v ~= 0 then
            rows[#rows + 1] = { "stat bonus", v }; total = total + v
        end
    end

    -- Authored per fight (see Grade.traitValue), spent per turn.
    for _, id in ipairs(def.traits or {}) do
        local v, authored = Grade.traitValue(id)
        if not authored then estimated = true end
        v = v / Grade.FIGHT_TURNS
        rows[#rows + 1] = { (authored and "trait:" or "trait?:") .. id, v }
        total = total + v
    end

    -- Resists are SUMMED, not picked. Combat.mitigatedDamage adds every resist matching any tag on the
    -- blow (docs/balance.md's ARMOR_SHARE note is entirely about this), so an iron plate's
    -- `physical 4, slash 4` takes EIGHT off a sword, not four. Reading the single worst entry priced
    -- every layered coat at half what it does, sank the whole armour type to the bottom of its shelf,
    -- and then trapped it there: a low slot means a low armour cap, which means the rescale cuts the
    -- coat's defense, which lowers its grade again. armor_iron_plate rode that spiral down to zero
    -- defense at 260 gold.
    --
    -- Measured per PROBE, the way Balance.mitigation measures a body: sum the entries a given blow
    -- would match, and take the best of those totals -- the answer to "how much does this stop from the
    -- thing it is meant to stop".
    if src.resist then
        local best = 0
        for _, name in ipairs(Balance.PROBE_ORDER) do
            local sum = 0
            for _, tag in ipairs(Balance.probe(name).tags) do
                local r = src.resist[tag]
                if type(r) == "number" then sum = sum + math.abs(r) end
            end
            best = math.max(best, sum)
        end
        if best > 0 then
            local v = best * Grade.STAT_VALUE.defense
            rows[#rows + 1] = { "resist", v }; total = total + v
        end
    end

    -- Ground that walks with the bearer, and its cousins: a hazard the wearer never spends an action
    -- on, so it is worth a hazard's per-turn value every turn, for free.
    for field, label in pairs({ incense = "incense", trail = "trail", aura = "aura" }) do
        if def[field] then
            local v = Grade.PLACED_TURNS.hazard * turn
            rows[#rows + 1] = { label, v }; total = total + v
        end
    end

    -- Mechanics conferred by a bare tag (see Grade.TAG_TURNS): the only rules an item can carry with
    -- no field at all to read. Authored per fight, like a trait.
    for _, tag in ipairs(src.tags or {}) do
        local turns = Grade.TAG_TURNS[tag]
        if turns then
            local v = (turns / Grade.FIGHT_TURNS) * turn
            rows[#rows + 1] = { "tag:" .. tag, v }; total = total + v
        end
    end

    -- The remaining passive fields, each quoted per fight and spent per turn, like a trait.
    local perFight = {
        { def.moveBehavior, 1.4, "move behavior" },   -- phasing, blinking: a movement rule of its own
        { def.terrainEase, 0.6, "terrain ease" },
        { def.statusImmunity, 1.6, "status immunity" },
        { def.manaShield, 1.4, "mana shield" },
    }
    for _, row in ipairs(perFight) do
        if row[1] then
            local v = (row[2] / Grade.FIGHT_TURNS) * turn
            rows[#rows + 1] = { row[3], v }; total = total + v
        end
    end

    -- A wait behavior replaces the turn you spend waiting with one that does something (Overwatch
    -- shooting whatever walks in). That is a turn re-earned, on the turns you use it -- per turn
    -- already, so it is not divided down.
    if def.waitBehavior then
        local v = Grade.VERB_TURNS.extraAction * turn * 0.5
        rows[#rows + 1] = { "wait behavior", v }; total = total + v
    end

    return total, estimated
end

-- THE GRADE. Returns `value, breakdown`, where breakdown is
-- { rows = { { label, value } ... }, estimated = bool, active = n, passive = n }.
--
-- `estimated` says the number leans on at least one un-authored trait weight, so a report can mark it
-- rather than presenting a placeholder as a measurement.
function Grade.of(idOrDef)
    local id, def = idOrDef, idOrDef
    if type(idOrDef) == "string" then def = Item.defs[idOrDef] else id = nil end
    if not def then return nil end

    local rows = {}
    local item = id and Item.instantiate(id, 1, 0) or nil
    local active = item and activeValue(def, item, rows) or 0
    local passive, estimated = passiveValue(def, rows, item)
    local total = active + passive

    -- A two-handed weapon costs the grid cell a second item would have filled.
    if (tonumber(def.hands) or 1) >= 2 then
        total = total * Grade.TWO_HANDED_DISCOUNT
        rows[#rows + 1] = { "two-handed", -(total / Grade.TWO_HANDED_DISCOUNT - total) }
    end

    -- BLIND, not weak. If nothing but the turn's own cost landed in the breakdown, the dry run saw
    -- nothing -- and for a handful of items that is the truth about the RUN, not about the item.
    -- Detonator needs a charge already planted, Dual Wield needs weapons beside it in the grid, the
    -- coin abilities need a purse: all of them are board state a boardless replay cannot have. Saying
    -- so is the difference between "this item is worth nothing" and "this instrument cannot see it",
    -- and only the second one is true. A caller ranks these last or sets them aside; it must not read
    -- the number as a judgement.
    local positive = false
    for _, row in ipairs(rows) do
        if row[2] > 0 then positive = true break end
    end

    return total, { rows = rows, estimated = estimated, active = active, passive = passive,
        blind = (not positive) and (item ~= nil) and (item.activeAbility ~= nil) or false }
end

-- ---------------------------------------------------------------------------
-- Price: the last link in the chain
-- ---------------------------------------------------------------------------
--
-- grade -> slot -> price, one direction only. Price used to be the INPUT to the shelf ordering, which
-- is how the ladder ended up sorted by item category (a consumable is cheap for being one-shot, a
-- passive dear for being permanent), and it is now the output: what a rung costs is a property of the
-- rung, not of the thing standing on it.
--
-- So every item on a slot costs the same, and the only thing that varies it is being SPENT. A
-- consumable is one use and then gone, and pricing it level with a weapon you keep would make it a
-- purchase nobody sensible makes -- which is the one true thing the old price scale was saying.
-- Deliberately NOT scaled by the finer grade: two items on a rung are meant to be a choice between
-- effects, and a price that separated them would put a thumb on that scale.
-- SLOTS THE GRADE MAY NOT DECIDE, each with the contract that fixed it and a spec that already
-- enforces it. A power ranking knows what an item is worth; it does not know that the general store
-- was dissolved and its wares promised to stay un-gated, or that a discipline's gate was chosen to sit
-- between the half of its kit that earns and the half that spends. Those are authored decisions, and a
-- ranking that quietly overruled them would break a test whose name explains exactly why it exists.
--
-- Named one by one with reasons rather than inferred, for the same reason Balance.MAGNITUDE_WAIVERS is:
-- a heuristic that swept these up would also sweep up things nobody decided, and the next author would
-- have no way to tell the two apart. The twelve family base weapons are NOT here -- they are read off
-- Balance.FAMILY_BASE by the tool, so the pin list and the magnitude ladder cannot name different ones.
--
--   at   the exact slot it must unlock from
--   min  the earliest it may unlock from
--   max  the latest
Grade.SLOT_PINS = {
    -- The five wares that were classless while the Cafe was a general store. Each went home to the
    -- house that wanted it, and each kept its opening-shelf place, because being there from the first
    -- visit was the one thing the general store was really providing (tests/progression_spec.lua).
    utility_torch = { at = 0, why = "a rehomed general good: un-gated since the Cafe closed its shelf" },
    utility_boots_of_speed = { at = 0, why = "a rehomed general good" },
    utility_stormglass_rod = { at = 0, why = "a rehomed general good" },
    consumable_witchlight_flare = { at = 0, why = "a rehomed general good" },
    consumable_wellspring_sandals = { at = 0, why = "a rehomed general good" },
    -- The resale rack is gone, so exactly one shelf sells the commonest thing in the game, and it sells
    -- it from the first visit.
    consumable_healing_potion = { at = 0, why = "the Crucible's steadiest seller, and nowhere else now" },

    -- THE PROLOGUE'S TEACHING SPELL. The first working the player ever casts, and the lesson's closing
    -- beat is built on its exact weight -- data/characters/character_demon_grunt.lua's health is "the
    -- SUM of five authored blows" and this is one of them.
    --
    -- Jolt used to be pinned here, and that was the wrong fix. The grade kept sending Jolt up the shelf
    -- and it was RIGHT to: a stun on a bolt is a large thing to carry, and holding it at slot 0 to
    -- protect a script meant one item was answering to two masters. Splitting it was the answer --
    -- ability_minor_shock carries the lesson's numbers, Jolt is graded for what it does -- and this pin
    -- now holds the spell that actually has a script to protect.
    ability_minor_shock = { at = 0, why = "the prologue's teaching spell: the lesson is tuned to its weight" },

    -- PLACED BY HAND, because the grader is honest about not being able to see them. Both are blind to
    -- the dry run -- Collapse drags whatever is within four tiles and Understudy repeats whatever your
    -- side last did, so a replay with no board finds nothing to drag and nothing to repeat, and their
    -- grades describe the instrument rather than the item. Neither carries a discipline, so neither is
    -- held above the discipline floor by anything; slot 3 is the author's call about where two
    -- board-reading abilities belong on a shelf.
    --
    -- The other ten items the dry run cannot see all carry a discipline and were judged to be sitting
    -- correctly already, so they keep their slots and stay out of the spread.
    ability_collapse = { at = 3, why = "blind to the dry run: placed by hand" },
    ability_understudy = { at = 3, why = "blind to the dry run: placed by hand" },

    -- PLACED BY HAND against the grade rather than around a blind spot. The dry run reads the Muster
    -- Rift perfectly well -- the teleport scores +5.0 -- and still nets it to -4.0, because everything
    -- it does is spent on the turn it costs, and the unit here is damage. What the ruler cannot price
    -- is WHAT is moved: a whole side, any distance, which is a verb nothing else in the game has. A
    -- party split by terrain or strung out by a chase is a party losing, and this un-loses it in one
    -- action. That is not opening-rack stock at 80 gold, whatever it grades.
    ability_muster_rift = { at = 8, why = "board-scale repositioning: not a verb the opening rack sells" },

    -- PLACED BY HAND for a different reason: the grade can see this one perfectly well now. Polymorph
    -- read at half a turn until status_polymorph carried an authored weight (the pig's emptiness is not
    -- a field), and on merit it ranks a rung below this. The last rung is the author's, and the thing it
    -- is protecting is not power but reach: taking a body out of the fight outright, deterministically,
    -- with no roll to survive, is not a verb the Arcanum hands over in its first half.
    ability_polymorph = { at = 6, why = "removing a body outright is not opened in the line's first half" },

    -- HEAVY ARMOUR NEEDS A DEEP ENOUGH RUNG TO BE LEGAL ON. Balance.ARMOR_SHARE caps one piece at 40%
    -- of the attack budget AT ITS OWN SLOT, and the iron plate's resist bag (physical 4, slash 4,
    -- pierce 4) already takes 8 off a sword before its defense is counted at all -- more than the whole
    -- cap allows on an early rung. Graded on protection alone it ranks low, lands early, and the rescale
    -- then cuts its defense to fit the cap it cannot fit: it rode that spiral down to 0 defense at 260
    -- gold, which is an item that costs money to be worse than nothing.
    --
    -- The floor is the armour's own protection deciding where it may sit, not a correction to the
    -- grade. Its authored slot is where its bag is legal.
    armor_iron_plate = { min = 7, why = "its resist bag is only legal at the cap from this rung up" },

    -- The Mammonite gate sits at slot 6 BETWEEN the halves of its kit: the earners are already on sale
    -- when the discipline unlocks, and the spenders are Aurea's own art, still two tiers off. Pinned as
    -- an ordering rather than as literal numbers, exactly as tests/purse_spec.lua asserts it.
    ability_ledgers_due = { max = 5, why = "a Mammonite earner: buyable by the time the gate clears" },
    ability_price_on_the_head = { max = 5, why = "a Mammonite earner" },
    ability_blood_money = { min = 6, why = "spends the purse: Aurea's art, and it waits for her" },
    ability_gilded_wound = { min = 6, why = "spends the purse" },
    ability_grease_palms = { min = 6, why = "spends the purse" },
    ability_open_account = { min = 6, why = "spends the purse" },

    -- THE WARD LINE IS PLACED, NOT RANKED -- both halves, at 3 and at 9, across all seven houses.
    --
    -- This is the hand-placed row of the table above and it carries that row's burden of proof, so:
    -- the grade reads this family perfectly well and reads it LOW, because both halves score as a turn
    -- spent to prevent less than a swing (-4.9 and -2.0 against the reference body). That reading is
    -- honest about the average turn and wrong about the family, which does not exist for the average
    -- turn. A ward is bought for the one telegraphed blow the fight actually turns on, and a dry run
    -- against a reference body has no telegraph in it -- the whole of what you are paying for is
    -- invisible to the instrument. Left to the ranking the line pooled at slot 0, which prices refusing
    -- a dragon's breath as opening-rack stock.
    --
    -- The two rungs are the family's shape rather than two numbers: a house teaches you to take the
    -- blow (3) long before it teaches you to refuse it (9), and voiding a blow outright is late-line
    -- power in the same way ability_polymorph's reach is. Every house reaches slot 10, so 9 is a real
    -- rung on all seven shelves and not a clamp.
    --
    -- tests/vulnerability_spec.lua asserts the ordering; these pins are what hold it.
    ability_ward_fire = { at = 3, why = "the ward line is placed at 3: taught before it is refused" },
    ability_ward_ice = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_lightning = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_water = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_dark = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_holy = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_acid = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_poison = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_slash = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_impact = { at = 3, why = "the ward line is placed at 3" },
    ability_ward_pierce = { at = 3, why = "the ward line is placed at 3" },

    ability_seal_fire = { at = 9, why = "voiding a blow outright is late-line power, not a graded row" },
    ability_seal_ice = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_lightning = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_water = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_dark = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_holy = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_acid = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_poison = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_slash = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_impact = { at = 9, why = "the seal line is placed at 9" },
    ability_seal_pierce = { at = 9, why = "the seal line is placed at 9" },
}

Grade.PRICE_BASE = 80   -- what the opening rung costs
Grade.PRICE_STEP = 60   -- and what each rung adds
Grade.PRICE_TYPE = {
    consumable = 0.4,   -- one-shot: the discount, and the only one
}

-- The shelf price of an item unlocking at `slot`, before any forge level (Vendor.priceFor still
-- applies that on top). Rounded to the nearest five, because a shelf full of prices like 447 reads as
-- noise where 445 reads as a number somebody chose.
function Grade.priceFor(slot, itemType)
    local base = Grade.PRICE_BASE + Grade.PRICE_STEP * math.max(0, slot or 0)
    local scaled = base * (Grade.PRICE_TYPE[itemType] or 1)
    return math.max(5, math.floor(scaled / 5 + 0.5) * 5)
end

-- ---------------------------------------------------------------------------
-- Fitness: is it any use against what comes NEXT?
-- ---------------------------------------------------------------------------
--
-- Raw power is not the whole question. A shelf is a ladder a player climbs against a specific
-- opposition, so the thing you unlock at slot 1 has to be worth carrying into the slot 2 quest -- and
-- an item is worth nothing there, whatever it grades, if that quest fields bodies that wall its damage
-- type or shrug off the status it exists to apply.
--
-- WHY THIS IS NOT PART OF Grade.of, and the line is load-bearing. Fitness needs to know which quest
-- comes next, which means it needs a SLOT -- and a power grade that read a slot would be the exact
-- tautology this whole file exists to break. So the slot is a PARAMETER here, never a lookup: the raw
-- grade proposes a placement, and fitness scores that proposal. One pass, in that order, and the
-- report says so. Iterating the two to a fixed point is deliberately not done -- a ranking that feeds
-- its own input is how the last two attempts at this failed to converge (Balance.slotAnchors' header).
--
-- SPARSE BY DESIGN. Most slots have no quest authored yet. A slot with nothing to face returns nil --
-- no verdict rather than an invented one -- and the report leaves those items ranked on power alone.

-- What the house `class` puts on the board at `slot`: every body of the sponsor's quest that sits
-- there (Balance.sponsorDoneFor), grown to that quest's own prestige. Memoized per house and slot.
function Grade.opposition(class, slot)
    local key = "opp:" .. tostring(class) .. ":" .. tostring(slot)
    if cache[key] ~= nil then return cache[key] or nil end

    local Quest = require("models.quest")
    local sponsor = require("models.vendor").forClass(class)
    local bodies = {}
    if sponsor then
        for questId, def in pairs(Quest.defs) do
            if def.sponsor == sponsor and Balance.sponsorDoneFor(questId) == slot then
                for _, row in ipairs(Balance.bodiesFor(questId)) do
                    bodies[#bodies + 1] = { id = row.id, role = row.role,
                        prestige = Balance.prestigeFor(questId) }
                end
            end
        end
    end
    cache[key] = (#bodies > 0) and bodies or false
    return cache[key] or nil
end

-- How well `id` reads against the opposition one slot on, as a MULTIPLIER: 1.0 means it works exactly
-- as the generic reference says, below 1 means that fight answers it. Returns `ratio, notes` -- or nil
-- when there is no quest at slot+1 to measure against, which is most of them today.
--
-- Two questions, because they are the two ways an item is answered: is its damage type walled, and is
-- the status it exists to apply one those bodies simply ignore.
function Grade.fitness(id, class, slot)
    local def = Item.defs[id]
    if not def then return nil end
    local bodies = Grade.opposition(class, (slot or 0) + 1)
    if not bodies then return nil end

    local item = Item.instantiate(id, 1, 0)
    local ab = item and item.activeAbility
    if not ab or not ab.effect then return nil end
    local out = Combat.abilityOutput(caster(isMagical(def)), item)
    if not out then return nil end

    local notes = {}

    -- Does its blow land on these bodies the way it lands on the reference one?
    local damageRatio = 1
    if (out.damage or 0) > 0 then
        local ref = math.max(1, landed(out.damage, def.tags))
        local sum, n = 0, 0
        for _, body in ipairs(bodies) do
            local unit = Balance.unitFor(body.id,
                require("models.growth").levelForPrestige(body.prestige))
            sum = sum + Combat.mitigatedDamage(unit, out.damage, def.tags or {})
            n = n + 1
        end
        if n > 0 then
            damageRatio = (sum / n) / ref
            if damageRatio < 0.7 then
                notes[#notes + 1] = string.format("its damage type lands %d%% here", damageRatio * 100)
            end
        end
    end

    -- Is what it applies something these bodies are simply immune to?
    local statusRatio = 1
    local wanted = #(out.statuses or {})
    if wanted > 0 then
        local reachable, total = 0, 0
        for _, body in ipairs(bodies) do
            local unit = Balance.unitFor(body.id,
                require("models.growth").levelForPrestige(body.prestige))
            for _, entry in ipairs(out.statuses) do
                total = total + 1
                if not Status.isImmune(unit, entry.id) then reachable = reachable + 1 end
            end
        end
        if total > 0 then
            statusRatio = reachable / total
            if statusRatio < 0.7 then
                notes[#notes + 1] = string.format("%d%% of these bodies ignore what it applies",
                    (1 - statusRatio) * 100)
            end
        end
    end

    -- Weighted toward whichever half the item actually IS: a pure debuff is not saved by its damage
    -- landing, and a plain weapon is not condemned by a status it never applies.
    local ratio
    if (out.damage or 0) > 0 and wanted > 0 then
        ratio = damageRatio * 0.6 + statusRatio * 0.4
    elseif wanted > 0 then
        ratio = statusRatio
    else
        ratio = damageRatio
    end

    return math.max(0.1, math.min(1.4, ratio)), notes
end

-- Every item of a class, richest first. `opts.priced` limits it to the shelf; without it the 166
-- quest rewards are ranked alongside, which is the whole reason the grade refuses to read a price.
function Grade.rank(class, opts)
    opts = opts or {}
    local rows = {}
    for id, def in pairs(Item.defs) do
        local matches = (class == nil) or (def.class == class)
        if matches and (not opts.priced or def.price) then
            local value, breakdown = Grade.of(id)
            if value then
                rows[#rows + 1] = { id = id, def = def, value = value, breakdown = breakdown }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.id < b.id
    end)
    return rows
end

-- Drop every memoized reference. Peer of Balance.reset, and sits at the file foot for the reason that
-- one had to move there: above the locals it clears, the names resolve to globals and nothing is
-- actually dropped.
function Grade.reset()
    cache = {}
end

return Grade
