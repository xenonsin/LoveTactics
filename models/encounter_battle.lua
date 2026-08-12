-- EncounterBattle: the two decisions a fight makes that nothing else may make a second time --
-- WHO you fight, and WHAT the win is worth.
--
-- Both used to live inside states/battle.lua, which was fine while the battle state was the only way
-- to resolve an encounter. It is not any more: a fight the company has outgrown can be walked off
-- without the board ever loading (models/autobattle.lua, states/game.lua), and that path has to
-- produce THE SAME fight and THE SAME payout, or the walk-off is a second implementation of the
-- economy quietly drifting away from the first. So the shared halves moved down here and the battle
-- state calls them.
--
-- What deliberately did NOT move is the battle state's unit assembly. Six launchers reach
-- battle.enter -- a campaign fight, the prologue, the menu's mock, a draft, a PvP duel, the duel
-- debugger -- and its forks over tutorial control overrides, live opponent instances and the
-- deployment phase belong to the state that owns those cases. EncounterBattle.build composes the
-- CAMPAIGN shape only, off the same spec, for callers with no board.
--
-- Pure (no love.graphics, no panel), so it loads under the headless tests.

local Arena = require("models.arena")
local Combat = require("models.combat")
local Growth = require("models.growth")
local Calendar = require("models.calendar") -- the world fights at the day's level
local Item = require("models.item")
local Spoils = require("models.spoils")
local EncounterModel = require("models.encounter")

local EncounterBattle = {}

-- ---------------------------------------------------------------------------
-- Who you fight
-- ---------------------------------------------------------------------------

-- The arena spec: composition, escorted allies, win condition and board, resolved from whichever
-- authority owns this fight. An objective reads the quest's `map.objective`; everything else reads the
-- encounter blueprint. Lifted verbatim from states/battle.lua's specFor.
function EncounterBattle.spec(opts, partyIds, seed)
    -- `ground` is what the overworld tile the marker stood on was made of (Overworld:groundAt): a river
    -- crossing, a rock field, open grass. A generated board is laid out to match, so WHERE a fight was
    -- taken is a tactical fact and not just a colour (Arena.GROUND_PROFILES). Threaded through the spec
    -- rather than read at either call site, so the walk-off (models/autobattle.lua) fights the same board
    -- the battle state would have built -- which is the whole reason this function exists.
    local spec = { biome = opts.biome, ground = opts.ground, party = partyIds, seed = seed }
    -- A marching formation, as a list of {col,row} slots parallel to partyIds, so Arena.build's bindUnits
    -- seats each member on their chosen tile. DRAFT MODE only: it keeps a 4x2 grid in its shop UI
    -- (models/draft_run.lua) and hands it over pre-resolved, because its un-merged duplicate ids would
    -- collide in an id-keyed map. The campaign brings none -- it chooses placement per battle in the
    -- deployment phase (docs/deployment.md) -- and neither does a scripted fight, which keeps its
    -- authored spawns.
    if opts.formationSlots then
        spec.formation = opts.formationSlots
        spec.formationCols = opts.formationCols
        spec.formationRows = opts.formationRows
    end
    -- A quest may name the exact board to fight on instead of rolling one (the prologue's tutorial,
    -- whose lesson is authored against specific tiles). Nil everywhere else, so ordinary fights keep
    -- their random pick. See Arena.pickLayout.
    spec.layout = opts.quest and opts.quest.map and opts.quest.map.layout
    local enc = opts.encounter or {}
    if enc.kind == "objective" then
        local obj = (opts.quest and opts.quest.map and opts.quest.map.objective) or {}
        spec.layout = obj.layout or spec.layout -- a boss may name its own board; else keep quest.map.layout
        spec.composition = obj.composition
        spec.allies = obj.allies -- AI-run escorts fighting on the party's side
        spec.objective = obj.win -- { type, target, protect } win condition; nil -> killAll
    else
        local def = enc.id and EncounterModel.get(enc.id)
        spec.composition = def and def.composition
        spec.allies = def and def.allies
        spec.objective = def and def.objective
    end
    -- A fight against somebody's team rather than a roll of the encounter table: a stored build, or
    -- another player. The far side arrives as live character instances, so THEIR ids are the
    -- composition -- the arena seats exactly those bodies, in that order, and battle.enter binds the
    -- instances it was handed onto those spawns. Overrides whatever the quest or encounter asked
    -- for, because the opponent is no longer this game's to choose.
    if opts.enemyChars then
        local ids = {}
        for i, char in ipairs(opts.enemyChars) do ids[i] = char.id end
        spec.composition = ids
    end
    return spec
