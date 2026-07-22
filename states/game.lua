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
local EncounterModel = require("models.encounter")
local Party = require("ui.panels.party")
local CoachBubble = require("ui.coach_bubble")
local Locale = require("models.locale")

local game = {}

local titleFont = love.graphics.newFont(22)
local hudFont = love.graphics.newFont(16)

-- Flight-leg coach lines (data/conversations/tutorial_flight.lua), keyed by node id and resolved
-- through Locale so {select}/localization behave exactly as they do in a spoken line. Loaded once.
local FLIGHT_HINTS
local function hintNode(id)
    if not FLIGHT_HINTS then
        FLIGHT_HINTS = {}
        for _, node in ipairs(require("data.conversations.tutorial_flight").script) do
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

-- prestige defaults to 1 when a quest is launched without it (e.g. dev/test).
--
-- `onComplete` (optional) reroutes the objective-win: when set, clearing the objective calls it
-- INSTEAD of the normal pay-out-and-return-to-hub flow. The prologue uses this to run its flight leg
-- as a real overworld traversal and then hand control back to its own sequencer (states/prologue.lua)
-- rather than ending at the hub. A normal board quest passes no onComplete and behaves as before.
function game.enter(self, quest, prestige, player, onComplete)
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

    -- A `layout` names a hand-authored map (data/overworld/<id>.lua): a fixed trail with its stops
    -- pinned in place, used where a rolled maze won't do -- the prologue's tutorial leg, where the
    -- chest has to be the first thing ahead. The route's `always` list still supplies each stop's
    -- content; the layout only fixes where each one sits. Every other quest generates a fresh map.
    if mp.layout then
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
            encounterCount = { min = encSpec.min or 6, max = encSpec.max or encSpec.min or 6 },
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
    game.map = OverworldMap.new(game.grid, {
        onEncounter = function(cell) game:openEncounter(cell) end,
        -- Fog-of-war radius from the active party (a torch-carrier widens it).
        visionRadius = Player.visionRadius(player),
    })

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
    game.coach = nil

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
            party = game.player and game.player.party or {},
            -- The player's stash, by reference: an item stolen mid-battle by a thief with a full
            -- grid is appended straight to it, so a theft survives whatever the battle does next.
            stash = game.player and game.player.stash,
            -- Victory resumes THIS overworld (no regenerate); the objective completes
            -- the quest instead. See the file header on why enter is skipped here.
            onWin = function(spoils)
                cell.cleared = true
                game.activePanel = nil
                if kind == "objective" then
                    game.complete = true
                    -- Prologue (or any scripted caller) reroute: hand the cleared objective back to
                    -- its sequencer instead of paying out and going home. No reward, no save -- the
                    -- prologue is not a board quest.
                    if game.onComplete then
                        game.onComplete()
                        return
                    end
                    -- The single payout seam: gold, prestige, and sponsor reputation are
                    -- granted here, once, and the game saves. Losing the quest (onLoss)
                    -- pays nothing, so a wipe costs the run.
                    game.reward = Quest.complete(game.player, game.quest)
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
                        if followUp then
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
                    State.current = game
                end
            end,
            -- "Try Again": restart this same fight from the pre-fight snapshot. Restore the party in
            -- place (so game.player and Player.active -- the same table -- both carry the fresh
            -- roster/party/inventory), refill resources, and re-open the un-cleared cell.
            onRetry = retrySnapshot and function()
                local fresh = Save.restore(retrySnapshot)
                if fresh then
                    for k, v in pairs(fresh) do game.player[k] = v end
                end
                Player.restore(game.player) -- a retry is a fresh attempt: the party opens whole
                game:openEncounter(cell)
            end or nil,
            -- "Return to Hub": give the fight up and fail the quest (no reward). Offered only once there
            -- is a hub to return to -- the prologue's flight leg (game.tutorial) has none yet, so there
            -- the panel shows Try Again alone.
            onLoss = (not game.tutorial) and function() State.switch(require("states.hub")) end or nil,
        })
        return
    end

    -- A narrative "Choose..." stop: no modal of its own. The branching dialogue overlay (ui/dialogue
    -- .lua) IS the encounter, and a choice's `effect` grants loot / sets a story flag on commit
    -- (models/story_effect.lua, wired in Conversation.play). Cleared before it plays so stepping back
    -- onto the tile can't replay it.
    if kind == "event" then
        cell.cleared = true
        if cell.encounter.conversation then
            require("models.conversation").play(cell.encounter.conversation)
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
        if #loot == 0 then cell.cleared = true; return end -- empty cache: nothing to reveal
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
            end,
            onCancel = function() game.activePanel = nil end,
        })
        return
    end

    game.activePanel = EncounterPanel.new({
        encounter = cell.encounter,
        onResolve = function()
            cell.cleared = true
            game.activePanel = nil
            game:resolveNonCombat(cell)
        end,
        onClose = function() game.activePanel = nil end,
    })
