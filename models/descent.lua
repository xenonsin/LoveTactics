-- The Descent: a run is a stack of FLOORS with a landing between each, and the landing asks the only
-- question the overworld never used to -- go deeper, or take what you have and leave.
--
-- This module owns the run's SHAPE and nothing else. No love.graphics, no UI, no state switching, so it
-- loads and tests under the headless runner exactly as models/draft_run.lua does (which is the working
-- precedent for a persistent multi-stage run and is worth reading beside this).
--
-- WHY THIS IS SO SMALL. states/game.lua never consults Quest.defs -- it reads `quest.id`, `quest.map`,
-- `quest.sponsor`, `quest.opening/intro/outro/followUp`, `quest.floorLevel` and `quest.endsCampaign` and
-- nothing else. So a SYNTHESIZED floor descriptor is a legal quest, and the entire overworld / battle /
-- spoils / relic / deployment stack runs on one unchanged. Descent.floorQuest below is that descriptor; the
-- game state's whole share of this feature is a branch and a call.
--
--   local run = Descent.new(player)
--   State.switch(states.game, Descent.floorQuest(run), prestige, player)
--   -- ... floor clears -> the landing -> Descent.advance(run) -> floorQuest again, or Descent.extract
--
-- WHAT A RUN CARRIES, and the one rule about it: `run` is PLAIN DATA -- ids, numbers, booleans and flat
-- tables. It is serialized whole by models/save.lua, and Save.encode raises on a function value, so a
-- closure that finds its way in here does not fail gracefully, it takes the whole save write down with
-- it. The quest blueprints build `objective.composition` as a closure, which is exactly the sort of
-- thing that could drift in later -- so floorQuest BUILDS the descriptor fresh on every call and the run
-- never stores one. tests/descent_spec.lua pins the round trip.
--
-- STAGE 1 SCOPE. Floors are procedural and every floor ends in a `meet` stair. The sins, the shuffle and
-- the stair guardians land in later stages; the seams they need are marked below.

local Descent = {}

-- THE SEVEN CIRCLES. One per sin, and a sin is not decoration here -- it names the house whose stock
-- the floor pays into, the ground it is fought on, and what stands on the stair.
--
-- The vendor is the JOIN, and it is the reason this table is small. `data/vendors/*.lua` already
-- declares a `sin` and a `class`; states/game.lua already resolves `game.houseMaterial` from
-- `quest.sponsor` through `Vendor.get(...).class`. So a floor naming its vendor gets its material
-- tagging, its shelf and its standing for free, and this table only has to say which vendor is which
-- circle. tests/descent_spec.lua asserts the pairing against the vendor blueprints rather than
-- restating it, so a sin renamed in data cannot leave a stale copy here.
--
-- The BIOME is a reading of the sin rather than a lookup, so it is authored:
-- (Listed here in the order a first descent meets them -- Descent.INFERNO -- which is not the order
-- the table below is written in.)
--
--   lust      forest      overgrown, fertile, and hard to see out of
--   gluttony  swamp       a place that swallows what walks into it
--   greed     underworld  the vault below the vault
--   wrath     volcanic    the obvious one, and it has earned it
--   sloth     tundra      the post nobody came back to
--   envy      desert      barren ground with a view of somewhere green
--   pride     castle      a library that outlived every scholar who could read it
--
-- THE SIN ITSELF STANDS ON THE STAIR. Not a strong body of that house's cast -- the general who IS
-- that circle, by name, every time you walk it. Megaera is at the end of Tartarus on your first run
-- and your fortieth; that is the shape.
--
-- This replaced a generic guardian (a dire bear for Gluttony, an inquisitor for Lust) and the
-- difference is the whole reason a circle is worth recognising on a landing. "Below you: Wrath" means
-- nothing if what is down there is a champion and some barbarians. It means everything if it is Ira.
-- The seven are already written, named and statted -- Gula the Unsated, Ira the Unappeased, Luxuria
-- the Unbidden -- each with a kit that reads its own sin as tactics, and each was reachable exactly
-- once per save at the end of a quest line almost nobody finished.
--
-- The `filler` is their honour guard, drawn from the house's own cast and thickening with depth.
-- Named ids rather than an encounter blueprint because none of this is rollable content: there is
-- exactly one boss per circle and the circle chooses it, never a weight.
--
-- ORDERED, and the order here is only a canonical listing: what a run actually walks is Dante's, and
-- then its own once the Crown is broken (Descent.INFERNO, Descent.sinOrder). It is a list rather than a
-- registry because `pairs` is unspecified, and a run must lay out the same floors from the same seed on
-- any machine.
-- AND SHE SPEAKS, every run, on her own stair. `scene` is the conversation played over the guardian
-- fight (data/conversations/descent/), which is the only seam an antagonist has: an `intro` runs before
-- the party is even picked, and by the time an `outro` runs the fight is over.
--
-- Its own scene rather than the campaign's confrontation, and the reason is who is standing there. A
-- house's own confrontation is the end of a ten-quest line, forty lines long, written for the
-- companions the player recruited along it -- and a descent's company is one authored body plus
-- whoever it found on the floors, so those scenes would play the avatar's lines with no avatar present
-- and skip every companion block they are made of. These are one speaker, two or three lines, and no
-- reply. See the folder header for the rest of that argument.
-- A CIRCLE IS A STRATUM OF FLOORS, NOT A FLOOR (Descent.FLOORS_PER_CIRCLE). Every floor a sin owns is
-- fought on that sin's ground and pays into that sin's house, and the LAST of them is where she is
-- standing. The ones above it are held by `minor`.
--
-- THE MINOR BOSS IS THE GENERAL'S OWN HONOUR GUARD, promoted. `minor.lead` is exactly the body that
-- fills out `guardian` on her floor -- so the thing that held a stair against you two floors ago is
-- standing behind her when you finally reach her, and a player reads their own progress off it without
-- being told. It also means a fifteen-floor descent needed no new blueprints: every body here was
-- already authored and already belongs to this house.
Descent.SINS = {
    { id = "gluttony", name = "Gluttony", vendor = "hunters_lodge", biome = "swamp",
        scene = "conversation_descent_gluttony",
        -- THE MINOR LEAD WAS character_dire_bear, AND THAT WAS A BUG. The bear is a Wild Shape a hunter
        -- WEARS -- its pools are placeholders the hunter's own body carries across, so its blueprint
        -- reads `health = 1`. Fielded here as a floor's centrepiece it spawned with one health at level
        -- 1 and 57 at level 17, while swinging for 62: a body that died to a stiff breeze and hit like a
        -- general. A blueprint used as both cargo and combatant has to be SPLIT, so the druid's bear
        -- stays hers and this floor gets a body authored to stand on it (character_the_gralloch.lua).
        --
        -- The filler moved for the same reason. A guardian's escort should be the circle's own stock,
        -- which the swamp now has.
        -- ...and the lieutenant stands behind her, which is the invariant the mini sin was BUILT for:
        -- the body that barred the stair two floors ago is at her shoulder when you reach her, so the
        -- rule it taught you the slow way is standing next to the thing that has it in full.
        guardian = { lead = "character_general_gluttony", filler = "character_the_gralloch" },
        -- SHE WILL NOT RISE WHILE THERE IS ANYTHING LEFT TO EAT: the floor must be picked clean.
        gate = { kind = "clear" },
        minor = { lead = "character_the_gralloch", filler = "character_gorge_fly" } },
    { id = "lust", name = "Lust", vendor = "cathedral", biome = "forest",
        scene = "conversation_descent_lust",
        guardian = { lead = "character_general_lust", filler = "character_the_suppliant" },
        -- THE UNBIDDEN COMES WHEN SHE IS CALLED, and the Suppliant is who calls her -- so the ward is
        -- a body, standing at its own end of the floor. This is the TEACHING GATE: Lust is first in
        -- Dante's order, so it is the one a new company meets, and every other circle's is read
        -- against it. Beat her, the ward breaks, the stair opens.
        gate = { kind = "ward" },
        minor = { lead = "character_the_suppliant", filler = "character_petal_drift" } },
    { id = "greed", name = "Greed", vendor = "undercroft", biome = "underworld",
        scene = "conversation_descent_greed",
        guardian = { lead = "character_general_greed", filler = "character_the_tally" },
        -- PAY AT THE STAIR. Priced as a SHARE of what is on the mule rather than as a flat purse, so
        -- greed taxes exactly what the company came down for and a fat bag costs more to walk past --
        -- which couples the two systems this mode is built on instead of standing beside them.
        gate = { kind = "toll", share = 0.25 },
        minor = { lead = "character_the_tally", filler = "character_coin_chitter" } },
    { id = "envy", name = "Envy", vendor = "alchemist", biome = "desert",
        scene = "conversation_descent_envy",
        -- THE SECOND OF THE TWO BROKEN LEADS. character_homunculus is the alchemist's SUMMON -- its own
        -- header says it is "reached only through the Summon Homunculus ability, which scales it by the
        -- item's upgrade level" -- so fielded as a floor's centrepiece it stood there as tier-1 chaff
        -- with 18 health at level 1. And the filler was character_homunculus_discard, which is CARGO: a
        -- `protect` objective with a holdGround posture, whose own header spends a paragraph on why it
        -- must never be fielded as a combatant. Both replaced by the circle's own stock.
        guardian = { lead = "character_general_envy", filler = "character_second_water" },
        -- SHE DOES NOT COME OUT FOR A COMPANY WITH NOTHING. Envy wants what you have, so the gate is
        -- carrying something worth wanting -- which makes it the one gate a player can fail by having
        -- been sensible, and the one that rewards walking onto her floor rich.
        gate = { kind = "carry", n = 3 },
        minor = { lead = "character_second_water", filler = "character_glass_mote" } },
    { id = "wrath", name = "Wrath", vendor = "colosseum", biome = "volcanic",
        scene = "conversation_descent_wrath",
        -- The Champion held this slot and held it CORRECTLY -- a real body carrying a Demon Sigil with
        -- two authored phases, and the worked example in trait_boss_phases. It was still the wrong
        -- occupant: a stratum's centrepiece should BE the sin one rank down, not an arena fighter who
        -- happens to be nearby. It stays the authoring pattern; it stops standing in for Ira.
        guardian = { lead = "character_general_wrath", filler = "character_the_anvil" },
        -- UNAPPEASED UNTIL ENOUGH HAS BEEN SPILLED. A count of fights won on her floor, which is the
        -- gate a company clears by doing the thing it came to do -- so Wrath is the circle that asks
        -- for no detour, only for commitment.
        gate = { kind = "kills", n = 3 },
        minor = { lead = "character_the_anvil", filler = "character_cinder_kin" } },
    { id = "sloth", name = "Sloth", vendor = "bastion", biome = "tundra",
        scene = "conversation_descent_sloth",
        guardian = { lead = "character_general_sloth", filler = "character_the_late_watch" },
        -- NOTHING. SHE IS ASLEEP AND THE STAIR STANDS OPEN.
        --
        -- The only gate that is a pure reading of its own sin, and the one to protect in review: the
        -- post nobody came back to is guarded by nobody, so a company may simply walk past Acedia and
        -- go down. Fighting her is opt-in, and sealing her circle costs health and mule slots the run
        -- could have spent elsewhere -- which under an extraction descent is a real decision rather
        -- than a formality. Every other circle asks something; this one asks whether you want to.
        gate = { kind = "none" },
        minor = { lead = "character_the_late_watch", filler = "character_drift_thing" } },
    { id = "pride", name = "Pride", vendor = "arcanum", biome = "castle",
        scene = "conversation_descent_pride",
        guardian = { lead = "character_general_pride", filler = "character_marginalia" },
        -- SHE WILL NOT FIGHT BENEATH HERSELF. A count of circles already sealed, so Pride refuses a
        -- company that came straight down without proving anything -- the one gate satisfied by the RUN
        -- rather than by the floor, and the reason her circle reads as the end of a road even when the
        -- shuffle deals it early.
        gate = { kind = "worth", n = 3 },
        minor = { lead = "character_marginalia", filler = "character_gilded_sworn" } },
}

-- WHAT COMES OFF THE BODY: the unique piece a rank pays for being put down, per sin, in the order it is
-- handed over.
--
-- "KILL A SIN, WEAR IT" is not a new idea here; it is the authored one, and this table is the wiring it
-- never had. data/items/armor/armor_mail_of_the_unappeased.lua says it outright -- "the payment for a
-- general, and the shape every one of the seven relics takes" -- and five more of those relics have been
-- sitting in their generals' own grids the whole time, `noSteal`, unpriced, on nobody's shelf. What a
-- circle paid instead was a SHOP DOOR, which was a patch applied when the Quest Board was retired and
-- seven houses could no longer open; the door opens on an errand now (models/errand.lua) and the body
-- goes back to paying what it was carrying.
--
-- A LIST PER RANK, NOT AN ITEM, because a general must not hand over something the player already has.
-- Descent.dropFor walks it and pays the first piece not already owned, so a second playthrough is paid
-- in things that playthrough has not seen. The lists are short today and they are meant to grow: that is
-- the shape the run-again loop is built on rather than a placeholder.
--
-- WRATH PAYS THE MAIL, NOT THE HEART, and she is the pattern for every lieutenant here. Ira carries
-- `utility_unappeased_heart`, which is `bound` -- her fight rule, and unstealable so a rogue cannot lift
-- her whole fight off her mid-battle. What drops is a wearable sibling carrying the same trait.
--
-- EVERY LIEUTENANT NEEDED THAT TREATMENT. Their kit is tagged `natural`, which in this codebase means a
-- body part rather than equipment -- handing a player the Gralloch Hook hands them an organ. So each has
-- a wearable piece of its own, and each carries the FIRST-PHASE rule that body was built to teach
-- (data/items/utility/utility_anvils_face.lua and its six siblings).
--
-- WHICH MAKES A CIRCLE A TWO-PIECE SET, in the order the circle taught it. The whole tier is built on one
-- rule -- a mini sin's second phase is its general's first -- so the lieutenant's piece is the cut-down
-- version and the general's is the thing it was cutting down. The Anvil sharpens on every blow and stops;
-- Ira never stops. Wear both and the two terms compound exactly as they compounded on her. That is what
-- makes the second half of a circle worth walking to rather than a smaller copy of the first.
--
-- AN EMPTY LIST IS STILL A PAYOUT, and the field stays even though nothing is empty today: a list runs
-- out on a second playthrough, and Descent.dropFor then returns nil and the landing pays the house's
-- forge stock. That is the same path an unauthored piece would take, which is why adding to these lists
-- is safe and forgetting to is survivable.
-- AND THE LISTS GREW, exactly as the paragraph above said they were meant to. When the retired Quest
-- Board's 49 unpostable quests came out, sixty-four unpriced pieces came out with them: a house's
-- "quest-only shelf stock", handed over by a slot nobody could reach, carrying no price so no cache and
-- no merchant could ever pay one instead (models/spoils.lua draws its pool from PRICED items only).
--
-- They are in the right place here and it is not a consolation prize. Every one already belongs to a
-- house, every house is a circle, and a circle's guardian is the thing at the bottom of it -- so the
-- piece a line's seventh quest used to hand over is now what the sin at the end of that line pays for
-- being put down. Descent.dropFor walks the list and pays the first piece not already owned, so these
-- are what a SECOND and a fifth descent are paid in, which is the run-again loop this table was built
-- for and had nothing to spend on.
--
-- ORDER IS THE AUTHORED RELIC FIRST, then the rest alphabetically. The first entry is the one the
-- fiction promises -- kill Ira, wear her mail -- so it must never be displaced by a piece that happens
-- to sort ahead of it. Everything after it is ordered only so two machines agree.
--
-- `. content-report items` is the check: it reports what a deletion would strand, and it counts these
-- lists as a live source.
Descent.DROPS = {
    gluttony = { minor = { "utility_larder_hook" }, general = {
        "utility_maw_of_the_unfed",
        "armor_bogwalkers_coat", "armor_raveners_hide", "weapon_corvids_bow", "weapon_held_breath",
        "weapon_last_word", "weapon_sunfall", "weapon_unravelling_shaft", "weapon_witchlight_bow",
    } },
    lust     = { minor = { "utility_beggars_bowl" }, general = {
        "utility_reliquary_unbidden",
        "armor_hem_of_the_stayed_hand", "armor_reliquary_mantle", "armor_robes_unbidden",
        "weapon_censer_of_the_grasping_hollow", "weapon_censer_of_the_hollow_dark",
        "weapon_censer_of_the_unravelling", "weapon_renewal_staff",
    } },
    greed    = { minor = { "utility_tally_stick" }, general = {
        "utility_bottomless_purse",
        "armor_slipstep_leathers", "armor_smokecloth_wrap", "armor_unlit_hood",
        "weapon_nightjar", "weapon_slipknife", "weapon_throughline",
    } },
    envy     = { minor = { "utility_second_vessel" }, general = {
        "utility_envious_glass",
        "armor_choking_apron", "armor_ichor_coat", "armor_volatile_carapace",
    } },
    wrath    = { minor = { "utility_anvils_face" }, general = {
        "armor_mail_of_the_unappeased",
        "armor_adrenal_harness", "armor_blood_fever_mail", "armor_last_stand_plate",
        "weapon_anvil_of_the_ninth", "weapon_carrion_axe", "weapon_given_hour", "weapon_hollow_arc",
        "weapon_kingsfall", "weapon_long_count", "weapon_mired_maul", "weapon_reapers_due",
        "weapon_tempo_debt", "weapon_the_stillness", "weapon_whitening",
    } },
    -- Acedia's relic is her PIKE, and it took a second look to see it: it is tagged
    -- { "spear", "pierce", "physical", "melee", "relic" }, so a search for the bare `tags = { "relic" }`
    -- the other six wear reports her as the one general with nothing to pay. She is not. The set is
    -- whole.
    sloth    = { minor = { "utility_unblown_horn" }, general = {
        "weapon_forsworn_pike",
        "armor_aegis_unbidden", "armor_given_guard", "armor_kept_wound_shield", "armor_martyrs_shield",
        "armor_reflecting_shield", "consumable_bannerets_steel", "utility_closed_entry",
        "utility_forty_one_marks", "utility_names_he_kept", "utility_relief_order",
        "utility_struck_name", "weapon_debt_bell", "weapon_knell_point", "weapon_lending_blade",
        "weapon_shepherds_crook", "weapon_splitglass_saber", "weapon_sunderers_answer",
        "weapon_suspension_mace", "weapon_tidesbreak", "weapon_wardens_tongue",
    } },
    pride    = { minor = { "utility_marginal_gloss" }, general = {
        "utility_codex_unanswered",
        "armor_sealed_coat", "armor_unravelling_habit", "weapon_overchannelled_staff",
        "weapon_sealed_ward_wand", "weapon_swineherds_wand", "weapon_unravelling_wand",
    } },
}

-- WHAT A SPENT SET PAYS INSTEAD, in units of the house's own forge stock.
--
-- Sized against the bench that bills it: a Forge rung costs two-to-three house stock (models/forge.lua),
-- so four is a rung and change -- enough that a general with nothing left to give is still the best thing
-- that happened on that floor, and not so much that farming a circle you have stripped beats going
-- deeper. One constant, because the right answer is a tuning question and will move.
Descent.SPENT_SET_STOCK = 4

-- ...and what a stair pays when even the house stock cannot be resolved (a general with no vendor, which
-- is only the bottom floor and any test fixture). The last-resort coin, and deliberately small: this is
-- the branch nothing should reach.
--
-- IT USED TO LIVE ON models/relic.lua as BARE_SHELF_GOLD, shared with a Reliquary that had run out of
-- shelf to offer. That second caller is gone -- relics stack now, so a pool can never be exhausted and
-- an empty reliquary is not a state the game has any more -- and a constant with one caller belongs to
-- that caller. Moved rather than deleted because the stair's own empty case is still real.
Descent.SPENT_SET_GOLD = 15

-- Does this company already hold `itemId` -- in the stash, or in anybody's grid?
--
-- Asked of the WHOLE company rather than of a ledger of its own, because that is what "already got this"
-- means to a player: a relic worn by the knight is not a relic they are missing. Selling one therefore
-- makes it droppable again, which is correct -- they gave it up.
local function ownsItem(player, itemId)
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

-- The piece this body pays, or nil when its list is empty or spent. See Descent.DROPS.
function Descent.dropFor(player, sin, isGeneral)
    local set = sin and Descent.DROPS[sin.id]
    if not set then return nil end
    for _, id in ipairs((isGeneral and set.general or set.minor) or {}) do
        if not ownsItem(player, id) then return id end
    end
    return nil
end

