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
local Calendar = require("models.calendar") -- the campaign clock; a fresh expedition spends a day
local Market = require("models.market") -- markOpened: what a class level crossing a rung put on the counter
local Request = require("models.request") -- a day foraging for a house, with no story attached
local Quest = require("models.quest")
local Vendor = require("models.vendor")   -- the sponsoring house behind a quest, for its cache stock
local Material = require("models.material")
local Identify = require("models.identify") -- the unread finds a floor hands up
local Item = require("models.item")     -- the Merchant's shelf prices come off the blueprints
local Character = require("models.character") -- MAX_INVENTORY, for the pack a wipe leaves on the floor
local Errand = require("models.errand")   -- the small work a house asks for before it opens a rung
local Spoils = require("models.spoils") -- ...and its stock off the same band a fight's loot rolls in
local EncounterPanel = require("ui.panels.encounter")
local LootReveal = require("ui.panels.loot_reveal")
local RelicOffer = require("ui.panels.relic_offer")   -- the Reliquary's pick-one-of-three
local RelicReveal = require("ui.panels.relic_reveal") -- the Sin's Altar's single relic + toll
local Merchant = require("ui.panels.merchant") -- the road's shop: ordinary goods for scrip
local Scrip = require("models.scrip")       -- the run's own coin: weightless, and gone at the surface
local Valuable = require("models.valuable") -- ...and the campaign's, which is objects and has weight
local Choice = require("ui.panels.choice")
local Crossroads = require("models.crossroads")
local RestChoice = require("ui.panels.rest_choice")
local RestReveal = require("ui.panels.rest")
local EncounterModel = require("models.encounter")
local Muster = require("models.muster")                     -- how the company stands against a fight
local Mule = require("models.mule")                         -- what it can carry out, and the way home
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
local Seed = require("models.seed") -- what this playthrough is made of; the ground is dealt off it
local SeedReadout = require("ui.seed_readout") -- ...and what says so on screen, in a dev build only
local Experience = require("models.experience") -- the one ladder: what turns banked xp into levels
local Relic = require("models.relic")
local Meal = require("models.meal") -- the Cafe's supper: one platter, worn by the company all run
local Wound = require("models.wound") -- what a body that went down carries out of the run
local CoachBubble = require("ui.coach_bubble")
local Locale = require("models.locale")
local Theme = require("ui.theme")
local ScreenFx = require("ui.screen_fx")
local VendorIcons = require("ui.vendor_icons") -- the house marks: the checklist is the map's legend

local game = {}

local titleFont = Theme.display(22)
local hudFont = Theme.body(16)

-- Coach lines, keyed by conversation and node id and resolved through Locale so {select}/localization
-- behave exactly as in a spoken line. Two files feed the map: the prologue's flight leg, and the one
-- line the campaign teaches out here (the first wound). Each is walked once and cached.
local HINT_FILES = {
    conversation_tutorial_flight = "data.conversations.tutorial.conversation_tutorial_flight",
    conversation_tutorial_wound  = "data.conversations.tutorial.conversation_tutorial_wound",
}
local hintNodes = {}
local function hintNode(convId, id)
    local nodes = hintNodes[convId]
    if not nodes then
        nodes = {}
        for _, node in ipairs(require(HINT_FILES[convId]).script) do
            if node.id then nodes[node.id] = node end
        end
        hintNodes[convId] = nodes
    end
    return nodes[id]
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

-- Where the always-on party strip is drawn (ui/party_status.lua). A constant rather than two literals
-- because something now has to POINT at a row of it: the first-wound coach bubble anchors through
-- PartyStatus.rowRect, which can only find the row if it is handed the origin the strip was drawn at.
local STRIP_X, STRIP_Y = 16, 60

-- WHAT THE WEEPING STONE CHARGES: a tenth of every roster member's maximum health, permanently, for the
-- rest of the descent. A share rather than a flat number so it costs the same on floor one and floor
-- eight and can never scale into the absurd against a company that has grown.
--
-- A tenth because the run has to be able to pay it more than once and still be a run. A company that
-- buys three rare relics off this stone has given up nearly a third of its ceiling -- steep, felt on
-- every remaining floor, and survivable if that is the build it wanted. Half again and it would be a
-- stop nobody could use twice; a twentieth and it would be free.
game.STONE_SHARE = 0.10

-- THE HUD'S BUTTON ROW: Back, then Items, then Use, LAID OUT OVER THE ONES ACTUALLY THERE.
--
-- Each of the three used to hold a hardcoded lane -- 16, 138, 260 -- and keep it whether or not the
-- button to its left drew at all. That was invisible while Back was present on everything except the
-- flight tutorial. A descent has no Back button ever (see backVisible), so the row would open behind a
-- permanent empty 110px lane on every floor of the mode: a slot reserved for a control that is not
-- coming back. The row closes up instead, which is the same rule the overworld already follows for
-- controls that only draw where they are legal.
--
-- The geometry is unchanged when all three are up: 16, then 16+110+12 = 138, then 260.
local BUTTON_ROW = { x = 16, y = 16, w = 110, h = 36, gap = 12 }

local function rowRect(slot)
    return { x = BUTTON_ROW.x + (slot - 1) * (BUTTON_ROW.w + BUTTON_ROW.gap),
             y = BUTTON_ROW.y, w = BUTTON_ROW.w, h = BUTTON_ROW.h }
