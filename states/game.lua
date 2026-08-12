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
local Vendor = require("models.vendor")   -- the sponsoring house behind a quest, for its cache stock
local Material = require("models.material")
local Item = require("models.item")     -- the Merchant's shelf prices come off the blueprints
local Spoils = require("models.spoils") -- ...and its stock off the same band a fight's loot rolls in
local EncounterPanel = require("ui.panels.encounter")
local LootReveal = require("ui.panels.loot_reveal")
local RelicOffer = require("ui.panels.relic_offer")   -- the Reliquary's pick-one-of-three
local RelicReveal = require("ui.panels.relic_reveal") -- the Sin's Altar's single relic + toll
local Merchant = require("ui.panels.merchant") -- the road's shop: ordinary goods for gold
local Choice = require("ui.panels.choice")
local Crossroads = require("models.crossroads")
local RestChoice = require("ui.panels.rest_choice")
local RestReveal = require("ui.panels.rest")
local EncounterModel = require("models.encounter")
local Muster = require("models.muster")                     -- how the company stands against a fight
local EncounterBattle = require("models.encounter_battle")  -- the board + the payout, shared with states/battle.lua
local Autobattle = require("models.autobattle")             -- and the fight itself, run with nobody watching
local Combat = require("models.combat")
local Debug = require("models.debug") -- gates the walk-off's calibration warning to a dev build
local BattleSummary = require("ui.panels.battle_summary")
local Party = require("ui.panels.party")
local Consumables = require("ui.panels.consumables")
local PartyStatus = require("ui.party_status")
local RelicStrip = require("ui.relic_strip")
local OverworldAbility = require("models.overworld_ability")
local Descent = require("models.descent") -- a run as a stack of floors, their circles, the landing between
local Experience = require("models.experience") -- what levels a descent's company, since no prestige does
local Relic = require("models.relic")
local Meal = require("models.meal") -- the Cafe's supper: one platter, worn by the company all run
local Wound = require("models.wound") -- what a body that went down carries out of the run
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
-- lesson -- and a potion has nothing to heal yet.
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

-- The always-on party HP/mana strip rides on every normal quest, but not the flight tutorial: that
-- leg's HUD is deliberately spare and its coach bubble lives where the strip would sit. The strip IS
-- the readout now -- it once had a Party button opening the same figures at modal size, which stopped
-- earning its place on the HUD the day the deployment phase took the marching grid out of that panel.
local function partyVisible()
    return game.tutorial ~= "flight"
end

-- A transient on-screen line an ability pushes when it fires (Amana heals X, Kaya forages, ...). Fades
-- over TOAST_LIFE; the newest sits on top. Capped so a flurry of wins can't stack off the screen.
local TOAST_LIFE = 3.2
function game:pushToast(text)
    game.toasts = game.toasts or {}
    table.insert(game.toasts, 1, { text = text, t = TOAST_LIFE })
    while #game.toasts > 5 do table.remove(game.toasts) end
end