end

-- Apply the outcome of a non-combat modal once the player confirms it. Treasure has its own reveal
-- panel (see openEncounter); this now handles only:
--   rest -> refill every resource on the roster to full (Player.restore).
function game:resolveNonCombat(cell)
    local enc = cell.encounter
    if enc.kind == "rest" then
        if game.player then Player.restore(game.player) end
        -- A rest may also carry loot: the flight leg's last camp hands over a class ability before the
        -- champion (states/prologue.lua). The grant is banked UP FRONT so dismissing the reveal can
        -- never cost it, and the chest reveal is reused purely to SHOW the find -- its item card and
        -- tooltip are where the new ability's mechanic is read, which is the whole point of the stop.
        local loot = enc.loot or {}
        if #loot > 0 and game.player then
            for _, id in ipairs(loot) do Player.grantItem(game.player, id) end
            game.activePanel = LootReveal.new({
                encounter = enc,
                loot = loot,
                description = "The party makes camp and sorts its kit for the road ahead.",
                onCollect = function() game.activePanel = nil end,
                onCancel = function() game.activePanel = nil end,
            })
        end
    end
end

local function toHub()
    State.switch(require("states.hub"))
end

function game.update(dt)
    if game.activePanel then
        game.activePanel:update(dt)
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
        CoachBubble.draw(Locale.text("tutorial_flight", node), game.map:tokenRect(),
            { prefer = "above", bounds = COACH_BOUNDS })
    elseif step == "loadout" and not game.activePanel and game.itemsVisible then
        local node = hintNode("loadout_hint")
        -- The Items button lives in the top HUD strip, above COACH_BOUNDS; give this one bubble a
        -- bounds that reaches up to the button so it can sit directly BELOW it, tail pointing up.
        local belowBounds = { x = 20, y = itemsButton.y,
            w = Scale.WIDTH - 40, h = Scale.HEIGHT - itemsButton.y - 44 }
        CoachBubble.draw(Locale.text("tutorial_flight", node), itemsButton,
            { prefer = "below", key = loadoutKey(), bounds = belowBounds })
    elseif step == "equip" and game.activePanel and game.activePanel.coachAnchor then
        local anchor = game.activePanel:coachAnchor()
        if anchor then
            local node = hintNode("equip_hint")
            local text, key = Locale.coachLine("tutorial_flight", node)
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
    -- The "back to hub" hint is dropped alongside the button itself during the flight tutorial.
    local back = backVisible() and (InputMode.isGamepad() and "Back: hub" or "Esc: hub") or ""
    local hint = InputMode.isGamepad()
        and ("Move: D-pad / Stick      " .. items .. back)
        or ("Move: WASD / Arrows / click adjacent tile      " .. items .. back)
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
    if (backVisible() and backContains(x, y)) or (game.itemsVisible and rectContains(itemsButton, x, y)) then
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
    else
        game.map:gamepadpressed(joystick, button)
    end
end

return game