end

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The Back button (return to the hub) is hidden on any scripted leg -- the prologue's flight tutorial
-- (before the player has even reached the city) and the debut's aftermath walk (a cutscene the reward
-- rides on, so it must not be abandonable). Both are scripted sequences, not board quests one can quit.
-- On a normal quest game.tutorial and game.scripted are both nil, so the button always shows. (A future
-- pass renames it "Return to City" and gates it behind an "abandon this quest?" warning.)
--
-- ...AND A DESCENT HAS NO BACK BUTTON AT ALL, because it already had a better one and this was the
-- worse of the two.
--
-- A floor's way out is the ASCENT STAIR, standing on the tile the company walked in on
-- (Descent.floorQuest's `exitAtStart`). Taking it goes up to the Gate and KEEPS the floor stack, so a
-- company that bites off too much can climb out and come back down to floor nine. This button was a
-- second exit to the same place that threw the stack away: it ran toHub, which nilled
-- player.descentRun, so giving up on floor nine cost nine floors and the hint on the HUD said only
-- "Esc: end run".
--
-- Which made the mode's incentives exactly backwards. A WIPE -- the punishing ending -- keeps your
-- depth and costs only what the company was carrying (see onLoss). Quitting kept nothing. So the
-- button that reads as the safe move was the expensive one, and it was bound to the key every other
-- screen in the game uses for "close this".
--
-- Nothing is lost by removing it. The stair is always reachable, the board autosaves on every step
-- (saveRun), so quitting the APP mid-floor resumes where it stood, and a company that cannot win still
-- has the wipe -- which now ends at the Gate with the levels, the mapped floors and the bound relics
-- intact. There is no way to strand a run in here, only ways to pay for one.
local function backVisible()
    return not game.tutorial and not game.scripted and not game.descent
end

-- The "Potions" button rides alongside the Items button on a normal quest (both flags start true). On the
-- flight tutorial it is held back TWICE over: it needs loot to spend (game.itemsVisible, set by the
-- teaching chest) and the first fight behind the party (game.useUnlocked, set on the survivors'
-- defence win). Until then that leg's HUD is deliberately spare -- the Items button IS the equip
-- lesson -- and a potion has nothing to heal yet.
local function useVisible()
    return game.itemsVisible and game.useUnlocked
end

-- Where each button actually sits this frame. One reading of the row, used by the draw, the hit test
-- and the cursor alike -- three copies of "which lane is Use in" is how a button ends up clickable
-- somewhere it is not drawn.
local function backRect() return rowRect(1) end
local function itemsRect() return rowRect(backVisible() and 2 or 1) end
local function useRect()
    local slot = 1
    if backVisible() then slot = slot + 1 end
    if game.itemsVisible then slot = slot + 1 end
    return rowRect(slot)
end

-- SEND THE MULE HOME (models/mule.lua). Drawn only where the move is legal -- underground, with the
-- mule standing here and something on it -- rather than as a greyed plate the player learns to ignore.
-- An empty mule has nothing to send and a mule already on the road cannot be sent twice; neither is a
-- refusal the player needs explained, because in both states the button simply is not there.
local function muleVisible()
    return game.descent ~= nil and not Mule.isAway(game.descent)
        and Mule.load(game.player, game.descent) > 0
end

local function muleRect()
    local slot = 1
    if backVisible() then slot = slot + 1 end
    if game.itemsVisible then slot = slot + 1 end
    if useVisible() then slot = slot + 1 end
    return rowRect(slot)
end

-- Send it, and say what went. The bank is silent otherwise -- re-baselining leaves nothing on screen
-- that moved -- and a control that appears to do nothing is one players stop pressing.
local function sendMule()
    local ok, carried = Mule.dispatch(game.player, game.descent, Save.snapshot(game.player))
    if not ok then return end
    game:pushToast("The mule is away with " .. carried ..
        (carried == 1 and " find" or " finds") .. "  --  back in " .. Mule.TRIP .. " fights")
    game:refreshHaul() -- the bag is banked, so the stake on the HUD is nought again
    Player.save()
end

local function backContains(x, y)
    return rectContains(backRect(), x, y)
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
    if #parts > 0 then
        table.sort(parts)
        game:pushToast("Supply cache: " .. table.concat(parts, ", "))
    end

    -- WHAT WAS BEHIND THE DOOR, and it is the reason the door was worth finding.
    --
    -- A secret's cache pays a SEALED piece on top of its materials -- drawn above the price band the
    -- floor is otherwise capped at (models/spoils.lua's SECRET_ABOVE), and unreadable until the
    -- Touchstone. Every other stop on the board pays inside that band, so this is the one place the rift
    -- hands up gear the road could not have given you, which is the sentence models/identify.lua has
    -- always said identification exists to make true.
    --
    -- Nil `floorLevel` pays nothing and that is how the campaign opts out, exactly as every other sealed
    -- draw does: a mystery blade on a road whose counter is three stops away is a reward with nowhere to
    -- collect it.
    if payload and payload.secret then
        for _, find in ipairs(Spoils.rollSealed({
            kind = "secret", floorLevel = game.quest and game.quest.floorLevel or nil,
        })) do
            Identify.grant(game.player, find.id, find.floor)
            game:pushToast("Sealed in the vault -- nobody here can read it")
        end
    end
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
        day = game.day,
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
        -- The roll is the city's lesson too: a body on the flight leg has one job and no ladder to
        -- read, so the tab arrives with the town that explains it.
        classes = game.tutorial ~= "flight",
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

-- Forward-declared, and defined where the rest of the run plumbing is (search for its header). It is
-- named up here because the landing -- which sits above that block -- now leaves the player standing on
-- a board it has changed, and a change to the board that is not persisted is one a resume loses.
local saveRun

-- LOSING A FIGHT, which is now the only thing on the board that costs anything.
--
-- The rule inverted. It used to be that the objective was the only exit that banked: a wipe AND a
-- walk-out both restored the company from its entry snapshot, and they differed only in how the player
-- arrived. That was right while the board was a one-way trip. It is wrong now that a day is the unit --
-- with a voluntary exit keeping everything (toHub), a total wipe penalty makes the last fight before
-- you turn back an all-or-nothing coin flip, and the sensible play is to leave after the first cache.
--
-- So a wipe takes wounds (already inflicted by the battle) plus most of the run's gold and forging
-- stock, and leaves the items. The arithmetic and the argument live in Player.loseHaul, where they can
-- be driven by a spec; this is the seam that hands it the entry snapshot and drops the run.
local function wipeRun()
    local run = game.player and game.player.activeRun
    local entry = run and run.entry
    if not entry then clearRun() return false end
    local before = Save.restore(entry)
    if not before then clearRun() return false end -- unreadable snapshot: keep everything, drop the run
    Player.loseHaul(game.player, before)
    clearRun()
    return true
end

-- WHERE A DESCENT GOES WHEN IT ENDS, which is now the same place a quest went: the city.
--
-- THE DESCENT IS THE GAME. It used to be a separate mode with its own front screen and its own save
-- file, and it ended by throwing a company away. Then the prologue became its on-ramp -- the avatar you
-- made, the Rowan sworn beside her, the guard at the capital's gate and the sponsor who cut in front of
-- the Adventurers' Guild -- and with it the mode joined the campaign's save. There is one company now,
-- so nothing is ever thrown away and every ending walks back up into the city it came from.
--
-- `outcome` is how it ended -- passed rather than inferred, because only the caller knows whether the
-- stair was taken as a victory or a defeat. It was "won", "wiped" or "left"; "left" is gone with the
-- Back button that produced it (see backVisible), and a wipe does not come through here at all any
-- more -- it wakes the company at the Gate with the run intact (onLoss). So the one caller left is the
-- Hollow Crown, and this is the function that closes a FINISHED descent.
--
-- `keep` no longer means anything about a file, because there is no separate file. It survives as the
-- distinction between an ending that finished the RUN (the Hollow Crown) and one that finished an
-- expedition, and the gate reads it to know whether to offer the stair again.
local function endDescent(outcome, result, keep)
    result = result or {}
    result.outcome = outcome
    if not keep and game.player then
        -- The run is over. The company is not -- it walks back into the city with everything it kept,
        -- and the next descent starts a fresh stack of floors.
        game.player.descentRun = nil
        -- ...WITHOUT THE SCRIP, which is the third and last exit a descent has (models/scrip.lua). The
        -- other two are the stair up and a wipe; all three burn it, which is what lets the rule be one
        -- sentence -- "it dies at the surface" -- instead of a table of exceptions.
        Scrip.clear(game.player)
    end
    Player.save()
    State.switch(require("states.hub"))
end

-- WHAT THIS RUN IS CARRYING, and would lose by getting wiped.
--
-- Read by DIFFING the live company against the entry snapshot rather than by tallying at each grant.
-- That is the whole reason it can be trusted: a chest, a fight's spoils, an event's gift, a relic's
-- payout and anything added later all land in the same places, and none of them has to remember to
-- report. There is no ledger to fall out of step with the stash.
--
-- Positive differences only. Drinking a potion the company marched in with is not a negative find, and
-- gold spent at the Merchant is not at stake -- a rollback would hand it back. What is shown is what a
-- wipe would actually take.
function game:refreshHaul()
    local run = game.player and game.player.activeRun
    local entry = run and run.entry
    if not entry then game.haul = nil return end

    -- Through Player.atRisk rather than a tally of its own, so the number on the defeat panel, the mark
    -- in the Loadout and the pile a wipe actually drops are one answer asked three times. They used to
    -- be two counts computed the same way in two files, which is exactly how a readout goes quietly
    -- false (the badge would have been the third).
    -- ITEMS, AND WHAT THE VALUABLES AMONG THEM ARE WORTH. The second figure is the whole reason the
    -- greed decision has teeth now (models/valuable.lua): the campaign's income IS these objects, so
    -- "carried this run" without a gold number beside it would be reporting a pile of gear and quietly
    -- omitting the takings. Read off the same atRisk keys rather than tallied at the grant, for the
    -- reason this whole function is a diff.
    local items, worth = 0, 0
    for item, n in pairs(Player.atRisk(game.player, entry)) do
        items = items + n
        worth = worth + n * Valuable.value(item)
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

    -- Gold gained as a NUMBER, which since the economy split is only ever an authored objective purse
    -- (models/scrip.lua) -- a rolled fight pays scrip and the campaign's real income arrives as the
    -- valuables counted above. Kept because an errand still pays one, and because zero is a reading.
    local gold = math.max(0, (game.player.gold or 0) - (entry.gold or 0))

    game.haul = (items > 0 or gold > 0 or worth > 0 or materials > 0)
        and { items = items, gold = gold, worth = worth, materials = materials } or nil
end

-- WHAT THE CIRCLE'S GATE READS RIGHT NOW (models/descent.lua's Descent.gateState). This is the only
-- place the board is counted for it, so the plate, the refusal and the toll all quote one answer.
--
-- Nil outside a descent, and on a floor whose stair nobody is standing on: the bottom has no sin and
-- the Crown bars nothing.
function game:stairGate()
    local run = game.descent
    if not run then return nil end
    local depth = Descent.depth(run)
    local sin = Descent.isGeneralFloor(depth) and Descent.sinAt(run, depth) or nil
    if not sin then return nil end

    -- THE FLOOR, COUNTED ONCE. Fights only -- a cache, a camp and a reliquary are not things left alive
    -- -- and the ward is counted apart, since beating it is its own condition rather than one more body.
    local cleared, total, wardDown = 0, 0, true
    local grid = game.grid
    for y = 1, (grid and grid.rows or 0) do
        for x = 1, grid.cols do
            local cell = grid.cells[y][x]
            local enc = cell.encounter
            if enc then
                if enc.wardFor then
                    wardDown = cell.cleared == true
                elseif enc.kind == "combat" or enc.kind == "elite" then
                    total = total + 1
                    if cell.cleared then cleared = cleared + 1 end
                end
            end
        end
    end

    -- CIRCLES SEALED, EVER, not this run's -- Pride is asking what this company has done, and a tally
    -- that reset with the expedition would make her gate unreachable in a mode that resets.
    local sealed = 0
    for _ in pairs((game.player and game.player.standing) or {}) do sealed = sealed + 1 end

    local st = Descent.gateState(sin, {
        fightsCleared = cleared,
        fightsTotal = total,
        wardDown = wardDown,
        carrying = Mule.load(game.player, run),
        sealed = sealed,
        paid = (run.tollPaid or {})[tostring(depth)] == true,
    })
    st.sin = sin
    st.depth = depth
    return st
end

-- PAY THE STAIR. `n` finds come off the mule -- the run's own finds, never the kit the company marched
-- down with, which is exactly the set Player.takeAtRisk already knows how to lift (it is what a wipe
-- drops). Taking the cheapest reading of "what you are carrying" is deliberate: the toll is a share of
-- the HAUL, and a stair that could reach into somebody's hand for their sword would be a robbery rather
-- than a price.
--
-- Marked per FLOOR, so a company that pays, climbs out and comes back down does not pay twice for the
-- same stair -- and a different circle's toll on a later floor is its own bill.
function game:payToll(n)
    local run = game.descent
    if not (run and game.player and n and n > 0) then return end
    local dropped = Player.takeAtRisk(game.player, run.entry) or {}
    -- takeAtRisk lifts the WHOLE haul, so the remainder goes straight back -- this is a share, not a
    -- confiscation. Sorted out here rather than by asking it for a subset, because "which particular
    -- finds" is not a question the player was asked and must not become one.
    for i = n + 1, #dropped do Player.addToStash(game.player, dropped[i]) end
    run.tollPaid = run.tollPaid or {}
    run.tollPaid[tostring(Descent.depth(run))] = true
    game:pushToast("She takes " .. math.min(n, #dropped) ..
        (n == 1 and " find" or " finds") .. " and stands aside")
    game:refreshHaul()
    saveRun()
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
    -- `pack` is a fight and salvages like one (see onWin), so the marker telegraphs the same stock. A
    -- pile with no cast on it is not a fight and promises nothing. The third reading of the one question
    -- (Encounter.opensBattle) -- what pays salvage is what runs the arena, and a hover that promised
    -- stock off a wider test than the branch that hands it over would be the same lie the border is.
    if not EncounterModel.opensBattle(enc) then return nil end
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
--
-- `chars` is who fell, for the one caller that has no battle state to read it off: a fight WALKED OFF
-- (Muster.canWalkOver) is resolved against a combat object nobody ever entered a state for, so
-- states/battle.lua's field would hold whatever the last real fight left in it. Everything else omits
-- it and takes that field, which is the ordinary case.
function game:inflictWounds(chars)
    -- Asked BEFORE the ledger moves, because Wound.inflict is what writes the one-way mark. See the
    -- coach below: this is the only moment the answer is still "never".
    local firstEver = not Wound.everWounded(game.player)
    local fallen = chars or require("states.battle").fallen
    local hurt = Wound.inflict(game.player, fallen)
    -- Named off the instances the battle handed back rather than looked up by id: these ARE the
    -- roster's own tables, and a companion's name can be the one the player typed at creation.
    local byId = {}
    for _, char in ipairs(fallen or {}) do byId[char.id] = char end
    for _, id in ipairs(hurt) do
        local char = byId[id]
        game:pushToast(((char and char.name) or "Someone") .. " is wounded")
    end

    -- THE FIRST ONE IS TAUGHT, and only the first. A toast says who; it does not say what a wound IS,
    -- and the mark it leaves -- the dark cap on that body's bar in the party strip -- is a thing the
    -- player has never seen before and will now be routing around for the rest of the expedition. So
    -- the very first time anybody in the company is carried out, the strip's own row gets a coach
    -- bubble naming it (drawCoach's "wound" branch).
    --
    -- ARMED HERE, WHICH IS ALSO WHY A WIPE NEVER SEES IT. Every wipe path calls this and then leaves
    -- the map inside the same function -- the haul is cut, the run is dropped, and the next screen is
    -- the city (or the Gate). A bubble pinned to an overworld that is already gone draws nothing, and
    -- there is nothing left for it to point at either: the surface sets every bone the moment the
    -- company is standing on it (models/wound.lua's Wound.clear), so a wiped company has no mark on any
    -- bar to be taught. The split falls out of where each path ends rather than out of a flag -- a
    -- company still standing on the board learns the mark, a company standing in a town has nothing to
    -- learn yet and will be taught by the first body carried out of a fight it survives.
    if firstEver and hurt[1] then
        game.coach = "wound"
        game.coachChar = hurt[1] -- whose row the bubble points at; the toasts name the rest
    end
    return hurt
end

-- HOW FAR THE COMPANY CAN SEE, re-resolved. The map widget's radius is settled once at enter from the
-- board's own, the party's torch and Gyeom's Ledger; this puts the Dark on top of all of it and takes it
-- off again when the stretch runs out.
--
-- A separate call rather than a field on the widget because the radius has three owners now and only one
-- of them changes mid-floor. `darkFor` counts DOWN IN STEPS (game:onArrive), not seconds: a hazard
-- measured in wall-clock would punish a player who stopped to read a tooltip, and what the dark is
-- actually taking is ground covered blind.
function game:applyVision()
    if not (game.map and game.player) then return end
    -- ONE STEP, and the dark takes it. Sight was a max of three sources -- the floor's own radius, the
    -- best torch in the company's packs, and Gyeom's Ledger on top -- which is what a NEIGHBOURHOOD
    -- needed when the fog hid the shape of the country. A place is the unit now and one step is four
    -- places (models/player.lua's Player.VISION), so there is one source and nothing widens it.
    --
    -- THE DARK TAKES IT TO NOTHING, which is the same bite it always had rather than a new one. It used
    -- to cut a radius of two-to-four down to one; against a flat one it would take nothing at all, and a
    -- hazard that costs the player nothing is a hazard that has been silently deleted. At zero the
    -- company reads only the place it is standing in and steps into whatever is beside it blind, which
    -- is what "covering ground blind" meant before and means now.
    game.map.visionRadius = ((game.darkFor or 0) > 0) and 0 or Player.visionRadius()
end

-- Put a marker on every pile lying on THIS floor, and take away the ones that have been lifted. Run
-- whenever the list can have changed -- a floor entered, a pile taken up.
--
-- The work is Descent.markPacks, in the model, because seating a marker is a decision about the run
-- rather than about this screen -- where a pile can be seen, and what happens when the tile it fell on
-- is already a fight (which is the tile a wipe lands on nearly every time). This screen's part is
-- knowing which floor the company is standing on.
function game:markBodies()
    if not (game.descent and game.grid) then return end
    Descent.markPacks(game.descent, game.grid, Descent.depth(game.descent), game.player)
end

-- THE LANDING. The circle's guard is face-down on the stair, and the stair is open.
--
-- IT USED TO BE AN EXTRACTION PROMPT, and deleting that question is the point rather than a
-- simplification. It asked "is what you are carrying worth more than what is below?", which is the right
-- question for a mode that banks -- and this one does not (models/descent.lua). Climbing out ended the
-- run and handed the player nothing they could spend, spend against, or beat next time; descending
-- risked a haul that evaporated on the way out anyway. BOTH ANSWERS PAID ZERO, so the choice was
-- between finishing the session and not finishing it, dressed as a decision about loot. Seven floors of
-- tension rested on a stake that was not there.
--
-- So the mode has one win now -- the Hollow Crown -- and the landing stops being an exit. What it is
-- instead is the beat the references all put here: you have just killed something with a name, and it
-- was carrying something. A slate of three off the beaten circle's own shelf, one taken, the other two
-- gone with it. Which circles the shuffle dealt you is now what a run's build is made of, and the seven
-- orders stop being seven orders of the same run.
--
-- AND IT NO LONGER TAKES THE STEP DOWN. Both of its buttons used to, so beating the guardian ended the
-- floor whether or not the company was finished with it -- see Descent.openStair for what that cost.
-- What this beat does now is credit the circle, hand over what she was carrying, and open the stair as
-- a tile behind her. Going down is a walk the player takes afterwards, and the panel is the reward for
-- the fight rather than the door out of the floor.
--
-- Deliberately NOT closeable: the slate is dealt once and dropped the moment this closes (`run.landing`),
-- so a dismissal that was not an answer would throw the boon away without ever having said so.
--
-- `cell` is the objective tile just cleared -- the ground the stair opens on. Nil on a resume, where
-- the board already came back with its stair on it and only the undealt boon is outstanding.
function game:openLanding(cell)
    local run = game.descent
    if not run then return end
    Descent.clearFloor(run, game.player)

    -- CIRCLES BEATEN, banked on the player so the tally outlives the run that earned it.
    --
    -- IT NO LONGER OPENS ANYTHING. This used to be the wiring that put a house in the city -- a beaten
    -- circle unlocked its shop -- which was a patch applied when the Quest Board was retired and seven
    -- doors could no longer open at all. It put every class's shelf behind fourteen floors of descent in
    -- a different order each run, so the only way to equip a class was to go deeper than that class's
    -- gear would have carried you. A house opens on the first errand it posts on a floor now
    -- (models/errand.lua) and this number is read by exactly one thing: the "Circles beaten:" line on the
    -- terminal card (models/descent.lua's Descent.account).
    --
    -- Credited ONCE per circle, on the general's floor, by the same test the run's own tally uses --
    -- getting past her honour guard is not getting past her.
    if Descent.isGeneralFloor(Descent.depth(run)) and game.player then
        local sin = Descent.sinAt(run, Descent.depth(run))
        if sin then
            game.player.standing = game.player.standing or {}
            game.player.standing[sin.vendor] = (game.player.standing[sin.vendor] or 0) + 1
        end
    end

    -- A CLEARED CIRCLE PAID CROSSING TOKENS HERE -- two of them, on the general's floor -- and that was
    -- the whole of how a descent grew its roster. The Crossing is retired: a companion is met at their
    -- house's opener and joins at that house's counter, so clearing a circle no longer pays toward the
    -- company at all. What it still pays is the guardian's own piece, below.
    --
    -- WORTH SAYING OUT LOUD RATHER THAN LEAVING AS A GAP: this is a reward hole, not a tidy-up. A circle
    -- used to hand over something that outlived the run, and now it does not.

    -- WHAT WAS ON THE BODY, and it is the body's OWN piece rather than a hand of cards.
    --
    -- THIS DEALT A RELIC SLATE: three for a general, two for her lieutenant, drawn off a weighted shelf
    -- leaning toward the circle just beaten. Both ranks paid the same currency and differed only in the
    -- WIDTH of the offer, which made a general a slightly wider lieutenant.
    --
    -- What each of them pays now is a unique authored object that was hers -- Ira's mail, the Codex, the
    -- Bottomless Purse -- and it survives the run, where a relic never did (models/descent.lua's DROPS,
    -- which carries the whole argument and the gaps still to be authored). Three consequences worth
    -- naming:
    --
    --   there is no CHOICE here any more, so there is no slate to pin to the run for a resume to
    --   re-deal, and `run.landing` goes with it;
    --
    --   the piece goes to the STASH, not to the run's relic state. The point of it is that it outlives
    --   the company that took it;
    --
    --   an exhausted list -- a second playthrough, or a rank whose mirror is not authored yet -- pays
    --   that house's forge stock instead, so the stair is never silent.
    local wasGeneral = Descent.isGeneralFloor(Descent.depth(run))
    local beaten = Descent.sinAt(run, Descent.depth(run))
    local dropId = Descent.dropFor(game.player, beaten, wasGeneral)

    -- THE WAY DOWN, OPENED. Done here rather than after the announcement so the board is already changed
    -- before anything is drawn over it: a player who quits with the notice still on screen comes back to
    -- a floor whose stair is standing open. What the naming below then says about the circle underneath
    -- belongs to the stair, and is said there -- at the moment the player commits to the step rather than
    -- at the moment they cannot.
    game:openStairDown(cell)
    run.landing = nil -- no slate to re-deal; a resume finds the stair open and nothing outstanding

    -- WHO IS BEING NAMED. The general by name on her own stair; her lieutenant by name on the floors above
    -- it (Descent.guardianName), which is what tells the two ranks apart now that both of them pay.
    local felled = Descent.guardianName(beaten, wasGeneral)
    -- WHO WENT DOWN, and only that. What she was CARRYING used to be said on this same line -- the piece,
    -- or the house stock that stands in for it, or the gold that stands in for that -- and a reward
    -- announced in the corner of the map is a reward the player reads after they have stopped looking for
    -- one. All three are named on the victory screen now, as cards beside the salvage, before this toast
    -- is ever drawn (states/game.lua's previewObjectiveReward -> ui/panels/battle_summary.lua). What is
    -- left here is the news, which is what a toast is for: a general is dead and the floor knows it.
    if felled then game:pushToast(felled .. " is beaten") end
    if game.player then
        if dropId then
            local item = Item.instantiate(dropId)
            Player.addToStash(game.player, item)
            Player.markNew(game.player, Player.NEW_STASH, dropId)
        else
            -- NOTHING OF HERS LEFT, so the house pays in its own stock -- the material its bench bills in
            -- (models/material.lua). It is the one payout that cannot run out and the one that still says
            -- whose circle this was, which is more than gold could do.
            local houseMat = beaten and Material.houseFor((Vendor.get(beaten.vendor) or {}).class)
            if houseMat then
                Player.addMaterial(game.player, houseMat, Descent.SPENT_SET_STOCK)
            else
                Player.addGold(game.player, Descent.SPENT_SET_GOLD)
            end
        end
    end
    -- ...and the stair the board now carries, which is the state worth losing least.
    --
    -- STILL NO PANEL HERE, and now for a better reason than the one that used to sit in this space. The
    -- old note asked whether a general's defeat deserved more than a line in the corner and declined to
    -- answer, because the only answer on offer was a chooser with one object in it. The answer turned out
    -- to be that it deserved the screen the game ALREADY draws for a won fight: the piece, the house stock
    -- that stands in for it, and the tokens below are all named on the victory panel now, one beat before
    -- this function runs. Opening a second panel here would report the same payout twice.
    --
    -- The tokens are still GRANTED here rather than on that screen -- the panel only ever displays, which
    -- is the rule that keeps a preview from becoming a second payout (see game:previewObjectiveReward).
    saveRun()
end

-- OPENING THE STAIR: the tile the guardian was holding stops being the floor's objective and becomes
-- the way down (models/descent.lua's Descent.openStair, which is where the argument for this lives).
--
-- Two things happen here that the model half cannot do, because both are about the SCREEN:
--
--   the token steps back off it. The company is standing on the ground it just fought for, and a stop
--     is only ever entered by ARRIVING at it (ui/overworld_map.lua) -- so a stair left underfoot would
--     be one the player had to walk away from before it could be used, which is exactly the shape of a
--     thing that reads as broken. Stepping back one tile, the way a tutorial retry does
--     (OverworldMap:retreatFromEncounter), puts it in front of them instead.
--   it is said out loud. Without a line the whole change is one marker swapping shape on the tile the
--     party is standing on, which is the least visible square on the board to put news in.
function game:openStairDown(cell)
    if not Descent.openStair(cell) then return end
    if game.map and game.map.retreatFromEncounter then game.map:retreatFromEncounter() end
    game:pushToast("The way down is open")
end

-- ---------------------------------------------------------------------------
-- A trip: the ground, and the several pieces of work standing on it
-- ---------------------------------------------------------------------------
--
-- A run used to BE a quest -- one objective, one payout, one trip home. It is a place now: the player
-- travels to a ground and everything the houses have posted there is on the board at once, each on its
-- own dead end (models/quest.lua's Quest.trip). The day is spent on entering, whatever you come home
-- with, and clearing one piece of work leaves you standing on the map with the others still out there.
--
-- Everything below reads through these three, so the single-quest legs -- the prologue's flight, the
-- debut's walk, every descent floor -- come through unchanged as a trip of one.

-- The board entry behind an objective cell, or nil. A cell carries only the quest ID (the spec can hold
-- a composition function and the board is serialized whole into the save), so this is the lookup back.
local function questAt(cell)
    local id = cell and cell.encounter and cell.encounter.questId
    if not id then return game.quest end
    for _, q in ipairs((game.quest and game.quest.quests) or {}) do
        if q.id == id then return q end
    end
    return game.quest
end

-- ...and its objective spec: what is fought there, what scene it opens with, how deep it is.
local function objectiveAt(cell)
    local mp = (game.quest and game.quest.map) or {}
    local id = cell and cell.encounter and cell.encounter.questId
    if id then
        for _, spec in ipairs(mp.objectives or {}) do
            if spec.questId == id then return spec end
        end
    end
    return (mp.objectives and mp.objectives[1]) or mp.objective
end

-- What is left to do on this ground: one row per piece of work, in board order, each with whether it
-- has been taken. THE run's title now (game:drawChecklist) and the thing that decides when the day is
-- over. Cleared rows keep their place -- what you did not take is read against what you did.
--
-- EACH ROW SAYS WHAT THE WORK IS, not what it is called. A quest's title -- "The Haunted Mill", "The
-- Sunken Sanctum" -- names a place without saying a thing about what the company is meant to do when it
-- gets there, and a checklist of titles is a list of nouns the player cannot act on. `work` is the
-- objective's own sentence, written by the same hand the battle HUD's objective line is
-- (Combat.objectiveGoal), so the promise made on the map is word for word the one the fight opens with.
-- The title stays on the row as `name` -- the map marker and the battle's own header still use it.
function game:worklist()
    local out = {}
    for _, q in ipairs((game.quest and game.quest.quests) or {}) do
        -- A COMPANION'S ASK NOBODY HAS AGREED TO YET is not on the list. Both ends of a
        -- recruit are seated when the floor is built (models/descent.lua), so the ask is
        -- standing out there before the body who wants it has been met -- and a checklist row
        -- for work the player was never asked for is the run promising something on their
        -- behalf. Required inline rather than closed over: this file sits against Lua 5.1's
        -- 60-upvalue ceiling per function.
        if not require("models.errand").unaskedPosting(game.player, q.id) then
        local spec = (q.map or {}).objective or {}
        -- A `meet` objective has no win condition to phrase: nothing is fought there, the company just
        -- has to arrive and the scene plays (see the meet branch in game:openEncounter).
        local work = spec.meet and "Reach the meeting" or Combat.objectiveGoal(spec.win)
        out[#out + 1] = {
            id = q.id, name = q.name, work = work,
            -- WHO POSTED IT, carried through so the row can wear that house's mark
            -- (ui/vendor_icons.lua) -- the same mark standing on the tile out on the board. The row is
            -- where the mark is glossed: here it sits beside the sentence saying what the work is.
            sponsor = q.sponsor,
            done = (game.tripDone or {})[q.id] == true,
        }
        end
    end
    -- ...and the title comes BACK on any row a second row reads identically to. A fight names who it is
    -- against and no two of those agree, but the ground objectives do not name anything of their own:
    -- two quests posted here that both want a post held are two rows reading "Hold the marked ground",
    -- which is true of each and tells the player nothing about either -- least of all which of the two
    -- the tick belongs to. The name is the only thing that separates them, so it is spent here.
    local seen = {}
    for _, row in ipairs(out) do seen[row.work] = (seen[row.work] or 0) + 1 end
    for _, row in ipairs(out) do
        if seen[row.work] > 1 then row.work = row.work .. "  ·  " .. row.name end
    end
    return out
end

-- Is there anything left on this ground? False the moment one box is unticked, so a trip of one
-- behaves exactly as a quest always did: clear the objective and the day is over.
function game:tripCleared()
    local rows = game:worklist()
    if #rows == 0 then return true end
    for _, row in ipairs(rows) do
        if not row.done then return false end
    end
    return true
end

-- PAYING FOR ONE PIECE OF WORK, without ending the day.
--
-- Quest.complete is the single payout seam and stays that -- gold, the relic, the companion, the
-- sponsor's standing, the shelf it opens -- but it is called once per objective now rather than once
-- per run. Two things were moved OFF it and onto the exit (game:bankHaul), because they belong to the
-- DAY rather than to a piece of work: the cache haul, which would otherwise be banked by whichever
-- objective happened to be cleared first and then again by the next one, and the supper, which is worn
-- by the company from the moment they set out.
--
-- Returns the reward summary (nil if this quest had already been paid -- the double-payout guard lives
-- in Quest.complete and is what makes a re-cleared tile worth nothing).
function game:payObjective(cell, materials)
    local quest = questAt(cell)
    if not quest then return nil end
    local reward = quest.request
        and Request.payout(game.player, quest, materials)
        or Quest.complete(game.player, quest, materials, { keepMeal = true })
    if quest.id then game.tripDone[quest.id] = true end
    return reward, quest
end

-- WHAT THE OBJECTIVE IS ABOUT TO PAY, named on the victory screen instead of in the corner of the map.
--
-- The arithmetic is Descent.objectiveReward's: it is a property of the run and the player, and it lives in
-- the model so that a spec can read it -- this file pulls ui/theme.lua and so cannot be required under the
-- headless runner, which makes any payout written here a payout no test can check.
--
-- What is decided HERE is the two cases with nothing to preview, both of them questions about the run
-- descriptor this state owns rather than about the payout itself:
--
--   NO DESCENT    a campaign board quest pays through Quest.complete and gets the Company Advancement
--                 overlay instead -- a different screen with a different job. (That overlay has had no
--                 reachable caller since the Quest Board was retired, which is most of why the descent's
--                 objectives ended up reporting themselves in toasts.)
--   ENDS THE RUN  the bottom of the descent finishes on the mode's own terminal card, which already names
--                 everything the account holds. Naming it on a victory panel first would spend the one
--                 screen this mode has been building toward for fifteen floors.
function game:previewObjectiveReward(objSpec)
    if not game.descent then return nil end
    if game.quest and game.quest.endsDescent then return nil end
    return Descent.objectiveReward(game.player, game.descent, objSpec)
end

-- THE DAY ENDS HERE, and this is the only place it does.
--
-- Everything the run found has been in the stash all along -- live, equippable, spendable -- but
-- provisional: the entry snapshot on the run could put it all back. Dropping the run drops that
-- snapshot and the finds become permanent. What is banked here rather than earlier is what the DAY
-- earned rather than what a quest did: the ore out of the caches (foraging is this now -- there is no
-- separate errand for it), and the supper, which is eaten whether or not the ground was cleared.
--
-- Reached three ways -- the last box ticked, the player walking out, or the ground beaten -- and a wipe
-- deliberately does NOT come through here: an unbanked haul is simply lost, which is what wipeRun's
-- penalty already says about gold and stock.
function game:bankHaul()
    local haul = game.map and game.map.cacheHaul
    if haul and game.player then
        for id, n in pairs(haul) do
            if (n or 0) > 0 then Player.addMaterial(game.player, id, n) end
        end
        game.map.cacheHaul = {}
    end
    -- The supper is spent by the day, not by the first fight that ends well.
    if game.player then Meal.clear(game.player) end
end

-- Persist the run if one is active (a resumable board quest). No-op otherwise, so it is safe to sprinkle at
-- every point the board changes -- entering the map, approaching an encounter, and resolving one. The
-- resolution saves matter: a treasure collected or an event resolved marks its cell cleared, and without
-- persisting that a resume would replay the stop and grant its spoils twice (a combat win already saves).
function saveRun()
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
-- The `_legacyPrestige` slot is dead and kept only so the positional signature does not shift under
-- half a dozen callers in one commit. The day is read off the PLAYER now (Calendar.day) rather than
-- handed in, which is the correct source: it is the campaign's clock, not a per-launch argument, and a
-- caller passing a stale one was exactly how a resumed run could scale to the wrong depth.
function game.enter(self, quest, _legacyPrestige, player, onComplete, resume)
    require("models.sound").music("music.overworld")
    ScreenFx.reset() -- the map opens on full colour, whatever the last screen left ringing

    -- A RESUMED DESCENT FLOOR IS RE-SYNTHESIZED HERE, because the descriptor that came back from the
    -- save was built without a player and a floor's ends are a fact about one.
    --
    -- Save.restoreRun runs inside Save.load, before there is a player object to hand it, so its
    -- `Descent.floorQuest(descent)` gets nil for the second argument -- and Descent.floorObjectives
    -- answers a nil player with the stair and nothing else. Every errand seated on the floor was
    -- therefore missing from `quest.map.objectives` on a resume, while the CELLS carrying them came
    -- back off the serialized board intact. objectiveAt matches a cell to its spec by questId and
    -- falls back to objectives[1] when nothing matches, so an errand tile resolved to THE STAIR: no
    -- posting was recognised, the scene that asks whether to take the work never played, and the
    -- fight the tile opened was the guardian's rather than the house's. Quit and Continue was all it
    -- took, which is why the model specs were green.
    --
    -- Rebuilt rather than patched, because the floor descriptor is pure -- the same run and the same
    -- player yield the same floor -- and the board itself is NOT rebuilt: it comes off the snapshot
    -- below, fog and cleared stops and all. What this restores is only the reading of it.
    if resume and resume.descent and player then
        quest = Descent.floorQuest(resume.descent, player) or quest
    end

    game.quest = quest
    -- A RESUME KEEPS THE DAY IT WAS ENTERED ON. Reading the clock afresh would be right today and
    -- wrong the moment anything else can move it, and the failure would be a board that quietly
    -- re-scales halfway through itself -- the enemy level, the encounter pool and the loot band all
    -- hang off this one number.
    game.day = (resume and resume.day) or Calendar.day(player)
    game.player = player -- kept so combat encounters can deploy the active party
    game.onComplete = onComplete
    -- A DESCENT floor rather than a board quest. The descriptor is synthesized (models/descent.lua) and
    -- carries the run itself, which is what makes one expedition out of a stack of floors: the same table
    -- travels from floor to floor, so the rollback point taken at the top survives all of them.
    game.descent = quest and quest.descent or nil

    -- A DESCENT'S CLOCK IS ITS DEPTH, and this line is load-bearing in a way that was invisible.
    --
    -- `day` is the campaign's difficulty dial: the enemy level, the loot band and -- the one that bites
    -- here -- WHICH ENCOUNTER BLUEPRINTS ARE ELIGIBLE AT ALL (each carries a `minDay`). A descent
    -- profile has no calendar, so Calendar.day fell through to 1 and every floor of a fifteen-floor
    -- dungeon drew from the day-one pool. Measured: the floor seated two or three fights where its own
    -- combat share allows twelve, because almost nothing was eligible to seat and the rest of the stops
    -- were re-seated as texture. The board looked like a pacing decision and was a gate.
    --
    -- So depth IS the day, scaled onto the campaign's forty so the two ladders speak the same units:
    -- floor one reads shallow, the Hollow Crown reads like the last week of the calendar.
    --
    -- ELIGIBILITY ONLY, and this line used to claim otherwise. It said the enemy LEVEL still came off
    -- `floorLevel` and was untouched by this -- but states/battle.lua read its level off
    -- Calendar.dangerLevel(day) too, and Growth.combatantLevel takes the higher of the two, so from
    -- floor 3 down this mapping WAS the level ladder and floorLevel was never read again. The descent
    -- carries its own dial now (Descent.dangerLevel, passed as `enemyLevel` at every fight below) and
    -- the day is back to the one job it was brought in for: which blueprints may appear at all.
    if game.descent then
        -- Derived from the floor's own danger rather than from its depth (Descent.poolDay), so the
        -- borrowed day can never out-rank the ladder it is standing beside. See that function.
        game.day = (resume and resume.day) or Descent.poolDay(game.descent)
        -- THE COMPANY'S HIGH-WATER MARK, written here because this is the line where a floor descriptor
        -- stops being a plan and becomes a board somebody is standing on. Every way down arrives here --
        -- the Gate's stair, the landing's "go down", a floor that gives way -- so a fourth one cannot
        -- forget to report. It is what the city grows on: the Cafe opens at floor two and the Forge at
        -- floor four (models/descent.lua's Descent.reached, models/building.lua's `unlockDepth`).
        Descent.reached(game.player, Descent.depth(game.descent))
    end
    local mp = quest and quest.map or {}
    -- Which house's stock this run pays out in: the quest's SPONSOR, not the party's needs. That is the
    -- whole point -- running the Bastion's line yields Bastion stock, which the Arcanum's gear will want
    -- at the Forge, so the seven lines feed one economy. Resolved once here because BOTH payers need it:
    -- the map's caches (below) and every fight's salvage (models/spoils.lua, via the battle state).
    -- A TRIP HAS NO ONE SPONSOR. Several houses can have work on the same ground, so the run's own
    -- salvage house is the first of them and the CACHES are dealt across all of them
    -- (map.houseMaterials, below). An objective fight still salvages in its own quest's house -- see
    -- the battle launch -- so the piece of work you took pays in the stock of whoever posted it.
    game.houseMaterial = Material.houseFor((Vendor.get(quest and quest.sponsor) or {}).class)
        or (mp.houseMaterials and mp.houseMaterials[1])

    -- WHAT IS STILL STANDING ON THIS GROUND. Keyed by quest id, carried through a quit-and-Continue
    -- (models/save.lua) so a resumed day comes back with the same boxes already ticked. A single-quest
    -- leg has one entry and nothing about it changes.
    game.tripDone = (resume and resume.tripDone) or {}

    -- Dynamic encounter selection: build the eligible weighted pool for this
    -- player's prestige + the quest's biome, plus any guaranteed "always" picks.
    -- `generalsStanding` rides on the ctx every composition function reads, so the finale can size
    -- itself by who is left alive without the state learning which quest is the finale
    -- (models/calendar.lua). Nil-safe everywhere else: no other blueprint asks for it.
    local ctx = { day = game.day, biome = mp.biome, quest = quest,
        generalsStanding = Calendar.generalsStanding(player) }
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
    elseif game.descent and Descent.floorBoard(game.descent, Descent.depth(game.descent)) then
        -- A FLOOR THIS COMPANY HAS ALREADY WALKED. Wizardry's levels are the same maze every time, which
        -- is the entire reason mapping one is worth doing -- a secret door found on the third trip is
        -- something you found rather than something that was rolled. So a descent keeps its boards
        -- (Descent.keepFloor) and re-enters the one it made, fog and cleared stops and all, rather than
        -- rolling a new one over the top of the player's own map.
        game.grid = Overworld.fromSnapshot(Descent.floorBoard(game.descent, Descent.depth(game.descent)))
        -- ...and its inhabitants are back. The maze is permanent and the monsters are not
        -- (Descent.rearmFloor) -- so a floor you finished is not an empty corridor next time, and the
        -- walk back down to a dropped pack costs what walking down cost the first time.
        Descent.rearmFloor(game.grid)
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
            -- ...and every house working this ground, for the caches to be dealt across (placeCaches).
            -- A one-house run leaves this nil and pays out exactly as it always did.
            houseMaterials = mp.houseMaterials,
            objective = mp.objective,
            -- ONE END PER PIECE OF WORK. A ground offering three quests puts three objectives on the
            -- board, each on its own dead end; a single-quest leg passes `objective` above and comes
            -- through the generator as a list of one (models/overworld.lua).
            objectives = mp.objectives,
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
            -- A descent floor gives an ABSOLUTE fight cap instead, because its budget has to cover the
            -- ends this same table passes as `objectives` -- the stair, the errands, the openers -- and a
            -- share of the stop count cannot see them (models/descent.lua's Descent.FLOOR_FIGHTS).
            combatBudget = mp.combatBudget,
            -- Which texture kinds the board is guaranteed to hold whatever the draw does. Absent (every
            -- campaign leg) the generator keeps its own default of a reliquary and a rest; a descent
            -- floor names that pair plus a recruit stop while the company has room (Descent.floorQuest).
            guaranteeKinds = mp.guaranteeKinds,
            -- ...and HOW MANY of each, which is a separate question from which. Absent (every campaign
            -- leg) the generator keeps its own per-kind density; a descent floor pins its camps to a flat
            -- one, because a floor is one segment of a fifteen-floor run and cannot read the run's length
            -- off its own stop count (Descent.FLOOR_RESTS).
            guarantee = mp.guarantee,
            -- THE WAY BACK UP, on the place the party walks in on. A descent floor only: a campaign quest
            -- is left for free by pressing Back, so a cell offering an exit would be offering nothing.
            exitAtStart = mp.exitAtStart,
            -- Places that read as absent until somebody stands beside them and looks
            -- (models/overworld.lua's placeSecrets). A descent floor only: a campaign ground is walked
            -- once and left, so ground the player never finds is content that was never made.
            secrets = mp.secrets,
            alwaysEncounters = always,
            -- A climb rather than a region: guaranteed encounters laid out in authored order by distance
            -- from the start, and the objective on the farthest dead-end there is. See
            -- Overworld:placeEncounters and :placeObjectiveAndGates.
            ascent = mp.ascent,
            -- THE GROUND IS DEALT OFF THE SAVE'S SEED, not off the clock (models/seed.lua).
            --
            -- This was a clock read, and it was the line that made the seed everything else in the mode
            -- reproduces from a half-truth: the circles, the deal of houses and the guard over a dropped
            -- pack all came back the same, and then the company walked out onto ground that had never
            -- existed before and would never exist again. A seed that does not decide the map is not a
            -- seed anybody can use.
            --
            -- A FLOOR IS (run, depth) and nothing else, which is the same rule every other derived thing
            -- down here obeys (Descent.floorQuest, Descent.sinOrder): a floor must lay out identically
            -- however many times it is asked for, or a resume that missed its kept board would rebuild a
            -- different one. A campaign ground is (lap, day, which piece of work) -- the day is the
            -- clock the campaign actually runs on, and the quest id keeps two grounds bought on one day
            -- from being the same ground twice.
            seed = game.descent
                and Seed.mix(game.descent.seed, Descent.depth(game.descent))
                or Seed.mix(Seed.lap(player), game.day or 1, Seed.text(quest and quest.id or "")),
        }
        game.grid = Overworld.generate(params)
    end
    game.activePanel = nil
    game.complete = false
    -- NO FIGHT IS IN PROGRESS ON A FLOOR NOBODY HAS WALKED YET, and this has to be said at the DOOR
    -- rather than trusted to the way out.
    --
    -- `game` is a module table, so every field on it outlives a State.switch. A hosted battle is held in
    -- `game.battle` and game.update forwards to it while it is set -- so a route that leaves this screen
    -- mid-fight without clearing it comes back INTO that fight, on whatever floor is entered next.
    --
    -- There were seven ways out of a fight and six of them cleared it. The seventh was the WIPE: the
    -- party is routed, the haul drops, the floor goes in the map book and the state switches to the Gate
    -- -- with `game.battle` still pointing at the battle just lost. Walking back down the stair then put
    -- the company straight back into the arena they had just been beaten in. That is the shape a
    -- failure route always fails in: the losing path is the one nobody walks while building the winning
    -- one ([[failure-route-skips-bookkeeping]]).
    --
    -- The wipe clears it too, alongside its six siblings, because a state left inconsistent between the
    -- switch and the next enter is still wrong. This is the guarantee: whatever any exit forgets, a
    -- floor opens with no fight on it.
    game.battle = nil
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
        -- A house's posted work asks at the doorway of the room it is in, and accepting opens the way
        -- rather than starting the job. Returns true when it took the step (the token stays on the
        -- threshold until the scene answers). See game:askErrandAtDoor.
        onDoorPosting = function(objCell) return game:askErrandAtDoor(objCell) end,
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
            -- THE FIRST-WOUND LESSON IS SPENT BY WALKING ON, and a step is the only honest thing to
            -- spend it on. Every other coach step out here is cleared by the player doing the thing it
            -- asked for; this one asks for nothing -- a wound cannot be answered on the board -- so
            -- what it is waiting for is to have been READ. Taking a step is the player saying so, and
            -- it is the same beat the bubble was put up to inform: the next stop is chosen by a
            -- company that is now short of that much.
            if game.coach == "wound" then
                game.coach, game.coachChar = nil, nil
            end
            -- A DOOR IS FOUND BY BEING BESIDE IT. Wizardry makes you stand at a wall and press Search,
            -- and the turns are the cost; there is no turn economy on this board to spend, so the cost
            -- is having WALKED there -- down a dead end that looked like it ended. A company that never
            -- goes down the spur never finds it, which makes exploring the reward rather than a roll,
            -- and stops searching becoming a chore performed against every wall.
            local door = game.grid:findSecrets(cell.x, cell.y, 1)
            if door then
                game.grid:reveal(cell.x, cell.y, game.map.visionRadius)
                game:pushToast("The wall gives. There is a way through here.")
                saveRun()
            end
            -- The Dark burns down in STEPS, here, because this is the one callback that fires on a
            -- landed tile and on nothing else. It is what the hazard is measured in: ground covered
            -- blind, rather than seconds a player might have spent reading a tooltip.
            if (game.darkFor or 0) > 0 then
                game.darkFor = game.darkFor - 1
                if game.darkFor <= 0 then
                    game.darkFor = nil
                    game:pushToast("The lamp catches again.")
                end
                game:applyVision()
            end
        end,
        -- A cache/key taken by walking over it: name it on screen (see announcePickup).
        onPickup = function(kind, payload) announcePickup(kind, payload) end,
        -- What colours a fight's marker and counts its pips: where the company stands against THIS fight
        -- (models/muster.lua). The map owns no roster and does no comparing -- it asks.
        musterBand = function(cell) return game:musterBand(cell) end,
        -- Fog: one step, on every floor rolled or authored (models/player.lua's Player.VISION).
        -- game:applyVision is what moves it afterwards, and the only thing that does is the dark.
        visionRadius = Player.visionRadius(),
    })

    -- On a resume, seat the token where the player quit (the map widget otherwise spawns it at the start
    -- cell). The grid already carries its fog and cleared stops from the snapshot; re-reveal around the
    -- landing tile so the current vision disc is lit, then snap the camera straight there (no pan-in).
    -- COMING UP A STAIR PUTS YOU ON THE STAIR YOU CAME DOWN BY, not at the floor's entrance.
    --
    -- `run.arriveAt` is set by Descent.retreat and consumed here, once. Without it the map widget seats
    -- the token on the grid's start cell -- which on the floor above is its own way UP, at the far end
    -- of ground the company already crossed. That would be a teleport wearing a staircase, and it would
    -- hand back for free the walk that going up is meant to cost.
    --
    -- Read before the resume branch and cleared immediately, so it cannot survive into a later entry and
    -- silently reposition a company that arrived by some other route.
    if game.descent and game.descent.arriveAt then
        local at = game.descent.arriveAt
        game.descent.arriveAt = nil
        if game.grid:isWalkable(at.x, at.y, {}) then
            game.map.px, game.map.py = at.x, at.y
            game.grid:reveal(at.x, at.y, game.map.visionRadius)
        end
    end

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
    -- The Potions button's own gate, held shut for the flight leg until the first fight is won (see
    -- useVisible and the combat onWin below). True from the start everywhere else.
    game.useUnlocked = (mp.tutorial ~= "flight")
    game.coach = nil
    game.coachChar = nil

    -- Autosave the run so quitting mid-quest resumes onto the map (states/menu.lua's Continue). Only a
    -- board quest is resumable (runResumable) -- a scripted/tutorial leg has no hub to return to. The live
    -- grid + map widget are parked on the player so ANY later Player.save (a won fight's spoils, the next
    -- encounter) re-snapshots the current board; cleared on the way out (clearRun / hub.enter backstop).
    -- THE DAY IS SPENT HERE, and "here" is load-bearing: at the top of a FRESH expedition, before the
    -- board is walked and before anything on it is found (models/calendar.lua).
    --
    -- Entering is what costs, not clearing. Take the objective, turn back with your pockets full, or get
    -- wiped -- the day is gone all three ways, which is the whole of "push on or go home with what I
    -- have". Charging on the way out instead would make a run that went badly free, and a player who
    -- turned back at the first bad fight would have spent nothing.
    --
    -- THREE THINGS THIS MUST NOT DO, each of which is a way of getting a day back for nothing:
    --   a RESUME must not re-charge. Quitting to the menu mid-quest and pressing Continue is the same
    --     expedition, and the day was spent when it began.
    --   a DESCENT must charge ONCE, at the mouth. It used to be exempt entirely -- a separate mode with
    --     no calendar behind it -- and the danger the exemption dodged is real: the second floor is a
    --     fresh game.enter, so a naive charge bills a day per floor. `descent.entry` is nil at exactly
    --     one moment, the top of an expedition (states/gate.lua's descend clears it), which is the same
    --     test the rollback point below is taken on. One walk in, one day.
    --   the PROLOGUE must not charge. It runs before the campaign the calendar measures; `runResumable`
    --     is already false for a scripted leg, which is why the spend sits inside that branch.
    local freshExpedition = not game.descent or not game.descent.entry
    if runResumable() and quest and quest.id and not resume and freshExpedition then
        -- A NIGHT PASSES, which is now the day itself and nothing else. It used to be three things --
        -- the day, a wound off everybody lodged at the Inn, and whoever that finished walking out of
        -- their room -- and the Inn is deleted along with the whole toll (models/wound.lua).
        --
        -- STILL THROUGH Gate.night rather than reaching for Calendar.spend directly. This is the only
        -- caller left, and the indirection is deliberately kept: "a night passes" is a fact about the
        -- loop, and the day is only the part of it the calendar happens to own.
        require("models.gate").night(game.player)
    end

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
        -- The day's work as plain ids, and which of it is already taken. Rebuilt into the trip on the
        -- way back in (models/save.lua -> Quest.tripFromIds); nil for every single-quest leg, which
        -- resumes through `questId` exactly as it always did.
        local trip
        if quest.trip then
            trip = { groundId = quest.groundId, questIds = {} }
            for _, q in ipairs(quest.quests or {}) do
                trip.questIds[#trip.questIds + 1] = q.id
            end
        end
        game.player.activeRun = {
            questId = quest.id,
            day = game.day,
            trip = trip,
            tripDone = game.tripDone,
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
            -- and losing a fight takes most of the coin and ore back (wipeRun). The gear the player walked in with is
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
    --
    -- THE ONE EXCEPTION IS THE LANDING, and it is not a stop -- it is the only screen in the game a
    -- resume can land BEHIND. The boon a circle's guard was carrying is dealt once and lives nowhere but
    -- that panel, so a player who quit while it was open would come back to a floor with a relic
    -- undealt and nothing on the board that could ever deal it. `run.landing` is set for exactly that
    -- window (game:openLanding) and cleared the moment the card is answered, so this re-opens the same
    -- panel with the same three. The STAIR needs no such handling any more: it is a tile on the board
    -- now (Descent.openStair), so it comes back in the snapshot with the rest of the ground.
    if resume then
        if game.descent and game.descent.landing then game:openLanding() end
        return
    end

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
        -- A GUARDED PACK IS RATED OFF THE CELL, because that is where its cast is: the company standing
        -- over a dropped bag was drawn once, when the party fell, and stored on the drop
        -- (models/descent.lua's Descent.packGuard). Its blueprint deliberately carries no composition,
        -- so rating the blueprint would price every pile on the board as the resolver's default body.
        if enc and enc.kind == "pack" and enc.composition then
            def = { kind = "pack", composition = enc.composition }
        end
        cached = def and Muster.encounter(def, {
            day = game.day,
            enemyLevel = game.quest and game.quest.dangerLevel,
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

-- ASKING WHETHER TO DO A HOUSE'S WORK, at the tile the work is standing on.
--
-- Two scenes, because there are two ways to meet one (models/errand.lua's Errand.posting): the errand
-- a house asked for, and the posting from a house that has no door yet. Both name the house and read
-- its own description out, through `{house}` and `{posting}` -- set on the player for the length of the
-- scene and cleared after, the same way one "the shelf just grew" scene per shop speaks any discipline
-- (models/locale.lua's Locale.substitute).
--
-- YES GOES INTO THE FIGHT and no steps the company back off the tile. Declining costs nothing and takes
-- nothing: the cell is never marked cleared, so the work is still standing there and walking back onto
-- it asks again. That is the whole point of asking -- a floor is not obliged to be spent the way it was
-- planned in a shop, and a company that arrived lighter than it left can take the stair instead.
--
-- NO ANSWER IS A NO. Escape and B end a scene from anywhere, choices on screen or not, and they mean
-- cancel on every other surface in the game; the answer comes back nil and the company steps back.
-- THE SAME QUESTION, ASKED AT THE DOORWAY. Called by the map when the company steps onto a door leading
-- into a chamber that holds posted work (ui/overworld_map.lua's :arrive).
--
-- The difference from askErrand below is what YES does. There, the company is already standing on the
-- marker, so accepting starts the work; here they are on the threshold, so accepting only opens the way
-- -- they walk in, and whatever is in the room happens when they meet it. That is the whole point of
-- moving the question: a room is the work, so being asked inside it is being told.
--
-- Refusing costs nothing at all: the company never moved. A doorway cannot be stood on (a step through
-- one carries straight to the tile beyond -- ui/overworld_map.lua's :step), so the question is asked
-- BEFORE the step commits and a no simply declines it. The job stays exactly where it was, to be walked
-- back to whenever. A refusal has to cost nothing or it is not one.
--
-- `errandAnswered` rides on the objective's own cell (and in CELL_FIELDS, so a resume remembers it),
-- which is what stops openEncounter asking the same question a second time when the fight is reached.
function game:askErrandAtDoor(objCell)
    local objSpec = objCell and objCell.encounter
    local questId = objSpec and objSpec.questId
    local posting = game.descent and questId and Errand.posting(game.player, questId)
    if not posting then return false end

    local player = game.player
    local vendor = Vendor.get(posting.vendorId) or {}
    if player then
        player.postingHouse = vendor.name or posting.vendorId
        player.postingWork = posting.def.description or posting.def.name
    end
    require("models.conversation").play(Errand.postingScene(posting), function(answer)
        if player then player.postingHouse, player.postingWork = nil, nil end
        if answer == "accept" then
            -- The way is open: the next step through this door carries the company in, and the marker
            -- inside will not ask again (openEncounter reads the same flag).
            objCell.errandAnswered = true
            -- ...AND THE COMPANY IS NOW CARRYING IT, which is the second half of saying yes and was
            -- missing. `errandAnswered` is a fact about this DOOR -- it stops the same question being
            -- asked twice -- and nothing about it reaches the run's own list of work. So a player who
            -- agreed to a posting saw no row for it on the checklist, walked away, and had nothing
            -- anywhere to say what they had agreed to or where. Recording it is what puts the row up
            -- (game:worklist, through Errand.unaskedPosting) and what makes the shop's own list of
            -- outstanding asks true.
            Errand.accept(player, questId, game.quest and game.quest.floor or 1)
            saveRun()
        end
        -- ...and a refusal does nothing, deliberately. Nothing moved, so there is nothing to step back
        -- from -- see the note above the function.
    end)
    return true
end

function game:askErrand(cell, posting)
    local player = game.player
    local vendor = Vendor.get(posting.vendorId) or {}
    if player then
        player.postingHouse = vendor.name or posting.vendorId
        player.postingWork = posting.def.description or posting.def.name
    end
    require("models.conversation").play(Errand.postingScene(posting), function(answer)
        if player then
            player.postingHouse, player.postingWork = nil, nil
        end
        if answer == "accept" then
            -- Taken on before the fight opens, so the run carries it whichever way it was
            -- agreed to -- at the door or standing on the marker (see askErrandAtDoor).
            require("models.errand").accept(game.player, cell.encounter and cell.encounter.questId,
                game.quest and game.quest.floor or 1)
            game:openEncounter(cell, { errandAnswered = true })
        elseif game.map and game.map.retreatFromEncounter then
            -- Back onto the tile they came from, the way a cleared stair steps the token off itself
            -- (game:openStairDown). A stop is only ever entered by ARRIVING at it, so a refusal that
            -- left the party standing on the marker would be work they could not walk back into.
            game.map:retreatFromEncounter()
        end
    end)
end

-- Engaging an encounter. Combat kinds (combat / elite / objective) drop into the
-- battle arena; the non-combat kinds (town / treasure) keep the simple modal.
--
-- `opts.errandAnswered` is set by the second call askErrand makes below, once a house's work has been
-- said yes to. Nothing else passes it, and a re-entered tile asks again.
function game:openEncounter(cell, opts)
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
    local objSpec = kind == "objective" and objectiveAt(cell) or nil

    -- A HOUSE'S WORK SAYS WHOSE IT IS BEFORE IT IS FOUGHT, and asks whether to fight it at all.
    --
    -- A floor's ends are all the same marker on the same kind of dead end, and two of them belong to a
    -- house: the job it asked for over its counter, and the posting that opens a house with no door
    -- yet. Neither ever said so out loud. Walking into the second of those meant fighting a siege for a
    -- quartermaster the company had never met and finding out what it had been for from a shelf that
    -- moved the next time they were in town (models/errand.lua's Errand.posting).
    --
    -- ONLY UNDERGROUND. The seam is the descent's -- an errand is seated on a floor and nowhere else --
    -- and a scripted leg's objective is not a thing anybody may decline: the prologue's flight has no
    -- answer for a refusal, and would sit on the map with nothing left to do.
    -- THE CIRCLE'S GATE. Her stair is barred until this circle's own condition is met
    -- (models/descent.lua's Descent.gateState), and walking onto it while it holds says what is holding
    -- it rather than refusing silently. The cell is left uncleared, so the marker stays and the company
    -- can come back once the condition is answered.
    --
    -- Asked only of the STAIR: a floor carries several ends and the gate belongs to exactly one of them.
    -- `wardFor` and `questId` are what tell the others apart.
    if game.descent and objSpec and not objSpec.questId and not objSpec.wardFor then
        local st = game:stairGate()
        if st and not st.met then
            -- A TOLL IS THE ONE GATE THE PLAYER CAN ANSWER ON THE SPOT, so it is asked rather than
            -- reported: the stair takes a share of the mule, and handing it over is a decision made in
            -- front of the price. Every other gate is a fact about the floor and can only be told.
            local carrying = Mule.load(game.player, game.descent)
            local due = Descent.tollFor(st.sin, carrying)
            if st.kind == "toll" and due > 0 then
                game.activePanel = Choice.new({
                    title = "The Stair Takes Its Share",
                    prompt = "She counts what you are carrying and names her price: " .. due ..
                        (due == 1 and " find" or " finds") .. " of the " .. carrying .. " on the mule.",
                    options = {
                        { label = "Pay", desc = "Hand it over and go down.",
                          accent = { 0.86, 0.66, 0.30 },
                          cb = function()
                              game.activePanel = nil
                              game:payToll(due)
                          end },
                        { label = "Refuse", desc = "Keep the lot. The stair stays shut.",
                          accent = { 0.88, 0.45, 0.33 },
                          cb = function() game.activePanel = nil end },
                    },
                    onClose = function() game.activePanel = nil end,
                })
                return
            end
            local said = st.label or "The way down is barred"
            if st.kind == "toll" then
                said = said .. " -- and you carry nothing she wants"
            elseif st.need and st.need > 0 and st.kind ~= "ward" then
                said = said .. "  (" .. (st.have or 0) .. " of " .. st.need .. ")"
            end
            game:pushToast(said)
            return
        end
    end

    local posting = game.descent and objSpec and Errand.posting(game.player, objSpec.questId)
    -- ...unless the doorway already asked (game:askErrandAtDoor). On a board of rooms the question is
    -- put on the threshold, and a company that answered yes there has answered; asking again on the
    -- marker two tiles later would be the same house introducing itself twice.
    if posting and not (opts and opts.errandAnswered) and not cell.errandAnswered then
        game:askErrand(cell, posting)
        return
    end

    if objSpec and objSpec.meet then
        cell.cleared = true
        game.complete = true
        local function finish()
            if game.onComplete then
                game.onComplete()
                return
            end
            -- A DESCENT floor's stair. The leg is over but the RUN is not, and neither is the floor:
            -- the landing credits the circle, deals what the guardian was carrying, and opens the way
            -- down as a tile to walk back to. Placed above the board-quest payout rather than inside it
            -- so a descent never touches Quest.complete, which has no floor to complete.
            if game.descent then
                game:openLanding(cell)
                return
            end
            -- A `meet` objective pays exactly as a fought one does.
            game.reward = game:payObjective(cell, nil)
            -- ...and leaves the day open if the ground still has work on it. A meeting is a piece of
            -- work like any other now; only the last one ends the expedition.
            if not game:tripCleared() then
                saveRun()
                return
            end
            game:bankHaul()
            clearRun() -- the day is over; the save below then writes no run to resume
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

    -- A DROPPED PACK WITH SOMETHING STANDING ON IT is a fight like any other, and goes through the
    -- arena on the ordinary path: the same deployment phase, the same relics, the same salvage, the
    -- same wounds. What is different is only what winning pays, which onWin handles below.
    --
    -- Guarded ONLY when the drop carries a cast (see markBodies). A pile left before the guard existed
    -- falls through to the unconditional pickup at the bottom of this function, which is what it was
    -- dropped under.
    local guardedPack = kind == "pack" and cell.encounter.composition ~= nil

    -- ASKED THROUGH THE MODEL rather than restated here, and the reason is the marker. The overworld
    -- draws a shared combat border on every stop that opens the arena (ui/overworld_map.lua's
    -- COMBAT_BORDER), which is a PROMISE about this branch -- so the two have to be one question or the
    -- board eventually advertises a fight that does not happen. The `meet` walk-out returns above this
    -- and Encounter.opensBattle excludes it too, which is the same answer reached twice on purpose.
    if EncounterModel.opensBattle(cell.encounter) then
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
            -- WHAT A WOUNDED BODY FIGHTS UNDER, stamped at spawn beside the relics' own boons because
            -- it is the same kind of thing: a status the unit ARRIVES wearing rather than one anything
            -- on the board applied. Two sources, one seam -- so combat never learns what a wound is
            -- (models/wound.lua's Wound.combatEffects).
            --
            -- Over the whole company for the same reason the relic traits are: a benched member has to
            -- arrive already carrying it when they rotate on.
            local boons = Relic.openingBoons(relicCtx)
            for _, char in ipairs((game.player and game.player.roster) or {}) do
                for _, effect in ipairs(Wound.combatEffects(game.player, char.id)) do
                    boons[#boons + 1] = { char = char, id = effect.id, opts = effect.opts }
                end
            end

            return {
                openingBoons = boons,
                -- Over the whole COMPANY, not just the deployed four: a party-scope relic is worn by
                -- everyone who marched, and a benched member has to arrive already wearing it when they
                -- rotate on. Only frontRow scope narrows, to the line actually put forward.
                relicTraits = Relic.combatTraitsByChar(game.relicState, game.player,
                    game.player and game.player.roster, front or deployed),
                -- THE FLAT STATS the run's relics grant, aggregated once with every stack already
                -- multiplied out (models/relic.lua's base + (n-1) * step). One bag for the whole
                -- company -- a relic is worn by everyone who marched -- so unlike relicTraits it needs
                -- no per-char map, and battle setup folds it beside the meal.
                relicBonus = {
                    bonus = Relic.statBonus(game.relicState),
                    maxBonus = Relic.maxBonus(game.relicState),
                    resist = Relic.resistBonus(game.relicState),
                    -- Per-relic rows for the damage-breakdown tooltip, resolved here rather than on
                    -- hover: that tooltip reads flatStat every frame the mouse is over a body.
                    parts = Relic.bonusParts(game.relicState),
                    -- THE RARE TIER'S INVERSIONS, with every magnitude already laddered. Resolved once
                    -- here so no hot path -- a stat read, a damage preview, a move overlay -- ever walks
                    -- the shelf. Nil for a run carrying no rare.
                    rules = Relic.resolvedRules(game.relicState),
                },
            }
        end

        -- A side-fight's takings, granted. THE single seam for them, and it is reached two ways now:
        -- from the battle summary's Continue when the fight was played, and from the walk-off below
        -- when it was not. Both panels only DISPLAY the spoils; this is where they land, which is what
        -- keeps them from ever being counted twice or paid differently depending on how the fight was
        -- resolved. (The objective pays through Quest.complete instead -- see onWin.)
        local function grantSideSpoils(spoils)
            -- THE MULE'S TRIP IS COUNTED IN WON FIGHTS (models/mule.lua's Mule.TRIP), and this is one
            -- of the two places a win is resolved -- the other is the objective branch below, which
            -- pays through Quest.complete instead and so never reaches here. Ticked BEFORE the grant,
            -- so the fight that brings the mule home can also load it: a trip that ended on the walk
            -- back would strand the takings of the fight that ended it.
            --
            -- Outside a descent this is a no-op on a nil run, which is what keeps the campaign's
            -- roadside fights from having an opinion about a mule they do not have.
            Mule.noteFight(game.descent)
            if spoils then
                if (spoils.gold or 0) > 0 then Player.addGold(game.player, spoils.gold) end
                -- THE RUN'S OWN COIN (models/scrip.lua). What a rolled fight pays, weightless, spendable
                -- at the Merchant and the Crossroads and by the money kit, and gone the moment the
                -- company reaches the surface. It does not ride the mule and cannot: there is nothing
                -- to carry.
                if (spoils.scrip or 0) > 0 then Scrip.add(game.player, spoils.scrip) end
                -- WHAT FITS ON THE MULE, and the rest is left where it fell (models/mule.lua).
                --
                -- SPLIT RATHER THAN REFUSED, which is the opposite call to the treasure chest above and
                -- the difference is what the thing IS: a chest is one object with a lid, and a fight's
                -- takings are a pile off several bodies. Refusing the pile outright would mean a company
                -- one slot short walked away from a won fight with nothing, which reads as the game
                -- eating a reward rather than as a bag being full.
                --
                -- Scrip and the salvage below are untouched: neither rides the mule (see Mule's header),
                -- so a full bag never costs the player run coin or forging stock.
                local left = 0
                for _, id in ipairs(spoils.loot or {}) do
                    if Mule.canTake(game.player, 1) then Player.grantItem(game.player, id)
                    else left = left + 1 end
                end
                -- THE VALUABLES AN END LEFT, which DO ride the mule and are the reason it has a cap
                -- worth caring about (models/valuable.lua). Weighed by bulk rather than counted: an idol
                -- is three slots, so a mule with two free refuses it and says so, and the choice of
                -- whether to go home and come back for it is the whole object.
                --
                -- Taken in the order rolled, and a piece that does not fit does not stop the ones behind
                -- it -- a two-slot lamp still goes on after a three-slot idol was refused. Greedy is the
                -- right rule here because the alternative is a packing solver deciding for the player
                -- what their eight slots are worth, which is the decision.
                for _, id in ipairs(spoils.valuables or {}) do
                    if Mule.canTakeItem(game.player, id) then Player.grantItem(game.player, id)
                    else left = left + 1 end
                end
                -- ...and the unread find, on the rare stop that paid one (models/identify.lua). Granted
                -- through Identify.grant rather than Player.grantItem: the piece goes into the stash as a
                -- HUSK, and the id it is really built on is the one thing the player has not bought yet.
                for _, find in ipairs(spoils.sealed or {}) do
                    if Mule.canTake(game.player, 1) then Identify.grant(game.player, find.id, find.floor)
                    else left = left + 1 end
                end
                -- SAID OUT LOUD, always. A reward that silently fails to arrive reads as a bug however
                -- correct the bookkeeping is -- the same rule the errand's spent first-clear bonus is
                -- announced under.
                if left > 0 then
                    game:pushToast(left .. (left == 1 and " find left behind" or " finds left behind") ..
                        " -- the mule cannot carry it")
                end
                -- The salvage floor: every won fight leaves forging stock behind, so a stop that
                -- rolled no loot is still worth having stopped at (models/spoils.lua). Banked straight
                -- to the player rather than onto the run's cache haul, because a cleared fight does not
                -- un-clear -- there is nothing here for the objective's double-payout guard to protect.
                for id, n in pairs(spoils.materials or {}) do
                    Player.addMaterial(game.player, id, n)
                end
                Player.save()
            end

            -- A THIN CHANCE OF A CROSSING TOKEN, on any won fight (models/voucher.lua's FIGHT_CHANCE).
            --
            -- HERE rather than at the three call sites, because this is the one seam every won fight
            -- passes through -- a road fight, a fight walked over without watching, and the floor's own
            -- guardian all pay through this call, which is exactly the property the salvage above
            -- relies on. Putting the roll anywhere else would give one of those three a different
            -- chance to the other two, and nothing would report it.
            --
            -- A won fight used to roll a thin chance of a crossing token here. The Crossing is retired
            -- and a companion is met at their house's opener instead, so a fight pays its spoils and
            -- nothing else.

            -- Companion abilities react to the win (Amana heals, Ren distils a dose, Rowan banks a
            -- vigil, Clem takes her cut, Gyeom studies), then the relics do too (Pilgrim's Coin pays,
            -- Alms Bowl heals, a Vice bites). Save so their effects persist.
            fireAbility("encounterCleared", { cell = cell, spoils = spoils })
            fireRelics("encounterCleared", { cell = cell, spoils = spoils })

            -- LEVEL-UPS, in every mode. This used to be gated on `game.descent`, because a campaign
            -- roster levelled off prestige and the experience combat banked was a counter nobody read.
            -- Prestige no longer sets anybody's level (models/player.lua), so the gate is gone and this
            -- is now the single place in the game where experience becomes a level.
            --
            -- This seam rather than the battle's own end because it is ALREADY the single point every
            -- won fight passes through, side-fight, stair guardian and objective alike (see the header
            -- above), so there is no second place that could forget. Growth.resolve is idempotent, so a
            -- body that earned nothing this fight costs a comparison.
            --
            -- The bench's share was already awarded where the fight ended (states/battle.lua's
            -- finishBattle, the only place that knows who stood on the board); this turns everybody's
            -- banked experience into levels.
            if game.player then
                -- ...on the one curve there is. It used to branch on `game.descent` for a steeper
                -- descent-only ladder, which meant every seam standing outside a run -- Act 0's whole
                -- tutorial included -- quietly cashed out on the cheap one (models/experience.lua).
                for _, up in ipairs(Experience.resolveParty(game.player.roster)) do
                    game:pushToast((up.char.name or up.char.id) .. " reaches level " .. up.toLevel)
                end

                -- ...AND WHAT THAT OPENED ON THE COUNTER. A shelf rung is a class level now
                -- (Quest.shelfRung), and a class level rises out of ordinary swinging rather
                -- than out of any event a seam could wrap -- so the market is asked here, at
                -- the same single point every won fight passes through, whether the fighting
                -- crossed a rung. Marks the rows; the dot on the door falls out of that
                -- (Vendor.hasMarkedStock) and goes out when the shelf is read.
                local opened = Market.markOpened(game.player)
                if opened then
                    game:pushToast(#opened.items .. (#opened.items == 1 and " new ware" or " new wares")
                        .. " at the market")
                end
            end

            if game.player then Player.save() end
        end

        -- THE PILE, HANDED BACK. Whatever was standing over the company's own dropped kit is down, so
        -- the kit is theirs again -- into the STASH, where every other find on this floor lands, rather
        -- than back into the grids it came out of. Which body carries what is a decision, and the
        -- Loadout is where decisions are taken.
        --
        -- ITS OWN SEAM, beside grantSideSpoils and for the same reason that one is one: a pack fight can
        -- be PLAYED or WALKED OFF (Muster.WALK_OVER), and a walk-off that resolved the guard without
        -- handing the bag over would leave the player standing on a cleared tile with their kit still
        -- on it. Both paths call this; there is no second copy to forget.
        --
        -- The salvage, the experience and the thin chance of a crossing token are paid by grantSideSpoils
        -- like any other won fight: beating somebody for your own bag back is still beating somebody.
        local function takeGuardedPack()
            if not guardedPack then return end
            local drop = cell.encounter and cell.encounter.drop
            local items = drop and game.descent and Descent.takePack(game.descent, drop, game.player)
            for _, item in ipairs(items or {}) do Player.addToStash(game.player, item) end
            -- The entry is off the run, so this clears the marker rather than re-drawing it. Every
            -- other pile still lying on this floor is re-marked in the same pass.
            game:markBodies()
            if items then
                game:pushToast("You take back what you dropped  (" .. #items ..
                    (#items == 1 and " item)" or " items)"))
            end
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
        -- THE FIGHT DOES NOT LEAVE THE MAP. states/battle.lua is entered as a SUB-STATE of this one
        -- rather than switched to: this state stays `State.current`, keeps its grid, its camera and the
        -- chamber the company is standing in, and forwards update/draw/input to the battle while one is
        -- running (see game.update and the callbacks at the foot of this file).
        --
        -- It costs almost nothing because battle.lua never switched anything itself -- it has always
        -- handed control back through `onWin` / `onLoss`, and the callbacks below have always resumed by
        -- assigning State.current rather than switching, precisely so the map would survive the fight.
        -- The state machine was the only thing insisting a fight was somewhere else.
        local Battle = require("states.battle")

        -- WHERE THE BOARD GOES: centred, as it always was before the rooms.
        --
        -- It was PINNED for a stretch, onto the chamber the fight was found in, and the reason was a
        -- coincidence rather than a principle: a vaults chamber and a battle board were both eight tiles
        -- at 64 logical pixels, so handing over the room's top-left made them one rectangle instead of
        -- two that happened to be the same size.
        --
        -- A place is one cell. Pinning an 8x8 board to a 101-pixel cell hangs half the arena off the
        -- side of the screen, which is what it did the first time this was run -- and centring the board
        -- ON the cell would only move the clipping to the floors where the fight is near an edge. The
        -- continuity it bought is real and it is bought elsewhere now: the fight opens over the floor it
        -- was found on, scrimmed rather than covered, with the company deploying on the side they walked
        -- in from (ui/overworld_map.lua's :entryEdge).
        game.battle = Battle
        Battle.enter(Battle, {
            hosted = true, -- fought on this screen: battle.draw scrims rather than covers. See above.
            encounter = cell.encounter,
            biome = mp.biome,
            -- THE SIDE THE COMPANY CAME IN ON, so they deploy where they walked in from.
            --
            -- This was read off the geometry -- which wall of the chamber the doorway was in
            -- (Overworld:entryEdge) -- because on a board of rooms the door was a fact about the room.
            -- A place has no doorway: the only thing that decides which side you arrived on is the step
            -- that brought you, so the map widget records it and the arena reads it (Arena's
            -- defaultZoneBlock). Simpler, and exactly as true.
            entry = game.map and game.map:entryEdge() or nil,
            quest = game.quest,
            -- The objective's own scene, played over the board with the general standing on it
            -- (states/battle.lua's openingConversation). This is the ONLY seam an antagonist can
            -- speak from: `intro` plays over the hub before the party is even picked, and by the
            -- time `outro` runs the target of an `assassinate` is dead.
            opening = objSpec and objSpec.opening or nil,
            -- WHICH end this is, resolved from the tile rather than looked up from the run: the
            -- composition, the escorts, the win condition and the board all come off this one spec
            -- (models/encounter_battle.lua), and a ground carrying three quests has three of them.
            objective = objSpec,
            -- WHAT WINNING THIS END PAYS, for the victory screen to name (game:previewObjectiveReward).
            --
            -- A FUNCTION rather than a value, because the answer is not knowable yet. It turns on what the
            -- player owns, and a fight is exactly the beat that can move that -- a thief lifting the
            -- guardian's own piece mid-battle would make a value read at launch name a thing already in
            -- the stash. Called once, when the summary is built.
            --
            -- AND ONLY FOR AN END. Every stop on a floor came through here with this callback attached,
            -- and `objSpec` is nil for all of them but the objective -- which Descent.objectiveReward
            -- reads as "the stair guardian" by contract (tests/objective_reward_spec.lua asks it that
            -- way). So a road fight three tiles from the stair was asking what the FLOOR pays and being
            -- told the guardian's own piece: the victory screen named the Beggar's Bowl after every win
            -- on a lust floor, plus the circle's tokens under it, while the grant -- which hangs off the
            -- objective alone (game:openLanding) -- never handed one over. A reward named and never paid,
            -- once per fight. Gated on the CELL rather than on `objSpec` being non-nil, because "is this
            -- the end" is a fact about the stop, and objectiveAt's fallback is allowed to come back empty.
            objectiveReward = kind == "objective"
                and function() return game:previewObjectiveReward(objSpec) end or nil,
            day = game.day,
            -- Who is still standing when the last door opens; read only by the finale's composition
            -- (data/quests/quest_the_gate_below.lua) and nil-safe everywhere else.
            generalsStanding = Calendar.generalsStanding(game.player),
            -- What this run stands to lose here, named on the defeat panel (ui/panels/battle_summary).
            -- Read at launch rather than at the loss, because by then the rollback has already put it
            -- back and there would be nothing left to count.
            lostHaul = game:haulPhrase(),
            -- What the defeat panel's button is called, and it has to name what the button DOES. It said
            -- "End the Run", which was accurate when a wipe ended everything and is now the one thing a
            -- wipe does not do: onLoss below drops the pack, wounds the company and wakes them at the
            -- Gate with their levels, their mapped floors and the stair to floor N still standing. A
            -- player reads this line at the worst moment of a run, and it was telling them they had lost
            -- fifteen floors they had not lost.
            lossLabel = game.descent and "Wake at the Gate" or nil,
            -- ...and what that same exit is called when the company is still standing. A rout is not a
            -- wipe -- it falls back onto the floor it came from with every find it made -- so a button
            -- reading "Wake at the Gate" would be naming a price this exit does not charge. Which of the
            -- two is shown is decided by the board at the moment the fight is decided, since only it knows
            -- whether anybody was left (states/battle.lua's lose stamps `battle.routed`).
            routedLabel = game.descent and "Fall Back" or nil,
            -- The sponsor's stock, for the salvage every won fight leaves behind (models/spoils.lua).
            -- Same value the map's caches were laid out with, so a run's fights and its dead ends pay
            -- into the same house.
            -- ...and an OBJECTIVE fight salvages in the house that posted it rather than in the run's:
            -- a ground can carry three houses' work, and the piece of work you took should pay in the
            -- stock of whoever asked for it.
            houseMaterial = (objSpec and objSpec.houseMaterial) or game.houseMaterial,
            -- This fight's authored difficulty FLOOR: the level its enemies may never drop below,
            -- however green the company walking in is. Scaling takes over above it (models/growth.lua,
            -- Growth.combatantLevel), so a floor stops a beat being walked on a replay or in New Game+
            -- without freezing it at a level the party has long outgrown. Read off the objective first,
            -- then the quest, so a line can set one floor for all its fights and a single beat can raise it.
            floorLevel = (objSpec and objSpec.floorLevel)
                or (game.quest and game.quest.floorLevel) or nil,
            -- ...and the level the world down here fights at, when the mode keeps a clock of its own. A
            -- descent hardens on DEPTH rather than on the calendar (Descent.dangerLevel); absent it,
            -- states/battle.lua falls back to the day, which is the campaign's answer and unchanged.
            enemyLevel = game.quest and game.quest.dangerLevel or nil,
            -- WHO WALKED DOWN THE STAIR, which underground is four and not the roster (Descent.party).
            -- The expedition is picked at the Gate and fixed for the run, so the deployment phase has
            -- nothing left to choose: it places the four it is given, and only their ARRANGEMENT is
            -- still a question. There is no bench down here, which is the premise models/wound.lua is
            -- priced against -- and, since the Quest Board went (models/quest.lua), there is no bench
            -- anywhere: the phase itself no longer has one to put anybody on (docs/deployment.md).
            --
            -- The roster fallback below is for a caller with no run behind it -- a probe, a debug hand.
            -- No live path reaches it: a quest carries its run (game.descent = quest.descent), and every
            -- quest is a floor of one.
            party = (game.descent and Descent.party(game.descent, game.player))
                or (game.player and game.player.roster) or {},
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

                -- THE BREACH, BEATEN. What came up the stair was the Hollow Crown and whichever
                -- generals were still standing behind it (models/descent.lua's breachComposition), so
                -- putting it down IS beating the game -- met three floors up in a corridor instead of
                -- on its own ground, because the company let the floors below fill.
                --
                -- IT ENDS EXACTLY WHERE THE BOTTOM ENDS: finishCampaign banks the win (and opens the
                -- shuffle for the next descent), the run is cleared, and the credits roll with New
                -- Game+ offered. Two roads, one ending, and neither of them is a date on a calendar.
                --
                -- The tile is handed back its stair first. Nothing walks off this board -- the credits
                -- are the next screen -- but a floor is snapshotted by several paths and a cell left
                -- carrying a spent breach would come back as a fight with no way out behind it.
                if cell.encounter and cell.encounter.breach then
                    cell.encounter = cell.wasAscent or cell.encounter
                    cell.wasAscent = nil
                    cell.cleared = false
                    Player.finishCampaign(game.player)
                    clearRun()
                    if game.player then game.player.descentRun = nil end
                    Player.save()
                    State.switch(require("states.credits"), { newGamePlus = true })
                    return
                end

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

                        -- BACK ONTO THE BOARD, and it has to be done by hand here for the same reason
                        -- the won-road-fight branch below does it: the battle state is still current,
                        -- frozen on its last frame, and returning to the map skips game.enter. Every
                        -- exit from this branch except the two that leave the mode entirely now lands
                        -- the player on the floor -- an errand paid, or a stair opened with a boon
                        -- sitting over it -- so the restore is here, above the fork, rather than
                        -- repeated down each arm and forgotten on one.
                        require("models.sound").music("music.overworld")
                        game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
                        game:refreshMuster() -- the fight was paid for in health and potions; re-rate
                        -- ...and the objective is the other won fight (see grantSideSpoils, which this
                        -- path deliberately does not reach). A stair guardian is still a fight, and a
                        -- mule sent out before one should come home no later for it having been hard.
                        Mule.noteFight(game.descent)

                        -- AN ERRAND FINISHED. A floor carries the stair AND whatever a house asked for
                        -- down here, each on its own end (models/descent.lua's floorObjectives), so the
                        -- objective just cleared is only the stair if it says so. An errand's spec is
                        -- stamped with the quest it belongs to; clearing it writes the shelf's own
                        -- ledger, which is what opens the next rung of that house's stock
                        -- (models/errand.lua, then Quest.sponsorProgress -> Vendor.stock).
                        --
                        -- Returns rather than falling through to the landing: a floor is not finished
                        -- because a piece of side work on it is, and the stair is still standing.
                        local errandId = objSpec and objSpec.questId
                        if errandId and Errand.complete(game.player, errandId) then
                            local def = require("models.quest").defs[errandId]
                            -- Paid here rather than through Quest.complete, which is the campaign's
                            -- payout seam and knows about days, standing and a board this mode does not
                            -- have. What an errand owes is its purse and its goods.
                            if def then
                                -- THE PURSE IS PAID ONCE, TO A COMPANY THAT DID NOT HAVE TO COME BACK.
                                -- Losing this fight spends the first-clear bonus for good
                                -- (models/errand.lua's Errand.fail); everything else an errand owes --
                                -- the goods, the rung, the discipline behind it, the outro -- lands on
                                -- whichever attempt finishes the work. Same condition the victory
                                -- screen's card is drawn from (Descent.objectiveReward), asked through
                                -- the same function so the two cannot drift.
                                if (def.rewardGold or 0) > 0
                                    and not Errand.failedOnce(game.player, errandId) then
                                    Player.addGold(game.player, def.rewardGold)
                                end
                                for _, itemId in ipairs(def.rewardItems or {}) do
                                    Player.grantItem(game.player, itemId)
                                end
                                -- WHO IT WAS FOR, and no longer WHAT IT PAID. The purse and the goods
                                -- above were announced by this toast and by nothing else, so a house's
                                -- work paid out in the corner of the map while the victory screen next to
                                -- it showed one ingot of salvage. Both are cards on that screen now
                                -- (game:previewObjectiveReward); this keeps the half a toast is good at,
                                -- which is naming the house whose ledger just moved.
                                game:pushToast("Done for " ..
                                    ((Vendor.get(def.sponsor) or {}).name or "the house"))
                                if def.outro then require("models.conversation").play(def.outro) end
                            end
                            Player.save()
                            saveRun()
                            return
                        end

                        -- THE BOTTOM, AND THE ONLY WIN THE MODE HAS. Clearing the last floor's
                        -- objective is not another landing -- there is nothing below it to be asked
                        -- about, and since the landing stopped offering an exit this is the one place a
                        -- descent can end on the player's terms. Every other ending is a wipe or a
                        -- walking away.
                        if game.quest and game.quest.endsDescent then
                            -- THE DEMON LORD IS DOWN, AND THE SAVE REMEMBERS IT.
                            --
                            -- WHAT IT OPENS is the shuffle: every descent after this one deals its own
                            -- order of the seven circles instead of walking Dante's
                            -- (models/descent.lua's Descent.sinOrder). Written BEFORE clearRun, so the
                            -- next run opened off this player is already the shuffled kind.
                            Player.finishCampaign(game.player)
                            clearRun()
                            if game.player then game.player.descentRun = nil end
                            Player.save()

                            -- AND THIS IS THE END OF THE GAME, not the end of a mode.
                            --
                            -- It used to fall through to the descent's own terminal and land at the hub,
                            -- on the reasoning that the credits belonged to the board's finale
                            -- (`endsCampaign`, data/quests/quest_the_gate_below.lua) and this stair had
                            -- nothing to do with it. The board is retired and that quest is deleted, so
                            -- that reasoning outlived both of its terms: the note saying the descent "is
                            -- a separate mode now" sat forty lines from states/gate.lua saying there is
                            -- ONE company and ONE save and the descent IS the game.
                            --
                            -- So the Crown rolls the credits, and the roll carries the game-icons.net
                            -- attribution that CC BY 3.0 requires -- which was reachable only through a
                            -- quest nobody could post, and is now reachable by finishing the game.
                            --
                            -- New Game+ is offered because the run is, by definition, over.
                            -- Player.finishCampaign above banks the win itself: watching the roll and
                            -- going back to the menu still beat the game, and `ngPlus` counts only the
                            -- separate act of choosing to play it again.
                            State.switch(require("states.credits"), { newGamePlus = true })
                            return
                        end
                        game:openLanding(cell)
                        return
                    end
                    if game.player and spoils and (spoils.gold or 0) > 0 then
                        Player.addGold(game.player, spoils.gold)
                    end
                    -- The skim and the bounty an objective fight earned, which are scrip like every
                    -- other coin taken off a body mid-fight (models/encounter_battle.lua). Paid here
                    -- rather than through Quest.complete for the reason the salvage is not: they belong
                    -- to the FIGHT, not to the piece of work, and a run that ends on this stair is about
                    -- to burn them anyway (Scrip.clear) -- which is the honest outcome for coin earned
                    -- on the last swing of an expedition and never spent.
                    if game.player and spoils and (spoils.scrip or 0) > 0 then
                        Scrip.add(game.player, spoils.scrip)
                    end
                    -- ...AND WHAT THE GENERAL WAS STANDING ON. The valuables an end leaves are the
                    -- campaign's actual income (models/valuable.lua), so the richest stop in a run pays
                    -- into the purse that matters -- and it pays in objects, which means the mule has to
                    -- have room for them. A company that walks into the last fight with a full bag is
                    -- making that choice with the same information as everywhere else.
                    if game.player and spoils then
                        local dropped = 0
                        for _, id in ipairs(spoils.valuables or {}) do
                            if Mule.canTakeItem(game.player, id) then
                                Player.grantItem(game.player, id)
                            else dropped = dropped + 1 end
                        end
                        if dropped > 0 then
                            game:pushToast(dropped ..
                                (dropped == 1 and " valuable left behind" or " valuables left behind") ..
                                "  --  the mule cannot carry it")
                        end
                    end
                    -- The objective fight's OWN salvage (models/spoils.lua) is paid through the quest
                    -- rather than granted here, so it inherits Quest.complete's double-payout guard and
                    -- is named in the reward table with the rest of the materials instead of arriving
                    -- as a silent number. The battle summary only DISPLAYED it a moment ago; this is
                    -- the grant. The run's CACHE haul is no longer folded in: that belongs to the day
                    -- rather than to this piece of work, and it banks at the exit (game:bankHaul) --
                    -- otherwise the first of three objectives would bank it and the second would bank
                    -- whatever had been picked up since, under a different quest's name.
                    local salvage = {}
                    for id, n in pairs(spoils and spoils.materials or {}) do salvage[id] = n end

                    -- THE PAYOUT SEAM, once per piece of work: gold, the relic, the companion, and the
                    -- sponsor's standing, which is what opens their shelf.
                    local doneQuest
                    game.reward, doneQuest = game:payObjective(cell, salvage)
                    -- The sting that marks a piece of work actually ending.
                    require("models.sound").play("quest.complete")

                    -- IS THE DAY OVER? Only if the ground has nothing left on it. A trip carries every
                    -- quest that could be run here (models/quest.lua's Quest.trip), so clearing one
                    -- leaves the others standing and the run goes back to the map -- after the outro,
                    -- which still plays over the frozen final frame where it always did.
                    --
                    -- The campaign's ending is the exception and takes itself home regardless: there is
                    -- no map to walk back onto once the credits have rolled.
                    local staying = not game:tripCleared()
                        and not (doneQuest and doneQuest.endsCampaign)
                    if not staying then
                        -- THIS IS THE EXTRACTION. Everything the run found has been in the stash all
                        -- along -- live, equippable, spendable -- but provisional: the entry snapshot
                        -- on the run could put it all back. Dropping the run here drops that snapshot
                        -- and the finds become permanent, the day's ore and supper with them.
                        game:bankHaul()
                        clearRun()
                    else
                        saveRun() -- the box is ticked; a resume must come back with it ticked
                    end
                    -- An outro scene plays over the (frozen) final battle frame, then the reward panel
                    -- opens over the board, and only then does the run go anywhere. No outro -> the
                    -- panel comes straight up.
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
                    -- ALL THREE ARE READ OFF THE QUEST THAT WAS JUST CLEARED, not off the run: a day on
                    -- one ground can carry three quests and only one of them has been finished here.
                    local followUp = doneQuest and doneQuest.followUp
                    local epilogue = doneQuest and doneQuest.epilogue
                    -- WHERE THE REPORT GOES ONCE THE SCENES HAVE PLAYED. Split out from goNext so the
                    -- reward panel can sit between the two.
                    local function route()
                        -- The campaign's last quest does not go home. `endsCampaign` is carried on the
                        -- quest (data/quests/quest_the_gate_below.lua) rather than a quest id compared here,
                        -- so this state never learns which file is the ending and a second one costs
                        -- no engine edit. New Game+ is offered because the run is, by definition, over.
                        if doneQuest and doneQuest.endsCampaign then
                            -- Banked HERE, not on the credits screen, because finishing the campaign
                            -- and choosing to play it again are different acts and only the first one
                            -- is what the post-game is owed to. `ngPlus` records the second and is
                            -- incremented from the credits' New Game+ button; a player who watches the
                            -- roll and goes back to the menu has still beaten the game, and the Descent
                            -- has to open for them. See Player.finishCampaign.
                            Player.finishCampaign(game.player)
                            State.switch(require("states.credits"), { newGamePlus = true })
                        elseif followUp then
                            -- A follow-up leg is its own traversal and ends at the city, so taking one
                            -- ENDS THE DAY even if the ground still had work on it. Only the debut uses
                            -- it, and the debut is alone on its ground; a quest that ever shares a
                            -- ground with others and wants a follow-up would be giving up the rest of
                            -- the day to have it, which is at least a decision the author can see.
                            State.switch(require("states.game"), followUp, game.day, game.player,
                                function() State.switch(require("states.hub")) end)
                        elseif staying then
                            -- BACK TO THE GROUND. The day is not over -- the other ends are still out
                            -- there -- so this returns to the map exactly as a won road fight does:
                            -- re-rate the company against what is left, restore the overworld bed the
                            -- battle swapped out, and resume without re-running enter (which would roll
                            -- a fresh board and lose the run).
                            game:refreshMuster()
                            require("models.sound").music("music.overworld")
                            game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
                        else
                            State.switch(require("states.hub"))
                        end
                    end

                    -- THE REPORT IS GIVEN WHERE THE WORK WAS DONE. It used to be handed to the hub
                    -- (`pendingSummary`), which opened the Company Advancement overlay on the way in --
                    -- right while a day was one piece of work and the walk home was the next thing that
                    -- happened. A day can clear three now, and three reports queued behind a walk home
                    -- would arrive as a stack of panels about fights the player finished an hour ago.
                    -- So it opens here, over the frozen board, as part of the victory: the fight, its
                    -- outro, then what it paid.
                    --
                    -- The `meet` objective keeps the old route deliberately -- it has no victory screen
                    -- to be part of, being a scene walked into rather than a fight won.
                    local function goNext()
                        if not (game.player and game.reward) then route() return end
                        -- The map has to be back on screen for the panel to sit over: the battle state
                        -- is still current at this point, frozen on its last frame.
                        require("models.sound").music("music.overworld")
                        game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
                        game.activePanel = require("ui.panels.advancement").new({
                            reward = game.reward,
                            onClose = function()
                                game.activePanel = nil
                                route()
                            end,
                        })
                    end

                    -- The scene chain: outro, then epilogue, then goNext. Either may be absent. The
                    -- outro belongs to the QUEST that was cleared, not to the day.
                    local function playEpilogue()
                        if epilogue then
                            require("models.conversation").play(epilogue, goNext)
                        else
                            goNext()
                        end
                    end
                    if doneQuest and doneQuest.outro then
                        require("models.conversation").play(doneQuest.outro, playEpilogue, nil,
                            (followUp or epilogue) and { deferJoins = true } or nil)
                    else
                        playEpilogue()
                    end
                else
                    -- Ahead of the salvage below because it is the thing this fight was FOR, and the
                    -- toasts should say so in that order.
                    takeGuardedPack()
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
                    game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
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
                game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
            end or nil,
            -- "Return to Hub": give the fight up and fail the quest. Offered only once there is a hub to
            -- return to -- the prologue's flight leg (game.tutorial) has none yet, so there the panel
            -- shows Try Again alone.
            onLoss = (not game.tutorial) and function()
                -- THE STAIR IS GIVEN BACK BEFORE ANYTHING ELSE HAPPENS, and it has to be here rather
                -- than only on the winning side. The breach turns the way-up tile into a fight for the
                -- length of that fight (see the ascent branch); losing it snapshots the floor into the
                -- company's map book a dozen lines below, and a tile stored as a spent breach would come
                -- back on the recovery dive as an encounter with no stair behind it -- a floor with no
                -- way out, written by the one path that was always going to run.
                --
                -- The tally is untouched by this. It is still full, so walking back onto the tile asks
                -- the same question again, which is correct: what changed is not the rift, it is that
                -- the company lost. The way down is the way out of it.
                if cell.encounter and cell.encounter.breach then
                    cell.encounter = cell.wasAscent or cell.encounter
                    cell.wasAscent = nil
                    cell.cleared = false
                end

                -- A COMPANY THAT IS STILL STANDING WALKS BACK ONTO THE FLOOR. It did not die; it lost.
                --
                -- FOUR THINGS END A FIGHT THE PARTY IS STILL ON ITS FEET FOR -- an escort whose charge was
                -- killed, a defend whose charge was, a control run out on the clock, and Fall Back -- and
                -- every one of them used to be answered with the WIPE below: pack dropped on the floor,
                -- the run's coin and ore gone, the company woken at the Gate. That is charging a rout what
                -- a destruction costs, and Descent.climbOut's note says exactly why it must not happen --
                -- a wipe already takes the haul, the purse and a wound on every head, and charging the
                -- failure twice is the thing this design is built not to do.
                --
                -- WHAT A ROUT COSTS INSTEAD IS THE STATE THEY ARE IN, and that is the whole of it. There
                -- is no rollback here and no Player.restore: whoever walked off that board at four health
                -- is standing on the map at four health, the potions they drank are drunk, and
                -- Combat.spentParty has already written a wound for everybody the fight emptied
                -- (states/battle.lua's lose). The second attempt is made by the company the first one left
                -- behind, which is a real price and the only one that needs no bookkeeping to collect.
                --
                -- THE END IS NOT SPENT. `cell.cleared` is deliberately untouched, so the marker is still
                -- standing and walking back onto it starts the same fight. Moving the posting was tried on
                -- paper and thrown out: a reseat has to stay inside the circle the work was met in (the
                -- rung it opens is balanced for that circle), which means seating onto floors already in
                -- the map book, which means a second placement rule -- all of it to relocate a fight the
                -- player can simply walk back to. What a house's work loses is its FIRST-CLEAR BONUS
                -- instead (models/errand.lua's Errand.fail): the purse is paid once, to a company that did
                -- not have to come back. The goods, the shelf rung, the discipline and the outro all still
                -- land on whichever attempt finishes it.
                --
                -- CAMPAIGN GROUND IS UNCHANGED and falls through to wipeRun below. There are no errands up
                -- there, a quest is a day rather than a floor, and a lost day is the shape that mode has
                -- always had.
                if game.descent and require("states.battle").routed then
                    local errandId = objSpec and objSpec.questId
                    -- Errand.fail answers true on the FIRST failure only, which is exactly when there is
                    -- news: a bonus spent is spent once. Said here, beside the wound toasts, because it
                    -- has to be told at the moment it is lost -- a purse that quietly fails to arrive an
                    -- hour later reads as a bug rather than as a price. The work itself is untouched and
                    -- the line says so, so the player is not sent looking for a marker that has moved.
                    if errandId and Errand.fail(game.player, errandId) then
                        local def = Quest.defs[errandId]
                        game:pushToast(((def and def.name) or "The work") ..
                            " still stands - the first-clear bonus is spent")
                    end
                    -- Before the return, and the ordering is the same one the wipe branch keeps: the
                    -- ledger moves while the battle's list of who fell is still the last one written.
                    game:inflictWounds()
                    -- The tutorial's Try Again path with the rewind deleted -- drop the defeat grey and
                    -- the low-HP vignette the loss froze on screen, step the token back onto the tile it
                    -- came from, and resume THIS overworld through State.current so game.enter does not
                    -- re-run and roll the board out from under the party.
                    ScreenFx.reset()
                    game.activePanel = nil
                    if game.map and game.map.retreatFromEncounter then
                        game.map:retreatFromEncounter()
                    end
                    require("models.sound").music("music.overworld")
                    game:refreshMuster() -- the fight was paid for in health and potions; re-rate
                    -- BOTH saves, because a rout moves both halves: the board (a token stepped back off
                    -- the marker) and the profile (wounds, and a bonus that is now spent). This is the
                    -- exit that would have been missing them -- of the ways out of a fight, the losing one
                    -- is where the bookkeeping goes unwritten.
                    saveRun()
                    Player.save()
                    game.battle = nil -- the fight is over; the map has input again (it never stopped being the state)
                    return
                end

                -- A DESCENT WIPE LEAVES THE COMPANY WHERE IT FELL, and does not end the descent.
                --
                -- IT USED TO END EVERYTHING -- the company, the floors, the file -- and that was right
                -- while a run banked nothing and had nowhere to come back to. It has both now (the gate,
                -- models/gate.lua), and the reference the mode is being built against answers a wipe the
                -- same way it answers a single death: the bodies stay down there, you form a NEW party,
                -- and you go and get them. That is the most famous thing about Wizardry and it costs
                -- nothing to have, because the machinery is already here -- a body left on a floor is
                -- exactly what game:buryLost writes, and this writes the whole party at once.
                --
                -- The rollback below is skipped: it exists to hand a campaign company back the gear it
                -- marched in with, and this company is not coming back for its gear -- it is lying on
                -- floor N wearing it, which is the point.
                if game.descent then
                    -- A WIPE DROPS WHAT THE EXPEDITION FOUND AND SENDS THE COMPANY HOME. The bodies
                    -- always come back -- they wake at the temple, whole and wounded -- and what stays
                    -- on the floor is everything they had picked up since they walked down.
                    --
                    -- It is the only thing standing between "climb out" and "die" being the same move.
                    -- Levels, mapped floors and bound relics all survive a wipe; the haul does not,
                    -- until somebody walks back down to the tile. Without it a company that died on
                    -- floor nine would wake, walk back, and have lost nothing but the walk.
                    --
                    -- IT USED TO TAKE THE KIT AS WELL -- every grid emptied, the company waking naked --
                    -- and that was the bloodstain read literally. It cannot work here. Dark Souls drops
                    -- a FLOW (souls come back by playing) and Wizardry lets you staff a rescue party out
                    -- of a tavern; this mode has neither. Gear comes off the floors, the Gate store
                    -- sells draughts and a spare blade, and a body is a gacha pull (models/voucher.lua)
                    -- -- so stripping the grids meant the recovery dive was STRICTLY HARDER than the
                    -- dive that had just failed: same bodies, wounded, floor rearmed, nothing to fight
                    -- with. That is a spiral, not a stake.
                    --
                    -- SO THE BET IS THE HAUL, WHICH IS THE BET THE MODE IS ABOUT. Pushing one more spur
                    -- risks what you are carrying out, never the chassis you carry it with -- and the
                    -- grids stay exactly as the player arranged them, holes and adjacencies included.
                    -- Measured against the entry snapshot by Player.takeAtRisk, which is also what the
                    -- Loadout badges, so what the player was shown at stake is precisely what falls.
                    --
                    -- ...AND THE COIN AND ORE GO WITH IT (wipeRun, below), or a company that had tidied
                    -- every find into a grid would pay nothing at all and "sort your bag before a risky
                    -- fight" would be the game's best move.
                    --
                    -- BOUND ITEMS STAY ON THEIR HOLDER, the one exception, and the same one
                    -- Player.release makes: a signature relic is welded to its bearer by every other
                    -- path in the game (never moved, stowed, sold or stolen), and a wipe is not the
                    -- place to invent a way to part them. Player.atRisk skips them on both sides.
                    --
                    -- IT IS NO LONGER A BLOODSTAIN in the other half either. A pile is not destroyed by
                    -- the next one and it does not sit there waiting to be strolled onto: piles
                    -- accumulate, and each has something standing over it, drawn to the size of what was
                    -- spilled (models/descent.lua's Descent.dropPack and Descent.packGuard). What a wipe
                    -- costs is a FIGHT rather than a deletion.
                    local floor = Descent.depth(game.descent)
                    local dropped = Player.takeAtRisk(game.player, game.descent.entry)

                    Descent.dropPack(game.descent, floor,
                        game.map and game.map.px, game.map and game.map.py, dropped)

                    -- ...AND MOST OF THE COIN AND ORE THE EXPEDITION EARNED, which is the half that does
                    -- not lie in a heap waiting to be fetched. A rout drops what it was carrying;
                    -- purses come open.
                    --
                    -- Player.loseHaul rather than wipeRun, and the difference is the one thing that must
                    -- not be copied over from the campaign path: wipeRun ends by dropping the run, and a
                    -- descent's run is what holds the floors, the piles and the stair the company is
                    -- going to walk back down. Only the cut is wanted here.
                    --
                    -- It is also what keeps "leave the grid" honest. Only items are recoverable off the
                    -- pile, so without a cost that is NOT an item, the optimal play before a risky fight
                    -- would be to tidy every find into a spare grid cell and walk in owing nothing.
                    local before = game.descent.entry and Save.restore(game.descent.entry)
                    if before then Player.loseHaul(game.player, before) end

                    -- Everybody wakes up hurt. The wound is the other half of the cost and the only one
                    -- that follows them out (models/wound.lua) -- so a wipe is a company that is poorer
                    -- AND worse, which is what makes the second attempt on a floor a different fight.
                    game:inflictWounds()

                    -- ...AND THE FLOOR GOES IN THE MAP BOOK, exactly as the stair down and the way up
                    -- put it there (Descent.keepFloor). A floor cannot be rebuilt from its seed
                    -- (Overworld:snapshot says why -- the stops are drawn in `pairs` order), so a route
                    -- OFF a floor that does not put the board away is a route that rolls a fresh floor N
                    -- on the way back down. This was the one such route left, and it was the worst one to
                    -- be missing it: the Gate tells a wiped company "they are still there, and so is
                    -- everything they were carrying", and then the recovery dive opened on ground they
                    -- had never walked -- with the pile seated onto tiles by coordinate (markBodies)
                    -- that no longer meant anything, so the thing they came back for could be standing
                    -- in a wall.
                    --
                    -- ...EXCEPT THAT THE RIFT CLOSES ON A WIPE TOO, so there is no map book to put it
                    -- in. Both exits reset (see the climb-out branch), and the symmetry is
                    -- load-bearing: if dying preserved the floor stack and leaving did not, a company
                    -- standing deep with a thin haul would be better off letting itself be killed, and
                    -- the mode would have built an incentive to throw fights.
                    --
                    -- WHAT SURVIVES INSTEAD IS THE PILE, carried onto the company and re-seated on the
                    -- next run that reaches this depth (Descent.strandPacks). So the promise the Gate
                    -- makes a wiped company -- "everything they were carrying is still down there" --
                    -- is kept; what changed is that fetching it is a dive rather than a stroll across
                    -- ground they had already cleared.
                    Descent.strandPacks(game.player, game.descent)
                    game.player.descentRun = nil
                    -- AND THE PURSE BURNS, exactly as it does on the stair up (models/scrip.lua). Not a
                    -- second punishment on top of the dropped pack and the lost ore: scrip goes because
                    -- the EXPEDITION ended, and there is no exit that keeps it. A wipe that let a
                    -- company hold its scrip would be the one way to carry run coin between runs.
                    Scrip.clear(game.player)

                    -- The fight is over -- lost, but over. Every other way out of a battle says this
                    -- (there are six) and this one did not, which put a wiped company back into the
                    -- arena they had just been routed in the moment they walked back down the stair.
                    -- game.enter now clears it at the door as well; both, because a route that leaves
                    -- this screen holding a dead battle is wrong even if the next entry tidies up.
                    game.battle = nil

                    game.descent = nil
                    Player.save()
                    State.switch(require("states.gate"), {
                        player = game.player,
                        wiped = floor,
                    })
                    return
                end
                -- The one thing a wipe does NOT take back. Inflicted BEFORE the rollback, which is
                -- the whole of the ordering rule: the wipe reads the entry snapshot to price what the run
                -- snapshot, and wounds only survive it because that function holds this key across
                -- the copy. Written here rather than after, so the two halves cannot drift into a
                -- state where the wounds are recorded on a player about to be overwritten.
                game:inflictWounds()
                -- A WIPE IS THE ONLY THING THAT COSTS YOU ANYTHING. Walking out is free -- the company
                -- goes home with everything it picked up -- so losing the fight is the whole of the
                -- risk, and it takes most of the run's coin and ore with it (wipeRun). The items
                -- stay: a sword out of a chest is carried by a body, and the bodies came home.
                wipeRun()
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
                quest = game.quest,
                day = game.day,
                -- Who is still standing when the last door opens; read only by the finale's
                -- composition and nil-safe everywhere else. Threaded onto the walk-off path as well as
                -- the played one, or the two would build different fights from the same tile.
                generalsStanding = Calendar.generalsStanding(game.player),
                floorLevel = game.quest and game.quest.floorLevel or nil,
                -- Threaded here as well as onto the played path, for the reason `generalsStanding`
                -- above is: the walk-off must settle the fight that was standing on the tile.
                enemyLevel = game.quest and game.quest.dangerLevel or nil,
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
                day = game.day,
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
                    -- ...and the bag, if what was walked off was standing on one. Same seam the played
                    -- path takes, so a pack recovered either way is recovered identically.
                    takeGuardedPack()
                    grantSideSpoils(spoils)
                    -- A walked-off fight wounds exactly as a played one does, and is TOLD exactly as
                    -- one is -- the toast naming who, and the coach bubble the first time it happens
                    -- at all. Through the same seam with the fallen handed in, rather than a bare
                    -- Wound.inflict: this combat object is the only record of who went down, since no
                    -- battle state was ever entered here and states/battle.lua's field would hold
                    -- whatever the last watched fight left in it.
                    game:inflictWounds(Combat.fallenParty(combat))
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
        -- What this cache is hiding, rolled ONCE here rather than inside the panel, because the panel is
        -- opened, dismissed and opened again on an uncollected chest -- rolling it there would let a
        -- player reopen the lid until they liked what was under it. Empty off a descent floor (the roll
        -- needs a floorLevel) and empty most of the time even on one; see Spoils.rollSealed.
        local sealed = Spoils.rollSealed({ kind = "treasure", floorLevel = game.quest and game.quest.floorLevel or nil })
        -- An empty cache is one with nothing legible AND nothing unread in it.
        if #loot == 0 and #sealed == 0 then cell.cleared = true; saveRun(); return end
        -- THE MULE HAS TO HAVE ROOM FOR THE WHOLE CHEST, and a full one leaves it shut
        -- (models/mule.lua). The cell is deliberately NOT cleared, so the marker stays on the board and
        -- the player can come back for it after sending the mule home -- which is the decision this cap
        -- exists to force, and the reason a full mule is the mechanic firing rather than a failure.
        --
        -- ALL OR NOTHING rather than taking what fits, and only here: a chest is one object, and a lid
        -- that opened, handed over two of its four pieces and then closed again would leave a marker
        -- promising a cache that is no longer there. A fight's salvage splits (grantSideSpoils) because
        -- it is a pile of separate things off separate bodies.
        local want = #loot + #sealed
        if not Mule.canTake(game.player, want) then
            game:pushToast(Mule.isAway(game.descent)
                and "The mule is away -- nothing to carry this in"
                or ("The mule is full  (" .. Mule.load(game.player) .. " of " ..
                    Mule.capacity(game.player) .. ")"))
            return
        end
        game.activePanel = LootReveal.new({
            encounter = enc,
            loot = loot,
            sealed = sealed,
            onCollect = function()
                cell.cleared = true
                for _, id in ipairs(loot) do Player.grantItem(game.player, id) end
                for _, find in ipairs(sealed) do
                    Identify.grant(game.player, find.id, find.floor)
                end
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

    -- A Reliquary: deals a SLATE of three relics (models/relic.lua's Relic.slate) and takes exactly ONE.
    -- The two refused are the price of the one kept, which is the whole reason the stop exists: a single
    -- free relic was never a decision. The slate is rolled ONCE and pinned to the cell (like the
    -- Merchant's shelf), so LEAVE -- which leaves the cell uncleared to reconsider -- can't be walked off
    -- and back onto for a fresh roll.
    --
    -- A PLAIN RARITY ROLL, and held relics are IN it. That inversion is what makes stacking happen at all:
    -- draw something you already carry and taking it deepens what you have (Relic.magnitude), which is how
    -- a run commits to a build rather than collecting one of everything. The old code excluded held
    -- relics and then filtered the pinned slate against them a second time -- two guards against the
    -- outcome the system now wants.
    --
    -- AND THE BARE-SHELF BRANCH IS GONE WITH THEM. It paid a gold consolation when the run held
    -- everything eligible, which was reachable only because a relic could be held exactly once; a
    -- thirty-six-deep shelf that stacks has no empty state to answer.
    if kind == "relic_cache" then
        local enc = cell.encounter
        local def = enc.id and EncounterModel.get(enc.id)
        if not enc.offer then
            enc.offer = Relic.slate({
                day = game.day,
                sin = game.quest and game.quest.sin, -- this circle's shelf leans toward its own
                tier = enc.tier or (def and def.tier) or nil,
            }, 3)
        end
        local offer = {}
        for _, id in ipairs(enc.offer) do
            -- The count is what the card previews against: a relic already held reads as the transition
            -- its next copy buys (+2 -> +3), never as a bare repeat of the authored base.
            offer[#offer + 1] = { id = id, info = Relic.info(id), held = Relic.count(game.relicState, id) }
        end
        game.activePanel = RelicOffer.new({
            title = enc.name or "Reliquary",
            offer = offer,
            onTake = function(entry)
                cell.cleared = true
                local _, n = Relic.grant(game.relicState, entry.id)
                local name = Relic.info(entry.id).name or entry.id
                -- A duplicate says so, because "Relic taken: Whetstone Tithe" over a card the player
                -- knows they already hold reads as the stop having done nothing.
                game:pushToast((n and n > 1)
                    and ("Relic deepened: " .. name .. "  x" .. n)
                    or ("Relic taken: " .. name))
                game.activePanel = nil
                saveRun()
            end,
            -- Persist on the way out too: the pin is what makes leaving safe instead of a free reroll.
            onLeave = function() game.activePanel = nil; saveRun() end,
        })
        return
    end

    -- THE ALTAR: pay a fixed toll and take a relic you do not get to see first. The gamble verb.
    --
    -- IT USED TO SELL VICES, which is a premise the shelf no longer has -- there is one pool now and a
    -- downside is a property a relic may carry rather than a category it belongs to. What is left when
    -- the moral framing goes is the thing that was always actually good about the stop: a price, and no
    -- preview. It is cheaper than the Merchant's named stock, and that gap IS the wager.
    --
    -- Held relics stay in the pool exactly as at a Reliquary, so a gamble can deepen what you carry.
    if kind == "shrine" then
        local title = cell.encounter.name or "The Altar"
        -- The unseen relic is rolled ONCE and pinned to the cell, so backing out and stepping on again
        -- cannot reroll the gamble. That is the whole of what makes it a wager.
        local enc = cell.encounter
        enc.gamble = enc.gamble or Relic.roll(Relic.pool({
            day = game.day,
            sin = game.quest and game.quest.sin,
        }))
        local id = enc.gamble
        local price = 20 + game.day * 8
        local held = Relic.held(game.relicState)

        -- THE GAMBLE: pay, and take a relic you did not get to see. Cheaper than the Merchant's named
        -- stock, and that gap IS the wager.
        local function openGamble()
            if not id then game.activePanel = nil; return end
            game.activePanel = RelicReveal.new({
                title = title,
                relic = { id = id, info = Relic.info(id), held = Relic.count(game.relicState, id) },
                priceLabel = "Offering: " .. price .. " gold",
                canPay = game.player and (game.player.gold or 0) >= price,
                onTake = function()
                    if not (game.player and Player.spendGold(game.player, price)) then return end
                    cell.cleared = true
                    local _, n = Relic.grant(game.relicState, id)
                    local name = Relic.info(id).name or id
                    game:pushToast("The altar takes " .. price .. "g and gives: " .. name
                        .. ((n and n > 1) and ("  x" .. n) or ""))
                    game.activePanel = nil
                    saveRun()
                end,
                onLeave = function() game.activePanel = nil end,
            })
        end

        -- THE TRADE: give up two relics, take one of your choosing from the rung above. The run's only
        -- REMOVAL, which is what turns a relic with a downside from a permanent regret into a debt you
        -- can pay off -- and the only way to steer the pile rather than take what falls.
        --
        -- Built as three ordinary pick-one panels in sequence rather than a bespoke multi-select: give
        -- one, give another, take one. Each step is the same question the player already knows how to
        -- answer from a Reliquary, and backing out of any of them costs nothing, because NOTHING IS SPENT
        -- UNTIL THE LAST PICK -- the two given relics are only removed once a replacement is chosen. A
        -- trade abandoned halfway must not eat the relics it was halfway through taking.
        local function relicRows(exclude)
            local rows = {}
            for _, e in ipairs(Relic.held(game.relicState)) do
                if e.id ~= exclude then
                    local info = Relic.info(e.def)
                    info.id = e.id
                    rows[#rows + 1] = { id = e.id, info = info, held = e.count }
                end
            end
            return rows
        end

        local openTrade
        local function openTakeStep(giveA, giveB)
            -- One rung up from what this floor would otherwise deal. A rare traded for is the same rare a
            -- Reliquary could have dealt; what the two relics bought is the CHOICE of which.
            local up = { common = "uncommon", uncommon = "rare", rare = "rare" }
            local best = "common"
            for _, gid in ipairs({ giveA, giveB }) do
                local t = (Relic.get(gid) or {}).tier or "common"
                if t == "rare" or (t == "uncommon" and best ~= "rare") then best = t end
            end
            local slate = Relic.slate({ day = game.day, tier = up[best],
                sin = game.quest and game.quest.sin }, 3)
            local offer = {}
            for _, sid in ipairs(slate) do
                offer[#offer + 1] = { id = sid, info = Relic.info(sid), held = Relic.count(game.relicState, sid) }
            end
            if #offer == 0 then game.activePanel = nil; return end
            game.activePanel = RelicOffer.new({
                title = "Take one",
                offer = offer,
                onTake = function(entry)
                    cell.cleared = true
                    Relic.forget(game.relicState, giveA)
                    Relic.forget(game.relicState, giveB)
                    local _, n = Relic.grant(game.relicState, entry.id)
                    local name = Relic.info(entry.id).name or entry.id
                    game:pushToast("Traded two for " .. name .. ((n and n > 1) and ("  x" .. n) or ""))
                    game.activePanel = nil
                    saveRun()
                end,
                onLeave = function() openTrade() end, -- back out: nothing has been given up yet
            })
        end

        openTrade = function()
            local rows = relicRows(nil)
            if #rows < 2 then game.activePanel = nil; return end
            game.activePanel = RelicOffer.new({
                title = "Give up a relic",
                offer = rows,
                onTake = function(a)
                    local rest = relicRows(a.id)
                    game.activePanel = RelicOffer.new({
                        title = "And another",
                        offer = rest,
                        onTake = function(b) openTakeStep(a.id, b.id) end,
                        onLeave = function() openTrade() end,
                    })
                end,
                onLeave = function() game.activePanel = nil end,
            })
        end

        -- The stop asks which verb first, because the two spend different things and a panel that showed
        -- one of them would be hiding the other. A trade needs two relics to give; below that the row is
        -- simply not offered rather than opening onto a refusal.
        local options = {}
        if id then
            options[#options + 1] = { label = "Gamble  (" .. price .. "g)",
                desc = "Pay, and take a relic you do not get to see first.", cb = openGamble }
        end
        if #held >= 2 then
            options[#options + 1] = { label = "Trade  (two relics)",
                desc = "Give up two of what you carry, and choose one from the rung above.", cb = openTrade }
        end
        if #options == 0 then cell.cleared = true; saveRun(); return end
        game.activePanel = Choice.new({
            title = title,
            prompt = "The stone takes something, and gives something back.",
            options = options,
            onClose = function() game.activePanel = nil end,
        })
        return
    end

    -- THE WEEPING STONE: a relic a rung above what this floor would deal, sold for a permanent cut to
    -- the company's MAXIMUM health.
    --
    -- Maximum rather than current, and that is the whole design of the stop. A camp hands back half of
    -- everything missing (Player.CAMP_SHARE), so a current-health price is one the floor's own rest
    -- undoes -- you would pay nothing and know it within two stops. A ceiling that does not come back is
    -- a decision every remaining floor has to be fought around, and it reads in the same register a
    -- wound does.
    --
    -- Priced as a SHARE rather than a flat number so it costs the same fraction on floor one and floor
    -- eight, and can never scale into the absurd against a company that has grown. Floored so that it
    -- always takes something, and so that it can never reduce a body below a single point.
    if kind == "weeping_stone" then
        local enc = cell.encounter
        enc.offer = enc.offer or Relic.slate({ day = game.day, tier = "rare",
            sin = game.quest and game.quest.sin }, 1)
        local id = enc.offer[1]
        if not id then cell.cleared = true; saveRun(); return end
        local roster = (game.player and game.player.roster) or {}
        local toll = {}
        for _, char in ipairs(roster) do
            local hp = char.stats and char.stats.health
            if type(hp) == "table" and (hp.max or 0) > 1 then
                toll[#toll + 1] = { char = char, amount = math.max(1, math.floor((hp.max or 0) * game.STONE_SHARE)) }
            end
        end
        game.activePanel = RelicReveal.new({
            title = cell.encounter.name or "The Weeping Stone",
            relic = { id = id, info = Relic.info(id), held = Relic.count(game.relicState, id) },
            priceLabel = "Offering: " .. math.floor(game.STONE_SHARE * 100) .. "% of every maximum, for the run",
            canPay = #toll > 0,
            onTake = function()
                cell.cleared = true
                for _, t in ipairs(toll) do
                    local hp = t.char.stats.health
                    hp.max = math.max(1, (hp.max or 0) - t.amount)
                    hp.current = math.min(hp.current or hp.max, hp.max)
                end
                local _, n = Relic.grant(game.relicState, id)
                local name = Relic.info(id).name or id
                game:pushToast("The stone takes its due: " .. name .. ((n and n > 1) and ("  x" .. n) or ""))
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
            for _, id in ipairs(Spoils.shelf({ prestige = game.day, count = 3 })) do
                enc.stock[#enc.stock + 1] = { id = id, price = Item.defs[id].price, bought = false }
            end
            -- ...AND A RELIC SHELF BESIDE THE GEAR. The road is the shop (see the encounter blueprint's
            -- own header), and until now the only thing a run could do with foraged gold was buy a
            -- weapon -- so every relic in the game arrived as something that happened TO the player
            -- rather than something they chose to spend on.
            --
            -- Two, priced by rung and by depth (Relic.price). Rolled off the same pool a Reliquary deals
            -- from, held relics INCLUDED: buying a second copy of something you already carry is a
            -- perfectly good use of a purse, and it is how a run commits to a build.
            for _, id in ipairs(Relic.slate({ day = game.day, sin = game.quest and game.quest.sin }, 2)) do
                enc.stock[#enc.stock + 1] =
                    { id = id, relic = true, price = Relic.price(id, game.day), bought = false }
            end
        end
        if #enc.stock == 0 then cell.cleared = true; saveRun(); return end
        local stock = {}
        for _, s in ipairs(enc.stock) do
            -- A shelf pinned to the cell can outlive the blueprint it names (a removed item, an older
            -- save), so a row whose id no longer resolves is simply not offered rather than crashing the
            -- panel that would have instantiated it.
            if s.relic then
                -- A relic row carries its info and how many the company already holds, so the shelf can
                -- say "held x2" and its reading can resolve the magnitude at that stack.
                local info = Relic.info(s.id)
                if info then
                    info.id = s.id
                    stock[#stock + 1] = { id = s.id, relic = info, price = s.price, bought = s.bought,
                                          held = Relic.count(game.relicState, s.id), src = s }
                end
            elseif Item.defs[s.id] then
                stock[#stock + 1] = { id = s.id, price = s.price, bought = s.bought, src = s }
            end
        end
        game.activePanel = Merchant.new({
            title = enc.name or "Merchant",
            stock = stock,
            -- PAID IN SCRIP (models/scrip.lua). The prices did not move: what used to be this shelf's
            -- gold price is its scrip price at the same number, and the fights that fund it were
            -- renamed on the same day at the same numbers -- so floor three is exactly as affordable as
            -- it was. What changed is that a relic bought here no longer costs a forge rung.
            gold = function() return Scrip.get(game.player) end,
            unit = Scrip.UNIT,
            suffix = Scrip.SUFFIX,
            onBuy = function(entry)
                if not (game.player and Scrip.spend(game.player, entry.price)) then return false end
                if entry.relic then
                    -- Straight onto the run, not into the stash: a relic is carried for this descent and
                    -- is not a thing the hub ever holds.
                    local _, n = Relic.grant(game.relicState, entry.id)
                    local name = entry.relic.name or entry.id
                    game:pushToast((n and n > 1)
                        and ("Relic deepened: " .. name .. "  x" .. n)
                        or ("Relic bought: " .. name))
                else
                    Player.grantItem(game.player, entry.id) -- straight into the stash, like any find
                    game:pushToast("Bought: " .. (entry.item and entry.item.name or entry.id))
                end
                if entry.src then entry.src.bought = true end -- persist the sale on the cell's shelf
                saveRun()
                return true
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
            -- THE WAGERS ARE IN SCRIP, and the two helpers keep their names. A dilemma is authored
            -- against "the purse" -- `ctx.gold()` and `ctx.addGold(30)` -- and which purse that is has
            -- never been the data's business (see models/crossroads.lua's header: it never reaches a
            -- model directly). Renaming them would have edited fourteen authored dilemmas to record a
            -- fact not one of them acts on. A crossroads is a stop on a floor, so it plays for the coin
            -- a floor pays (models/scrip.lua).
            --
            -- addGold is handed NEGATIVE amounts by the dilemmas that charge a toll, which Scrip.add
            -- refuses outright -- so the sign is settled here, at the seam that knows both shapes,
            -- rather than by loosening the model's contract for one caller.
            gold = function() return Scrip.get(game.player) end,
            addGold = function(n)
                if not game.player then return end
                n = math.floor(tonumber(n) or 0)
                if n >= 0 then Scrip.add(game.player, n) else Scrip.take(game.player, -n) end
            end,
            reveal = function() game:restStudy() end,
            drainParty = function(n)
                for _, c in ipairs((game.player and game.player.roster) or {}) do
                    local hp = c.stats and c.stats.health
                    if type(hp) == "table" then hp.current = math.max(1, (hp.current or hp.max) - n) end
                end
            end,
            -- SET A BONE, and it is the one helper here that can pay nothing through no fault of the
            -- dilemma: a company with no wounds has none to set. It answers with the count it actually
            -- moved rather than with true, so a resolve can say "there was nothing here you needed" in
            -- its own voice instead of leaving the player looking at a stop that reported silence.
            --
            -- Only two things underground can do this and this is the second (the first is a Rest spent
            -- on Bind). Both are the same shape on purpose -- taken INSTEAD of something -- because a
            -- wound that can be shed for free as often as you like is not a meter (models/wound.lua).
            mendWound = function(n)
                local mended = Wound.mend(game.player, n or 1)
                if #mended > 0 then
                    game:pushToast((#mended == 1) and "A bone is set" or (#mended .. " bones are set"))
                end
                return #mended
            end,
            grantRelic = function(tier)
                local id = Relic.roll(Relic.pool({ prestige = game.day, tier = tier,
                    sin = game.quest and game.quest.sin }))
                if not id then return nil end
                local _, n = Relic.grant(game.relicState, id)
                local name = Relic.info(id).name or id
                game:pushToast("You gain: " .. name .. ((n and n > 1) and ("  x" .. n) or ""))
                return name
            end,
            -- AN UNREAD PIECE, which is the one stake that exists because you are in the rift rather
            -- than on a road. It costs no new balance surface -- what a seal hides is the forge level,
            -- and every magnitude already resolves per level off an authored curve -- and it puts a
            -- second beat on the find, back at the Touchstone. Returns false on a campaign board (no
            -- floorLevel) so a dilemma can say so rather than silently paying nothing.
            grantSealed = function()
                local floor = game.quest and game.quest.floorLevel
                if not floor then return false end
                local got = Spoils.rollSealed({ kind = "offer", floorLevel = floor })
                for _, find in ipairs(got) do Identify.grant(game.player, find.id, find.floor) end
                if #got == 0 then return false end
                game:pushToast("Sealed -- nobody here can read it")
                return true
            end,
        }
        -- THE CIRCLE PICKS THE QUESTION. `quest.sin` is on the floor descriptor already (models/
        -- descent.lua) and is read three lines up to filter the relic shelf; a floor draws the shared
        -- dilemmas plus its own sin's, so roughly half of what a player meets down here is Gluttony's or
        -- Pride's rather than nobody's.
        local dilemma = Crossroads.roll(rnd, game.quest and game.quest.sin)
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

    -- A Rest is a DECISION, not just a breather: Heal the party, Sharpen a lasting run edge, Study the
    -- ground (models/relic.lua + the fog reveal), or Bind the company's wounds. One only; leaving (X/Esc)
    -- forgoes it and leaves the cell to reconsider. The companions plug in here later (Amana strengthens
    -- Heal, Gyeom strengthens Study).
    --
    -- BIND IS OFFERED ONLY TO A COMPANY THAT HAS SOMETHING TO BIND, which is why the callback is handed
    -- over conditionally rather than gated inside the panel: the row simply is not there for a whole
    -- company, and a control draws where it can be used. It is also the only bone-setting the floors
    -- have -- the Inn that used to do it for coin is gone (models/wound.lua) -- so it has to be spent
    -- INSTEAD of the heal, the whetstone or the map, which is the property a counter never had.
    if kind == "rest" then
        game.activePanel = RestChoice.new({
            title = cell.encounter.name or "Make Camp",
            onBind = (#Wound.wounded(game.player) > 0) and function()
                cell.cleared = true
                game:restBind()
                saveRun()
            end or nil,
            onHeal = function()
                cell.cleared = true
                game:restHeal()
                saveRun()
            end,
            onSharpen = function()
                cell.cleared = true
                -- SHARPENING TWICE NOW MEANS SOMETHING. This used to answer a second camp with "your
                -- edge is already keen" and pay nothing, because a relic could be held exactly once --
                -- so the choice was dead from the second rest onward. It stacks, so a company that
                -- keeps choosing the whetstone over the bandage opens harder every time.
                local _, n = Relic.grant(game.relicState, "relic_honed_edge")
                game:pushToast((n and n > 1)
                    and ("You hone your edge again  (Honed Edge x" .. n .. ")")
                    or "You hone your edge  (Honed Edge)")
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

    -- THE WAY BACK UP. The tile the party walked in on, and the only ending a descent has that costs
    -- nothing (models/overworld.lua's placeExit).
    --
    -- THIS IS THE RETREAT, AND IT IS NOT THE EXTRACTION THAT WAS DELETED. That one was a button on the
    -- landing: it ended a run, banked nothing, and read as the sensible answer, so the landing's whole
    -- question was fake. This is a PLACE. You have to be standing on it, which means you have to have
    -- walked back to it -- so how deep a company pushes is bounded by how far it is willing to be from
    -- the way out, and the return trip is real ground it needs something left for. That bound is the
    -- whole of Wizardry's pacing and it cannot be got from a menu.
    --
    -- AND IT BANKS, which the extraction never did. The company, its levels, its gear and its purse go
    -- into the descent's own file and the next expedition picks them up where they stood -- same seed,
    -- so the same seven circles in the same order, and the floor it climbed out of is the floor it goes
    -- back down to. That is the persistence the mode used to refuse outright, and it is what makes the
    -- distance to this tile worth measuring.
    --
    -- Four ways off a floor, and they are properly different:
    --   this tile     climb out. Keep the company and everything on it. Come back to this floor.
    --   this tile     ...or up ONE floor, to the stair you came down by (Descent.retreat). The
    --                 expedition continues; the tally pays for the ground given back.
    --   the stair     go deeper, having beaten the circle's general.
    --   losing        wake at the Gate, keep the floor and the levels, leave the packs on the tile.
    --
    -- There was a fourth -- Esc, which gave up where you stood and discarded the floor stack -- and it
    -- is gone (see backVisible). This tile is what it should always have been: the way out is a PLACE
    -- you walk to, priced in the distance back to it, exactly as the way down is.
    if kind == "ascent" then
        local run = game.descent
        if not run then cell.cleared = true; return end
        local carried = game:haulPhrase()
        local depth = Descent.depth(run)

        -- THE STAIR IS NOT AN EXIT AT THE CEILING, which is the thing the tally has been counting toward
        -- since it was written (models/descent.lua's Descent.isBreached, docs/the-count.md).
        --
        -- It is the same card in the same place, and that is deliberate: the player walks back to the
        -- tile they have always walked back to, presses it the way they always have, and what has
        -- changed is the answer. A separate screen for the breach would announce it before the tile
        -- did; a marker on the map would let it be avoided, and the whole point is that the way out is
        -- what filled up.
        --
        -- IT IS OPENED AS A FIGHT ON THIS BOARD rather than as a mode of its own. The tile is turned
        -- into an elite encounter carrying its own cast (the same seam a dropped pack's guard uses --
        -- `enc.composition` beats a blueprint's, models/encounter_battle.lua) and re-dispatched through
        -- the ordinary fight path, so the deployment, the spoils, the wounds and -- the one that
        -- matters -- the WIPE all behave exactly as they do everywhere else. Losing the breach is a
        -- wipe: the company wakes at the Gate with the run intact and the tally still full, which is
        -- what makes this a state to fight out of rather than a game over.
        --
        -- THE ONLY THING SPECIAL-CASED IS THE WIN, and it is handled where every other win is
        -- (`cell.encounter.breach` in the battle's onWin). Beating what came up the stair is beating
        -- the Crown, wherever it was met.
        if Descent.isBreached(game.player) then
            local standing = Calendar.generalsStanding(game.player)
            game.activePanel = Choice.new({
                title = "The Stair",
                prompt = "The way up is full of them. " ..
                    (standing > 0
                        and ("The Hollow Crown has come up to meet the company, and " .. standing ..
                             (standing == 1 and " general still stands beside it."
                                            or " generals still stand beside it."))
                        or "The Hollow Crown has come up to meet the company, and it comes alone.") ..
                    "\nThere is no climbing out of this one. Every floor below still prunes: the count " ..
                    "goes down by going down.",
                options = {
                    {
                        label = "Cut your way out",
                        desc = "Fight what is on the stair. Everything the company is carrying is at " ..
                            "stake, exactly as it would be against anything else down here.",
                        accent = { 0.86, 0.36, 0.30 },
                        cb = function()
                            game.activePanel = nil
                            -- The tile stops being a way up for exactly as long as the fight lasts.
                            -- Restored in onWin before the floor is put away, so a board snapshotted
                            -- with a spent breach on it does not come back as a fight nobody can win.
                            cell.wasAscent = cell.encounter
                            cell.encounter = {
                                kind = "elite",
                                name = "The Breach",
                                breach = true,
                                composition = Descent.breachComposition(
                                    game.player, Descent.floorLevel(run)),
                            }
                            game:openEncounter(cell)
                        end,
                    },
                    {
                        label = "Stay down",
                        desc = "The floor is not finished with, and neither is the one below it.",
                        accent = { 0.83, 0.73, 0.45 },
                        cb = function() game.activePanel = nil end,
                    },
                },
                onClose = function() game.activePanel = nil end,
            })
            return
        end

        -- UP ONE FLOOR, and only where there is one to go up to.
        --
        -- A descent had one direction, and this tile's only offer was to end the expedition -- so a
        -- company that wanted to walk back to a pack it dropped two floors above had to climb out of the
        -- rift and re-descend from the top. The floors are kept precisely so they can be walked again
        -- (Descent.keepFloor): the map is still there, and the only thing missing was the door back to
        -- it.
        --
        -- BUILT AS A LIST rather than written inline as `depth > 1 and {...} or nil`, which is a trap
        -- Lua sets in exactly this shape: a nil first element leaves a hole at index 1 and `ipairs` --
        -- which is what walks an option list -- stops on it, so the card would have come up EMPTY on
        -- floor one. It did, before this was pulled out.
        local upOptions = {}
        if depth > 1 then
            upOptions[1] = {
                label = "Up to floor " .. (depth - 1),
                desc = "Back up the stair you came down by. The floor above is as you left it.",
                accent = { 0.72, 0.78, 0.86 },
                cb = function()
                    game.activePanel = nil
                    -- This floor goes in the map book before the company steps off it, exactly as every
                    -- other way off a floor does -- or the walk back down rolls a new one over the map
                    -- the player made.
                    Descent.keepFloor(run, depth, game.grid:snapshot())
                    Descent.retreat(run, game.player)
                    Player.save()
                    State.switch(require("states.game"),
                        Descent.floorQuest(run, game.player), game.day, game.player)
                end,
            }
        end

        upOptions[#upOptions + 1] = {
            label = "Climb out",
            desc = "The expedition ends here. The company keeps everything it is carrying -- and the " ..
                "rift closes behind them. The next way down is a new one, from the top.",
            accent = { 0.72, 0.78, 0.86 },
            cb = function()
                game.activePanel = nil
                -- WHAT THE WAY UP COSTS, and the only thing in the mode that costs it. Marked
                -- BEFORE the rollback point is taken, so a wipe on the next floor cannot
                -- un-teach the readout the player has already been shown.
                Descent.markClimbedOut(game.player)
                Descent.climbOut(game.player)
                -- THE SURFACE BURNS THE SCRIP (models/scrip.lua), and this is the line that makes the
                -- two-currency economy mean anything. Unspent run coin is a LOSS, which is what turns
                -- the Merchant from a stop priced against a forge rung into a stop you had better use.
                -- Forecast on the prompt below, BEFORE the choice is made, rather than reported as a
                -- toast after it: a cost said afterwards is news, and this one is a decision.
                Scrip.clear(game.player)
                -- BANKING IS RE-BASELINING, not dropping the run. Everything found has been live
                -- on the company since it was picked up; what made it provisional is the entry
                -- snapshot a wipe rolls back to (wipeRun). Re-taking that snapshot here is the
                -- whole of the bank: the floors below can no longer reach anything the company
                -- climbed out with.
                --
                -- ...AND THE RIFT CLOSES BEHIND THEM. This is the extraction rule and it is the
                -- whole shape of the mode: leaving banks everything and throws the DUNGEON away.
                -- Next descent is a fresh stack from floor one, a fresh shuffle of the circles, a
                -- fresh set of boards.
                --
                -- THE BOARD USED TO BE KEPT, and the argument for keeping it was Wizardry's: the
                -- maze is permanent, so the fog you lifted and the map you made are still there
                -- next time. That is the right answer for a descent you can bank progress in, and
                -- it is exactly what made walking out free -- the stair stayed open, the city
                -- healed for nothing, and the company came back down onto ground it had already
                -- cleared. The price on leaving is now the ground itself.
                --
                -- WHAT SURVIVES is everything the company IS: gold, gear, the stash, levels,
                -- completed errands and the shelf rungs they opened, the circles it has sealed,
                -- husks in the satchel, the tally. Only the expedition is thrown away -- which is
                -- why the bank below has to happen before it is.
                local entry = Save.snapshot(game.player)
                if game.player.activeRun then game.player.activeRun.entry = entry end
                run.entry = entry
                -- WHAT WAS LEFT LYING ON THE FLOORS comes with them as a debt rather than dying
                -- with the run (Descent.strandPacks): a pile is the mode's entire economy, and a
                -- reset that quietly deleted one would turn an expensive mistake into a permanent
                -- one -- the exact rule Descent.dropPack was rewritten to avoid.
                Descent.strandPacks(game.player, run)
                game.player.descentRun = nil
                game.descent = nil
                Player.save() -- the company, banked, with no expedition open
                -- UP TO THE GATE, not to a terminal card. Climbing out is not the end of
                -- anything -- it is the other half of the loop, and there is a town at the top
                -- of the stair now (states/gate.lua). The card that reports how a run ENDED is
                -- still there for the three endings that are endings.
                State.switch(require("states.gate"), { player = game.player })
            end,
        }
        upOptions[#upOptions + 1] = {
            label = "Stay down",
            desc = "The floor is not finished with.",
            accent = { 0.83, 0.73, 0.45 },
            cb = function() game.activePanel = nil end,
        }

        game.activePanel = Choice.new({
            title = "The Way Up",
            -- WHAT THE WAY UP COSTS, said where the decision is made, as a TRANSITION rather than an
            -- addition (models/descent.lua's count): this is an always-on forecast of a move the player
            -- has not made yet, and "18 of 25" alone would not say which way it moved. Same grammar and
            -- the same arrow the party sheet's forecasts use (ui/panels/party.lua).
            --
            -- ON THE PROMPT RATHER THAN THE OPTION, and that is a layout fact rather than a preference:
            -- ui/panels/choice.lua grows its box to fit a wrapped prompt and holds every option card at
            -- a fixed 70px, so a third line of description spills out of the card and over the one
            -- below it. Measured, not guessed -- it did exactly that.
            --
            -- Silent until Iselle has named the thing (Descent.everClimbedOut), because a number quoted
            -- before anybody has explained what it counts is a price on a service the player cannot read.
            prompt = (carried
                and ("The company is on floor " .. depth .. " carrying " .. carried ..
                     ". Climb out and all of it comes with them.")
                or ("The company is on floor " .. depth .. " and has found nothing yet.")) ..
                -- ...AND WHAT DOES NOT COME UP WITH THEM (models/scrip.lua). Said here, at the decision,
                -- because an unspent purse is the one cost of leaving that the player can still do
                -- something about -- there is a Merchant back there. A number that only appears after
                -- the choice is made would be a receipt for a decision they were never offered.
                --
                -- Silent at zero, which is not the same rule as the count's silence below: an empty
                -- purse has nothing to warn about, and printing "0 scrip will not come up" on every
                -- exit would teach the player to stop reading the line that matters.
                ((Scrip.get(game.player) > 0)
                    and ("\n" .. Scrip.get(game.player) .. " " .. Scrip.UNIT ..
                         " will not come up with them.")
                    or "") ..
                (Descent.everClimbedOut(game.player)
                    and ("\nThe count goes " .. Descent.count(game.player) .. " \226\134\146 " ..
                         math.min(Descent.COUNT_MAX, Descent.count(game.player) + 1) ..
                         " of " .. Descent.COUNT_MAX .. ".")
                    or ""),
            options = upOptions,
            -- Backing out is staying down, which is a real answer -- unlike the landing, this tile is
            -- one the party can simply walk off again. The cell is left uncleared to come back to.
            onClose = function() game.activePanel = nil end,
        })
        return
    end

    -- THE WAY DOWN, and it is the way up's opposite number in every respect that matters: a tile, on
    -- ground the company had to fight for, that answers every time it is stood on and never clears.
    --
    -- It exists because beating a floor's guardian used to BE the step down (models/descent.lua's
    -- Descent.openStair). Now the fight only opens it, and everything still standing on the floor --
    -- the reliquary, the caches, the recruit, a house's errand -- is between the player and this tile
    -- for exactly as long as they want it to be. What the stair asks is the only question left: enough.
    --
    -- ONE-WAY, and the panel says so rather than implying it. The board is kept on the way through
    -- (Descent.keepFloor), but nothing walks back UP a floor -- the only route to this ground again is
    -- climbing out to the gate and coming back down -- so what is left here is left.
    if kind == "stair" then
        local run = game.descent
        if not run then cell.cleared = true; return end
        local depth = Descent.depth(run)
        local below = Descent.nameOf(run, depth + 1)
        -- Phrased so the place NAMES itself rather than being slotted after an article: a sin takes
        -- none ("Below you is Wrath"). The bottom is the one exception and takes its article, because
        -- it is a thing rather than a place -- and naming the Hollow Crown is the whole of the warning
        -- a player gets before the last floor of the run. It is said HERE, on the step itself, rather
        -- than on the boon card a floor earlier where there was nothing to do about it.
        local last = Descent.isBottom(depth + 1)
        game.activePanel = Choice.new({
            title = "The Stair Down",
            prompt = last
                and ("There are no more circles. Below you is " .. below ..
                     ", and beating it ends the descent.")
                or ("Below you is " .. below .. "."),
            options = {
                {
                    label = "Go down",
                    desc = "Floor " .. (depth + 1) .. ". Whatever is still standing on this floor " ..
                        "stays on it.",
                    accent = { 0.83, 0.73, 0.45 },
                    cb = function()
                        game.activePanel = nil
                        -- Put this floor away before stepping off it, so a company that climbs out and
                        -- comes back finds the map it made rather than a fresh roll.
                        Descent.keepFloor(run, depth, game.grid:snapshot())
                        Descent.advance(run, game.player)
                        State.switch(require("states.game"), Descent.floorQuest(run, game.player),
                            game.day, game.player)
                    end,
                },
                {
                    label = "Not yet",
                    desc = "The floor is not finished with.",
                    accent = { 0.72, 0.78, 0.86 },
                    cb = function() game.activePanel = nil end,
                },
            },
            onClose = function() game.activePanel = nil end,
        })
        return
    end

    -- ---- THE THREE HAZARDS (data/encounters/encounter_dark.lua and siblings) ------------------------
    --
    -- What makes a descent floor a place that lies to you rather than a route with fights on it. All
    -- three resolve WITHOUT a panel and without a choice: a hazard you are asked to confirm is a door,
    -- and the thing being borrowed here is the square that does it to you before you have finished
    -- stepping. The toast is the whole of the telling.
    --
    -- Each marks its cell cleared, so a floor a company keeps (Descent.keepFloor) does not spring the
    -- same hole twice -- which is the difference between a hazard and a wall.

    -- THE DARK: vision to arm's length for a stretch of walking. Everything the board says at a distance
    -- -- a fight's tier pips, a reward past its guard, the way up -- has to be walked into instead.
    if kind == "dark" then
        cell.cleared = true
        game.darkFor = (game.darkFor or 0) + Descent.darkSteps(game.grid)
        game:pushToast("The lamp gutters. You can see a pace ahead.")
        game:applyVision()
        saveRun()
        return
    end

    -- THE TURNING FLOOR: your place on your own map, taken. The ground around the company goes back
    -- under the fog; everything learned about the REST of the floor is untouched, which is right --
    -- what a spinner costs is bearings, not the map.
    if kind == "spinner" then
        cell.cleared = true
        local r = Descent.SPINNER_RADIUS
        local up = game.grid:startCell()
        for y = cell.y - r, cell.y + r do
            for x = cell.x - r, cell.x + r do
                local c = game.grid:get(x, y)
                -- The place underfoot stays read. A company that cannot see the place it is standing in
                -- is not disoriented, it is stuck.
                local here = (x == cell.x and y == cell.y)
                -- ...AND THE WAY UP IS NEVER UNLEARNED. The exit is not bearings, it is the run's bank:
                -- walking out is free and the risk is meant to be losing a fight, so a hazard that can
                -- strand a full haul without one is off-contract. The radius used to be six, which on
                -- this floor is the whole of it -- the stair went with everything else and a company
                -- that had walked the place had no way home it could see. See Descent.SPINNER_RADIUS.
                local exit = Descent.SPINNER_SPARES_EXIT and up and c == up
                if c and not here and not exit then c.seen = false end
            end
        end
        game:pushToast("The floor turns under you. Nothing here looks the way you left it.")
        game:applyVision()
        saveRun()
        return
    end

    -- THE TRANSLATION: somewhere else on this floor, onto ground already walked. The cost is the walk
    -- back, which on a warren this size is the largest bill the board can hand out for free.
    if kind == "translation" then
        cell.cleared = true
        -- HOW FAR IS A THIRD OF THIS FLOOR'S CROSSING, and it RELAXES rather than giving up.
        --
        -- It was a fixed eight, which on a forty-step board was a long walk and on an eighteen-step one
        -- is further than most of the floor is from most of the floor. The pass found nothing that
        -- qualified and fell through to a toast saying nothing had happened -- so the hazard became a
        -- thing the player learns to ignore, which is worse than not having it. Relaxing a step at a
        -- time is what every seating pass in the generator does when a floor cannot meet its own rule.
        local seen = {}
        local want = Descent.translationMin(game.grid)
        while #seen == 0 and want >= 1 do
            for y = 1, game.grid.rows do
                for x = 1, game.grid.cols do
                    local c = game.grid.cells[y][x]
                    -- Known ground, walkable, and not where they already are. Deliberately not fog: a
                    -- party dropped blind beside an unread fight is an ambush the board chose, and this
                    -- mode spends its cruelty on permanent death instead.
                    if c.seen and game.grid:typeWalkable(c.tile) and not c.encounter
                        and (math.abs(x - cell.x) + math.abs(y - cell.y)) >= want then
                        seen[#seen + 1] = c
                    end
                end
            end
            want = want - 1
        end
        if #seen > 0 then
            local to = seen[math.random(#seen)]
            game.map.px, game.map.py = to.x, to.y
            game.map.slidePrevX, game.map.slidePrevY = to.x, to.y
            game.map:updateCamera()
            game.map:snapCamera()
            game:pushToast("You step, and the step lands somewhere else.")
        else
            -- Nowhere far enough that the company has seen. Nothing happens, and it says so rather than
            -- reporting a translation that did not occur.
            game:pushToast("The air pulls, and lets go.")
        end
        game:applyVision()
        saveRun()
        return
    end

    -- WHAT YOU DROPPED, UNGUARDED. A pile has something standing on it now (Descent.packGuard) and is
    -- handled far above, on the combat path -- so the only packs that reach here are the ones dropped
    -- before that landed, which carry no cast. They are picked up by walking onto them, which is what
    -- they were dropped under; a save mid-run must not have a fight invented over its bag.
    if kind == "pack" then
        local drop = cell.encounter.drop
        local items = drop and game.descent and Descent.takePack(game.descent, drop, game.player)
        if items then
            for _, item in ipairs(items) do Player.addToStash(game.player, item) end
            game:pushToast("You take back what you dropped  (" .. #items ..
                (#items == 1 and " item)" or " items)"))
        end
        cell.cleared = true
        cell.encounter = nil
        game:markBodies()
        saveRun()
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

-- HEAL (a rest's first choice): give back a share of every roster member's missing resources
-- (Player.camp), then replay it on a reveal panel so the player SEES what it did -- each party member's
-- HP bar sweeps from the wound they walked in with to where the camp left them (ui/panels/rest.lua).
-- Factored out of the rest resolution so RestChoice's Heal option and any back-compat non-combat path
-- both reach the same code.
--
-- A CAMP IS NOT THE HUB. This called Player.restore -- the hub's full refill -- until the board's
-- attrition was measured: one guaranteed rest per two and a half fights, each erasing everything the
-- fights before it cost, which left a won fight costing nothing durable and made every optional fight
-- on the board a free yes. Player.CAMP_SHARE carries the reasoning; the hub still heals whole, because
-- going home is supposed to be the thing that makes you whole.
function game:restHeal()
    if not game.player then return end
    -- THE UNPAID TITHE (a rare relic): the company recovers nothing between fights, and a camp is the
    -- loudest thing that would otherwise quietly disagree with that.
    --
    -- Told rather than silently zeroed. The relic hooks are gagged inside ctx.restore and simply pay
    -- nothing, which is right for a passive that fires on its own -- but this is a button the player
    -- deliberately pressed, and a rest that plays its whole reveal animation over four bars that do not
    -- move is the game claiming to have done something it did not. Say why, and leave the stop
    -- unspent so the other two choices are still there to take.
    local rules = Relic.resolvedRules(game.relicState)
    if rules and rules.noRecovery then
        game:pushToast("The tithe is unpaid -- the company recovers nothing")
        game.activePanel = nil
        return
    end
    -- Snapshot each shown member's wound BEFORE the heal: the reveal animates from it, and once
    -- Player.camp runs the live stat has already moved, so this is the only place the "before" exists.
    -- The whole roster marches, so the whole roster is healed and shown.
    local shown = game.player.roster or {}
    local entries = {}
    for _, char in ipairs(shown) do
        local hp = char.stats and char.stats.health
        if type(hp) == "table" then
            entries[#entries + 1] = { char = char, from = hp.current or hp.max, max = hp.max or 0 }
        end
    end
    Player.camp(game.player)
    -- ...and the "after", read back off the same live stat the camp just moved. Taken here rather than
    -- computed from CAMP_SHARE so the bar cannot disagree with the roster: a wound cap, a rounding rule
    -- or a later change to what a camp restores all land on this line for free.
    for _, e in ipairs(entries) do
        local hp = e.char.stats and e.char.stats.health
        e.to = (type(hp) == "table" and hp.current) or e.max
    end
    if #entries > 0 then
        game.activePanel = RestReveal.new({
            entries = entries,
            onDone = function() game.activePanel = nil end,
        })
    else
        game.activePanel = nil
    end
end

-- BIND (a rest's fourth choice, and only offered when there is something to bind): set one wound off
-- every body carrying one (models/wound.lua's Wound.mend).
--
-- IT IS THE ONLY BONE-SETTING BELOW GROUND, and it has to be a choice rather than a service. The Inn
-- did this at a counter for coin, and the price landed only ever on the player who had needed it -- so
-- the building went and the wound became a condition of the expedition instead, ended free by the walk
-- home. What that leaves is a company that is worse for the rest of a dive it may not want to abandon,
-- and this is the answer to that: spend the camp on the bandage and you do not get the whetstone, the
-- map or the refill.
--
-- IT GIVES BACK THE CEILING, NOT THE HEALTH, and the distinction is the whole reason it sits beside
-- Heal rather than replacing it. A wound RESERVES a slice of the pool (Combat.unreservedMax reads the
-- share Wound.stamp writes); binding hands the slice back, and what is standing in it is whatever the
-- body already had. So the dark band on the party strip retreats and the bar does not rise -- you have
-- room again, and filling it is a different stop. Anything else would make this strictly better than
-- Heal and collapse a four-way weigh into a one-way one.
--
-- WHICH IS ALSO WHY THERE IS NO REVEAL PANEL. restHeal's animates each bar from where the fights left
-- it to where the camp put it, and this moves no bar at all; playing that reveal over four still bars
-- would be the game claiming to have done something it did not (the same reason the unpaid tithe below
-- refuses to play it). A toast naming who was bound is the honest report.
function game:restBind()
    if not game.player then return end
    local mended = Wound.mend(game.player, 1)
    -- Named off the roster rather than by id, for the same reason the wound toasts are: a companion's
    -- name can be the one the player typed at creation, and an id is not a person.
    local byId = {}
    for _, char in ipairs(game.player.roster or {}) do byId[char.id] = char end
    local names = {}
    for _, id in ipairs(mended) do
        local char = byId[id]
        names[#names + 1] = (char and char.name) or "Someone"
    end
    if #names > 0 then
        game:pushToast("You bind " .. table.concat(names, ", "))
    else
        -- Reachable only if the ledger emptied between the panel opening and this firing, which nothing
        -- on this screen can do. Said rather than passed over in silence, because a stop the player
        -- spent that reports nothing is indistinguishable from a bug.
        game:pushToast("There is nothing left to bind")
    end
    game.activePanel = nil
end

-- STUDY (a rest's third choice): lift the fog off the objective and every Reliquary on the board, so the
-- run's back half can be planned around the boss and a looting route toward the caches. Reuses the grid's
-- own reveal, the same one Gyeom's Ledger and the Cartographer's Eye relic use.
function game:restStudy()
    local grid = game.grid
    if not grid then return end
    -- STUDYING THE GROUND FINDS ITS DOORS. This is what a Study is for and it had nothing to find until
    -- there were secrets to find -- a whole board's worth at once, which is what makes the Rest's third
    -- option worth taking over a heal on a floor the company has half-walked. Done first, so the reveal
    -- passes below light the ground the doors just opened.
    if grid.findSecrets then
        local opened = 0
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                if grid.cells[y][x].secret then
                    grid.cells[y][x].secret = nil
                    opened = opened + 1
                end
            end
        end
        if opened > 0 then
            game:pushToast(opened == 1 and "A door you had walked past."
                or (opened .. " doors you had walked past."))
        end
    end
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

-- A QUEST'S DOOR, and a descent can no longer come through it.
--
-- There was a branch here that read `if game.descent then endDescent("left", ...)` -- walking away from
-- a descent ended the run where it stood, discarding the floor stack. It was written while that was the
-- mode's only voluntary exit; the ascent stair is that now, and it PAUSES a run rather than ending one.
-- Deleted rather than left unreachable behind the vanished Back button, because a dead branch whose one
-- act is to throw away fifteen floors is a trap for whoever wires the next exit into here.
--
-- The two endings a descent still has are the Hollow Crown (endDescent "won", which does close the run)
-- and a wipe (onLoss, which keeps it and sends the company to the Gate).
local function toHub()
    -- WALKING OUT IS FREE, and this is the line that says so. It used to void the run exactly as a
    -- wipe does -- the two differed only in how the player got there -- which made the objective the
    -- only exit that banked anything. It is the other way round now: the company comes home with
    -- everything it found, and the only thing the day cost is the day.
    --
    -- That is what puts the decision back where it belongs. "Do I take one more spur" is a bet against
    -- the FIGHT rather than against the walk home, and the answer changes with how much you are
    -- already carrying.
    if game.player and game.player.activeRun then
        -- THE DAY IS BANKED ON THE WAY OUT. The ore in the caches used to be paid in by whichever
        -- objective was cleared, which meant walking out with a full pack and nothing to show for it --
        -- the exact opposite of the line above. It banks here instead, alongside the supper being
        -- eaten, so a day spent entirely on foraging comes home with what it carried.
        game:bankHaul()
        clearRun()
        Player.save()
    end
    State.switch(require("states.hub"))
end

-- Back / Esc / pad-Back. Walking out of a QUEST is free now -- the company goes home with everything
-- it picked up and the only thing spent is the day -- so there is nothing to warn about and nothing to
-- ask. It just leaves.
--
-- A DESCENT NEVER REACHES THIS. It used to, and the prompt that stood here ("Give Up the Descent?")
-- was the mode's only voluntary end -- from back when there was no climbing out of one. There is now:
-- the ascent stair, which keeps the floor stack instead of throwing it away, so the give-up ended a run
-- the stair would have paused. The button is gone with it (see backVisible), and this is a quest's
-- door only.
local function leaveQuest()
    toHub()
end

-- ---------------------------------------------------------------------------
-- The battle, hosted rather than switched to
-- ---------------------------------------------------------------------------
--
-- A fight runs INSIDE this state (see the launch in openEncounter). While `game.battle` is set it owns
-- update, draw and every input; the map is still here underneath, still holding the chamber the company
-- walked into, and the moment the fight resolves its callback clears this field and the map has the
-- screen back without a state change, an `enter`, or a frame of black.
--
-- One forwarding rule, applied the same way in every callback below rather than a dispatch table: a
-- table would have to be kept in step with LOVE's callback list by hand, and the list is the one thing
-- main.lua already enumerates.
local function battling() return game.battle ~= nil end

function game.update(dt)
    if battling() then return game.battle.update(dt) end
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

    -- The fight draws OVER the floor it is being fought on, and the floor is still there behind it --
    -- the room, its doors, the plan of the level. Drawn after the map and before this state's own HUD,
    -- because while a battle is running the battle's HUD is the one that answers for the screen.
    if battling() then
        game.battle.draw()
        game.drawCoach()
        return
    end

    game.drawHud()

    if game.activePanel then
        game.activePanel:draw()
    end

    -- The coach bubble sits on TOP of everything, including an open panel: the equip step points at
    -- the stash inside the Loadout screen.
    game.drawCoach()
end

-- The gold coach bubble, pinned to whatever the current step is about. Three of the four steps are the
-- prologue's flight leg and draw nowhere else; the fourth ("wound") is the campaign's, and fires once
-- ever, on the first body carried out of a fight (game:inflictWounds).
function game.drawCoach()
    local step = game.coach
    if not step then return end
    -- The first wound, named on the row of the body that took it. Held off while a panel is open for
    -- the same reason the move hint is: the strip it is pointing at is behind that panel, so a bubble
    -- drawn over the top would be an arrow into a menu. Nothing spends it -- it waits (game:onArrive).
    if step == "wound" and not game.activePanel and partyVisible() then
        local anchor = PartyStatus.rowRect(game.player, game.coachChar, STRIP_X, STRIP_Y)
        local node = hintNode("conversation_tutorial_wound", "wound_hint")
        if anchor and node then
            CoachBubble.draw(Locale.text("conversation_tutorial_wound", node), anchor,
                { prefer = "right", bounds = COACH_BOUNDS })
        end
        return
    end
    if step == "move" and not game.activePanel then
        local node = hintNode("conversation_tutorial_flight", "move_hint")
        CoachBubble.draw(Locale.text("conversation_tutorial_flight", node), game.map:tokenRect(),
            { prefer = "above", bounds = COACH_BOUNDS })
    elseif step == "loadout" and not game.activePanel and game.itemsVisible then
        local node = hintNode("conversation_tutorial_flight", "loadout_hint")
        -- The Items button lives in the top HUD strip, above COACH_BOUNDS; give this one bubble a
        -- bounds that reaches up to the button so it can sit directly BELOW it, tail pointing up.
        -- The LIVE rect, not the authored lane: the flight tutorial hides Back, so Items sits in the
        -- first slot there and a bubble anchored on the old constant would point at empty air.
        local anchor = itemsRect()
        local belowBounds = { x = 20, y = anchor.y,
            w = Scale.WIDTH - 40, h = Scale.HEIGHT - anchor.y - 44 }
        CoachBubble.draw(Locale.text("conversation_tutorial_flight", node), anchor,
            { prefer = "below", key = loadoutKey(), bounds = belowBounds })
    elseif step == "equip" and game.activePanel and game.activePanel.coachAnchor then
        local anchor = game.activePanel:coachAnchor()
        if anchor then
            local node = hintNode("conversation_tutorial_flight", "equip_hint")
            local text, key = Locale.coachLine("conversation_tutorial_flight", node)
            CoachBubble.draw(text, anchor, { prefer = "above", key = key, bounds = COACH_BOUNDS })
        end
    end
end

-- The line at the top of the board. A ground and a day for a campaign trip; a scripted or descent leg
-- keeps naming itself, because those are one authored place and the day means nothing to them.
function game:runTitle()
    local name = (game.quest and game.quest.name) or "Quest"
    if not (game.quest and game.quest.trip) then return name end
    return name .. "  ·  day " .. tostring(game.day or 1)
end

-- THE CHECKLIST: what the houses have posted on this ground, and what is still standing.
--
-- Top-left, starting below the Back / Items / Use row, which owns the first 52 pixels. A cleared line
-- keeps its exact place and greys out rather than dropping off: a list that re-flows as you tick it
-- makes you re-find your place every time, and what you did NOT take is the information -- it is read
-- against what you did.
--
-- Drawn for a trip carrying ANY work at all, one row included. It used to want two, because a row was
-- the quest's title and a ground with one quest already had that title over the map -- the same words
-- twice. A row states the WORK now, which the title never did, so a single piece of work is exactly the
-- case that needs the line: the header says where the company is, and this says what it came to do.
--
-- It sits UNDER the party strip rather than above it, which is the top-left corner's other tenant. The
-- strip is read every time a fight is weighed up and this is read once a spur; the one consulted more
-- keeps the corner.
function game:checklistTop()
    return STRIP_Y + PartyStatus.stripHeight(#(game.player and game.player.roster or {})) + 8
end

-- A ROW IS A SENTENCE NOW, so it is allowed to wrap. It used to be a title, which always fitted on one
-- line at any width worth giving it; "Defeat the crew that took the crate, keep Reagent alive" only just
-- does, and the half a single line would have cut is the `protect` clause -- the loss condition, the one
-- part of the row a player must not miss. Two lines is the cap: past that the column is a paragraph
-- sitting on the board, and nothing in the data reaches even the second line by much.
local CHECKLIST_W = 330    -- the text column, right of the tick box
local CHECKLIST_LINE = 20
local CHECKLIST_MAX_LINES = 2
-- The row's two marks, left of the sentence and in the order they are read: DID I DO IT (the tick box,
-- x + 1, ten pixels) and WHOSE IS IT (the house's mark, ui/vendor_icons.lua). The house sits second
-- because the box is the thing scanned down the column; the mark is looked at once, when the row is
-- being weighed against the other rows.
local CHECKLIST_MARK_X = 16
local CHECKLIST_MARK = 14
local CHECKLIST_TEXT_X = CHECKLIST_MARK_X + CHECKLIST_MARK + 6
local CHECKLIST_DONE = { 0.45, 0.48, 0.44 } -- a row already ticked: greyed, and it keeps its place

local function checklistLines(text)
    local _, lines = hudFont:getWrap(text, CHECKLIST_W)
    if #lines == 0 then return { text } end
    if #lines > CHECKLIST_MAX_LINES then
        local kept = {}
        for i = 1, CHECKLIST_MAX_LINES - 1 do kept[i] = lines[i] end
        -- Everything that did not fit, folded back onto the last line and trimmed there, so the row ends
        -- in an ellipsis rather than stopping mid-clause with no sign that it was cut.
        local tail = lines[CHECKLIST_MAX_LINES]
        for i = CHECKLIST_MAX_LINES + 1, #lines do tail = tail .. " " .. lines[i] end
        kept[CHECKLIST_MAX_LINES] = Theme.ellipsize(tail, hudFont, CHECKLIST_W)
        lines = kept
    end
    return lines
end

-- ...which makes the block's height a question about the text rather than about the row count.
function game:checklistHeight()
    local rows = game:worklist()
    if #rows == 0 then return 0 end
    local h = 6
    for _, row in ipairs(rows) do
        h = h + #checklistLines(row.work or row.name) * CHECKLIST_LINE
    end
    return h
end

function game:drawChecklist()
    local rows = game:worklist()
    if #rows == 0 then return end

    love.graphics.setFont(hudFont)
    local x, y = 16, game:checklistTop()
    for _, row in ipairs(rows) do
        -- The row's colour, held rather than merely set: the house mark below paints in it and then
        -- shades its own detail off it, so the sentence has to be able to get it back.
        local c = row.done and CHECKLIST_DONE or Theme.ink
        love.graphics.setColor(c)
        -- The box is what makes this a list of work rather than a caption, so it is drawn as a box
        -- rather than typed as a character -- a glyph would depend on the font having it. It sits on the
        -- row's FIRST line; a wrapped continuation is indented under the text, not under the box.
        love.graphics.rectangle("line", x + 1, y + 4, 10, 10)
        if row.done then
            love.graphics.line(x + 3, y + 9, x + 6, y + 12)
            love.graphics.line(x + 6, y + 12, x + 10, y + 6)
        end
        -- ...and between the box and the sentence, the HOUSE that posted this row, as the same mark
        -- standing on its tile out on the board (ui/vendor_icons.lua). This is the legend: the mark is
        -- unreadable on a 32px tile until it has been met once beside the words, and this row is the
        -- only place on the whole map screen where the work is spelled out. Unsponsored work simply
        -- leaves the slot empty rather than shuffling the column: two indents in one list would read as
        -- two kinds of row.
        --
        -- IN THE HOUSE'S OWN COLOUR, which is the half of the marker that reads from across the board --
        -- the shape settles which house, the hue is what carried you to the tile in the first place. A
        -- legend that taught only the shape would leave the player learning the louder signal by trial.
        -- A TICKED ROW gives the colour up and greys with the rest of the row: the house is a thing to
        -- go and do, and work already done should not go on being the brightest thing on the screen.
        local hr, hg, hb = VendorIcons.color(row.sponsor)
        if row.done or not hr then hr, hg, hb = c[1], c[2], c[3] end
        VendorIcons.draw(row.sponsor, x + CHECKLIST_MARK_X, y + 3, CHECKLIST_MARK, CHECKLIST_MARK,
            hr, hg, hb)
        love.graphics.setColor(c)
        -- The work, not the title (game:worklist).
        for _, line in ipairs(checklistLines(row.work or row.name)) do
            love.graphics.print(line, x + CHECKLIST_TEXT_X, y)
            y = y + CHECKLIST_LINE
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- One button of the row, at the lane it actually occupies this frame (see BUTTON_ROW).
local function drawRowButton(rect, label)
    love.graphics.setColor(0.20, 0.23, 0.32)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(hudFont)
    love.graphics.printf(label, rect.x, rect.y + rect.h / 2 - 8, rect.w, "center")
end

function game.drawHud()
    -- Back button. Hidden during the flight tutorial, and absent from a descent entirely (backVisible).
    if backVisible() then drawRowButton(backRect(), "Back") end

    -- Items button. Hidden on the flight tutorial until the first chest is opened (game.itemsVisible),
    -- so the Loadout panel is introduced only once there is loot to arrange.
    if game.itemsVisible then drawRowButton(itemsRect(), "Items") end

    -- Potions button (drink a draught), beside Items. Same visibility gate save for the flight tutorial.
    if useVisible() then drawRowButton(useRect(), "Potions") end

    -- Send Mule, last in the row and only where it is legal (muleVisible).
    if muleVisible() then drawRowButton(muleRect(), "Send Mule") end

    -- Always-on party HP/mana strip: the run's attrition, legible while routing (models/player.lua).
    -- Pass the mouse (logical space) so the per-companion ability badge shows its tooltip on hover.
    if partyVisible() then
        local mx, my
        if InputMode.isMouse() then mx, my = Scale.toGame(love.mouse.getPosition()) end
        PartyStatus.drawStrip(game.player, STRIP_X, STRIP_Y, mx, my, game.abilityState)
        -- THE RELIC TRAY, directly under the vitals rather than in the opposite corner. Both readouts
        -- answer the same question -- how is this expedition doing -- and a pile parked across the screen
        -- from the company carrying it is a pile the player checks once and then forgets while routing.
        -- Chips rather than named rows, because the shelf stacks now and a dozen named rows is half the
        -- screen (see ui/relic_strip.lua's header for the whole argument).
        RelicStrip.draw(game.relicState, STRIP_X,
            STRIP_Y + PartyStatus.stripHeight(#((game.player and game.player.roster) or {})) + 6, mx, my)

        -- WHAT THIS RUN IS CARRYING. Stacked under the relics, because both answer the same question --
        -- what has this expedition accrued -- and because the decision it feeds is taken out here on the
        -- map, not in a panel. Without a figure on screen there is nothing to be greedy about: the
        -- push-one-more-spur choice is a bet, and a bet needs a stake the player can see. It also means
        -- a wipe takes something the player was watching rather than something they find out about.
        --
        -- Absent entirely when the run has found nothing yet -- an empty ledger is not information, and
        -- a row of zeroes would read as a broken readout.
        -- No longer offset by the relic readout: the tray moved to the left column under the vitals, so
        -- the right edge is the haul's alone and it starts where the relics used to.
        local x = Scale.WIDTH - 16
        local y = 60
        love.graphics.setFont(hudFont)
        if game.haul then
            -- Named for what it IS, not what it counts: "carried" says the thing the number turns on --
            -- that none of this is yours yet.
            love.graphics.setColor(Theme.muted)
            love.graphics.printf("Carried this run", x - 240, y, 240, "right")
            local parts = {}
            if game.haul.items > 0 then
                parts[#parts + 1] = game.haul.items .. (game.haul.items == 1 and " item" or " items")
            end
            -- WHAT THE VALUABLES IN THAT COUNT ARE WORTH, folded in with the coin rather than given a
            -- figure of its own: to the player they are the same number -- gold that reaches the city --
            -- and splitting "12g earned" from "900g carried" into two rows would be reporting the
            -- plumbing. Summed, because the decision it feeds is one decision.
            local coin = (game.haul.gold or 0) + (game.haul.worth or 0)
            if coin > 0 then parts[#parts + 1] = coin .. "g" end
            if game.haul.materials > 0 then parts[#parts + 1] = game.haul.materials .. " stock" end
            love.graphics.setColor(Theme.accentAmber)
            love.graphics.printf(table.concat(parts, "   "), x - 240, y + 18, 240, "right")
            love.graphics.setColor(1, 1, 1)
            y = y + 44
        end

        -- THE RUN'S PURSE (models/scrip.lua), between the haul and the mule -- which is where it belongs
        -- in the reading as well as on the screen: the haul is what goes home, the mule is what will
        -- carry it, and this is the one number that does neither.
        --
        -- IT DRAWS ON AN EMPTY PURSE, on the mule's rule rather than the haul's. Scrip is a spending
        -- limit, and a limit is most worth stating at the moment it is binding -- a player standing in
        -- front of a Merchant with nothing needs to be told that before they open it, not after.
        --
        -- A BANKED RESOURCE SHOWS ITS COUNT: this is the only place the purse is legible outside the two
        -- panels that spend it, and a currency the player cannot see between stops is a currency they
        -- cannot plan around.
        if game.descent then
            love.graphics.setColor(Theme.muted)
            love.graphics.printf("Scrip", x - 240, y, 240, "right")
            -- Amber when there is something to spend, muted at nothing -- a purse at zero is not a
            -- warning (the mule's full IS one), it is simply the state the run opens in.
            love.graphics.setColor(Scrip.get(game.player) > 0 and Theme.accentAmber or Theme.muted)
            love.graphics.printf(Scrip.get(game.player) .. "", x - 240, y + 18, 240, "right")
            love.graphics.setColor(1, 1, 1)
            y = y + 44
        end

        -- THE MULE, under the haul it is carrying (models/mule.lua).
        --
        -- IT DRAWS ON AN EMPTY BAG, unlike the haul above, and the two are different for a reason: the
        -- haul is a ledger and an empty one is not information, while the mule is a CAPACITY and how
        -- much of it is left is the whole decision. A player about to open a chest needs to know they
        -- have one slot, and "nothing carried yet" is exactly the state in which that is most worth
        -- saying quietly rather than not at all.
        --
        -- Only underground. There is no mule on a campaign road and never was; a readout there would be
        -- naming an object the player does not have.
        if game.descent then
            local away = Mule.fightsAway(game.descent)
            love.graphics.setColor(Theme.muted)
            love.graphics.printf("Pack mule", x - 240, y, 240, "right")
            if away > 0 then
                -- The transition the player is waiting on, said as what it costs rather than as a bar:
                -- an absence is measured in the thing that ends it, which is fights.
                love.graphics.setColor(Theme.cursor)
                love.graphics.printf("on the road  " .. away ..
                    (away == 1 and " fight" or " fights"), x - 240, y + 18, 240, "right")
            else
                local load, cap = Mule.load(game.player), Mule.capacity(game.player)
                -- Full wears the hostile accent, because it is the one reading that changes what the
                -- player may do next. Everything below it is bookkeeping and stays quiet.
                love.graphics.setColor(load >= cap and Theme.accentWeapon or Theme.accentAmber)
                love.graphics.printf(load .. " of " .. cap, x - 240, y + 18, 240, "right")
            end
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- Companion-ability toasts, stacked just under the party strip so ability feedback groups with the
    -- party it comes from. Newest on top; each fades over its life.
    if game.toasts and #game.toasts > 0 then
        love.graphics.setFont(hudFont)
        -- Under the checklist when there is one, so a toast never lands on top of the day's work list.
        local baseY = game:checklistTop() + game:checklistHeight()
        for i, toast in ipairs(game.toasts) do
            local a = math.min(1, toast.t / 0.6) -- fade out over the last 0.6s
            love.graphics.setColor(0.85, 0.9, 0.7, a)
            love.graphics.print(toast.text, 18, baseY + (i - 1) * 20)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- WHERE THE COMPANY IS AND WHAT DAY IT IS. The run used to be named after a quest, which was right
    -- while it was one; a day on the tundra can carry three of them and picking one of the three to
    -- print would be arbitrary. The ground is what is true of the whole run, and the checklist below
    -- says which pieces of work are standing on it.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(game:runTitle(), 0, 20, Scale.WIDTH, "center")

    game:drawChecklist()

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
    else
        -- ...AND THE SAME LINE FOR A PIECE OF POSTED WORK, which is where the FIRST-CLEAR BONUS is told.
        --
        -- An errand pays a purse the first time it is cleared and losing the fight spends that purse for
        -- good (models/errand.lua's Errand.fail), so it is a figure the player weighs BEFORE committing --
        -- exactly the thing this readout was added for, and exactly the thing that cannot go on the
        -- marker: at a 32px tile a mark is under two pixels across, which is the lesson the muster pips
        -- already paid for. So the bonus is named here, in words, at the moment of deciding, and once it
        -- is spent the clause is simply absent -- every errand carries one, so its absence is the mark.
        --
        -- The NUMBER rather than "bonus rewards", because a figure is what a decision is made against: 80
        -- gold is worth walking into a fight under-strength for and a word is not.
        local work = game.map:hoveredWork()
        local def = work and Quest.defs[work.encounter.questId]
        if def then
            local line = work.encounter.name or def.name or "Somebody's work"
            if (def.rewardGold or 0) > 0 and not Errand.failedOnce(game.player, work.encounter.questId) then
                line = line .. "  -  first clear pays " .. def.rewardGold .. " gold"
            end
            local pays = game:payoutPhrase(work.encounter)
            if pays then line = line .. "  -  leaves " .. pays end
            love.graphics.setFont(hudFont)
            love.graphics.setColor(0.72, 0.72, 0.66)
            love.graphics.printf(line, 0, total > 0 and 72 or 52, Scale.WIDTH, "center")
        end
    end

    love.graphics.setFont(hudFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse
    -- otherwise. The items key only appears once the Loadout button itself does.
    local items = game.itemsVisible and (InputMode.isGamepad() and "Y: items      " or "I: items      ") or ""
    local use = useVisible() and (InputMode.isGamepad() and "X: potions      " or "U: potions      ") or ""
    -- ...and the mule, on the same rule as its button: named only where the move is legal.
    local mule = muleVisible() and (InputMode.isGamepad() and "LB: send mule      " or "M: send mule      ") or ""
    -- The "back to hub" hint is dropped alongside the button itself -- during the flight tutorial, and
    -- on every floor of a descent, which has no Back button any more (see backVisible). It read
    -- "Esc: end run" down there, which was true and was the problem: one keystroke, on the key every
    -- other screen uses to close a panel, discarding the whole floor stack.
    local back = backVisible() and (InputMode.isGamepad() and "Back: hub" or "Esc: hub") or ""
    local hint = InputMode.isGamepad()
        and ("Move: D-pad / Stick      " .. items .. use .. mule .. back)
        or ("Move: WASD / Arrows / click adjacent tile      " .. items .. use .. mule .. back)
    love.graphics.printf(hint, 0, Scale.HEIGHT - 30, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)

    -- THE NUMBERS THIS BOARD WAS DEALT FROM, in a development build only (ui/seed_readout.lua). The
    -- board is the thing a bug actually stands on, so this is where the readout earns its corner: a
    -- floor with no way down, a stop seated in a wall, a fight that should not be there -- all of them
    -- are unreportable without the rift and the depth, and unreproducible from a screenshot.
    SeedReadout.draw(game.player, game.descent)
end

function game.mousemoved(x, y, dx, dy)
    if battling() then return game.battle.mousemoved(x, y, dx, dy) end
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
    if (backVisible() and backContains(x, y)) or (game.itemsVisible and rectContains(itemsRect(), x, y))
        or (useVisible() and rectContains(useRect(), x, y))
        or (muleVisible() and rectContains(muleRect(), x, y)) then
        return "hand"
    end
    return "arrow"
end

function game.mousepressed(x, y, button)
    if battling() then return game.battle.mousepressed(x, y, button) end
    if game.activePanel then
        game.activePanel:mousepressed(x, y, button)
    elseif button == 1 and backVisible() and backContains(x, y) then
        leaveQuest()
    elseif button == 1 and game.itemsVisible and rectContains(itemsRect(), x, y) then
        openLoadout()
    elseif button == 1 and useVisible() and rectContains(useRect(), x, y) then
        openConsumables()
    elseif button == 1 and muleVisible() and rectContains(muleRect(), x, y) then
        sendMule()
    else
        game.map:mousepressed(x, y, button)
    end
end

-- Only panels that scroll or drag define these; the overworld map handles neither.
function game.mousereleased(x, y, button)
    if battling() then return game.battle.mousereleased(x, y, button) end
    local panel = game.activePanel
    if panel and panel.mousereleased then panel:mousereleased(x, y, button) end
end

function game.wheelmoved(dx, dy)
    if battling() then return game.battle.wheelmoved(dx, dy) end
    local panel = game.activePanel
    if panel and panel.wheelmoved then panel:wheelmoved(dx, dy) end
end

function game.keypressed(key)
    if battling() then return game.battle.keypressed(key) end
    if game.activePanel then
        game.activePanel:keypressed(key)
    elseif key == "escape" and backVisible() then
        leaveQuest()
    elseif key == "i" and game.itemsVisible then
        openLoadout()
    elseif key == "u" and useVisible() then
        openConsumables()
    elseif key == "m" and muleVisible() then
        sendMule()
    else
        game.map:keypressed(key)
    end
end

function game.gamepadpressed(joystick, button)
    if battling() then return game.battle.gamepadpressed(joystick, button) end
    if game.activePanel then
        game.activePanel:gamepadpressed(joystick, button)
    elseif button == "back" and backVisible() then
        leaveQuest()
    elseif button == "y" and game.itemsVisible then
        openLoadout()
    elseif button == "x" and useVisible() then
        openConsumables()
    elseif button == "leftshoulder" and muleVisible() then
        sendMule()
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
