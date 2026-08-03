-- Overworld state: reached by starting a quest from the Quest Board. It generates
-- a procedural overworld map (models/overworld.lua) from the quest's `map` params,
-- renders it with a scrolling camera (ui/overworld_map.lua), and lets the player
-- traverse it. Stepping onto an encounter tile opens a modal encounter panel;
-- clearing the objective completes the quest and returns to the hub.
--
-- All per-run state (grid, map widget, open panel) is (re)built in `enter`, so
-- re-entering a quest always starts a fresh map.

local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Overworld = require("models.overworld")
local OverworldMap = require("ui.overworld_map")
local Player = require("models.player")
local Save = require("models.save")
local Quest = require("models.quest")
local EncounterPanel = require("ui.panels.encounter")
local LootReveal = require("ui.panels.loot_reveal")
local RelicReveal = require("ui.panels.relic_reveal")
local Fence = require("ui.panels.fence")
local Choice = require("ui.panels.choice")
local Crossroads = require("models.crossroads")
local RestChoice = require("ui.panels.rest_choice")
local RestReveal = require("ui.panels.rest")
local EncounterModel = require("models.encounter")
local Party = require("ui.panels.party")
local Consumables = require("ui.panels.consumables")
local PartyStatus = require("ui.party_status")
local RelicStrip = require("ui.relic_strip")
local OverworldAbility = require("models.overworld_ability")
local Relic = require("models.relic")
local CoachBubble = require("ui.coach_bubble")
local Locale = require("models.locale")
local Theme = require("ui.theme")
local ScreenFx = require("ui.screen_fx")

local game = {}

local titleFont = Theme.display(22)
local hudFont = Theme.body(16)

-- Flight-leg coach lines (data/conversations/tutorial/conversation_tutorial_flight.lua), keyed by node
-- id and resolved through Locale so {select}/localization behave exactly as in a spoken line. Loaded once.
local FLIGHT_HINTS
local function hintNode(id)
    if not FLIGHT_HINTS then
        FLIGHT_HINTS = {}
        for _, node in ipairs(require("data.conversations.tutorial.conversation_tutorial_flight").script) do
            if node.id then FLIGHT_HINTS[node.id] = node end
        end
    end
    return FLIGHT_HINTS[id]
end

-- The Loadout button is opened by I (keyboard) / Y (gamepad) / a click (mouse) -- NOT the confirm key
-- {select} names -- so the loadout hint's key cap is chosen per device here rather than in the line.
local function loadoutKey()
    if InputMode.isGamepad() then return "Y" end
    if InputMode.isKeyboard() then return "I" end
    return nil -- mouse: no cap; the gold ring on the button is the instruction
end

-- Where a coach bubble is allowed to live: clear of the top HUD (title + buttons) and the bottom hint.
local COACH_BOUNDS = { x = 20, y = 70, w = Scale.WIDTH - 40, h = Scale.HEIGHT - 70 - 44 }

-- Clickable "Back" button so a mouse-only player can leave to the hub.
local backButton = { x = 16, y = 16, w = 110, h = 36 }
-- Clickable "Items" button: opens the Party screen (stash mode) to arrange party items on the overworld.
local itemsButton = { x = 138, y = 16, w = 110, h = 36 }
-- Clickable "Use" button: opens the consumables screen to drink a restorative draught between fights.
local useButton = { x = 260, y = 16, w = 110, h = 36 }
-- Clickable "Party" button: opens the party panel -- HP/mana readout + the marching-grid editor -- so
-- the formation can be re-set between fights while the attrition is in view.
local partyButton = { x = 382, y = 16, w = 110, h = 36 }

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function backContains(x, y)
    return rectContains(backButton, x, y)
end

-- The Back button (return to the hub) is hidden on any scripted leg -- the prologue's flight tutorial
-- (before the player has even reached the city) and the debut's aftermath walk (a cutscene the reward
-- rides on, so it must not be abandonable). Both are scripted sequences, not board quests one can quit.
-- On a normal quest game.tutorial and game.scripted are both nil, so the button always shows. (A future
-- pass renames it "Return to City" and gates it behind an "abandon this quest?" warning.)
local function backVisible()
    return not game.tutorial and not game.scripted
end

-- The "Use" button rides alongside the Items button on a normal quest (both flags start true). On the
-- flight tutorial it is held back TWICE over: it needs loot to spend (game.itemsVisible, set by the
-- teaching chest) and the first fight behind the party (game.useUnlocked, set on the survivors'
-- defence win). Until then that leg's HUD is deliberately spare -- the Items button IS the equip
-- lesson -- and a potion has nothing to mend yet.
local function useVisible()
    return game.itemsVisible and game.useUnlocked
end

-- Open the consumables screen over the overworld (same modal slot as the encounter panel).
local function openConsumables()
    game.activePanel = Consumables.new({
        player = game.player,
        onClose = function() game.activePanel = nil end,
    })
end

-- The party panel (HP/mana readout + marching-grid editor) and its always-on HP strip ride on every
-- normal quest, but not the flight tutorial: that leg's HUD is deliberately spare and its coach bubble
-- lives where the strip would sit.
local function partyVisible()
    return game.tutorial ~= "flight"
end

-- Open the party panel over the overworld (same modal slot as the encounter panel).
local function openParty()
    game.activePanel = PartyStatus.new({
        player = game.player,
        abilityState = game.abilityState, -- so the panel can show what each companion has banked
        onClose = function() game.activePanel = nil end,
    })
end

-- A transient on-screen line an ability pushes when it fires (Amana mends X, Kaya forages, ...). Fades
-- over TOAST_LIFE; the newest sits on top. Capped so a flurry of wins can't stack off the screen.
local TOAST_LIFE = 3.2
function game:pushToast(text)
    game.toasts = game.toasts or {}
    table.insert(game.toasts, 1, { text = text, t = TOAST_LIFE })
    while #game.toasts > 5 do table.remove(game.toasts) end
end

-- Fire a companion overworld-ability event (models/overworld_ability.lua) for the active party, carrying
-- the per-run scratch (game.abilityState, reset each quest in enter), a toast notifier, and any event
-- extras (cell, spoils).
local function fireAbility(event, extra)
    local ctx = {
        player = game.player,
        party = game.player and game.player.party,
        grid = game.grid,
        state = game.abilityState,
        notify = function(text) game:pushToast(text) end,
    }
    if extra then for k, v in pairs(extra) do ctx[k] = v end end
    OverworldAbility.dispatch(event, ctx)
end