end

-- ---------------------------------------------------------------------------
-- Which fights a model alone can finish
-- ---------------------------------------------------------------------------

-- Can this encounter be resolved by the combat model with nobody watching?
--
-- Only a plain kill-them-all fight. Two things disqualify one, and both are the same fact: the WIN
-- CLOCK for anything else is driven by states/battle.lua, not by models/combat.lua. Reinforcement
-- waves are spawned by the battle state's spawnWaves; a `defend`/`reach`/`survive` objective is
-- scored against timers the state advances. A headless loop over the model would walk such a fight
-- forever and never be told it had ended.
--
-- `allies` disqualifies too: an escorted survivor is a body the player is meant to keep alive by
-- choosing where to stand, and handing that decision to the AI is not the same fight.
--
-- Five encounters carry one or both today (the prologue's siege and survivors legs).
function EncounterBattle.eligible(def)
    if not def then return false end
    if def.objective then return false end
    if def.allies then return false end
    return true
end

-- The same question asked of an overworld cell: is this a side-fight the model can finish alone?
-- The quest objective is never one of them, whatever its encounter def happens to say.
function EncounterBattle.cellEligible(cell)
    local enc = cell and cell.encounter
    if not enc then return false end
    if enc.kind ~= "combat" and enc.kind ~= "elite" then return false end
    return EncounterBattle.eligible(enc.id and EncounterModel.get(enc.id))
end

-- ---------------------------------------------------------------------------
-- The board, for a caller with no battle state
-- ---------------------------------------------------------------------------

-- Build a campaign encounter's arena and its (unopened) combat, off the same spec the battle state
-- uses. Returns { arena, combat, partyUnits, enemyUnits, seed }.
--
-- `opts`: encounter, quest, biome, prestige, floorLevel, party (the marching company), relicTraits,
-- seed. The combat is built with `deferOpen`, so the caller places the company (Combat.deployUnit)
-- and then calls Combat.openBattle -- the same two-beat open the deployment phase performs.
--
-- Nothing is seated on the party side here: like an ordinary campaign fight, the board is built with
-- the enemy on it and no party, and the arena's bound spawns survive as the placement suggestion.
function EncounterBattle.build(opts)
    local party = opts.party or {}
    local partyIds = {}
    for i, char in ipairs(party) do partyIds[i] = char.id end

    local seed = opts.seed or Arena.randomSeed()
    -- `encounterKind` picks the fight TIER (Arena.enemyCap): an ordinary road stop is a small skirmish,
    -- a guardian or an objective a set-piece. It must be threaded here as well as in states/battle.lua
    -- or the walk-off would resolve a differently sized fight from the one it stands in for.
    local ctx = { day = opts.day or 1, biome = opts.biome, quest = opts.quest,
        encounterKind = opts.encounter and opts.encounter.kind }
    local arena = Arena.build(ctx, EncounterBattle.spec(opts, partyIds, seed))

    -- The world fights at the level the CALENDAR sets, not at one derived from the company: that is
    -- what makes a squandered day a day the world pulled ahead (models/calendar.lua).
    local enemyLevel = Calendar.dangerLevel(opts.day or 1)
    local partyUnits, enemyUnits = {}, {}
    -- Escorted allies fight on the party's side but are not the player's characters, so they get
    -- fresh instances and run themselves -- scaled like the far side, not left at level 1.
    for _, u in ipairs(arena.allies or {}) do
        partyUnits[#partyUnits + 1] =
            { char = Growth.spawn(u.id, enemyLevel, opts.floorLevel), x = u.x, y = u.y, control = "ai" }
    end
    for _, u in ipairs(arena.enemies) do
        enemyUnits[#enemyUnits + 1] =
            { char = Growth.spawn(u.id, enemyLevel, opts.floorLevel), x = u.x, y = u.y }
    end

    local combat = Combat.new(arena, partyUnits, enemyUnits, { deferOpen = true })
    return { arena = arena, combat = combat, partyUnits = partyUnits, enemyUnits = enemyUnits, seed = seed }
end

-- Stand the company on the board with no player to place them. Returns `deployed, front` -- the
-- members placed, in placement order, and those of them standing nearest the enemy: the two lists a
-- caller's `resolveOpening` wants (states/game.lua's frontRow-scoped relics and Rowan's Vigil).
--
-- This is DeployPhase:autoFill's placement (ui/deploy_phase.lua) with the panel taken off: the
-- arena's own bound spawns first -- exactly where the company stood before there was a phase to
-- choose in -- and the zone's first free tile for anyone whose spawn is gone. Walking a fight off
-- should stand the line where pressing Auto-Fill and Begin would have, or the walk-off is quietly
-- fighting a different battle from the one the player could have played.
--
-- `chars` arrives already ordered and already cut to the field (Muster.fielded); anyone past
-- MAX_FIELD or with nowhere to stand is benched, exactly as commitDeploy benches the unplaced.
function EncounterBattle.autoDeploy(combat, arena, chars)
    local spawns = (arena and arena.party) or {}
    local deployed, si = {}, 0

    for _, char in ipairs(chars or {}) do
        local unit
        if #deployed < Combat.MAX_FIELD then
            si = si + 1
            local sp = spawns[si]
            if sp and Combat.inDeployZone(combat, sp.x, sp.y) then
                unit = Combat.deployUnit(combat, char, sp.x, sp.y)
            end
            if not unit then
                -- No bound spawn left (or it is taken): the first free tile of the zone instead.
                for _, t in ipairs(Combat.reinforceTiles(combat)) do
                    unit = Combat.deployUnit(combat, char, t.x, t.y)
                    if unit then break end
                end
            end
        end
        if unit then
            deployed[#deployed + 1] = { char = char, unit = unit }
        else
            Combat.benchUnit(combat, char)
        end
    end

    -- The front line, measured off the deployed bodies rather than off the zone, so it means what it
    -- says on a board whose zone is an odd shape. Same reading as DeployPhase:frontLine.
    local chars_, front = {}, {}
    local towardTop = Combat.enemyHomeEdge(combat) == "top"
    local best
    for _, p in ipairs(deployed) do
        chars_[#chars_ + 1] = p.char
        local y = p.unit.y
        if not best or (towardTop and y < best) or (not towardTop and y > best) then best = y end
    end
    for _, p in ipairs(deployed) do
        if p.unit.y == best then front[#front + 1] = p.char end
    end
    return chars_, front
end

-- ---------------------------------------------------------------------------
-- What the win is worth
-- ---------------------------------------------------------------------------

-- Difficulty tier (1..3, stamped on the encounter by models/overworld.lua) scales the payout: a
-- tougher side-fight is worth more, the risk/reward for spending HP before the boss. Tier 1 (or an
-- unstamped fight) pays exactly as it always did.
EncounterBattle.TIER_GOLD = { [1] = 1.0, [2] = 1.6, [3] = 2.4 }

-- Everything a won fight pays: { gold, loot = {ids}, materials = {[id]=n} }, or nil for a kind that
-- pays nothing. Lifted from states/battle.lua's finishBattle so the walk-off path cannot pay a
-- different number for the same fight.
--
-- `opts`: encounter, enemyUnits, prestige, houseMaterial, combat (for the in-fight takings below),
-- rescue (`{ saved, of }` -- how many of the fight's charges walked out; see the rescue pay below).
function EncounterBattle.spoils(opts)
    local encounter = opts.encounter or {}
    local kind = encounter.kind
    local spoils

    if kind == "combat" or kind == "elite" then
        spoils = Spoils.roll({
            enemyUnits = opts.enemyUnits,
            day = opts.day,
            -- How deep this stop is, on a descent. Nil in the campaign, where the day carries the
            -- same job -- see Spoils.roll, which takes the larger of the two.
            floorLevel = opts.floorLevel,
            kind = kind,
            rewardGold = encounter.rewardGold,
            loot = encounter.loot,
            rewardScale = EncounterBattle.TIER_GOLD[encounter.tier or 1] or 1.0,
            tier = encounter.tier,
            houseMaterial = opts.houseMaterial,
        })
    elseif kind == "objective" then
        -- The general pays through Quest.complete, not through spoils -- but the SALVAGE floor is
        -- owed by every won fight, and the last fight of a run is not the one to make an exception
        -- of. Materials only: no gold and no loot roll here, so the quest stays the single payout
        -- seam for both (states/game.lua's objective branch).
        spoils = { gold = 0, loot = {}, materials = Spoils.materials({
            kind = kind, tier = encounter.tier, houseMaterial = opts.houseMaterial,
        }) }
    end

    -- WHAT WALKED OUT WITH YOU. A `defend` objective is satisfied while ANY of its charges still
    -- stands, so a party that screens one survivor and lets the other go down wins exactly the fight a
    -- party that got both out won -- and was paid exactly the same for it, which quietly says the
    -- second one never mattered. An encounter may price the difference PER HEAD instead (`rescue` on
    -- its blueprint, data/encounters/encounter_survivors_defend.lua): every charge still standing when
    -- the last enemy fell pays its own purse and its own share of what they were carrying, ON TOP of
    -- whatever the fight rolled. Authored gold, so the difficulty-tier scale never touches it -- the
    -- same rule `rewardGold` follows. Nobody saved is not a case here: the objective already failed.
    --
    -- The count is the CALLER'S, and has to be: it is taken before the victory seam's mercy revive
    -- stands the fallen back up (states/battle.lua's win), and counting it off `combat` down here would
    -- pay for a survivor who died. A walked-off fight passes none and never needs to -- an escort is
    -- not walk-off eligible (EncounterBattle.eligible refuses anything carrying `allies`).
    local rescue = opts.rescue
    local pay = encounter.id and EncounterModel.get(encounter.id)
    pay = pay and pay.rescue
    if spoils and pay and rescue and (rescue.saved or 0) > 0 then
        spoils.gold = (spoils.gold or 0) + (pay.gold or 0) * rescue.saved
        spoils.loot = spoils.loot or {}
        for _ = 1, rescue.saved do
            for _, id in ipairs(pay.loot or {}) do
                -- An unknown id is dropped rather than granted, the same guard the loot override keeps:
                -- a typo in a data file must not reach Item.instantiate.
                if Item.defs[id] then spoils.loot[#spoils.loot + 1] = id end
            end
        end
        -- What the victory panel says about the count that decided the purse -- otherwise the payout
        -- moves and nothing on screen says why (ui/panels/battle_summary.lua). The words are authored
        -- beside the payout they explain, because they belong to the stop: these are survivors on this
        -- map and something else on the next.
        if pay.note and (rescue.of or 0) > 0 then
            spoils.note = string.format(pay.note, rescue.saved, rescue.of)
        end
    end

    local combat = opts.combat
    -- Gold picked off the enemy DURING the fight (Combat.skimGold, the Skimmer's Cut) rides out on
    -- the spoils rather than through a purse-path of its own. Folded in after the roll so it is
    -- added to the takings rather than replacing them, and a table is minted when the fight rolled
    -- no spoils of its own -- a skim earned in a quest battle is still earned.
    local skimmed = combat and combat.skimmed or 0
    if skimmed > 0 then
        spoils = spoils or { gold = 0, loot = {} }
        spoils.gold = (spoils.gold or 0) + skimmed
    end
    -- Bounties settled during the fight (Combat.bounty -- a Struck Ledger paid out when its mark
    -- fell, a body spent to the Ledger's Due) ride out on exactly the same path. Every caller of
    -- this reaches it only on a WIN, which is the whole economy of a bounty: the promise is banked
    -- on the combat, and a battle that is lost pays nothing, however many marks were collected.
    local bounty = combat and combat.bounty or 0
    if bounty > 0 then
        spoils = spoils or { gold = 0, loot = {} }
        spoils.gold = (spoils.gold or 0) + bounty
    end

    return spoils
end

return EncounterBattle