-- Say what a walked-over marker just handed over (ui/overworld_map.lua's onPickup). A cache and a key
-- are the only two marks that pay out WITHOUT opening a panel -- they are simply taken as the token
-- crosses them -- so this toast is the whole of their feedback, and the only place the copper wedge on
-- the trail ever names itself. Materials are listed by name and count, sorted so the same haul always
-- reads the same way; they ride the run in `cacheHaul` and are banked by Quest.complete.
local function announcePickup(kind, payload)
    if kind == "key" then
        game:pushToast("Key taken -- it opens a barred gate")
        return
    end
    local parts = {}
    for id, n in pairs((payload and payload.materials) or {}) do
        local def = Material.get(id)
        parts[#parts + 1] = ((def and def.name) or id) .. " x" .. n
    end
    if #parts == 0 then return end
    table.sort(parts)
    game:pushToast("Supply cache: " .. table.concat(parts, ", "))
end

-- Fire a companion overworld-ability event (models/overworld_ability.lua) for the active party, carrying
-- the per-run scratch (game.abilityState, reset each quest in enter), a toast notifier, and any event
-- extras (cell, spoils).
local function fireAbility(event, extra)
    local ctx = {
        player = game.player,
        party = game.player and game.player.roster,
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
        party = game.player and game.player.roster,
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

-- LEAVING WITHOUT THE OBJECTIVE. Put the company back exactly as it walked in, then drop the run.
--
-- This is the whole extraction rule in one function. A run's finds are granted the moment they are
-- picked up -- a chest's sword is in the stash and equippable at the next fight -- but they are not the
-- player's until the objective banks them. Both ways out that are not the objective come through here:
-- a wipe (the defeat panel's Return to Hub) and a walk-out (Back / Esc). They differ only in how the
-- player arrived; neither pays.
--
-- What comes back: items found, gold gained, gold SPENT (a Merchant's ware, a Sin's Altar toll), materials
-- picked, recipes, story flags. Reversing the spending is not generosity -- without it a forfeit would
-- launder run gold into permanent hub goods, which is the same hole from the other side.
--
-- What is NEVER at stake: the gear the company walked in with, its forge levels, the stash, the roster.
-- The snapshot IS that state, so restoring it can only take back what the run added.
--
-- Restored IN PLACE (field by field onto the existing table) so `game.player` and `Player.active` -- the
-- same table -- both carry the rolled-back company, exactly as the prologue's Try Again does. Returns
-- true when a rollback actually happened, so a caller can say so on screen.
local function rollbackRun()
    local run = game.player and game.player.activeRun
    local entry = run and run.entry
    if not entry then clearRun() return false end
    local fresh = Save.restore(entry)
    if not fresh then clearRun() return false end -- unreadable snapshot: drop the run, keep the player
    -- WOUNDS DO NOT ROLL BACK, and this is the one line in the file that has to know it.
    --
    -- The loop below is deliberately total -- it hands the player every key the entry snapshot holds,
    -- which is what makes the rollback correct without a list of what a run can change. `wounds` is
    -- the single exception, and it is an exception on purpose: the whole point of an injury is that it
    -- outlives the run that caused it, and a wipe restoring the pre-run wound count would hand the
    -- company back whole at the exact moment it was hurt worst. Held across the copy rather than
    -- excluded from the snapshot, so a resume still reads its wounds from disk.
    local wounds = game.player.wounds
    for k, v in pairs(fresh) do game.player[k] = v end
    game.player.wounds = wounds
    clearRun()
    return true
end

-- WHERE A DESCENT GOES WHEN IT ENDS, which is not where a quest goes.
--
-- A campaign quest ends at the city: the company lives there, the reward is banked there, and the
-- advancement overlay opens on the way in. A descent has no city. It is a separate game mode with its own
-- front screen (states/descent.lua), it banks nothing, and the company it musters at the gate does not
-- outlive the run -- so the account this hands over is the ONLY report the player gets, and after it the
-- run is gone.
--
-- `outcome` is how it ended -- "extracted", "wiped" or "left" -- and it is passed rather than inferred
-- because the three are indistinguishable by the time they arrive here: all three have dropped the run,
-- and only the caller knows whether that was a victory, a defeat or a decision.
--
-- The saved run goes with it. That is what "each run is clean" means in one line: there is no file left
-- for the next entry to find, so the next entry musters.
local function endDescent(outcome, result)
    result = result or {}
    result.outcome = outcome
    Descent.clearSaved()
    -- The throwaway company stops being the active player. Nothing would ask it for anything -- both
    -- doors into the hub call Player.start first -- but leaving a spent descent profile sitting in the
    -- global is exactly the sort of thing that is only ever discovered by a bug.
    Player.active = nil
    State.switch(require("states.descent"), { result = result })
end

-- WHAT THIS RUN IS CARRYING, and would lose by leaving any way but through the objective.
--
-- Read by DIFFING the live company against the entry snapshot rather than by tallying at each grant.
-- That is the whole reason it can be trusted: a chest, a fight's spoils, an event's gift, a relic's
-- payout and anything added later all land in the same places, and none of them has to remember to
-- report. There is no ledger to fall out of step with the stash.
--
-- Positive differences only. Drinking a potion the company marched in with is not a negative find, and
-- gold spent at the Merchant is not at stake -- a rollback would hand it back. What is shown is what a wipe
-- would actually take.
local function tallyItems(roster, stash)
    local t = {}
    local function add(it)
        if it and it.id then t[it.id] = (t[it.id] or 0) + (it.quantity or 1) end
    end
    for _, char in ipairs(roster or {}) do
        -- `pairs`, not a numeric walk: a live grid is keyed 1..9 with holes and the snapshot stores a
        -- sparse map. Both read the same this way.
        for _, it in pairs(char.inventory or {}) do add(it) end
    end
    for _, it in ipairs(stash or {}) do add(it) end
    return t
end

function game:refreshHaul()
    local run = game.player and game.player.activeRun
    local entry = run and run.entry
    if not entry then game.haul = nil return end

    local was = tallyItems(entry.roster, entry.stash)
    local now = tallyItems(game.player.roster, game.player.stash)
    local items = 0
    for id, n in pairs(now) do
        local gained = n - (was[id] or 0)
        if gained > 0 then items = items + gained end
    end

    local materials = 0
    for id, n in pairs(game.player.materials or {}) do
        local gained = (n or 0) - ((entry.materials or {})[id] or 0)
        if gained > 0 then materials = materials + gained end
    end
    -- The run's unbanked cache haul rides on the map, not the player, until the objective pays it out --
    -- so it has to be added by hand or the readout would under-report the very thing the caches exist
    -- for (models/spoils.lua, states/game.lua's objective branch).
    for _, n in pairs(game.map and game.map.cacheHaul or {}) do materials = materials + (n or 0) end

    local gold = math.max(0, (game.player.gold or 0) - (entry.gold or 0))

    game.haul = (items > 0 or gold > 0 or materials > 0)
        and { items = items, gold = gold, materials = materials } or nil
end

-- The haul as a plain phrase ("4 items, 210 gold, 6 stock"), or nil when the run has found nothing.
-- One writer for it, so the turn-back confirmation and the defeat panel name the same loss the same way
-- -- a player who reads "4 items" before the fight and "3 items" after it has been told the rule wrong.
function game:haulPhrase()
    if not game.haul then return nil end
    local parts = {}
    if game.haul.items > 0 then
        parts[#parts + 1] = game.haul.items .. (game.haul.items == 1 and " item" or " items")
    end
    if game.haul.gold > 0 then parts[#parts + 1] = game.haul.gold .. " gold" end
    if game.haul.materials > 0 then parts[#parts + 1] = game.haul.materials .. " stock" end
    return table.concat(parts, ", ")
end

-- WHAT A STOP LEAVES BEHIND, as a phrase ("2 Iron Scrap, Salt Iron"), or nil for a stop that salvages
-- nothing (everything that is not a fight).
--
-- Reads the same Spoils.materials the win will actually grant, with the same arguments, rather than
-- reproducing its table here -- so the telegraph cannot drift from the payout. A floor that promised
-- stock the fight then did not leave would be worse than promising nothing.
--
-- Ordered by name so two reads of the same marker never rearrange themselves under the cursor; `pairs`
-- over the result is unspecified.
function game:payoutPhrase(enc)
    if not (enc and (enc.kind == "combat" or enc.kind == "elite" or enc.kind == "objective")) then
        return nil
    end
    local got = Spoils.materials({
        kind = enc.kind, tier = enc.tier, houseMaterial = game.houseMaterial,
    })
    local parts = {}
    for id, n in pairs(got) do
        local def = Material.get(id)
        if def then parts[#parts + 1] = { name = def.name or id, n = n } end
    end
    if #parts == 0 then return nil end
    table.sort(parts, function(a, b) return a.name < b.name end)
    local out = {}
    for i, p in ipairs(parts) do
        out[i] = (p.n > 1 and (p.n .. " ") or "") .. p.name
    end
    return table.concat(out, ", ")
end

-- WHAT THE LAST FIGHT COST THE BODIES IN IT. states/battle.lua records who ended a fight down --
-- carried out on a win, simply down on a loss -- on `battle.fallen`, and this turns that into wounds
-- that outlive the run (models/wound.lua).
--
-- Read off the battle state rather than handed through the callback because there is nowhere to hand
-- it: onWin takes the spoils and onLoss takes nothing, and threading a second argument through both
-- would mean touching every launcher in the file for one of them. The field is cleared on every
-- battle.enter, so a stale list cannot be read twice.
--
-- The toast is the point of doing this here rather than silently in a model: an injury nobody is told
-- about is a bug report about the hub's healing.
function game:inflictWounds()
    local fallen = require("states.battle").fallen
    local hurt = Wound.inflict(game.player, fallen)
    -- Named off the instances the battle handed back rather than looked up by id: these ARE the
    -- roster's own tables, and a companion's name can be the one the player typed at creation.
    local byId = {}
    for _, char in ipairs(fallen or {}) do byId[char.id] = char end
    for _, id in ipairs(hurt) do
        local char = byId[id]
        game:pushToast(((char and char.name) or "Someone") .. " is wounded")
    end
    return hurt
end

-- THE LANDING. A floor is cleared and the party is standing at the head of the next stair, which is the
-- only place in the game that asks the question an extraction is actually about: is what you are carrying
-- worth more than what is below?
--
-- Both answers are real, and that is the whole design. Extract banks the haul and ends the run; Descend
-- keeps everything provisional for one more floor. Nothing about the board makes this decision for the
-- player, so the prompt has to carry the two facts they weigh it on -- what a wipe would cost them
-- (game:haulPhrase, the same words the turn-back prompt and the defeat panel use) and where they are
-- being asked to go. A choice between two unlabelled doors is not a choice.
--
-- Deliberately NOT closeable: `onClose` is nil, so Esc and B do not dismiss it. There is nowhere to back
-- out to -- the floor is over and the party is on the stair -- and a dismissable landing would strand the
-- player on a cleared board with no way forward.
function game:openLanding()
    local run = game.descent
    if not run then return end
    Descent.clearFloor(run)

    -- The CIRCLE below, not the ground below. A biome is where you will be standing; a sin is what you
    -- are going down to face, whose house the floor pays into and whose own cast holds its stair. It is
    -- also the thing the shuffle makes worth reading -- the ground is a consequence of it.
    --
    -- Under the seventh there is no circle left, and the landing says so outright: naming the Hollow
    -- Crown is the whole of the warning a player gets, and it is the one they most need. A descent has
    -- a bottom, and this is the stair that reaches it.
    local nextFloor = Descent.depth(run) + 1
    local below = Descent.nameOf(run, nextFloor)
    local last = Descent.isBottom(nextFloor)
    local carried = game:haulPhrase()

    game.activePanel = Choice.new({
        title = last and "There is one stair left." or "The stair goes down.",
        prompt = carried
            and ("You are carrying " .. carried .. ". It is yours only if you walk out with it.")
            or "You are carrying nothing yet.",
        options = {
            {
                label = last and "Go down to it" or "Go deeper",
                -- Phrased so the place NAMES itself rather than being slotted after an article: the
                -- sin takes none ("The next floor is Wrath"), which is also why the line names the
                -- circle rather than the ground it is fought on. The bottom is the one exception and
                -- takes its article, because it is a thing rather than a place.
                desc = last
                    and ("Below this there are no more circles. " .. below ..
                        " is waiting, and beating it ends the descent with everything you are carrying.")
                    or ("The next floor is " .. below .. ". Everything you carry stays at stake."),
                -- The same amber the turn-back prompt gives "Keep going": pressing on with the haul
                -- still unbanked. Note the landing INVERTS that prompt's morals -- there, walking out
                -- was the empty-handed answer; here it is the one that pays -- so the colours are
                -- assigned by what the option does to your stake, never by which one continues.
                accent = { 0.83, 0.73, 0.45 },
                cb = function()
                    game.activePanel = nil
                    Descent.advance(run)
                    State.switch(require("states.game"),
                        Descent.floorQuest(run, game.player), game.prestige, game.player)
                end,
            },
            {
                label = "Climb out",
                desc = carried and ("Walk out with " .. carried .. " and end the descent.")
                    or "End the descent and go back up.",
                accent = { 0.42, 0.80, 0.62 }, -- green: the answer that ends the run on your terms
                cb = function()
                    game.activePanel = nil
                    -- THE EXTRACTION. Dropping the run drops the rollback point with it, so the floors
                    -- below stop being able to take the haul back. What it no longer does is BANK: there
                    -- is nothing on the other side of a descent to bank into, and the company that
                    -- carried it out does not outlive the run either. See Descent.extract on what that
                    -- changed and why the landing's question is still a real one without it.
                    local out = Descent.extract(game.player, run)
                    clearRun()
                    endDescent("extracted", out)
                end,
            },
        },
    })
end

-- Persist the run if one is active (a resumable board quest). No-op otherwise, so it is safe to sprinkle at
-- every point the board changes -- entering the map, approaching an encounter, and resolving one. The
-- resolution saves matter: a treasure collected or an event resolved marks its cell cleared, and without
-- persisting that a resume would replay the stop and grant its spoils twice (a combat win already saves).
local function saveRun()
    if game.player and game.player.activeRun then
        Player.save()
        -- Every seam that changes what the run is carrying already passes through here -- a collected
        -- chest, a cleared fight, a bought relic, a paid toll -- so the readout is re-read here rather
        -- than at each of them. One call site instead of a dozen that could each forget.
        game:refreshHaul()
    end
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
    -- A DESCENT floor rather than a board quest. The descriptor is synthesized (models/descent.lua) and
    -- carries the run itself, which is what makes one expedition out of a stack of floors: the same table
    -- travels from floor to floor, so the rollback point taken at the top survives all of them.
    game.descent = quest and quest.descent or nil
    local mp = quest and quest.map or {}
    -- Which house's stock this run pays out in: the quest's SPONSOR, not the party's needs. That is the
    -- whole point -- running the Bastion's line yields Bastion stock, which the Arcanum's gear will want
    -- at the Forge, so the seven lines feed one economy. Resolved once here because BOTH payers need it:
    -- the map's caches (below) and every fight's salvage (models/spoils.lua, via the battle state).
    game.houseMaterial = Material.houseFor((Vendor.get(quest and quest.sponsor) or {}).class)

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
            cacheCount = mp.cacheCount, -- nil -> derived from the encounter count (Overworld.generate)
            houseMaterial = game.houseMaterial, -- the sponsor's stock; resolved once at the top of enter
            objective = mp.objective,
            -- Denser default boards (~8-11 stops) so a rolled run has room for the roguelike texture --
            -- caches, rests and fights between them (guaranteed variety + a combat-share cap live in
            -- Overworld:placeEncounters). A quest still overrides via its own mp.encounters.min/max.
            encounterCount = { min = encSpec.min or 8, max = encSpec.max or encSpec.min or 11 },
            -- A descent floor reweights the same pool -- more fights, fewer set-pieces, almost no
            -- texture -- because a floor is not a roadside. See Descent.floorPool for the argument;
            -- this is the dispatch.
            encounters = game.descent and Descent.floorPool(ctx) or EncounterModel.pool(ctx),
            -- ...and raises the share cap to match. Absent (every campaign leg) the generator keeps
            -- its own 0.6.
            combatShare = mp.combatShare,
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
    -- Per-run scratch for companion overworld abilities (banked vigils/doses/steps/forage) and the run's
    -- relic inventory (models/relic.lua). Reset each run, like the fog -- relics are CARRIED, not kept.
    --
    -- "Each run" is the load-bearing word once a run is a stack of floors. Descending is not a fresh
    -- expedition, so both ride on the descent between floors: without that, stepping down a stair would
    -- silently strip every relic the party had picked up, and each floor would be a new holiday. Three
    -- sources in priority order -- a quit-and-Continue (resume), the floor above (descent), or fresh.
    game.abilityState = (resume and resume.abilityState)
        or (game.descent and game.descent.abilityState) or {}
    game.relicState = (resume and resume.relicState)
        or (game.descent and game.descent.relicState) or Relic.newState()
    if game.descent then
        game.descent.abilityState = game.abilityState
        game.descent.relicState = game.relicState
    end
    game.toasts = {} -- transient ability feedback lines (see game:pushToast)
    -- Where the company stands against each fight on this board. The far side of every marker is
    -- priced lazily and once (game:cellMuster); the company's own worth is re-rated here and whenever
    -- a panel closes over it (game.update).
    game.encounterMuster = nil
    game:refreshMuster()
    game.map = OverworldMap.new(game.grid, {
        onEncounter = function(cell) game:openEncounter(cell) end,
        -- The autosave seam, fired one beat BEFORE the step onto an un-engaged stop: the snapshot is
        -- taken with the token still on the tile it is leaving, so Continue lands the player in the
        -- overworld a step short of the fight -- time to open the Loadout, spend a dose, re-form the
        -- party -- instead of resuming inside the battle they were about to walk into.
        onApproach = function() saveRun() end,
        -- Every landed tile drives the per-step abilities (Kaya's forage, Saber's steps, ...) and the
        -- per-step relics (Poacher's Map, a Vice's road-toll). `revealed` is how many cells that step
        -- lifted the fog off for the first time -- 0 when it only re-trod mapped ground -- so a hook that
        -- pays for EXPLORING can tell a discovery from a lap.
        onArrive = function(cell, revealed)
            fireAbility("step", { cell = cell, revealed = revealed })
            fireRelics("step", { cell = cell, revealed = revealed })
        end,
        -- A cache/key taken by walking over it: name it on screen (see announcePickup).
        onPickup = function(kind, payload) announcePickup(kind, payload) end,
        -- What colours a fight's marker and counts its pips: where the company stands against THIS fight
        -- (models/muster.lua). The map owns no roster and does no comparing -- it asks.
        musterBand = function(cell) return game:musterBand(cell) end,
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
        game.map.cacheHaul = resume.cacheHaul or {}
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
        -- Take the rollback point with NO run parked on the player. Save.snapshot folds the active run
        -- into what it writes, so snapshotting while a stale one is still attached would nest a run
        -- inside the entry snapshot inside the next run -- growing the save on every quest. The hub
        -- clears it on the way through and so does every exit; this is the belt to that pair of braces.
        game.player.activeRun = nil
        -- THE ROLLBACK POINT IS PER EXPEDITION, NOT PER BOARD. On a descent the second floor is a fresh
        -- game.enter with no `resume`, so taking a new snapshot here would bank everything floor one
        -- found -- turning a provisional haul permanent just by walking downstairs, and quietly making
        -- the extraction rule meaningless. The descent carries the snapshot from the top of the run, so
        -- the third source below is what makes a stack of floors one expedition.
        local entry = (resume and resume.entry)
            or (game.descent and game.descent.entry)
            or Save.snapshot(game.player)
        if game.descent then game.descent.entry = entry end
        game.player.activeRun = {
            questId = quest.id,
            prestige = game.prestige,
            -- Serialized by Save.snapshotRun and taken by Save.restoreRun BEFORE it tries Quest.get,
            -- since a floor id is never in Quest.defs.
            descent = game.descent,
            grid = game.grid,
            map = game.map,
            abilityState = game.abilityState,
            relicState = game.relicState,
            -- THE ROLLBACK POINT: the company exactly as it walked in. Everything a run finds -- chest
            -- loot, a fight's spoils, salvage, an event's gift -- still lands in the stash the instant it
            -- is picked up and equips at the Loadout like any other gear. What this makes it is
            -- PROVISIONAL: the objective banks it (clearRun drops this snapshot and the gains stand),
            -- and any other way out puts it all back (rollbackRun). The gear the player walked in with is
            -- never at stake -- a lost run costs what it found, never what it brought.
            --
            -- Taken ONCE, above, and carried by reference: a re-snapshot mid-run would quietly bank
            -- whatever had been picked up by then. On a resume the snapshot travels with the run, so
            -- quitting and continuing keeps the same rollback point rather than minting a new one.
            entry = entry,
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

-- ---------------------------------------------------------------------------
-- Muster: where the company stands against each fight on the board
-- ---------------------------------------------------------------------------

-- Re-rate the company. Cheap, but not per-frame cheap (it walks four bodies' grids), and it only
-- changes when the roster's gear does -- so it is recomputed at the two moments that can move it: the
-- run opening, and a panel closing (the Loadout is the one that re-kits anybody mid-run).
function game:refreshMuster()
    game.partyMuster = Muster.company(Muster.fielded(game.player))
    -- A won fight banks its spoils on the way back to the map and re-rates the company here; the run's
    -- ledger moved with it, so it is re-read on the same beat.
    game:refreshHaul()
end

-- What this fight is worth, memoised per cell. Fixed for the whole run -- an encounter's composition
-- is a deterministic function of prestige, and prestige does not move until the quest pays out -- so
-- this is computed once per marker and never again.
--
-- Deliberately kept in a side table rather than written onto `cell.encounter`: models/overworld.lua's
-- CELL_FIELDS persists that table whole into the run save, and a cached score would ride along and
-- come back stale into a run resumed at a different prestige.
function game:cellMuster(cell)
    game.encounterMuster = game.encounterMuster or {}
    local cached = game.encounterMuster[cell]
    if cached == nil then
        local enc = cell.encounter
        local def = enc and enc.id and EncounterModel.get(enc.id)
        cached = def and Muster.encounter(def, {
            prestige = game.prestige,
            quest = game.quest,
            floorLevel = game.quest and game.quest.floorLevel,
        }) or false
        game.encounterMuster[cell] = cached
    end
    return cached or nil
end

-- How this fight stands to the company, as a margin in percent -- nil for a cell there is no
-- comparison to make about.
function game:musterMargin(cell)
    if not EncounterBattle.cellEligible(cell) then return nil end
    if not game.partyMuster then game:refreshMuster() end
    return Muster.margin(game.partyMuster, game:cellMuster(cell))
end

-- ...and that margin as a band name, which is all the map wants (ui/overworld_map.lua's marker).
function game:musterBand(cell)
    return Muster.band(game:musterMargin(cell))
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
            -- A DESCENT floor's stair. The leg is over but the RUN is not: instead of paying out and
            -- going home, the landing asks whether there is a next floor. Extraction still happens
            -- through exactly one seam -- it has just moved from "the objective cleared" to "the player
            -- said so" (game:openLanding -> clearRun). Placed above the board-quest payout rather than
            -- inside it so a descent never touches Quest.complete, which has no floor to complete.
            if game.descent then
                game:openLanding()
                return
            end
            -- A `meet` objective extracts exactly as a fought one does: dropping the run drops the
            -- rollback point with it, so the leg's finds stand. See the combat objective's branch below.
            clearRun() -- the quest is over; Quest.complete's save below then writes no run to resume
            game.reward = Quest.complete(game.player, game.quest, game.map and game.map.cacheHaul)
            -- Same settle the fought path takes below: a line's tenth quest can release a companion, and
            -- this branch is the one where the farewell has ALREADY played (`meet` puts its scene before
            -- the payout, not after it), so the roster catches up immediately.
            if game.reward and game.reward.temptation then
                require("models.temptation").settle(game.player)
                require("models.player").save()
            end
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
        -- Everything that has to know WHO IS STANDING WHERE, resolved once the deployment phase commits
        -- and handed back to the battle. It cannot be computed here any more: the player chooses which of
        -- the company take the field, and on which tiles, over the real board (docs/deployment.md), so
        -- the front line does not exist until they have. Battle calls this with:
        --   deployed -- the company members actually placed, in placement order
        --   front    -- those of them standing on the forward line of the deploy zone
        -- and gets back the two things battle setup stamps onto the units at spawn.
        --
        -- What each half does is unchanged:
        --   * companion overworld abilities spend their banked readiness onto the party's carried
        --     resources (the chars ride in by reference): Rowan's Vigil readies the front line, Saber's
        --     Held Swing pours her banked steps into her opening;
        --   * relics do the same through a battleStart dispatch, queueing each combat relic's boon (a
        --     barrier, Haste, an empower) via grantBoon for battle setup to drain onto the units, and the
        --     trait-relics (Martyr's Bell) resolve to the members who wear them this fight, by identity.
        local function resolveOpening(deployed, front)
            local frontRow = function() return front or deployed end
            fireAbility("battleStart", { cell = cell, party = deployed, frontRow = frontRow })
            local relicCtx = fireRelics("battleStart", { cell = cell, party = deployed, frontRow = frontRow })
            return {
                openingBoons = Relic.openingBoons(relicCtx),
                -- Over the whole COMPANY, not just the deployed four: a party-scope relic is worn by
                -- everyone who marched, and a benched member has to arrive already wearing it when they
                -- rotate on. Only frontRow scope narrows, to the line actually put forward.
                relicTraits = Relic.combatTraitsByChar(game.relicState, game.player,
                    game.player and game.player.roster, front or deployed),
            }
        end

        -- A side-fight's takings, granted. THE single seam for them, and it is reached two ways now:
        -- from the battle summary's Continue when the fight was played, and from the walk-off below
        -- when it was not. Both panels only DISPLAY the spoils; this is where they land, which is what
        -- keeps them from ever being counted twice or paid differently depending on how the fight was
        -- resolved. (The objective pays through Quest.complete instead -- see onWin.)
        local function grantSideSpoils(spoils)
            if spoils then
                if (spoils.gold or 0) > 0 then Player.addGold(game.player, spoils.gold) end
                for _, id in ipairs(spoils.loot or {}) do Player.grantItem(game.player, id) end
                -- The salvage floor: every won fight leaves forging stock behind, so a stop that
                -- rolled no loot is still worth having stopped at (models/spoils.lua). Banked straight
                -- to the player rather than onto the run's cache haul, because a cleared fight does not
                -- un-clear -- there is nothing here for the objective's double-payout guard to protect.
                for id, n in pairs(spoils.materials or {}) do
                    Player.addMaterial(game.player, id, n)
                end
                Player.save()
            end
            -- Companion abilities react to the win (Amana heals, Ren distils a dose, Rowan banks a
            -- vigil, Clem takes her cut, Gyeom studies), then the relics do too (Pilgrim's Coin pays,
            -- Alms Bowl heals, a Vice bites). Save so their effects persist.
            fireAbility("encounterCleared", { cell = cell, spoils = spoils })
            fireRelics("encounterCleared", { cell = cell, spoils = spoils })

            -- THE DESCENT'S LEVEL-UPS, and the whole boundary between the two ladders in the game.
            --
            -- Combat banks experience on every body that acts, in every mode (models/experience.lua) --
            -- but in the campaign it is a counter nobody reads, because a campaign roster levels off
            -- prestige (Player.syncLevels) and always has. Here is the one place it is ever spent, and
            -- the gate is `game.descent`: a clean run musters at level 1 with no prestige behind it, so
            -- what it does in the fighting is the only thing that can grow it.
            --
            -- This seam rather than the battle's own end because it is ALREADY the single point every
            -- won fight passes through, side-fight and stair guardian alike (see the header above), so
            -- there is no second place that could forget. Growth.resolve is idempotent, so a body that
            -- earned nothing this fight costs a comparison.
            if game.descent and game.player then
                for _, up in ipairs(Experience.resolveParty(game.player.roster)) do
                    game:pushToast((up.char.name or up.char.id) .. " reaches level " .. up.toLevel)
                end
            end

            if game.player then Player.save() end
        end

        -- The battle launch itself, deferred behind the walk-off offer for a fight the company has
        -- outgrown (below).
        local function startBattle()
        -- Tutorial leg only (the prologue's flight): snapshot the party BEFORE the fight so the defeat
        -- panel's "Try Again" can restart THIS same encounter with a whole party -- consumed potions and
        -- any downed member undone. In-memory only, no disk save. The cell is not yet marked `cleared`
        -- (onWin does that), so a retry preserves overworld progress and loot already collected. A normal
        -- quest takes no snapshot: losing it still costs the run (Return to Hub, below).
        local retrySnapshot = game.tutorial and game.player and Save.snapshot(game.player) or nil
        State.switch(require("states.battle"), {
            encounter = cell.encounter,
            biome = mp.biome,
            -- What the ground under this marker is made of, so the arena is laid out like the place the
            -- fight was picked: a crossing becomes a chokepoint, a rock field a cover fight, open grass a
            -- ranged exchange (Overworld:groundAt -> Arena.GROUND_PROFILES). Read off the cell rather than
            -- the quest, because it is the tile the player chose to walk onto that decides it.
            ground = game.grid and game.grid.groundAt and game.grid:groundAt(cell.x, cell.y) or nil,
            quest = game.quest,
            -- The objective's own scene, played over the board with the general standing on it
            -- (states/battle.lua's openingConversation). This is the ONLY seam an antagonist can
            -- speak from: `intro` plays over the hub before the party is even picked, and by the
            -- time `outro` runs the target of an `assassinate` is dead.
            opening = kind == "objective" and mp.objective and mp.objective.opening or nil,
            prestige = game.prestige,
            -- What this run stands to lose here, named on the defeat panel (ui/panels/battle_summary).
            -- Read at launch rather than at the loss, because by then the rollback has already put it
            -- back and there would be nothing left to count.
            lostHaul = game:haulPhrase(),
            -- What the give-up button is called. A quest is abandoned back to the city; a descent has no
            -- city, and its run simply ends -- so the button says that rather than naming somewhere the
            -- player cannot go (states/battle.lua).
            lossLabel = game.descent and "End the Run" or nil,
            -- The sponsor's stock, for the salvage every won fight leaves behind (models/spoils.lua).
            -- Same value the map's caches were laid out with, so a run's fights and its dead ends pay
            -- into the same house.
            houseMaterial = game.houseMaterial,
            -- This fight's authored difficulty FLOOR: the level its enemies may never drop below,
            -- however green the company walking in is. Scaling takes over above it (models/growth.lua,
            -- Growth.combatantLevel), so a floor stops a beat being walked on a replay or in New Game+
            -- without freezing it at a level the party has long outgrown. Read off the objective first,
            -- then the quest, so a line can set one floor for all its fights and a single beat can raise it.
            floorLevel = (kind == "objective" and mp.objective and mp.objective.floorLevel)
                or (game.quest and game.quest.floorLevel) or nil,
            -- The whole marching company. Battle's deployment phase decides which of them take the field
            -- and where; the rest wait on the bench and can be rotated in (docs/deployment.md).
            party = game.player and game.player.roster or {},
            player = game.player, -- so the phase can remember who was fielded (Player.noteDeployed)
            -- The supper bought at the Cafe before this quest (models/meal.lua): one platter, worn by
            -- the whole company at every fight of the run, and cleared when the run resolves. Read live
            -- off the player rather than snapshotted at launch, so a resumed run picks it up too.
            meal = Meal.held(game.player),
            -- Resolved AFTER placement, since the front line is a thing the player chooses on the board.
            -- Returns { relicTraits, openingBoons } for battle setup to stamp at spawn; see above.
            resolveOpening = resolveOpening,
            -- The player's stash, by reference: an item stolen mid-battle by a thief with a full
            -- grid is appended straight to it, so a theft survives whatever the battle does next.
            stash = game.player and game.player.stash,
            -- Victory resumes THIS overworld (no regenerate); the objective completes
            -- the quest instead. See the file header on why enter is skipped here.
            onWin = function(spoils)
                cell.cleared = true
                game.activePanel = nil
                -- WINNING IS NOT THE SAME AS COMING OUT WHOLE. A member who went down is carried out
                -- alive (states/battle.lua's win) and keeps the wound anyway -- the free revive stands,
                -- and the injury is the price rather than the loss of the body. Here at the top of the
                -- callback rather than in either branch below, so the objective and an ordinary road
                -- fight charge the same thing and neither can be given a fork that forgets to.
                --
                -- The tutorial is exempt: its flight leg is authored to be lost bodies and all, and a
                -- lesson that permanently scars the company before the hub exists is not a lesson.
                if not game.tutorial then game:inflictWounds() end
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
                    -- A DESCENT FLOOR'S STAIR GUARDIAN. The same fork the `meet` branch above takes,
                    -- and it is here as well because from stage 3 the stair is FOUGHT rather than
                    -- walked onto -- the objective that ends a floor is a set-piece now, so this is the
                    -- branch a cleared floor actually comes out of.
                    --
                    -- Above the payout rather than inside it: a floor has no Quest.defs entry to
                    -- complete, and clearRun here would bank the very haul the landing is about to put
                    -- back at stake. The guardian pays through grantSideSpoils -- the SAME call an
                    -- ordinary road win takes -- so its gold, loot and salvage arrive by one route and
                    -- the skim below never doubles it.
                    if game.descent then
                        grantSideSpoils(spoils)
                        -- THE BOTTOM. Clearing the last floor's objective is not another landing --
                        -- there is nothing below it to be asked about. The run is WON, so it banks
                        -- itself: extraction here rather than at a prompt, because the alternative is
                        -- a player who beat the Hollow Crown and then had to press "climb out" to be
                        -- allowed to keep it.
                        if game.quest and game.quest.endsDescent then
                            local out = Descent.extract(game.player, game.descent)
                            if out then out.title = "The Crown Is Broken" end
                            clearRun()
                            -- The descent's own terminal, NOT the credits. Rolling the campaign's ending
                            -- here was right while the descent was the campaign's spine; it is a separate
                            -- mode now, and beating its bottom finishes that mode's run rather than the
                            -- game. The credits still belong to the campaign's finale
                            -- (data/quests/quest_the_gate_below.lua), which is reached from the board and
                            -- has nothing to do with this stair.
                            endDescent("extracted", out)
                            return
                        end
                        game:openLanding()
                        return
                    end
                    if game.player and spoils and (spoils.gold or 0) > 0 then
                        Player.addGold(game.player, spoils.gold)
                    end
                    -- The objective's own salvage (models/spoils.lua) rides in on the run's cache haul
                    -- rather than being granted here. Same reason the caches bank at the objective: it
                    -- inherits Quest.complete's double-payout guard, and it is named in the quest's
                    -- reward table with the rest of the materials instead of arriving as a silent
                    -- number. The battle summary only DISPLAYED it a moment ago; this is the grant.
                    local haul = {}
                    for id, n in pairs(game.map and game.map.cacheHaul or {}) do haul[id] = n end
                    for id, n in pairs(spoils and spoils.materials or {}) do
                        haul[id] = (haul[id] or 0) + n
                    end
                    -- The single payout seam: gold and prestige are granted here, once, the quest is
                    -- marked done (which is what advances the sponsor's standing), and the game saves.
                    --
                    -- THIS IS THE EXTRACTION. Everything the run found has been in the stash all along --
                    -- live, equippable, spendable -- but provisional: the entry snapshot on the run could
                    -- put it all back. Dropping the run here drops that snapshot, and the finds become
                    -- permanent. The objective is the ONLY exit that does this; a wipe and a walk-out both
                    -- roll back instead (see rollbackRun). So the haul comes home through the boss or it
                    -- does not come home.
                    clearRun() -- quest cleared; Quest.complete's save (and the endsCampaign->credits path) writes no run
                    game.reward = Quest.complete(game.player, game.quest, haul)
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
                    --
                    -- A quest may also name an `epilogue`: a SECOND scene played straight after the
                    -- outro, before anything else. The seam exists because one beat can need two
                    -- scenes with a hard cut between them and no leg in between -- the padded card
                    -- (data/quests/colosseum/quest_colosseum_slot_02.lua) ends with the party dead on
                    -- the sand, and the next thing they see is a ceiling they do not know. That is a
                    -- change of place and cast, not a change of subject, so it cannot be more lines
                    -- on the end of the outro. Like a followUp it DEFERS the join banner: whoever was
                    -- recruited belongs to the scene the author put them in, which is the second one.
                    local followUp = game.quest and game.quest.followUp
                    local epilogue = game.quest and game.quest.epilogue
                    local function goNext()
                        -- A class line's last quest settles its temptation ledger, and a companion whose
                        -- line ended in `left` walks HERE rather than in Quest.complete -- she has to
                        -- still be on the roster for the outro above to give her a farewell, and
                        -- `when = { has = ... }` would have dropped her own goodbye out of her own
                        -- scene. The flag was stamped at completion; this is where the roster catches up
                        -- with it. A no-op on every quest that is not a line's tenth.
                        if game.reward and game.reward.temptation then
                            require("models.temptation").settle(game.player)
                            require("models.player").save()
                        end
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
                    -- The scene chain home: outro, then epilogue, then goNext. Either may be absent.
                    local function playEpilogue()
                        if epilogue then
                            require("models.conversation").play(epilogue, goNext)
                        else
                            goNext()
                        end
                    end
                    if game.quest and game.quest.outro then
                        require("models.conversation").play(game.quest.outro, playEpilogue, nil,
                            (followUp or epilogue) and { deferJoins = true } or nil)
                    else
                        playEpilogue()
                    end
                else
                    -- A combat/elite win: grant the spoils the battle summary just revealed, then
                    -- resume THIS overworld. See grantSideSpoils -- the walk-off path pays through the
                    -- very same call, so a fight is worth the same whether it was played or skipped.
                    grantSideSpoils(spoils)
                    -- The fight cost the company health, mana and potions, so what it is worth against
                    -- the NEXT marker has moved. Re-rate before the map comes back.
                    game:refreshMuster()
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
            -- "Return to Hub": give the fight up and fail the quest. Offered only once there is a hub to
            -- return to -- the prologue's flight leg (game.tutorial) has none yet, so there the panel
            -- shows Try Again alone.
            onLoss = (not game.tutorial) and function()
                -- A DESCENT WIPE ENDS THE RUN, and there is nothing to put back. The rollback below
                -- exists to hand a campaign company back the gear it marched in with; here the company
                -- IS the run -- mustered at the gate, discarded with it -- so restoring it would be
                -- rebuilding a table on its way to the bin. Wounds are not inflicted either: they outlive
                -- a quest because the roster does, and this roster does not.
                if game.descent then
                    -- `floors` is where they were STANDING, not what they cleared: the account reads
                    -- "went down on floor 4", and a company that dies on the fourth floor cleared three.
                    endDescent("wiped", { floors = Descent.depth(game.descent),
                                          circles = game.descent.standing })
                    return
                end
                -- The one thing a wipe does NOT take back. Inflicted BEFORE the rollback, which is
                -- the whole of the ordering rule: rollbackRun hands the player every key of the entry
                -- snapshot, and wounds only survive it because that function holds this key across
                -- the copy. Written here rather than after, so the two halves cannot drift into a
                -- state where the wounds are recorded on a player about to be overwritten.
                game:inflictWounds()
                -- A wipe VOIDS the run. Everything this expedition found goes back with it: the chest
                -- loot, the fights' spoils and salvage, the gold, and the gold spent along the way. The
                -- company keeps exactly what it marched in with. See rollbackRun -- the objective is the
                -- only exit that banks, and this is the other side of that rule.
                rollbackRun()
                if game.player then Player.save() end
                State.switch(require("states.hub"))
            end or nil,
        })
        end -- startBattle

        -- WALKING THE FIGHT OFF. The company has outgrown this one (Muster.WALK_OVER), so it is
        -- resolved against the combat model with nobody watching and the player is handed the same
        -- victory panel the board would have shown them.
        --
        -- The fight is REAL. It is built from the same spec (EncounterBattle.build), the company is
        -- stood where Auto-Fill would have stood them, the opening abilities and relics still fire,
        -- and every turn is planned by the same AI that drives an enemy. What it spends, it spends off
        -- the roster by reference -- health, mana, potions, a purse, a theft -- because those are the
        -- ordinary code paths and there is no second set. That spending is the whole cost of the
        -- convenience, and it is why this is worth doing at all rather than just handing over gold.
        --
        -- The WIN, however, is not in doubt: the gate is set high enough that the outcome is a
        -- formality, so a simulation that somehow went badly is still finished as a victory rather
        -- than costing a run the player was never shown. Combat.reviveFallenParty carries anyone who
        -- fell out at a sliver of health -- exactly what a won battle does -- so a bad roll reads as a
        -- mauling, which is an honest price, instead of as a defeat.
        local function autoResolve()
            local built = EncounterBattle.build({
                encounter = cell.encounter,
                biome = mp.biome,
                -- The same ground the played fight would have been laid out on: a walk-off must resolve
                -- the board the player could have fought, not a different one (see EncounterBattle.spec).
                ground = game.grid and game.grid.groundAt and game.grid:groundAt(cell.x, cell.y) or nil,
                quest = game.quest,
                prestige = game.prestige,
                floorLevel = game.quest and game.quest.floorLevel or nil,
                party = game.player and game.player.roster or {},
            })
            local combat = built.combat
            -- The player's stash by reference, so a theft mid-fight survives it, exactly as in battle.
            combat.stash = game.player and game.player.stash

            -- Stand the line where pressing Auto-Fill and Begin would have stood it, then let the
            -- companion abilities and relics spend their openings on it (the same resolveOpening the
            -- battle state calls at commit) before the bell.
            -- Same order commitDeploy uses, and the order matters: place the line, resolve the opening
            -- against it, stamp the relic traits BEFORE the bell (Combat.openBattle's Trait.setup
            -- attaches them and only then fires the openers), ring the bell, then lay the boons on.
            local deployed, front = EncounterBattle.autoDeploy(combat, built.arena,
                Muster.fielded(game.player))
            local opening = resolveOpening(deployed, front)
            if game.player then Player.noteDeployed(game.player, deployed) end

            local traits = opening.relicTraits
            for _, unit in ipairs(combat.units) do
                if unit.side == "party" then unit.relicTraits = traits and traits[unit.char] or nil end
            end
            -- A benched member has to arrive already wearing their party-scope relic when they rotate
            -- in, exactly as commitDeploy seats them.
            for _, entry in ipairs(combat.bench or {}) do
                entry.relicTraits = traits and traits[entry.char] or nil
            end

            Combat.openBattle(combat)

            -- Opening boons a relic or companion ability queued (a barrier, Haste, an empower),
            -- matched to their unit by char identity -- the same instance resolveOpening queued them
            -- for. Applied after the bell, once traits are on and the units are built.
            local Status = require("models.status")
            for _, boon in ipairs(opening.openingBoons or {}) do
                for _, unit in ipairs(combat.units) do
                    if unit.side == "party" and unit.char == boon.char and unit.alive then
                        Status.apply(combat, unit, boon.id, boon.opts)
                        break
                    end
                end
            end

            local result = Autobattle.run(combat)
            -- Carried out and unhooked, the same two calls a won battle makes (states/battle.lua's
            -- win + releaseParty). Done on ANY result: see the note above on why the win is a
            -- formality.
            --
            -- A result that was not a win is the one signal that WALK_OVER is set too low, and it is
            -- addressed to whoever tunes it rather than to the player -- who is about to be handed a
            -- victory either way and would only be alarmed by it. So it goes to the console in a
            -- development build and nowhere at all in a release one.
            if result ~= "win" and Debug.enabled then
                print(("[autoresolve] %s resolved as %s -- the walk-off gate may be too low")
                    :format(tostring(cell.encounter.id), tostring(result)))
            end
            Combat.reviveFallenParty(combat)
            for _, unit in ipairs(combat.units) do
                if unit.side == "party" then Combat.releaseClaims(unit.char) end
            end

            local spoils = EncounterBattle.spoils({
                encounter = cell.encounter,
                enemyUnits = built.enemyUnits,
                prestige = game.prestige,
                -- The same depth the played fight is paid by, or a walked-off stop would be worth a
                -- different amount from the one the player could have stood in.
                floorLevel = game.quest and game.quest.floorLevel or nil,
                houseMaterial = game.houseMaterial,
                combat = combat,
            })

            cell.cleared = true
            require("models.sound").play("battle.win")
            -- The same victory panel the board shows, opened over the OVERWORLD instead -- it is a
            -- panel and not a state, and this file already hosts panels. Continue pays out through the
            -- one grant seam, so a walked-off fight and a fought one bank identically. No log to
            -- review: there was no battle to watch.
            game.activePanel = BattleSummary.new({
                result = "win",
                spoils = spoils,
                technique = combat.techniqueByActor,
                encounter = cell.encounter,
                actions = { { label = "Continue", onSelect = function()
                    game.activePanel = nil
                    grantSideSpoils(spoils)
                    -- A walked-off fight wounds exactly as a played one does. Read off THIS combat
                    -- object rather than states/battle.lua's field, because no battle state was ever
                    -- entered here -- the fight was resolved with nobody watching, and the field would
                    -- hold whatever the last real battle left in it.
                    Wound.inflict(game.player, Combat.fallenParty(combat))
                    game:refreshMuster() -- the fight was paid for in health and potions; re-rate
                    saveRun()
                end } },
            })
        end

        -- Stepping onto a fight enters it immediately -- no confirm -- UNLESS the company has plainly
        -- outgrown it, which is the one case where the fight is not a decision any more and playing it
        -- out is just clicking. Then, and only then, the choice is offered. You still skip an ordinary
        -- fight by routing AROUND it: combats never sit on the objective spine
        -- (models/overworld.lua), and the marker already lets you judge one before you commit the
        -- step -- a marker gone calm IS this offer, seen from across the board. The boss takes
        -- Ren's dose pour first, and is never walked off.
        if kind == "objective" then
            fireAbility("objectiveReached", { cell = cell })
            fireRelics("objectiveReached", { cell = cell })
        end
        if Muster.canWalkOver(game:musterMargin(cell)) then
            game.activePanel = Choice.new({
                title = cell.encounter.name or "A Fight Beneath You",
                prompt = "Your company outmatches what is waiting here.",
                options = {
                    { label = "Auto-resolve", desc = "Settle it without drawing the board. It still costs you.",
                      accent = { 0.42, 0.80, 0.62 },
                      cb = function() game.activePanel = nil; autoResolve() end },
                    { label = "Fight", desc = "Take the field anyway.",
                      accent = { 0.88, 0.45, 0.33 },
                      cb = function() game.activePanel = nil; startBattle() end },
                },
                -- No backing out: the token is standing on the fight. Closing the panel would leave a
                -- live encounter underfoot with no way back into it.
                onClose = nil,
            })
            return
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

    -- A Reliquary: builds a SLATE of three run relics (models/relic.lua's Relic.slate -- a Vice against two
    -- Virtues where the shelf allows) and takes exactly ONE. The two refused are the price of the one kept,
    -- which is the whole reason the stop exists: a single free relic was never a decision. The slate is
    -- rolled ONCE and pinned to the cell (like the Merchant's shelf), so LEAVE -- which leaves the cell
    -- uncleared to reconsider -- can't be walked off and back onto for a fresh roll. An empty shelf (the
    -- run already holds everything eligible) pays a small gold consolation rather than an empty panel.
    if kind == "relic_cache" then
        local enc = cell.encounter
        local def = enc.id and EncounterModel.get(enc.id)
        if not enc.offer then
            enc.offer = Relic.slate({
                prestige = game.prestige,
                sin = game.quest and game.quest.sin, -- this circle's shelf leans toward its own
                tier = enc.tier or (def and def.tier) or nil,
                exclude = game.relicState,
            }, 3)
        end
        -- The pinned slate can go stale: a relic on it may have been taken at a Sin's Altar or won at a
        -- Crossroads since. Drop what the run already holds rather than offering a duplicate.
        local offer = {}
        for _, id in ipairs(enc.offer) do
            if not Relic.has(game.relicState, id) then
                offer[#offer + 1] = { id = id, info = Relic.info(id) }
            end
        end
        if #offer == 0 then -- shelf exhausted: don't strand the player on an empty reliquary
            cell.cleared = true
            if game.player then Player.addGold(game.player, 15); game:pushToast("The reliquary is bare  +15g") end
            saveRun()
            return
        end
        game.activePanel = RelicOffer.new({
            title = enc.name or "Reliquary",
            offer = offer,
            onTake = function(entry)
                cell.cleared = true
                Relic.grant(game.relicState, entry.id)
                game:pushToast("Relic taken: " .. (Relic.info(entry.id).name or entry.id))
                game.activePanel = nil
                saveRun()
            end,
            -- Persist on the way out too: the pin is what makes leaving safe instead of a free reroll.
            onLeave = function() game.activePanel = nil; saveRun() end,
        })
        return
    end

    -- A Sin's Altar: rolls a VICE relic and offers it for an upfront toll in gold. Pay and it's yours
    -- (power with a standing cost); leave and the coin -- and the temptation -- stays in your purse. The
    -- greed gamble made into a stop. An empty vice-shelf just clears (nothing to tempt with).
    if kind == "shrine" then
        local id = Relic.roll(Relic.pool({
            prestige = game.prestige, alignment = "vice", exclude = game.relicState,
            sin = game.quest and game.quest.sin,
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

    -- The Merchant: a wandering market. Rolls a small shelf of ordinary goods ONCE (stored on the cell
    -- so a re-step shows the same stock, never a fresh reroll) and sells them for gold, at the item's own
    -- shelf price -- see Spoils.shelf for why the road charges what the houses charge. Leaving keeps the
    -- cell so you can come back and spend later; a bought row stays marked sold.
    if kind == "merchant" then
        local enc = cell.encounter
        if not enc.stock then
            enc.stock = {}
            for _, id in ipairs(Spoils.shelf({ prestige = game.prestige, count = 3 })) do
                enc.stock[#enc.stock + 1] = { id = id, price = Item.defs[id].price, bought = false }
            end
        end
        if #enc.stock == 0 then cell.cleared = true; saveRun(); return end
        local stock = {}
        for _, s in ipairs(enc.stock) do
            -- A shelf pinned to the cell can outlive the blueprint it names (a removed item, an older
            -- save), so a row whose id no longer resolves is simply not offered rather than crashing the
            -- panel that would have instantiated it.
            if Item.defs[s.id] then
                stock[#stock + 1] = { id = s.id, price = s.price, bought = s.bought, src = s }
            end
        end
        game.activePanel = Merchant.new({
            title = enc.name or "Merchant",
            stock = stock,
            gold = function() return (game.player and game.player.gold) or 0 end,
            onBuy = function(entry)
                if game.player and Player.spendGold(game.player, entry.price) then
                    Player.grantItem(game.player, entry.id) -- straight into the stash, like any find
                    if entry.src then entry.src.bought = true end -- persist the sale on the cell's shelf
                    game:pushToast("Bought: " .. (entry.item and entry.item.name or entry.id))
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
                for _, c in ipairs((game.player and game.player.roster) or {}) do
                    local hp = c.stats and c.stats.health
                    if type(hp) == "table" then hp.current = math.max(1, (hp.current or hp.max) - n) end
                end
            end,
            grantRelic = function(tier)
                local id = Relic.roll(Relic.pool({ prestige = game.prestige, tier = tier, exclude = game.relicState,
                    sin = game.quest and game.quest.sin }))
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

    -- A Rest is a DECISION, not just a breather: Heal the party, Sharpen a lasting run edge, or Study the
    -- ground (models/relic.lua + the fog reveal). One only; leaving (X/Esc) forgoes it and leaves the cell
    -- to reconsider. The companions plug in here later (Amana strengthens Heal, Gyeom strengthens Study).
    if kind == "rest" then
        game.activePanel = RestChoice.new({
            title = cell.encounter.name or "Make Camp",
            onHeal = function()
                cell.cleared = true
                game:restHeal()
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

-- HEAL (a rest's first choice): refill every resource on the roster to full (Player.restore), then replay
-- the heal on a reveal panel so the player SEES what it did -- each party member's HP bar sweeps up to
-- full (ui/panels/rest.lua). Factored out of the rest resolution so RestChoice's Heal option and any
-- back-compat non-combat path both reach the same code.
function game:restHeal()
    if not game.player then return end
    -- Snapshot each shown member's wound BEFORE the refill: the reveal animates from it, and once
    -- Player.restore runs the live stat is already at max, so this is the only place the "before"
    -- exists. The whole roster marches, so the whole roster is healed and shown.
    local shown = game.player.roster or {}
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
    if enc.kind == "rest" then game:restHeal() end -- back-compat: any path still routing rest here heals
end

local function toHub()
    -- WALKING AWAY FROM A DESCENT ends the run where it stands. Same reading as the wipe above: there is
    -- no company on the other side of this to hand anything back to, so there is nothing to roll back --
    -- only a run to close and an account of it to give. It is still a real loss, and the landing's "climb
    -- out" is still the exit that is not: leaving from the middle of a floor abandons what the floor was
    -- worth, which is exactly what the prompt that reached here just named.
    if game.descent then
        endDescent("left", { floors = (game.descent.cleared or 0), circles = game.descent.standing })
        return
    end
    -- Abandoning a quest (Back / Esc) VOIDS the run, exactly as a wipe does -- the two differ only in how
    -- the player got here. The expedition's finds go back, the company's own gear does not move, and
    -- Continue has no map to drop them back into. Persist so disk agrees; the hub clears as a backstop.
    if game.player and game.player.activeRun then
        rollbackRun()
        Player.save()
    end
    State.switch(require("states.hub"))
end

-- Back / Esc / pad-Back. Walking out now costs the whole haul, so it asks first -- and the asking names
-- the price in items and coin rather than saying "are you sure", which tells the player nothing they
-- did not already know. A run carrying nothing leaves without ceremony: there is no decision to put in
-- front of someone who has found nothing yet.
local function leaveQuest()
    local lost = game:haulPhrase()
    if not (game.player and game.player.activeRun and lost) then toHub() return end
    -- The same decision in both modes, but not the same stakes, so not the same words. A quest's walk-out
    -- gives up one expedition and the company goes home; a descent's gives up the company as well, since
    -- there is no home on the other side of it to go to.
    game.activePanel = Choice.new({
        title = "Turn Back?",
        prompt = game.descent
            and ("Nothing you have found is yours until you climb out. Leave now and " .. lost ..
                 " stay where you found them, and the run ends here.")
            or ("Nothing you have found is yours until the objective is cleared. Walk out now and "
                .. lost .. " stay where you found them."),
        options = {
            { label = "Keep going",
              desc = game.descent and "The stair is the only way out with any of it."
                  or "The objective is the only way home with any of it.",
              accent = { 0.83, 0.73, 0.45 },
              cb = function() game.activePanel = nil end },
            { label = game.descent and "End the run" or "Walk out empty",
              desc = game.descent and "The company is left at the gate. The descent counts for nothing."
                  or "Return to the city. The expedition counts for nothing.",
              accent = { 0.88, 0.45, 0.33 },
              cb = function() game.activePanel = nil; toHub() end },
        },
    })
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
        -- A panel just closed. The Loadout is the one that can re-kit the company mid-run, and gear is
        -- what the muster ruler is made of -- so re-rate here and the markers answer to the
        -- weapon that was just handed over before the player has taken a step.
        if game.panelWasOpen then game:refreshMuster() end
        game.map:update(dt)
    end
    game.panelWasOpen = game.activePanel ~= nil
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

    -- Always-on party HP/mana strip: the run's attrition, legible while routing (models/player.lua).
    -- Pass the mouse (logical space) so the per-companion ability badge shows its tooltip on hover.
    if partyVisible() then
        local mx, my
        if InputMode.isMouse() then mx, my = Scale.toGame(love.mouse.getPosition()) end
        PartyStatus.drawStrip(game.player, 16, 60, mx, my, game.abilityState)
        -- Run relics carried this quest, top-right (models/relic.lua) -- the snowball, legible while routing.
        RelicStrip.draw(game.relicState, Scale.WIDTH - 16, 60, mx, my)

        -- WHAT THIS RUN IS CARRYING. Stacked under the relics, because both answer the same question --
        -- what has this expedition accrued -- and because the decision it feeds is taken out here on the
        -- map, not in a panel. Without a figure on screen there is nothing to be greedy about: the
        -- push-one-more-spur choice is a bet, and a bet needs a stake the player can see. It also means
        -- a wipe takes something the player was watching rather than something they find out about.
        --
        -- Absent entirely when the run has found nothing yet -- an empty ledger is not information, and
        -- a row of zeroes would read as a broken readout.
        if game.haul then
            local x = Scale.WIDTH - 16
            local y = 60 + RelicStrip.height(#Relic.held(game.relicState)) + (game.haul and 8 or 0)
            love.graphics.setFont(hudFont)
            -- Named for what it IS, not what it counts: "carried" says the thing the number turns on --
            -- that none of this is yours yet.
            love.graphics.setColor(Theme.muted)
            love.graphics.printf("Carried this run", x - 240, y, 240, "right")
            local parts = {}
            if game.haul.items > 0 then
                parts[#parts + 1] = game.haul.items .. (game.haul.items == 1 and " item" or " items")
            end
            if game.haul.gold > 0 then parts[#parts + 1] = game.haul.gold .. "g" end
            if game.haul.materials > 0 then parts[#parts + 1] = game.haul.materials .. " stock" end
            love.graphics.setColor(Theme.accentAmber)
            love.graphics.printf(table.concat(parts, "   "), x - 240, y + 18, 240, "right")
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- Companion-ability toasts, stacked just under the party strip so ability feedback groups with the
    -- party it comes from. Newest on top; each fades over its life.
    if game.toasts and #game.toasts > 0 then
        love.graphics.setFont(hudFont)
        local baseY = 60 + PartyStatus.stripHeight(#(game.player and game.player.roster or {})) + 6
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

    -- THE FIGHT YOU ARE WEIGHING UP, in words. The marker is the at-a-glance read across
    -- the whole board; this is the exact one, for the moment you are actually deciding. Docked here,
    -- under the quest name with the keys count -- both are facts about the board rather than about a
    -- point on it -- rather than floating at the cursor, so it is always found in the same place
    -- however the player is driving (see ui/overworld_map.lua's hoveredFight for what "weighing up"
    -- means with a pad, which has no pointer to hover with).
    local fight = game.map:hoveredFight()
    if fight then
        local band = game:musterBand(fight)
        local line = fight.encounter.name or "A fight"
        if fight.encounter.tier then line = line .. "  -  Tier " .. fight.encounter.tier end
        if band then line = line .. "  -  " .. (Muster.BAND_LABEL[band] or band) end
        -- ...AND WHAT IT LEAVES BEHIND. A stop is a proposition, and until now this line gave only
        -- half of it: how dangerous, never how worthwhile. Naming the salvage is what turns eight
        -- fights on a floor from a treadmill into eight routing decisions -- the Hades rule that the
        -- source is telegraphed BEFORE you commit, which docs/progression.md already cites as the one
        -- thing its material economy was missing.
        --
        -- Only the SALVAGE is named, and that is a correctness point rather than a shortcut: it is
        -- computed and never rolled (models/spoils.lua -- "no RNG, no zero case"), so this is the exact
        -- payout rather than an estimate of one. Gold carries +/-15% jitter and naming a figure the
        -- fight then missed would teach the player to distrust the line.
        --
        -- Deliberately NOT a glyph on the marker: at a 32px tile a mark is under 2px across, which is
        -- the lesson the muster pips already paid for (see models/muster.lua's notes). The marker is
        -- the read across the whole board; this is the read at the moment of deciding.
        local pays = game:payoutPhrase(fight.encounter)
        if pays then line = line .. "  -  leaves " .. pays end
        love.graphics.setFont(hudFont)
        love.graphics.setColor(0.72, 0.72, 0.66)
        love.graphics.printf(line, 0, total > 0 and 72 or 52, Scale.WIDTH, "center")
    end

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse
    -- otherwise. The items key only appears once the Loadout button itself does.
    local items = game.itemsVisible and (InputMode.isGamepad() and "Y: items      " or "I: items      ") or ""
    local use = useVisible() and (InputMode.isGamepad() and "X: use      " or "U: use      ") or ""
    -- The "back to hub" hint is dropped alongside the button itself during the flight tutorial.
    -- Where backing out actually goes, named honestly. A quest is abandoned to the city; a descent has no
    -- city to be abandoned to -- the run simply ends (states/game.lua's toHub) -- and a hint that names a
    -- place the player cannot reach teaches them the wrong thing about the mode they are in.
    local backTo = game.descent and "end run" or "hub"
    local back = backVisible() and (InputMode.isGamepad() and ("Back: " .. backTo)
        or ("Esc: " .. backTo)) or ""
    local hint = InputMode.isGamepad()
        and ("Move: D-pad / Stick      " .. items .. use .. back)
        or ("Move: WASD / Arrows / click adjacent tile      " .. items .. use .. back)
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
        or (useVisible() and rectContains(useButton, x, y)) then
        return "hand"
    end
    return "arrow"
end

function game.mousepressed(x, y, button)
    if game.activePanel then
        game.activePanel:mousepressed(x, y, button)
    elseif button == 1 and backVisible() and backContains(x, y) then
        leaveQuest()
    elseif button == 1 and game.itemsVisible and rectContains(itemsButton, x, y) then
        openLoadout()
    elseif button == 1 and useVisible() and rectContains(useButton, x, y) then
        openConsumables()
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
        leaveQuest()
    elseif key == "i" and game.itemsVisible then
        openLoadout()
    elseif key == "u" and useVisible() then
        openConsumables()
    else
        game.map:keypressed(key)
    end
end

function game.gamepadpressed(joystick, button)
    if game.activePanel then
        game.activePanel:gamepadpressed(joystick, button)
    elseif button == "back" and backVisible() then
        leaveQuest()
    elseif button == "y" and game.itemsVisible then
        openLoadout()
    elseif button == "x" and useVisible() then
        openConsumables()
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