-- Fire a RELIC event (models/relic.lua) for the run's held relics, on the same four traversal events the
-- abilities ride -- so a found relic and a companion perk react to the same step/win/fight without either
-- knowing about the other. Carries the run's relic-state (game.relicState) and returns the dispatch ctx,
-- whose `boons` a battleStart caller drains onto the party as opening statuses.
local function fireRelics(event, extra)
    local ctx = {
        player = game.player,
        party = game.player and game.player.party,
        grid = game.grid,
        state = game.relicState,
        prestige = game.prestige,
        notify = function(text) game:pushToast(text) end,
    }
    if extra then for k, v in pairs(extra) do ctx[k] = v end end
    return Relic.dispatch(event, ctx)
end

-- Open the Party screen over the overworld (same modal slot as the encounter panel).
local function openLoadout()
    -- During the flight tutorial, opening the loadout is the step that unlocks the equip lesson: the
    -- coach moves from pointing at the button to pointing at the stash.
    if game.coach == "loadout" then game.coach = "equip" end
    game.activePanel = Party.new({
        player = game.player,
        -- The Tactics tab is taught later, at the hub; hide it on the flight leg (before the player has
        -- ever reached the city) so the overworld Loadout is just the equip lesson.
        tactics = game.tutorial ~= "flight",
        -- Clear the equip coach the instant the player equips something, not on panel close.
        onEquip = function()
            if game.coach == "equip" then game.coach = nil end
        end,
        onClose = function()
            game.activePanel = nil
            if game.coach == "equip" then game.coach = nil end -- lesson done (closed without equipping)
        end,
    })
end

