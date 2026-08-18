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
--   gluttony  swamp       a place that swallows what walks into it
--   lust      forest      overgrown, fertile, and hard to see out of
--   greed     underworld  the vault below the vault
--   envy      desert      barren ground with a view of somewhere green
--   wrath     volcanic    the obvious one, and it has earned it
--   sloth     tundra      the post nobody came back to
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
-- ORDERED, and the order is only a canonical listing -- a run reshuffles it (Descent.sinAt). `pairs`
-- over a registry is unspecified, and a run must lay out the same floors from the same seed on any
-- machine.
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
        minor = { lead = "character_the_gralloch", filler = "character_gorge_fly" } },
    { id = "lust", name = "Lust", vendor = "cathedral", biome = "forest",
        scene = "conversation_descent_lust",
        guardian = { lead = "character_general_lust", filler = "character_the_suppliant" },
        minor = { lead = "character_the_suppliant", filler = "character_petal_drift" } },
    { id = "greed", name = "Greed", vendor = "undercroft", biome = "underworld",
        scene = "conversation_descent_greed",
        guardian = { lead = "character_general_greed", filler = "character_the_tally" },
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
        minor = { lead = "character_second_water", filler = "character_glass_mote" } },
    { id = "wrath", name = "Wrath", vendor = "colosseum", biome = "volcanic",
        scene = "conversation_descent_wrath",
        -- The Champion held this slot and held it CORRECTLY -- a real body carrying a Demon Sigil with
        -- two authored phases, and the worked example in trait_boss_phases. It was still the wrong
        -- occupant: a stratum's centrepiece should BE the sin one rank down, not an arena fighter who
        -- happens to be nearby. It stays the authoring pattern; it stops standing in for Ira.
        guardian = { lead = "character_general_wrath", filler = "character_the_anvil" },
        minor = { lead = "character_the_anvil", filler = "character_cinder_kin" } },
    { id = "sloth", name = "Sloth", vendor = "bastion", biome = "tundra",
        scene = "conversation_descent_sloth",
        guardian = { lead = "character_general_sloth", filler = "character_the_late_watch" },
        minor = { lead = "character_the_late_watch", filler = "character_drift_thing" } },
    { id = "pride", name = "Pride", vendor = "arcanum", biome = "castle",
        scene = "conversation_descent_pride",
        guardian = { lead = "character_general_pride", filler = "character_marginalia" },
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
Descent.DROPS = {
    gluttony = { general = { "utility_maw_of_the_unfed" },     minor = { "utility_larder_hook" } },
    lust     = { general = { "utility_reliquary_unbidden" },   minor = { "utility_beggars_bowl" } },
    greed    = { general = { "utility_bottomless_purse" },     minor = { "utility_tally_stick" } },
    envy     = { general = { "utility_envious_glass" },        minor = { "utility_second_vessel" } },
    wrath    = { general = { "armor_mail_of_the_unappeased" }, minor = { "utility_anvils_face" } },
    -- Acedia's relic is her PIKE, and it took a second look to see it: it is tagged
    -- { "spear", "pierce", "physical", "melee", "relic" }, so a search for the bare `tags = { "relic" }`
    -- the other six wear reports her as the one general with nothing to pay. She is not. The set is
    -- whole.
    sloth    = { general = { "weapon_forsworn_pike" },         minor = { "utility_unblown_horn" } },
    pride    = { general = { "utility_codex_unanswered" },     minor = { "utility_marginal_gloss" } },
}

-- WHAT A SPENT SET PAYS INSTEAD, in units of the house's own forge stock.
--
-- Sized against the bench that bills it: a Forge rung costs two-to-three house stock (models/forge.lua),
-- so four is a rung and change -- enough that a general with nothing left to give is still the best thing
-- that happened on that floor, and not so much that farming a circle you have stripped beats going
-- deeper. One constant, because the right answer is a tuning question and will move.
Descent.SPENT_SET_STOCK = 4

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

-- HOW DEEP A CIRCLE GOES. Wizardry's proving grounds are ten levels and its descendants go deeper; the
-- descent was eight, which is a tour of the seven rather than a dungeon. Two floors per circle makes it
-- fifteen -- squarely in that band -- and it is one constant, so three per circle is a one-line change.
--
-- Two rather than three on purpose: a floor is a real sitting, and twenty-two of them is a mode nobody
-- finishes. Fifteen is long enough that the way up is a decision and short enough to be walked.
Descent.FLOORS_PER_CIRCLE = 2

-- How many STOPS a floor's board hosts -- not how many fights. models/overworld.lua's combatShare caps
-- combat at a share of this and re-seats the rest as texture (a rest, a cache, a merchant), so the
-- number here buys density rather than battles.
--
-- Deliberately low for now. The plan's target is a Dream Quest board of 10-12 stops, and that only
-- becomes playable once an ordinary fight is a two-minute skirmish rather than a six-minute set-piece
-- (the skirmish tier). Raising this before that lands would produce a forty-minute floor. One constant,
-- so that stage is a one-line change here.
--
-- The Dream Quest target, now that an ordinary stop is a skirmish rather than a set-piece: the
-- generator's combat share (0.6) turns ten-to-twelve stops into roughly eight fights, and GUARANTEE
-- seats the rests and the relic cache among the rest. About twenty-seven minutes of floor.
-- RAISED WITH THE BOARD, and measured rather than guessed. At 10-12 on the dungeon carve's 30x30 grid a
-- floor came out with TWO fights on it: five of the stops are spoken for before the draw begins (the
-- reliquary, the rest and the recruit are guaranteed, and the stair and the way up are fixtures), so
-- ten stops leave five to roll and the combat share is a CAP on those rather than a floor under them.
-- Two fights and a boss is not a floor of a dungeon, it is a corridor with a boss at the end.
--
-- Sixteen leaves eleven to roll, which lands six or seven fights -- the number the pacing note below was
-- written against -- and on ~440 walkable tiles it is one stop per twenty-seven, still sparse enough
-- that the floor reads as ground with things on it rather than a string of stops.
Descent.FLOOR_STOPS = { min = 14, max = 18 }

-- CACHES ARE PINNED, and this is the thing the density bump above would otherwise have moved in
-- silence. Overworld.generate derives the cache count from the stop count at about one per two stops,
-- so twelve stops is six caches where four was two -- and a cache is the largest single source of
-- forging material on a board, well above what the fights leave. Measured, a derived twelve-stop floor
-- pays around three Forge rungs of craft and house stock against the one the stage-2 payout rebase was
-- calibrated to (models/spoils.lua). Two or three holds that line at the new density.
Descent.FLOOR_CACHES = { min = 2, max = 3 }

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
-- before the stair. Raising FLOOR_STOPS must not quietly multiply it, which is what a `per` would do.
Descent.FLOOR_RESTS = 1

-- What share of a floor's stops may be fights. The generator's own cap (0.6) is a roadside's share; a
-- floor wants nearly every stop that is not a guaranteed rest or reliquary to be one. Still a CAP -- it
-- re-seats the overflow as texture and never invents fights -- so it works with the weights above
-- rather than instead of them.
Descent.COMBAT_SHARE = 0.75

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

function Descent.floorPool(ctx)
    local pool = require("models.encounter").pool(ctx)
    local out = {}
    for i, e in ipairs(pool) do
        local weight = e.weight
        if e.kind == "elite" then
            weight = Descent.ELITE_WEIGHT
        elseif e.kind ~= "combat" then
            weight = weight * Descent.TEXTURE_SCALE
        end
        out[i] = { id = e.id, kind = e.kind, name = e.name, weight = weight }
    end

    -- ...and the hazards, appended rather than re-weighted in place: Encounter.pool only ever returns
    -- entries with a weight above zero, so a blueprint authored at zero is not in the list to find.
    local Encounter = require("models.encounter")
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
Descent.FLOOR_COLS, Descent.FLOOR_ROWS = 26, 26

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
-- THE STOP COUNT DOES NOT FOLLOW IT, which is the load-bearing half of this and the thing a later
-- retune must not undo. Measured over forty floors each (`. board-report 40 descent floor=N`):
--
--   floor 1, 26x26   385 walkable tiles   17.8 stops   one per 21.6 tiles   3.3 arena sites
--   floor 15, 33x33  589 walkable tiles   17.8 stops   one per 33.1 tiles   5.5 arena sites
--
-- The sparseness is deliberate. A floor is a SITTING, and the deep ones are already the long ones:
-- their fights stand a dozen levels above the shallow floors' and take proportionally longer to win.
-- Scaling stops with the area on top of that would put the last floor of a fifteen-floor run at
-- twenty-seven stops of level-14 fighting, which is the forty-minute floor Descent.FLOOR_STOPS' own
-- header refuses. So a deep floor is the same amount of dungeon spread over more of it, which is what
-- makes crossing one a decision rather than a formality.
--
-- And nothing the floor is judged on went backwards on the way down: the camp stays at one, guarded
-- boons hold (50% to 47%, against the 30% tests/descent_floor_spec.lua asserts), dead ends rise 7.5 to
-- 10.1 -- more spurs for the offer rule and for a door to hide behind -- and the arena sites a fight can
-- be seated in rise faster than anything else, which drops the fights seated on sub-standard ground
-- from 0.60 a board to 0.38. The extra ground is the good kind: room, not corridor.
Descent.FLOOR_GROWTH = 1

-- The board a given floor is fought on. Pure arithmetic on the depth -- no run state, no rng -- because
-- a floor's board has to reproduce from (seed, floor) alone like everything else down here.
function Descent.floorDims(floor)
    local span = math.max(0, (floor or 1) - 1) * Descent.FLOOR_GROWTH
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
Descent.FLOOR_CARVE = "dungeon"
Descent.FLOOR_SPACING = 3

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
Descent.LEVEL_PER_FLOOR = 1

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

-- The level the world fights at on this floor -- the descent's Calendar.dangerLevel, and the number
-- states/battle.lua takes as `enemyLevel`. Fed in as the TRACKED level rather than as a battleFloor,
-- which is what keeps Growth's two tiers apart: ordinary stock lags it and anything naming a
-- `floorLevel` of its own tracks it exactly, so the trash thins out and the guardian does not.
function Descent.dangerLevel(run)
    return Descent.OPENING_DANGER + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
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
        seed = seed or (os.time() % 1000000),
        -- Taken at the first floor and then carried by reference for the rest of the descent. See above.
        entry = nil,
        -- Quest ids banked but not yet paid out. Nothing writes this until authored floors land; it is
        -- declared here so the shape of a run does not change under models/save.lua later.
        pending = {},
        -- The deepest floor this run has actually cleared, which is what a new depth record is measured
        -- against at extraction. Distinct from `floor`, which is where the party is standing.
        cleared = 0,
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

-- The gold a company walks in with. Small on purpose: the descent's economy is what its floors pay out
-- -- spoils, caches and the overworld's own merchant stops -- and an opening purse that could buy its
-- way past floor one would settle the run before a tile of it was walked.
Descent.OPENING_GOLD = 50

-- WHO WALKS IN. One body, the same one every run.
--
-- A descent used to open on a MUSTER: a shelf of eleven candidates, a twelve-coin purse, and a company
-- of up to eight bought at the mouth (models/descent_muster.lua, deleted with this). It was the mode's
-- first decision and it was the wrong thing to open on. The whole run was settled on a screen, by
-- comparing eleven bodies the player had never fought with, before a single tile was walked -- and every
-- run after the first was that same screen again. What belongs at the mouth of a descent is a stair.
--
-- So the company is one body and it grows on the road: a stop per floor where somebody still standing
-- down there joins it (models/descent_recruit.lua). A run's company is now something that HAPPENED --
-- who you found, in the order the floors offered them -- rather than something bought.
--
-- NOBODY ON THE BOARD IS YOU. A descent's player is a TACTICIAN: you direct the company, you never
-- stand in it, and there is no body anywhere in the mode that is your character.
--
-- THIS REPLACED A CREATED AVATAR, and the reason is worth keeping. The descent briefly opened on
-- character creation and walked in with the body it produced -- which read well until you asked what
-- happens when it dies. Every answer was bad. Losing it outright ends the mode over one fight. Leaving
-- it recoverable means minting a SECOND you to go and fetch the first, and identity here is `char.id`,
-- so two bodies with one id is a company where half the ledger points at the wrong person. Protecting
-- it specially makes one member unkillable and quietly deletes the stake from the only body the player
-- is attached to.
--
-- A tactician has none of those problems because a tactician cannot be on the floor. Every body in the
-- company is hired or found, all four are equally losable, and what the player owns is the company
-- rather than a member of it. It is also the older and better fit for this game: the party is a party,
-- and the person giving the orders is holding the map.
--
-- So there is no starting body constant. A company is built at the gate, out of the same authored
-- slate the floors offer (models/descent_recruit.lua), and Descent.startingCompany returns nothing.

-- How many bodies the company may hold, ever. The FIELD is four (Player.MAX_FIELD), so a descent's
-- company is exactly what stands on the board: no bench, no body sitting out a floor, and every one you
-- find fights. That is the trade for starting alone -- a recruit is never a spare.
--
-- Mirrored rather than required, the same way Combat.MAX_FIELD mirrors Player.MAX_FIELD, so this file
-- stays free of the player model; tests/descent_recruit_spec.lua pins the two together.
Descent.PARTY_MAX = 4

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

-- Is there room for one more? Asked by the floor descriptor (to seat a recruit stop at all), by the
-- stop itself (a company that filled up between the two must not be offered a body it cannot take), and
-- by the temple (a raise into a full company would be paid for and have nowhere to stand).
function Descent.hasRoom(player)
    return #((player and player.roster) or {}) < Descent.PARTY_MAX
end

-- ---------------------------------------------------------------------------
-- What the company dropped where it fell
-- ---------------------------------------------------------------------------

-- Drop `items` on floor `floor` at (x, y). Snapshotted on the way in, for the reason `drops` gives.
--
-- ONE PILE EXISTS AT A TIME, EVER, AND THIS IS THE RULE THAT MAKES THE WALK BACK MATTER. Dropping a new
-- pack destroys the old one wherever it was lying. Die on floor nine, walk back down, die again on the
-- way -- and everything from the first death is gone for good, replaced by everything from the second.
--
-- Dark Souls' bloodstain exactly, and it is the answer to "what stops the player simply walking back".
-- Nothing stops them. What the game does instead is make the walk back the most dangerous thing they
-- will do, because failing it costs twice: the new pack plus the old one, permanently. A second pile
-- waiting patiently beside the first would turn a disaster into an errand.
--
-- One pile per wipe rather than one per body, for the same reason: the company went down together, in a
-- heap, and four markers on four adjacent tiles would be four walks for one mistake.
--
-- An EMPTY drop is not a drop. A company that wiped carrying nothing leaves nothing, and a marker
-- promising a pack that hands over an empty list reads as a bug however correct the bookkeeping is.
function Descent.dropPack(run, floor, x, y, items)
    if not (run and items and #items > 0) then return nil end
    local Save = require("models.save")
    local snap = {}
    for i, item in ipairs(items) do snap[i] = Save.snapshotItem(item) end
    -- The old pile goes. Replaced rather than appended -- see above.
    run.drops = { { floor = floor or 1, x = x, y = y, items = snap, count = #snap } }
    return run.drops[1]
end

-- Every pile lying on `floor`, so the board can put a marker on each. Cheap and called once per entry.
function Descent.dropsOn(run, floor)
    local out = {}
    for _, d in ipairs((run and run.drops) or {}) do
        if d.floor == floor then out[#out + 1] = d end
    end
    return out
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
-- (Experience.DESCENT_STEP), never the reward for a fight actually fought. The floor's PLACES stay
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
    for _, p in ipairs(grid.patrols or {}) do
        if p.cleared then p.cleared = nil; n = n + 1 end
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

-- Pick a dropped pack up off the floor. Returns the LIVE items, rebuilt from their snapshots, and drops
-- the entry -- so a pack is recoverable exactly once and cannot be walked over twice for two copies of
-- everything the company owned.
function Descent.takePack(run, entry)
    if not (run and entry) then return nil end
    for i, d in ipairs(run.drops or {}) do
        if d == entry then
            table.remove(run.drops, i)
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
    profile.gold = Descent.OPENING_GOLD

    -- The campaign's meters, left at their zero. Nothing in a descent moves them any more -- levels come
    -- from what each body does in the fighting now (models/experience.lua) rather than from prestige --
    -- but the fields stay because the shape is Player.new's and Save.snapshot writes all of it.
    profile.completedQuests = {}
    profile.standing = {}
    profile.deepest = 0
    profile.wounds = {}

    return profile
end

-- Is there an unfinished run on disk? Asked by states/descent.lua before it opens a new one.
function Descent.hasRun()
    return require("models.save").exists(Descent.FILE)
end

-- The saved run's company, or nil if there is none (or it is unreadable). The floor stack and board come
-- back on `resumeRun`, exactly as the campaign's Continue reads them (models/save.lua Save.restoreRun);
-- `saveFile` is re-stamped here because Save.snapshot does not write it -- where a file lives is not
-- something to read out of the file.
function Descent.loadProfile()
    local profile = require("models.save").read(Descent.FILE)
    if not profile then return nil end
    profile.saveFile = Descent.FILE
    return profile
end

-- The run is over -- climbed out, wiped, or abandoned. Nothing carries, so the file goes.
function Descent.clearSaved()
    require("models.save").clear(Descent.FILE)
end

-- How deep the party is standing, 1-based. The only number the difficulty ladder reads.
function Descent.depth(run)
    return (run and run.floor) or 1
end

function Descent.floorLevel(run)
    return 1 + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
end

-- WHICH SIN THIS FLOOR IS, from a per-run shuffle of the seven.
--
-- A SHUFFLE, not a random pick per floor, and the difference is the whole feature: a pick would let a
-- run draw Wrath three times and never reach Envy, so the first seven floors would stop being a tour
-- of the circles and become a slot machine. Dealt as a permutation instead -- floors 1..7 are the seven
-- sins in some order, exactly once each -- which is what makes re-treading the shallow floors tolerable
-- (it is a different game each run) without making the deep ones a lottery.
--
-- A DESCENT HAS A BOTTOM. Seven circles and then the thing at the end of them, which is what makes
-- this a run rather than a treadmill -- the same shape Hades and Dream Quest use: a fixed way down, a
-- boss that ends it, and a reason to go again that lives in the meta rather than in the depth.
--
-- Derived, never stored. A run is a seed and a depth (Descent.snapshot), and a resume re-derives the
-- whole layout from them; a stored order would be a second copy that could disagree with the seed.
local function shuffledSins(seed)
    local deck = {}
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
    return shuffledSins(run and run.seed)[circle]
end

-- WHICH HOUSE HAS WORK POSTED ON THIS FLOOR, as a vendor id -- the door-opening job a shut house cannot
-- ask for, because a house asks inside its own shop (models/errand.lua's Errand.opener).
--
-- A SECOND PERMUTATION, DELIBERATELY UNCORRELATED WITH THE SINS. Both are dealt off the run's seed, but
-- with different salts, so the house whose opener is lying on floor three has nothing to do with the sin
-- who holds it. That is the entire point of the change: which shop you meet stops tracking how deep you
-- have gone. Correlating them -- seating a house's opener on its own circle's floors -- would rebuild the
-- thing this replaced with one fewer boss in front of it.
--
-- ONE FLOOR EACH, CYCLING. Floors 1..7 carry the seven houses in the dealt order and floors 8..14 carry
-- them again, so every house is offered exactly twice in a descent and walking past one costs a lap
-- rather than the run. Nothing is seated at the bottom: the Hollow Crown's floor is not a circle and has
-- no house.
--
-- Derived from the seed, never stored, for the same reason the sins are: a resume re-derives the floor
-- from a seed and a depth, and a stored order is a second copy that can disagree with it. Whether the
-- opener is actually SEATED is a separate question and belongs to the player, not the run -- see
-- Descent.floorObjectives.
local function shuffledHouses(seed)
    local deck = {}
    for i, sin in ipairs(Descent.SINS) do deck[i] = sin.vendor end
    for i = #deck, 2, -1 do
        -- Salted off the sins' own shuffle (which passes floor = 0) so the two permutations cannot come
        -- out in step. 991 is arbitrary and only has to be a number the sins never pass.
        local j = (hash(seed, 991, i) % i) + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function Descent.openerAt(run, floor)
    floor = math.max(1, floor or 1)
    if Descent.isBottom(floor) then return nil end
    local deck = shuffledHouses(run and run.seed)
    return deck[((floor - 1) % #deck) + 1]
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
local function guardianComposition(sin, floorLevel, isGeneral)
    -- Both halves resolved HERE, outside the closure, so the returned function reads no upvalue that
    -- could have moved by the time the fight is built.
    local band = isGeneral and sin.guardian or sin.minor
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
-- The first two are the generator's own default (models/overworld.lua's placeEncounters), restated
-- because naming a third REPLACES the list rather than adding to it -- a floor that asked only for a
-- recruit would lose its reliquary and its rest.
--
-- The third is where the company grows. A descent walks in with whoever was hired at the gate and holds
-- four, so a floor seats one stop where somebody joins -- and stops seating it the moment the
-- company is full, because a stop that can only refuse is a walk for nothing.
--
-- ONE PER FLOOR, so the company fills over the first three circles rather than on the first board.
-- Seating one per empty seat would make floor one the muster again with walking in it, and it would
-- spend a third of that floor's stops on stops that are not fights. Growing a body per circle puts the
-- company's third and fourth members on the boards where the guardians start to need them.
local function guaranteeKinds(player)
    local kinds = { "relic_cache", "rest" }
    if Descent.hasRoom(player) then kinds[#kinds + 1] = "recruit" end
    return kinds
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
                encounters = { min = Descent.FLOOR_STOPS.min, max = Descent.FLOOR_STOPS.max },
                cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
                keyCount = 0,
                -- The way back up, standing on the tile the party walks in on. See EXIT below.
                exitAtStart = true,
                -- A floor is not a climb: its fights are optional stops around a stair, so its rewards get guards
                -- even though `ascent` is set (models/overworld.lua's guardBoons).
                guardBoons = true,
                -- ...and doors that read as wall until somebody looks (Overworld:placeSecrets).
                secrets = true,
                -- A warren cut into the rock, not the sin's own country. See Descent.FLOOR_CARVE.
                carve = Descent.FLOOR_CARVE,
                spacing = Descent.FLOOR_SPACING,
                combatShare = Descent.COMBAT_SHARE,
                guaranteeKinds = guaranteeKinds(player),
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
            encounters = { min = Descent.FLOOR_STOPS.min, max = Descent.FLOOR_STOPS.max },
            cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
            -- keyCount 0 because a floor is not a lock puzzle: the stair is always reachable.
            keyCount = 0,
            -- The way back up, standing on the tile the party walks in on. See EXIT below.
            exitAtStart = true,
            -- A floor is not a climb: its fights are optional stops around a stair, so its rewards get guards
            -- even though `ascent` is set (models/overworld.lua's guardBoons).
            guardBoons = true,
            -- ...and two or three doors that read as wall until somebody looks (Overworld:placeSecrets).
            secrets = true,
            -- A warren cut into the rock, not the sin's own country. See Descent.FLOOR_CARVE.
            carve = Descent.FLOOR_CARVE,
            spacing = Descent.FLOOR_SPACING,
            combatShare = Descent.COMBAT_SHARE,
            -- The reliquary, the rest, and -- while there is room in the company -- somebody to join it.
            guaranteeKinds = guaranteeKinds(player),
            -- ...and how many of each, where a floor differs from a ground. See Descent.FLOOR_RESTS.
            guarantee = { rest = { count = Descent.FLOOR_RESTS } },
            objective = {
                name = general and ("The Stair Down — " .. sin.name) or "The Stair Down",
                -- SHE SPEAKS ONLY ON HER OWN STAIR. The scene is hers, and a lieutenant playing it
                -- would have the general talking through a body she is standing two floors below. A
                -- minor floor opens in silence, which is also what makes hers land.
                opening = general and sin.scene or nil,
                composition = guardianComposition(sin, floorLevel, general),
                win = { type = "killAll" },
            },
            -- ...AND WHATEVER A HOUSE HAS ASKED FOR DOWN HERE. See Descent.floorObjectives.
            objectives = Descent.floorObjectives(player, floor, sin, floorLevel, general, run),
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
        name = general and sin and ("The Stair Down — " .. sin.name) or "The Stair Down",
        opening = general and sin and sin.scene or nil,
        composition = guardianComposition(sin, floorLevel, general),
        win = { type = "killAll" },
        floorLevel = floorLevel,
    }
    if not player then return { stair } end

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
    -- job that would have introduced it. A house met and walked past keeps its posting and comes round
    -- again seven floors later (Descent.openerAt).
    local house = Descent.openerAt(run, floor)
    local openerId = house and not Errand.doorOpen(player, house) and Errand.opener(house)
    local openerDef = openerId and require("models.quest").defs[openerId]
    if openerDef and openerDef.map and openerDef.map.objective then
        out[#out + 1] = specFor({
            id = openerId,
            name = openerDef.name,
            sponsor = openerDef.sponsor,
            map = openerDef.map,
        })
    end

    return out
end

-- Step to the next floor. Records that the floor just left was cleared, which is what the depth record
-- is read from at extraction -- `floor` alone would over-report, since it is where the party is
-- standing rather than what they beat.
function Descent.advance(run)
    if not run then return end
    run.cleared = math.max(run.cleared or 0, run.floor or 1)
    run.floor = (run.floor or 1) + 1
    return run
end

-- The party has cleared a floor and is standing on its landing. Called before the extract-or-descend
-- prompt so both branches agree on what has been beaten.
function Descent.clearFloor(run)
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
    end
    run.cleared = math.max(run.cleared or 0, floor)
    return run.cleared
end

-- THE ACCOUNT OF A RUN THAT HAS ENDED, however it ended: read by states/descent.lua's terminal card,
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
    local drops = {}
    for i, d in ipairs(run.drops or {}) do
        drops[i] = { floor = d.floor, x = d.x, y = d.y, count = d.count, items = d.items }
    end
    return {
        floor = run.floor or 1,
        seed = run.seed or 0,
        cleared = run.cleared or 0,
        pending = pending,
        -- Unbanked standing rides in the save, or quitting on floor four and resuming would hand the
        -- three circles below back at zero -- a resume is not an extraction and must lose nothing.
        standing = standing,
        -- An undealt boon, if the run was saved on a landing. Nil at every other moment, and NOT
        -- defaulted to an empty table on the way out: the presence of the field is what tells a resume
        -- there is a panel to re-open (states/game.lua), so an empty list would re-open an empty one.
        landing = landing,
        drops = drops,
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
        drops[i] = { floor = d.floor, x = d.x, y = d.y, count = d.count, items = d.items }
    end
    return {
        floor = snap.floor or 1,
        seed = snap.seed or 0,
        cleared = snap.cleared or 0,
        pending = pending,
        standing = standing, -- absent in a save written before circles had houses; an empty table reads the same
        landing = landing,   -- nil unless the run was saved standing on a landing; see snapshot
        drops = drops,       -- ...and the packs, still lying where the company dropped them
        floors = snap.floors or {}, -- ...and the maps it made of the floors it walked
        entry = nil, -- re-attached by Save.restoreRun from the run-level copy; see above
    }
end

return Descent