-- WHAT CLEARING AN OBJECTIVE IS ABOUT TO PAY, so the victory screen can name it instead of the corner of
-- the map. Returns `{ gold, items = {ids}, materials = {[id]=n}, vouchers }`, or nil for an objective that
-- pays nothing by these routes.
--
-- The three things a cleared descent objective hands over -- an errand's purse and goods, the guardian's
-- own piece, the tokens a finished circle pays -- were each announced by a pushToast and by nothing else.
-- So the one fight a floor is BUILT AROUND was the only fight whose reward never reached the screen that
-- exists to report a reward: the panel showed the salvage floor alone, and the objective read as the
-- poorest stop on the board. (The campaign's objectives had the Company Advancement overlay for this,
-- which has had no reachable caller since the Quest Board was retired -- both its entry points hang off
-- Quest.complete.)
--
-- DISPLAY ONLY, and that is the whole contract. NOTHING HERE GRANTS. Every grant stays exactly where it
-- was -- the errand branch in states/game.lua's onWin, and game:openLanding -- which keeps the
-- double-payout guards those paths already carry as the only guards there need to be. The returned table
-- rides the spoils as `awarded`, a field grantSideSpoils deliberately does not read: folding these ids
-- into `spoils.loot` instead would have paid every one of them out twice, once on the panel's Continue
-- and once on the beat below it.
--
-- Every branch mirrors the test its own grant makes, so the screen can never name a thing the payout then
-- declines to hand over:
--   an errand   pays only while unfinished, which is Errand.complete's own first check;
--   a guardian  pays the first piece of hers this player does not already own (Descent.dropFor above,
--               which is pure), and the house's stock when the list is exhausted -- openLanding's own
--               fallback, and the gold beneath that when even the house has no material;
--   (a cleared circle paid crossing tokens here too, until the Crossing was retired.)
--
-- IT LIVES HERE RATHER THAN ON THE STATE that calls it because states/game.lua cannot be required under
-- the headless runner (it pulls ui/theme.lua, which wants a window), so a payout written there is a
-- payout no spec can read. This is arithmetic over a run and a player, which is what a model is.
function Descent.objectiveReward(player, run, objSpec)
    if not (player and run) then return nil end
    local out = { gold = 0, items = {}, materials = {} }

    -- AN ERRAND, tried first and returned from -- the same order states/game.lua's onWin takes, and for
    -- the same reason: a floor carries the stair AND whatever a house asked for down here, each on its own
    -- end (Descent.floorObjectives), so the objective just cleared is only the stair if it says so.
    local errandId = objSpec and objSpec.questId
    if errandId then
        if (player.completedQuests or {})[errandId] then return nil end
        local def = require("models.quest").defs[errandId]
        if not def then return nil end
        -- THE PURSE IS THE FIRST-CLEAR BONUS, so it is named only while it is still on offer. A company
        -- that has already lost this fight once has spent it (models/errand.lua's Errand.fail), and a
        -- card promising it here would be the Beggar's Bowl again: a reward named on the victory screen
        -- and handed over by nobody. The condition is READ FROM THE SAME FUNCTION the grant reads
        -- (states/game.lua's errand payout), which is the only way two sides of a payout stay agreed.
        out.gold = require("models.errand").failedOnce(player, errandId) and 0 or (def.rewardGold or 0)
        -- The GOODS are not a bonus and are never withheld -- they are this slot's share of the line's
        -- quest-only shelf stock (tests/obtainable_spec.lua), so a failure that took them would delete
        -- an item from the run rather than charge for a loss.
        for _, itemId in ipairs(def.rewardItems or {}) do out.items[#out.items + 1] = itemId end
        return (out.gold > 0 or #out.items > 0) and out or nil
    end

    -- THE STAIR GUARDIAN: what was on the body, then what the circle paid toward the next company.
    local depth = Descent.depth(run)
    local beaten = Descent.sinAt(run, depth)
    local dropId = Descent.dropFor(player, beaten, Descent.isGeneralFloor(depth))
    if dropId then
        out.items[#out.items + 1] = dropId
    else
        local houseMat = beaten and require("models.material")
            .houseFor((require("models.vendor").get(beaten.vendor) or {}).class)
        if houseMat then
            out.materials[houseMat] = Descent.SPENT_SET_STOCK
        else
            out.gold = Descent.SPENT_SET_GOLD
        end
    end
    return out
end

-- HOW DEEP A CIRCLE GOES. Wizardry's proving grounds are ten levels and its descendants go deeper; the
-- descent was eight, which is a tour of the seven rather than a dungeon. Two floors per circle makes it
-- fifteen -- squarely in that band -- and it is one constant, so three per circle is a one-line change.
--
-- Two rather than three on purpose: a floor is a real sitting, and twenty-two of them is a mode nobody
-- finishes. Fifteen is long enough that the way up is a decision and short enough to be walked.
-- ONE, AND THE STACK IS EIGHT FLOORS: seven circles and the Crown.
--
-- IT WAS TWO, AND THE ARGUMENT FOR TWO IS THE ONE THIS REVERSES. Fifteen floors was written for a
-- descent you could BANK PROGRESS IN -- the run outlived every climb-out, the map book kept what you
-- had walked, and the bottom was somewhere you got to eventually across many sittings. A descent that
-- RESETS when you walk out of it cannot ask that: the run is the roguelike now, the whole stack has to
-- be walkable in one, and a hundred and thirteen fights is not a run, it is a campaign.
--
-- WHAT IT COSTS, stated rather than smoothed over: the lieutenant loses her stratum. `minor.lead` was
-- the body holding the stairs above a general, so that the thing which barred your way two floors ago
-- was standing at her shoulder when you reached her -- and a player read their own progress off it
-- without being told. She is a GATE on the general's own floor now (Descent.SINS' `gate`), which keeps
-- the payoff and compresses the distance: you beat her, the ward breaks, and she is in the honour guard
-- behind her mistress ten minutes later instead of two floors later.
--
-- AND THE FIGHT COUNT MOVED WITH IT (FLOOR_FIGHTS below). Eight floors at the old six-to-nine is sixty
-- fights, which undershoots as badly as fifteen floors overshot; the floors got bigger instead, which
-- is what keeps a run that ends on floor two from feeling like a run that ended before it started.
Descent.FLOORS_PER_CIRCLE = 1

-- HOW MANY FIGHTS A FLOOR HOLDS, and it counts EVERY fight -- the stair, the errands, the openers and
-- the rolled stops between them. That is the whole of what changed here, and it is worth saying why the
-- old shape could not be tuned into this one.
--
-- This used to be a STOP count (14-18) with a combat SHARE over it, and the ends were placed by a
-- different pass entirely (models/overworld.lua's placeObjectiveAndGates), after the share had already
-- had its say. So a floor's ends were free: the stair cost nothing, an errand cost nothing, and the
-- three door-openers dealt onto floor one (Descent.openersAt) cost nothing. The budget governed the
-- half of the board the player cared about least.
--
-- MEASURED, at 14-18 stops and a 0.75 share (`. board-report 60 descent`): 11.33 rolled fights a floor.
-- The header this replaced claimed that setting "lands six or seven fights" -- a figure derived by
-- multiplying two constants and never rolled -- and it is out by nearly double, because the guarantee
-- pass seats far fewer texture stops than the arithmetic assumed and a CAP does not bind when the pool
-- is fight-heavy underneath it. Add the ends the instrument could not see (board-report builds its floor
-- from a nil player, which seats the stair and nothing else) and a real floor one is 11.3 + a stair + 3
-- openers = FIFTEEN fights. Fifteen floors of that is about two hundred fights in a run.
--
-- And the density was buying nothing. At 11.3 fights only 20.9% of them stood in front of a reward --
-- nine loose fights a floor guarding nothing at all. At 5 the same pass puts 48% of them on a guard: a
-- thinner board makes each fight MORE likely to mean something, because guardBoons is supply-limited by
-- the boons rather than by the fights.
--
-- SIX, and the number comes off the games this is modelled on rather than off the constants. The board
-- is Dream Quest's (see models/overworld.lua's DIM_MAX note) and a Dream Quest level is six to ten
-- fights before the stairs -- for a whole three-level run. The attrition is Darkest Dungeon's
-- (models/wound.lua), where a Short dungeon is four to six fights, a Medium seven to nine, and a Long
-- ten to twelve -- and a Long is the opt-in, high-risk one you go HOME after. Hades runs fourteen
-- chambers to a biome, but a chamber is forty seconds and a skirmish here is two minutes, so it is not
-- the same unit. Wizardry (Descent.FLOORS_PER_CIRCLE) is what sets fifteen floors, not what fills one.
--
-- Fifteen is the multiplier that settles it: there is no hub anywhere in the stack, so whatever number
-- stands here is spent fifteen times over. Six is a Dream Quest level and a Darkest Dungeon medium, and
-- fifteen of them is ninety fights -- a long run. Eleven was a Long dungeon fifteen times.
--
-- THE FIRST FLOOR'S, and the bottom's is below. See Descent.floorFights for the climb between them.
-- EIGHT AT THE TOP, ELEVEN AT THE BOTTOM, and the pair lays out 8/8/9/9/10/10/11/11 -- seventy-six
-- fights for a complete descent. That number is the whole re-cut: a hundred and thirteen (fifteen
-- floors at six-to-nine) is a campaign rather than a run, and sixty (eight floors at the old numbers)
-- is a stack you walk through before the mule has asked you anything.
--
-- THE SPAN IS STILL THREE, deliberately. Twelve at the bottom was tried and it widens the ramp to four,
-- which the case above refuses in as many words -- and it refuses it for a reason that did not change
-- when the stack did: difficulty already climbs on every other axis down here, so a fight count that
-- climbed harder would be charging twice for the same descent. Raising both ends by two keeps the
-- proportion identical and leaves the pin honest.
Descent.FLOOR_FIGHTS = 8

-- WHAT THE BOTTOM HOLDS, and the whole argument is in how little it is above the top.
--
-- A floor gets harder with depth on every axis that is not this one: the stock is grown to
-- Descent.dangerLevel, the stair carries a general rather than a lieutenant, the board itself widens a
-- tile a floor (Descent.floorDims), and the company walking it has been walking since floor one with no
-- hub to go home to. So the fight COUNT is the last place difficulty needs to come from, and a steep
-- ramp here would be charging twice for the same descent.
--
-- But flat was wrong too, and reading it on a board says why: floor fifteen laid out exactly as many
-- fights as floor one on a rectangle a third larger, which is not "the same dungeon, sparser" so much as
-- a bottom that stops asking for more than the top did. A count that never moves is a count the player
-- stops reading.
--
-- THREE, over fourteen floors. It lands as 6/6/6/7/7/7/7/8/8/8/8/8/9/9/9 -- four rungs, each held for
-- three or four floors, which is long enough that arriving on a new one registers as the descent asking
-- for more rather than as noise. And it is small: 113 fights across a run against 90 flat, where the
-- shape this replaced was about 200.
--
-- Authored as the bottom rather than as a per-floor step, because the run's LENGTH is the thing most
-- likely to move (Descent.FLOORS_PER_CIRCLE is one constant away from twenty-two floors) and a step
-- would silently re-price the bottom every time it did. An endpoint holds its meaning: whatever the
-- stack turns out to be, the last floor of it asks for nine.
Descent.FLOOR_FIGHTS_DEEP = 11

-- How many fights floor `f` may hold in all -- its ends included. Linear between the two constants
-- above and rounded, so the climb is the same shape whatever the run's length turns out to be.
function Descent.floorFights(f)
    local span = math.max(1, Descent.FLOORS - 1)
    local t = math.min(1, math.max(0, ((f or 1) - 1) / span))
    return math.floor(Descent.FLOOR_FIGHTS
        + t * (Descent.FLOOR_FIGHTS_DEEP - Descent.FLOOR_FIGHTS) + 0.5)
end

-- ...AND THE FLOOR UNDER THE ROLLED SHARE. A floor deep in the errand ladder can carry the stair and
-- four asked jobs, which spends the whole budget on ends before the pool is dealt a card -- and a board
-- whose only fights are its objectives is four markers on dead ends with empty trail between them.
--
-- So the budget is a ceiling on the ROLLED fights and the ends are subtracted from it, but never below
-- this: an errand-heavy floor overshoots six and is the longer sitting, which is the right way round.
-- The ends are the work the player chose to come down for; the two rolled fights are the ground.
Descent.FLOOR_ROLLED_MIN = 2

-- HOW MANY NON-FIGHT STOPS A FLOOR HOLDS, which is the other half of what the old stop count was doing
-- and the half nobody is complaining about. The rest, the reliquary, the recruit, a merchant, a shrine,
-- a crossroads, a find: the service and texture side. It should not move because the fight count did --
-- a sparser floor is meant to be a floor with less FIGHTING on it, not a floor with less on it.
--
-- SIX, because that is what the old board actually held, and the first number tried here was ten -- read
-- off the report's `boons` row, which counts CACHE TILES. A cache is not a stop: `cacheCount` is its own
-- pin (Descent.FLOOR_CACHES) and the caches land whatever this says. The non-fight STOPS at 14-18 were
-- 4.4 services plus 1.2 finds, and the ten put five phantom stops on the board -- which the combat cap
-- then filled with the only thing left in the pool, so a floor came out with nine merchants on it.
--
-- Held flat and ADDED to the rolled fights rather than shared with them, which is the inversion that
-- makes the budget mean what it says: a stop count with a share over it lets a fight and a cache compete
-- for the same tile, so capping the fights hard would have re-seated all of them as merchants and left a
-- floor with ten shops on it. Two separate numbers cannot do that to each other.
-- NINE, raised with the frame (FLOOR_COLS). See that constant for why the two move together.
Descent.FLOOR_TEXTURE = 9

-- The board's stop count and its absolute fight cap, for a floor carrying `ends` objectives -- the stair
-- plus whatever Descent.floorObjectives seated beside it. Returns both because they are one decision:
-- the generator sizes and fills the board off the stop count and holds combat to the budget, and a stop
-- count that did not move with the budget would just re-seat the difference as texture.
--
-- `ends` counts the stair, so the ordinary first floor passes 1 and rolls five.
--
-- THE RAMP REACHES THE ERRAND FLOORS FIRST, which is the reason it is applied here rather than to the
-- rolled count alone. The budget is a ceiling the ends are taken out of, so a deeper floor does not
-- merely deal more fights -- it has more ROOM for the work a house asked for before FLOOR_ROLLED_MIN
-- starts overshooting. Floor 3 carrying the stair and three errands rolls the minimum two and comes to
-- six; floor 11 carrying the same four ends rolls four and comes to eight. The climb lands where the
-- ladder is thickest, which is where a company notices it.
function Descent.floorBudget(ends, floor)
    local rolled = math.max(Descent.FLOOR_ROLLED_MIN,
        Descent.floorFights(floor) - math.max(1, ends or 1))
    local stops = Descent.FLOOR_TEXTURE + rolled
    return { min = stops, max = stops }, rolled
end

-- CACHES ARE PINNED, and this is the thing the density bump above would otherwise have moved in
-- silence. Overworld.generate derives the cache count from the stop count at about one per two stops,
-- so twelve stops is six caches where four was two -- and a cache is the largest single source of
-- forging material on a board, well above what the fights leave. Measured, a derived twelve-stop floor
-- pays around three Forge rungs of craft and house stock against the one the stage-2 payout rebase was
-- calibrated to (models/spoils.lua). Two or three holds that line at the new density.
-- THREE TO FOUR, RAISED DELIBERATELY, which is not the thing the note above forbids. What it refuses
-- is a DERIVED `per` that multiplies silently with the stop count; this is a considered absolute. The
-- reason it moved is the stack: eight floors instead of fifteen nearly halves the forging material a
-- complete run pays, and the bench was calibrated against the old total. Re-measure with
-- `. board-report N descent` before moving it again.
Descent.FLOOR_CACHES = { min = 3, max = 4 }

-- WHAT A FLOOR IS MADE OF, which is not what a quest board's leg is made of.
--
-- The generator draws its stops from a weighted pool, and the campaign's authored weights describe a
-- ROADSIDE -- a long walk with fights among the texture. Measured over thirty generated floors, those
-- weights hand a twelve-stop floor 5.2 fights, of which 2.8 are ELITES. The floor lands on its
-- twenty-seven minutes, but by the wrong route: few long fights instead of many short ones, which is
-- the exact trade the skirmish tier was built to reverse. A floor of five fights where three are
-- six-body set-pieces is the old pacing wearing a new board.
--
-- So a floor reweights the same pool. Three rules, and each is a different kind of statement:
--
--   fights keep their authored weights relative to each other -- which wolf, which boar, is a question
--   about the biome and this has no opinion on it;
--
--   an elite is pinned to a FLAT weight instead of the authored `weight = prestige`. That scaling was
--   written for a campaign where prestige is the run's difficulty dial; on a descent it means elites
--   crowd out ordinary fights without limit as the company grows, so by prestige 20 an "ordinary road
--   stop" is a set-piece again. One or two elites a floor is the punctuation; more is the old problem;
--
--   texture is scaled DOWN hard, because a floor already gets its rests and its reliquary from the
--   generator's own guarantees. Every free draw spent on a town is a skirmish the floor does not have.
--
-- Deliberately a transform over Encounter.pool rather than a second pool: eligibility, biome filtering
-- and the ctx-driven weights are all decisions that table already makes correctly, and restating them
-- here would be a second copy to drift.
Descent.ELITE_WEIGHT = 1.5
Descent.TEXTURE_SCALE = 0.2

-- HOW MANY CAMPS A FLOOR HOLDS, and the reason it is a flat number where a campaign ground uses a density.
--
-- The generator's rest guarantee is authored as one per six stops (models/overworld.lua's GUARANTEE),
-- which is the right unit for a quest board's leg: that board IS the run, the party goes home from it,
-- and Player.restore makes them whole at the hub -- so how much refund a board owes really does track how
-- big the board is. A floor is a SEGMENT. There are fifteen of them and no hub anywhere in the stack, so
-- a floor's stop count says nothing about how long the run it belongs to is.
--
-- Applied at that density a floor came out with THREE, measured (`. board-report 60 descent`), and three
-- is not a little more generous than two -- a camp hands back half of what is missing (Player.CAMP_SHARE),
-- so camps COMPOUND. Three of them return about 53% of everything a floor cost against 25% for one, and
-- at fifteen floors that is the difference between a descent that grinds a company down and one where
-- every floor opens near enough whole. Free attrition is the exact failure CAMP_SHARE was cut to 0.5 to
-- fix; carrying the campaign's density down here reintroduced it one board lower.
--
-- So: one, and it is a statement about the SHAPE of a floor rather than about its size -- the breather
-- before the stair. Raising the stop count must not quietly multiply it, which is what a `per` would do.
Descent.FLOOR_RESTS = 1

-- (`Descent.COMBAT_SHARE` stood here and is GONE. It was a fraction of the stop count -- 0.75 of it --
-- and a fraction is exactly the wrong instrument for this question: it could not see the objectives at
-- all (they are placed by a different pass), it did not bind when the pool was fight-heavy underneath
-- it, and its product with the stop count was not readable from either number. A floor names an
-- absolute fight budget now and the generator takes it as `combatBudget`, which wins over the share.
-- See Descent.FLOOR_FIGHTS for the measurement that retired it.)

-- THE FOUR HAZARDS, and the weight each gets on a descent floor.
--
-- They are authored at `weight = 0` (data/encounters/encounter_dark.lua and its three siblings) so a
-- rolled campaign board can never produce one -- a quest board's leg is a road through country, and a
-- hole that drops the company a floor has nowhere to drop them. Giving them a weight HERE is what scopes
-- all four to the only place they mean anything, without a second pool to keep in step.
--
-- Weighted well below a fight and unevenly among themselves, by how much each one costs. The Dark and
-- the Turning Floor take knowledge and are cheap enough to meet often; the Translation costs a long walk;
-- the Sink costs a floor, and one every few floors is a horror where one a floor is a mode about falling.
-- ORDERED, and that is not tidiness. The generator draws its stops out of this pool in list order, so a
-- pool assembled by walking a keyed table with `pairs` would lay a DIFFERENT floor on the same seed on
-- another machine -- the identical rule Descent.SINS is ordered for.
Descent.HAZARDS = {
    { id = "encounter_dark", weight = 1.2 },
    { id = "encounter_spinner", weight = 1.0 },
    { id = "encounter_translation", weight = 0.7 },
    { id = "encounter_sink", weight = 0.4 },
}

-- ---------------------------------------------------------------------------
-- What each hazard costs, in the floor's own units
-- ---------------------------------------------------------------------------
--
-- THESE WERE LITERALS IN states/game.lua AND EVERY ONE OF THEM WAS SIZED FOR A BOARD THAT NO LONGER
-- EXISTS. A floor used to be 40x40 tiles -- 931 walkable, a forty-step crossing -- and the three numbers
-- were picked against it: the Turning Floor unlearned a 13x13 block, the Translation wanted somewhere
-- eight steps off, the Dark ran thirty steps. All three read as "a neighbourhood", "a long way" and "a
-- stretch of walking" on that board.
--
-- A floor is a 10x10 grid of PLACES now, crossed in about eighteen steps. The same three numbers mean:
-- unlearn the entire floor, find somewhere further away than the floor is wide, and walk blind for
-- nearly two crossings. Measured on a fully-walked floor, the Turning Floor took the known cells from
-- 97 to 44 and took the WAY UP off the map with them -- which in a mode whose only bank is the stair you
-- came down by is not a hazard, it is a lost run with no fight in it.
--
-- So they live here, next to the table that deals them, and they are stated in the units their meaning
-- is actually in. Two are LOCAL and one is a DURATION, and that difference is the whole lesson: a number
-- that means "around you" must not be a fraction of the floor (which is how 6 got written), and a number
-- that means "for a while" must be, or it stops meaning anything when the floor changes size.

-- THE TURNING FLOOR takes your bearings, not your map. Two places, flat, on any floor: "the ground
-- around the company" is not a share of anything -- it is the neighbourhood you orient by, and it is the
-- same size whether the floor is ten a side or twelve. Thirteen cells of a seventy-five-place floor,
-- which is about what the old radius took of the old board before the board shrank under it.
Descent.SPINNER_RADIUS = 2

-- ...AND IT NEVER TAKES THE WAY UP. The exit is not bearings, it is the run's whole bank
-- (docs/overworld.md, Getting out): walking out is free and the risk is meant to be losing a FIGHT. A
-- hazard that can strand a full haul without one is off-contract, and the handler's own note already
-- says the spinner costs bearings rather than the map. Asserted, not just intended -- see
-- tests/hazard_scale_spec.lua.
Descent.SPINNER_SPARES_EXIT = true

-- THE DARK runs half a crossing. It is a DURATION and so it does scale: a stretch of walking means a
-- stretch of THIS floor. It also bites harder than it used to for a reason that is not about size --
-- sight is flat at one step now (models/player.lua's Player.VISION), so the dark takes it to nothing
-- rather than merely narrowing it, and thirty steps of that on an eighteen-step floor is most of a
-- sitting spent unable to read the place you are about to walk into.
function Descent.darkSteps(grid)
    local span = ((grid and grid.cols) or 10) + ((grid and grid.rows) or 10)
    return math.max(4, math.floor(span / 2))
end

-- THE TRANSLATION drops you a third of a crossing away, onto ground already walked. A third rather than
-- the old fixed eight, which on this floor is further than most of the floor is from most of the floor:
-- the pass found nothing to qualify and the hazard silently became a toast saying nothing happened,
-- which is the worst version of a hazard -- one the player learns to ignore.
function Descent.translationMin(grid)
    local span = ((grid and grid.cols) or 10) + ((grid and grid.rows) or 10)
    return math.max(2, math.floor(span / 3))
end

-- A FLOOR SEATS NO FIGHT THAT IS NOT A FIGHT, and this is the whole of what that means.
--
-- The pool a floor draws from is the CAMPAIGN's (Encounter.pool), which is right -- the world is the
-- world, and a wolf is a wolf whichever side of the stair it is on. But some of those blueprints are
-- ROADSIDE encounters: a lone ancient stag met crossing a forest is a fine thing to meet crossing a
-- forest. Seated in a dungeon against a company of four it is not a fight, it is a formality with a
-- marker on it -- and states/game.lua will offer to resolve it without a board (Muster.canWalkOver), so
-- the player is invited to skip the thing they came down here for.
--
-- MEASURED, AND THE CUT LANDS IN A GAP. Every fight in the mode was rated through Muster against the
-- company that can really be standing on its floor, and the walk-over-able ones -- fourteen instances
-- across two blueprints, encounter_stag and encounter_carrion_swarm -- all sat between 45% and 53% of
-- their own floor's MEDIAN fight. The next thing above them is 57%. So the threshold is not a dial
-- somebody has to keep re-tuning; it is a line drawn through four points of empty space, and 360 rated
-- fight-instances are on the far side of it.
--
-- RELATIVE TO THE FLOOR'S OWN STOCK, which is what makes it hold as content lands. An absolute floor
-- would need re-deriving every time the ladder moved; a share of the median re-derives itself. It also
-- says the true thing, which a body count does not: the same stag is a real fight on floor two (62% of
-- that floor's median, and not walkable) and a formality on floor eight (50%, and walkable), because
-- what changed is the company and the stock around it rather than the beast.
--
-- IT DOES NOT REPLACE THE BODY COUNT, and finding that out is the reason both are here. "A floor seats
-- no lone body" was the first cut, and on its own it is not enough: the stag composes TWO from day four,
-- so it passed a count of two and was still a walk-over on ten separate floors. Size is a proxy for worth
-- and worth is what the rule is about.
--
-- But the share is not enough on its own either, and it fails exactly where it is needed most. A relative
-- rule needs a pool with a shape; the desert at day one has SEVEN rateable fights, and the light ones drag
-- the median down with them until the lone stag sits at 55% of it and survives by a hair. The thinner the
-- floor, the more likely a lone beast is to be seated, and the less able a median is to say so. So the
-- count stands underneath as a hard floor that does not care what the rest of the board looks like: two
-- rules, because they are two different statements and each catches what the other misses.
--
-- NOT COMPANY-RELATIVE, which is the invariant this had to be written around. "Drop what the company
-- could walk over" is the rule one actually wants and it cannot live here: it would make the pool a
-- function of the roster, and a floor's layout has to reproduce from (seed, floor) ALONE -- see the note
-- on `hash`, which the whole resume rests on. A floor's own median is a property of the floor.
--
-- Fixed at the pool rather than in the blueprints, because the blueprints are not wrong. data/encounters/
-- is shared with the campaign, where a lone stag on a road is the encounter it was written to be; what is
-- wrong is a dungeon floor seating it. Curating its own pool is already this function's job -- it
-- re-weights elites and texture in the same loop for the same reason.
Descent.MIN_SHARE = 0.55

-- The hard floor underneath the share, in bodies. A dungeon fight is never one animal, whatever the rest
-- of the board happens to weigh -- see the note above for the thin-pool case this exists to catch.
Descent.MIN_BODIES = 2

-- ...AND THE CEILING OVER IT, which exists for one reason: a cap does not always bite.
--
-- Arena.clampComposition cuts a fight to the floor's ceiling by dropping repeated FILLER, and where the
-- distinct cast alone is already over the ceiling it yields rather than truncate -- a winnability rule,
-- since 43 quests win by assassinating a body the truncation would have deleted. So the opening floor's
-- cap of two silently does nothing to the fights made entirely of named bodies, which on a first circle
-- is exactly the wrong set: A Rival Company is four discipline exemplars in full loadouts (992 muster
-- against a pair's 296), and the Press-Gang is a four-part combo whose every piece is distinct.
--
-- A floor that cannot cut a fight to its own size does not seat it. Stated as a property of the CUT
-- rather than as a second worth threshold, so it needs no ratio of its own and cannot disagree with the
-- cap it is enforcing -- and it is inert on every floor that names no cap, which today is every floor
-- but the first.
local function overCap(def, ctx, cap)
    if not cap then return false end
    local Arena = require("models.arena")
    local ids = Arena.resolveComposition(def.composition, ctx)
    return #Arena.clampComposition(ids, cap) > cap
end

-- Below this many rateable fights the SHARE is not applied at all. A median over two or three entries is
-- not a median. The body floor still holds there, which is the whole reason it is safe to stand down.
Descent.SHARE_FLOOR_N = 6

function Descent.floorPool(ctx)
    local Encounter = require("models.encounter")
    local Muster = require("models.muster")
    local pool = Encounter.pool(ctx)

    -- What each fight on this floor is WORTH, rated exactly as the marker and the walk-off gate will
    -- rate it (Muster.encounter). The levels come off the floor descriptor when the caller has one --
    -- states/game.lua passes `quest` -- and where it does not, everything is rated at the same wrong
    -- level and the SHARE is unchanged, which is the other reason this rule is a ratio.
    local worths, rated = {}, {}
    for _, e in ipairs(pool) do
        if e.kind == "combat" or e.kind == "elite" then
            local ok, worth = pcall(Muster.encounter, Encounter.get(e.id), {
                day = ctx.day,
                quest = ctx.quest,
                floorLevel = ctx.quest and ctx.quest.floorLevel,
                enemyLevel = ctx.quest and ctx.quest.dangerLevel,
            })
            -- A blueprint that cannot be rated from a bare floor ctx is KEPT rather than dropped: this
            -- is a filter against light fights, not a gate every blueprint has to prove itself through,
            -- and a set-piece reading something only a live battle knows must not vanish from the floor
            -- because it was asked the wrong question here.
            if ok and type(worth) == "number" and worth > 0 then
                rated[e.id] = worth
                worths[#worths + 1] = worth
            end
        end
    end
    table.sort(worths)
    local median = #worths >= Descent.SHARE_FLOOR_N and worths[math.ceil(#worths / 2)] or nil

    local out = {}
    for _, e in ipairs(pool) do
        local weight = e.weight
        if e.kind == "elite" then
            weight = Descent.ELITE_WEIGHT
        elseif e.kind ~= "combat" then
            weight = weight * Descent.TEXTURE_SCALE
        end
        -- Only FIGHTS are weighed or counted. A rest, a reliquary and a merchant field nobody, so a
        -- filter that forgot to ask what KIND it was looking at would strip the floor of everything that
        -- is not a fight and leave it a corridor of skirmishes.
        local light = false
        if e.kind == "combat" or e.kind == "elite" then
            light = median ~= nil and rated[e.id] ~= nil
                and rated[e.id] < median * Descent.MIN_SHARE
            if not light then
                -- ...and the hard floor, which holds on a pool too thin to have a median worth trusting.
                local comp = Encounter.get(e.id).composition
                local ids = type(comp) == "function" and comp(ctx) or comp
                if type(ids) == "table" and #ids < Descent.MIN_BODIES then light = true end
            end
            -- ...and the ceiling, which drops what the floor cannot cut down to its own size. An elite
            -- is exempt from the cap (Arena.UNCAPPED_KINDS) and so is exempt from this: it is the one
            -- fight the opening floor is allowed to be too big for.
            if not light and e.kind ~= "elite"
                and overCap(Encounter.get(e.id), ctx, ctx.quest and ctx.quest.enemyCap) then
                light = true
            end
        end
        if not light then
            out[#out + 1] = { id = e.id, kind = e.kind, name = e.name, weight = weight }
        end
    end

    -- ...and the hazards, appended rather than re-weighted in place: Encounter.pool only ever returns
    -- entries with a weight above zero, so a blueprint authored at zero is not in the list to find.
    for _, h in ipairs(Descent.HAZARDS) do
        local def = Encounter.get(h.id)
        if def then
            out[#out + 1] = { id = h.id, kind = def.kind, name = def.name, weight = h.weight }
        end
    end
    return out
end

-- The board a floor is fought on, pinned rather than derived. Overworld.generate honours explicit
-- cols/rows ahead of deriveDims, and deriveDims run at twelve stops reaches its 27x19 cap -- one stop
-- per forty-odd tiles, which is the "marathon warren to shuffle a token through" that
-- models/overworld.lua's own header warns against.
--
-- 20x20 IS WIZARDRY'S FLOOR, and matching it changes what a floor IS rather than just how big it is.
--
-- The arithmetic, because it is the whole decision. 20x20 is 400 play cells against 15x13's 195, and the
-- stop count does NOT rise with it: 10-12 stops is one per thirty-odd tiles where it used to be one per
-- sixteen. So a floor stops being a string of fights with corridor between them and becomes mostly
-- GROUND -- which is exactly what a Wizardry floor is. Most squares of a proving-grounds level hold
-- nothing; what they hold is distance, and distance is what makes mapping worth doing, what gives a
-- spinner or a chute somewhere to displace you to, and what makes the walk back to the way up a real
-- decision rather than a formality.
--
-- It is also what keeps FIFTEEN floors playable. A floor with twenty-five stops on it would be a
-- forty-minute sitting, and fifteen of those is a mode nobody finishes; a floor with eleven stops spread
-- over four hundred tiles is a place you explore in one sitting and come back to.
--
-- A FLOOR IS TWO-WAY GROUND and this size assumes it. It was briefly cut to 13x11 for a one-way board
-- -- ground that closed behind the party, so every tile was walked once and never re-used, which wants
-- a tighter board. That was the wrong shape: one-way ground is the path-picker's idea (Hades, Slay the
-- Spire), where the map is a set of routes and what you skip never existed. A Wizardry floor is a place
-- you wander, map, and leave by walking back out of, and nothing on it is forfeit for being skipped --
-- so the tiles between the stops get crossed three or four times and their cost is amortised, which is
-- what one-way ground would have broken. See the note on the descent's shape at the top of this file.
--
-- THIS IS THE FIRST FLOOR'S BOARD, and every floor under it is wider. See Descent.floorDims.
-- FORTY, which is sixteen sectors of ten (models/layouts/vaults.lua). A sector spends one column and one
-- row on the wall it shares, so a chamber is nine a side -- which at the board's own 64 pixels a tile is
-- about 576, an arena's worth of frame.
--
-- The lattice is what sets this, and the lattice is set by a content rule: one encounter to a chamber
-- and no chamber without one, so the floor needs about as many chambers as it has stops. Thirty gave
-- nine sectors against thirteen stops.
--
-- SIX, AND IT IS A GRID OF PLACES RATHER THAN A RECTANGLE OF TILES. Everything above this line is the
-- record of the board this replaced and is kept because the argument it lost is the useful part: a
-- Wizardry floor is mostly GROUND, distance is what makes mapping worth doing, and 20x20 grew to 40x40
-- chasing it. What that produced was 931 walkable tiles carrying thirteen stops -- one every thirty
-- tiles, with the stair forty steps from the door -- and the walking was the content.
--
-- The floor is a grid of places now (models/overworld.lua): one cell is one place, it holds one thing,
-- and stepping onto it is arriving.
--
-- TEN A SIDE, AND IT IS SIGHT THAT SETS IT rather than any argument about how much ground a floor
-- should hold. The fog lifts ONE STEP (models/player.lua's Player.VISION) -- the place you stand in and
-- the four beside it -- so what a floor costs to learn is a function of how many places there are to
-- stand in. Six a side was twenty-seven places and about nine steps corner to corner, which one step of
-- sight reads out almost completely on the way to the stair: the floor was known by the time it was
-- crossed, and there was nothing left to have explored.
--
-- A hundred cells, a quarter of them blocked, is about seventy-five places and a crossing near twenty
-- steps. That is a floor you have to CHOOSE how much of to see -- which is the decision one-step sight
-- exists to create, and the decision a floor small enough to sweep cannot offer.
--
-- The stop budget does NOT move with it. Descent.FLOOR_FIGHTS is still six climbing to nine, argued
-- from Dream Quest and Darkest Dungeon, so a bigger floor is a THINNER one rather than a longer sitting
-- -- about a fifth of the places holding something against half at six a side. That is the row to read
-- if this ever wants revisiting (`. board-report N descent`, the `full` column): the fights are the
-- length of the sitting and the places are how much floor there is to spend them across.
-- ELEVEN, NOT TEN, AND THE FILL MOVED WITH IT. The stack went from fifteen floors to eight
-- (FLOORS_PER_CIRCLE), so a floor has to be a bigger place or a run that ends on floor two is a run
-- that ended before it started.
--
-- ELEVEN AND NOT MORE, AND THE CEILING IS THE SCREEN. The whole floor is drawn in one frame with no
-- camera -- that is what the sector grid was adopted for -- so the place size is
-- Overworld.BOARD_EXTENT (608) divided by the longer side, and a marker with its tier pips under it
-- stops being legible below about 44 pixels (tests/floor_grid_spec.lua pins both ends). That puts a
-- hard cap of 13 on the DEEPEST floor, and FLOOR_SPAN adds two to each side on the way down, so the
-- top is eleven. Twelve was tried and the bottom drew at 43.
--
-- BOTH HALVES OR NEITHER. The frame and the fill are one decision: widening this without raising
-- FLOOR_TEXTURE and FLOOR_FIGHTS lays the same content across more ground and produces a sparse floor,
-- and raising those without this crowds a board that has nowhere to put them.
--
-- (The note above still describes floor one as 26x26 and the bottom as 33x33. That is prose left over
-- from the retired warren carve -- there is no carve, and these are the sector grid.)
Descent.FLOOR_COLS, Descent.FLOOR_ROWS = 11, 11

-- HOW MUCH WIDER EACH FLOOR IS THAN THE ONE ABOVE IT: one tile of span per floor, laid on alternating
-- axes, so floor 1's 26x26 becomes 27x26, then 27x27, and the bottom is fought on 33x33.
--
-- WHY IT GROWS AT ALL. A run is fifteen floors of the same carve, and a fixed rectangle makes them
-- fifteen boards of the same size -- the fights get harder, the ground never does. Depth is the one
-- axis this mode has, so the place has to widen along it: the deep circles are meant to read as a
-- dungeon that is getting away from you, and the way up you left at the entrance has to get further
-- back the further down you are.
--
-- WHAT IT BUYS IS GROUND, NOT DISTANCE, and that distinction is the whole reason this is a gentle
-- slope rather than a steep one. The constant above already records the measurement: a lattice carve
-- lays one corridor per `spacing` tiles however big the frame is, so growing the rectangle barely moves
-- the deepest point (20x20 to 44x44 is five times the area and takes it from 32 tiles to 40). What a
-- bigger frame gives is more warren -- more to map, more wall to hide a door behind, more room between
-- the stops. That is worth having a floor at a time; it is not worth doubling the board for.
--
-- ONE TILE A FLOOR, ALTERNATING, and both halves of that are the point:
--
--   one tile, because the rate has to be legible over a RUN rather than between two floors. Half a
--   percent of area a floor is nothing to walk into and +61% by the bottom (676 play cells to 1089),
--   which is the same order as the 20 -> 26 the first floor was already grown by and lands the deepest
--   floor at a size that is still one sitting.
--
--   alternating, because it keeps every floor strictly bigger than the one above it. Growing both axes
--   together would step 26x26 -> 27x27 and hold a size for two floors at a time; a floor at a time is
--   what the mode is counting down, so the board moves at a floor at a time. It also means consecutive
--   floors are differently SHAPED (33x32 is not 32x33 to walk), which is free variety off a rule that
--   was going to be there anyway.
--
-- THE STOP COUNT DOES NOT FOLLOW IT -- it climbs on its own terms, which is a different statement and
-- the one a later retune must not blur. Measured over forty floors each (`. board-report 40 descent
-- floor=N`):
--
--   floor 1, 26x26   385 walkable tiles   13.0 stops   one per 29.6 tiles   3.4 arena sites   6 fights
--   floor 15, 33x33  589 walkable tiles   16.0 stops   one per 36.8 tiles   5.5 arena sites   9 fights
--
-- The board grows by 53% and the stops by 23%, because the three extra stops are the AUTHORED fight
-- ramp (Descent.FLOOR_FIGHTS_DEEP) and not a reading of the rectangle. That distinction is the whole of
-- what this note protects: a floor is a SITTING, and the deep ones are already the long ones -- their
-- fights stand a dozen levels above the shallow floors' and take proportionally longer to win -- so
-- scaling stops with the AREA on top of that would put the last floor of a fifteen-floor run at
-- twenty-seven stops of level-14 fighting, which is the forty-minute floor Descent.FLOOR_FIGHTS' own
-- header refuses. A deep floor is a little more dungeon spread over rather more of it, which is what
-- makes crossing one a decision rather than a formality.
--
-- And nothing the floor is judged on went backwards on the way down: the camp stays at one, guarded
-- boons hold (50% to 47%, against the 30% tests/descent_floor_spec.lua asserts), dead ends rise 7.5 to
-- 10.1 -- more spurs for the offer rule and for a door to hide behind -- and the arena sites a fight can
-- be seated in rise faster than anything else, which drops the fights seated on sub-standard ground
-- from 0.60 a board to 0.38. The extra ground is the good kind: room, not corridor.
-- TWO A FLOOR NOW, AND WHAT IT BUYS IS CHAMBERS RATHER THAN ROOM. Under the warren the extra span was
-- more ground to lay corridor and clearings on, and one a floor was enough. A vaults floor is a lattice
-- of fixed-size chambers -- a chamber is sized to fill the frame and has nowhere to grow to -- so span
-- buys the SECTOR COUNT: forty across is four sectors of ten, and it takes fifty to reach five.
--
-- At one a floor the bottom board only reached 47 from 40, which is a fifth more ground over fifteen
-- floors and reads as no change at all; two reaches 54, and picks up the fifth sector on the way. The
-- room count still follows the stop budget rather than the lattice (models/layouts/vaults.lua), so the
-- extra sectors are headroom and never empty chambers.
-- FOUR CELLS OF SPAN ACROSS THE WHOLE RUN, which is 10x10 at the top and 12x12 at the bottom.
--
-- The rate above was a tile a floor and the reasoning behind it still holds -- depth is the one axis
-- this mode has, so the place has to widen along it, and the way up you left at the entrance has to get
-- further back the further down you are. What changed is what a cell is worth. A tile was half a percent
-- of the board; a cell is a whole PLACE, and a place is somewhere the company has to walk to, stand in
-- and read. One a floor would take the bottom to 24x24 -- four hundred places -- and turn a sitting into
-- an afternoon.
--
-- Four rungs over fifteen floors, laid on alternating axes so no floor is ever smaller than the one
-- above it and consecutive floors are differently SHAPED (11x10 is not 10x11 to walk). It lands as
-- 10x10 x3 / 11x10 x3 / 11x11 x3 / 12x11 x3 / 12x12 x3 -- long enough on each rung that arriving on a
-- new one registers as the descent asking for more rather than as noise.
--
-- IT IS FOUR CELLS AND NOT A SHARE, deliberately. A proportional rate would have grown with the floor
-- when the floor grew from six a side to ten, which would have re-priced the bottom as a side effect of
-- a decision about the TOP. The endpoint holds its own meaning: whatever the first floor turns out to
-- be, the last one is four cells of span wider.
-- HOW MUCH WIDER THE BOTTOM IS THAN THE TOP, in total span rather than per floor.
--
-- IT WAS `4 / 14` AND THE 14 WAS A MAGIC LITERAL -- Descent.CIRCLE_FLOORS spelled out, which meant
-- re-cutting the stack silently re-priced the growth: at eight floors the same fraction would have
-- widened the bottom by two cells instead of four, and nothing would have said so. Stated as the
-- ENDPOINT and divided by the stack at the point of use, so whatever the run's length turns out to be,
-- the last floor of it is four cells of span wider than the first.
Descent.FLOOR_SPAN = 4

-- The floor a given depth is walked on. Pure arithmetic on the depth -- no run state, no rng -- because
-- a floor has to reproduce from (seed, floor) alone like everything else down here.
--
-- CIRCLE_FLOORS is read inside the body rather than closed over: it is derived further down this file
-- and would be nil at the moment this function is defined.
function Descent.floorDims(floor)
    local per = Descent.FLOOR_SPAN / math.max(1, Descent.CIRCLE_FLOORS)
    local span = math.floor(math.max(0, (floor or 1) - 1) * per + 0.5)
    return Descent.FLOOR_COLS + math.ceil(span / 2), Descent.FLOOR_ROWS + math.floor(span / 2)
end

-- WHAT A FLOOR IS CARVED OUT OF, and it is the single most load-bearing pair of constants here.
--
-- A descent floor used to inherit its biome's layout, which meant it inherited a campaign GROUND: the
-- volcanic circle got `rifts`, the desert got `sands`, and both carve open country with a road through
-- it, because that is what a quest board's leg is. Measured with a stopwatch on a 20x20 play area, the
-- deepest point of such a floor was NINETEEN TILES from the entrance -- 1.9 seconds of walking, out and
-- back. A place you can cross in two seconds has no room in it for a way up worth returning to, for
-- ground worth mapping, or for anything a chute or a teleporter could displace you to.
--
-- AND THE LEVER IS SPACING, NOT SIZE, which is the part worth writing down because it is the opposite
-- of the obvious move. Growing the rectangle barely moves the distance: 20x20 to 44x44 is five times the
-- area and takes the deepest point from 32 tiles to 40, because a lattice carve lays one corridor per
-- `spacing` tiles however large the frame is -- so a bigger board is mostly more fill. Halving the
-- spacing doubles the corridor per unit of area AND lengthens every path through it:
--
--   biome default, 20x20        237 walkable    deepest 19 tiles    1.9s round trip
--   dungeon at spacing 2, 20x20 278 walkable    deepest 74 tiles    7.4s round trip
--   dungeon at spacing 2, 26x26 455 walkable    deepest 71 tiles    7.2s round trip
--
-- 26 rather than 20 because the depth saturates but the GROUND does not: the same seven-second walk, and
-- nearly twice as much floor to get lost in and to hide things on. See models/layouts/dungeon.lua.
--
-- The biome still supplies the TILESET, so a swamp circle is a swamp warren and a castle circle a castle
-- one. What the sin owns is the look; what the descent owns is the shape underneath it.
-- SPACING 3, NOT 2, AND THE SECRETS ARE WHY. A lattice carve leaves walls exactly `spacing - 1` tiles
-- thick, so at 2 there is a single tile of rock between every pair of corridors -- and a floor with
-- one-tile walls has nowhere to hide anything behind one. Measured: at spacing 2 not one secret door was
-- dug on any seed, because every attempt broke through into a corridor the player had already walked,
-- which is a shortcut rather than a secret and the dig correctly refused it.
--
-- What it costs is depth, and less than it looks: 71 tiles at spacing 2 against 52 at spacing 3 on the
-- same 26x26 board, with the walkable ground within a few tiles of identical. Fifty-two is still five
-- seconds of round trip against the nineteen tiles the biome layouts were giving, so the trade is most
-- of the distance kept and hidden ground bought with the rest.
-- ...AND ALL OF THAT IS NOW HISTORY, kept because the reasoning above is still true of the carve it
-- describes and is the reason this one exists.
--
-- A floor is carved as ROOMS JOINED BY DOORS (models/layouts/vaults.lua). The argument for the warren
-- was walking distance and it was correct on its own terms; what it could not answer is that two thirds
-- of a floor's walkable tiles were one-tile corridor asking the player nothing. That was defensible
-- while a fight was an 8x8 window cut out of the map -- the ground you stood on WAS the arena, so a
-- defile and a hall were different fights -- and it stopped being defensible when models/arena.lua began
-- building its own board.
--
-- Measured, 30 rolled floors of each at floor one:
--
--                     dungeon        vaults
--   open ground       35.8%          62.4%
--   dead traversal    ~245 tiles     the door tiles, and nothing else
--   boons guarded     49.7%          55.8%
--   boons gateable    73.9%          100%
--
-- THE ROOM WAS THREE THINGS AT ONCE -- the unit of content, of the fight, and of the view -- and that
-- is exactly the admission the grid was built on. A floor of ten-tile sectors whose rooms hold one stop
-- each, light whole on entry, and gate on the doorway rather than on any tile IS a grid of places; it
-- was paying sixteen hundred cells to express sixteen of them.
--
-- SO THERE IS NO CARVE. A floor is a grid and the only shaping it takes is which cells are not there
-- (models/overworld.lua's Overworld:hollow). `carve` and `spacing` are gone with the layouts they named.

-- The enemy-level floor for a given depth: "a fight on this floor is never easier than this". Same
-- meaning the authored `floorLevel` has everywhere else (models/growth.lua's combatantLevel), which is
-- why it can simply ride on the descriptor.
--
-- ONE per floor, not two, and the ceiling is why. At two per floor an eight-floor descent topped out at
-- level 15, which is what the growth tables and the shelf were balanced against; at fifteen floors the
-- same slope would reach 29 and walk off the end of every curve in the game. So the LADDER GOT LONGER
-- AND THE CEILING STAYED PUT: the seventh circle's general now stands on floor 14 at level 14, within a
-- point of the 13 that Quest.SLOT_FLOOR used to hand the deepest quest of a line. More floors, the same
-- difficulty envelope, a gentler climb through it -- which is also the right shape for a mode whose
-- company now persists between expeditions rather than being minted at level 1 each time.
-- TWO, WHICH IS A REVERT RATHER THAN A NEW FIGURE. The note above is the whole derivation and it was
-- written the other way round: at two per floor an EIGHT-floor descent topped out at level 15, which is
-- what the growth tables and the shelf were balanced against, and it went to one only because the stack
-- grew to fifteen and the same slope would have reached 29. The stack is eight again
-- (FLOORS_PER_CIRCLE), so the ceiling lands back where every curve in the game expects it.
Descent.LEVEL_PER_FLOOR = 2

-- WHAT THE WORLD FIGHTS AT ON THE FIRST STAIR, and the number that fixes a floor nobody had to play.
--
-- The campaign hardens on the calendar (models/calendar.lua) and a descent has no calendar, so
-- states/game.lua maps depth onto the campaign's forty days to decide which encounter blueprints are
-- eligible down here. That mapping was only ever meant to open the deep pool -- its own comment says the
-- enemy LEVEL still comes off `floorLevel` -- but Calendar.dangerLevel(day) is what states/battle.lua
-- reads for the level too, and Growth.combatantLevel takes the higher of the two. So from floor 3 down
-- the day ladder won outright and floorLevel was never read again: measured, the bottom floor spawned
-- ordinary stock at 19 and elites at 22 against a company the experience curve puts at 15.
--
-- The shallow end was worse than the deep one. Floor 1 asked for day 2, which is danger 2, which after
-- ENEMY_LEVEL_LAG is stock at BLUEPRINT LEVEL 1 -- while a company clears that same floor arriving at
-- level 4, because the descent's experience curve is cheapest at the bottom (10, then 20, then 30). A
-- muster margin of 192% against Muster.WALK_OVER of 200 means every marker on the floor goes calm and
-- every fight on it opens the auto-resolve offer instead of a board. The first floor of the mode was
-- the one floor nobody had to play.
--
-- So the descent gets its own dial, keyed on the only clock it has, and the day goes back to the one job
-- it was brought in for. THREE is where a company that has fought its way onto the stair actually
-- stands, so floor 1 opens as a fight rather than a formality.
Descent.OPENING_DANGER = 3

-- HOW MANY BODIES THE OPENING FLOOR FIELDS, and the number that fixes a floor priced for a company
-- nobody has yet.
--
-- Floor one is walked by TWO: the avatar and Rowan (data/player.lua's startingRoster), at the level Act
-- 0 leaves them -- within one of OPENING_DANGER, which tests/experience_spec.lua pins. Every other body
-- in the game is met at a companion's posting down here and joins by clearing the fight she asks for
-- (models/errand.lua), and one companion is dealt per floor -- so the company cannot be three until the
-- first floor's posting has been found AND run, which makes the opening floor the one board in the mode
-- whose headcount is known before it is rolled.
--
-- The tuning it met assumed four. Measured through Muster against that pair: the floor's heaviest stops
-- were A Rival Company at 40%, the Broken Column at 53% and the Press-Gang at 54% -- and the two openers
-- that HAND OVER the third body read 65% and 67%, so the fight gating the company's growth was priced
-- for the company it would grow into. The same floor against four reads 110% on those openers, which is
-- where it was aimed.
--
-- THE GAP IS A HEADCOUNT, NOT A LEVEL, which is what rules out the two dials that already existed:
-- dropping OPENING_DANGER from 3 to 1 moves the median stop by three points, because
-- Growth.ENEMY_LEVEL_LAG flattens the first two levels into the same stock, and pulling the depth->day
-- mapping back to day one lands in the same place while re-opening the seating bug that mapping was
-- added to fix. Bodies are the only dial with any authority left.
--
-- So the opening floor names its own ceiling and every ordinary fight on it is cut to fit
-- (Arena.enemyCap honours it as a `math.min`, so it can only ever take bodies off).
--
-- THREE RATHER THAN TWO, and the difference is a floor with a shape against a floor with none. Two put
-- every stop within a hair of every other -- and it cut a fight authored as A LEAD PLUS A SWARM down to
-- a lead and one gnat, which is not a smaller version of that fight, it is a different and much easier
-- one. The Carrion Flight fell to 158 and the Drift to 198 against a pair worth 365, so both crossed
-- Muster.WALK_OVER and the game began offering to resolve them without a board: the "one floor nobody
-- had to play" failure that OPENING_DANGER was raised to fix, walked back in through the ceiling.
--
-- At three, nothing on the floor is skippable anywhere in Act 0's exit band and nothing stands more than
-- a step above: the spread runs 62% (the Broken Column) to 146% (the Drift) against a level-3 pair, with
-- the two openers at 75% and 78%. Measured, in tests/descent_spec.lua's opening-floor case.
--
-- TWO THINGS ARE EXEMPT, and they are the floor's whole shape. An ELITE is a tier of its own
-- (Arena.UNCAPPED_KINDS) and the STAIR names `enemyCap = false` on its spec: those are what a pair walks
-- around and comes back for once an opener has paid out, which is the only reason a floor tuned for two
-- still has somewhere to grow into. See OPENING_GUARD.
Descent.OPENING_CAP = 3

-- WHAT STANDS ON THE OPENING STAIR, in filler, and why it is stated here rather than left to the
-- guardian formula.
--
-- guardianComposition sizes a lieutenant's guard at `2 + floorLevel/3`, minus one for not being the
-- general -- which at floorLevel 1 is ONE body, and a minor circle's filler is swarm stock priced at a
-- third of a bandit (petal-drift 53, gorge-fly 47, coin-chitter 52). So the thing at the end of the
-- first road was worth 202 against a floor whose median stop was 443: the lightest fight on the board
-- was the one it ended on, and that is true of every minor stair, not just Lust's.
--
-- Five, which puts the opening stair at 412 muster: an even fight for the trio it is meant for, and 89%
-- for the pair who have not climbed out yet -- so it is a fight at the end of the road rather than the
-- gap in it, and it is a reason to do an opener FIRST. It is deliberately not the heaviest thing on the
-- floor; an ogre or a warband is allowed to outweigh a lieutenant, and the difference between them is
-- that only one of the three is mandatory.
--
-- FIVE RATHER THAN SIX BECAUSE A COUNT IS ALSO A CLAIM. Six put seven bodies on the opening stair, which
-- is what the deepest general's own guard fields (`2 + floorLevel/3` at floorLevel 14) -- and "deeper
-- stairs are held harder" is an invariant with a case on it. That claim is still true by WORTH at seven
-- gnats, and asserting worth where a body count is asserted today is a separate argument; five keeps the
-- count climbing and costs about a tenth of the fight.
--
-- THE SWARM IS THE RIGHT BODY TO THICKEN IT WITH, not a second lead. A drift is authored to be worth
-- nothing to kill and to charge you for holding your turn (data/characters/character_petal_drift.lua) --
-- so six of them is the fight that circle was written to be rather than merely a bigger one, and the
-- muster ruler UNDERPRICES it either way: it reads stats, and a body whose whole threat is a Charm on
-- contact rates as nine health. Expect this stair to play harder than 465 says.
--
-- A FLAT BODY COUNT IS SAFE HERE FOR A REASON WORTH WRITING DOWN. The seven minor bands do not field
-- comparable filler -- a cinder-kin is worth three petal-drifts -- so six of one is not six of another,
-- and at these numbers Wrath's opening stair would read 1100 where Lust's reads 465. It cannot happen to
-- the company this constant is for: a first descent walks Dante's order (Descent.INFERNO), so floor one
-- is ALWAYS Lust until the Crown is broken, and the shuffle that could seat any other circle first is
-- only dealt to a lap that carries its veteran company across (Player.newGamePlus). The cheap filler and
-- the level-one pair are the same case, every time.
--
-- Scoped to the opening floor because that is the floor whose company is known. Every minor stair below
-- it is met by whatever the player has assembled, and re-pricing those is a separate argument.
Descent.OPENING_GUARD = 5

-- Is this the floor a descent opens on -- the one board walked by a company that has not been assembled
-- yet? Its own call rather than `floor == 1` spelled out at four sites, so the three rules that key off
-- it (the cap, the stair's guard, and the pool's own filter) cannot drift apart.
function Descent.isOpeningFloor(floor)
    return (floor or 1) <= 1
end

-- The level the world fights at on this floor -- the descent's Calendar.dangerLevel, and the number
-- states/battle.lua takes as `enemyLevel`. Fed in as the TRACKED level rather than as a battleFloor,
-- which is what keeps Growth's two tiers apart: ordinary stock lags it and anything naming a
-- `floorLevel` of its own tracks it exactly, so the trash thins out and the guardian does not.
function Descent.dangerLevel(run)
    return Descent.OPENING_DANGER + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
end

-- WHICH DAY A FLOOR BORROWS, purely to decide which encounter blueprints may appear on it (`minDay`).
-- The enemy LEVEL is Descent.dangerLevel's and this must never become a second answer to it.
--
-- WHICH IS EXACTLY WHAT IT HAD BECOME, TWICE, AND THE SECOND TIME IS WHY THIS FUNCTION EXISTS. The
-- mapping was `depth / FLOORS * SPAN` -- depth spread evenly across the campaign's forty days -- and
-- states/battle.lua reads its level off Calendar.dangerLevel(day) while Growth.combatantLevel takes the
-- HIGHER of that and the floor's own. So whenever the borrowed day out-ranks the floor, the day silently
-- becomes the ladder and OPENING_DANGER stops meaning anything. At fifteen floors it did that from floor
-- three down. Re-cutting the stack to eight made it worse rather than better: five days a floor instead
-- of under three, so the day overtook the ladder on floor ONE.
--
-- SO THE DAY IS DERIVED FROM THE LADDER RATHER THAN FROM THE DEPTH. Read Calendar.dangerLevel backwards
-- -- find the day whose danger matches this floor's -- and floor it, so the borrowed day always rates a
-- shade BELOW the floor it is standing on and the descent's dial wins every comparison by construction.
-- Re-cutting the stack, the ladder or the calendar cannot re-break this, because it no longer contains
-- an opinion about any of their lengths.
function Descent.poolDay(run)
    local Calendar = require("models.calendar")
    local span, final = Calendar.SPAN or 1, Calendar.FINAL_DANGER or 1
    if span <= 1 or final <= 1 then return 1 end
    -- ONE RUNG BELOW THE FLOOR'S OWN DANGER, not level with it. Aiming at parity lands the borrowed day
    -- on exactly the floor's level once the calendar's rounding is applied, and a day that TIES with the
    -- ladder is a day that has quietly become the ladder again -- Growth.combatantLevel takes the higher
    -- of the two and cannot tell which one it took. A rung of margin costs a sliver of pool breadth and
    -- makes the ownership unambiguous at every depth.
    local t = (Descent.dangerLevel(run) - 2) / (final - 1)
    return math.max(1, math.min(span, math.floor(1 + t * (span - 1))))
end

-- Ids are `descent_f<N>`. Nothing in the engine ever looks a floor up in Quest.defs -- models/save.lua
-- branches on the presence of a stored descent BEFORE it tries Quest.get -- but the prefix keeps a floor
-- id recognisable in a save file and in a log line.
local ID_PREFIX = "descent_f"

-- ---------------------------------------------------------------------------
-- Determinism
-- ---------------------------------------------------------------------------

-- A floor's layout has to reproduce from (seed, floor) alone: the run is saved as a seed and a depth,
-- and a resume re-derives everything from them. So this is a plain integer hash rather than a stateful
-- RNG -- an RNG would have to store its position too, and would drift the moment anything else drew
-- from it. Pure, headless, and identical on every machine.
--
-- Bit ops are avoided on purpose: this is Lua 5.1 (LOVE's interpreter) and it has none. Multiply-and-mod
-- over values that stay well inside a double's exact-integer range does the same job.
local function hash(seed, floor, salt)
    local h = ((seed or 0) % 1000003) * 31 + (floor or 0) * 7919 + (salt or 0) * 104729
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Start a descent. `seed` is optional and exists so a spec can pin a run; live play rolls one.
--
-- `entry` is left nil here and filled by states/game.lua on the first floor, because the rollback point
-- is a Save.snapshot and this module deliberately knows nothing about the save format. What matters is
-- that it lives on the RUN rather than on the floor: the whole descent is one expedition, so the
-- snapshot is taken once at the top and every floor after it shares the same way back.
function Descent.new(player, seed)
    return {
        floor = 1,
        -- OFF THE SAVE'S OWN SEED, not off the clock (models/seed.lua). It was `os.time()`, which is a
        -- seed nobody can say: a bug report about a floor could not be replayed, a run could not be
        -- handed to somebody else, and the number the whole layout hangs from was different every time
        -- the same save went down. Seed.run folds the lap's seed with which descent this is, so two runs
        -- in one playthrough are different rifts and the same playthrough replays as itself.
        --
        -- An explicit `seed` still wins, which is what a spec pins a run with. The clock survives only
        -- for a run with no player behind it at all -- a fixture, never live play.
        seed = seed or (player and require("models.seed").run(player)) or (os.time() % 1000000),
        -- WHICH ORDER THE SEVEN CIRCLES COME IN, decided once, here, at the mouth of the run.
        --
        -- False is Dante's order and true is this run's own shuffle; what flips it is having broken the
        -- Crown (Player.hasFinishedCampaign). See Descent.sinOrder for why the poem goes first.
        --
        -- STAMPED RATHER THAN ASKED, and the reason is that a layout must not move under a company
        -- standing in the middle of it. Everything else about a floor is re-derived from the seed and
        -- the depth on every resume, which is exactly what stops a stored copy drifting -- but the
        -- seed cannot know what the player had done when they walked in, so this one boolean rides
        -- along with it. It is also what keeps the FIRST run after the Crown falls honest: the run in
        -- progress when it fell keeps the order it opened with, and the next one deals its own.
        -- Asked ONLY of a player who was handed in. Player.hasFinishedCampaign falls back to
        -- Player.active and then to the save on disk when given nil, which is right for the main menu
        -- and wrong here twice over: a run's layout would depend on ambient state, and a headless
        -- caller passing no player would go and read the player's real save file to lay out its floors.
        shuffled = (player and require("models.player").hasFinishedCampaign(player)) or nil,
        -- Taken at the first floor and then carried by reference for the rest of the descent. See above.
        entry = nil,
        -- Quest ids banked but not yet paid out. Nothing writes this until authored floors land; it is
        -- declared here so the shape of a run does not change under models/save.lua later.
        pending = {},
        -- The deepest floor this run has actually cleared, which is what a new depth record is measured
        -- against at extraction. Distinct from `floor`, which is where the party is standing.
        cleared = 0,
        -- Iselle's tally: what this company has left forming behind it. Climbs when they come back up
        -- early, falls when they go deeper. See the count section below.
        count = 0,
        -- The boon slate dealt off the general the party just put down, held only for the window between
        -- clearing a floor and taking its stair (states/game.lua's openLanding). A list of relic ids, so
        -- it rides in a save as plain data and a resume re-opens the landing on the same three cards
        -- rather than dealing three new ones. Nil at every other moment of a run.
        landing = nil,
        -- WHAT THE COMPANY DROPPED WHERE IT FELL. The bodies always come back -- a wipe wakes the
        -- company at the temple, whole and wounded (states/game.lua's onLoss) -- and what stays on the
        -- floor is everything they were CARRYING.
        --
        -- Dark Souls' bloodstain, and it is the only thing standing between "climb out" and "die" being
        -- the same move. Levels, mapped floors and bound relics survive a wipe; the kit and the haul do
        -- not, until somebody walks back down to the tile and picks them up. Without that the way up is
        -- decorative: a company that died on floor nine would wake, walk back, and have lost nothing but
        -- the walk.
        --
        -- Entries are { floor, x, y, items } where `items` is a list of Save.snapshotItem data, NOT live
        -- instances -- a live one can hold loaded images and Save.encode raises on userdata, so a pack
        -- kept as instances would take the save down the first time a company wiped.
        drops = {},
        -- THE FLOORS THIS COMPANY HAS WALKED, keyed by depth, as Overworld:snapshot data.
        --
        -- A Wizardry floor is the SAME maze every time you go down to it -- that is the entire reason
        -- mapping one is worth doing, and it is why a secret door found on the third trip is a thing you
        -- found rather than a thing that was rolled. A board cannot be rebuilt from its seed here
        -- (Overworld:snapshot says why: the stops are drawn in `pairs` order, so the same seed reshuffles
        -- them), so keeping the floor means literally keeping it.
        --
        -- Costs a save file that grows by a board per floor visited. Accepted: a board is plain data and
        -- fifteen of them is a fraction of what a company's own gear costs to store.
        floors = {},
        -- Which circles this run has cleared, as { [vendorId] = floors cleared }. It used to be standing
        -- OWED to the houses, banked into the campaign player on the way out; there is no campaign player
        -- to bank into now, so it is simply the run's own record of what it beat and the terminal card
        -- reads it. Still held on the run rather than anywhere durable, and still lost with a wipe.
        standing = {},
    }
end

-- ---------------------------------------------------------------------------
-- The run's company
-- ---------------------------------------------------------------------------

-- Where a descent in progress lives on disk. Its OWN file, never the campaign's -- a run banks nothing
-- into a save and must not be able to touch one. Deleted the moment a run ends (Descent.clearSaved), so
-- what persists here is one unfinished run and never a trace of a finished one.
Descent.FILE = "descent_run.lua"

-- The coin a company walks in with. Small on purpose: the descent's economy is what its floors pay out
-- -- spoils, caches and the overworld's own merchant stops -- and an opening purse that could buy its
-- way past floor one would settle the run before a tile of it was walked.
--
-- IT IS SCRIP NOW, and this constant is an alias rather than a second number. The economy split
-- (models/scrip.lua): a run spends its own weightless coin, so what a company "walks in with" is the
-- thing Scrip.OPENING names. Kept under its old name because the argument above is the argument that
-- chose the number and belongs beside it, and because a spec pins it.
Descent.OPENING_GOLD = require("models.scrip").OPENING

-- WHO WALKS IN. Four of the roster, chosen at the Gate before the stair (Descent.party).
--
-- A descent used to open on a MUSTER: a shelf of eleven candidates, a twelve-coin purse, and a company
-- of up to eight bought at the mouth (models/descent_muster.lua, deleted with this). It was the mode's
-- first decision and it was the wrong thing to open on. The whole run was settled on a screen, by
-- comparing eleven bodies the player had never fought with, before a single tile was walked -- and every
-- run after the first was that same screen again. What belongs at the mouth of a descent is a stair.
--
-- So the company is not bought at all: it is the roster you already have, and FOUR of it go down the
-- stair (Descent.party). It grows a floor at a time -- one companion stands per floor, asks for one
-- piece of work, and joins when it is cleared (models/errand.lua) -- rather than at a stop that deals
-- bodies.
--
-- A FLOOR SLATE DID EXIST, one body offered per floor off an authored pool (models/descent_recruit.lua,
-- deleted with its panel). It went with the pull it was built beside: two ways to gain a companion is
-- one more than the mode can explain, and the posting is the better one because it is met while playing
-- rather than chosen off a card.
--
-- THE AVATAR STANDS IN THE COMPANY, and this file argued the opposite for a long time. The claim was
-- that a descent's player is a TACTICIAN -- you direct the company, you never stand in it -- because
-- every answer to "what happens when your body dies" looked bad: losing it outright ends the mode over
-- one fight; leaving it recoverable means minting a SECOND you to fetch the first, and identity here is
-- `char.id`, so two bodies with one id is a company where half the ledger points at the wrong person;
-- protecting it specially makes one member unkillable.
--
-- What settled it was a third answer nobody had asked for: the avatar is never permanently lost, and it
-- is also never REQUIRED. It can be fielded, benched, or left at home like anybody -- FFT's protagonist
-- without FFT's mandatory slot. Nothing has to be minted, because nothing is gone; and no member is
-- unkillable in a fight, because the recovery happens at the Gate rather than on the floor. The company
-- is still what the player owns; it just has them in it.
--
-- The one thing that survives from the tactician argument is the floor it puts under the roster: the
-- avatar cannot be lost, so the roster can never reach zero -- which is what makes the Gate's forward
-- guarantee structural rather than a special case (models/gate.lua, tests/gate_forward_spec.lua).
--
-- So there is no starting body constant, and Descent.startingCompany returns nothing.

-- How many bodies STAND ON THE BOARD. Four, mirroring Player.MAX_FIELD the same way Combat.MAX_FIELD
-- does, so this file stays free of the player model; tests/descent_party_spec.lua pins the two
-- together.
-- IT IS THE TRAVEL CAP, AND IT IS ITS OWN NUMBER. How many bodies go DOWN THE STAIR -- not how many
-- stand on the board, which is Player.MAX_FIELD and happens to be the same four.
--
-- IT MEANT THE BOARD FOR ONE RELEASE, and the difference was invisible because the two numbers match.
-- It mattered anyway: while this only capped the board, the whole roster walked down and the deployment
-- phase picked four per fight, so a wounded body was somebody who sits out rather than a quarter of the
-- company. models/wound.lua's FLOOR is priced for a company with NO bench underground -- its own header
-- says so -- and that premise came back the moment the expedition became four.
--
-- IT CAPPED THE ROSTER BEFORE THAT, which is a third meaning and the one that broke. Four held, ever,
-- every body you found fought; nothing ever left a company, so the fourth body ended recruitment for
-- good and the floors stopped seating anyone. Three distinct claims have worn this name, so: the ROSTER
-- is unbounded, the EXPEDITION is this, and the FIELD is Player.MAX_FIELD.
Descent.PARTY_MAX = 4

-- WHO IS GOING DOWN: the bodies picked at the Gate, as roster instances.
--
-- Stored on the RUN as ids rather than on the player, because it is a fact about this expedition and
-- not about the company -- climb out, swap two hurt bodies for two rested ones, and go back down is the
-- loop the Gate exists for. Ids rather than instances so it survives a save without holding a second
-- reference to a body the roster already owns.
--
-- An unset party is the first four of the roster. That is the honest default rather than a placeholder:
-- a company that has never picked has not expressed a preference, and refusing to descend until it does
-- would gate the stair on a screen the player has no reason to have opened yet.
--
-- Filtered against the live roster on the way out, so a party naming somebody who has since left (or a
-- save from before this existed) degrades to whoever is really there rather than to a hole in the line.
-- EVERY BODY ON THE ROSTER IS PICKABLE, and there is no second filter here any more. Anyone lodged at
-- the Inn used to be strained out on the way through -- a bed took them out of the company for a day a
-- wound, and that absence was the real cost of the stay. The Inn is gone (models/wound.lua): a wound is
-- a condition of the expedition it was taken on and the surface ends it, so there is no state a body can
-- be in that makes them unavailable to send.
function Descent.party(run, player)
    local roster = {}
    for _, char in ipairs((player and player.roster) or {}) do
        roster[#roster + 1] = char
    end

    local picked = run and run.party
    if not picked or #picked == 0 then
        local out = {}
        for _, char in ipairs(roster) do
            if #out >= Descent.PARTY_MAX then break end
            out[#out + 1] = char
        end
        return out
    end

    local byId = {}
    for _, char in ipairs(roster) do byId[char.id] = char end
    local out = {}
    for _, id in ipairs(picked) do
        if byId[id] and #out < Descent.PARTY_MAX then out[#out + 1] = byId[id] end
    end
    return out
end

-- Set who goes down, from a list of ids (or characters). Clamped to PARTY_MAX and silently deduped --
-- a caller toggling rows should not be able to build an illegal party by pressing quickly.
function Descent.setParty(run, ids)
    if not run then return end
    local seen, out = {}, {}
    for _, entry in ipairs(ids or {}) do
        local id = type(entry) == "table" and entry.id or entry
        if id and not seen[id] and #out < Descent.PARTY_MAX then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    run.party = out
    return out
end

-- The company a run walks in with: NOBODY. See the note above -- the player is a tactician, so there is
-- no authored body that is theirs, and the first member is hired at the gate off the same slate the
-- floors offer.
--
-- Kept as a function rather than deleted, and returning a list rather than nil, because every caller
-- builds a profile out of it (Descent.newProfile) and an empty company is a legal one -- the gate is
-- where it stops being empty, and Gate.canDescend is what refuses to open the stair until it does.
function Descent.startingCompany()
    return {}
end

-- THERE IS NO Descent.hasRoom ANY MORE, and this note is here because three call sites used to ask it
-- and a fourth was about to. The roster is unbounded (see PARTY_MAX above), so "is there room for one
-- more" has exactly one answer and a function that always returns true is a branch pretending to be a
-- question. What still has a limit is the BOARD, and the thing that asks about the board is the
-- deployment phase, which counts against Player.MAX_FIELD where it always did.

-- ---------------------------------------------------------------------------
-- What the company dropped where it fell
-- ---------------------------------------------------------------------------

-- HOW BIG A PILE HAS TO BE BEFORE SOMEBODY ELSE COMES FOR IT. See packGuard.
Descent.PACK_COMPANY_ITEMS = 10

-- WHAT IS STANDING OVER A PILE, resolved when the company falls and stored on the drop as a plain id
-- list. A pile is a FIGHT (see dropPack), and this is the cast of it.
--
-- TWO FICTIONS, and the pile itself picks which one. A small pile draws the circle's own vermin, which
-- are already authored -- the gorge flies, the coin chitters, the cinder kin that fill out that sin's
-- honour guard (Descent.SINS). A big one draws a RIVAL COMPANY: you are not the only outfit down here,
-- word travels, and four bodies' worth of kit lying unattended is the best day somebody else has had
-- all season. Same warband draw the road's own company fight uses (models/warband.lua).
--
-- SO THE GUARD IS PRICED OFF WHAT YOU LOST rather than off the floor, and that is the whole of why it is
-- shaped this way: the pile you leave on your first bad night is four or five things and the thing over
-- it is vermin, while the pile a full company leaves on floor twelve is a company's worth of gear and
-- somebody good is wearing it by the time you get back. The recovery fight scales with the disaster,
-- which is the only version of it a player who died early can actually walk back into.
--
-- COUNTED IN ITEMS, NOT IN GOLD, and the obvious alternative is wrong here: `price` is nil on exactly
-- the pieces a descent pays out -- a general's relic is unpriced because it is never sold -- so pricing
-- the pile would have read a bag of the best things you own as worthless.
--
-- RESOLVED ONCE, HERE, and stored. Deciding it at the marker instead would re-draw the company every
-- time the floor was re-entered, and a fight that is four bodies before the save and six after it is
-- not a fight the player can plan against. Plain strings, so it rides in a save like everything else on
-- a run (see the `drops` note on why a closure here would take the save write down).
function Descent.packGuard(run, floor, count)
    local sin = Descent.sinAt(run, floor)
    -- The circle's small things. Never its lieutenant: what comes for a spilled pack is what already
    -- lives on this floor, and a named body does not scavenge. Depth does the rest of the work -- a
    -- floor-fourteen gorge fly is a floor-fourteen body (Descent.dangerLevel).
    --
    -- The BOTTOM has no vermin of its own -- Descent.sinAt returns nothing for the Hollow Crown's floor
    -- -- so a pile spilled down there is always somebody else's find, whatever its size.
    local filler = sin and sin.minor and sin.minor.filler
    if filler and (count or 0) < Descent.PACK_COMPANY_ITEMS then
        local list = {}
        for _ = 1, 2 + math.floor((floor or 1) / 4) do list[#list + 1] = filler end
        return "drawn", list
    end
    -- models/warband.lua requires nothing, so this cannot close a cycle back through here.
    local Warband = require("models.warband")
    return "scavengers", Warband.compose({ quest = { descent = run }, day = floor })
end

-- Drop `items` on floor `floor` at (x, y). Snapshotted on the way in, for the reason `drops` gives.
--
-- PILES ACCUMULATE, and a pile is GUARDED. Both halves of that replaced one rule -- dropping a pack
-- used to destroy the last one wherever it was lying -- and the rule is worth writing down because it
-- was load-bearing and its replacement has to carry the same weight.
--
-- WHY IT WENT. It was Dark Souls' bloodstain, and it was borrowed from a game where the thing on the
-- ground is a FLOW: souls come back by playing, so a lost stain is deferred income. Down here the pile
-- is kit, kit comes off the floors, and the Gate store sells draughts and a spare blade -- so the pile
-- is not income, it is the entire economy, and deleting it deleted things the save could never mint
-- again. A second bad night on the way back turned an expensive mistake into a permanent one.
--
-- WHAT REPLACES IT. Deleting a limiter obliges you to name its replacement, and the replacement is that
-- the pile has something standing on it (Descent.packGuard). "What stops the player simply walking
-- back" is answered by a fight rather than by a threat to erase what they are walking back for -- and
-- the fight is priced off the size of the pile, so the walk back is dangerous in proportion to what is
-- lying there rather than in proportion to how badly the player needs it.
--
-- ONE PILE PER TILE. A second wipe on the same square MERGES into the pile already there -- and
-- re-resolves its guard, because the pile just got bigger. One heap, one marker, one guard, one walk
-- back; two piles side by side would be two fights for what was one mistake made twice. Wipes on
-- different tiles are different piles, which is the point. Matched on the square the pile IS LYING ON
-- (Descent.markPacks writes a slid pile's seat back onto it), never the square the bodies fell on --
-- so the pile that merges is the one the player can see.
--
-- ONE PILE PER WIPE rather than one per body, unchanged: the company went down together, in a heap, and
-- four markers on four adjacent tiles would be four walks for one mistake.
--
-- An EMPTY drop is not a drop. A company that wiped carrying nothing leaves nothing, and a marker
-- promising a pack that hands over an empty list reads as a bug however correct the bookkeeping is.
function Descent.dropPack(run, floor, x, y, items)
    if not (run and items and #items > 0) then return nil end
    local Save = require("models.save")
    floor = floor or 1
    run.drops = run.drops or {}

    -- The pile already lying on this square, if there is one. Matched on the tile rather than on the
    -- floor, so two deaths on one floor leave two piles and two deaths on one tile leave one.
    local pile
    for _, d in ipairs(run.drops) do
        if d.floor == floor and d.x == x and d.y == y then pile = d break end
    end
    if not pile then
        run.dropSeq = (run.dropSeq or 0) + 1
        -- An id rather than the table itself, because the board's marker carries a COPY of this entry
        -- through a save (the grid snapshot holds the encounter whole) and Descent.takePack has to be
        -- able to say which pile it is standing on after a reload.
        pile = { id = "drop" .. run.dropSeq, floor = floor, x = x, y = y, items = {}, count = 0 }
        run.drops[#run.drops + 1] = pile
    end

    for _, item in ipairs(items) do pile.items[#pile.items + 1] = Save.snapshotItem(item) end
    pile.count = #pile.items
    pile.guard, pile.guardIds = Descent.packGuard(run, floor, pile.count)
    return pile
end

-- Every pile lying on `floor`, so the board can put a marker on each. Cheap and called once per entry.
function Descent.dropsOn(run, floor)
    local out = {}
    for _, d in ipairs((run and run.drops) or {}) do
        if d.floor == floor then out[#out + 1] = d end
    end
    return out
end

-- The blueprint that supplies a pile's fiction, keyed by the guard drawn when it fell
-- (Descent.packGuard). A pile from before the guard existed names neither and stays a walk-on pickup.
local PACK_BLUEPRINT = { scavengers = "encounter_pack_scavengers", drawn = "encounter_pack_drawn" }

-- WHERE A PILE CAN ACTUALLY BE SEEN, given where it fell. Returns the cell to put the marker on, or nil
-- if there is nowhere on the floor to put one.
--
-- A MARKER MUST NOT GO OVER ANOTHER STOP -- a pack drawn over the way up, or over a fight nobody has
-- cleared yet, deletes the thing underneath it -- and for as long as that rule was the WHOLE of the
-- answer, the common case had no marker at all. The common case is the point: a company wipes at a
-- FIGHT, the fight is lost so its stop stays armed, and the pile lands on a tile that is already spoken
-- for. The pack sat on the run, correctly bookkept and invisible, and the one thing the mode asks you
-- to walk back down for was a coordinate the player had never been shown.
--
-- So the pile SLIDES. The nearest walkable tile with nothing on it, breadth-first from where they fell
-- -- one step, in every case that matters: the doorway of the room they died in. It is also the honest
-- fiction, since a pack does not stay neatly under the body that was carrying it.
--
-- HIDDEN GROUND IS NOT A SEAT. A marker behind a secret door the party has not found is drawn into
-- black (Overworld:isHidden gates the reveal), which is the same invisibility this exists to end.
function Descent.packSeat(grid, x, y)
    if not (grid and x and y) then return nil end
    local start = grid:get(x, y)
    if not start then return nil end
    if not (start.encounter or grid:isHidden(start)) then return start end
    local seen = { [grid:cellKey(x, y)] = true }
    local q, qi = { start }, 1
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(grid:pathNeighbors(c.x, c.y)) do
            local key = grid:cellKey(n.x, n.y)
            if not seen[key] then
                seen[key] = true
                if not (n.encounter or grid:isHidden(n)) then return n end
                q[#q + 1] = n
            end
        end
    end
    return nil
end

-- Put a marker on every pile lying on THIS floor, and take away the ones that have been lifted. Run
-- whenever the list can have changed -- a floor entered, a pile picked up.
--
-- The marker is an `encounter` of kind "pack", for the reason the way up is one (models/overworld.lua's
-- placeExit): the marker pipeline, the fog and the walk-onto-it seam all come free, and a bespoke cell
-- field would have meant writing all three again. It carries the run entry itself, so the stop knows
-- which pile it is standing on without searching.
--
-- THE SEAT IS WRITTEN BACK ONTO THE DROP. Where a pile lies is where its marker is, from the first
-- moment anybody could have seen it -- so a pile that slid off a fight tile (Descent.packSeat) does not
-- slide again on the next visit, a second wipe on the same fight leaves a second pile rather than
-- merging into one the player can no longer find, and the tile the run names is the tile the marker is
-- on. What is given up is the exact square the bodies fell on, which nothing reads and nobody is shown.
-- `player` is optional and is what carries STRANDED piles onto the board -- the ones a closed rift left
-- behind (Descent.strandPacks). They are seated exactly as this run's own are and are indistinguishable
-- once down: the same marker, the same guard, the same walk back. What differs is only where the ledger
-- lives, and a pile the company lost two rifts ago has to be as recoverable as one it lost this hour.
function Descent.markPacks(run, grid, floor, player)
    if not (run and grid) then return 0 end
    -- Clear first, so a pack picked up leaves no marker behind and a re-entry does not double them.
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if c.encounter and c.encounter.kind == "pack" then c.encounter = nil end
        end
    end
    -- This run's piles, then the ones carried over from rifts that closed on them. Concatenated rather
    -- than merged into either ledger: the two are written and cleared by different owners, and a pile
    -- that lived in both would be picked up twice.
    local piles = {}
    for _, d in ipairs(Descent.dropsOn(run, floor)) do piles[#piles + 1] = d end
    for _, d in ipairs(Descent.lostAt(player, floor)) do piles[#piles + 1] = d end

    local n = 0
    for _, drop in ipairs(piles) do
        -- Seated in list order, and each seat is taken as it is filled: two piles that would land on one
        -- tile get one tile each, because the second one's search sees the first one's marker.
        --
        -- A STRANDED PILE HAS NO SEAT TO ASK FOR. Its coordinates named a tile on a board that no longer
        -- exists (Descent.strandPacks drops them deliberately rather than carrying a lie), so the search
        -- starts from the middle of this floor and slides outward to the first free ground -- which is
        -- what packSeat does for every pile anyway. Without this the pile would ask for tile nil and
        -- quietly fail to appear, and the company would dive for something that was never seeded.
        local sx = drop.x or math.max(1, math.floor(grid.cols / 2))
        local sy = drop.y or math.max(1, math.floor(grid.rows / 2))
        local c = Descent.packSeat(grid, sx, sy)
        if c then
            drop.x, drop.y = c.x, c.y
            c.encounter = {
                -- A PILE IS A FIGHT. `id` names the blueprint that supplies the fiction and
                -- `composition` is the cast, drawn once when the company fell and kept on the drop
                -- (Descent.packGuard) so the same company is standing there on the second attempt as on
                -- the first. A drop from before this landed carries neither and stays a walk-on pickup:
                -- a player who put a pack down under the old rules did not agree to fight for it.
                kind = "pack",
                name = "What You Dropped",
                drop = drop,
                id = PACK_BLUEPRINT[drop.guard],
                composition = drop.guardIds,
            }
            n = n + 1
        end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- The way down
-- ---------------------------------------------------------------------------

-- THE STAIR IS A PLACE, NOT A CONSEQUENCE OF A FIGHT.
--
-- It used to be the fight itself: the floor's objective was the guardian, and putting her down walked
-- the company onto the next floor in the same beat. That made the one stop a floor guarantees also the
-- stop that ends it -- so a party that met the stair early lost the floor's caches, its reliquary, its
-- recruit and whatever a house had asked for down here, and lost them to WINNING. The board's whole
-- offer is "how much of this floor is worth the walk", and the answer was being taken out of the
-- player's hands by the one thing they could not decline.
--
-- So the guardian's death OPENS the stair and nothing more. The tile she was holding stops being an
-- objective and becomes the way down, and going down is a step taken when the floor is finished with.
-- Which is also what makes the way up (placeExit's `ascent` stop) a real choice for the first time:
-- two stairs, both places, and the distance between them is the decision.
--
-- LEFT UNCLEARED, and that is what makes it re-enterable: ui/overworld_map.lua fires onEncounter on
-- arrival at any uncleared stop, so the stair answers every time it is walked onto rather than once.
-- It rides in the board snapshot with everything else (Descent.keepFloor), so a floor a company climbs
-- out of and comes back down to still has its stair standing open -- and rearmFloor leaves it alone,
-- because it is a place rather than an inhabitant.
--
-- Takes the CELL rather than finding it off the board, so the caller's "the objective just cleared"
-- and this function's "the tile that becomes the stair" can never disagree -- a floor carries several
-- ends (Descent.floorObjectives) and only one of them is the stair.
function Descent.openStair(cell)
    if not cell then return nil end
    cell.cleared = nil
    cell.encounter = { kind = "stair", name = "The Stair Down" }
    return cell
end

-- ---------------------------------------------------------------------------
-- The floors a company has walked
-- ---------------------------------------------------------------------------

-- Put this floor's board away, exactly as it stands -- fog lifted, stops cleared, secrets found. Called
-- whenever the party leaves a floor by any route (the stair down, the way up), so the next visit gets
-- the map they made rather than a fresh roll.
function Descent.keepFloor(run, floor, snapshot)
    if not (run and snapshot) then return end
    run.floors = run.floors or {}
    run.floors[tostring(floor or 1)] = snapshot
end

-- WHAT COMES BACK WHEN YOU COME BACK. Re-arm a restored floor's fights and leave everything else spent.
--
-- THE MAZE IS PERMANENT, THE MONSTERS ARE NOT, which is Wizardry's own split and the reason its floors
-- stay dangerous forever. There, the level is a fixed map you draw once and the fighting is rolled as
-- you walk, so a floor is never "cleared" -- walking back down to level seven is exactly as dangerous as
-- walking down it the first time. Our fights are seated on tiles instead, so without this a floor a
-- company had finished was an empty corridor and the walk back to a dropped pack cost nothing but time.
--
-- WHAT RE-ARMS is only what LIVES there: combat, elites, and the fights that walk their beat. What
-- stays spent is everything that was a PLACE rather than an inhabitant --
--
--   the stair       its guard is dead and the circle is credited. Waking her would un-earn a boon --
--                   and the stair she was holding is a place now (Descent.openStair), which is why it
--                   is still standing open on a floor the company comes back down to.
--   caches, the reliquary, the recruit, the shrine, the merchant, a crossroads
--   the hazards     a sink you have already fallen through is a hole, not an ambush
--   secret doors    found is found; that is the whole point of keeping the floor
--   a dropped pack  it is yours, and it is not a monster
--
-- AND A RE-ARMED FIGHT PAYS IN FULL. It was tempting to suppress its spoils to stop a company farming
-- a shallow floor forever, and it is the wrong trade: a fight that costs health and turns and hands back
-- nothing does not respect the time it took, and the player who grinds anyway is now grinding for
-- nothing. If the curve ever needs defending from grinding, the lever is the curve
-- (Experience.STEP), never the reward for a fight actually fought. The floor's PLACES stay
-- spent, so re-treading pays combat and nothing else -- no second cache, no second relic -- which is
-- most of the answer on its own.
function Descent.rearmFloor(grid)
    if not grid then return 0 end
    local n = 0
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            if e and c.cleared and (e.kind == "combat" or e.kind == "elite") then
                c.cleared = nil
                n = n + 1
            end
        end
    end
    return n
end

-- The board this company already has for `floor`, or nil for one it has never walked.
--
-- KEYED BY STRING, and that is not a style choice: models/save.lua encodes tables, and a numeric key
-- round-trips through the encoder as a string on some paths and an integer on others -- so a board
-- stored under 3 and looked up under "3" would silently generate a fresh floor after every load, which
-- is precisely the bug this feature exists to prevent and is invisible until somebody notices their map
-- is gone.
function Descent.floorBoard(run, floor)
    return (run and run.floors or {})[tostring(floor or 1)]
end

-- ---------------------------------------------------------------------------
-- What a closed rift leaves behind
-- ---------------------------------------------------------------------------

-- CARRY THIS RUN'S PILES OUT OF IT AND ONTO THE COMPANY, tagged with the depth they were lost at.
--
-- THE PILE IS THE PROBLEM A RESET CREATES. `run.drops` was the right home while a descent outlived
-- every climb-out -- the pile lay on floor nine and you walked back down to floor nine for it. A
-- descent that is thrown away when you leave has no floor nine to walk back to, so the pile would die
-- with the run: an expensive mistake made permanent, which is precisely what Descent.dropPack's own
-- header says the design refuses ("the pile is not income, it is the entire economy").
--
-- SO IT MOVES TO THE PLAYER AND WAITS FOR A DEPTH. `Descent.markPacks` seats a stranded pile on the
-- next run that reaches the floor it was lost on, guard and all -- which makes the walk back a DIVE
-- back, and that is better than it was: you have to earn your way down to your own corpse rather than
-- stroll across ground you had already cleared.
--
-- Called on both exits, because both throw the run away. Idempotent: it empties `run.drops` as it goes,
-- so a second call carries nothing twice.
function Descent.strandPacks(player, run)
    if not (player and run) then return 0 end
    local moved = 0
    player.lostPacks = player.lostPacks or {}
    for _, d in ipairs(run.drops or {}) do
        -- The seat (x, y) is deliberately dropped. It named a tile on a board that no longer exists,
        -- and carrying it would seat a pile at a coordinate the next floor may not even have --
        -- Descent.markPacks finds it a seat on whatever ground it lands on.
        player.lostPacks[#player.lostPacks + 1] = {
            id = d.id, floor = d.floor, count = d.count, items = d.items,
            guard = d.guard, guardIds = d.guardIds,
        }
        moved = moved + 1
    end
    run.drops = {}
    return moved
end

-- The piles this company has left down there, at `floor`. Empty for a depth it has never lost anything
-- on, which is every depth for a company that has never wiped.
function Descent.lostAt(player, floor)
    local out = {}
    for _, d in ipairs((player and player.lostPacks) or {}) do
        if (d.floor or 1) == (floor or 1) then out[#out + 1] = d end
    end
    return out
end

-- Take a stranded pile back off the company's ledger, by id. Called when the pile is picked up, so a
-- recovered pack cannot be seeded again on a later run.
function Descent.claimLost(player, id)
    local list = (player and player.lostPacks) or {}
    for i, d in ipairs(list) do
        if d.id == id then table.remove(list, i) return d end
    end
    return nil
end

-- Pick a dropped pack up off the floor. Returns the LIVE items, rebuilt from their snapshots, and drops
-- the entry -- so a pack is recoverable exactly once and cannot be walked over twice for two copies of
-- everything the company owned.
--
-- MATCHED BY ID FIRST, and identity is only the fallback. The marker the player walked onto carries the
-- entry it was built from (markBodies), and a floor that has been through a save and back hands over a
-- COPY of it -- the grid snapshot stores the encounter whole, drop and all -- so `d == entry` was true
-- exactly until somebody reloaded. It survived the one-pile rule because there was never a second entry
-- for the copy to be confused with; there is now.
-- `player` is optional and is what lets a STRANDED pile be picked up -- one carried over from a rift
-- that closed on it (Descent.strandPacks). Both ledgers are searched, and whichever holds it is the one
-- it comes off, so a recovered pack can never be seeded again.
function Descent.takePack(run, entry, player)
    if not (run and entry) then return nil end
    local pool = {}
    for _, d in ipairs(run.drops or {}) do pool[#pool + 1] = { d = d, run = true } end
    for _, d in ipairs((player and player.lostPacks) or {}) do pool[#pool + 1] = { d = d } end
    for _, slot in ipairs(pool) do
        local d = slot.d
        if d == entry or (entry.id and d.id == entry.id) then
            entry = d -- the live entry, never the marker's copy: it is the one holding the real items
            if slot.run then
                for i, x in ipairs(run.drops) do
                    if x == d then table.remove(run.drops, i) break end
                end
            else
                Descent.claimLost(player, d.id)
            end
            local Item = require("models.item")
            local out = {}
            for _, snap in ipairs(entry.items or {}) do
                local item = Item.instantiate(snap.id, snap.level)
                if item then
                    item.quantity = snap.quantity or 1
                    out[#out + 1] = item
                end
            end
            return out
        end
    end
    return nil
end

-- A PLAYER-SHAPED PROFILE FOR ONE RUN, and the reason this exists rather than a new shape.
--
-- states/game.lua, states/battle.lua, models/spoils.lua, models/wound.lua and the relic stack all take a
-- `player` and read a dozen fields off it. A descent could have been given its own object and every one
-- of them taught a second shape; instead it gets the shape they already know, built by Player.new and
-- then overwritten where a clean run differs from a new campaign. The entire overworld/battle/spoils
-- stack then runs a descent unchanged, which is the same trick Descent.floorQuest plays on the quest
-- format one layer up.
--
-- WHAT MAKES IT A DESCENT'S rather than a campaign's is one field: `saveFile`. Player.save writes to it,
-- so every existing save point in the game persists this company to the descent's file and none of them
-- can reach `save.lua`. See Player.save for why that beats a per-call-site flag.
--
-- `chars` is the company the run walks in with -- one body (Descent.startingCompany), already
-- instantiated with its authored kit. Taken as a list rather than as the id, because what the roster
-- holds is instances and because a run that later starts with two is then a caller's change, not this
-- function's.
function Descent.newProfile(chars)
    local Player = require("models.player")
    local profile = Player.new()

    profile.saveFile = Descent.FILE
    profile.roster = {}
    profile.lastDeployed = {}
    for _, char in ipairs(chars or {}) do
        profile.roster[#profile.roster + 1] = char
        profile.lastDeployed[#profile.lastDeployed + 1] = char.id
    end

    -- A clean run carries in nothing a campaign would have accumulated. Player.new seeds an opening
    -- stash, materials and recipes for a new GAME; a descent's company is the one body it walked in
    -- with, whoever joins it on the way down, and whatever the floors hand them.
    profile.stash = {}
    profile.materials = {}
    profile.recipes = {}
    profile.newItems = {}
    -- NO CAMPAIGN GOLD AND AN OPENING SCRIP PURSE (models/scrip.lua). A run's company has earned the
    -- campaign nothing yet -- gold only exists here as valuables in the pack, and the pack is empty --
    -- and what it walks in with is the coin the floors themselves deal in.
    profile.gold = 0
    require("models.scrip").open(profile)

    -- The campaign's meters, left at their zero. Nothing in a descent moves them any more -- levels come
    -- from what each body does in the fighting now (models/experience.lua) rather than from prestige --
    -- but the fields stay because the shape is Player.new's and Save.snapshot writes all of it.
    profile.completedQuests = {}
    profile.standing = {}
    profile.deepest = 0
    profile.wounds = {}

    -- THE HIRING PURSE, empty (models/voucher.lua). A company at the mouth has beaten no circle, so it
    -- has been handed nothing -- the one voucher it opens the game with is the sponsor's, and she plants
    -- that herself when the prologue's scene closes rather than here.
    profile.vouchers = 0
    profile.bonds = {}
    profile.pulls = 0
    profile.pity = 0

    return profile
end

-- THREE FUNCTIONS STOOD HERE -- hasRun, loadProfile and clearSaved -- and states/descent.lua was
-- the only thing that ever called them. They read and cleared Descent.FILE, the throwaway save
-- the standalone mode kept beside the campaign's; that mode was promoted into the campaign and
-- its screen is deleted, so the three went with it.
--
-- Descent.FILE ITSELF STAYS. Descent.newProfile still stamps it onto a profile's `saveFile`, and
-- tests/descent_spec.lua pins that a run's company never writes save.lua -- which is the rule the
-- separate file existed to keep, and it outlived the screen that read it.

-- How deep the party is standing, 1-based. The only number the difficulty ladder reads.
function Descent.depth(run)
    return (run and run.floor) or 1
end

function Descent.floorLevel(run)
    return 1 + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
end

-- THE ORDER THE CIRCLES ARE MET IN, FIRST TIME THROUGH: Dante's, top to bottom.
--
-- The Inferno is a funnel of nine circles and the sinners get worse as it narrows, so a first descent
-- walks it in the poet's own order. Four of the seven are his outright -- Lust in the second circle,
-- Gluttony in the third, Greed in the fourth, and the Wrathful on the surface of the Styx in the fifth
-- with the Sullen (which is sloth) submerged under them, so sloth is the deeper of that pair. The last
-- two are read from where their sin actually lands in the poem rather than from the Purgatorio's
-- terraces: envy is what Dante blames Florence's ruin on and the envious who ACT are among the
-- fraudulent in the eighth, and pride is the ninth circle itself -- Lucifer frozen at the centre, whose
-- sin was pride and who is the root the other six grew out of.
--
-- WHY IT IS AUTHORED AT ALL, since this was a per-run shuffle and the shuffle was the feature. A
-- permutation makes re-treading the shallow floors tolerable, and that argument is sound -- for a player
-- who has re-tread them. A FIRST descent is not a re-tread: it is the only time the seven circles are
-- new, and dealing them at random spends that once and never gets it back. A player who meets Pride on
-- floor one and Lust on floor thirteen has been handed the fiction backwards, and the game has no way to
-- tell them there was an order. So the first way down is the poem, and the shuffle is what the ending
-- unlocks (see Descent.sinOrder).
--
-- BY ID rather than by rebuilding the table, so a sin's blueprint stays the one authored copy of it and
-- this is only a running order. Every id must name one of Descent.SINS and all seven must appear;
-- tests/descent_spec.lua fails a list that drops or invents one.
Descent.INFERNO = { "lust", "gluttony", "greed", "wrath", "sloth", "envy", "pride" }

-- WHICH SIN THIS FLOOR IS. Dante's order on a first descent, a per-run shuffle once the Crown is broken.
--
-- THE SHUFFLE IS THE POST-GAME, and that is the whole of why there are two orders. A permutation is what
-- makes going back down worth doing -- floors 1..7 are the seven sins in some order, exactly once each,
-- so a re-tread is a different game without the deep floors becoming a lottery (a per-floor PICK would
-- let a run draw Wrath three times and never reach Envy at all). But it is a reward for having seen the
-- authored one, not a substitute for it. So the Demon Lord at the bottom is what turns it on
-- (Player.hasFinishedCampaign, banked when the Crown falls -- states/game.lua), and every run after that
-- deals its own seven.
--
-- A DESCENT HAS A BOTTOM. Seven circles and then the thing at the end of them, which is what makes this
-- a run rather than a treadmill -- the same shape Hades and Dream Quest use: a fixed way down, a boss
-- that ends it, and a reason to go again that lives in the meta rather than in the depth. The order
-- opening up IS that reason, said in the one currency this mode has.
--
-- Derived from the seed and one boolean, never stored as a list. A run is a seed and a depth
-- (Descent.snapshot), and a resume re-derives the whole layout from them; a stored order would be a
-- second copy that could disagree with the seed.
function Descent.sinOrder(seed, shuffle)
    local byId = {}
    for _, sin in ipairs(Descent.SINS) do byId[sin.id] = sin end

    local deck = {}
    if not shuffle then
        -- The poem. Falls back to the authored table order for any id INFERNO fails to name, so a sin
        -- added to Descent.SINS and forgotten here still gets a floor rather than leaving a hole the
        -- run would index into and find nil.
        local placed = {}
        for _, id in ipairs(Descent.INFERNO) do
            if byId[id] and not placed[id] then
                placed[id] = true
                deck[#deck + 1] = byId[id]
            end
        end
        for _, sin in ipairs(Descent.SINS) do
            if not placed[sin.id] then deck[#deck + 1] = sin end
        end
        return deck
    end

    for i, sin in ipairs(Descent.SINS) do deck[i] = sin end
    -- Fisher-Yates driven by the integer hash rather than by math.random: the RNG is shared with
    -- everything else that draws in a frame, so seeding it here would both perturb them and be
    -- perturbed BY them. Pure in, pure out, identical on every machine.
    for i = #deck, 2, -1 do
        local j = (hash(seed, 0, i) % i) + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- How many floors the seven circles cover between them, and how many a whole descent is: that, plus the
-- bottom under them. Fifteen at two floors per circle.
Descent.CIRCLE_FLOORS = #Descent.SINS * Descent.FLOORS_PER_CIRCLE
Descent.FLOORS = Descent.CIRCLE_FLOORS + 1

-- Is this the floor the Hollow Crown is standing on? Everything that behaves differently at the end of
-- a run asks this rather than comparing against a number -- the floor count is one constant and this is
-- one reading of it.
function Descent.isBottom(floor)
    return (floor or 1) > Descent.CIRCLE_FLOORS
end

-- ---------------------------------------------------------------------------
-- The gates: how each circle decides you may fight its general
-- ---------------------------------------------------------------------------

-- A CIRCLE IS ONE FLOOR, SO ITS FLOOR NEEDS A SPINE. With a stratum, the shape of a circle was a
-- lieutenant's stair and then hers; compressed to one board that becomes "walk to the end and fight the
-- boss", which is a corridor. So the general's stair is BARRED, and each circle bars it its own way --
-- a condition read straight off the sin rather than a difficulty knob wearing a fiction.
--
-- SEVEN DIFFERENT KINDS OF CONDITION, which is the point of authoring them one at a time: clear
-- everything, beat a body, pay, carry, kill enough, do nothing, be worth her time. No two circles play
-- the same before their casts are even dealt.
--
-- THE GATE IS ALWAYS LEGIBLE. Its condition is stated from the moment the company lands and carries its
-- own progress where it has any -- a gate the player has to deduce is a puzzle, and this is not a
-- puzzle game. Descent.gateState is the one reading, so the plate, the refusal and any later readout
-- cannot drift apart.
--
-- PURE. It is handed a table of facts about the floor and the company rather than reaching for a grid,
-- a player or a run, so a spec can drive every branch without a board and states/game.lua stays the
-- only thing that knows how to count a cleared cell.
Descent.GATES = {
    clear = { label = "Nothing may be left alive on this floor" },
    ward  = { label = "The ward holds" },
    toll  = { label = "The stair takes its share" },
    carry = { label = "She wants what you are carrying" },
    kills = { label = "Unappeased" },
    none  = { label = nil },
    worth = { label = "She will not fight beneath herself" },
}

-- The gate a circle bars its stair with, or nil for a circle that does not (and for the bottom, which
-- is not a circle). A missing gate reads as none, which is fail-open on purpose: an unauthored gate must
-- leave the game finishable rather than seal a general behind a condition nobody wrote.
function Descent.gateFor(sin)
    local g = sin and sin.gate
    if not g or not g.kind then return nil end
    return g
end

-- IS THE WAY PAST HER OPEN? `facts` is what the caller measured on the board and the company:
--
--   fightsCleared / fightsTotal   won and seated fights on THIS floor
--   wardDown                      the circle's lieutenant end has been beaten
--   carrying                      how many finds are on the mule (models/mule.lua)
--   sealed                        circles this company has already sealed, ever
--   paid                          the toll has been handed over
--
-- Returns `met`, a short `label` naming the condition, and `have`/`need` where the condition counts --
-- so a surface can draw "4 of 7" without knowing which gate it is looking at.
function Descent.gateState(sin, facts)
    facts = facts or {}
    local gate = Descent.gateFor(sin)
    if not gate then return { met = true } end
    local def = Descent.GATES[gate.kind] or {}
    local out = { kind = gate.kind, label = def.label, met = true }

    if gate.kind == "none" then
        return out
    elseif gate.kind == "clear" then
        out.have, out.need = facts.fightsCleared or 0, facts.fightsTotal or 0
        out.met = out.have >= out.need
    elseif gate.kind == "ward" then
        out.met = facts.wardDown == true
    elseif gate.kind == "kills" then
        out.have, out.need = facts.fightsCleared or 0, gate.n or 1
        out.met = out.have >= out.need
    elseif gate.kind == "carry" then
        out.have, out.need = facts.carrying or 0, gate.n or 1
        out.met = out.have >= out.need
    elseif gate.kind == "worth" then
        out.have, out.need = facts.sealed or 0, gate.n or 1
        out.met = out.have >= out.need
    elseif gate.kind == "toll" then
        out.have, out.need = facts.paid and 1 or 0, 1
        out.met = facts.paid == true
    end
    return out
end

-- What the toll costs, in items off the mule. A SHARE of what is being carried, rounded up -- so a
-- company carrying nothing is charged nothing, a full bag pays properly, and the bill can never exceed
-- what is in hand, because a price nobody can pay is a wall rather than a toll.
function Descent.tollFor(sin, carrying)
    local gate = Descent.gateFor(sin)
    if not gate or gate.kind ~= "toll" then return 0 end
    carrying = math.max(0, carrying or 0)
    if carrying <= 0 then return 0 end
    return math.max(1, math.min(carrying, math.ceil(carrying * (gate.share or 0.25))))
end

-- WHICH FLOOR OF ITS CIRCLE THIS IS, 1..FLOORS_PER_CIRCLE. A circle owns a stratum, and the difference
-- between its floors is only ever this number: the biome, the house and the material tagging are the
-- sin's and therefore identical across all of them.
function Descent.floorWithinCircle(floor)
    floor = math.max(1, floor or 1)
    return ((floor - 1) % Descent.FLOORS_PER_CIRCLE) + 1
end

-- Is the sin herself standing on this stair? True on the LAST floor of each circle, which is what makes
-- a stratum a descent toward somebody rather than a set of interchangeable floors. Every other floor of
-- the circle is held by her honour guard, promoted for the occasion (Descent.SINS' `minor`).
--
-- False at the bottom, which is not a circle and has no general -- it has the thing the seven of them
-- were in front of.
function Descent.isGeneralFloor(floor)
    if Descent.isBottom(floor) then return false end
    return Descent.floorWithinCircle(floor) == Descent.FLOORS_PER_CIRCLE
end

-- WHO WAS STANDING ON THIS STAIR, by name -- the general on her own floor, her lieutenant on the ones
-- above it. Read off the character blueprint rather than restated here: the lieutenant is a body from the
-- circle's own cast (Descent.SINS' `minor.lead`) and renaming it in data must not leave a stale copy in
-- this table. Nil at the bottom, which has no sin and names itself.
--
-- Exists because the LANDING says it out loud. Both ranks pay a relic now, and a card that opened over
-- "the stair is clear" said nothing about which of the two fights had just been won.
function Descent.guardianName(sin, isGeneral)
    if not sin then return nil end
    local band = isGeneral and sin.guardian or sin.minor
    local def = band and band.lead and require("models.character").defs[band.lead]
    return (def and def.name) or (isGeneral and sin.name) or nil
end

-- Which circle this floor is. Nil at the bottom, which is not a sin -- it is what the seven of them
-- were in front of.
-- A CIRCLE OWNS A RUN OF FLOORS, so the deck is indexed by which stratum this floor falls in rather
-- than by the floor itself. That one division is the whole of "every floor a sin owns is her ground":
-- biomeAt, the sponsor, the material tagging and the guardian all read through here, so they cannot
-- disagree about where the party is standing.
function Descent.sinAt(run, floor)
    floor = math.max(1, floor or 1)
    if Descent.isBottom(floor) then return nil end
    local circle = math.floor((floor - 1) / Descent.FLOORS_PER_CIRCLE) + 1
    -- `run.shuffled` is stamped once, when the run is opened (Descent.new), rather than asked of the
    -- player here. A run's layout is decided at its mouth and must not move under a company standing
    -- on floor nine -- and this is the one thing about that layout the seed cannot say on its own.
    return Descent.sinOrder(run and run.seed, run and run.shuffled)[circle]
end

-- WHICH COMPANION IS STANDING ON THIS FLOOR, as a vendor id -- the one body waiting at a dead end with
-- one piece of work to ask for (models/errand.lua).
--
-- A SECOND PERMUTATION, DELIBERATELY UNCORRELATED WITH THE SINS. Both are dealt off the run's seed, but
-- with different salts, so the companion standing on floor three has nothing to do with the sin who
-- holds it. Correlating them -- seating each body on its own house's circle -- would make the recruit
-- order and the biome order the same list, and the run would have one permutation where it has two.
--
-- ONE PER FLOOR, WHICH IS THE WHOLE OF THE PACING. It dealt all of them across the first two floors
-- before this, and the compression was defended as a price: every door offered early, climb back for the
-- one you walked past. What it actually did was hand the entire roster over inside two boards. A company
-- that swept floors one and two walked onto floor three complete, and every floor under it was fought by
-- a party that had stopped growing -- so the one reward the descent has that is not gear arrived all at
-- once, at the shallowest point, and never again.
--
-- Spread out, a recruit is what a floor is FOR. Each of the six is met at a different depth, the party
-- is a different shape on every floor, and going one deeper is a body rather than a number.
--
-- THE COST, STATED PLAINLY: an opener hands over slot 0, a band of gear balanced against the shallowest
-- floors (docs/balance.md), so the sixth companion's kit lands well under the depth it is met at. The
-- FIGHT does not have that problem -- Descent.floorObjectives overrides the errand's authored
-- `floorLevel` with the floor's own -- and the payout that matters here is the body, which does not go
-- stale. Rebalancing the openers' `rewardItems` against depth is the follow-up, not a reason to pile six
-- introductions into two boards.
--
-- SIX, NOT SEVEN. The Bastion's companion is Rowan, who is sworn in the prologue, so its opener grants
-- nobody and Errand.houses leaves it out -- the deck is what actually recruits, not what names a body.
-- One sin's floor therefore carries no companion, and which one moves with the seed.
--
-- Derived from the seed, never stored, for the same reason the sins are: a resume re-derives the floor
-- from a seed and a depth, and a stored order is a second copy that can disagree with it. Whether the
-- companion is actually SEATED is a separate question and belongs to the player, not the run -- see
-- Descent.floorObjectives.
local function shuffledHouses(seed)
    -- Off Errand.houses rather than the sins' own vendors: a house whose posting recruits nobody must
    -- not take a floor's slot, and this is the one place that could seat it. Sorted before the shuffle
    -- because `pairs` order is not stable across processes and this deck must be a function of the seed
    -- alone -- an unsorted deck is a resumed run that meets a different body on floor four.
    local deck = {}
    for vendorId in pairs(require("models.errand").houses()) do deck[#deck + 1] = vendorId end
    table.sort(deck)
    for i = #deck, 2, -1 do
        -- Salted off the sins' own shuffle (which passes floor = 0) so the two permutations cannot come
        -- out in step. 991 is arbitrary and only has to be a number the sins never pass.
        local j = (hash(seed, 991, i) % i) + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- Still a LIST rather than one id, and the callers are why: Descent.floorObjectives loops it and the
-- spec counts it. A floor carries at most one today, and the shape says "however many this floor has"
-- so that a later decision to double up on a deep floor is a change here and nowhere else.
function Descent.openersAt(run, floor)
    floor = math.max(1, floor or 1)
    if floor > Descent.CIRCLE_FLOORS then return {} end
    local deck = shuffledHouses(run and run.seed)
    local vendorId = deck[floor]
    return vendorId and { vendorId } or {}
end

-- Which biome this floor wears: its sin's, and the underworld at the bottom -- where the campaign's own
-- ending was always fought (data/quests/quest_the_gate_below.lua). Kept as its own call because the
-- overworld and the landing both ask for the ground by name and neither needs to know what decided it.
function Descent.biomeAt(run, floor)
    local sin = Descent.sinAt(run, floor)
    return sin and sin.biome or "underworld"
end

-- What the landing calls the floor below it: the circle's name, or the thing waiting under all of them.
function Descent.nameOf(run, floor)
    local sin = Descent.sinAt(run, floor)
    return sin and sin.name or "the Hollow Crown"
end

function Descent.floorId(floor)
    return ID_PREFIX .. tostring(floor or 1)
end

function Descent.isFloorId(id)
    return type(id) == "string" and id:sub(1, #ID_PREFIX) == ID_PREFIX
end

-- THE SYNTHESIZED QUEST. Every field here is one states/game.lua actually reads; nothing else is
-- invented, and no field is a function.
--
-- The objective is a `meet` stair: states/game.lua's meet branch (the one the arena debut's walk-out
-- already uses) marks the tile cleared and ends the leg without a fight, which is precisely what a
-- stairwell wants. `ascent = true` puts it on the farthest dead end on the board
-- (Overworld:placeObjectiveAndGates), so the stair is the end of the road rather than a tile you might
-- stumble over on the way to somewhere else.
--
-- WHAT STANDS ON THE STAIR. A set-piece drawn from the circle's own house: one lead body, and filler
-- that thickens with depth so a deep floor's guardian is a wall where a shallow one's is a warning.
--
-- WHICH lead depends on where in the circle's stratum this floor sits. The sin herself holds the LAST
-- floor she owns; every floor above it is held by her honour guard promoted to lead its own
-- (Descent.SINS' `minor`, Descent.isGeneralFloor). So a circle is a descent toward somebody rather than
-- a set of interchangeable floors, and the body that barred your way two floors ago is standing behind
-- her when you finally reach her.
--
-- Deliberately NOT an encounter blueprint. The pool in `data/encounters/` is rollable content, weighted
-- and drawn at random against a biome; a guardian is neither -- there is exactly one per floor and the
-- circle chooses it outright. Routing it through the pool would mean authoring seven blueprints that
-- exist only to be picked by a rule that already knows the answer.
--
-- Read as a quest objective's `composition`, so it opens through the unchanged EncounterBattle path at
-- `kind = "objective"` -- which is what puts it at SET-PIECE scale: Arena.CAP_BY_KIND has no entry for
-- an objective, so the cap falls through to the quest's difficulty (Arena.DEFAULT_ENEMY_CAP, nine) and
-- the skirmish tier never touches it. That fall-through was written for the campaign's objectives and
-- is doing the same job here for free.
local function guardianComposition(sin, floorLevel, isGeneral, floor)
    -- Both halves resolved HERE, outside the closure, so the returned function reads no upvalue that
    -- could have moved by the time the fight is built.
    local band = isGeneral and sin.guardian or sin.minor
    local opening = not isGeneral and Descent.isOpeningFloor(floor)
    return function()
        local list = { band.lead }
        -- Two at the top of the descent, climbing to a full set-piece at the bottom. Read off the floor
        -- rather than off prestige: this fight is a statement about how deep the party has gone, not
        -- about how decorated they are (see models/spoils.lua's GOLD_DEPTH_SLOPE for the same argument
        -- about the gold).
        local n = 2 + math.floor((floorLevel or 1) / 3)
        -- A lieutenant's stair is a smaller thing than his general's, and it has to read that way from
        -- outside: same house, same ground, one body fewer behind it.
        if not isGeneral then n = math.max(1, n - 1) end
        -- ...except on the stair a descent OPENS on, where that subtraction left one swarm body holding
        -- the end of the road and made it the lightest fight on the board. See Descent.OPENING_GUARD.
        if opening then n = math.max(n, Descent.OPENING_GUARD) end
        for _ = 1, n do list[#list + 1] = band.filler end
        return list
    end
end

-- THE BOTTOM. Lifted whole from data/quests/quest_the_gate_below.lua rather than reinvented: the
-- Hollow Crown, its honour guard, its confrontation scene and the assassinate condition are all
-- authored content that already works, and the campaign reaching the same body by a different road is
-- not a reason to write it twice. What the descent changes is only the way in -- seven circles instead
-- of seven generals' keys.
--
-- The guard thickens with the FLOOR rather than with prestige, like every other stair on the way down.
local function crownComposition(floorLevel)
    return function()
        local list = { "character_demon_lord" }
        for _ = 1, 2 + math.floor((floorLevel or 1) / 4) do list[#list + 1] = "character_champion" end
        return list
    end
end

-- WHAT A FLOOR IS GUARANTEED TO HOLD, whatever the weighted draw does with the rest of it.
--
-- These are the generator's own default (models/overworld.lua's placeEncounters), restated because
-- naming any of them REPLACES the list rather than adding to it -- a floor that asked only for one
-- would lose the others.
--
-- A THIRD STOP STOOD HERE TWICE AND IS GONE BOTH TIMES. First a RECRUIT: somebody standing where you
-- came through, taken on or walked past. It latched shut -- it could only seat while the company had
-- ROOM, and nothing ever left a company, so it stopped seating for good once four bodies were held,
-- which was the second floor of the first run. Then a HEROIC SPIRIT, the same place rebuilt around a
-- payout that could not fill up: a crossing token, which had no cap.
--
-- The Crossing is retired and the token with it, so the spirit was a stop that paid nothing. What it
-- was FOR is worth keeping in view if a third stop is ever wanted here: a reason to open the floor up
-- rather than beeline the stair, and a reward the player steers toward rather than one that happens to
-- them.
local function guaranteeKinds(player, floor)
    -- THE WEEPING STONE IS GUARANTEED FROM THE SECOND FLOOR, and the depth gate is the whole of why it
    -- is listed conditionally rather than always. It sells a relic for a permanent cut to the company's
    -- maximum health, and a company that has not yet been hurt has nothing to weigh that against -- on
    -- floor one it is a number, and by floor two it is a decision.
    --
    -- Guaranteed rather than left to the weights because it is the only stop that prices a relic in
    -- something a purse cannot cover. A run that never met one would never be offered that trade at all,
    -- and a way to spend that turns up sometimes is a way to spend nobody builds around.
    if floor and floor >= 2 then
        return { "relic_cache", "rest", "merchant", "weeping_stone" }
    end
    return { "relic_cache", "rest", "merchant" }
end

function Descent.floorQuest(run, player)
    local floor = Descent.depth(run)
    local sin = Descent.sinAt(run, floor)
    local floorLevel = Descent.floorLevel(run)
    -- Is the sin herself on this stair, or her honour guard holding it for her? The one thing that
    -- differs between the floors of a circle: the ground, the house and the tagging are all hers either
    -- way (Descent.sinAt).
    local general = Descent.isGeneralFloor(floor)
    -- Wider the further down. See Descent.floorDims.
    local cols, rows = Descent.floorDims(floor)

    -- EVERY END THIS FLOOR CARRIES, resolved BEFORE the board is described rather than inside it, because
    -- the ends are now part of the board's own budget: each one is a fight the pool does not get to deal
    -- (Descent.floorBudget). The Crown has no houses posting work on it and carries the one end below.
    local objectives = sin and Descent.floorObjectives(player, floor, sin, floorLevel, general, run) or nil
    local stops, rolled = Descent.floorBudget(objectives and #objectives or 1, floor)

    if not sin then
        return {
            id = Descent.floorId(floor),
            name = "The Descent — The Hollow Crown",
            description = "The bottom.",
            -- No house holds this floor, so nothing tags its materials. Deliberate: the last floor is
            -- not anybody's errand.
            sponsor = nil,
            floorLevel = floorLevel,
            dangerLevel = Descent.dangerLevel(run),
            descent = run,
            -- What states/game.lua reads to know that clearing this objective ENDS the run rather than
            -- opening another landing. Named on the descriptor rather than inferred from the depth, so
            -- the state never has to learn how long a descent is.
            endsDescent = true,
            map = {
                biome = "underworld",
                ascent = true,
                cols = cols,
                rows = rows,
                encounters = stops,
                cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
                keyCount = 0,
                -- The way back up, standing on the tile the party walks in on. See EXIT below.
                exitAtStart = true,
                -- Places that read as absent until somebody looks (Overworld:placeSecrets).
                secrets = true,
                -- An absolute cap, not a share -- and the Crown's own end is already subtracted from it
                -- above. See Descent.FLOOR_FIGHTS.
                combatBudget = rolled,
                guaranteeKinds = guaranteeKinds(player, floor),
                guarantee = { rest = { count = Descent.FLOOR_RESTS } },
                objective = {
                    name = "The Hollow Crown",
                    -- The only seam the Crown can speak from: by the time an outro runs, an
                    -- assassinate target is already dead.
                    --
                    -- The DESCENT'S scene, not the campaign finale's. That one is written for the
                    -- avatar and is made of blocks answering for each companion who knew one of the
                    -- seven; a descent has neither, so it played an avatar's lines with no avatar in
                    -- the room and skipped everything else. See the scene's own header.
                    opening = "conversation_descent_crown",
                    composition = crownComposition(floorLevel),
                    win = { type = "assassinate", target = "character_demon_lord" },
                },
            },
        }
    end

    return {
        id = Descent.floorId(floor),
        name = "The Descent — " .. sin.name,
        description = "Down.",
        -- The circle's house. states/game.lua resolves `game.houseMaterial` from this through
        -- Vendor.get(...).class, so naming the vendor is the whole of the material tagging: the floor's
        -- caches and every fight on it pay into that house's stock.
        sponsor = sin.vendor,
        -- Which circle this is, for anything that wants to say so without re-deriving the shuffle (the
        -- landing names the one below, and from stage 4 extraction banks standing against it).
        sin = sin.id,
        floorLevel = floorLevel,
        -- What the world fights at down here. Distinct from `floorLevel`, which is the per-fight
        -- MINIMUM a set-piece can raise; this is the level ordinary stock is grown to. See
        -- Descent.dangerLevel for why the day cannot do this job.
        dangerLevel = Descent.dangerLevel(run),
        -- ...and how many bodies it fields them in. Nil on every floor but the first, which is the one
        -- board whose company is known in advance. Read by Arena.enemyCap as a ceiling, so it reaches
        -- the rolled fight, the errand at its dead end, and the marker each is drawn from, all through
        -- the one field. See Descent.OPENING_CAP.
        enemyCap = Descent.isOpeningFloor(floor) and Descent.OPENING_CAP or nil,
        -- The field states/game.lua keys the whole feature off. Carried by reference: the state reads it
        -- to know it is in a descent and to park it on player.activeRun.
        descent = run,
        map = {
            biome = sin.biome,
            ascent = true,
            -- Pinned, all three of them, and each for its own reason -- see the constants. The board is
            -- pinned per FLOOR rather than flat: it widens a tile a floor (Descent.floorDims), while the
            -- stop count and the cache count stay put and the floor gets sparser as it gets deeper.
            cols = cols,
            rows = rows,
            -- The texture count plus whatever fights the ends left unspent. See Descent.floorBudget.
            encounters = stops,
            cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
            -- keyCount 0 because a floor is not a lock puzzle: the stair is always reachable.
            keyCount = 0,
            -- The way back up, standing on the tile the party walks in on. See EXIT below.
            exitAtStart = true,
            -- Two or three places that read as absent until somebody looks (Overworld:placeSecrets).
            secrets = true,
            -- HOW MANY FIGHTS THE POOL MAY DEAL, absolute, and the stair and every errand and opener on
            -- this floor have already been taken off it (Descent.floorBudget). A share could not do this
            -- job: the ends are seated by a different pass and were never inside the fraction.
            combatBudget = rolled,
            -- The reliquary, the rest, and -- while there is room in the company -- somebody to join it.
            guaranteeKinds = guaranteeKinds(player, floor),
            -- ...and how many of each, where a floor differs from a ground. See Descent.FLOOR_RESTS.
            guarantee = { rest = { count = Descent.FLOOR_RESTS } },
            objective = {
                -- THE END IS NAMED FOR WHO IS STANDING ON IT, not for what is under them.
                --
                -- It read "The Stair Down — <Sin>", and that gave the floor away. A board's own end is
                -- named on its marker and in the hovered readout, so the moment the fog lifted off that
                -- place the player had been told where the exit was -- before meeting the thing holding
                -- it. The stair is meant to be found UNDER the guardian: you meet a body at the end of
                -- the road, you put it down, and the way down is what it was standing on
                -- (Descent.openStair renames the cell at that moment, and only then).
                --
                -- `guardianName` is the landing card's own function, so the name on the marker and the
                -- name the landing reports are one string and cannot drift.
                name = Descent.guardianName(sin, general) or "The Guard",
                -- SHE SPEAKS ONLY ON HER OWN STAIR. The scene is hers, and a lieutenant playing it
                -- would have the general talking through a body she is standing two floors below. A
                -- minor floor opens in silence, which is also what makes hers land.
                opening = general and sin.scene or nil,
                composition = guardianComposition(sin, floorLevel, general, floor),
                -- The stair opts out of the floor's own body ceiling (Descent.OPENING_CAP). What the
                -- circle put on it is what stands there.
                enemyCap = false,
                win = { type = "killAll" },
            },
            -- ...AND WHATEVER A HOUSE HAS ASKED FOR DOWN HERE. See Descent.floorObjectives. Resolved at
            -- the top of this function rather than here, because the fight budget above is spent on it.
            objectives = objectives,
        },
    }
end

-- EVERY END THIS FLOOR CARRIES: the stair, one per errand a house has asked for down here, and -- if a
-- house with a shut door has work posted on this floor -- the job that opens it.
--
-- The stair is ALWAYS FIRST, because states/game.lua resolves "the objective" as `objectives[1]` before
-- it falls back to `objective` -- so a floor whose errand sorted ahead of its stair would treat the
-- errand as the thing that ends the floor.
--
-- An errand becomes an objective spec exactly as a quest does on a campaign ground (models/quest.lua's
-- Quest.trip): its own composition, its own win condition, stamped with `questId` so the payout knows
-- which piece of work was finished. The generator gives each its own dead end, which is what a ground
-- carrying three quests has always done -- so a floor with an errand on it is that same shape, and the
-- stair is simply one of two things worth walking to.
function Descent.floorObjectives(player, floor, sin, floorLevel, general, run)
    local stair = {
        -- Named for the body on it rather than for the stair beneath it -- see the descriptor's own
        -- `objective` above for why, and Descent.openStair for when the name changes.
        name = Descent.guardianName(sin, general) or "The Guard",
        opening = general and sin and sin.scene or nil,
        composition = guardianComposition(sin, floorLevel, general, floor),
        -- Exempt from the opening floor's ceiling, exactly as the descriptor's own `objective` is: a
        -- floor cut to the size of the company that walks in still ends on the fight the circle put
        -- there. See Descent.OPENING_CAP.
        enemyCap = false,
        win = { type = "killAll" },
        floorLevel = floorLevel,
    }
    -- THE WARD, for a circle that bars its stair with a body (Descent.GATES' `ward`). One more end on
    -- the floor, at its own dead end like every other -- the lieutenant who used to hold a stair two
    -- floors up, standing on this one because her circle no longer has two floors.
    --
    -- Marked `wardFor` rather than given a questId: it settles nothing on a shelf and pays no purse, so
    -- the errand payout must not see it. What beating it does is open the stair, which states/game.lua
    -- reads off this mark.
    local ward
    if general and sin then
        local gate = Descent.gateFor(sin)
        if gate and gate.kind == "ward" then
            ward = {
                name = Descent.guardianName(sin, false) or "The Ward",
                composition = guardianComposition(sin, floorLevel, false, floor),
                enemyCap = false,
                win = { type = "killAll" },
                floorLevel = floorLevel,
                wardFor = sin.id,
            }
        end
    end

    if not player then
        local out = { stair }
        if ward then out[#out + 1] = ward end
        return out
    end

    -- One errand-shaped entry becomes one end on the board. Shared by the two kinds this floor can carry
    -- -- the jobs a house ASKED for and the one it cannot ask for -- because they are the same object: a
    -- quest blueprint's objective, stamped with the id that says which piece of work it settles.
    local function specFor(entry)
        local spec = {}
        for k, v in pairs(entry.map and entry.map.objective or {}) do spec[k] = v end
        spec.questId = entry.id
        spec.name = spec.name or entry.name
        -- The floor's own difficulty, not the errand's authored `floorLevel`. That number was written
        -- for a campaign ground reached on a particular day; down here the only honest answer to "how
        -- hard is this" is how deep the company has walked.
        spec.floorLevel = floorLevel
        -- Salvages in the house that asked for it, which is the same rule a sponsored quest follows.
        spec.houseMaterial = require("models.material")
            .houseFor((require("models.vendor").get(entry.sponsor) or {}).class)
        return spec
    end

    local Errand = require("models.errand")
    local out = { stair }
    if ward then out[#out + 1] = ward end
    for _, entry in ipairs(Errand.onFloor(player, floor)) do
        out[#out + 1] = specFor(entry)
    end

    -- THE DOOR-OPENING JOB, seated for a house that has no door to ask through.
    --
    -- Never accepted, because there is nowhere to accept it: Errand.accept is reached from inside a
    -- shop, and this house's shop does not exist yet. It is simply lying on the floor, at its own dead
    -- end like every other end here, and finishing it opens the shop and counts as that house's first
    -- errand in one stroke (models/errand.lua's Errand.opener).
    --
    -- Skipped once its door is open, which is what stops a house that already trades from posting the
    -- job that would have introduced it -- and it is why a later run's first circle is a thinner place
    -- than a first run's: only the doors still shut are lying there. A house met and walked past keeps
    -- its posting on the floor that carried it, and the only way back is up (Descent.openersAt: every
    -- door is dealt into the first circle, because an opener hands over slot 0 and slot 0 is balanced
    -- for exactly those floors).
    -- THE COMPANIONS, AND A RECRUIT IS TWO BEATS.
    --
    --   1. YOU MEET THEM    at the doorway of the chamber their work is standing in. The scene
    --                       plays, they ask, and accepting costs nothing but the walk in.
    --   2. YOU DO THE THING they asked for, which is the fight inside. Clearing it is what brings
    --                       them into the company (the quest's own `rewardCharacter`).
    -- BOTH BEATS HAPPEN AT ONE END, and that is capacity rather than taste. A shallow floor carves
    -- about seven and a half dead ends and the stair takes one, so seating the meeting as an end of
    -- its own would have put two spurs per companion on a floor that already deals three or four
    -- of them -- and the generator would start degrading them onto shared ground.
    --
    -- So the meeting is the DOORWAY and the ask is the room behind it (game:askErrandAtDoor). The
    -- company steps up to the chamber, the body standing there asks, and accepting only opens the
    -- way -- they still have to walk in and win it. Refusing costs nothing at all, because the
    -- company never stepped through; the job stays where it is, to be walked back to whenever.
    for _, house in ipairs(Descent.openersAt(run, floor)) do
        local openerId = not Errand.doorOpen(player, house) and Errand.opener(house)
        local openerDef = openerId and require("models.quest").defs[openerId]
        if openerDef and openerDef.map and openerDef.map.objective then
            local spec = specFor({
                id = openerId,
                name = openerDef.name,
                sponsor = openerDef.sponsor,
                map = openerDef.map,
            })
            out[#out + 1] = spec
        end

    end

    return out
end

-- ---------------------------------------------------------------------------
-- The depth record: how far this COMPANY has ever got
-- ---------------------------------------------------------------------------
--
-- `run.cleared` is what one expedition beat and it dies with the run (states/game.lua nils
-- `player.descentRun` when a descent ends). `player.deepest` is the company's own high-water mark and
-- outlives every run, which is what the city grows on: the Cafe opens at floor two and the Forge at
-- floor four (data/buildings/), and a door that shut again because the last expedition was short would
-- be a city that forgets.
--
-- THE FIELD IS OLD AND WAS INERT. It was the descent's depth record back when a run banked into the
-- campaign save and levelled the company off the record so it could not be farmed; that went when the
-- descent was made a separate mode, and the field survived in models/player.lua and models/save.lua
-- reading "nothing writes this and nothing reads it". The descent is the campaign again, so it has a
-- writer and a reader once more, and it means what it always meant.
--
-- REACHED, NOT CLEARED, and the two gates it feeds are why. What the Cafe and the Forge are asking is
-- how far down this company has been -- a body that walked onto floor four has seen floor four, whether
-- or not it beat what was standing there. `cleared` is the harder question and it already has a home on
-- the run, where the payouts read it.

-- The deepest floor this company has ever stood on. Zero for one that has never gone down.
function Descent.deepest(player)
    return (player and player.deepest) or 0
end

-- The party has arrived on `floor`. Monotone: climbing out and going back down to floor three cannot
-- lower a record set at eight.
--
-- Called from ONE seam -- states/game.lua's game.enter, which is where a floor descriptor becomes a
-- board the company is standing on. The three callers that build a descriptor (the Gate's stair, the
-- landing's "go down", a floor that gives way) all funnel through it, so the record cannot be missed by
-- adding a fourth way down.
function Descent.reached(player, floor)
    if not (player and floor) then return end
    player.deepest = math.max(player.deepest or 0, floor)
    return player.deepest
end

-- ---------------------------------------------------------------------------
-- The count: what the company left forming behind it
-- ---------------------------------------------------------------------------
--
-- IT IS ISELLE'S TALLY, AND THE FICTION FOR IT IS THE FIRST CONVERSATION IN THE GAME. The capital sits
-- on the Rift, four houses pay companies to dig it, and the other half of that trade is that the floors
-- do not stay dug: nothing down there is born, it FORMS, out of whatever is at the bottom of the hole.
-- The Crown pays by the floor to keep the number down and the trade calls it pruning. Leave the deep
-- floors unpruned and the count climbs, and what is down there comes up the stair and out into the
-- country -- which is Bellmere, which is the fight the game opens on
-- (data/conversations/prologue/conversation_prologue_sponsor.lua).
--
-- WHAT IT IS FOR, MECHANICALLY. Every other event in the loop is already priced and priced well: a wipe
-- drops the haul as a pack with a guard on it, takes most of the purse and wounds every head
-- (states/game.lua's onLoss). Healing is free, a bed is twenty-five a head. The one move that cost
-- NOTHING was the voluntary climb-out -- it banked, it kept the mapped floor, and the city handed over a
-- full restore on arrival -- so the optimal play was to walk back to the ascent tile after every fight,
-- go up, heal, and come back down to a floor already cleared and already lit. This is the price on that,
-- and it is deliberately the only thing being priced.
--
-- WHY THIS EVENT AND NOT A CHEAPER ONE. A cost on healing, on a bed, or on a rest is a tax on NEEDING to
-- recover, and needing to recover is what being bad at the game looks like; a bounded allowance is the
-- same defect wearing a counter, since a cap is equal in supply and unequal in impact -- only the
-- struggling player ever reaches it. The voluntary climb-out is the one event in the loop that is a
-- decision with an alternative rather than a need, and the failure case (the wipe) is exempt, so the
-- player having the hardest time is the one who pays this least.
--
-- IT MOVES BOTH WAYS, which is what keeps it from being a countdown:
--
--   climbing out        +1   the floor you walked away from starts filling again
--   reaching a floor    -1   pruning (Descent.advance, below -- the one seam a floor number rises at)
--   sealing a circle    -2   a general felled on her own floor (Descent.clearFloor)
--
-- So a company that withdraws once a floor and keeps descending sits at nought forever and never learns
-- the number exists, which is right: that is the pacing move the ascent tile was built for. A company
-- that climbs out after every fight nets seven a floor.
--
-- THE MAXIMUM IS PROVISIONAL AND IS MEANT TO BE MEASURED, not derived. Nothing reads it yet except the
-- readout and the bands below: what happens when it is reached -- the stair stops being an exit and what
-- is down there comes up with you -- is deliberately not wired, because it should be built against a
-- played descent rather than against an estimate. See docs/the-count.md.
--
-- IT WAS TWENTY-FIVE AND THAT WAS TOO SLACK. A full descent pays back twenty-eight on its own (fourteen
-- floors stepped onto, seven circles sealed), so at twenty-five even a careless company finished the run
-- around half full and the city never went dark on anybody. Fifteen puts a company that withdraws three
-- times a floor near the top by the bottom of the rift, which is the band where the plaza boards up, and
-- leaves a shuttle full on floor three.
--
-- WHAT LOWERING IT DOES NOT DO, because it is worth knowing before it is moved again: it does not touch
-- the careful player at all. One withdrawal a floor nets zero against the stair's own payback and two a
-- floor is cancelled exactly by the seals, so both sit at nought whatever this number is. The maximum
-- decides how fast the CARELESS fill; the ratios below decide whether the careful ever move. If ordinary
-- play should feel this, the dial is COUNT_SEAL, not COUNT_MAX.
Descent.COUNT_MAX = 15

-- What a felled general takes off it. Two rather than one because a circle is two floors
-- (Descent.FLOORS_PER_CIRCLE), so a seal pays back the floor it stood on and the one above it.
Descent.COUNT_SEAL = 2

-- The bands, as the lowest count each begins at. Ordered deepest-first so a lookup walks it and stops.
--
-- MOST OF THEM SAY NOTHING, and that is the point of a meter. The marks already say where the tally
-- stands; a line of prose under them restating it in words is the same fact twice, and a card that
-- always carries a sentence has no way to raise its voice when it needs to. So the bottom two bands are
-- marks alone, and the warning is the only text this readout ever shows.
--
-- It is drawn at the point where the number stops being bookkeeping and starts being a thing about to
-- happen -- two thirds of the way up -- so its arrival IS the signal. The player learns the marks first
-- and the words only when it matters.
--
-- THE TOP TWO USED TO SHARE ONE STRING, and this is the note that said when they would stop. "Breach
-- imminent" was as true at the ceiling as one below it, and what a full tally ought to say differently
-- was the ending firing -- which was not built. A readout announcing "it is coming up the stair" over a
-- stair that politely went to town would have been the game making a claim it does not keep, so the top
-- band reported the state and promised nothing.
--
-- IT IS BUILT (Descent.isBreached, and states/game.lua's ascent branch), so the promise is kept and the
-- top band says the event. The one below it goes on warning, which is the whole ladder working: the
-- orange band is the last morning on which the stair is still a way home.
--
-- SPACED TO THE READOUT'S GROUPS OF FIVE, not to arithmetic thirds. The marks are drawn in fives
-- (ui/count_meter.lua) and each mark wears its own band's colour, so a boundary that falls inside a
-- group renders as four green and one yellow sitting together -- which reads as an off-by-one rather
-- than as a ladder. Measured on screen, not guessed. Sitting them on 6 and 11 makes the first group
-- wholly green, the second wholly yellow, and the last orange with a single red cap on the mark that
-- is the ceiling.
--
-- Moving COUNT_MAX must move these with it: a band table left at its old thresholds when the ceiling
-- drops is three bands nobody can reach and one that is the whole meter. tests/count_spec.lua walks
-- every value from nought to the maximum against them.
Descent.COUNT_BANDS = {
    { at = 15, id = "up",       phrase = "It is on the stair" },
    { at = 11, id = "unpruned", phrase = "Breach imminent" },
    { at = 6,  id = "climbing" },
    { at = 0,  id = "low" },
}

-- What the tally reads. Zero for a company that has never come back up early.
--
-- IT LIVES ON THE PLAYER, NOT ON THE RUN, and that move is what makes the tally mean anything at all
-- once an expedition stops being the whole story. It was `run.count`, which was correct while a run
-- outlived every climb-out: the company went up, the run stayed open, and the number was still there
-- when they walked back down. Under a descent that RESETS on extraction there is no run in the city to
-- read, so a tally on the run would fall to nought the moment it mattered most -- and the breach it is
-- counting toward could never fire, because nothing would ever reach the ceiling.
--
-- models/save.lua said this out loud before it was true: `climbedOut` is persisted on the player as a
-- one-way mark precisely because "Iselle's tally falls back to nought the moment they descend again and
-- the readout it gates must not come off the plaza the morning after it was earned". The mark no longer
-- has to cover for the number. They are both the company's now.
--
-- THE STATE OF THE RIFT IS NOT A PROPERTY OF ONE EXPEDITION. That is the design reading and it is the
-- reason this is not merely a save-location change: the deep floors go unpruned whoever left them that
-- way, and the count is what the country is carrying, not what a trip did.
function Descent.count(player)
    return (player and player.count) or 0
end

-- Which band a raw tally of `n` stands in. Returns the band table (id, phrase), never nil.
--
-- Split out from countBand because the READOUT needs it per MARK rather than per run: each mark in the
-- row is coloured by the band it belongs to, so the meter climbs green, yellow, orange, red as it fills
-- (ui/count_meter.lua). Mark i is the mark a count of i lights, so bandAt(i) is exactly its band.
function Descent.bandAt(n)
    n = n or 0
    for _, band in ipairs(Descent.COUNT_BANDS) do
        if n >= band.at then return band end
    end
    return Descent.COUNT_BANDS[#Descent.COUNT_BANDS]
end

-- Which band this company stands in.
function Descent.countBand(player)
    return Descent.bandAt(Descent.count(player))
end

-- Move the tally by `delta`, floored at zero and capped at the maximum. Returns the new count.
--
-- Floored rather than allowed to go negative: a company that seals every circle on the way down would
-- otherwise bank a large credit against withdrawals it has not made yet, and "I may now come up eleven
-- times for free" is a resource, not a pacing rule. The tally is a statement about the state of the
-- rift right now, not a purse.
function Descent.countBy(player, delta)
    if not player then return 0 end
    player.count = math.max(0, math.min(Descent.COUNT_MAX, (player.count or 0) + (delta or 0)))
    return player.count
end

-- UP ONE FLOOR, to the floor above and the stair they came down by.
--
-- A DESCENT HAD ONE DIRECTION, and that was the gap this fills. The way up on a floor offered exactly
-- one thing -- climb out of the rift entirely -- so a company that wanted to walk back to a pack it
-- dropped on floor four, or to a shop it passed on floor two, had to end the expedition to do it and
-- then re-descend from the top. Wizardry's stairs run both ways and the floors are kept precisely so
-- they can (Descent.keepFloor): the map you made is still there, so the only thing missing was a door
-- back to it.
--
-- IT COSTS ONE ON THE TALLY, and it has to, symmetrically with Descent.advance taking one off. Going
-- down prunes the rift by one; if coming back up were free, a company could walk a stair up and down
-- between two floors and drive the count to zero for the price of the walking. That would make the
-- tally a purse rather than a statement about the state of the rift, which is the exact thing
-- Descent.countBy's own header refuses. Up and down is now net zero, which is what "no progress" should
-- cost.
--
-- WHERE YOU COME OUT is the floor above's own stair down -- the place you left it by -- rather than its
-- entrance. Arriving at the far end of a floor you already crossed would be a teleport wearing a
-- staircase, and it would hand back for free the walk that going up is supposed to cost. Read off the
-- kept board's own `objective`, which is the cell Descent.openStair converted when that floor's guard
-- fell; a floor with no kept board (which should not happen -- you descended through it) falls back to
-- its entrance rather than refusing the move.
function Descent.retreat(run, player)
    if not run then return nil end
    local from = Descent.depth(run)
    if from <= 1 then return nil end -- floor one's way up is the way OUT, and that is a different card
    run.floor = from - 1
    -- `player` because the tally is the company's rather than the run's (Descent.count). Optional, so a
    -- spec driving a bare run still walks the floors; what it loses is only the number moving.
    Descent.countBy(player, 1)
    local board = Descent.floorBoard(run, run.floor)
    run.arriveAt = board and board.objective and { x = board.objective.x, y = board.objective.y } or nil
    return run.floor
end

-- The company took the ascent stair. THE ONE CALLER IS states/game.lua's ascent branch and it must stay
-- that way: a wipe also ends an expedition and also wakes the company at the Rift, and it is exempt --
-- it already costs the haul, the purse and a wound on every head, and charging the failure twice is the
-- exact thing this design is built not to do.
function Descent.climbOut(player)
    return Descent.countBy(player, 1)
end

-- ---------------------------------------------------------------------------
-- The breach: what the tally is counting toward
-- ---------------------------------------------------------------------------

-- IS THE STAIR STILL AN EXIT? At the ceiling it is not, and this is the one question that asks.
--
-- THIS IS WHAT THE COUNT WAS ALWAYS FOR, and until now it was the one thing about it that was not built
-- -- docs/the-count.md said so under "What is not built", and COUNT_BANDS' top band was left sharing a
-- warning with the band below it precisely so the readout would not promise an event nothing delivered.
-- It delivers now, so the top band has a line of its own.
--
-- IT IS ALSO WHAT REPLACED THE FORTIETH DAY. The campaign had a deadline once -- the demon lord landed
-- on a date, and every general left unfelled stood beside him (models/calendar.lua) -- and that clock
-- measured a Quest Board that no longer exists. This is the same ending arrived at the other way round:
-- not a date, but a company that shuttled up and down until the floors it kept walking away from filled.
--
-- A COMPANY THAT PRESSES ON NEVER SEES IT. That is the design, not an oversight: one withdrawal a floor
-- is cancelled by the stair's own payback and two are cancelled by the seals, so the ceiling is reached
-- only by shuttling (docs/the-count.md measures all four play styles). Which also means this is never a
-- softlock -- the way back down is always open, every new floor pays a mark off, and every circle sealed
-- pays two. The company that meets the breach walked itself into it and can walk itself out.
function Descent.isBreached(player)
    return Descent.count(player) >= Descent.COUNT_MAX
end

-- WHO COMES UP THE STAIR. The Hollow Crown, and every general whose circle is still unsealed.
--
-- Iselle's own line is the spec (data/conversations/prologue/conversation_prologue_sponsor.lua): the
-- deep floors go unpruned, the count climbs, and what is down there comes up and out into the country.
-- What is down there is what is at the bottom, so the fight is the bottom's -- met on floor three in a
-- corridor rather than on its own ground, which is the point.
--
-- SIZED BY WHAT THE PLAYER DID, through the same reading the retired finale was sized by
-- (Calendar.generalsStanding): felling a general on her own floor seals her circle and takes her out of
-- this list. Seven standing is a wall; none standing is a duel. Neither is arbitrary -- both are the
-- campaign's own record of the run, and the only thing that shortens the list is having gone down.
--
-- NAMED BODIES FIRST, and that is load-bearing rather than tidy. Arena.clampComposition keeps one of
-- every DISTINCT id ahead of any repeated filler and yields outright when the distinct cast alone
-- exceeds the ceiling, so the generals cannot be trimmed off by an arena cap -- while the champions
-- behind them are exactly what a cap is for. A breach that quietly dropped three of the seven would be
-- a fight reporting a threat it did not field.
--
-- Returns a PLAIN LIST OF IDS rather than the composition function a descriptor carries, and that is a
-- storage fact: this cast is written onto a cell (states/game.lua's ascent branch) and a cell rides in a
-- save, so a function could never survive the trip. It is the same reason a dropped pack's guard is
-- drawn once and kept (Descent.packGuard) -- and it has the same welcome side effect, that the fight
-- standing on the stair is the same fight on the second attempt as on the first.
function Descent.breachComposition(player, floorLevel)
    local list = { "character_demon_lord" }
    local sealed = (player and player.descentRun and player.descentRun.standing) or {}
    for _, sin in ipairs(Descent.SINS) do
        if (sealed[sin.vendor] or 0) <= 0 then
            list[#list + 1] = sin.guardian.lead
        end
    end
    -- The horde behind them, thickening with depth exactly as the Crown's own guard does.
    for _ = 1, 2 + math.floor((floorLevel or 1) / 4) do list[#list + 1] = "character_champion" end
    return list
end

-- Has this company ever come back up early? A ONE-WAY MARK ON THE PLAYER rather than a reading of the
-- live tally, and for the same reason the Inn's door is (models/wound.lua's Wound.everWounded): the
-- count falls back to nought the moment the company descends again, so a readout that asked the ledger
-- would come off the plaza the morning after it was earned, having taught nobody anything.
--
-- It is what the readout and Iselle's scene are gated on. Before the first climb-out the Rift card is
-- exactly what it is today.
function Descent.everClimbedOut(player)
    return (player and player.climbedOut) or false
end

function Descent.markClimbedOut(player)
    if not player then return false end
    player.climbedOut = true
    return true
end

-- Has Iselle explained the tally yet? A SECOND one-way mark, and the two are deliberately not one.
--
-- `climbedOut` is set the instant the stair is taken, because the readout has to be on screen while she
-- points at it. This one is set when her scene has actually finished, and it is what stops the scene
-- playing twice -- including for a player who quit the game in the middle of it, which a flag passed
-- through the state switch would not survive.
function Descent.tallyTaught(player)
    return (player and player.tallyTaught) or false
end

function Descent.markTallyTaught(player)
    if not player then return false end
    player.tallyTaught = true
    return true
end

-- Step to the next floor. Records that the floor just left was cleared, which is what the depth record
-- is read from at extraction -- `floor` alone would over-report, since it is where the party is
-- standing rather than what they beat.
--
-- ...and it PRUNES, which is why the tally's payback sits here rather than in states/game.lua's
-- game.enter. `run.floor` rises in exactly one place and this is it, so every way down pays back once
-- and only once: the landing's stair, and a floor that gives way under the company. Re-entering a floor
-- the party climbed out of does not come through here -- the floor number does not move -- so the walk
-- back to where they were is correctly worth nothing.
function Descent.advance(run, player)
    if not run then return end
    run.cleared = math.max(run.cleared or 0, run.floor or 1)
    run.floor = (run.floor or 1) + 1
    -- The pruning, paid to the COMPANY's tally rather than the run's (Descent.count). `player` is
    -- optional for the same reason it is on Descent.retreat: a spec that only cares where the party is
    -- standing passes a bare run and walks the stack unchanged.
    Descent.countBy(player, -1)
    return run
end

-- The party has cleared a floor and is standing on its landing. Called before the extract-or-descend
-- prompt so both branches agree on what has been beaten.
function Descent.clearFloor(run, player)
    if not run then return end
    local floor = run.floor or 1
    -- Credit the circle, once. Re-entering a floor cannot happen today (the stair is one-way) but the
    -- guard is cheap and the alternative is a bug that pays double and is invisible in a save file.
    --
    -- A CIRCLE IS BEATEN WHEN ITS GENERAL IS, not when one of its floors is. She holds the last floor
    -- of her stratum, so crediting every cleared floor would report Gluttony beaten by a party that had
    -- only got past her honour guard -- and the terminal card's "Circles beaten:" line would be a lie
    -- one floor early, every time.
    if floor > (run.cleared or 0) and Descent.isGeneralFloor(floor) then
        local vendor = Descent.sinAt(run, floor).vendor
        run.standing = run.standing or {}
        run.standing[vendor] = (run.standing[vendor] or 0) + 1
        -- ...and the tally comes down with her. Inside the once-only guard deliberately: the payback is
        -- for felling the general, and a floor credited twice would pay twice. Paid to the COMPANY's
        -- tally (Descent.count), and `player` is optional exactly as it is on advance and retreat.
        Descent.countBy(player, -Descent.COUNT_SEAL)
    end
    run.cleared = math.max(run.cleared or 0, floor)
    return run.cleared
end

-- THE ACCOUNT OF A RUN THAT HAS ENDED, however it ended. It was read by the standalone mode's terminal
-- card, which is deleted; what still asks is states/game.lua and ui/panels/advancement.lua,
-- which is the only place any of it is ever said.
--
-- THIS USED TO BE `Descent.extract` AND IT USED TO BANK, and both of those going is the mode.
--
-- It banked first: standing per house and a new depth record onto the campaign player, plus a prestige
-- point per floor, so a descent was the campaign's progression engine wearing a stair. That went when
-- the descent became a separate mode.
--
-- What was left was an extraction that banked nothing -- and an extraction that banks nothing is a quit
-- button with prose on it. The landing offered it against descending, and both answers paid the same
-- zero, so seven floors of "press on or take what you have" rested on a stake that did not exist. So
-- there is no climbing out any more. A descent ends in exactly three ways and this reports all three:
-- the Hollow Crown beaten, the company wiped, or the player walking away from a floor mid-way.
--
-- What became of the two things it used to bank:
--
--   the depth record   nothing outlives a run, so there is no record to beat. It is reported and gone.
--   levels             earned in the fighting now, body by body (models/experience.lua), which is what
--                      lets a clean run start at level 1 and still reach the seventh circle.
--
-- The run's FINDS are not touched here and never were: they have been live in the company's stash since
-- the moment they were picked up. What ENDING a run does is drop the rollback point, which is the
-- caller's job (clearRun) because the snapshot lives on player.activeRun.
--
-- NO TITLE AND NO OUTCOME. Both belong to how the run ended, which is the caller's knowledge and not
-- this table's -- the same numbers read three different ways.
--
-- `player` is taken and only read: the terminal names the company the run ended with.
function Descent.account(player, run)
    if not (player and run) then return nil end

    -- Which circles this run beat, copied out so the terminal reads a table the run cannot still be
    -- mutating. Ordered by Descent.SINS at the point of display, never by `pairs`.
    local circles = {}
    for vendorId, n in pairs(run.standing or {}) do circles[vendorId] = n end

    local survivors = {}
    for _, char in ipairs(player.roster or {}) do
        survivors[#survivors + 1] = char
    end

    return {
        -- Two floor numbers, because a run that ended well and a run that ended badly are counting
        -- different things: `floors` is what the company BEAT, `depth` is where it was standing when it
        -- stopped. They differ by exactly one on a wipe, and a wipe reported as "you cleared four" when
        -- the fourth is what killed you is the wrong number wearing the right label.
        floors = run.cleared or 0,
        depth = run.floor or 1,
        circles = circles,
        gold = player.gold or 0,
        -- The company as it ended, levels and all -- the one place a run's growth is ever shown whole,
        -- since there is no hub advancement overlay on the other side of this any more.
        company = survivors,
    }
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

-- Plain data only, and deliberately WITHOUT `entry`.
--
-- The rollback point is a full Save.snapshot -- the whole company, its grids and the stash -- and
-- models/save.lua's snapshotRun already writes it once at the run level. Serializing it here as well
-- would put a second copy of the entire player in every save, growing the file by a company per write.
-- So the descent holds `entry` in MEMORY (which is the point: it is what carries the rollback point from
-- one floor to the next, since each floor is a fresh game.enter that would otherwise re-snapshot and
-- quietly bank the last floor's finds) and Save.restoreRun re-attaches it on the way back in.
function Descent.snapshot(run)
    if type(run) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(run.pending or {}) do pending[i] = id end
    local standing = {}
    for vendorId, n in pairs(run.standing or {}) do standing[vendorId] = n end
    local landing
    if run.landing then
        landing = {}
        for i, id in ipairs(run.landing) do landing[i] = id end
    end
    -- The dropped packs ride out whole. Each entry is already plain data (Descent.dropPack snapshots on
    -- the way in), so this is a copy rather than a conversion -- and it has to be a copy, or the saved
    -- table would still be the one the run is mutating.
    --
    -- `id` and the guard travel with them, and BOTH have to: the id is how a marker rebuilt after a load
    -- names its pile (Descent.takePack), and `guardIds` is the company standing over it, drawn once when
    -- the party fell. Re-drawing that on resume would change the fight under a player who had already
    -- looked at it. `guardIds` is a flat list of id strings, which is the only reason it can be here --
    -- a composition function would take the save write down (see the `drops` note on the run).
    local drops = {}
    for i, d in ipairs(run.drops or {}) do
        drops[i] = { id = d.id, floor = d.floor, x = d.x, y = d.y, count = d.count, items = d.items,
            guard = d.guard, guardIds = d.guardIds }
    end
    return {
        floor = run.floor or 1,
        seed = run.seed or 0,
        -- Which order this run's circles were dealt in (Descent.new). Nil on Dante's, which is what an
        -- older save and a first descent both read as -- so this is purely additive and Save.VERSION
        -- does not move. A run resumed after the Crown fell keeps the order it opened with.
        shuffled = run.shuffled or nil,
        cleared = run.cleared or 0,
        pending = pending,
        -- (Iselle's tally STOOD HERE and has moved to the player -- see Descent.count for why. A run
        -- that resets on extraction cannot carry a number the city has to keep reading. models/save.lua
        -- writes it beside `climbedOut` now, and reads an old save's `descentRun.count` forward off the
        -- raw snapshot so nobody's tally is dropped on the way in.)
        --
        -- HOW LONG THE MULE IS STILL AWAY (models/mule.lua), in fights. On the RUN rather than on the
        -- player, which is the opposite call to the tally above and for the opposite reason: a trip is
        -- something happening inside one expedition, and a company must never walk into a fresh rift
        -- with a mule notionally still halfway home. Nil while it is standing right there, which is
        -- what an older save reads as too.
        muleAway = (run.muleAway or 0) > 0 and run.muleAway or nil,
        -- WHICH STAIRS HAVE BEEN PAID FOR, keyed by floor as a string (the same reason `floors` is:
        -- Save.encode round-trips a numeric key inconsistently). Greed's gate is the only thing that
        -- writes it, and it has to ride: a company that paid, climbed out and came back down must not
        -- be billed twice for the stair it already bought.
        tollPaid = next(run.tollPaid or {}) and run.tollPaid or nil,
        -- Unbanked standing rides in the save, or quitting on floor four and resuming would hand the
        -- three circles below back at zero -- a resume is not an extraction and must lose nothing.
        standing = standing,
        -- An undealt boon, if the run was saved on a landing. Nil at every other moment, and NOT
        -- defaulted to an empty table on the way out: the presence of the field is what tells a resume
        -- there is a panel to re-open (states/game.lua), so an empty list would re-open an empty one.
        landing = landing,
        drops = drops,
        -- The counter the pile ids come off. Carried, or a resumed run would start numbering at one
        -- again and mint a second "drop1" beside the pile still lying on floor three.
        dropSeq = run.dropSeq or nil,
        -- WHO WALKED DOWN (Descent.party). A flat list of ids, and it has to ride: quitting on floor
        -- four and resuming with a different four is a company the player did not send. Nil while
        -- nobody has picked, which is what an older save reads as too -- and an unset party is the
        -- roster's first four, so both degrade to the same honest default. Purely additive, so
        -- Save.VERSION does not move.
        party = (run.party and #run.party > 0) and run.party or nil,
        -- Every board this company has walked, whole. See `floors` on the run.
        floors = run.floors or {},
    }
end

function Descent.restore(snap)
    if type(snap) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(snap.pending or {}) do pending[i] = id end
    local standing = {}
    for vendorId, n in pairs(snap.standing or {}) do standing[vendorId] = n end
    local landing
    if snap.landing then
        landing = {}
        for i, id in ipairs(snap.landing) do landing[i] = id end
    end
    local drops = {}
    for i, d in ipairs(snap.drops or {}) do
        drops[i] = { id = d.id, floor = d.floor, x = d.x, y = d.y, count = d.count, items = d.items,
            guard = d.guard, guardIds = d.guardIds }
    end
    return {
        floor = snap.floor or 1,
        seed = snap.seed or 0,
        -- Absent on an older save and on a first descent alike, and both read as Dante's order --
        -- which is what they are (Descent.sinOrder).
        shuffled = snap.shuffled or nil,
        cleared = snap.cleared or 0,
        pending = pending,
        -- (No `count` -- the tally is the player's. models/save.lua carries an old save's forward.)
        muleAway = type(snap.muleAway) == "number" and snap.muleAway or nil, -- see snapshot
        tollPaid = (function()                                              -- ...and see snapshot
            if type(snap.tollPaid) ~= "table" then return nil end
            local out = {}
            for k, v in pairs(snap.tollPaid) do if v == true then out[tostring(k)] = true end end
            return next(out) and out or nil
        end)(),
        standing = standing, -- absent in a save written before circles had houses; an empty table reads the same
        landing = landing,   -- nil unless the run was saved standing on a landing; see snapshot
        drops = drops,       -- ...and the packs, still lying where the company dropped them
        dropSeq = snap.dropSeq or nil, -- ...and the counter their ids come off; see snapshot
        -- ...and who walked down. Copied rather than aliased, like every other list here: the restored
        -- run must not share a table with the snapshot it was read from.
        party = snap.party and (function()
            local out = {}
            for i, id in ipairs(snap.party) do out[i] = id end
            return out
        end)() or nil,
        floors = snap.floors or {}, -- ...and the maps it made of the floors it walked
        entry = nil, -- re-attached by Save.restoreRun from the run-level copy; see above
    }
end

return Descent