-- A resumable run is an ordinary board quest -- NOT the prologue's flight tutorial, a scripted aftermath
-- leg, or any caller that reroutes completion with its own onComplete. Only those autosave an overworld the
-- player can quit and drop back into (states/menu.lua's Continue); a scripted leg has no hub to resume to.
-- Read after enter has set the three flags below.
local function runResumable()
    return not game.tutorial and not game.scripted and not game.onComplete
end

-- Drop the resumable-run autosave. A finished, abandoned, or lost quest must not leave a run on disk that
-- Continue would drop the player back into. Callers persist (Player.save) straight after so disk agrees.
-- No-op on scripted/tutorial legs, which never set activeRun in the first place.
local function clearRun()
    if game.player then game.player.activeRun = nil end
end

-- Persist the run if one is active (a resumable board quest). No-op otherwise, so it is safe to sprinkle at
-- every point the board changes -- entering the map, approaching an encounter, and resolving one. The
-- resolution saves matter: a treasure collected or an event resolved marks its cell cleared, and without
-- persisting that a resume would replay the stop and grant its spoils twice (a combat win already saves).
local function saveRun()
    if game.player and game.player.activeRun then Player.save() end
end

-- prestige defaults to 1 when a quest is launched without it (e.g. dev/test).
--
-- `resume` (optional) is a descriptor from a saved run (models/save.lua Save.restoreRun): its pre-built
-- grid, token position and per-run scratch are used INSTEAD of rolling a fresh map, so Continue lands the
-- player exactly where they quit. Passed only by states/menu.lua; a board or scripted launch omits it.
--
-- `onComplete` (optional) reroutes the objective-win: when set, clearing the objective calls it
-- INSTEAD of the normal pay-out-and-return-to-hub flow. The prologue uses this to run its flight leg
-- as a real overworld traversal and then hand control back to its own sequencer (states/prologue.lua)
-- rather than ending at the hub. A normal board quest passes no onComplete and behaves as before.
function game.enter(self, quest, prestige, player, onComplete, resume)
    require("models.sound").music("music.overworld")
    ScreenFx.reset() -- the map opens on full colour, whatever the last screen left ringing

    game.quest = quest
    game.prestige = prestige or 1
    game.player = player -- kept so combat encounters can deploy the active party
    game.onComplete = onComplete
    local mp = quest and quest.map or {}

    -- Dynamic encounter selection: build the eligible weighted pool for this
    -- player's prestige + the quest's biome, plus any guaranteed "always" picks.
    local ctx = { prestige = game.prestige, biome = mp.biome, quest = quest }
    -- A guaranteed encounter is either a bare id string or a table carrying a per-placement payload:
    -- `loot` for a treasure (the exact kit a chest hands over) or `conversation` for an `event` (which
    -- "Choose..." scene this stop plays). The payload rides onto the placed cell in
    -- Overworld:placeEncounters so the same blueprint id can seed different stops along a route.
    local encSpec = mp.encounters or {}
    local always = {}
    for _, entry in ipairs(encSpec.always or {}) do
        local id = type(entry) == "table" and entry.id or entry
        local def = EncounterModel.get(id)
        if def then
            always[#always + 1] = { id = id, kind = def.kind, name = def.name,
                loot = type(entry) == "table" and entry.loot or nil,
                conversation = type(entry) == "table" and entry.conversation or nil }
        end
    end

    -- A resumed run brings its own board (the exact map, with fog and cleared stops) rather than rolling
    -- or laying out a fresh one -- see Save.restoreRun. Its token position and keys are seated onto the map
    -- widget below; the encounter pool / always list above is built but unused (harmless).
    if resume then
        game.grid = resume.grid
    elseif mp.layout then
        game.grid = Overworld.fromLayout({
            layout = mp.layout,
            biome = mp.biome,
            objective = mp.objective,
            alwaysEncounters = always,
        })
    else
        local params = {
            biome = mp.biome,
            cols = mp.cols,
            rows = mp.rows,
            keyCount = mp.keyCount,
            objective = mp.objective,
            -- Denser default boards (~8-11 stops) so a rolled run has room for the roguelike texture --
            -- caches, rests and fights between them (guaranteed variety + a combat-share cap live in
            -- Overworld:placeEncounters). A quest still overrides via its own mp.encounters.min/max.
            encounterCount = { min = encSpec.min or 8, max = encSpec.max or encSpec.min or 11 },
            encounters = EncounterModel.pool(ctx),
            alwaysEncounters = always,
            -- A climb rather than a region: guaranteed encounters laid out in authored order by distance
            -- from the start, and the objective on the farthest dead-end there is. See
            -- Overworld:placeEncounters and :placeObjectiveAndGates.
            ascent = mp.ascent,
            seed = os.time() + math.floor(((love.timer and love.timer.getTime()) or 0) * 1000) % 100000,
        }
        game.grid = Overworld.generate(params)
    end
    game.activePanel = nil
    game.complete = false
    -- Per-run scratch for companion overworld abilities (banked vigils/doses/steps/forage). Reset each
    -- quest, like the fog -- it is a fresh run, not a holiday.
    game.abilityState = resume and resume.abilityState or {}
    -- Per-run relic inventory + scratch (models/relic.lua), reset each quest exactly like abilityState and
    -- the fog: relics are CARRIED, not kept -- picked up on the expedition, gone when it ends.
    game.relicState = resume and resume.relicState or Relic.newState()
    game.toasts = {} -- transient ability feedback lines (see game:pushToast)
    game.map = OverworldMap.new(game.grid, {
        onEncounter = function(cell) game:openEncounter(cell) end,
        -- The autosave seam, fired one beat BEFORE the step onto an un-engaged stop: the snapshot is
        -- taken with the token still on the tile it is leaving, so Continue lands the player in the
        -- overworld a step short of the fight -- time to open the Loadout, spend a dose, re-form the
        -- party -- instead of resuming inside the battle they were about to walk into.
        onApproach = function() saveRun() end,
        -- Every landed tile drives the per-step abilities (Kaya's forage, Saber's steps, ...) and the
        -- per-step relics (Poacher's Map, a Vice's road-toll).
        onArrive = function(cell) fireAbility("step", { cell = cell }); fireRelics("step", { cell = cell }) end,
        -- Fog-of-war radius: the map's own reveal-a-neighbourhood radius (3 for a rolled board, 2 for an
        -- authored leg -- see models/overworld.lua), widened by a torch-carrier AND by Gyeom's Ledger.
        visionRadius = math.max(game.grid.visionRadius or 2, Player.visionRadius(player))
            + OverworldAbility.visionBonus(player),
    })

    -- On a resume, seat the token where the player quit (the map widget otherwise spawns it at the start
    -- cell). The grid already carries its fog and cleared stops from the snapshot; re-reveal around the
    -- landing tile so the current vision disc is lit, then snap the camera straight there (no pan-in).
    if resume then
        game.map.px, game.map.py = resume.px or game.map.px, resume.py or game.map.py
        game.map.keysHeld = resume.keysHeld or {}
        -- Restore the party's attrition (HP/mana/stamina) captured with the run, clamped to each pool's
        -- max. A resume is NOT a hub visit, so nothing else refills these -- reloading must not heal the
        -- party (that would make Continue a free heal). Keyed by char id, like the run snapshot stored them.
        for _, char in ipairs(game.player and game.player.roster or {}) do
            local pools = resume.resources and resume.resources[char.id]
            if pools then
                for stat, current in pairs(pools) do
                    local res = char.stats and char.stats[stat]
                    if type(res) == "table" then
                        res.current = math.max(0, math.min(res.max or current, current))
                    end
                end
            end
        end
        game.grid:reveal(game.map.px, game.map.py, game.map.visionRadius)
        game.map:updateCamera()
        game.map:snapCamera()
    end

    -- Overworld tutorial state (only the prologue's flight leg sets `tutorial = "flight"`). The coach
    -- runs move -> loadout -> equip; the Loadout button stays HIDDEN until the first chest is opened,
    -- so the panel is introduced only once there is loot to put in it. Both are inert on a normal
    -- board quest -- the button shows from the start and no bubble is ever drawn.
    game.tutorial = mp.tutorial
    -- A scripted leg (the debut's aftermath walk) hides the Back button the same way the flight
    -- tutorial does, without turning the coach on -- it is a cutscene the reward rides on, not a
    -- board quest to abandon. See backVisible and arena_debut's followUp.
    game.scripted = mp.scripted
    game.itemsVisible = (mp.tutorial ~= "flight")
    -- The Use button's own gate, held shut for the flight leg until the first fight is won (see
    -- useVisible and the combat onWin below). True from the start everywhere else.
    game.useUnlocked = (mp.tutorial ~= "flight")
    game.coach = nil

    -- Autosave the run so quitting mid-quest resumes onto the map (states/menu.lua's Continue). Only a
    -- board quest is resumable (runResumable) -- a scripted/tutorial leg has no hub to return to. The live
    -- grid + map widget are parked on the player so ANY later Player.save (a won fight's spoils, the next
    -- encounter) re-snapshots the current board; cleared on the way out (clearRun / hub.enter backstop).
    if runResumable() and quest and quest.id then
        game.player.activeRun = {
            questId = quest.id,
            prestige = game.prestige,
            grid = game.grid,
            map = game.map,
            abilityState = game.abilityState,
            relicState = game.relicState,
        }
        Player.save() -- the first autosave: entering the overworld (and, on a resume, re-establishing it)
    else
        clearRun()
    end

    -- A resume drops back onto the BOARD -- no opening scene (that plays once, on first entry), and never
    -- into an encounter: the autosave is taken on approach (the map widget's onApproach), one tile shy of
    -- the stop, precisely so Continue hands the player an overworld to act in first. Nothing is auto-opened
    -- here; walking onto the (still-uncleared) tile engages it, exactly as it did the first time.
    if resume then return end

    -- Last, once the map exists: a quest may open with a scene played OVER it. A conversation is a
    -- global overlay on a frozen state (main.lua), so the road, the markers and the fog sit there
    -- behind the box and nothing moves until the player dismisses it.
    --
    -- Fielded from `enter`, which is exactly once per leg -- returning from a battle deliberately
    -- skips this function (see the file header), so a won encounter never replays the scene.
    local opening = quest and quest.opening
    if opening then
        -- On the tutorial leg the move coaching begins the instant the opening scene is dismissed --
        -- not before, or it would draw behind the overlay the scene freezes the map under.
        require("models.conversation").play(opening, function()
            if game.tutorial == "flight" then game.coach = "move" end
        end)
    elseif mp.tutorial == "flight" then
        game.coach = "move"
    end
end

-- Engaging an encounter. Combat kinds (combat / elite / objective) drop into the
-- battle arena; the non-combat kinds (town / treasure) keep the simple modal.
function game:openEncounter(cell)
    local kind = cell.encounter.kind
    local mp = game.quest and game.quest.map or {}

    -- No autosave here: the pre-encounter save already happened one beat ago, on APPROACH (the map's
    -- onApproach -> saveRun), with the token still on the previous tile. Saving again now would overwrite
    -- that with a snapshot standing on the stop itself -- which is what used to drop a resumed run straight
    -- into the battle. Each resolution below saves AGAIN, so a cleared stop persists past this point.

    -- A non-combat "meeting" objective: reaching the tile plays a scene and ends the leg instead of
    -- dropping into a fight. This is how the debut's aftermath walk finishes -- Saber catches the party
    -- at the gate out and asks in (arena_debut's followUp -> arena_saber_joins). She is already on the
    -- roster (the debut's rewardCharacter), and the join banner the arena outro held for this scene
    -- folds onto it when it plays (Conversation.drainJoins). Completion routes exactly like a cleared
    -- combat objective: a scripted caller's onComplete goes home, a board quest pays out and returns.
    if kind == "objective" and mp.objective and mp.objective.meet then
        cell.cleared = true
        game.complete = true
        local function finish()
            if game.onComplete then
                game.onComplete()
                return
            end
            clearRun() -- the quest is over; Quest.complete's save below then writes no run to resume
            game.reward = Quest.complete(game.player, game.quest)
            if game.player and game.reward then game.player.pendingSummary = game.reward end
            State.switch(require("states.hub"))
        end
        if mp.objective.conversation then
            require("models.conversation").play(mp.objective.conversation, finish)
        else
            finish()
        end
        return
    end

    if kind == "combat" or kind == "elite" or kind == "objective" then
        -- The battle launch itself, deferred behind a fight-or-slip confirm for side fights (below).
        local function startBattle()
        -- Companion overworld abilities spend their banked readiness onto the party's carried resources
        -- right before the fight builds its units (the party chars ride in by reference): Rowan's Vigil
        -- readies the front line, Saber's Held Swing pours her banked steps into her opening.
        fireAbility("battleStart", { cell = cell })
        -- Relics spend their opening readiness the same way: a battleStart dispatch queues each combat
        -- relic's boon (a barrier, Haste, an empower) onto the party via grantBoon; battle setup drains
        -- that queue onto the units at spawn. And the trait-relics (Martyr's Bell) resolve to the actual
        -- members who wear them this fight, front-row or whole-party, by identity.
        local relicCtx = fireRelics("battleStart", { cell = cell })
        local openingBoons = Relic.openingBoons(relicCtx)
        local relicTraits = Relic.combatTraitsByChar(game.relicState, game.player, game.player and game.player.party)
        -- Tutorial leg only (the prologue's flight): snapshot the party BEFORE the fight so the defeat
        -- panel's "Try Again" can restart THIS same encounter with a whole party -- consumed potions and
        -- any downed member undone. In-memory only, no disk save. The cell is not yet marked `cleared`
        -- (onWin does that), so a retry preserves overworld progress and loot already collected. A normal
        -- quest takes no snapshot: losing it still costs the run (Return to Hub, below).
        local retrySnapshot = game.tutorial and game.player and Save.snapshot(game.player) or nil
        State.switch(require("states.battle"), {
            encounter = cell.encounter,
            biome = mp.biome,
            quest = game.quest,
            -- The objective's own scene, played over the board with the general standing on it
            -- (states/battle.lua's openingConversation). This is the ONLY seam an antagonist can
            -- speak from: `intro` plays over the hub before the party is even picked, and by the
            -- time `outro` runs the target of an `assassinate` is dead.
            opening = kind == "objective" and mp.objective and mp.objective.opening or nil,
            prestige = game.prestige,
            -- This fight's authored difficulty FLOOR: the level its enemies may never drop below,
            -- however green the company walking in is. Scaling takes over above it (models/growth.lua,
            -- Growth.combatantLevel), so a floor stops a beat being walked on a replay or in New Game+
            -- without freezing it at a level the party has long outgrown. Read off the objective first,
            -- then the quest, so a line can set one floor for all its fights and a single beat can raise it.
            floorLevel = (kind == "objective" and mp.objective and mp.objective.floorLevel)
                or (game.quest and game.quest.floorLevel) or nil,
            party = game.player and game.player.party or {},
            -- Run relics carried into this fight: `relicTraits` maps each party char to the trait ids its
            -- relics grant (battle stamps them onto the unit); `openingBoons` is the queue of opening
            -- statuses (barrier/Haste/empower) to lay on the named units at spawn. See models/relic.lua.
            relicTraits = relicTraits,
            openingBoons = openingBoons,
            -- The player's persistent marching grid (charId -> cell); specFor resolves it onto the party's
            -- spawns. See models/player.lua and the Formation tab of ui/panels/party.lua.
            formation = game.player and game.player.formation,
            -- The player's stash, by reference: an item stolen mid-battle by a thief with a full
            -- grid is appended straight to it, so a theft survives whatever the battle does next.
            stash = game.player and game.player.stash,
            -- Victory resumes THIS overworld (no regenerate); the objective completes
            -- the quest instead. See the file header on why enter is skipped here.
            onWin = function(spoils)
                cell.cleared = true
                game.activePanel = nil
                -- The flight leg's Use lesson: the party walks off the survivors' defence wounded,
                -- with a pocket of draughts from the teaching chest and nowhere to spend them, so the
                -- button appears the moment that need does. Revealed on the leg's FIRST combat win --
                -- which the authored trail makes the defence (states/prologue.lua's FLIGHT_QUEST,
                -- stop 3) -- rather than keyed to an encounter id typed a second time over here.
                if game.tutorial == "flight" then game.useUnlocked = true end
                if kind == "objective" then
                    game.complete = true
                    -- Prologue (or any scripted caller) reroute: hand the cleared objective back to
                    -- its sequencer instead of paying out and going home. No reward, no save -- the
                    -- prologue is not a board quest.
                    if game.onComplete then
                        game.onComplete()
                        return
                    end
                    -- Gold skimmed off the enemy during the fight (the Skimmer's Cut) arrives on the
                    -- spoils table, which this branch otherwise ignores -- a quest pays through
                    -- Quest.complete, not through spoils. Granted here so a skim earned in a quest
                    -- battle is still earned, and deliberately BELOW the prologue's early return
                    -- above: that leg pays nothing at all, and the takings go with it.
                    if game.player and spoils and (spoils.gold or 0) > 0 then
                        Player.addGold(game.player, spoils.gold)
                    end
                    -- The single payout seam: gold and prestige are granted here, once, the quest is
                    -- marked done (which is what advances the sponsor's standing), and the game saves.
                    -- Losing the quest (onLoss) pays nothing, so a wipe costs the run.
                    clearRun() -- quest cleared; Quest.complete's save (and the endsCampaign->credits path) writes no run
                    game.reward = Quest.complete(game.player, game.quest)
                    -- The sting that marks a quest actually ending. Until now the single loudest
                    -- silence in the game was here: the objective clears, the board goes quiet, and
                    -- nothing at all says the run is over.
                    require("models.sound").play("quest.complete")
                    -- Hand the reward (gold/prestige/rep + the roster's level-ups) to the hub, which
                    -- opens the Company Advancement overlay on entry and clears this once shown.
                    if game.player and game.reward then game.player.pendingSummary = game.reward end
                    -- An outro scene plays over the (frozen) final battle frame before returning to
                    -- the hub; the hub then opens the reward summary. No outro -> straight home.
                    --
                    -- A quest may also hand off to a short follow-up overworld leg BEFORE the hub -- the
                    -- debut walks the party off the sand, where Saber catches them and asks in
                    -- (arena_debut's inline `followUp`). It runs as a scripted traversal (launched with
                    -- its own onComplete back to the hub), so it never lands on the board and pays out
                    -- nothing itself. When there is a followUp the outro DEFERS its join banner: the
                    -- recruit belongs to the meeting the leg ends on, not to the arena scene before it.
                    local followUp = game.quest and game.quest.followUp
                    local function goNext()
                        -- The campaign's last quest does not go home. `endsCampaign` is carried on the
                        -- quest (data/quests/quest_the_gate_below.lua) rather than a quest id compared here,
                        -- so this state never learns which file is the ending and a second one costs
                        -- no engine edit. New Game+ is offered because the run is, by definition, over.
                        if game.quest and game.quest.endsCampaign then
                            State.switch(require("states.credits"), { newGamePlus = true })
                        elseif followUp then
                            State.switch(require("states.game"), followUp, game.prestige, game.player,
                                function() State.switch(require("states.hub")) end)
                        else
                            State.switch(require("states.hub"))
                        end
                    end
                    if game.quest and game.quest.outro then
                        require("models.conversation").play(game.quest.outro, goNext, nil,
                            followUp and { deferJoins = true } or nil)
                    else
                        goNext()
                    end
                else
                    -- A combat/elite win: grant the spoils the battle summary just revealed (gold +
                    -- loot), save, then resume THIS overworld. The panel only displayed them; this is
                    -- the single grant, so nothing double-counts.
                    if spoils then
                        if (spoils.gold or 0) > 0 then Player.addGold(game.player, spoils.gold) end
                        for _, id in ipairs(spoils.loot or {}) do Player.grantItem(game.player, id) end
                        Player.save()
                    end
                    -- Companion abilities react to the win (Amana mends, Ren distils a dose, Rowan banks a
                    -- vigil, Clem takes her cut, Gyeom studies), then save so their effects persist.
                    fireAbility("encounterCleared", { cell = cell, spoils = spoils })
                    -- ...and the relics react to it too (Pilgrim's Coin pays, Alms Bowl mends, a Vice bites).
                    fireRelics("encounterCleared", { cell = cell, spoils = spoils })
                    if game.player then Player.save() end
                    -- Resuming the map does NOT re-run game.enter, so the overworld bed the battle
                    -- swapped out for its victory sting has to be restored here by hand (idempotent).
                    require("models.sound").music("music.overworld")
                    State.current = game
                end
            end,
            -- "Try Again": restore the party from the pre-fight snapshot, then hand the player back to
            -- the OVERWORLD one tile shy of the fight -- not straight into a rematch -- so they can open
            -- the Loadout and re-equip before re-engaging. Restore the party in place (so game.player
            -- and Player.active -- the same table -- both carry the fresh roster/party/inventory) and
            -- refill resources; the cell was never marked `cleared`, so stepping back onto it re-triggers
            -- this same fight. State.current (not State.switch) resumes the existing overworld map without
            -- re-running enter -- the same seam onWin uses to return from a won combat.
            onRetry = retrySnapshot and function()
                local fresh = Save.restore(retrySnapshot)
                if fresh then
                    for k, v in pairs(fresh) do game.player[k] = v end
                end
                Player.restore(game.player) -- a retry is a fresh attempt: the party opens whole
                -- Drop the defeat grey (and any low-HP vignette the loss froze on screen) before the map
                -- comes back. Resuming through State.current skips game.enter, so nothing else clears it
                -- and the overworld would sit desaturated until the next state switch (ui/screen_fx.lua).
                ScreenFx.reset()
                game.activePanel = nil
                game.map:retreatFromEncounter()
                -- Same seam as the won-combat resume above: restore the overworld bed the defeat
                -- swapped out, since stepping back onto the map here skips game.enter.
                require("models.sound").music("music.overworld")
                State.current = game
            end or nil,
            -- "Return to Hub": give the fight up and fail the quest (no reward). Offered only once there
            -- is a hub to return to -- the prologue's flight leg (game.tutorial) has none yet, so there
            -- the panel shows Try Again alone.
            onLoss = (not game.tutorial) and function()
                -- A wipe fails the quest: drop its run so Continue can't resume a lost fight, and persist
                -- the drop before heading home.
                if game.player then game.player.activeRun = nil; Player.save() end
                State.switch(require("states.hub"))
            end or nil,
        })
        end -- startBattle

        -- Stepping onto a fight enters it immediately -- no confirm. You skip a fight by routing AROUND
        -- it: combats never sit on the objective spine (models/overworld.lua), and the marker's danger
        -- pips + the party strip already let you judge it before you commit the step. The boss takes
        -- Ren's dose pour first.
        if kind == "objective" then
            fireAbility("objectiveReached", { cell = cell })
            fireRelics("objectiveReached", { cell = cell })
        end
        startBattle()
        return
    end

    -- A narrative "Choose..." stop: no modal of its own. The branching dialogue overlay (ui/dialogue
    -- .lua) IS the encounter, and a choice's `effect` grants loot / sets a story flag on commit
    -- (models/story_effect.lua, wired in Conversation.play). Cleared before it plays so stepping back
    -- onto the tile can't replay it.
    if kind == "event" then
        cell.cleared = true
        if cell.encounter.conversation then
            -- Persist once the scene (and any effect its choice commits) resolves, so a resume neither
            -- replays the conversation nor re-grants its spoils. saveRun is a no-op off a resumable run.
            require("models.conversation").play(cell.encounter.conversation, saveRun)
        else
            saveRun() -- an eventless stop still cleared a cell worth persisting
        end
        return
    end

    -- A treasure cache is its own modal: the chest reveal (ui/panels/loot_reveal.lua) opens showing a
    -- CLOSED chest, and its Open button plays the opening + one-at-a-time loot reveal in place -- so the
    -- "open" screen already has the chest. Loot is granted only once the player OPENS and collects it
    -- (onCollect); dismissing the closed chest (onCancel) leaves the cell uncleared to try again.
    if kind == "treasure" then
        local enc = cell.encounter
        local def = enc.id and EncounterModel.get(enc.id)
        local loot = enc.loot or (def and def.loot) or {}
        if #loot == 0 then cell.cleared = true; saveRun(); return end -- empty cache: nothing to reveal
        game.activePanel = LootReveal.new({
            encounter = enc,
            loot = loot,
            onCollect = function()
                cell.cleared = true
                for _, id in ipairs(loot) do Player.grantItem(game.player, id) end
                if game.tutorial == "flight" and not game.itemsVisible then
                    game.itemsVisible = true
                    game.coach = "loadout" -- the loot has somewhere to go now; introduce the panel
                end
                game.activePanel = nil
                -- Persist the collected loot AND the cleared chest together, so a resume can't re-open it.
                saveRun()
            end,
            onCancel = function() game.activePanel = nil end,
        })
        return
    end

    -- A Reliquary: rolls ONE run relic (models/relic.lua) from the eligible shelf, biased by the
    -- blueprint's tier and never a duplicate of what the run already holds, and offers it. TAKE grants it
    -- into game.relicState; LEAVE (or the X) leaves the cell uncleared to reconsider. An empty shelf (the
    -- run already holds everything eligible) pays a small gold consolation rather than an empty panel.
    if kind == "relic_cache" then
        local enc = cell.encounter
        local def = enc.id and EncounterModel.get(enc.id)
        local id = Relic.roll(Relic.pool({
            prestige = game.prestige,
            tier = enc.tier or (def and def.tier) or nil,
            exclude = game.relicState,
        }))
        if not id then -- shelf exhausted: don't strand the player on an empty reliquary
            cell.cleared = true
            if game.player then Player.addGold(game.player, 15); game:pushToast("The reliquary is bare  +15g") end
            saveRun()
            return
        end
        game.activePanel = RelicReveal.new({
            title = enc.name or "Reliquary",
            relic = { id = id, info = Relic.info(id) },
            onTake = function()
                cell.cleared = true
                Relic.grant(game.relicState, id)
                game:pushToast("Relic taken: " .. (Relic.info(id).name or id))
                game.activePanel = nil
                saveRun()
            end,
            onLeave = function() game.activePanel = nil end,
        })
        return
    end

    -- A Sin's Altar: rolls a VICE relic and offers it for an upfront toll in gold. Pay and it's yours
    -- (power with a standing cost); leave and the coin -- and the temptation -- stays in your purse. The
    -- greed gamble made into a stop. An empty vice-shelf just clears (nothing to tempt with).
    if kind == "shrine" then
        local id = Relic.roll(Relic.pool({
            prestige = game.prestige, alignment = "vice", exclude = game.relicState,
        }))
        if not id then cell.cleared = true; saveRun(); return end
        local price = 20 + game.prestige * 8
        local canPay = game.player and (game.player.gold or 0) >= price
        game.activePanel = RelicReveal.new({
            title = cell.encounter.name or "Sin's Altar",
            relic = { id = id, info = Relic.info(id) },
            priceLabel = "Offering: " .. price .. " gold",
            canPay = canPay,
            onTake = function()
                if not (game.player and Player.spendGold(game.player, price)) then return end
                cell.cleared = true
                Relic.grant(game.relicState, id)
                game:pushToast("The altar takes " .. price .. "g and gives: " .. (Relic.info(id).name or id))
                game.activePanel = nil
                saveRun()
            end,
            onLeave = function() game.activePanel = nil end,
        })
        return
    end

    -- The Fence: a wandering market. Rolls a small stock of run relics ONCE (stored on the cell so a
    -- re-step shows the same shelf, never a fresh reroll) and sells them for gold. Leaving keeps the cell
    -- so you can come back and spend later; a bought relic stays marked sold.
    if kind == "fence" then
        local enc = cell.encounter
        if not enc.stock then
            local exclude = {}
            for _, hid in ipairs(game.relicState.held or {}) do exclude[hid] = true end
            enc.stock = {}
            for _ = 1, 3 do
                local id = Relic.roll(Relic.pool({ prestige = game.prestige, exclude = exclude }))
                if not id then break end
                exclude[id] = true
                local info = Relic.info(id)
                local price = (info.tier == "rare" and 55 or 30) + game.prestige * 6
                if info.alignment == "vice" then price = math.floor(price * 0.7) end -- a Vice sells cheaper
                enc.stock[#enc.stock + 1] = { id = id, price = price, bought = false }
            end
        end
        if #enc.stock == 0 then cell.cleared = true; saveRun(); return end
        local stock = {}
        for _, s in ipairs(enc.stock) do
            stock[#stock + 1] = { id = s.id, info = Relic.info(s.id), price = s.price, bought = s.bought, src = s }
        end
        game.activePanel = Fence.new({
            title = enc.name or "The Fence",
            stock = stock,
            gold = function() return (game.player and game.player.gold) or 0 end,
            onBuy = function(entry)
                if game.player and Player.spendGold(game.player, entry.price) then
                    Relic.grant(game.relicState, entry.id)
                    if entry.src then entry.src.bought = true end -- persist the sale on the cell's shelf
                    game:pushToast("Bought: " .. (Relic.info(entry.id).name or entry.id))
                    saveRun()
                    return true
                end
                return false
            end,
            onClose = function() game.activePanel = nil; saveRun() end,
        })
        return
    end

    -- A Crossroads: a branching gamble (models/crossroads.lua) with real stakes -- a relic, coin, a wound.
    -- Choosing commits and clears the stop; backing out (X/Esc) leaves it to reconsider. The mechanics come
    -- in through a ctx of helpers, so the dilemma data never touches a model directly.
    if kind == "crossroads" then
        local rnd = function() return (love.math and love.math.random()) or math.random() end
        local ctx = {
            rnd = rnd,
            notify = function(m) game:pushToast(m) end,
            gold = function() return (game.player and game.player.gold) or 0 end,
            addGold = function(n) if game.player then Player.addGold(game.player, n) end end,
            reveal = function() game:restStudy() end,
            drainParty = function(n)
                for _, c in ipairs((game.player and game.player.party) or {}) do
                    local hp = c.stats and c.stats.health
                    if type(hp) == "table" then hp.current = math.max(1, (hp.current or hp.max) - n) end
                end
            end,
            grantRelic = function(tier)
                local id = Relic.roll(Relic.pool({ prestige = game.prestige, tier = tier, exclude = game.relicState }))
                if not id then return nil end
                Relic.grant(game.relicState, id)
                game:pushToast("You gain: " .. (Relic.info(id).name or id))
                return Relic.info(id).name or id
            end,
        }
        local dilemma = Crossroads.roll(rnd)
        local options = {}
        for _, o in ipairs(dilemma.options) do
            options[#options + 1] = {
                label = o.label, desc = o.desc,
                cb = function()
                    cell.cleared = true
                    o.resolve(ctx)
                    game.activePanel = nil
                    saveRun()
                end,
            }
        end
        game.activePanel = Choice.new({
            title = cell.encounter.name or "Crossroads",
            prompt = dilemma.prompt,
            options = options,
            onClose = function() game.activePanel = nil end, -- back out, reconsider
        })
        return
    end

    -- A Rest is a DECISION, not just a breather: Mend the party, Sharpen a lasting run edge, or Study the
    -- ground (models/relic.lua + the fog reveal). One only; leaving (X/Esc) forgoes it and leaves the cell
    -- to reconsider. The companions plug in here later (Amana strengthens Mend, Gyeom strengthens Study).
    if kind == "rest" then
        game.activePanel = RestChoice.new({
            title = cell.encounter.name or "Make Camp",
            onMend = function()
                cell.cleared = true
                game:restMend()
                saveRun()
            end,
            onSharpen = function()
                cell.cleared = true
                local got = Relic.grant(game.relicState, "relic_honed_edge")
                game:pushToast(got and "You hone your edge  (Honed Edge)" or "Your edge is already keen")
                game.activePanel = nil
                saveRun()
            end,
            onStudy = function()
                cell.cleared = true
                game:restStudy()
                game:pushToast("You study the ground")
                game.activePanel = nil
                saveRun()
            end,
            onClose = function() game.activePanel = nil end,
        })
        return
    end

    game.activePanel = EncounterPanel.new({
        encounter = cell.encounter,
        onResolve = function()
            cell.cleared = true
            game.activePanel = nil
            game:resolveNonCombat(cell)
            saveRun() -- persist the cleared stop (a town) so a resume doesn't re-offer it
        end,
        onClose = function() game.activePanel = nil end,
    })
end

-- MEND (a rest's first choice): refill every resource on the roster to full (Player.restore), then replay
-- the mend on a reveal panel so the player SEES what it did -- each party member's HP bar sweeps up to
-- full (ui/panels/rest.lua). Factored out of the rest resolution so RestChoice's Mend option and any
-- back-compat non-combat path both reach the same code.
function game:restMend()
    if not game.player then return end
    -- Snapshot each shown member's wound BEFORE the refill: the reveal animates from it, and once
    -- Player.restore runs the live stat is already at max, so this is the only place the "before"
    -- exists. Show the deployable party (who actually fight), falling back to the whole roster.
    local shown = (game.player.party and #game.player.party > 0 and game.player.party)
        or game.player.roster or {}
    local entries = {}
    for _, char in ipairs(shown) do
        local hp = char.stats and char.stats.health
        if type(hp) == "table" then
            entries[#entries + 1] = { char = char, from = hp.current or hp.max, max = hp.max or 0 }
        end
    end
    Player.restore(game.player)
    if #entries > 0 then
        game.activePanel = RestReveal.new({
            entries = entries,
            onDone = function() game.activePanel = nil end,
        })
    else
        game.activePanel = nil
    end
end

-- STUDY (a rest's third choice): lift the fog off the objective and every Reliquary on the board, so the
-- run's back half can be planned around the boss and a looting route toward the caches. Reuses the grid's
-- own reveal, the same one Gyeom's Ledger and the Cartographer's Eye relic use.
function game:restStudy()
    local grid = game.grid
    if not grid then return end
    if grid.objective then grid:reveal(grid.objective.x, grid.objective.y, 1) end
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and e.kind == "relic_cache" then grid:reveal(x, y, 1) end
        end
    end
end

-- Apply the outcome of a generic non-combat modal (a town) once the player confirms it. Treasure, rest
-- and relic caches all have their own panels now (see openEncounter); this is the fallback for the plain
-- "Enter/Resolve" stops that hand over nothing mechanical.
function game:resolveNonCombat(cell)
    local enc = cell.encounter
    if enc.kind == "rest" then game:restMend() end -- back-compat: any path still routing rest here mends
end

local function toHub()
    -- Abandoning a quest (Back / Esc) drops its run, so Continue won't resume the map they walked out of.
    -- Persist the drop so disk agrees; the hub would clear it as a backstop regardless.
    if game.player and game.player.activeRun then
        game.player.activeRun = nil
        Player.save()
    end
    State.switch(require("states.hub"))
end

function game.update(dt)
    -- Ability toasts fade regardless of whether a panel is open (they were pushed as the player
    -- returned from a fight, and should keep counting down while they read the result).
    if game.toasts then
        for i = #game.toasts, 1, -1 do
            local toast = game.toasts[i]
            toast.t = toast.t - dt
            if toast.t <= 0 then table.remove(game.toasts, i) end
        end
    end
    if game.activePanel then
        if game.activePanel.update then game.activePanel:update(dt) end
    else
        game.map:update(dt)
    end
end

function game.draw()
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    game.map:draw()

    game.drawHud()

    if game.activePanel then
        game.activePanel:draw()
    end

    -- The coach bubble sits on TOP of everything, including an open panel: the equip step points at
    -- the stash inside the Loadout screen.
    game.drawCoach()
end

-- The flight tutorial's gold coach bubble, pinned to whatever the current step is about. Nil on any
-- other quest (game.coach stays nil), so this is a no-op everywhere but the prologue's flight leg.
function game.drawCoach()
    local step = game.coach
    if not step then return end
    if step == "move" and not game.activePanel then
        local node = hintNode("move_hint")
        CoachBubble.draw(Locale.text("conversation_tutorial_flight", node), game.map:tokenRect(),
            { prefer = "above", bounds = COACH_BOUNDS })
    elseif step == "loadout" and not game.activePanel and game.itemsVisible then
        local node = hintNode("loadout_hint")
        -- The Items button lives in the top HUD strip, above COACH_BOUNDS; give this one bubble a
        -- bounds that reaches up to the button so it can sit directly BELOW it, tail pointing up.
        local belowBounds = { x = 20, y = itemsButton.y,
            w = Scale.WIDTH - 40, h = Scale.HEIGHT - itemsButton.y - 44 }
        CoachBubble.draw(Locale.text("conversation_tutorial_flight", node), itemsButton,
            { prefer = "below", key = loadoutKey(), bounds = belowBounds })
    elseif step == "equip" and game.activePanel and game.activePanel.coachAnchor then
        local anchor = game.activePanel:coachAnchor()
        if anchor then
            local node = hintNode("equip_hint")
            local text, key = Locale.coachLine("conversation_tutorial_flight", node)
            CoachBubble.draw(text, anchor, { prefer = "above", key = key, bounds = COACH_BOUNDS })
        end
    end
end

function game.drawHud()
    -- Back button. Hidden during the flight tutorial (see backVisible).
    if backVisible() then
        love.graphics.setColor(0.20, 0.23, 0.32)
        love.graphics.rectangle("fill", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.rectangle("line", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.setFont(hudFont)
        love.graphics.printf("Back", backButton.x, backButton.y + backButton.h / 2 - 8,
            backButton.w, "center")
    end

    -- Items button. Hidden on the flight tutorial until the first chest is opened (game.itemsVisible),
    -- so the Loadout panel is introduced only once there is loot to arrange.
    if game.itemsVisible then
        love.graphics.setColor(0.20, 0.23, 0.32)
        love.graphics.rectangle("fill", itemsButton.x, itemsButton.y, itemsButton.w, itemsButton.h, 6, 6)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.rectangle("line", itemsButton.x, itemsButton.y, itemsButton.w, itemsButton.h, 6, 6)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.setFont(hudFont)
        love.graphics.printf("Items", itemsButton.x, itemsButton.y + itemsButton.h / 2 - 8,
            itemsButton.w, "center")
    end

    -- Use button (drink a potion), beside Items. Same visibility gate save for the flight tutorial.
    if useVisible() then
        love.graphics.setColor(0.20, 0.23, 0.32)
        love.graphics.rectangle("fill", useButton.x, useButton.y, useButton.w, useButton.h, 6, 6)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.rectangle("line", useButton.x, useButton.y, useButton.w, useButton.h, 6, 6)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.setFont(hudFont)
        love.graphics.printf("Use", useButton.x, useButton.y + useButton.h / 2 - 8,
            useButton.w, "center")
    end

    -- Party button, beside Use. Opens the HP/mana + marching-grid panel.
    if partyVisible() then
        love.graphics.setColor(0.20, 0.23, 0.32)
        love.graphics.rectangle("fill", partyButton.x, partyButton.y, partyButton.w, partyButton.h, 6, 6)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.rectangle("line", partyButton.x, partyButton.y, partyButton.w, partyButton.h, 6, 6)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.setFont(hudFont)
        love.graphics.printf("Party", partyButton.x, partyButton.y + partyButton.h / 2 - 8,
            partyButton.w, "center")
    end

    -- Always-on party HP/mana strip: the run's attrition, legible while routing (models/player.lua).
    -- Pass the mouse (logical space) so the per-companion ability badge shows its tooltip on hover.
    if partyVisible() then
        local mx, my
        if InputMode.isMouse() then mx, my = Scale.toGame(love.mouse.getPosition()) end
        PartyStatus.drawStrip(game.player, 16, 60, mx, my, game.abilityState)
        -- Run relics carried this quest, top-right (models/relic.lua) -- the snowball, legible while routing.
        RelicStrip.draw(game.relicState, Scale.WIDTH - 16, 60, mx, my)
    end

    -- Companion-ability toasts, stacked just under the party strip so ability feedback groups with the
    -- party it comes from. Newest on top; each fades over its life.
    if game.toasts and #game.toasts > 0 then
        love.graphics.setFont(hudFont)
        local baseY = 60 + PartyStatus.stripHeight(#(game.player and game.player.party or {})) + 6
        for i, toast in ipairs(game.toasts) do
            local a = math.min(1, toast.t / 0.6) -- fade out over the last 0.6s
            love.graphics.setColor(0.85, 0.9, 0.7, a)
            love.graphics.print(toast.text, 18, baseY + (i - 1) * 20)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- Quest name + objective hint.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(game.quest and game.quest.name or "Quest", 0, 20, Scale.WIDTH, "center")

    -- Keys held (only shown when the map has locks).
    local total = #game.grid.keyIds
    if total > 0 then
        local held = 0
        for _ in pairs(game.map.keysHeld) do held = held + 1 end
        love.graphics.setFont(hudFont)
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.printf("Keys: " .. held .. " / " .. total, 0, 52, Scale.WIDTH, "center")
    end

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse
    -- otherwise. The items key only appears once the Loadout button itself does.
    local items = game.itemsVisible and (InputMode.isGamepad() and "Y: items      " or "I: items      ") or ""
    local use = useVisible() and (InputMode.isGamepad() and "X: use      " or "U: use      ") or ""
    local party = partyVisible() and (InputMode.isGamepad() and "LB: party      " or "P: party      ") or ""
    -- The "back to hub" hint is dropped alongside the button itself during the flight tutorial.
    local back = backVisible() and (InputMode.isGamepad() and "Back: hub" or "Esc: hub") or ""
    local hint = InputMode.isGamepad()
        and ("Move: D-pad / Stick      " .. items .. use .. party .. back)
        or ("Move: WASD / Arrows / click adjacent tile      " .. items .. use .. party .. back)
    love.graphics.printf(hint, 0, Scale.HEIGHT - 30, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)
end

function game.mousemoved(x, y, dx, dy)
    if game.activePanel then
        game.activePanel:mousemoved(x, y)
    else
        game.map:mousemoved(x, y)
    end
end

-- Hand over the Back / Items buttons, or defer to an open panel; arrow over the overworld map (a
-- click there travels -- map navigation, not a button). See ui/cursor.lua.
function game:cursorKind(x, y)
    if game.activePanel then
        return game.activePanel.cursorKind and game.activePanel:cursorKind(x, y) or "arrow"
    end
    if (backVisible() and backContains(x, y)) or (game.itemsVisible and rectContains(itemsButton, x, y))
        or (useVisible() and rectContains(useButton, x, y))
        or (partyVisible() and rectContains(partyButton, x, y)) then
        return "hand"
    end
    return "arrow"
end

function game.mousepressed(x, y, button)
    if game.activePanel then
        game.activePanel:mousepressed(x, y, button)
    elseif button == 1 and backVisible() and backContains(x, y) then
        toHub()
    elseif button == 1 and game.itemsVisible and rectContains(itemsButton, x, y) then
        openLoadout()
    elseif button == 1 and useVisible() and rectContains(useButton, x, y) then
        openConsumables()
    elseif button == 1 and partyVisible() and rectContains(partyButton, x, y) then
        openParty()
    else
        game.map:mousepressed(x, y, button)
    end
end

-- Only panels that scroll or drag define these; the overworld map handles neither.
function game.mousereleased(x, y, button)
    local panel = game.activePanel
    if panel and panel.mousereleased then panel:mousereleased(x, y, button) end
end

function game.wheelmoved(dx, dy)
    local panel = game.activePanel
    if panel and panel.wheelmoved then panel:wheelmoved(dx, dy) end
end

function game.keypressed(key)
    if game.activePanel then
        game.activePanel:keypressed(key)
    elseif key == "escape" and backVisible() then
        toHub()
    elseif key == "i" and game.itemsVisible then
        openLoadout()
    elseif key == "u" and useVisible() then
        openConsumables()
    elseif key == "p" and partyVisible() then
        openParty()
    else
        game.map:keypressed(key)
    end
end

function game.gamepadpressed(joystick, button)
    if game.activePanel then
        game.activePanel:gamepadpressed(joystick, button)
    elseif button == "back" and backVisible() then
        toHub()
    elseif button == "y" and game.itemsVisible then
        openLoadout()
    elseif button == "x" and useVisible() then
        openConsumables()
    elseif button == "leftshoulder" and partyVisible() then
        openParty()
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
