-- Battle state: reached when the player engages a combat encounter on the overworld
-- (states/game.lua -> game:openEncounter). It builds an 8x8 arena from the quest's
-- biome (models/arena.lua), placing the party on the near side and the encounter's
-- prestige-scaled enemy roster on the far side, then drives a live models/combat.lua
-- timeline: units act in turn order (lowest `time` first), the player moves/acts the
-- current party unit, and enemies act via Combat.planEnemyAction. Victory/defeat come
-- from Combat.evaluate, firing the overworld-supplied onWin/onLoss.
--
-- Player interaction (mouse + keyboard + gamepad, per the project standard):
--   * A party unit's turn defaults to MOVE mode: blue reachable tiles are shown; picking
--     one moves the unit and ends its turn. Hovering a tile previews the turn order.
--   * Selecting an item (click a slot / number key / gamepad Y) ARMS it: its range is shown
--     in red. Confirming on a valid target resolves it; re-selecting the item cancels.
--   * Forfeit button / Esc / gamepad B (when not armed) = concede the battle (a loss).
--   * F5 saves the current arena to data/arenas/ for hand-editing (dev only).

local Scale = require("scale")
local InputMode = require("input_mode")
local Arena = require("models.arena")
local BattleMap = require("ui.battle_map")
local CombatPanel = require("ui.combat_panel")
local CombatFx = require("ui.combat_fx")
local CombatLog = require("ui.combat_log")
local StatusTooltip = require("ui.status_tooltip")
local ItemTooltip = require("ui.item_tooltip")
local TileTooltip = require("ui.tile_tooltip")
local InventoryPeek = require("ui.inventory_peek")
local ActionPreview = require("ui.action_preview")
local Character = require("models.character")
local Discipline = require("models.discipline")
local Growth = require("models.growth")
local Item = require("models.item")
local Combat = require("models.combat")
local Command = require("models.command") -- the vocabulary a live duel speaks (models/netplay.lua)
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Status = require("models.status")
local EncounterModel = require("models.encounter")
local EncounterBattle = require("models.encounter_battle") -- the spec + the payout, shared with the walk-off path
local Tutorial = require("models.tutorial")
local Intent = require("models.intent")
local Sound = require("models.sound")
local Conversation = require("models.conversation")
local TutorialPrompt = require("ui.tutorial_prompt")
local CoachBubble = require("ui.coach_bubble")
local Glyphs = require("ui.glyphs")
local Theme = require("ui.theme")
local BattleSummary = require("ui.panels.battle_summary")
local WindupChooser = require("ui.panels.windup_chooser")
local SpendChooser = require("ui.panels.spend_chooser")
local BenchChooser = require("ui.panels.bench_chooser")
local DebugMenu = require("ui.panels.debug_menu")
local CloseButton = require("ui.close_button")
local Debug = require("models.debug")
local ScreenFx = require("ui.screen_fx")
local Settings = require("models.settings")
local SettingsMenu = require("ui.settings_menu")
local Cursor = require("ui.cursor")
local DeployPhase = require("ui.deploy_phase")
local Player = require("models.player")

local battle = {}

local titleFont = Theme.display(22)
local hudFont = Theme.display(16)
local hintFont = Theme.body(13) -- control hint: dense, so it keeps the plain body face and fits one line

-- The in-battle settings overlay (see openSettings): reachable from the hamburger drawer without a
-- state switch, since switching away and back would re-enter battle.enter and rebuild the fight.
local overlayTitleFont = Theme.display(30)
local overlayRowFont = Theme.display(18)
local overlayBodyFont = Theme.body(14)

local PANEL_W = CombatPanel.WIDTH
-- A left column, mirroring the right combat panel, that houses the buttons and the docked
-- tooltips (see drawLeftColumn). The board is centred in the gap between the two columns.
-- Slimmer than the right panel (it only holds buttons + a tooltip), to give the board room.
local LEFT_W = 264

-- The gutter under the board: the free strip between the left button column and the combat panel,
-- below the last row of tiles. Mirrors ui/tutorial_prompt.lua's own PAD/GAP/BOTTOM so the mentor's
-- panel and a LESSON's opening conversation land in exactly the same rect -- one speaks during the
-- lesson and the other before it, and they should not sit an inch apart while doing it. Only a guided
-- fight stages its opening here; every other battle opening uses the ordinary full-screen scene UI.
local GUTTER_PAD = 16    -- inset from the columns on either side
local GUTTER_GAP = 8     -- between the board's bottom edge and the box
local GUTTER_BOTTOM = 12 -- between the box and the bottom of the screen
local BOARD_TILE = 60 -- on-screen tile size (< the arena's logical 64), for breathing room
local BOARD_TOP = 104 -- fixed board top (below the 3-line HUD); the freed bottom holds the log
local AI_DELAY = 0.35 -- seconds between enemy actions, so each move is watchable
-- Seconds a walking unit rests on every tile it steps onto, the destination included. A move is
-- played out one tile at a time (see startWalk) rather than teleporting, so the route a unit takes
-- is visible -- and so is what it walks into, since a trap springs or a hazard bites on the very
-- beat the unit lands on that tile. Applies to both sides.
local MOVE_STEP = 0.25
-- Minimum beat held after an action that actually landed a hit (dealt damage, healed, or felled a
-- unit) before the turn hands off, so the strike and its aftermath read. The hold runs until BOTH
-- this has elapsed AND the sprite reactions have finished (battle.fx:busy); a turn that changed
-- nothing visible (a bare move, a wait) skips it entirely and hands off at once.
local IMPACT_PAUSE = 0.5

-- The left column's controls fold behind a single hamburger toggle. Closed (the default), only
-- MENU_BUTTON is drawn and the whole column below it belongs to the docked tooltips -- which is what
-- buys the terrain box its guaranteed room in drawTileTooltip. Open, the entries drop beneath it.
-- Every entry also has a key binding of its own (Esc / pad B = forfeit, L / left-shoulder = log,
-- T / left-stick = threats, V / pad A = auto), so the menu is a mouse affordance and never the only way to
-- reach them.
local MENU_BUTTON = { x = 16, y = 16, w = 36, h = 36 }
-- Clickable "Forfeit" entry so a mouse-only player can bail out (counts as a loss). Wait/Focus/
-- Defend is not here: it lives in a long button under the item grid (ui/combat_panel.lua).
local forfeitButton = { x = 16, y = 60, w = 130, h = 36 }
-- Toggles the combat-log panel on the left (also L / gamepad left-shoulder).
local logButton = { x = 16, y = 104, w = 130, h = 36 }
-- Toggles the danger overlay that paints EVERY enemy's reach-and-strike range purple across the
-- whole board (also T / gamepad left-stick), so the player can survey all threats at once.
local rangesButton = { x = 16, y = 148, w = 130, h = 36 }
-- Hands the WHOLE player side to the AI (also V / gamepad A): sets battle.autoAll, which arms auto-battle for
-- every player-controlled unit on its turn -- the same think-pause the Tactics-tab switch grants a
-- single unit. Any input still takes the current turn straight back (reclaimAutoTurn); the flag then
-- re-arms the next unit, so "auto" holds across the side until the button is pressed off.
local autoButton = { x = 16, y = 192, w = 130, h = 36 }
-- Sends a body from the bench onto an OPEN slot (models/combat.lua's Combat.reinforce). A drawer entry
-- rather than a button under the item grid, because it is not a turn action -- nobody spends anything for
-- it, and it can be taken while any of the player's units is in hand. Drawn only when the fight has a
-- bench at all, and greyed with its reason otherwise.
--
-- No longer the way the move is FOUND: battle.offerOpenSlot raises the chooser the moment a body drops,
-- which is the only beat at which a slot opens. This is the way back to it -- after a prompt was
-- declined, or in a fight that deployed under the cap and so never had a body fall to announce one.
-- That is the right job for a menu entry, and the wrong one for a play the player has to notice.
local reinforceButton = { x = 16, y = 236, w = 130, h = 36 }
-- Opens the settings overlay (volumes, tooltips, effects) over the paused fight -- so a player can
-- turn the music down mid-battle without abandoning the encounter.
local settingsButton = { x = 16, y = 280, w = 130, h = 36 }
-- Playback-speed cycler, drawn only while whole-side auto is ON (it is meaningless otherwise -- the
-- player sets the pace of their own turns by taking them). Sits flush to the right of the Auto
-- button as a paired control. Clicking it -- or F / gamepad right-stick -- steps battle.autoSpeed
-- through SPEED_STEPS, which scales the gameplay clock in battle.update. Unlike every other input,
-- adjusting speed does NOT reclaim the auto turn: changing how fast the AI plays is not taking over.
local speedButton = { x = 150, y = 192, w = 56, h = 36 }
local SPEED_STEPS = { 1, 2, 3 }
-- Debug-only shortcut that decides the fight instantly, so a developer can jump straight to the win
-- follow-up (spoils screen, overworld onWin) without playing the encounter out. Gated on
-- Debug.enabled -- it never renders or takes a click in a release build. There is deliberately no
-- matching "Lose": Forfeit above is that button, in every build, and two ways to concede one fight is
-- one too many. Sits BELOW Settings, in the drawer's last row: it once had Settings' own y, which drew
-- "Win" over "Settings" while mousepressed still tested Settings first -- so the debug button silently
-- opened the settings overlay instead of ending the fight.
local winButton = { x = 16, y = 324, w = 130, h = 36 }
-- The drawer's whole content BEFORE the bell (the deployment phase): Settings, and nothing else. Every
-- other entry describes a fight that is not running yet -- there is nothing to forfeit, the log has no
-- lines and its rect is the deployment strip's, and Threats / Auto / Reinforce all read a turn order
-- that has not started. So it takes the drawer's FIRST slot rather than settingsButton's own: a lone
-- entry belongs under the hamburger, not half-way down an empty column.
--
-- A field on `battle` rather than another file local, and so are the three helpers further down
-- (drawMenuButton / drawMenuEntry / menuHoverCue): this chunk is within a handful of names of Lua
-- 5.1's ceiling of 200 locals per function, and going over it is a SYNTAX error at load -- one no
-- spec catches, because nothing headless requires a state that draws. Add module-level names here as
-- `battle.*`, not `local`.
battle.deploySettingsButton = { x = 16, y = 60, w = 130, h = 36 }
-- The band the deployment phase stacks its own controls down (Loadout, Auto-Fill, Clear, Auto, the
-- bell): straight under that lone drawer entry, at the entries' own width, so the column reads as one
-- run of plates whether the drawer is open or shut. The phase lays the buttons out from here and docks
-- its hover boxes below them (ui/deploy_phase.lua). Every fight before the bell has these controls, so
-- unlike the drawer this band is not conditional on anything.
battle.deployControlRect = { x = 16, y = 104, w = 130 }

-- The y the docked tooltip stack may rise to: just under the hamburger while the menu is closed, or
-- under its last visible entry while it is open, so the menu and the tooltips never draw over each
-- other. Read as drawTileTooltip's `dockTop`, and handed to the deployment phase for its own docked
-- hover boxes (ui/deploy_phase.lua).
local function menuBottom()
    if not battle.menuOpen then return MENU_BUTTON.y + MENU_BUTTON.h + 8 end
    if battle.deploy then return battle.deploySettingsButton.y + battle.deploySettingsButton.h + 8 end
    local last = Debug.enabled and winButton or settingsButton
    return last.y + last.h + 8
end

-- The 3x3 item grid mapped onto the number KEYPAD by physical position: kp7 is the top-left slot,
-- kp3 the bottom-right, matching the grid's row-major layout so the keys sit where the slots do.
-- kp0, the top-row 0, and Space are all the Wait action. (The top-row 1-9 keys still arm slots 1-9 in order.)
local KEYPAD_SLOT = {
    kp7 = 1, kp8 = 2, kp9 = 3,
    kp4 = 4, kp5 = 5, kp6 = 6,
    kp1 = 7, kp2 = 8, kp3 = 9,
}

local function pointIn(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

-- Whether the player may hand their side (or a single unit) to the AI. Auto-battle is disallowed for
-- the whole of a tutorial fight -- a lesson exists to make the student take the actions themselves, so
-- the Auto control is hidden, its key/pad bindings go dead, and any per-unit autoBattle flag is ignored.
local function autoAllowed()
    return not battle.tutorial
end

-- Whether a point is over one of the drawer's entries (never the hamburger itself, which is handled
-- on its own as the toggle). False while the menu is closed: closed, those rects belong to the
-- docked tooltip column. Shared by mousepressed -- which folds the drawer away on any click that
-- misses it -- and cursorKind, so the hand cursor and the click regions can't drift apart.
local function overMenuEntry(x, y)
    if not battle.menuOpen then return false end
    if battle.deploy then return pointIn(battle.deploySettingsButton, x, y) end
    return pointIn(forfeitButton, x, y) or pointIn(logButton, x, y) or pointIn(rangesButton, x, y)
        or (autoAllowed() and pointIn(autoButton, x, y)) or pointIn(settingsButton, x, y)
        or (autoAllowed() and battle.autoAll and pointIn(speedButton, x, y))
        or (battle.hasBench and pointIn(reinforceButton, x, y))
        or (Debug.enabled and pointIn(winButton, x, y))
end

-- An id for whichever HUD button the point is over, or nil -- so battle.mousemoved can sound a hover
-- cue on the CROSSING from one button to the next (not every frame the pointer rests on one). The
-- hamburger cues whether the drawer is open or shut; the entries only while it is open (closed, their
-- rects belong to the tooltip column). Mirrors overMenuEntry, but names the button rather than just
-- answering yes/no.
local function hoveredMenuButton(x, y)
    if pointIn(MENU_BUTTON, x, y) then return "menu" end
    if not battle.menuOpen then return nil end
    if battle.deploy then
        return pointIn(battle.deploySettingsButton, x, y) and "settings" or nil
    end
    if pointIn(forfeitButton, x, y) then return "forfeit" end
    if pointIn(logButton, x, y) then return "log" end
    if pointIn(rangesButton, x, y) then return "threats" end
    if autoAllowed() and pointIn(autoButton, x, y) then return "auto" end
    if battle.hasBench and pointIn(reinforceButton, x, y) then return "reinforce" end
    if pointIn(settingsButton, x, y) then return "settings" end
    if autoAllowed() and battle.autoAll and pointIn(speedButton, x, y) then return "speed" end
    if Debug.enabled and pointIn(winButton, x, y) then return "win" end
    return nil
end

-- Tear the settings overlay down (its Back row, the X, Esc/B, or a click on the dim backdrop). Leaving
-- the fight exactly as it was frozen -- update() is gated on this being nil, so nothing moved.
local function closeSettings()
    battle.settingsMenu = nil
    battle.settingsClose = nil
    battle.settings = nil
end

-- Raise the settings list as a modal over the paused fight. A centred panel sized to the option list,
-- with the shared SettingsMenu widget inside it, an X and a click-off to close. NOT a state switch:
-- battle.enter rebuilds the whole encounter, so leaving for the settings screen and coming back would
-- restart the battle. This keeps the board frozen behind the panel and returns to it untouched.
local function openSettings()
    battle.menuOpen = false
    local rows = #Settings.defs + 1 -- every option, plus the Back row
    local rowH, rowSp, listW = 40, 8, 620
    local listH = rows * rowH + (rows - 1) * rowSp
    local padTop, padBottom = 64, 78 -- title above the list; description + hint below it
    local panelW = listW + 60
    local panelH = padTop + listH + padBottom
    local panelX = (Scale.WIDTH - panelW) / 2
    local panelY = (Scale.HEIGHT - panelH) / 2
    battle.settings = { x = panelX, y = panelY, w = panelW, h = panelH }
    battle.settingsMenu = SettingsMenu.build(closeSettings, {
        buttonWidth = listW,
        buttonHeight = rowH,
        spacing = rowSp,
        startY = panelY + padTop,
        centerX = Scale.WIDTH / 2,
        font = overlayRowFont,
    })
    battle.settingsClose = CloseButton.new(panelX + panelW, panelY)
end

-- Whether an item carries a given tag (Combat's own hasTag is private). Used by the context cursor
-- to tell a physical strike ("physical") from a spell ("magical").
local function itemHasTag(item, want)
    local tags = item and item.tags
    if not tags then return false end
    for _, t in ipairs(tags) do
        if t == want then return true end
    end
    return false
end

local function charName(id)
    local def = id and Character.defs[id]
    return (def and def.name) or id or "the target"
end

-- Human-readable objective line for the HUD. `protect` is a loss condition layered over
-- whatever the win type is, so it reads as a second clause rather than replacing the first.
local function objectiveText(obj)
    local text
    -- Timed objectives (survive/defend/hold) name the GOAL only; the remaining time is drawn as a
    -- live tick countdown beside the hourglass glyph (drawObjectiveClock), because "ticks" is the unit
    -- the whole game is quoted in and "turns" is not a thing the player is ever shown.
    if obj.type == "survive" then
        text = "Objective: survive"
    elseif obj.type == "defend" then
        text = "Objective: clear every wave"
    elseif obj.type == "reach" then
        -- `who` names the ONE body that has to cross (an escort/extraction), so the line has to say
        -- which body -- "get anyone" is only true for the open footrace with no `who`.
        if obj.who then
            text = "Objective: get " .. charName(obj.who) .. " to the far side"
        else
            text = "Objective: get anyone to the far side"
        end
    elseif obj.type == "hold" then
        text = "Objective: hold the marked ground"
    elseif obj.type == "control" then
        text = "Objective: hold the moving node"
    elseif obj.type == "assassinate" then
        text = "Objective: defeat " .. charName(obj.target)
    else
        text = "Objective: defeat all enemies"
    end
    -- When the body that must cross is also the one that must live (the usual escort), fold the two
    -- clauses so it doesn't read "get the Driver across -- the Driver must survive".
    if obj.protect and obj.protect ~= obj.who then
        text = text .. " -- " .. charName(obj.protect) .. " must survive"
    elseif obj.protect then
        text = text .. " -- alive"
    end
    return text
end

-- Wave progress for a wave-based `defend`: how many waves have walked on out of the total the fight
-- fields. The opening composition is wave 1; each `objective.waves` entry is another, counted arrived
-- once the clock passes its `at` tick (the same reckoning Combat.allWavesArrived uses to judge the
-- win). Returns (arrived, total), or nil for any objective that is not a defend.
local function objectiveWaves(obj, combat)
    if not obj or obj.type ~= "defend" then return nil end
    local waves = obj.waves or {}
    local clock = (combat and combat.clock) or 0
    local arrived = 1 -- the opening set is always on the board
    for _, w in ipairs(waves) do
        if clock >= (w.at or 0) then arrived = arrived + 1 end
    end
    return arrived, 1 + #waves
end

-- Draw the objective line, and for a timed one append its remaining ticks as "<hourglass> N" on the
-- same line -- the text and the clock centred together as one group. The hourglass is the game's mark
-- for "measured in ticks" (ui/glyphs.lua), worn wherever a duration is quoted, so the countdown reads
-- in the same unit as the turn-order strip and every cost badge rather than in "turns", which the
-- player is never shown.
function battle.drawObjective(x, y, w)
    love.graphics.setFont(hudFont)
    local obj = battle.arena.objective
    local text = objectiveText(obj)
    local textW = hudFont:getWidth(text)

    -- The trailing read-out is one of two things: a tick countdown (survive/hold), worn with the
    -- hourglass because it is measured in ticks, OR a wave tally (the wave-based defend), drawn as
    -- plain text and NOT the hourglass -- the hourglass is the game's mark for ticks alone.
    -- The countdown in TICKS (Combat.objectiveRemaining), the same number the hover tooltip quotes on
    -- the marked ground itself -- one formula, so the banner and the tile can never disagree.
    local remaining = Combat.objectiveRemaining(battle.combat)
    local wArrived, wTotal = objectiveWaves(obj, battle.combat)
    local gw, gap, numGap = 11, 12, 5
    local col = Theme.accentAmber
    local clockLabel = remaining and tostring(remaining) or nil
    local waveLabel = wArrived and ("Wave " .. wArrived .. "/" .. wTotal) or nil

    local tailW = 0
    if clockLabel then tailW = gap + gw + numGap + hudFont:getWidth(clockLabel)
    elseif waveLabel then tailW = gap + hudFont:getWidth(waveLabel) end
    local sx = x + (w - (textW + tailW)) / 2

    Theme.set(Theme.ink)
    love.graphics.print(text, sx, y)
    if clockLabel then
        local cx = sx + textW + gap
        Glyphs.hourglass(cx, y + 2, gw, hudFont:getHeight() - 4, col[1], col[2], col[3], 1)
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.print(clockLabel, cx + gw + numGap, y)
    elseif waveLabel then
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.print(waveLabel, sx + textW + gap, y)
    end
    love.graphics.setColor(1, 1, 1)
end

-- A real-time clock as m:ss, floored (never shows a phantom extra second). Used by the chess-clock
-- read-out on a draft battle.
local function clockText(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The draft/PvP read-out: the two control scores flanking the board top, and this player's chess clock
-- beneath their own. Only drawn for a draft battle (battle.isDraft), so a campaign fight shows none of
-- it. The scores update live off the model (Combat.scoreFor), which bank in Combat.rebase.
function battle.drawControlHud(boardX, boardW)
    local combat = battle.combat
    if not (combat and combat.objective and combat.objective.type == "control") then return end
    local mySide = combat.playerSide or "party"
    local foeSide = Combat.OPPOSING[mySide] or "enemy"

    love.graphics.setFont(hudFont)
    -- Your score + clock at the near (left) corner; the foe's score at the far (right) corner.
    Theme.set(Theme.accentAmber)
    love.graphics.print("YOU  " .. Combat.scoreFor(combat, mySide), boardX + 4, 20)
    if battle.chessClock then
        Theme.set(battle.chessClock[mySide] <= 10 and { 0.9, 0.45, 0.4 } or Theme.muted)
        Glyphs.hourglass(boardX + 4, 44, 11, hudFont:getHeight() - 4,
            (battle.chessClock[mySide] <= 10) and 0.9 or 0.6,
            (battle.chessClock[mySide] <= 10) and 0.45 or 0.6,
            (battle.chessClock[mySide] <= 10) and 0.4 or 0.6, 1)
        love.graphics.print(clockText(battle.chessClock[mySide]), boardX + 20, 42)
    end
    Theme.set(Theme.ink)
    local foe = "FOE  " .. Combat.scoreFor(combat, foeSide)
    love.graphics.print(foe, boardX + boardW - 4 - hudFont:getWidth(foe), 20)
    love.graphics.setColor(1, 1, 1)
end

-- Resolve the encounter's composition spec + objective. Placed encounters read their
-- blueprint; the objective tile reads the quest's `map.objective`.
-- The arena spec -- composition, escorts, win condition, board -- moved down to
-- models/encounter_battle.lua, because a fight the company has outgrown is now resolved without this
-- state ever loading (models/autobattle.lua) and has to face the same enemy this would have built.
local specFor = EncounterBattle.spec

-- ---------------------------------------------------------------------------
-- Combat controller (all module-level locals so they close over `battle`; declared
-- before battle.enter so its panel callbacks can reference them as upvalues).
-- ---------------------------------------------------------------------------

-- Release the between-battle leftovers every surviving party member carries out of the fight (mana
-- reservations, summon claims), so the overworld reads a clean roster: no item tooltip still crying
-- "is still on the field" over a creature that left with the battlefield. Combat.new does this too as
-- it rebuilds the grid, but that only fires when the NEXT battle opens -- too late for the hub in
-- between. Both sides do it on the way out so a loss (a forfeit, a wipe of all but a summon) is clean too.
local function releaseParty()
    for _, unit in ipairs(battle.combat.units) do
        if unit.side == "party" then Combat.releaseClaims(unit.char) end
    end
end

-- ---- Combat log review (opened from the victory/defeat panel) ---------------
-- The summary panel offers a "Review Combat Log" button; pressing it opens this modal read of the
-- whole fight over the panel -- a full-height, scrollable CombatLog of its own (sized large, not the
-- thin in-battle gutter strip) with an X / Esc / B back to the summary. While it is up it intercepts
-- input ahead of the summary. See ui/panels/battle_summary.lua and ui/combat_log.lua.
local function openLogReview()
    if battle.logReview then return end
    local w = 560
    local x = Scale.WIDTH / 2 - w / 2
    local y = 90
    local h = Scale.HEIGHT - y - 90
    battle.logReview = {
        x = x, y = y, w = w, h = h,
        log = CombatLog.new(battle.combat, { x = x + 12, y = y + 44, w = w - 24, h = h - 56, visible = true }),
        close = CloseButton.new(x + w, y),
    }
end

local function closeLogReview()
    battle.logReview = nil
end

-- Hand a decided fight to its summary overlay, then let the player choose how to leave it -- the
-- state's own onWin/onLoss/onRetry is deferred until a panel button is pressed. A win offers one button
-- ("Continue") and rolls the combat/elite spoils the panel reveals and passes to onWin; an objective
-- win carries none (its reward flows through the hub's Company Advancement). A defeat offers "Try Again"
-- (onRetry, restart this fight) and, when there is a hub to abandon to, "Return to Hub" (onLoss). A
-- netplay duel keeps the immediate callback and shows no panel: it has no campaign player to reward and
-- the harness owns the handoff.
local function finishBattle(result)
    if battle.session then
        local cb = result == "win" and battle.onWin or battle.onLoss
        if cb then cb() end
        return
    end

    -- What the win pays: rolled by models/encounter_battle.lua, so a fight walked off without the
    -- board loading pays exactly what fighting it would have. Only on a win -- which is also the whole
    -- economy of a bounty (the promise is banked on the combat, and a battle that is lost pays
    -- nothing, however many marks were collected on the way down).
    local spoils
    if result == "win" then
        spoils = EncounterBattle.spoils({
            encounter = battle.encounter,
            enemyUnits = battle.enemyUnits,
            prestige = battle.prestige,
            floorLevel = battle.floorLevel, -- a descent floor pays by depth (models/spoils.lua)
            houseMaterial = battle.houseMaterial,
            combat = battle.combat,
            -- How many of the fight's charges walked out of it, for an encounter whose payout is
            -- priced per head (models/encounter_battle.lua's rescue pay). Counted in win(), above the
            -- mercy revive -- see the note there.
            rescue = battle.rescue,
        })
    end

    -- Wrap each state callback so pressing its button clears the overlay before handing control on.
    local function action(label, fn, arg)
        return { label = label, onSelect = function()
            battle.summary = nil
            if fn then fn(arg) end
        end }
    end

    local actions = {}
    if result == "win" then
        actions[#actions + 1] = action("Continue", battle.onWin, spoils)
    else
        if battle.onRetry then actions[#actions + 1] = action("Try Again", battle.onRetry) end
        if battle.onLoss then actions[#actions + 1] = action(battle.lossLabel or "Return to Hub", battle.onLoss) end
        -- A decided fight must always offer a way out, even if a launcher wired neither exit.
        if #actions == 0 then actions[#actions + 1] = action("Continue", nil) end
    end

    battle.summary = BattleSummary.new({
        result = result,
        spoils = spoils,
        -- What the fight banked toward forging discipline gear (models/discipline.lua), grouped by the
        -- body that earned it. Wins only: a defeat panel is deliberately reward-free, and "Try Again"
        -- rolls the party back to its pre-fight snapshot anyway, so naming a number there would be
        -- naming one about to be undone.
        technique = result == "win" and battle.combat and battle.combat.techniqueByActor or nil,
        encounter = battle.encounter,
        actions = actions,
        -- What the overworld run was carrying, named on a defeat so the cost of the loss is on the panel
        -- that announces it rather than discovered later in the stash. Supplied by the launcher
        -- (states/game.lua) because only it knows what the expedition has picked up; nil everywhere else.
        lost = result == "loss" and battle.lostHaul or nil,
        -- The log survives the fight; let the player read back how it went before leaving the panel.
        onReviewLog = openLogReview,
    })
end

local function win()
    battle.over = true
    battle.walk = nil -- nobody finishes their stroll once the battle is decided
    battle.heldObjects = nil -- and the final board shows every zone it holds, walk unfinished or not
    ScreenFx.vignette(0) -- a won fight is not a dying one: drop any low-HP edge before the panel opens
    Combat.logEvent(battle.combat, "system", "Victory!")
    -- WHO WAS SAVED, counted HERE and not at the payout, because the very next line stands the fallen
    -- back up: an escorted survivor is party-side and revivable like anyone else, so a beat from now
    -- the one who died is walking out with everybody else and a per-head payout would pay for them
    -- (models/encounter_battle.lua's rescue pay). A field on `battle` rather than a file-scope local,
    -- for the reason the note below gives.
    local saved, ofMany = Combat.protectedCount(battle.combat)
    battle.rescue = { saved = saved, of = ofMany }

    -- A won fight is not a lost life: any party member who fell is carried out to the overworld at a
    -- sliver of health rather than staying down. Only on a win -- a defeat costs the run outright.
    --
    -- WHO WENT DOWN is kept for the launcher, which turns it into wounds (models/wound.lua): the free
    -- revive stands, and the wound is the price rather than the loss of the body. A field on the
    -- existing table and NOT a new file-scope local -- this chunk sits within a couple of declarations
    -- of Lua 5.1's 200-local ceiling, and crossing it is a compile error naming an unrelated line.
    battle.fallen = Combat.reviveFallenParty(battle.combat)
    releaseParty()
    Sound.play("battle.win")
    Sound.music("music.victory") -- the tactical bed gives way to the exhale under the spoils panel
    finishBattle("win")
end

local function lose()
    battle.over = true
    battle.walk = nil
    battle.heldObjects = nil
    Combat.logEvent(battle.combat, "system", "Defeat.")
    -- Nobody is carried out of a lost fight, but everyone who fell in it is still hurt. Recorded on
    -- the same field the win writes, so the launcher reads one thing however the fight ended.
    battle.fallen = Combat.fallenParty(battle.combat)
    -- The colour drains out of the world as the defeat panel closes over it -- a grey that says the run
    -- is lost more plainly than any banner. Not motion, so it plays even under reduced effects; cleared
    -- when the next battle enters or the player retries (see battle.enter). See ui/screen_fx.lua.
    ScreenFx.grey(0.85)
    releaseParty()
    Sound.play("battle.loss")
    Sound.music("music.defeat") -- the tactical bed gives way to the mournful bed under the grey
    finishBattle("loss")
end

-- Narrow one of the overlay sets to what a running tutorial permits, or hand it back untouched when
-- no tutorial is running (every ordinary battle). `kind` is "move" or "attack".
--
-- This is the whole shape of the guided battle's gate, and it is deliberately a FILTER over the sets
-- rather than a veto on clicks: confirm, armedActionAt, tryDefaultAction and actionPreviewFor all key
-- off these same sets, so a tile the lesson didn't ask for simply isn't a legal action anywhere.
-- Highlight, cursor glyph, preview tooltip and click agree for free, on mouse, keyboard and pad
-- alike, with no per-path conditionals. See models/tutorial.lua.
-- The ordered list and the keyed set are filtered INDEPENDENTLY, not one from the other: the keyed
-- sets deliberately span more ground than the lists they accompany (attackReach covers targets
-- standing inside the blue move band, which threatCells omits so the two overlays don't stack), so
-- rebuilding one from the other would quietly drop legal targets.
local function narrow(kind, cells, keyed)
    if not battle.tutorial then return cells, keyed end
    local keptCells, keptKeyed = {}, {}
    for _, c in ipairs(cells) do
        if Tutorial.allowsCell(battle.tutorial, kind, c.x, c.y) then
            keptCells[#keptCells + 1] = c
        end
    end
    for k, cell in pairs(keyed) do
        if Tutorial.allowsCell(battle.tutorial, kind, cell.x, cell.y) then keptKeyed[k] = cell end
    end
    return keptCells, keptKeyed
end

-- Reachable tiles for the current unit (blue move highlights + move validity). A rooted unit
-- (a movement-blocking status) can't move this turn, so its reachable set is empty -- it can
-- still attack from where it stands. So is a unit that has already spent its one move: Combat.reachable
-- answers "where could this body walk", a question with no notion of a turn, and the one-move rule
-- lives out here -- startWalk clears the band as the walk begins. That made the band's emptiness a
-- thing only startWalk maintained, so any LATER rebuild of it mid-turn (toggleBlink calls this) raised
-- the spent move from the dead: a full blue band, a walk-and-strike attackReach/rangeReach built over
-- it, a lit target needing an approach, a route drawn to it and a preview pricing move+cast -- and then
-- confirm's Combat.hasMoved guard refused the click. The rule belongs here, where every derived set
-- reads it, not in the one function that happens to spend the move.
local function computeReachable(unit)
    if Status.blocksMove(unit) or Combat.hasMoved(battle.combat) then
        battle.reachable, battle.moveCells = {}, {}
        battle.blinking = false
        return
    end
    -- An armed, affordable Blink turns the move set into a teleport diamond (ignoring terrain and
    -- obstacles); otherwise it is the ordinary walk. battle.blinking drives the confirm/preview path
    -- and lets the overlay read as a jump rather than a stroll.
    local blink = Combat.blinkReady(unit)
    if blink then
        battle.blinking = true
        battle.reachable = Combat.teleportCells(battle.combat, unit, blink.movement)
    else
        battle.blinking = false
        battle.reachable = Combat.reachable(battle.combat, unit)
    end
    local cells = {}
    for _, node in pairs(battle.reachable) do
        cells[#cells + 1] = { x = node.x, y = node.y }
    end
    battle.moveCells, battle.reachable = narrow("move", cells, battle.reachable)
end

-- The route the current unit will walk to the cursor tile: `battle.movePath = { cells, cost }`, or
-- nil when the cursor isn't a plain walk target. Built Advance-Wars style so the player can STEER
-- among the many routes to a tile: as the cursor steps to a reachable neighbour of the route's end
-- the route extends onto it (the "last touched tile" becomes a waypoint), and stepping back onto an
-- earlier tile trims the route to there. A deliberate detour is allowed as far as the movement budget
-- stretches (Combat.planMoveVia caps it) and is charged its full cost. Anything the trail can't
-- absorb -- a cursor JUMP (fast mouse flick, non-adjacent), an over-budget extension, a revisit --
-- rebuilds the plain shortest path (Combat.planMove), so the preview always shows a legal walk.
local function updateMovePath(unit)
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    -- Only a walked move draws a route: not a blink (a teleport has none), and standing still isn't
    -- a move.
    if battle.blinking or (cx == unit.x and cy == unit.y) then
        battle.movePath = nil
        return
    end
    -- The cursor must be a reachable tile to STEER the route to it. When it isn't: in armed mode the
    -- player has steered the approach and moved the cursor onto a foe to aim (or onto a tile out of
    -- move range) -- keep the drawn route so its endpoint stays the tile the strike fires from. In
    -- move mode an off-set cursor just clears the route.
    if not (battle.reachable and battle.reachable[cx .. "," .. cy]) then
        if battle.mode ~= "armed" then battle.movePath = nil end
        return
    end

    -- Try to reuse the existing route: trim if the cursor is on it, extend if it's adjacent to the end.
    local prev = battle.movePath and battle.movePath.cells
    local candidate
    if prev then
        local hit
        for i, c in ipairs(prev) do if c.x == cx and c.y == cy then hit = i break end end
        if hit then
            candidate = {}
            for i = 1, hit do candidate[i] = prev[i] end
        else
            local last = prev[#prev]
            if math.abs(last.x - cx) + math.abs(last.y - cy) == 1 then
                candidate = {}
                for i = 1, #prev do candidate[i] = prev[i] end
                candidate[#candidate + 1] = { x = cx, y = cy }
            end
        end
    end

    local plan = candidate and Combat.planMoveVia(battle.combat, unit, candidate)
    plan = plan or Combat.planMove(battle.combat, unit, cx, cy)
    if not plan then battle.movePath = nil return end
    -- Ground that STOPS a walk (quicksand mires, and a mired unit goes no further -- Combat.stepMove)
    -- makes the route's price a promise the board will not keep: the timeline ghost is charged for the
    -- ground actually crossed, not for the walk the player drew. The cells stay WHOLE -- steering trims
    -- and extends them, and an armed strike fires from the tile they end on. Where the line stops being
    -- solid is answered per frame in refreshView, off whichever route it ends up drawing.
    local stop, walked = Combat.walkStop(battle.combat, unit, plan.path)
    battle.movePath = { cells = plan.path, cost = stop < #plan.path and walked or plan.cost }
end

-- The steered route, only when it actually ends on (x, y) -- so a caller reading it for a specific
-- cell (confirm, the action preview) never picks up a route built for a different tile.
local function movePathTo(x, y)
    local mp = battle.movePath
    if not mp then return nil end
    local last = mp.cells[#mp.cells]
    if last.x == x and last.y == y then return mp end
    return nil
end

-- The tile a steered route commits the unit to standing on -- the end of the drawn move route
-- (battle.movePath) plus that route, or nil when none is drawn. In armed mode this is the tile the
-- player has steered to, and the one an ensuing strike should fire FROM (see armedActionAt).
local function steeredStand()
    local mp = battle.movePath
    if not mp then return nil end
    return mp.cells[#mp.cells], mp
end

-- Can `unit`, standing on (sx, sy), legally land `ab` / `item` on the target cell (tx, ty)? The same
-- per-stand-tile test Combat.attackReach applies -- base range + the item's grid-adjacency bonus +
-- the stand tile's own field range bonus (a sighted ability only) - any range-cutting debuff (Blind),
-- floored at 1, clamped below by the min range and gated on line
-- of sight when it needs it -- pulled out so a SPECIFIC stand tile (the steered route's endpoint) can
-- be checked, not just the cheapest one attackReach records. Combat.useItem re-validates on confirm.
local function standCanHit(unit, ab, item, sx, sy, tx, ty)
    local r = math.max(1, (ab.range or 1) + Combat.adjacencyRangeBonus(unit.char, item)
        + Combat.fieldRangeBonus(battle.combat, ab.requiresSight, sx, sy)
        - Status.rangeMalus(unit))
    local d = math.abs(sx - tx) + math.abs(sy - ty)
    if d < Combat.abilityMinRange(ab) or d > r then return false end
    if ab.requiresSight and not Combat.hasLineOfSight(battle.combat, sx, sy, tx, ty) then return false end
    return true
end

-- The armed ability's valid-to-hit AREA (red for offensive, green for support): every tile the
-- ability could legally land on this turn -- moving first if needed, so the reach is the WALK-AND-
-- STRIKE band (Combat.attackReach), not just what it hits from the tile it stands on now. In range
-- from some reachable stand tile, walkable (never a wall), and in line of sight (from that stand
-- tile) when the ability needs it. A tile it CAN'T validly hit is dropped, so the highlight stops at
-- cover and never falls on a unit of the wrong kind (an ally under an enemy strike, a foe under a
-- support cast). A tile-target ability (e.g. summoning a trap) additionally needs an empty cell; a
-- self-only ability can land only on the caster's own tile. `battle.rangeReach` records the cheapest
-- stand tile per cell (like the default action's attackReach) so confirm can walk there and cast.
-- Combat.useItem re-checks all of this on confirm.
local function computeRange(unit, item)
    local ab = item.activeAbility
    local target = ab and ab.target
    battle.rangeReach = {}
    battle.rangeFor = item -- what the sets below describe; refreshView rebuilds them when it changes
    -- A self-only ability can only ever land on the caster's own tile (no walk).
    if target == "self" then
        battle.rangeCells = { { x = unit.x, y = unit.y } }
        battle.rangeReach[unit.x .. "," .. unit.y] =
            { x = unit.x, y = unit.y, fromX = unit.x, fromY = unit.y, moveCost = 0 }
        return
    end
    -- Base range (grid-adjacency bonus folded in); attackReach adds each stand tile's own terrain
    -- range bonus, so pass the raw base rather than Combat.abilityRange (which bakes in the CURRENT
    -- tile's field bonus and would double-count it). Blink is a teleport, not a walk-and-strike set,
    -- so it reaches only from the current tile.
    local range = ((ab and ab.range) or 1) + Combat.adjacencyRangeBonus(unit.char, item)
    local minRange = Combat.abilityMinRange(ab)
    local requiresSight = ab and ab.requiresSight
    local reachForRange = battle.blinking and {} or battle.reachable
    local reach = Combat.attackReach(battle.combat, unit, range, reachForRange, requiresSight, minRange)
    local cells = {}
    for k, cell in pairs(reach) do
        -- Drop cells the ability can't validly land on: a tile cast needs an empty cell; a unit-target
        -- cast can't hit a unit of the wrong side (an empty tile still shows, so the reach reads even
        -- with no one standing in it).
        local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
        local valid
        if target == "tile" then valid = occ == nil or ab.allowOccupied == true
        elseif occ and target == "enemy" then valid = occ.side ~= unit.side
        elseif occ and target == "ally" then valid = occ.side == unit.side
        else valid = true end
        if valid then
            cells[#cells + 1] = { x = cell.x, y = cell.y }
            battle.rangeReach[k] = cell
        end
    end
    battle.rangeCells, battle.rangeReach = narrow("attack", cells, battle.rangeReach)
end

-- Run `fn` with `unit` standing on (sx, sy) rather than on its own tile, then put it back where it
-- was. A click can fold an APPROACH into the action -- walk to the stand tile rangeReach recorded,
-- then swing -- and every directional footprint (a spear's line, an axe's arc, any cone) is oriented
-- from wherever the caster stands at the moment it swings. Asking "what would this cast do?" from the
-- tile the unit currently occupies therefore answers for a swing that will never be thrown: the line
-- runs off in the wrong direction, and a walk-and-strike lands on tiles the preview never lit.
--
-- The unit itself is relocated rather than a stand-in copy passed, so its identity survives: an effect
-- that compares fx.user against the bodies on the board still recognises the caster, and Combat.unitAt
-- reads the board exactly as it will be once the approach is walked (the caster on the stand tile, its
-- old tile empty). Only ever wrapped around INERT dry runs -- Combat.aoeCells, Combat.previewAbility --
-- which never touch the board; the tile is restored even if one of them throws.
local function asIfStandingAt(unit, sx, sy, fn)
    if not (unit and sx and sy) or (unit.x == sx and unit.y == sy) then return fn() end
    local ox, oy = unit.x, unit.y
    unit.x, unit.y = sx, sy
    local ok, result = pcall(fn)
    unit.x, unit.y = ox, oy
    if not ok then error(result, 0) end
    return result
end

-- The blast footprint an AoE ability would cover if fired at cell (cx, cy): the cells
-- Combat.aoeCells returns for the armed/hovered ability, or nil for a single-target ability or a
-- cell that isn't a legal aim point. Drives the brighter red/green area highlight (ui/battle_map)
-- that previews exactly what an AoE cast sweeps as the cursor moves over the board.
local function aoeFootprint(item, cx, cy)
    local ab = item and item.activeAbility
    if not (ab and ab.aoe) then return nil end
    -- Only preview the blast on a legal aim cell (membership in the pre-computed valid range set),
    -- so the footprint never implies a shot the unit can't actually take.
    local onTarget = false
    for _, c in ipairs(battle.rangeCells or {}) do
        if c.x == cx and c.y == cy then onTarget = true break end
    end
    if not onTarget then return nil end
    -- Oriented from the tile the cast would FIRE from, which a click-to-use approach may have moved
    -- off the caster's own square (see asIfStandingAt). The stand tile is the one rangeReach recorded
    -- for this aim -- and only when those sets describe THIS item, which refreshView guarantees before
    -- it calls here.
    local entry = (battle.rangeFor == item) and battle.rangeReach and battle.rangeReach[cx .. "," .. cy] or nil
    local unit = battle.current
    return asIfStandingAt(unit, entry and entry.fromX, entry and entry.fromY, function()
        return Combat.aoeCells(battle.combat, ab, cx, cy, unit)
    end)
end

-- The default-ACTION reach: every cell the unit could use its default action on this turn (the
-- player-chosen action, Combat.defaultAction -- a strike, a heal, a summon), moving first if needed.
-- Stores `battle.defaultAction` + `battle.attackReach` (cell -> cheapest stand tile, which spans the
-- whole reach and drives click-to-use pathing), `battle.defaultSupport` (a friendly action, so the
-- band reads green not red), and `battle.threatCells`, the highlight = the reach band beyond movement,
-- keeping only cells the action can VALIDLY land on: for a strike, drop the caster's own tile and any
-- ally; for a support action, drop the caster and any foe (empty cells in range still show either way,
-- so the reach reads even with no target on it). Tiles inside the blue move band are left to the blue
-- overlay so the two never stack into a muddy overlap. Reads the live `battle.reachable`, so once the
-- unit has moved (reachable cleared) only what it can reach from where it now stands shows.
local function computeThreat(unit)
    -- The unit rides along so a signature's `unlock` is asked live: while it is still charging the
    -- default falls through to something the unit can actually open with, and the swing it lit the
    -- band with is the swing the click will land.
    local action = Combat.defaultAction(unit.char, unit)
    battle.defaultAction = action
    local ab = action and action.activeAbility
    local support = ab ~= nil and Combat.isSupportAbility(ab)
    battle.defaultSupport = support
    local range = ((ab and ab.range) or 1) + Combat.adjacencyRangeBonus(unit.char, action)
    -- While Blink is armed the move set is a teleport diamond, which is NOT a set of walk-and-strike
    -- stand tiles (click-to-use folds a WALK into the approach). So reach only from the current tile:
    -- the mage blinks OR acts from where it stands, it does not walk-then-act.
    local reachForThreat = battle.blinking and {} or battle.reachable
    battle.attackReach = Combat.attackReach(battle.combat, unit, range, reachForThreat,
        ab and ab.requiresSight, Combat.abilityMinRange(ab))

    local moveKeys = {}
    for _, c in ipairs(battle.moveCells) do moveKeys[c.x .. "," .. c.y] = true end

    local cells = {}
    for k, cell in pairs(battle.attackReach) do
        -- Show the reach, minus tiles already lit blue (the move band), the caster's own tile, and any
        -- occupant of the wrong side for this action (a friend can't be struck; a foe can't be healed).
        if not moveKeys[k] and not (cell.x == unit.x and cell.y == unit.y) then
            local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
            local wrongSide = occ and (support and occ.side ~= unit.side or not support and occ.side == unit.side)
            if not wrongSide then
                cells[#cells + 1] = { x = cell.x, y = cell.y }
            end
        end
    end
    battle.threatCells, battle.attackReach = narrow("attack", cells, battle.attackReach)
end

-- The reach a single unit threatens THIS turn with its default weapon: its walk-and-strike band,
-- split (like computeThreat) into the movement tiles and the attack tiles beyond them. Powers the
-- "hover a unit to read its range" preview (Fire Emblem / Triangle Strategy): the inspected unit's
-- own movement (orange) + attack reach (crimson), computed on demand and cached against the unit it
-- was built for (battle.inspectFor) so it isn't rebuilt every frame. Pass nil to clear.
local function computeInspect(unit)
    battle.inspectFor = unit
    battle.inspectMoveCells = {}
    battle.inspectRangeCells = {}
    if not unit then return end
    local reachable = Status.blocksMove(unit) and {} or Combat.reachable(battle.combat, unit)
    local moveKeys = {}
    -- Only highlights, so the order is nobody's business but the renderer's -- taken in board order
    -- anyway, because one rule about how the reachable set is walked is easier to keep than a rule
    -- with an exception in it (Combat.reachableList).
    for _, node in ipairs(Combat.reachableList(battle.combat, unit, reachable)) do
        battle.inspectMoveCells[#battle.inspectMoveCells + 1] = { x = node.x, y = node.y }
        moveKeys[node.x .. "," .. node.y] = true
    end
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    local range = (ab and ab.range) or 1
    local reach = Combat.attackReach(battle.combat, unit, range, reachable,
        ab and ab.requiresSight, Combat.abilityMinRange(ab))
    for k, cell in pairs(reach) do
        -- The attack band is what it can hit BEYOND where it can stand -- the move tiles are their
        -- own overlay, and its own tile isn't a strike target.
        if not moveKeys[k] and not (cell.x == unit.x and cell.y == unit.y) then
            battle.inspectRangeCells[#battle.inspectRangeCells + 1] = { x = cell.x, y = cell.y }
        end
    end
end

-- The unit whose range the board is currently previewing: the one hovered on the turn-order strip
-- (an explicit "look at this" gesture) or, failing that, the one under the board cursor -- as long
-- as it isn't the acting unit itself and we're in plain MOVE mode (not aiming an armed ability).
--
-- DISABLED for now: hovering a foe to preview its reach clashed with the click-to-attack preview on
-- the same hover. Returning nil keeps the actor's own move/danger overlays up at all times; delete
-- the early return to bring the feature back (the compute/draw path below is intact).
local function desiredInspectUnit()
    do return nil end
    if battle.mode ~= "move" or battle.over then return nil end
    local cur = battle.current
    local h = battle.hoverUnit
    if h and h.alive and h ~= cur then return h end
    local u = Combat.unitAt(battle.combat, battle.map.cursor.x, battle.map.cursor.y)
    if u and u.alive and u ~= cur then return u end
    return nil
end

-- The party's danger zone: every tile any living hostile unit could reach-and-strike this turn with
-- its default weapon, unioned across the enemies. `battle.dangerCells` is the keyed set ("x,y" ->
-- {x,y}) the purple overlay reads; `battle.dangerSources` maps each threatened tile to the list of
-- enemy POSITIONS that threaten it, so a tile the cursor lands on can trace a red line back to each
-- foe. Recomputed on turn hand-off and after any walk (an enemy's reachable set shifts as units
-- move) -- never per frame. Decoys (control "none") never advance, so they raise no threat.
--
-- The union itself is Combat.threatMap, shared with the AI: what the player reads as "where it is
-- dangerous to stand" is the very question a unit weighing a tile to stand on asks, and the two must
-- not be allowed to drift apart -- an overlay that promises a tile is safe while the AI prices it as
-- exposed teaches the player a rule the game isn't playing.
-- Forward-declared: computeIntents is defined further down (it needs scriptedAction, which the AI
-- prediction routes through), but computeDanger calls it so the two never drift out of step. The
-- local is assigned before either ever runs -- both fire at runtime, well after the file has loaded.
local computeIntents

-- WATCHED GROUND: the tiles beside an enemy holding the Overwatch stance -- dear to enter
-- (Combat.watchTax) and shot at on arrival (Combat.triggerOverwatch). One ring for both, because it
-- is one fact: this is the ground that body is holding.
--
-- Drawn at all only while somebody is actually watching, which is rare -- it takes an item that swaps
-- Wait into the stance, and a turn spent taking it. That rarity is exactly why it has to be drawn: a
-- player meets this rule for the first time somewhere in the middle of some fight, and without a ring
-- the only evidence is a move band that quietly reaches less far than it did a moment ago.
--
-- Sits with the danger family rather than getting a colour of its own -- it IS danger, of a kind the
-- board already speaks about in purple.
local function watchedRing()
    local out = {}
    local seen = {}
    for _, watcher in ipairs(battle.combat.units) do
        local zone = watcher.alive and watcher.overwatch and watcher.overwatch.zone
        if zone and zone > 0 and watcher.side ~= "party" then
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local x, y = watcher.x + d[1], watcher.y + d[2]
                local k = x .. "," .. y
                if not seen[k] and battle.arena.tiles[y] and battle.arena.tiles[y][x] then
                    seen[k] = true
                    out[#out + 1] = { x = x, y = y }
                end
            end
        end
    end
    return out
end

local function computeDanger()
    -- A lesson step may ask for a clean board (Tutorial.hidesDanger). Emptying the sets here rather
    -- than at each draw site is what makes that one decision instead of four: the purple move-band
    -- split, the red threat lines and the "Threats" survey all read these, so they all go quiet
    -- together and none of them can be forgotten.
    if battle.tutorial and Tutorial.hidesDanger(battle.tutorial) then
        battle.dangerCells, battle.dangerSources = {}, {}
        battle.watchedCells = {}
        battle.inspectFor = nil
        battle.enemyIntents = {}
        battle.retargetKey = nil
        return
    end
    battle.dangerCells, battle.dangerSources = Combat.threatMap(battle.combat, "party")
    battle.watchedCells = watchedRing()
    battle.inspectFor = nil -- board changed: a lingering hover preview is rebuilt on the next frame
    -- Predictions ride the exact same cadence as the danger map, and for the same reason: the moment
    -- the board changes an old prediction is a lie, and the move-preview cache below is keyed on a
    -- board that just moved, so it is dropped here too.
    computeIntents()
    battle.retargetKey = nil
end

-- Auto-arm the unit's default action at the start of its turn, so its effective range shows by
-- default (the player pins WHICH action in the Loadout screen). This is exactly the state clicking
-- the item would arm -- armed mode, its walk-and-strike range lit -- so the player can immediately
-- act, click the item (or Esc) to disarm and move freely, or click a different item to switch. Reads
-- battle.defaultAction/defaultSupport (computeThreat set them just before). A default the unit can't
-- afford right now, or a bare-handed unit with no ability at all, simply starts disarmed (move mode).
-- The wind-up an item opens (and floors) at, in TOTAL ticks: its `windup` min -- a signature swing is
-- always at least this deep a commitment -- or 0 for an item that resolves at once. Read through
-- Item.windupRange so the scalar shorthand (`windup = 4`) and the chargeable range are one question.
local function windupFloor(item)
    local lo = Item.windupRange(item and item.activeAbility)
    return lo
end

-- Could `unit` land `item`'s SIGHT-GATED enemy strike on an actual foe this turn -- from where it
-- stands, or from any tile it could walk to and shoot from (the walk-and-strike band)? True unless
-- there is no such foe. Only meaningful for a `requiresSight` enemy ability: a weapon that must SEE
-- its mark (The Held Breath, whose draw grants Unseen the instant it commits) must not be armable
-- when nothing is in its line, or it degrades into a free reposition/stealth crutch aimed at open
-- ground. Reads the live `battle.reachable`, so once the unit has moved it only asks what it can hit
-- from where it now stands. Uses Combat.attackReach -- the same LOS-gated, stand-tile-aware reach the
-- range band and Combat.useItem agree on -- and checks whether any target cell holds a living enemy.
local function canSightAFoe(unit, item)
    local ab = item and item.activeAbility
    if not (ab and ab.requiresSight and ab.target == "enemy") then return true end
    local range = (ab.range or 1) + Combat.adjacencyRangeBonus(unit.char, item)
    local reachForRange = battle.blinking and {} or battle.reachable
    local reach = Combat.attackReach(battle.combat, unit, range, reachForRange,
        true, Combat.abilityMinRange(ab))
    for _, cell in pairs(reach) do
        local occ = Combat.unitAt(battle.combat, cell.x, cell.y)
        if occ and occ.alive and occ.side ~= unit.side then return true end
    end
    return false
end

local function armDefaultAction(current)
    -- A tutorial step whose whole lesson is "ready your weapon" has to start with it sheathed --
    -- otherwise the step is satisfied before the player touches anything, and the click it is asking
    -- for would disarm instead of arm.
    if battle.tutorial and Tutorial.suppressesAutoArm(battle.tutorial) then return end
    local action = battle.defaultAction
    if not (action and action.activeAbility) then return end
    if Combat.itemBlockReason(current, action) then return end
    -- A sight-gated bow with nothing in its line doesn't auto-arm: the turn opens in move mode
    -- instead, exactly as it should be "not activatable with no line of sight". The player can walk
    -- into a shot and arm it then (canSightAFoe accounts for walk-and-strike stand tiles).
    if not canSightAFoe(current, action) then return end
    battle.armedItem = action
    battle.windup = windupFloor(action) -- a chargeable signature (First Motion) opens at its floor, not +0
    battle.mode = "armed"
    battle.armedSupport = battle.defaultSupport
    battle.armedTile = action.activeAbility.target == "tile"
    computeRange(current, action)
end

-- ---------------------------------------------------------------------------
-- Keyboard/gamepad target assist. A mouse aims itself; a cursor player picks a target by snapping the
-- aim onto the nearest valid one when an item (or the turn's default weapon) is selected, then cycling
-- the ring with Tab / the shoulder buttons and confirming with Enter / A. All three read the reach
-- sets computeRange/computeThreat already built for the current aiming context -- they never recompute
-- reach, so the assist can never light a target the confirm path would then refuse.
-- ---------------------------------------------------------------------------

-- The 4 cardinal steps, as (dx, dy) pairs -- the lanes a throw (or any straight shove) travels. Only
-- four, not eight: Combat.knockback/hurlObject resolve direction through signDominant, which collapses
-- any aim onto its dominant axis (a 4-directional grid), so a diagonal landing could never be honoured.
local THROW_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- The grabbable standing on (x, y) for the current actor, as (thing, kind): a body ("unit"), or a prop
-- / a detected trap. nil when the tile holds nothing a throw could pick up. Mirrors the order Heave's
-- own effect reads the tile in (a body first, then furniture).
local function throwGrabbableAt(x, y)
    local body = Combat.unitAt(battle.combat, x, y)
    if body and body.alive then return body, "unit" end
    local obj, kind = Combat.throwableAt(battle.combat, x, y, battle.current and battle.current.side)
    if obj then return obj, kind end
    return nil
end

-- Where a thing grabbed at (fromX, fromY) could be thrown: out along each of the 4 cardinal lines, up
-- to `range` tiles, each ray adding every open tile it crosses AND the first blocked tile (a wall, a
-- unit, a prop -- where the throw would slam), then stopping. Rays emanate from the GRABBED tile, not
-- the thrower, matching Combat.knockback/hurlObject's lane. Returns a list of {x,y} and a lookup set
-- keyed "x,y".
local function throwLandingCells(fromX, fromY, range)
    local combat = battle.combat
    local cells, set = {}, {}
    for _, d in ipairs(THROW_DIRS) do
        local x, y = fromX, fromY
        for _ = 1, range do
            x, y = x + d[1], y + d[2]
            local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
            local cell = row and row[x]
            local blocked = not (cell and cell.walkable)
                or Combat.objectBlocksAt(combat, x, y)
                or Combat.unitAt(combat, x, y) ~= nil
            local key = x .. "," .. y
            if not set[key] then
                set[key] = true
                cells[#cells + 1] = { x = x, y = y }
            end
            if blocked then break end -- the ray slams here; nothing behind it can be reached
        end
    end
    return cells, set
end

-- The valid confirm targets for the current aiming context, nearest-first from the actor: the living
-- bodies an armed unit-target strike/support (or, in move mode, the default action) could legally land
-- on, each carrying its aim cell. Enemy abilities list foes, support abilities list allies; a tile- or
-- self-target ability has no unit to cycle and returns empty, as does an enemy turn or a spent context.
-- A two-stage throw substitutes its own rings (its landings, or its grabbable neighbours).
local function targetCells()
    local current = battle.current
    if not current or not Combat.isPlayerControlled(current) or battle.over then return {} end
    -- A two-stage throw cycles its own rings: the ray of legal landings in the destination phase, and
    -- the adjacent grabbables in the grab phase (neither is a unit-target ring the block below builds).
    if battle.throwStage == "dest" and battle.throwCells then
        local from = battle.throwFrom
        local list = {}
        for _, c in ipairs(battle.throwCells) do
            list[#list + 1] = { x = c.x, y = c.y,
                d = math.abs(c.x - from.x) + math.abs(c.y - from.y) }
        end
        table.sort(list, function(a, b)
            if a.d ~= b.d then return a.d < b.d end
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)
        return list
    end
    if battle.throwStage == "grab" then
        local list = {}
        for _, entry in pairs(battle.rangeReach or {}) do
            if throwGrabbableAt(entry.x, entry.y) then
                list[#list + 1] = { x = entry.x, y = entry.y,
                    d = math.abs(entry.x - current.x) + math.abs(entry.y - current.y) }
            end
        end
        table.sort(list, function(a, b)
            if a.d ~= b.d then return a.d < b.d end
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)
        return list
    end
    local reach, support, ab
    if battle.mode == "armed" and battle.armedItem then
        ab = battle.armedItem.activeAbility
        reach, support = battle.rangeReach, battle.armedSupport
    elseif battle.mode == "move" and battle.defaultAction then
        ab = battle.defaultAction.activeAbility
        reach, support = battle.attackReach, battle.defaultSupport
    end
    if not (ab and reach) then return {} end
    -- A tile-target weapon with a footprint (an axe's cleave, a spear's line) aims a FACING, not a body:
    -- there is no foe cell to snap onto directly. So offer the aim tiles whose resulting AoE actually
    -- sweeps a unit of the target side, ranked by how many it catches -- a cursor player arms the axe and
    -- lands at once on the tile that cleaves the most foes, then cycles among the other worthwhile facings.
    -- A tile ability with no footprint (a trap, a summon) has no foe to aim at and yields nothing --
    -- UNLESS it also allows an occupied cell, in which case a body standing in reach is a legal aim and
    -- often the point of it (the Deadfall Bow pins whoever is already on the read instead of arming the
    -- jaws; a shove aims at the one being shoved). Those fall through to the unit ring below, so a
    -- cursor player gets the same snap-and-cycle a unit-target ability gives. A placement onto genuinely
    -- bare ground still offers nothing, because there is nothing to rank there.
    if ab.target == "tile" and ab.aoe then
        local list = {}
        for _, entry in pairs(reach) do
            local hits = 0
            for _, u in ipairs(Combat.aoeUnits(battle.combat, ab, entry.x, entry.y, current)) do
                if u.alive
                    and (support and u.side == current.side or not support and u.side ~= current.side) then
                    hits = hits + 1
                end
            end
            if hits > 0 then
                list[#list + 1] = { x = entry.x, y = entry.y, hits = hits,
                    d = math.abs(entry.x - current.x) + math.abs(entry.y - current.y) }
            end
        end
        -- Most caught first, then nearest, then a stable board order -- so the ring is the same every time
        -- and "the best facing" is unambiguous when two sweep the same count at the same distance.
        table.sort(list, function(a, b)
            if a.hits ~= b.hits then return a.hits > b.hits end
            if a.d ~= b.d then return a.d < b.d end
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)
        return list
    end
    if ab.target == "tile" then
        if not ab.allowOccupied then return {} end
    elseif ab.target ~= "enemy" and ab.target ~= "ally" then
        return {}
    end
    local list = {}
    for _, entry in pairs(reach) do
        local occ = Combat.unitAt(battle.combat, entry.x, entry.y)
        if occ and occ.alive
            and (support and occ.side == current.side or not support and occ.side ~= current.side) then
            list[#list + 1] = { x = entry.x, y = entry.y,
                d = math.abs(entry.x - current.x) + math.abs(entry.y - current.y) }
        end
    end
    -- Nearest-first, then a stable board order (top-to-bottom, left-to-right) so the cycle ring is the
    -- same every time and "the nearest valid target" is unambiguous when two are equidistant.
    table.sort(list, function(a, b)
        if a.d ~= b.d then return a.d < b.d end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return list
end

-- Snap the cursor onto the nearest valid target for the current aiming context. Called when a cursor
-- player selects an item or the turn's default weapon, so the aim lands on something at once. A no-op
-- under mouse (which aims itself), and when the context has no unit target to snap to.
local function snapToNearestTarget()
    if InputMode.isMouse() then return end
    -- A self-target ability has no unit ring to cycle (targetCells is empty), yet its one legal cell is
    -- the caster's own tile -- so aim there at once, sparing a cursor player from walking back onto self.
    local current = battle.current
    if current and battle.mode == "armed" and battle.armedItem
        and battle.armedItem.activeAbility and battle.armedItem.activeAbility.target == "self" then
        battle.map.cursor.x, battle.map.cursor.y = current.x, current.y
        return
    end
    local list = targetCells()
    if #list == 0 then return end
    battle.map.cursor.x, battle.map.cursor.y = list[1].x, list[1].y
end

-- Step the aim to the next (dir +1) or previous (dir -1) valid target, wrapping the nearest-first ring.
-- If the cursor is already on a target, advance from there; otherwise land on the nearest (forward) or
-- farthest (back). Returns true when it moved the aim, so a caller can treat the press as consumed.
local function cycleTarget(dir)
    local list = targetCells()
    if #list == 0 then return false end
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    local idx
    for i, c in ipairs(list) do
        if c.x == cx and c.y == cy then idx = i break end
    end
    local nextIdx = idx and ((idx - 1 + dir) % #list + 1) or (dir > 0 and 1 or #list)
    battle.map.cursor.x, battle.map.cursor.y = list[nextIdx].x, list[nextIdx].y
    return true
end

-- Start the current unit's turn: MOVE mode + reachable set for a unit the player commands, or an
-- AI delay for anyone else (an enemy, or a summon fighting for them). Control -- not side -- picks
-- the branch, so a player's summon takes an interactive turn and an inert decoy does not.
-- `resume` means the turn never actually ended: a free action (Battle Tonic, the Harrier's Bow) --
-- or a surged extra action -- left `combat.turn` open on the SAME unit, and the player is simply
-- carrying on with it. Beginning it afresh there would re-run Combat.startTurn, which WIPES every
-- per-turn latch the open turn is still holding (freeActionsUsed, actionSpent, overwatch), hands the
-- move back (moved -> false) and re-bumps the turnTaken tally -- so a free shot would refresh the whole
-- turn and let the shooter act again. That is the "the Harrier's Bow still lets you cast other items"
-- bug. On a resume we read the current unit off the open turn and leave every model latch untouched;
-- only the UI overlays are recomputed for the continued turn.
local function beginTurn(resume)
    local current = resume and battle.combat.turn and battle.combat.turn.unit
        or Combat.startTurn(battle.combat)
    battle.current = current
    -- Square a running lesson with a board that moved on: a step whose target died (to Rowan's own
    -- strike, a trap, an overwatch shot) is skipped, and a step whose actor died abandons the lesson
    -- outright. The latter is the one that matters -- Combat.evaluate only calls a loss when EVERY
    -- party unit is down, so the avatar can fall while Rowan fights on, and without this the gate
    -- would hold a fight nobody could play.
    if battle.tutorial then
        Tutorial.reconcile(battle.tutorial, function(charId)
            for _, u in ipairs(battle.combat.units) do
                if u.alive and u.char.id == charId then return true end
            end
            return false
        end)
    end
    battle.mode = "move"
    battle.armedItem = nil
    battle.windup = 0 -- a chargeable wind-up never carries its depth across turns
    battle.windupChooser = nil -- nor does an un-committed depth chooser (cancelled by the turn ending)
    battle.spendChooser = nil  -- nor an un-committed money slider (a purchasable blow, sized but not paid)
    battle.throwStage, battle.throwFrom = nil, nil -- a two-stage throw never carries across turns either
    battle.throwCells, battle.throwSet = nil, nil
    battle.hoverItem = nil
    battle.waitPreview = false -- the first-press Wait preview never carries to a new actor's turn
    battle.keySlot = nil -- the keyboard-selected slot (its item's tooltip); a new actor's grid is a new set of slots
    battle.notice = nil -- a refusal belonged to the turn it was refused on
    battle.rangeCells = {}
    battle.rangeReach = {}
    battle.rangeFor = nil
    battle.moveCells = {}
    battle.threatCells = {}
    battle.attackReach = {}
    battle.movePath = nil
    if not current then return end
    -- A soft tick as the active unit changes -- but a more present cue when control returns to the
    -- PLAYER, so they hear their turn begin rather than only see it. Skipped on a resume: the same
    -- turn is continuing after a free action, not beginning, so it should not re-announce itself.
    if not resume then
        Sound.play(Combat.isPlayerControlled(current) and "battle.playerturn" or "battle.turn")
    end
    computeDanger() -- every turn, so the "Threats" survey toggle stays fresh on enemy turns too
    -- A unit surfacing mid-channel doesn't take an interactive turn -- its slot IS the spell resolving.
    -- Hold a beat on the telegraphed tiles (like the AI's think-pause) so the blast reads, then
    -- battle.update fires resolveChannel. Works for both sides: an enemy Meteor Storm resolves itself,
    -- with no player-vs-AI branch involved.
    if current.channel then
        battle.resolveTimer = AI_DELAY
        return
    end
    if Combat.isPlayerControlled(current) then
        if not resume then
            battle.map:flareTurn(current) -- pull the eye to the unit whose move just began (ui/battle_map.lua)
        end
        computeReachable(current)
        computeThreat(current)
        armDefaultAction(current) -- start with the default action armed (its range shown by default)
        -- Auto-battle: a player unit the player has asked to run itself (the Tactics tab's switch)
        -- gets the AI's think-pause instead of waiting for input. The overlays above are computed
        -- FIRST and deliberately so -- the board still shows this unit's reach and danger while it
        -- thinks, because the player is watching it play and needs to see what it is looking at.
        --
        -- `autoPending` rather than a mode flag: any input during the pause cancels it and hands the
        -- turn straight back (see battle.keypressed / mousepressed). That is what makes the feature
        -- safe to hand a player -- it can always be taken back, on the turn it matters, without
        -- opening a menu.
        if autoAllowed() and (current.char.autoBattle or battle.autoAll) then
            battle.aiTimer = AI_DELAY
            battle.autoPending = current
        end
        -- Snap the cursor to the new actor for keyboard/pad play. But if the mouse is the live device
        -- and still resting on a board cell, keep the cursor under it instead -- so a target the player
        -- was already hovering stays aimed and its action preview appears at once, without a mouse jiggle.
        local hoverX, hoverY
        if battle.mouseX and InputMode.isMouse() then
            hoverX, hoverY = battle.map:cellAt(battle.mouseX, battle.mouseY)
        end
        if hoverX then
            battle.map.cursor.x, battle.map.cursor.y = hoverX, hoverY
        else
            battle.map.cursor.x, battle.map.cursor.y = current.x, current.y
            -- Keyboard/pad: the turn opened with the default weapon armed (armDefaultAction), so land
            -- the aim on the nearest foe now -- the player confirms with Enter/A, or cycles the ring.
            snapToNearestTarget()
        end
    else
        battle.aiTimer = AI_DELAY
    end
end

-- Walk on the reinforcements a lesson step calls for -- the village fight's demon grunt, arriving
-- the moment the Clear Out that cleared the imps has finished resolving. Combat.addUnit is the same seam
-- a summon arrives through, so the newcomer joins the turn order, the board and every query with no
-- further wiring; it gets a script key off its spawn cell exactly like the units placed at start.
--
-- The player's line is broken but their company is not: raise the bench chooser instead of letting the
-- fight be decided. Defined further down, with the rest of the rotation UI (it leans on the chooser,
-- notify and refreshView); declared here because resolveAdvance below has to consult it BEFORE it asks
-- Combat.evaluate anything. See the rotation section.
local offerLastStand

-- Recompute the turn-order preview + battlefield overlays and hand them to the widgets. Defined far
-- below (it leans on nearly every helper in this file); declared here because the rotation section --
-- which sits between the turn loop and it -- has to call it after a swap changes what is on the board.
-- Without the declaration those calls would resolve to a nil GLOBAL, which Lua only tells you about at
-- the moment the player actually rotates.
local refreshView

-- The bench chooser's open/close pair, defined far below with the rest of the rotation UI. Declared up
-- here, rather than beside them, because confirm() now reaches openBenchChooser as well: a click on lit
-- rally ground sends a reserve in. A local declared AFTER its caller is not a forward declaration at
-- all -- the call would compile against a nil GLOBAL, and Lua would only mention it at the instant a
-- player actually clicked the tile. Moving the declaration costs nothing (the same two names, read
-- earlier) and this file has no room for a third.
local closeBenchChooser, openBenchChooser

-- Claimed once from the lesson rather than checked against the board, because a spawned unit can
-- die: "is it already here?" has no honest answer, so the lesson remembers instead.
local function spawnReinforcements()
    local spawns = battle.tutorial and Tutorial.claimSpawn(battle.tutorial)
    if not spawns then return end
    for _, s in ipairs(spawns) do
        -- Grown like any other arrival on the far side. The village grunt this exists for is
        -- `scaling = false`, so it stays blueprint-exact and the parry lesson's arithmetic holds.
        local unit = Combat.addUnit(battle.combat,
            Growth.spawn(s.char, battle.enemyLevel, battle.floorLevel), "enemy", s.x, s.y)
        unit.scriptKey = s.x .. "," .. s.y
        -- A reinforcement may name where it lands in the ORDER as well as on the board. Combat.addUnit
        -- gives an arrival its natural initiative, which drops it wherever its own speed says -- fine
        -- for a summon, but a scripted arrival is a beat in a scene, and a beat has to fall in the
        -- right place. The village grunt claims 0 so it acts at once: its charge, Rowan's answer and
        -- the player's turn have to happen in that order or the lesson between them makes no sense.
        if s.initiative then unit.initiative = s.initiative end
        Combat.logEvent(battle.combat, "action",
            string.format("%s joins the fight!", unit.char.name or "A demon"), unit)
    end
end

-- Walk a COMMITTED wave plan onto the board (Combat.previewWaveArrival built it a couple of turns ago
-- and it has been telegraphed since). For every landing tile still free, a body; for every one a unit
-- now stands on, NOTHING -- a tile the player has marched onto in the meantime turns its reinforcement
-- back, so holding the marked ground denies the muster outright. The chars were instantiated when the
-- plan was committed, so nothing is rolled twice between the promise and the arrival.
local function fireWave(plan)
    if not plan then return end
    for i, t in ipairs(plan.tiles) do
        local char = plan.chars[i]
        if Combat.footprintFree(battle.combat, t.w, t.h, t.x, t.y) then
            local unit = Combat.addUnit(battle.combat, char, "enemy", t.x, t.y)
            Combat.logEvent(battle.combat, "action",
                string.format("%s joins the fight!", unit.char.name or "A demon"), unit)
        else
            Combat.logEvent(battle.combat, "action",
                string.format("%s is turned back -- the ground is held.", (char and char.name) or "A reinforcement"))
        end
    end
end

-- Walk on any reinforcement WAVES whose tick has come (objective.waves = { { at = <ticks>,
-- composition = ids|fn, from = <edge descriptor> }, ... }). `at` is a mark on the SAME clock the win
-- conditions read, so a wave and a "survive" duration are quoted in one unit -- ticks -- the player
-- already sees everywhere. `from` says which SIDE the wave walks on from (default: behind the enemy
-- line; see Combat.resolveWaveEdge for the top/bottom/left/right/random/flank/open/surround forms),
-- resolved against the live board so the dynamic modes react to how the fight has developed.
--
-- A wave with `every = N` instead RECURS: it fires every N ticks for as long as the fight lasts, the
-- endless-reinforcement shape a `reach`/escort fight wears so the road can never be won by attrition
-- (Arena.normalizeObjective synthesizes one for every reach objective). `maxAlive` caps it: while the
-- board already holds that many living enemies the recurrence holds its breath, so it TOPS UP toward
-- a strength rather than piling on without limit. `count` caps the number of firings.
--
-- Each one-shot wave fires once; both kinds arrive through Combat.addUnit, so a newcomer joins the
-- turn order, the board and every query with no further wiring. Generic cousin of spawnReinforcements.
--
-- A wave does not simply appear. LEAD_TICKS before it is due it COMMITS -- Combat.previewWaveArrival
-- resolves its edge, its landing tiles and its roster once, off the live board, and that plan is held.
-- refreshView telegraphs the committed plan (overlays.reinforcements) and fireWave spawns FROM it, so
-- the marker the player sees and the bodies that land are the same thing, and a dynamic edge cannot
-- drift between the promise and the arrival. A crowded (`maxAlive`) or retired (`count`) wave drops its
-- commit and shows nothing until it can fire again.
local LEAD_TICKS = 2 * Status.TICKS_PER_TURN -- how far ahead a wave commits and starts telegraphing

-- Nothing left to outlast: with the board cleared during a `survive`, the next muster is pulled forward
-- rather than letting the clock run down over an empty field. Without it, killing the wood's last wolf
-- early leaves the player pressing Wait at nobody for the rest of the duration.
--
-- Only the EARLIEST pending wave moves, so the tide keeps its authored shape -- it just stops making the
-- player wait for it -- and it is pulled to ONE TURN out rather than to now, so the muster still
-- telegraphs and can still be turned back by marching onto the ground it lands on. A wave already due
-- sooner than that is left alone.
--
-- `survive` only. A `defend` fight's waves are its pacing (the flight leg's lesson beats are written
-- against those ticks) and a `reach` fight's trickle is pressure on a road the player advances by
-- walking -- neither is standing still waiting for a clock.
local function pullMusterForward(waves, clock)
    local soonest
    for i, wave in ipairs(waves) do
        local st = battle.combat.waveState[i]
        -- A retired wave has nothing left to send, so it is not what the empty board is waiting for.
        if not (wave.count and st.fires >= wave.count) and st.nextAt < math.huge then
            if not soonest or st.nextAt < soonest.nextAt then soonest = st end
        end
    end
    local due = clock + Status.TICKS_PER_TURN
    if soonest and soonest.nextAt > due then soonest.nextAt = due end
end

local function spawnWaves()
    local obj = battle.combat and battle.combat.objective
    local waves = obj and obj.waves
    if not waves then return end
    local state = battle.combat.waveState
    local clock = battle.combat.clock or 0
    local ctx = battle.encounterCtx or {}
    for i, wave in ipairs(waves) do
        -- First fire lands at `at` for a one-shot, at `every` for a recurring wave that gives no
        -- explicit start (so an endless wave holds off one period before its first reinforcement).
        state[i] = state[i] or { fires = 0, nextAt = wave.at or wave.every or 0 }
    end
    if obj.type == "survive" and Combat.aliveCount(battle.combat, "enemy") == 0 then
        pullMusterForward(waves, clock)
    end
    for i, wave in ipairs(waves) do
        local st = state[i]
        local capped = wave.count and st.fires >= wave.count
        local crowded = wave.maxAlive and Combat.aliveCount(battle.combat, "enemy") >= wave.maxAlive
        if capped or crowded then
            -- Retired, or a top-up wave holding its breath while the board is full: no commit, so no
            -- telegraph and nothing to fire until the board makes room (or, for `count`, ever again).
            st.committed = nil
        elseif clock >= st.nextAt then
            -- Due. Fire from the plan committed in the lead window; if that window was skipped in one
            -- clock jump (a very slow unit's turn elapsing many ticks at once), resolve it in place so
            -- the wave still lands -- just without the early warning.
            fireWave(st.committed or Combat.previewWaveArrival(battle.combat, wave, ctx))
            st.fires = st.fires + 1
            st.committed = nil
            -- Recurring waves rearm relative to the fire that just happened (so a `maxAlive` stall
            -- doesn't bank up owed waves); a one-shot wave is retired.
            st.nextAt = wave.every and (clock + wave.every) or math.huge
        elseif clock >= st.nextAt - LEAD_TICKS and not st.committed then
            -- Entering the lead window: resolve the arrival once and HOLD it, so the telegraph is stable
            -- (a random edge is fixed here, not re-rolled every frame) and the spawn reads the same plan.
            st.committed = Combat.previewWaveArrival(battle.combat, wave, ctx)
        end
    end
end

-- Charge `unit`'s just-ended turn what the LESSON says it costs, rather than the move-plus-action
-- total the combat model already billed. A guided fight's turn order is authored (see `pace` in
-- data/tutorials/village.lua), and this is the half that holds it: without it the order drifts apart
-- again on the second pass, because a mace and a sword do not come round at the same rate.
--
-- Applied here, after the model has ended and rebased the turn, so it overwrites a settled number in
-- a settled frame -- "your next turn is N ticks out" -- and rebases again to seat everyone. Doing it
-- from inside the combat model would mean teaching endTurn about lessons; doing it here keeps the
-- model unaware that a tutorial exists.
--
-- Deliberately NOT a freeze on the timeline. The authored cost decides where a unit lands; anything
-- the fight does to it afterwards still counts -- which is what leaves the Jolt's stun free to shove
-- the grunt's card down the strip, the one place the lesson teaches the turn order by moving it.
local function pacedTurn(unit)
    if not (unit and battle.tutorial) then return end
    local cost = Tutorial.paceTurn(battle.tutorial, unit.scriptKey or unit.char.id)
    if not cost then return end
    unit.initiative = cost
    Combat.rebase(battle.combat)
end

-- The real hand-off, run once an action's reactions have played: resolve the objective, else start
-- the next unit's turn.
local function resolveAdvance()
    battle.pendingAdvance = nil
    -- A lesson may owe this fight a body, and it is owed BEFORE the objective is judged. The village
    -- Clear Out kills the last two imps, and an empty enemy side is a victory (Combat.evaluate) -- so
    -- without this the battle would be won a beat before the reinforcement that the remaining three
    -- steps are entirely about. Fielded here rather than from refreshView so it cannot lose a race
    -- with the very check it exists to forestall.
    spawnReinforcements()
    spawnWaves() -- timed enemy reinforcements (objective.waves), before the objective is judged
    -- The player's last body just fell, but the company still has someone on the bench: the fight is not
    -- decided, it is waiting. Ahead of Combat.evaluate for the same reason the lesson's reinforcement is
    -- -- otherwise the defeat is declared a beat before the answer to it. Combat.outcomeFor agrees (a
    -- side with a bench is not eliminated), so this is the UI half of one rule, not a second rule.
    if offerLastStand() then return end
    local result = Combat.evaluate(battle.combat)
    if result == "win" then win() return
    elseif result == "loss" then lose() return end
    -- A body of the player's fell and the fight goes on: offer the free reinforcement now, where the
    -- player is already looking, rather than leaving it greyed in the drawer. AFTER the objective is
    -- judged, because a slot that opened on the same blow that ended the fight is not a decision
    -- anyone needs to make. See battle.offerOpenSlot for why this fires on the drop and not the state.
    battle.offerOpenSlot()
    -- A FREE action (or a surged extra action) leaves the model's `combat.turn` open on the same unit
    -- rather than ending it; a normal action nils it in endTurn. So a still-set turn here means "carry
    -- on the open turn", not "begin a new one" -- resume it (see beginTurn) so the per-turn latches the
    -- open turn is holding survive. Every genuine turn boundary (a spent action, a wait, a death) has
    -- already nilled combat.turn, so those still fall through to a fresh beginTurn.
    beginTurn(battle.combat.turn ~= nil)
end

-- End of an action. Drain the model's animation cues (damage/heal/death) into the fx controller, then
-- hold the hand-off while those reactions read (battle.update runs resolveAdvance once the beat and
-- battle.fx:busy both clear). An action that raised no cues and left nothing animating -- a bare move,
-- a wait, a pass -- resolves at once, so non-combat turns stay snappy.
-- Tell the other machine what this one just did, and check the two boards still agree.
--
-- Called once per completed turn, whoever took it -- ours OR theirs. Both peers fingerprint the same
-- turn number and compare, so a divergence is caught on the turn that caused it, while the command
-- responsible is still the one everybody is looking at. Nil in every single-player battle, which is
-- what the guard is for.
-- Declared here and defined further down, once the pieces it leans on exist (advanceTurn, notify,
-- holdLanding). battle.enter hands it to the session as the remote-turn hook, and enter runs long
-- after this file has finished loading, so the forward declaration is enough -- whereas defining it
-- up here would have captured three globals that happen to be nil.
local netApplyRemote

local function netFinishTurn(cmd)
    local session = battle.session
    if not session or not session:isPlaying() then return end
    -- Only a turn WE took is announced; a remote one already came from them.
    if cmd then session:submit(cmd) end
    session:report(session.turn, battle.combat)
    if battle.netLog then
        battle.netLog(string.format("sent #%d %s hash %s", session.turn, tostring(cmd and cmd.kind),
            require("models.state_hash").digestOf(battle.combat)))
    end
end

-- `carried` is a cue list an action raised BEFORE the walk that replays its approach -- held back
-- Cue types that carry sound but paint nothing on the board (ui/combat_fx.lua plays them and returns).
-- An action whose only cues are these needs no impact hold -- see advanceTurn.
local SOUND_ONLY_FX = { status = true, miss = true }

local function hasVisibleFx(events)
    for _, e in ipairs(events) do
        if not SOUND_ONLY_FX[e.type] then return true end
    end
    return false
end

-- since (see holdLanding) so the blow does not land on screen ahead of the feet that carried it.
local function advanceTurn(carried)
    pacedTurn(battle.current)
    local events = Combat.drainFx(battle.combat)
    -- The blow is about to play (ingest below): the ground this action laid -- a summoned zone, a
    -- raised wall, a keg set down, a status painting its field -- was held off the board through the
    -- approach walk (holdLanding). Release it now so it blooms in WITH the impact rather than before
    -- the caster ever arrived to make it.
    battle.heldObjects = nil
    if carried then
        battle.fx:hold(carried, -1) -- the approach has finished; the blow may be seen now
        if events then
            for _, e in ipairs(events) do carried[#carried + 1] = e end
        end
        events = carried
    end
    if events then battle.fx:ingest(events, battle.current) end
    -- Only a VISIBLE reaction earns the impact beat. Some cues carry sound alone -- a status landing, a
    -- blow voided outright (ui/combat_fx.lua) -- and an action that raised nothing else (a bare Defend)
    -- must still resolve at once rather than sit through a half-second of nothing, exactly as it did
    -- before those cues existed. The sound already played during ingest above.
    if (events and hasVisibleFx(events)) or battle.fx:busy() then
        battle.pendingAdvance = { hold = IMPACT_PAUSE }
    else
        resolveAdvance()
    end
end

-- ---------------------------------------------------------------------------
-- Walking. A move is played out one tile at a time rather than teleporting, so the route a unit
-- takes is legible -- and so is what it walks into, since the model springs each tile's trap and
-- hazard on the very beat the unit lands there (Combat.stepMove). Both sides walk.
-- ---------------------------------------------------------------------------

-- Is a unit mid-walk? The board is mid-animation, so player input and the AI clock both hold.
local function walking()
    return battle.walk ~= nil
end

-- How long a refusal notice stays up, in seconds.
local NOTICE_LIFE = 2.2

-- Say why an action was refused. Every path that turns a player's activation down -- an arm, a
-- number-key, a click-to-strike -- routes its Combat.itemBlockReason here instead of returning
-- silently, so a dead click always explains itself (a grayed slot only reads once you go looking for
-- the tooltip). Drawn over the board by drawNotice and fading on its own timer.
local function notify(text, quiet)
    if not text then return end
    battle.notice = { text = text, life = NOTICE_LIFE }
    -- A refusal rings the "denied" cue; pass quiet for an informational notice (the wind-up readout),
    -- which is feedback, not a rejection. Silent until the file exists (models/sound.lua).
    if not quiet then Sound.play("ui.denied") end
end

-- Is a running tutorial refusing this kind of action right now? Announces the lesson's nudge through
-- the same notice banner every other refusal uses, so a dead click always explains itself. Always
-- false in an ordinary battle (no tutorial), and false again once the lesson finishes -- the gate
-- must never outlive it. Guards the discrete verbs; the cell-based ones are refused structurally by
-- `narrow` above.
local function tutorialRefuses(kind)
    if not battle.tutorial or Tutorial.allows(battle.tutorial, kind) then return false end
    -- The nudge goes through the mentor's own panel rather than the generic notice banner: she is
    -- already on screen saying what to do, so the correction belongs in her mouth, and the banner
    -- would land on top of her panel besides. Ages out on its own timer (battle.update), after which
    -- the panel falls back to the step's standing instruction.
    battle.tutorialNudge = { text = Tutorial.nudge(battle.tutorial), life = NOTICE_LIFE }
    return true
end

-- Hand over the item the current lesson step gives the player -- the mentor passing on a battle art
-- mid-fight, because an ability lesson is unteachable to someone carrying only a sword.
--
-- Idempotent (it checks the grid before adding), so it can run every frame from refreshView: the
-- gift lands as soon as it is due no matter which path advanced to the step, and there is no single
-- advancement point to keep in step with. It goes to the step's ACTOR -- the unit being taught --
-- and stays in that character's grid after the battle: the art is genuinely theirs now.
--
-- Held back until the actor actually HOLDS the turn, which is the one thing being every-frame does
-- not give for free. A step can become current partway through somebody else's turn -- the mentor's
-- own strike advances the lesson -- and the item would then appear in the panel mid-swing, several
-- seconds before the hand that receives it can do anything with it, reading as a slot filling
-- itself. Waiting costs nothing (the step is already waiting on that turn) and puts the gift where
-- the fiction puts it: she passes it over when it is your move.
local function grantLessonItem()
    local id = battle.tutorial and Tutorial.grant(battle.tutorial)
    if not id then return end
    local actorId = Tutorial.step(battle.tutorial).actor
    if not (battle.current and battle.current.alive and battle.current.char.id == actorId) then
        return
    end
    for _, u in ipairs(battle.combat.units) do
        if u.alive and u.char.id == actorId then
            for _, held in ipairs(Character.eachItem(u.char)) do
                if held.id == id then return end -- already handed over
            end
            -- A full grid simply refuses, and the step's own gate then refuses the arming that
            -- follows: better a lesson that stalls visibly than one that silently drops the gift.
            --
            -- Deliberately SILENT: no notice banner. The gift is already announced twice over -- the
            -- mentor is mid-sentence handing it to you, and the coach bubble is pinned to the slot it
            -- landed in -- and a third announcement lands in the gutter the mentor's own panel
            -- occupies, clipping the line that is doing the announcing.
            Character.addItem(u.char, Item.instantiate(id))
            return
        end
    end
end

-- Tell a running tutorial that `unit` just committed an action, so it can advance to the next step
-- when that was the one being asked for. Called at the handful of points where an action actually
-- resolves rather than in advanceTurn, because that is where the target is still known: a strike
-- that kills leaves nothing on the cell for a later lookup to find.
--
-- Events that don't match the current step are ignored by the model, so this can be called freely --
-- there is no need to work out here whether the lesson cares.
local function observeAction(kind, unit, x, y, targetId, itemId)
    if not battle.tutorial then return end
    Tutorial.observe(battle.tutorial, {
        kind = kind, actor = unit.char.id, x = x, y = y, target = targetId, item = itemId,
    })
end

-- Refuse `item` for `unit` if anything blocks it, announcing the reason. Returns true when the
-- action was blocked (the caller should bail), false when it may proceed.
local function refuseIfBlocked(unit, item)
    local blocked = Combat.itemBlockReason(unit, item)
    if not blocked then return false end
    notify(string.format("%s: %s", item.name or "That item", blocked.text or blocked.reason))
    return true
end

-- Should player input be held right now? True mid-walk, and also while the current unit is resolving
-- a channel -- a channeling caster (even a player one) doesn't get an interactive turn; its slot IS
-- the spell going off, and letting the player arm a second action then would double-cast. The input
-- guards below test this instead of raw walking().
local function busy()
    return walking() or battle.pendingAdvance ~= nil
        or (battle.current ~= nil and battle.current.channel ~= nil)
end

-- Play one tile of the captured route: slide the sprite onto the tile this step enters, and float any
-- cue (a sprung trap, a hazard's bite, an overwatch shot) it triggered. Returns false once the route
-- is exhausted, so the caller can end the walk. The unit's model position is already the END of the
-- route, so the slide is named against the tile this step arrives on, not against unit.x/unit.y.
local function walkStep(w)
    w.i = w.i + 1
    local step = w.steps[w.i]
    if not step then return false end
    w.timer = MOVE_STEP
    Sound.play("battle.step") -- one footstep per tile of the route, either side's walk
    battle.fx:setSlide(w.unit, step.fromX, step.fromY, MOVE_STEP, nil, step.x, step.y)
    -- A trap that sprang, a hazard that bit, an overwatch shot -- float its number on arrival. No
    -- actor leans in: this is damage taken while walking, not a strike the unit made. This step's cues
    -- were held up front (beginWalk) so a unit felled LATER in the route keeps its HP bar and turn-strip
    -- card until the tile that fells it actually plays; release this step's hold as it plays so its blow
    -- lands live -- awaiting (while held) hands off to the death fade (once ingested) with no gap.
    if step.fx then battle.fx:hold(step.fx, -1) end
    battle.fx:ingest(step.fx, nil)
    return true
end

-- Begin replaying `steps` as `unit`'s walk, calling `onDone` when it comes to rest. The first step is
-- played AT ONCE, before any frame is drawn -- because the model already teleported `unit` to the
-- route's end, and until a slide is set the sprite draws at that end. A draw can land between the
-- walk's creation and updateWalk's first tick (an AI move begins mid-update, after updateWalk already
-- ran for the frame), and without this prime that draw would flash the sprite on its destination tile
-- for a frame before the walk snaps it back to the origin. Priming here places it on the origin from
-- frame one.
local function beginWalk(unit, steps, onDone)
    local w = { steps = steps, i = 0, timer = 0, onDone = onDone, unit = unit }
    battle.walk = w
    -- The model resolved the ENTIRE route in startWalk, so every trap/overwatch death down the line has
    -- ALREADY set alive=false -- which drops that unit from Combat.buildTimeline at once. Hold every
    -- step's cues now so a unit felled partway keeps its HP bar and turn-strip card (fx:awaiting) until
    -- walkStep plays the tile that fells it; without this its card blinks off the timeline the instant the
    -- walk begins, a whole route before it is seen to die. walkStep releases each step's hold as it plays.
    for _, step in ipairs(steps) do
        if step.fx then battle.fx:hold(step.fx, 1) end
    end
    walkStep(w)
    return w
end

-- Send `unit` walking to (x, y), calling `onDone` once it comes to rest -- on the destination, or
-- on the tile it died on. Returns false, having changed nothing, if the move is illegal. The move
-- is spent the instant the walk starts: the blue reachable band and the red threat band both clear,
-- so nothing on the board invites a second move while the unit is still on its feet.
-- `cells`, when given, is a player-steered route (see updateMovePath): the walk follows it exactly
-- rather than the shortest path, as long as Combat.planMoveVia accepts it. Any failure (or no route)
-- falls back to the shortest path to (x, y) -- so the walk is never worse than the direct one.
local function startWalk(unit, x, y, onDone, cells)
    local plan = cells and Combat.planMoveVia(battle.combat, unit, cells)
    plan = plan or Combat.planMove(battle.combat, unit, x, y)
    if not plan then return false end
    -- The move happens HERE, all of it: every tile entered, every trap sprung, every overwatch shot
    -- taken. What comes back is the route as it was walked, with each tile's cues attached, and what
    -- battle.walk holds from this point on is a playback position -- not a handle the frame clock
    -- uses to push the model forward one tile at a time. The model is finished before the first
    -- frame of the walk is drawn.
    local steps = Combat.runMove(battle.combat, plan)
    beginWalk(unit, steps, onDone)
    battle.reachable, battle.moveCells = {}, {}
    battle.threatCells, battle.attackReach = {}, {}
    -- The armed/hovered ability's band was built over the move budget this walk just spent, so it is
    -- stale the moment the feet leave. Dropping `rangeFor` (the "what are these sets for" marker) is
    -- what forces the rebuild: refreshView and armedActionAt recompute only when the previewed ITEM
    -- changes, so hovering or re-arming the same item would otherwise redraw the pre-move
    -- walk-and-strike reach over a unit that can no longer walk.
    battle.rangeCells, battle.rangeReach, battle.rangeFor = {}, {}, nil
    battle.movePath = nil
    return true
end

-- Replay one tile of the captured route per MOVE_STEP seconds, then hand off to the walk's onDone.
-- The first step lands at once (the unit is already standing on the origin); every step after rests
-- on the tile it entered, so a trap that fired or a hazard that bit is on screen long enough to see.
--
-- Nothing here touches the model -- it finished the whole walk back in startWalk. This only decides
-- when each tile's cues are allowed to be seen, which is why a route the model resolved in one call
-- still reads at a walking pace.
local function updateWalk(dt)
    local w = battle.walk
    w.timer = w.timer - dt
    if w.timer > 0 then return end
    if walkStep(w) then return end
    battle.walk = nil
    if w.onDone then w.onDone() end
end

-- Take everything the action just resolved and keep it off the screen until the walk replaying its
-- approach has finished.
--
-- CombatFx already does this for the second and later beats of an exchange, and for the same reason
-- its comment gives: the model settles the whole thing before any of it is seen, so a bar would
-- drain and a corpse drop ahead of the blow that earned it. That used to leave the FIRST beat alone
-- because a cast resolved at the moment the view was handed it -- which stopped being true when the
-- approach started being walked after the strike had already landed. Without this a unit's health
-- visibly falls while its attacker is still three tiles away.
--
-- Identity set of every placed board object standing right now: hazards, walls, props, and the
-- statuses units carry. Snapshotted the instant before an action resolves so holdLanding can tell the
-- ground the action LAYS from the ground already there -- membership by table identity, so a zone that
-- is merely refreshed (Hazard.place returning the existing one) still counts as already-present.
local function boardObjects()
    local set = {}
    for _, h in ipairs(battle.combat.hazards or {}) do set[h] = true end
    for _, w in ipairs(battle.combat.walls or {}) do set[w] = true end
    for _, p in ipairs(battle.combat.props or {}) do set[p] = true end
    for _, u in ipairs(battle.combat.units or {}) do
        set[u] = true -- the body itself, so a summon conjured this turn reads as freshly arrived
        for _, st in ipairs(u.statuses or {}) do set[st] = true end
    end
    return set
end

-- A live object list narrowed to what may be drawn this frame -- everything except the ground an
-- in-flight walk-then-cast has laid but not yet been seen to lay (battle.heldObjects, see holdLanding).
-- Returns the list untouched when nothing is held, so the common case allocates nothing.
local function shownObjects(list)
    local held = battle.heldObjects
    if not held or not list then return list end
    local out = {}
    for _, o in ipairs(list) do
        if not held[o] then out[#out + 1] = o end
    end
    return out
end

-- Returns the held list, to be handed to advanceTurn when the feet stop.
--
-- `pre` (optional) is a boardObjects() snapshot taken the instant before the action resolved: with it,
-- every hazard, wall, prop or carried-status field the action LAID (anything now on the board that was
-- not in the snapshot) is stashed in battle.heldObjects, which the overlay pass hides until advanceTurn
-- reveals it when the blow plays. Without this the fx cues wait for the feet but the GROUND does not --
-- a summoned zone flashes onto the board while the caster is still three tiles away walking in.
local function holdLanding(pre)
    local events = Combat.drainFx(battle.combat)
    if events then
        battle.fx:hold(events, 1)
        -- The same argument, for position rather than health: a blow that shoves has ALREADY moved its
        -- target in the model, so without this the victim stands on its knocked-back tile all through
        -- the approach and then snaps home to be shoved again once the feet stop. The unit still walking
        -- in is exempt (see pinSlides): a hit-and-run blow shoves the striker itself, and pinning the
        -- body the walk is driving would freeze it on its destination instead of walking it there.
        battle.fx:pinSlides(events, battle.walk and battle.walk.unit)
    end
    if pre then
        local held
        local function scan(list)
            for _, o in ipairs(list or {}) do
                if not pre[o] then held = held or {}; held[o] = true end
            end
        end
        scan(battle.combat.hazards)
        scan(battle.combat.walls)
        scan(battle.combat.props)
        scan(battle.combat.units) -- a body summoned this turn (drawUnits/trackArrivals honour the set)
        for _, u in ipairs(battle.combat.units or {}) do scan(u.statuses) end
        battle.heldObjects = held
    end
    return events
end

-- Which grid cell `item` sits in for `unit`. A networked command names an item by CELL rather than
-- by id, because an id is ambiguous -- a character can carry two of the same blueprint at different
-- upgrade levels -- while the cell is both what the player clicked and the same on the far machine,
-- which rebuilt this character from the same snapshot. See models/command.lua.
local function slotOf(unit, item)
    local inv = unit and unit.char and unit.char.inventory
    if not (inv and item) then return nil end
    for cell = 1, Character.MAX_INVENTORY do
        if inv[cell] == item then return cell end
    end
    return nil
end

-- Apply a turn the other player took, and play it back here. (Forward-declared above.)
--
-- Deliberately the same shape as our own approach-and-strike: Command.apply resolves the whole thing
-- against the model at once and hands back the route, then the walk replays it while the blow's cues
-- are held until the feet stop. So a remote turn reads exactly like a local one -- the opponent's
-- unit walks rather than teleporting, and its strike lands when it arrives.
--
-- A refusal here is serious. The command was legal on their board, so if it is not legal on ours the
-- two have already diverged; the fingerprint exchange would catch it a moment later anyway, and
-- saying so now names the command that did it.
function netApplyRemote(cmd)
    local current = battle.combat.turn and battle.combat.turn.unit
    if not current then
        if battle.netLog then battle.netLog("remote cmd arrived with no unit up -- dropped") end
        return
    end
    -- Snapshotted before the command resolves so the ground it lays is held off the board until its
    -- walk replays (holdLanding). Command.apply is atomic over move AND action, so unlike the local
    -- paths a zone the approach itself sprang rides in the held set too -- a minor cosmetic nuance on
    -- the remote side, where the whole turn arrives at once anyway.
    local pre = boardObjects()
    local res, err = Command.apply(battle.combat, current, cmd)
    if not res then
        notify("Out of step with the other player.")
        if battle.session then battle.session:close("refused a remote command: " .. tostring(err)) end
        return
    end
    -- Fingerprint BEFORE handing the turn on, because that is where the sender fingerprints too
    -- (netFinishTurn runs inside the action, ahead of advanceTurn). Both peers must measure the same
    -- MOMENT in a turn, not just the same turn: advanceTurn starts the next unit's turn, so a peer
    -- that hashed afterwards would include a turn the other had not begun and report a desync on
    -- every single command. Which is exactly what it did.
    if battle.session then
        battle.session:report(battle.session.turn, battle.combat)
        if battle.netLog then
            battle.netLog(string.format("recv #%d %s hash %s", battle.session.turn,
                tostring(cmd.kind), require("models.state_hash").digestOf(battle.combat)))
        end
    end

    local blow = holdLanding(pre)
    if res.moved and #res.moved > 0 then
        battle.reachable, battle.moveCells = {}, {}
        battle.threatCells, battle.attackReach = {}, {}
        battle.movePath = nil
        beginWalk(current, res.moved, function() advanceTurn(blow) end)
    else
        advanceTurn(blow)
    end
end

-- Is the lesson TALKING TO THE PLAYER right now -- the step's actor holding the turn, with nothing
-- mid-resolution? Both halves of the tutorial's UI hang off this, and they hang off the SAME answer
-- on purpose: an instruction and the voice giving it should not be able to disagree about whether
-- they are being addressed to anyone.
--
-- It is false during the mentor's own turns, the enemies', and the walk a click has already started.
-- Everything the lesson says is something to DO, and a standing instruction left up through a beat
-- the player cannot act in reads as a prompt the game is ignoring.
local function lessonAddressesPlayer()
    if not (battle.tutorial and battle.lessonOpen) then return false end
    -- A conversation owns the screen while it plays. The lesson's own UI would otherwise draw
    -- UNDERNEATH it -- the coach bubble on the board and the mentor's panel in the gutter the
    -- dialogue box occupies -- which is two of her talking at once, in two different registers.
    -- (The village opening would escape it anyway -- Rowan holds the first turn by the lesson's own
    -- `leads`, so nothing has opened yet -- but that is a fact about one lesson's turn order, and
    -- this has to hold for any scene played over any board.)
    if Conversation.active then return false end
    if battle.over or busy() then return false end
    local step, current = Tutorial.step(battle.tutorial), battle.current
    if not (step and current) then return false end
    return Combat.isPlayerControlled(current) and current.char.id == step.actor
end

-- Sheathe the armed item back to move mode. A player-initiated cancel (Esc, gamepad B, re-clicking
-- the armed slot, cycling past the last ability) sounds the back cue; `quiet` suppresses it for the
-- INTERNAL disarms -- switching to Blink, or the tutorial's per-frame auto-disarm -- which are not a
-- cancel the player asked for and would otherwise blip every frame.
local function cancelArm(quiet)
    if not quiet and battle.mode == "armed" then Sound.play("ui.cancel") end
    battle.mode = "move"
    battle.armedItem = nil
    battle.windup = 0
    battle.throwStage, battle.throwFrom = nil, nil
    battle.throwCells, battle.throwSet = nil, nil
end

-- Back out one step of a two-stage throw: from the landing phase, drop the grabbed tile and return to
-- the grab phase (rebuilding its adjacent reach); from the grab phase, disarm outright. Returns true
-- when it consumed the cancel, so Esc / right-click / gamepad B can fall through to a full disarm only
-- when there is no throw phase to step back from.
local function throwStepBack()
    if battle.throwStage == "dest" then
        battle.throwStage, battle.throwFrom = "grab", nil
        battle.throwCells, battle.throwSet = nil, nil
        if battle.armedItem then computeRange(battle.current, battle.armedItem) end
        snapToNearestTarget()
        Sound.play("ui.cancel")
        return true
    end
    return false
end

-- The wind-up a chargeable channel (Saber's signature) is held at is NOT tuned in the background any
-- more -- a scroll knob on the armed board was undiscoverable and easy to skip past. The depth is now
-- chosen in a modal that opens the moment the swing is confirmed on a target (openWindupChooser below),
-- so battle.windup simply holds the floor the arm opened at until that panel commits a deeper hold.

-- Toggle a Blink (moveBehavior) item on or off for `unit`. A free, turn-neutral flip: it spends
-- nothing and ends no turn -- mana is paid per jump, at move time (Combat.blink). Flipping it
-- recomputes the move overlay so the blue band switches between walk and teleport at once. If the
-- unit cannot afford even one jump, computeReachable simply keeps showing the walk (a silent
-- fallback), so arming it is never a trap.
local function toggleBlink(unit)
    if battle.mode == "armed" then cancelArm(true) end
    unit.blinkArmed = not unit.blinkArmed
    computeReachable(unit)
    computeThreat(unit)
end

-- Arm an ability item (or toggle it off if already armed). A Blink item toggles teleport movement
-- instead of arming a cast (it has a moveBehavior, not an activeAbility).
local function armItem(item)
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if tutorialRefuses("arm") then return end
    -- A step that names an item admits only that one: "ready your sword" is not satisfied by the
    -- torch. Same nudge, same banner-free path as the coarse refusal above.
    if battle.tutorial and item and not Tutorial.allowsItem(battle.tutorial, item.id) then
        battle.tutorialNudge = { text = Tutorial.nudge(battle.tutorial), life = NOTICE_LIFE }
        return
    end
    if item and item.moveBehavior and item.moveBehavior.mode == "teleport" then
        toggleBlink(current)
        return
    end
    if not (item and item.activeAbility) then return end
    if battle.armedItem == item then cancelArm() return end
    -- Anything that would make useItem reject the cast -- an unpayable cost, a spent stack, a
    -- missing adjacent item (Rain of Arrows without its bow) -- leaves it disarmed, and says so.
    -- The grayed slot and its tooltip carry the same reason, but only for a player who goes looking:
    -- an outright click on the slot has to answer for itself.
    if refuseIfBlocked(current, item) then return end
    -- A sight-gated strike (a bow, The Held Breath) can't be armed with nothing in its line -- there
    -- is no shot to take, and arming it anyway would just be a way to walk around under its banner.
    -- Accounts for tiles the unit could move to and fire from, so a foe you can reach-and-shoot still
    -- arms; only a truly line-less turn is refused. Said out loud, like the block refusal above.
    if not canSightAFoe(current, item) then
        notify(string.format("%s: no line of sight", item.name or "That item"))
        return
    end
    battle.armedItem = item
    battle.windup = windupFloor(item) -- a chargeable signature opens at its floor, not +0
    battle.mode = "armed"
    -- Friendly abilities (heal / buff) highlight green; offensive strikes and trap placements red.
    battle.armedSupport = Combat.isSupportAbility(item.activeAbility)
    battle.armedTile = item.activeAbility.target == "tile" -- tile-target (e.g. summon a trap)
    -- A two-stage throw (Heave) opens in its GRAB phase: the first aim picks the adjacent target, a
    -- second phase then picks where it lands (enterThrowDest). nil for every single-aim ability.
    battle.throwStage = Item.isThrow(item.activeAbility) and "grab" or nil
    battle.throwFrom, battle.throwCells, battle.throwSet = nil, nil, nil
    -- Observed BEFORE the range is built: arming may complete a tutorial step, and computeRange
    -- narrows against whatever step is current -- so the strike band that this arming just unlocked
    -- has to be computed under the NEW step, not the arm step that is now finished.
    observeAction("arm", current, current.x, current.y, nil, item.id)
    computeRange(current, item)
    -- Keyboard/pad: arming an item aims it at the nearest valid target at once (mouse aims itself).
    snapToNearestTarget()
    -- A pick sound for SELECTING an action. Only reached on a player-initiated arm (armDefaultAction
    -- inlines its own arm and never calls here), so the turn's auto-arm stays silent.
    Sound.play("battle.select")
end

local function armSlot(n)
    local current = battle.current
    if not current or not Combat.isPlayerControlled(current) then return end
    -- Remember the slot so keyboard play can float its tooltip (battle.draw): pressing the key is how a
    -- pad/keyboard player reads an item, so it must answer even for a passive slot armItem can't arm.
    -- A SECOND press of the slot already selected toggles it back off -- the arm and its tooltip clear
    -- together. armItem itself undoes the underlying arm/blink on the repeat; we mirror that in keySlot.
    local item = current.char.inventory[n]
    battle.keySlot = (item and battle.keySlot ~= n) and n or nil
    armItem(item)
end

-- Gamepad Y cycles through the current unit's ability items (past the end -> back to move).
-- Items that can't be activated right now are skipped rather than landed on -- armItem would
-- refuse them, leaving Y with nothing to advance to.
local function cycleAbilityItem()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if tutorialRefuses("arm") then return end
    local items = Combat.abilityItems(current.char)
    if #items == 0 then return end
    local idx = 0
    for i, it in ipairs(items) do
        if it == battle.armedItem then idx = i break end
    end
    for i = idx + 1, #items do
        if not Combat.itemBlockReason(current, items[i]) then
            armItem(items[i])
            -- Float the tooltip for the slot the pad just landed on, same as a numpad press (armSlot).
            for slot, it in ipairs(current.char.inventory) do
                if it == items[i] then battle.keySlot = slot break end
            end
            return
        end
    end
    battle.keySlot = nil -- cycled past the end, back to plain move: nothing selected, no tooltip
    cancelArm()
end

-- Use the current unit's default ACTION on cell (tx, ty) -- a strike on a foe, or a heal/buff on an
-- ally: if the cheapest stand tile for that cell isn't where the unit already is, move there first
-- (only if it hasn't moved yet), then act -- a click-to-use that folds an approach into one action.
-- No-op if the target is out of this turn's reach, or the default action can't resolve (e.g. an
-- ability the unit can't afford -- unarmed itself is always free). Combat.useItem re-checks the
-- target side, so a mistargeted click simply does nothing.
local function tryDefaultAction(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    -- Don't reposition for a strike useItem would refuse: a cost the unit can't pay, an unmet grid
    -- requirement. Bail before moving (unarmed is free and requires nothing, so this only guards
    -- real weapons), and say why -- this click aimed at a foe, so a silent no-op reads as a bug.
    if refuseIfBlocked(unit, weapon) then return end
    -- A CHARGEABLE signature (The First Motion) is never loosed by a one-click move-mode strike: that
    -- would commit it at its floor and skip the whole depth choice the weapon exists for, with no
    -- wind-up read-out ever shown. Arm it instead -- the actions header turns into the "Wind-up N/max"
    -- read-out, the wheel / +- / bumpers tune it, and a second click on this same foe commits the
    -- chosen depth through the armed path (which passes it to useItem). Non-chargeable defaults strike
    -- at once, as before. (The turn normally opens with the default already armed via armDefaultAction;
    -- this only bites the move-mode click that follows an explicit disarm.)
    if Item.isChargeable(weapon.activeAbility) then
        armItem(weapon)
        return
    end
    -- Who is being struck, read before the blow lands: a lethal hit clears the cell, and the tutorial
    -- needs the id to know whether this was the demon it asked for.
    local victim = Combat.unitAt(battle.combat, tx, ty)
    local function strike()
        if Combat.useItem(battle.combat, unit, weapon, tx, ty) then
            observeAction("attack", unit, tx, ty, victim and victim.char.id, weapon.id)
            advanceTurn()
        end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end -- can't move twice in a turn
        -- Walk into reach first, then strike from where the approach left off. A unit cut down on
        -- the way in (a trap it stepped on) never gets to swing.
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- Strike a revealed enemy trap on (tx, ty) with the default action, folding an approach move
-- into the strike exactly like tryDefaultAction (attackReach records the cheapest stand tile).
-- Combat.strikeTrap re-checks range/visibility/cost; this just handles the click-to-destroy UX.
local function tryDamageTrap(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.strikeTrap(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- A revealed enemy trap on (x, y), or nil. `battle.trapCells` is the per-frame lookup of traps
-- the party can currently see (refreshView), keyed "x,y".
local function revealedEnemyTrapAt(unit, x, y)
    local trap = battle.trapCells and battle.trapCells[x .. "," .. y]
    if trap and trap.side ~= unit.side then return trap end
    return nil
end

-- A living wall on (x, y), or nil. Walls are always visible to both sides, so unlike traps there is
-- no per-side filter -- any wall in reach can be struck down (your own, to open a path; the enemy's,
-- to break through). `battle.wallCells` is the per-frame "x,y" lookup built in refreshView.
local function wallAt(x, y)
    return battle.wallCells and battle.wallCells[x .. "," .. y]
end

-- A living prop on (x, y), or nil. Sideless and always visible, exactly like a wall -- anything in
-- reach can be struck, which for an explosive barrel is the whole point of it being there.
local function propAt(x, y)
    return battle.propCells and battle.propCells[x .. "," .. y]
end

-- Strike a prop on (tx, ty) with the default action, folding an approach move into the strike exactly
-- like tryDamageWall. Combat.strikeProp re-checks range/cost; this handles the click UX.
local function tryDamageProp(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.strikeProp(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- Strike a wall on (tx, ty) with the default action, folding an approach move into the strike
-- exactly like tryDamageTrap. Combat.strikeWall re-checks range/cost; this handles the click UX.
local function tryDamageWall(unit, tx, ty)
    local entry = battle.attackReach and battle.attackReach[tx .. "," .. ty]
    local weapon = battle.defaultAction
    if not entry or not weapon then return end
    if refuseIfBlocked(unit, weapon) then return end
    local function strike()
        if Combat.strikeWall(battle.combat, unit, weapon, tx, ty) then advanceTurn() end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then return end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- A board object on (x, y) an OFFENSIVE weapon can break -- a revealed enemy trap, a wall, or a prop
-- (the barrel) -- paired with the Combat.strike* verb that breaks it, or nil. Same precedence the
-- move-mode confirm() picks a strike target with (trap, then wall, then prop). This is the armed-mode
-- counterpart: the auto-armed default weapon lights a barrel's tile red, so it must be clickable to
-- strike without first disarming to move freely.
local function strikeableObjectAt(unit, x, y)
    local trap = revealedEnemyTrapAt(unit, x, y)
    if trap then return trap, "trap" end
    local wall = wallAt(x, y)
    if wall then return wall, "wall" end
    local prop = propAt(x, y)
    if prop then return prop, "prop" end
    return nil
end

-- Would confirming `item` on (cx, cy) actually DO something -- land on a body, place something,
-- break an object standing there -- or is it a swing at empty air? Combat.castDoesSomething replays
-- the effect as an inert dry run (so a ground-laying ability answers yes on bare earth); the object
-- check adds the barrel/wall/revealed trap the swing would break, which no dry run sees because the
-- object layer isn't a unit.
--
-- Asked from the tile the swing would actually be thrown FROM -- (sx, sy), the stand tile rangeReach
-- recorded for this aim, which a folded-in approach may have moved off the caster's own square. A
-- directional footprint is oriented by where the caster stands (see asIfStandingAt), so asking from
-- the current tile answered for a line that runs off in a different direction than the one the walk-
-- and-strike will sweep: the dry run "found" a body the swing then missed, and the click resolved as
-- an attack on empty air instead of the step the player meant. Defaults to the caster's own tile.
--
-- Memoised on the aim, the item, where the swing fires from and the turn, because the same cell is
-- asked about up to three times a frame -- refreshView's overlay pass, the action-preview tooltip and
-- the confirm itself all route through armedActionAt. Every way the board can change under a held aim
-- moves one of those: a walk moves the actor, a cast ends the turn, and the next turn bumps
-- turnCount (so even a unit granted a second turn on the same tile re-asks).
local castCache = { key = nil, value = false }
local function castConnectsAt(item, cx, cy, sx, sy)
    local unit = battle.current
    if not (unit and item and item.activeAbility) then return false end
    sx, sy = sx or unit.x, sy or unit.y
    local key = tostring(item) .. "@" .. cx .. "," .. cy .. "|" .. sx .. "," .. sy
        .. "#" .. (battle.combat.turnCount or 0)
    if castCache.key ~= key then
        castCache.key = key
        castCache.value = asIfStandingAt(unit, sx, sy, function()
            return Combat.castDoesSomething(battle.combat, unit, item, cx, cy)
        end) or strikeableObjectAt(unit, cx, cy) ~= nil
    end
    return castCache.value
end

-- Break a board object with the ARMED item, walking to the firing tile (entry.fromX/fromY, out of the
-- item's own reach) first when the blow can't land from where the unit stands. The armed-mode sibling
-- of tryDamageProp/Wall/Trap, which strike with the default action in move mode; `kind` selects the
-- Combat.strike* verb, `entry` is the rangeReach stand tile. Combat.strike* re-checks range/cost and
-- returns (false, why) on refusal, which is surfaced the same way an armed cast's refusal is.
local function strikeArmedObject(unit, item, kind, tx, ty, entry)
    local strikeFn = (kind == "trap" and Combat.strikeTrap)
        or (kind == "wall" and Combat.strikeWall)
        or Combat.strikeProp
    local function strike()
        local ok, why = strikeFn(battle.combat, unit, item, tx, ty)
        if ok then
            advanceTurn()
        elseif why then
            notify(string.format("%s: %s", item.name or "That item", tostring(why)))
        end
    end
    if entry.fromX ~= unit.x or entry.fromY ~= unit.y then
        if Combat.hasMoved(battle.combat) then
            notify("Out of reach from here -- already moved this turn")
            return
        end
        return startWalk(unit, entry.fromX, entry.fromY, function()
            if unit.alive then strike() else advanceTurn() end
        end)
    end
    strike()
end

-- What an armed click on (cx, cy) resolves to, for the currently armed item (the turn-start default
-- or an explicitly armed one):
--   { kind = "act",  entry, cells }  -- a valid target here (a foe/ally to hit, a legal tile to
--                                 place): walk to the stand tile (entry.fromX/fromY), then use the
--                                 item. `cells`, when set, is the player-steered route to that stand
--                                 tile so the approach follows the drawn path, not the shortest one.
--   { kind = "move", x, y, cells }  -- no valid target, but the cell is a reachable tile: a single-
--                                 target strike/heal aimed at empty air is a REPOSITION, so walk onto
--                                 it (following the steered `cells` when a route ends there).
--   nil                        -- nothing to do here.
-- The move case is what lets an armed unit still walk freely (like move mode) by clicking an empty
-- tile: without it, aiming empty air would walk to the adjacent stand tile to "strike" nothing --
-- the movement stopping a tile short. A SELF-target ability never takes it (its only aim is the tile
-- it already stands on).
--
-- A TILE-target ability needs the same escape, and can't get it from "is there a body here": an empty
-- tile is a legal aim for it, so every reachable tile is one and the move band vanishes inside the
-- cast band. Whole weapon families aim a tile because their aimed cell is a FACING for an arc or a
-- line -- every spear, axe and greatsword -- and the turn auto-arms the default weapon, so without
-- this a knight had to disarm and re-arm to take a single step. The tie is broken by what the cast
-- would actually DO (castConnectsAt):
--   1. it connects -- a body in the footprint, ground it would lay, an object it would break -> act.
--   2. it connects with nothing, and a move is still available -> walk there (staying armed).
--   3. it connects with nothing and the move is spent -> swing anyway, into empty air. A wasted swing
--      is the player's to make; a click that silently does nothing is not.
-- An offensive swing that catches nobody but your OWN line connects with nothing for this purpose
-- (Combat.castDoesSomething): a facing whose arc runs through an ally is a walk, not an aim -- which
-- is what gives the step back in a corridor, where the company stands shoulder to shoulder and every
-- tile in front of a knight is covered by a friend.
-- `ab.groundAim` pins an ability to (1) whatever the dry run says, for anything whose real work a dry
-- run can't see.
--
-- The stand tile a strike fires from is the steered route's endpoint whenever that tile can legally
-- reach the target (so the player picks WHERE to attack from); otherwise the cheapest tile
-- attackReach recorded in rangeReach.
local function armedActionAt(cx, cy)
    local item = battle.armedItem
    local ab = item and item.activeAbility
    if not ab then return nil end
    -- The range sets may currently describe an ability the player is HOVERING rather than the armed
    -- one; what an armed confirm does is always read from the armed item's own reach.
    if battle.rangeFor ~= item then computeRange(battle.current, item) end
    local occ = Combat.unitAt(battle.combat, cx, cy)
    local support = battle.armedSupport
    local needsOccupant = ab.target == "enemy" or ab.target == "ally"
    local hasTarget = occ and occ.alive and (support and occ.side == battle.current.side
        or not support and occ.side ~= battle.current.side)
    if needsOccupant and not hasTarget then
        -- No unit to hit here, but an OFFENSIVE strike can still break a board object standing on the
        -- tile -- a barrel, a wall, a revealed enemy trap -- exactly as the move-mode default action
        -- does. The red band already lit the tile, so a click has to land the blow rather than fall
        -- through to a reposition (or nothing).
        if not support then
            local obj, kind = strikeableObjectAt(battle.current, cx, cy)
            local entry = obj and battle.rangeReach and battle.rangeReach[cx .. "," .. cy]
            if entry then return { kind = "act", strikeKind = kind, object = obj, entry = entry } end
        end
        if battle.reachable and battle.reachable[cx .. "," .. cy] then
            local mp = movePathTo(cx, cy)
            return { kind = "move", x = cx, y = cy, cells = mp and mp.cells or nil }
        end
        return nil
    end
    local entry = battle.rangeReach and battle.rangeReach[cx .. "," .. cy]
    -- WHERE the swing would be thrown from, resolved before anything asks what it would hit -- because
    -- what a directional cast hits depends entirely on the tile it is thrown from.
    --
    -- The steered route only decides the stand tile when the actor CAN'T already hit from where it
    -- stands. Otherwise the route is ignored and the strike fires in place: the trail extends itself
    -- across every reachable tile the cursor crosses, so merely sweeping the mouse onto a foe drew a
    -- route and silently turned an in-place attack into a walk-and-strike. Steering still picks the
    -- firing tile for anything out of reach, which is the case it exists for.
    -- The endpoint must not BE the target cell: a tile-target cast (summon / AoE placement) steers its
    -- route right onto the target -- the cursor tile is the target -- so honouring that as the stand
    -- tile would walk the caster onto the very cell it means to place on, and the cast then rejects it
    -- as occupied (the caster is now standing there). Excluding it falls back to the cheapest in-range
    -- stand tile (entry), so the placement fires in place instead of turning into a bare move.
    local stand, mp = steeredStand()
    local inPlace = standCanHit(battle.current, ab, item, battle.current.x, battle.current.y, cx, cy)
    local steered = stand ~= nil and not inPlace and not (stand.x == cx and stand.y == cy)
        and standCanHit(battle.current, ab, item, stand.x, stand.y, cx, cy)
    -- A steered route names the APPROACH LANE, not a demand to walk its whole length. The trail extends
    -- itself over every reachable tile the cursor crosses, so sweeping the mouse out to a distant foe
    -- drags the route to the far edge of the move band -- the tile CLOSEST to the target. For a reach
    -- weapon that is the worst tile on the lane: the shot came into range several steps back, and the
    -- extra steps only give away the distance a bow exists to keep. So the route is cut to its EARLIEST
    -- tile that can already land the blow -- the same lane the player drew, stopped at the first tile
    -- that can fire, which is the farthest one on it from the target. Melee is untouched: with reach 1
    -- the first firing tile on a lane is also its last. A prefix the walk gate refuses (it would stop on
    -- an ally, or it prices differently) keeps the full route rather than inventing an illegal one.
    if steered then
        for i = 2, #mp.cells do
            local c = mp.cells[i]
            if not (c.x == cx and c.y == cy)
                and standCanHit(battle.current, ab, item, c.x, c.y, cx, cy) then
                if i < #mp.cells then
                    local cut = {}
                    for j = 1, i do cut[j] = mp.cells[j] end
                    local trimmed = Combat.planMoveVia(battle.combat, battle.current, cut)
                    if trimmed then
                        -- Priced exactly as updateMovePath prices the drawn route: ground that STOPS a
                        -- walk (a quicksand mire) is charged for what is actually crossed.
                        local stop, walked = Combat.walkStop(battle.combat, battle.current, trimmed.path)
                        stand = trimmed.path[#trimmed.path]
                        mp = { cells = trimmed.path,
                               cost = stop < #trimmed.path and walked or trimmed.cost }
                    end
                end
                break
            end
        end
    end
    local fromX = steered and stand.x or (entry and entry.fromX)
    local fromY = steered and stand.y or (entry and entry.fromY)
    -- A tile aim that would connect with nothing is a step, as long as there is still a step to take
    -- (see the note above). A reachable tile the cast can't even be aimed at (inside a thrown ability's
    -- minimum range) walks too, rather than staying the dead click it used to be. The question is put
    -- from the firing tile resolved above, so a line/arc that only "connects" when drawn from the tile
    -- the unit is about to LEAVE reads as the empty swing it really is -- and steps.
    -- Not while a blink is armed: `battle.reachable` is then a teleport diamond, and the armed move
    -- branch walks. Toggling blink disarms anyway (toggleBlink), so this only skips the case where the
    -- player re-armed on top of it -- which keeps aiming, exactly as before.
    if ab.target == "tile" and not ab.groundAim and not battle.blinking
        and battle.reachable and battle.reachable[cx .. "," .. cy]
        and not Combat.hasMoved(battle.combat)
        and not (entry and castConnectsAt(item, cx, cy, fromX, fromY)) then
        local path = movePathTo(cx, cy)
        return { kind = "move", x = cx, y = cy, cells = path and path.cells or nil }
    end
    if not entry then return nil end
    if steered then
        return { kind = "act", cells = mp.cells,
                 entry = { x = cx, y = cy, fromX = stand.x, fromY = stand.y, moveCost = mp.cost } }
    end
    return { kind = "act", entry = entry }
end

-- Advance a two-stage throw to its LANDING phase: remember the grabbed tile, light the ray of tiles it
-- can be sent to, and (for a cursor player) snap the aim onto the nearest one. No cast yet -- the next
-- confirm, on a lit landing, resolves the throw. snapToNearestTarget/targetCells key off throwStage.
local function enterThrowDest(gx, gy)
    local ab = battle.armedItem and battle.armedItem.activeAbility
    battle.throwStage = "dest"
    battle.throwFrom = { x = gx, y = gy }
    battle.throwCells, battle.throwSet = throwLandingCells(gx, gy, (ab and ab.throwRange) or 3)
    snapToNearestTarget()
    Sound.play("battle.select")
end

-- What confirming on cell (cx, cy) would DO right now, as a descriptor the action-preview tooltip
-- (ui/action_preview.lua) renders beside the character/tile tooltip. Mirrors confirm()'s branching
-- so the preview always names the very action a click would take:
--   { kind = "attack",     item, target, entry }  -- default-weapon strike on a foe
--   { kind = "strikeTrap", item, trap, trapDamage, trapLethal }  -- destroy a revealed enemy trap
--   { kind = "move",       moveCost, steps }       -- step to a reachable tile
--   { kind = "ability",    item, target, support, entry }  -- armed unit/self cast (heal/strike/...)
--   { kind = "place",      item }                  -- armed tile cast (summon a trap / a creature)
-- Returns nil when a click on this cell would do nothing (not the player's turn, out of reach, an
-- invalid target), so the tooltip only appears on an actionable hover. `entry` is the dry-run effect
-- on the target unit (Combat.previewAbility); `support` tints the panel green for a friendly cast.
-- Every item-driven action also carries `spend` (Combat.abilitySpend): what the cast would take out
-- of the actor's own pools -- the resource cost AND a summon's reservation -- which the preview
-- panel lists and the actor's turn-strip bars project as a red loss slice.
-- Where a previewed cast would leave the ACTOR, as { x, y, fromX, fromY }, or nil when it leaves it
-- where it stands. `sx, sy` is the tile the cast fires from -- which a click-to-use approach may have
-- moved off the actor's own square, so the walk and the blink are two legs of one plan and the second
-- is measured from the end of the first. A landing equal to that tile is dropped: an ability that puts
-- you back where you already were (Shadow Strike, when the turn started here) moves nobody, and a
-- marker on the tile the actor is already ringed on says nothing.
local function castLanding(preview, sx, sy)
    if not (preview and preview.userRestsX) then return nil end
    local x, y = preview.userRestsX, preview.userRestsY
    if x == sx and y == sy then return nil end
    return { x = x, y = y, fromX = sx, fromY = sy }
end

local function actionPreviewFor(cx, cy)
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return nil end
    local unit = Combat.unitAt(battle.combat, cx, cy)

    if battle.mode == "armed" and battle.armedItem then
        local item = battle.armedItem
        if not item.activeAbility then return nil end
        -- Two-stage throw: the landing phase previews the throw itself (aimed at the grabbed tile, sent
        -- to the lit landing under the cursor, so the panel shows any slam damage); the grab phase names
        -- the pick-up on an adjacent grabbable, or a reposition on an empty reachable tile.
        if battle.throwStage == "dest" then
            if not (battle.throwSet and battle.throwSet[cx .. "," .. cy]) then return nil end
            local from = battle.throwFrom
            local preview = Combat.previewAbility(battle.combat, current, item, from.x, from.y, { x = cx, y = cy })
            return {
                kind = "ability", item = item, actor = current,
                target = Combat.unitAt(battle.combat, cx, cy), support = false,
                spend = Combat.abilitySpend(current, item.activeAbility),
                entries = preview and preview.entries or nil,
                order = preview and preview.order or nil,
            }
        end
        if battle.throwStage == "grab" then
            if throwGrabbableAt(cx, cy) and battle.rangeReach and battle.rangeReach[cx .. "," .. cy] then
                return { kind = "place", item = item, actor = current,
                         target = Combat.unitAt(battle.combat, cx, cy), support = false,
                         spend = Combat.abilitySpend(current, item.activeAbility) }
            end
            if battle.reachable and battle.reachable[cx .. "," .. cy] then
                local mp = movePathTo(cx, cy)
                local node = battle.reachable[cx .. "," .. cy]
                local cost = mp and mp.cost or node.cost
                local steps = mp and (#mp.cells - 1) or node.steps
                return { kind = "move", actor = current, steps = steps,
                         moveCost = Combat.moveInitiative(current, cost) }
            end
            return nil
        end
        local plan = armedActionAt(cx, cy)
        if not plan then return nil end
        -- Aiming empty air is a reposition (walk onto the tile) -- with a single-target ability, or
        -- with a tile-aimed one whose swing would connect with nothing (see armedActionAt). A steered
        -- detour ending here is priced by its own (longer) route, not the shortest one's.
        if plan.kind == "move" then
            local mp = movePathTo(cx, cy)
            local node = battle.reachable[cx .. "," .. cy]
            local cost = mp and mp.cost or node.cost
            local steps = mp and (#mp.cells - 1) or node.steps
            return { kind = "move", actor = current, steps = steps,
                     moveCost = Combat.moveInitiative(current, cost) }
        end
        -- Breaking a board object: same preview shape (and "break" cursor) the move-mode default
        -- action uses on a trap/wall/prop, but priced from the armed item's own attack stat.
        if plan.strikeKind then
            local obj = plan.object
            local dmg = Combat.computeTrapDamage(current, item)
            return { kind = "strikeTrap", item = item, actor = current, trap = obj, support = false,
                     trapDamage = dmg, trapLethal = dmg >= (obj.health or 0),
                     spend = Combat.abilitySpend(current, item.activeAbility) }
        end
        -- Priced from the tile the cast FIRES from, not the one the actor stands on now: a click-to-use
        -- folds the approach into the strike, and a directional footprint (a spear's line, an axe's arc)
        -- sweeps whatever the stand tile faces (see asIfStandingAt). Weighed from here, the panel names
        -- the bodies the swing will really catch -- and agrees with both the red footprint the board
        -- paints and the plan confirm() commits.
        local preview = asIfStandingAt(current, plan.entry.fromX, plan.entry.fromY, function()
            return Combat.previewAbility(battle.combat, current, item, cx, cy)
        end)
        local entry = preview and unit and preview.entries[unit] or nil
        local lands = castLanding(preview, plan.entry.fromX, plan.entry.fromY)
        return {
            kind = (item.activeAbility.target == "tile") and "place" or "ability",
            item = item, actor = current, target = unit, support = battle.armedSupport,
            spend = Combat.abilitySpend(current, item.activeAbility),
            entry = entry,
            lands = lands, -- where the cast puts the actor, for the board's landing mark
            -- Weighed from the tile the cast fires from -- the plan's stand tile, which a steered
            -- approach may have moved off the actor's own square, and which a blink moves off again
            -- before the blow lands (Shadow Step cuts from the square it slipped to, and is answered
            -- from there -- so a preview weighed from four tiles out would promise safety it hasn't).
            counters = Combat.previewCounters(battle.combat, current, item, unit,
                { entry = entry,
                  fromX = lands and lands.x or plan.entry.fromX,
                  fromY = lands and lands.y or plan.entry.fromY }),
            entries = preview and preview.entries or nil, -- every affected unit (AoE), for banner preview
            order = preview and preview.order or nil, -- ordered affected units, for the AoE summary
        }
    end

    if battle.mode == "move" then
        local action = battle.defaultAction
        local support = battle.defaultSupport
        local inReach = battle.attackReach and battle.attackReach[cx .. "," .. cy]
        -- A valid default-action target on this cell, in reach -> click-to-use (moving into reach
        -- first): a foe to strike with an offensive default, an ally to support with a friendly one.
        if unit and unit.alive and action and action.activeAbility then
            local validTarget = support and unit.side == current.side
                or not support and unit.side ~= current.side
            if validTarget and inReach then
                -- Weighed from the stand tile the strike fires from, exactly as the armed branch above
                -- does: the walk is folded into the click, and a directional footprint sweeps whatever
                -- that tile faces (see asIfStandingAt).
                local preview = asIfStandingAt(current, inReach.fromX, inReach.fromY, function()
                    return Combat.previewAbility(battle.combat, current, action, cx, cy)
                end)
                local entry = preview and preview.entries[unit] or nil
                local lands = castLanding(preview, inReach.fromX, inReach.fromY)
                return { kind = support and "ability" or "attack", item = action, actor = current,
                         target = unit, support = support,
                         entry = entry,
                         lands = lands, -- where the action puts the actor, for the board's landing mark
                         -- Click-to-use walks into reach first, so the answer is weighed from the
                         -- stand tile the strike fires from, not the tile the actor stands on now --
                         -- and from the landing tile when the strike itself blinks the actor there.
                         counters = Combat.previewCounters(battle.combat, current, action, unit,
                             { entry = entry,
                               fromX = lands and lands.x or inReach.fromX,
                               fromY = lands and lands.y or inReach.fromY }),
                         spend = Combat.abilitySpend(current, action.activeAbility),
                         entries = preview and preview.entries or nil,
                         order = preview and preview.order or nil }
            end
            return nil -- an occupied cell that isn't a valid default target: nothing to preview
        end
        -- A revealed enemy trap in reach -> click-to-destroy with an offensive default (a support
        -- default doesn't strike). A wall or a prop in reach breaks the same way -- all three are
        -- "something with HP that isn't a body", so they share one preview shape and one cursor.
        local trap = not support
            and (revealedEnemyTrapAt(current, cx, cy) or wallAt(cx, cy) or propAt(cx, cy))
        if trap and inReach then
            local dmg = action and Combat.computeTrapDamage(current, action) or 0
            return { kind = "strikeTrap", item = action, actor = current, trap = trap,
                     support = false, trapDamage = dmg, trapLethal = dmg >= (trap.health or 0),
                     spend = action and Combat.abilitySpend(current, action.activeAbility) or nil }
        end
        -- An empty reachable tile -> move (or blink) there.
        local node = battle.reachable and battle.reachable[cx .. "," .. cy]
        if node then
            if battle.blinking then
                -- A blink owes no move initiative; its price is the mana it spends per jump.
                local mb = Combat.blinkReady(current)
                return { kind = "move", actor = current, steps = node.steps, moveCost = 0, blink = true,
                         spend = mb and mb.cost and { { kind = "cost", stat = mb.cost.stat, amount = mb.cost.amount } } or nil }
            end
            -- The initiative the walk charges, not the raw path cost: a hasted unit pays half. A
            -- steered detour ending here costs its own (longer) route, not the shortest one's.
            local mp = movePathTo(cx, cy)
            local cost = mp and mp.cost or node.cost
            local steps = mp and (#mp.cells - 1) or node.steps
            return { kind = "move", actor = current, steps = steps,
                     moveCost = Combat.moveInitiative(current, cost) }
        end
    end

    return nil
end

-- Resolve a confirm during a two-stage throw (Heave). In the GRAB phase it picks up the adjacent
-- target -- walking into reach first when needed, or repositioning on an empty tile -- and hands off to
-- the landing phase (enterThrowDest); in the DESTINATION phase it flings the grabbed thing at the aimed
-- landing. Split out of confirm() so a grab can never fall through to a one-click cast.
local function confirmThrow(current, item, cx, cy)
    if battle.throwStage == "dest" then
        -- Only a lit landing resolves; a tile off the ray is a misclick that does nothing.
        if not (battle.throwSet and battle.throwSet[cx .. "," .. cy]) then return end
        local from = battle.throwFrom
        local victim = Combat.unitAt(battle.combat, from.x, from.y) -- read before the throw clears it
        -- The actor is already beside the grabbed tile (the grab phase saw to that), so the throw fires
        -- in place -- no approach to hold cues behind, exactly like a plain in-place cast.
        local ok, why = Combat.useItem(battle.combat, current, item, from.x, from.y, nil, { x = cx, y = cy })
        if not ok then
            notify(string.format("%s: %s", item.name or "That item", tostring(why or "cannot be used here")))
            return
        end
        netFinishTurn({ kind = "use", cell = slotOf(current, item),
                        tx = from.x, ty = from.y, dx = cx, dy = cy })
        observeAction("attack", current, from.x, from.y, victim and victim.char.id, item.id)
        advanceTurn()
        return
    end
    -- GRAB phase. An empty reachable tile is a reposition (walk, stay in the grab phase); a tile holding
    -- a grabbable is the pick-up (walking into reach first when it isn't already adjacent).
    if not throwGrabbableAt(cx, cy) then
        if battle.reachable and battle.reachable[cx .. "," .. cy] and not Combat.hasMoved(battle.combat) then
            local mp = movePathTo(cx, cy)
            netFinishTurn({ kind = "move", x = cx, y = cy, path = mp and mp.cells })
            startWalk(current, cx, cy, function()
                if not current.alive then advanceTurn() return end
                observeAction("move", current, current.x, current.y)
                computeThreat(current) computeDanger() computeRange(current, item)
            end, mp and mp.cells)
        end
        return
    end
    local plan = armedActionAt(cx, cy)
    if not (plan and plan.kind == "act" and plan.entry) then return end
    local entry = plan.entry
    if entry.fromX ~= current.x or entry.fromY ~= current.y then
        -- Walk into reach first (one move per turn), then open the landing phase from beside the target.
        if Combat.hasMoved(battle.combat) then
            notify("Out of reach from here -- already moved this turn")
            return
        end
        netFinishTurn({ kind = "move", x = entry.fromX, y = entry.fromY, path = plan.cells })
        startWalk(current, entry.fromX, entry.fromY, function()
            if not current.alive then advanceTurn() return end
            observeAction("move", current, current.x, current.y)
            computeThreat(current) computeDanger() computeRange(current, item)
            enterThrowDest(cx, cy)
        end, plan.cells)
        return
    end
    enterThrowDest(cx, cy)
end

-- Commit an armed strike (an offensive cast on a target/tile) at wind-up depth `wu` (nil for every
-- non-chargeable ability). Walks into the firing tile first when the blow can't land from where the
-- unit stands (plan.entry.fromX/fromY, the steered route's endpoint or attackReach's cheapest stand
-- tile), then resolves. Lifted out of confirm() so a CHARGEABLE swing can defer here until the wind-up
-- chooser has picked its depth -- everything below is identical whether the depth came from the modal
-- or was nil for a fixed-tell weapon.
local function commitArmedStrike(current, item, cx, cy, plan, wu, sp)
    local entry = plan.entry
    local victim = Combat.unitAt(battle.combat, cx, cy) -- read before the cast clears the cell
    -- Why the model refused a cast the board had just offered. Every branch below routes its refusal
    -- through here: a click that lights a target, draws a route and prices the turn in the preview, and
    -- then does NOTHING when pressed, is unreadable -- the player has no way to tell a bug from a rule.
    local function refuse(why)
        notify(string.format("%s: %s", item.name or "That item", tostring(why or "cannot be used here")))
    end
    local function cast()
        local cell = slotOf(current, item)
        local ok, why = Combat.useItem(battle.combat, current, item, cx, cy, wu, nil, sp)
        if not ok then refuse(why) return end
        netFinishTurn({ kind = "use", cell = cell, tx = cx, ty = cy, windup = wu, spend = sp })
        -- The item rides along so a lesson can ask for a strike with a NAMED ability rather than any
        -- blow at all -- the village lesson's Clear Out, which is aimed at the caster's own tile and so
        -- cannot be pinned by its victim (see data/tutorials/village.lua).
        observeAction("attack", current, cx, cy, victim and victim.char.id, item.id)
        advanceTurn()
    end
    if entry.fromX ~= current.x or entry.fromY ~= current.y then
        -- Can't move twice in a turn. The approach is part of the action here, so a spent move kills the
        -- whole click -- say so, rather than letting the press vanish.
        if Combat.hasMoved(battle.combat) then
            notify("Out of reach from here -- already moved this turn")
            return
        end
        if not startWalk(current, entry.fromX, entry.fromY, nil, plan.cells) then
            notify("No route to attack from")
            return
        end
        -- The approach is already spent: startWalk walked it in the model, so the unit is standing on
        -- the entry tile and the blow lands NOW, before a frame of the walk is drawn. Its cues stay in
        -- the queue while the route replays -- advanceTurn drains them when the feet stop, so the impact
        -- still reads after the approach rather than during it. Nothing about the exchange is decided by
        -- how long the animation took. Snapshotted after the approach is spent but before the cast
        -- resolves, so only the ground the CAST lays is held back -- anything the walk itself sprang (a
        -- trap's zone) is already in `pre` and stays visible as the route replays.
        local pre = boardObjects()
        local landed, why
        if current.alive then
            landed, why = Combat.useItem(battle.combat, current, item, cx, cy, wu, nil, sp)
        end
        -- The approach is already walked and paid for; only the blow was refused. Name the reason so the
        -- turn doesn't just look like it evaporated.
        if not landed and why then refuse(why) end
        local blow = holdLanding(pre)
        -- Announced now, not when the animation finishes: the model already resolved the whole turn, and
        -- the peer should be told at once rather than after our playback -- their window has its own walk.
        netFinishTurn({ kind = "use", cell = slotOf(current, item),
                        tx = cx, ty = cy, path = plan.cells,
                        x = entry.fromX, y = entry.fromY, windup = wu, spend = sp })
        battle.walk.onDone = function()
            if landed then
                observeAction("attack", current, cx, cy, victim and victim.char.id, item.id)
            end
            advanceTurn(blow)
        end
    else
        cast()
    end
end

-- Raise the wind-up chooser (ui/panels/windup_chooser.lua): a modal that opens the moment a CHARGEABLE
-- signature (The First Motion) is confirmed on a target, so the depth is a decision made AT the swing
-- rather than a background scroll knob the player had to know about in advance. The blow does not
-- commit until the panel does -- Confirm hands the chosen depth to commitArmedStrike; Cancel closes and
-- leaves the aim armed. The plan (firing tile, route) is captured now so the swing lands exactly where
-- it was aimed, however long the panel stays up.
local function openWindupChooser(current, item, cx, cy, plan)
    local lo, hi = Item.windupRange(item.activeAbility)
    -- Anchor the little slider over the AIMED tile (not the actor's own square): the swing is being
    -- sized against the target, so the control sits where the eye already is. cellToPixel gives the
    -- tile's top-left; the widget centres itself on the tile and clears it (above, or below if it would
    -- clip the screen top).
    local px, py = battle.map:cellToPixel(cx, cy)
    local sz = battle.map.size
    battle.windup = lo -- the slider opens at the floor; onChange slides it (and the strip) from there
    battle.windupChooser = WindupChooser.new({
        lo = lo, hi = hi, depth = lo,
        anchorX = px + sz / 2, anchorY = py + sz / 2, tileSize = sz,
        -- Price each depth off the live board (Combat.previewAbility takes the wind-up now), so the
        -- damage read-out climbs as the ladder fills. The aimed occupant is the headline; the total and
        -- count cover a swing that sweeps more than one body (First Motion's line/cone).
        damageAt = function(depth)
            local preview = Combat.previewAbility(battle.combat, current, item, cx, cy, nil, depth)
            if not preview then return nil end
            local occ = Combat.unitAt(battle.combat, cx, cy)
            local primary = occ and preview.entries[occ] and preview.entries[occ].damage or nil
            local total, count = 0, 0
            for _, e in ipairs(preview.order or {}) do
                total = total + (e.damage or 0)
                if (e.damage or 0) > 0 then count = count + 1 end
            end
            return { primary = primary, total = total, count = count }
        end,
        -- Every slide writes the armed depth, so refreshView slides the channel's resolve slot along the
        -- turn-order strip and repaints the board footprint at that depth -- the preview the player reads.
        onChange = function(depth)
            battle.windup = depth
        end,
        onConfirm = function(depth)
            battle.windupChooser = nil
            battle.windup = depth
            commitArmedStrike(current, item, cx, cy, plan, depth)
        end,
        onCancel = function()
            battle.windupChooser = nil
            battle.windup = lo -- drop the preview back to the floor; the aim stays armed
        end,
    })
end

-- Raise the SPEND chooser (ui/panels/spend_chooser.lua): the money twin of openWindupChooser. A
-- PURCHASABLE ability (The Gilded Wound) does not swing on confirm -- it opens a small slider over the
-- aimed tile so the caster can dial how much GOLD to pour into the blow (ten per point of damage), then
-- commits at that amount. The plan (firing tile, route) is captured now so the swing lands where it was
-- aimed however long the panel stays up. The high end of the slider is the smaller of the ability's own
-- ceiling and what the caster's purse can actually afford, so it never offers a spend that cannot be paid.
local function openSpendChooser(current, item, cx, cy, plan)
    local ab = item.activeAbility
    local rate, cap = Item.purchaseRate(ab)
    local available = Combat.purseAvailable(battle.combat, current)
    local hi = math.min(cap, math.floor(available / rate))
    if hi < 1 then
        -- The one place a money ability's affordability is enforced (Combat.itemBlockReason does not read
        -- the purse -- it has no combat handle): too poor to buy even a single point, so say so plainly
        -- and leave the aim armed rather than opening a slider with nothing on it.
        notify(string.format("%s: not enough gold (need %dg)", item.name or "That item", rate))
        return
    end
    local px, py = battle.map:cellToPixel(cx, cy)
    local sz = battle.map.size
    battle.spendChooser = SpendChooser.new({
        lo = 1, hi = hi, value = 1, rate = rate,
        anchorX = px + sz / 2, anchorY = py + sz / 2, tileSize = sz,
        onConfirm = function(value)
            battle.spendChooser = nil
            commitArmedStrike(current, item, cx, cy, plan, nil, value * rate)
        end,
        onCancel = function()
            battle.spendChooser = nil
        end,
    })
end

-- Confirm on the cursor cell: move there (does NOT end the turn -- the unit can still act or
-- wait), use the default action on it (a strike on a foe, a heal on an ally -- moving into reach
-- first), strike a trap/wall with an offensive default, or use the armed item on it (ends the turn).
local function confirm()
    -- SEND SOMEONE IN: a click (or confirm) on lit rally ground. Claimed above everything below --
    -- including the whose-turn guard -- because a reinforcement is not a turn action. Nobody spends
    -- anything for it, so it is legal on either side's turn, and the tile it lands on has just been
    -- named by the press itself, which is why the chooser it opens has no second pick to make.
    --
    -- One seam serves all three inputs: the mouse arrives here through battle.map:mousepressed (which
    -- sets the cursor from the click), and the keyboard and pad through their own confirm. refreshView
    -- already withheld every tile the acting unit could walk to, so this cannot eat a move.
    local rx, ry = battle.map.cursor.x, battle.map.cursor.y
    if battle.reinforceHere and rx and battle.reinforceHere[rx .. "," .. ry]
        and not battle.over and not busy() then
        openBenchChooser("reinforce", false, "Send someone in  --  free", { x = rx, y = ry })
        return
    end
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    local cx, cy = battle.map.cursor.x, battle.map.cursor.y
    -- A commit sound for CONFIRMING an action -- but only when the aimed cell actually resolves to one
    -- (actionPreviewFor mirrors the branching below exactly), so a click on dead air stays silent.
    if actionPreviewFor(cx, cy) then Sound.play("battle.confirm") end
    if battle.mode == "move" then
        local action, support = battle.defaultAction, battle.defaultSupport
        local target = Combat.unitAt(battle.combat, cx, cy)
        local validTarget = target and target.alive and action and action.activeAbility
            and (support and target.side == current.side or not support and target.side ~= current.side)
        if validTarget then
            tryDefaultAction(current, cx, cy)
        elseif not support and revealedEnemyTrapAt(current, cx, cy) then
            tryDamageTrap(current, cx, cy)
        elseif not support and wallAt(cx, cy) and battle.attackReach and battle.attackReach[cx .. "," .. cy] then
            tryDamageWall(current, cx, cy)
        elseif not support and propAt(cx, cy) and battle.attackReach and battle.attackReach[cx .. "," .. cy] then
            tryDamageProp(current, cx, cy)
        elseif battle.reachable[cx .. "," .. cy] then
            if battle.blinking then
                -- A blink is instant (no walk animation): jump, spend mana, then recompute the threat
                -- band from where it landed. Blinking onto a lethal trap/hazard ends the turn.
                if Combat.blink(battle.combat, current, cx, cy) then
                    battle.reachable, battle.moveCells = {}, {}
                    battle.threatCells, battle.attackReach = {}, {}
                    -- The jump spends the turn's one move, so the ability band built over it is stale
                    -- for the same reason startWalk's is -- see the note there.
                    battle.rangeCells, battle.rangeReach, battle.rangeFor = {}, {}, nil
                    netFinishTurn({ kind = "blink", x = cx, y = cy })
                    if current.alive then computeThreat(current) computeDanger() else advanceTurn() end
                end
            else
                -- Walk there (startWalk already cleared the move band -- only one move per turn),
                -- following the player-steered route when one ends on this tile. Once the unit
                -- arrives, recompute the threat band from the tile it actually stopped on and stay in
                -- this turn so the player can still arm an item or wait. A unit that walked into a
                -- lethal trap has no turn left to take.
                local mp = movePathTo(cx, cy)
                netFinishTurn({ kind = "move", x = cx, y = cy, path = mp and mp.cells })
                startWalk(current, cx, cy, function()
                    if not current.alive then advanceTurn() return end
                    -- A bare move does not end the turn, so it never reaches advanceTurn -- the
                    -- tutorial hears about it here instead. Observed BEFORE the bands are rebuilt so
                    -- they come back narrowed for the step this move just unlocked. Note the move
                    -- band is deliberately NOT recomputed: startWalk cleared it, and a unit gets one
                    -- move per turn.
                    observeAction("move", current, current.x, current.y)
                    computeThreat(current)
                    computeDanger()
                end, mp and mp.cells)
            end
        end
    elseif battle.mode == "armed" and battle.armedItem then
        local item = battle.armedItem
        -- A two-stage throw runs its own grab/landing flow; intercept before armedActionAt so a grab is
        -- never resolved as a one-click cast.
        if battle.throwStage then confirmThrow(current, item, cx, cy) return end
        local plan = armedActionAt(cx, cy)
        if not plan then return end
        -- Aiming an empty reachable tile is a reposition, not an attack on empty air: walk onto it and
        -- stay armed, refreshing the range from the tile it now stands on (one move per turn).
        if plan.kind == "move" then
            if Combat.hasMoved(battle.combat) then notify("Already moved this turn") return end
            netFinishTurn({ kind = "move", x = plan.x, y = plan.y, path = plan.cells })
            startWalk(current, plan.x, plan.y, function()
                if not current.alive then advanceTurn() return end
                -- Same bare move as the move-mode branch, and it reaches here far more often than
                -- that one does: armDefaultAction arms the default weapon at the start of every turn,
                -- so a plain "walk onto that tile" is normally a reposition in armed mode. The
                -- tutorial has to hear about it from both paths or its move lesson never completes.
                observeAction("move", current, current.x, current.y)
                computeThreat(current) computeDanger() computeRange(current, item)
            end, plan.cells)
            return
        end
        -- Breaking a board object (a barrel, a wall, a revealed enemy trap) the armed weapon reaches:
        -- the armed-mode counterpart of the move-mode trap/wall/prop branch below, walking into reach
        -- first when the firing tile isn't the one the unit stands on.
        if plan.strikeKind then
            strikeArmedObject(current, item, plan.strikeKind, cx, cy, plan.entry)
            return
        end
        -- The strike itself. A CHARGEABLE signature (The First Motion) does not swing on this confirm:
        -- it raises the wind-up chooser, which picks the depth and then hands back here to commit. Every
        -- other ability commits at once (wu = nil). The walk-and-strike, the network command and the
        -- refusal banner all live in commitArmedStrike, shared by both paths.
        if Item.isChargeable(item.activeAbility) then
            openWindupChooser(current, item, cx, cy, plan)
        elseif Item.isPurchasable(item.activeAbility) then
            -- A money ability (The Gilded Wound) raises the SPEND chooser on confirm, the same way a
            -- chargeable one raises the wind-up chooser: the amount of gold is a decision made AT the
            -- swing. It hands the chosen gold back to commitArmedStrike; Cancel closes and stays armed.
            openSpendChooser(current, item, cx, cy, plan)
        else
            commitArmedStrike(current, item, cx, cy, plan, nil)
        end
    end
end

-- End the current party unit's turn without acting. The default is a delay (Combat.wait), but an
-- item may swap this into Focus (restore mana) or Defend (a defensive stance) -- see
-- Combat.waitBehavior. Available whether or not the unit moved.
local function waitTurn()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if tutorialRefuses("wait") then return end
    local kind = Combat.waitBehavior(current).kind
    local action = (kind == "focus" and Combat.focus)
        or (kind == "defend" and Combat.defend)
        or (kind == "overwatch" and Combat.overwatch)
        or (kind == "gather" and Combat.gather)
        or Combat.wait
    if action(battle.combat, current) then
        Sound.play("battle.wait") -- a soft hold/pass, whichever wait behaviour it was (wait/focus/defend/overwatch/gather)
        observeAction("wait", current, current.x, current.y)
        netFinishTurn({ kind = "wait" })
        advanceTurn()
    end
end

-- ---------------------------------------------------------------------------
-- Rotation: trading the field for the bench, mid-fight
-- ---------------------------------------------------------------------------
--
-- Two ways a benched member takes the field, both routed through the same chooser (see
-- ui/panels/bench_chooser.lua) because the question -- which of these people -- is the same one:
--
--   ROTATE     the acting unit spends its TURN to trade places, and must be standing in the deploy zone
--              (its own lines). Called FALL BACK everywhere the player can read it -- the button under
--              the item grid, which appears only once a body of theirs is standing on rally ground.
--   REINFORCE  a slot has opened, so filling it is FREE. The drawer button, and -- when nothing of the
--              player's is left standing -- a prompt raised automatically, because a company with a body
--              still on the bench has not lost and the turn loop has nobody to hand the turn to.
--
-- Neither is spoken over the network: a duel would need a Command kind for it (models/command.lua) or the
-- two peers desync. Rotation is a campaign feature and the deployment phase it belongs to is skipped in
-- every duel and draft, so there is nothing to speak.

closeBenchChooser = function()
    battle.benchChooser = nil
end

-- Rotate: the acting unit falls back and `index` comes on where it stood. Ends the turn.
local function rotateTurn(index)
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if tutorialRefuses("rotate") then return end
    local ok, why = Combat.rotate(battle.combat, current, index)
    if not ok then
        if why then notify(why) end
        return
    end
    Sound.play("battle.wait") -- a fall-back and a hand-off; the same soft pass a wait makes
    observeAction("wait", current, current.x, current.y)
    advanceTurn()
end

-- Reinforce: `index` walks on at (x, y), free. Not a turn -- nobody acted -- so the turn in progress (if
-- any) simply carries on, and a battle that had nobody to act is handed back to the turn loop.
local function reinforceAt(index, x, y)
    local unit, why = Combat.reinforce(battle.combat, index, x, y)
    if not unit then
        if why then notify(why) end
        return false
    end
    Sound.play("battle.start")
    battle.reinforcePick = nil
    -- The line just grew: reconcile the baseline here rather than waiting for the next hand-off, so the
    -- body that walked on can never read as a drop, and the next real one still does.
    battle.slotOffer = false
    battle.lastFieldCount = Combat.fieldCount(battle.combat, battle.combat.playerSide or "party")
    -- With nothing of the player's standing, the fight was waiting on this body: hand the turn loop
    -- back its actor. Otherwise the current turn is untouched and only the view needs to catch up.
    if not battle.current or not battle.current.alive then advanceTurn() else refreshView() end
    return true
end

-- Raise the chooser. `mode` is "rotate" (costs the acting unit's turn) or "reinforce" (free, fills an
-- open slot). A reinforce pick is followed by a TILE pick, since there is no vacated tile to inherit.
--
-- `mandatory` marks the LAST-STAND prompt: nothing of the player's is standing, so the fight is waiting
-- on this one decision and there is no turn to hand back. Backing out of it would leave the turn loop
-- with no actor and no way to reach one, so it simply cannot be backed out of -- Esc, B, the X and a
-- click-off all re-raise it. Every other chooser cancels normally.
--
-- `title` overrides the default line. Only offerOpenSlot passes one: a chooser the player OPENED says
-- what the move costs, but one that arrived on its own has to say what just happened first, or it reads
-- as an interruption rather than an answer to the body that dropped.
--
-- `at` is a tile the caller has ALREADY chosen -- the lit rally tile a click landed on. It collapses the
-- flow to one decision: the ground was named by the press that opened the card, so the pick lands the
-- body there and the tile step never happens. It also anchors the card on that tile, which is the more
-- honest place for it than the acting unit -- after a death the "acting unit" is usually the enemy that
-- did the killing, halfway across the board from the ground the body is about to walk in on.
-- Returns true if it actually opened one. The caller has to know: offerLastStand below is holding the
-- turn loop on the promise that this chooser is up, and a silent refusal there strands the fight.
openBenchChooser = function(mode, mandatory, title, at)
    if battle.benchChooser or battle.over or busy() then return false end
    local combat = battle.combat
    if #(combat.bench or {}) == 0 then notify("No one is on the bench.") return false end

    local anchorUnit = battle.current
    if mode == "rotate" then
        local ok, why = Combat.canRotate(combat, anchorUnit)
        if not ok then notify(why or "You cannot fall back right now.") return false end
    else
        local ok, why = Combat.canReinforce(combat)
        if not ok then notify(why or "There is no room to bring anyone in.") return false end
    end

    local m = battle.map
    -- With nothing of the player's left standing there is no body to anchor to; the card goes to the
    -- middle of the board, which is where the eye already is.
    local ax, ay = Scale.WIDTH / 2, Scale.HEIGHT / 2
    if at then
        ax = m.originX + (at.x - 0.5) * m.size
        ay = m.originY + (at.y - 0.5) * m.size
    elseif anchorUnit and anchorUnit.alive then
        ax = m.originX + (anchorUnit.x - 0.5) * m.size
        ay = m.originY + (anchorUnit.y - 0.5) * m.size
    end

    title = title or (mode == "rotate" and "Fall Back  --  costs this turn" or "Reinforce  --  free")
    if mandatory then title = "Your line is broken" end -- the log carries the rest; the card is narrow

    battle.benchChooser = BenchChooser.new({
        entries = combat.bench,
        title = title,
        mandatory = mandatory,
        anchorX = ax, anchorY = ay, tileSize = m.size,
        onCancel = function()
            closeBenchChooser()
            battle.reinforcePick = nil
            -- Declining is a real answer -- holding the reserve, or waiting for better ground, is often
            -- the play -- so the open slot stops asking. The drawer's Reinforce entry is the way back.
            battle.slotOffer = false
            refreshView()
        end,
        onPick = function(index)
            closeBenchChooser()
            if mode == "rotate" then
                rotateTurn(index)
            else
                battle.slotOffer = false -- answered; the next body to fall raises the next one
                -- The ground was named by the click that opened this card: land them and be done.
                if at then reinforceAt(index, at.x, at.y) return end
                -- Pick the ground next. One free tile means there is no decision to make, so it is made.
                local tiles = Combat.reinforceTiles(battle.combat)
                if #tiles == 1 then
                    reinforceAt(index, tiles[1].x, tiles[1].y)
                else
                    battle.reinforcePick = { index = index, tiles = tiles, mandatory = mandatory }
                    notify("Choose where they come in.")
                    refreshView()
                end
            end
        end,
    })
    return true
end

-- The turn loop found nobody of the player's to act. If there is a body on the bench, the fight is not
-- over -- it is waiting for the player to send someone in, and the chooser is raised for them rather than
-- the defeat panel. Returns true when it took over, so the caller holds off deciding the fight.
-- (Forward-declared above resolveAdvance, which consults it.)
--
-- The blow that broke the line is usually still animating when this runs, and openBenchChooser refuses
-- while the board is busy -- so a refusal RE-ARMS the advance rather than giving up. Without that the
-- fight would sit with no actor, no chooser and nothing scheduled to produce either: the exact hang
-- this function exists to prevent, reached by the exact path it exists for.
offerLastStand = function()
    if battle.over then return false end
    if battle.benchChooser or battle.reinforcePick then return true end -- already in the player's hands
    local combat = battle.combat
    local side = combat.playerSide or "party"
    if Combat.aliveCount(combat, side) > 0 then return false end
    if not Combat.canReinforce(combat, side) then return false end
    if not openBenchChooser("reinforce", true) then
        battle.pendingAdvance = { hold = 0 } -- try again next frame, once the board has settled
        return true
    end
    Combat.logEvent(combat, "system", "Your line is broken -- send someone in.")
    return true
end

-- A body of the player's has dropped and the company still has someone waiting: raise the chooser at the
-- moment the slot opens, instead of leaving the move greyed inside the hamburger drawer. That drawer
-- holds Forfeit, Log, Threats, Auto and Settings -- things about the SESSION -- and Reinforce was the
-- only actual play among them, three clicks deep in a menu nobody opens looking for one. The last-stand
-- prompt already proved the shape: the game knows how to put this decision in front of the player. It
-- was only doing it at zero alive, where reinforcing is a formality, and hiding it across the range
-- where it is a tactic.
--
-- Fires on the TRANSITION, never on the state. `Combat.canReinforce` is true from the opening bell of
-- any fight that deployed fewer than four, so asking IT would greet the player with a chooser before a
-- blow had landed. `battle.lastFieldCount` is the count this was last reconciled against; a DROP below
-- it is the event, and `battle.slotOffer` carries that event until the player answers it either way.
-- Both cleared on an answer, so a declined prompt stays declined until another body falls -- a modal
-- that re-raises itself every hand-off is worse than the drawer it replaced.
--
-- One prompt per hand-off, deliberately: an area attack that fells two opens two slots, and two cards
-- back to back is nagging. The first is offered, the drawer covers the second.
--
-- A field on `battle` rather than a file local for the reason at the top of this file: this chunk is
-- within a handful of names of Lua 5.1's ceiling of 200 locals, and going over it is a SYNTAX error at
-- load. Being a field also spares it a forward declaration -- resolveAdvance is defined long before
-- this line and reaches it through `battle`, which is resolved when it is called, not when it is read.
battle.offerOpenSlot = function()
    local combat = battle.combat
    local side = combat.playerSide or "party"
    local n = Combat.fieldCount(combat, side)
    if n < (battle.lastFieldCount or n) then battle.slotOffer = true end
    battle.lastFieldCount = n
    if not battle.slotOffer then return false end
    -- offerLastStand owns the nothing-standing case and its prompt cannot be declined. Never shadow it
    -- with a cancellable second copy of the same question.
    if Combat.aliveCount(combat, side) == 0 then return false end
    -- Auto-battle is a fight the player is WATCHING, at up to 3x. A card sitting there waiting on a
    -- click is the one thing that must not appear in one; models/autobattle.lua sends a body in on its
    -- own when the line actually breaks.
    if battle.autoAll then return false end
    -- The line refilled itself, the bench emptied, or there is nowhere to come in: the slot is no longer
    -- open, so the event is spent rather than held for a later hand-off that has nothing to do with it.
    if not Combat.canReinforce(combat, side) then battle.slotOffer = false return false end
    -- A refusal here is the board still settling (openBenchChooser declines while busy). Leave the offer
    -- standing and let the next hand-off raise it -- unlike offerLastStand there is no turn loop waiting
    -- on this, so it re-arms nothing and cannot hang.
    if not openBenchChooser("reinforce", false, "A slot is open  --  free") then return false end
    Combat.logEvent(combat, "system", "A slot is open -- send someone in, or hold the reserve.")
    return true
end

-- The keyboard Wait (Space / 0 / numpad-0 with nothing aimed) is a two-press action, mirroring how the
-- mouse already reads: the first press ARMS a preview -- the delay slot lit on the timeline, exactly the
-- ghost the mouse shows on Wait-button hover (battle.waitPreview feeds it, see the ghost block in
-- refreshView) -- and only the second press commits it. A stray tap therefore never burns the turn on a
-- wait the player did not mean; any other input clears the preview (top of battle.keypressed / beginTurn).
local function previewOrConfirmWait()
    local current = battle.current
    if battle.over or busy() or not current or not Combat.isPlayerControlled(current) then return end
    if tutorialRefuses("wait") then return end -- a lesson forbidding wait nudges rather than previewing
    if battle.waitPreview then
        battle.waitPreview = false
        waitTurn()
    else
        -- Arming the preview is the selection landing on Wait, so it takes the highlight the way any
        -- action does: drop a still-armed item and the keyboard-selected slot so NO action stays lit
        -- alongside it (the Wait button brightens off view.waitPreview, ui/combat_panel.lua). Exclusive,
        -- exactly as choosing one action clears the rest.
        cancelArm(true)
        battle.keySlot = nil
        battle.waitPreview = true
        Sound.play("ui.move") -- a soft tick acknowledging the armed preview, like crossing onto a button
    end
end

-- A tutorial's authored turn for this unit, translated into the same { move, item, tx, ty } plan
-- shape planEnemyAction returns -- so a hand-scripted mentor and an ordinary enemy travel the exact
-- same walk-then-act path below, with no second execution route to keep in step.
--
-- Returns nil (and the caller falls back to the AI) when the unit isn't scripted, when its queue has
-- run dry, or when the authored strike cell no longer holds a living foe. That last case is why the
-- weapon lookup lives here rather than in models/tutorial.lua: the lesson is pure data and knows
-- nothing of the board, so the check for whether its script still makes sense belongs on this side.
-- `peek` runs the plan WITHOUT spending the scripted turn: the intent preview (intentResolver) reads
-- what a unit is about to do to draw its target line, and must not consume the queue entry the unit's
-- real turn is owed. Only executeEnemyAction, which actually takes the turn, consumes. See
-- Tutorial.scriptFor's `peek`.
local function scriptedAction(unit, peek)
    if not battle.tutorial then return nil end
    local entry = Tutorial.scriptFor(battle.tutorial, unit.scriptKey or unit.char.id, peek)
    if not entry then return nil end
    local act = { move = entry.move }
    if entry.strike then
        local target = Combat.unitAt(battle.combat, entry.strike.x, entry.strike.y)
        if target and target.alive and target.side ~= unit.side then
            act.item = Combat.defaultWeapon(unit.char)
            act.tx, act.ty = entry.strike.x, entry.strike.y
        end
    elseif entry.guard then
        -- A standing order rather than an authored cell: cut down whatever is at your elbow, and
        -- never take a step. It is the mentor's whole part in the fight (data/tutorials/village.lua),
        -- and it is here rather than in the lesson data because WHICH foe is adjacent on any given
        -- turn is a fact about the board, which that file is not allowed to know.
        --
        -- The no-step half is what makes it safe: an AI ally would advance, and every tile she might
        -- advance to is one the choreography needs empty. Standing still, she can only ever take what
        -- walks into her -- which is exactly the body the lesson meant her to have.
        --
        -- Finding nobody is a HOLD, not a wasted entry: no item is set, so the caller passes the turn
        -- (below), and the post itself is a standing order the lesson does not spend on an empty
        -- board -- it is offered again next turn and retired by step, not by turn count. See
        -- Tutorial.scriptFor and `through` in data/tutorials/village.lua.
        for _, other in ipairs(battle.combat.units) do
            if other.alive and other.side ~= unit.side
                and math.abs(other.x - unit.x) + math.abs(other.y - unit.y) == 1 then
                act.item = Combat.defaultWeapon(unit.char)
                act.tx, act.ty = other.x, other.y
                break
            end
        end
    end
    return act
end

-- The resolver the intent preview plans through: the SAME line executeEnemyAction takes, so a
-- scripted mentor or boss is previewed doing what it will truly do, not what its bare AI would.
local function intentResolver(unit)
    return scriptedAction(unit, true) or Combat.planEnemyAction(battle.combat, unit)
end

-- Predict every hostile unit's turn -- who it strikes and the KIND of thing it does -- and cache it,
-- so the board's target lines (ui/battle_map's drawTargetLines) and the timeline's intent icons read
-- a decision made once rather than replanning per frame. Recomputed only on the seams computeDanger
-- is (turn hand-off, after any committed walk or action); AI.plan is the expensive call, and danger
-- already proves that cadence is enough. Assigned to the forward-declared local so computeDanger can
-- reach it.
--
-- The whole read is a preference: Settings "enemy_intent" off leaves the cache empty and every
-- surface that reads it goes quiet together, the way Tutorial.hidesDanger empties the danger sets.
function computeIntents()
    battle.enemyIntents = {}
    if not battle.combat or not Settings.get("enemy_intent") then return end
    for _, u in ipairs(battle.combat.units) do
        -- Whoever raises a threat is whoever gets a prediction: hostile to the party, and not an inert
        -- decoy (control "none" never advances, so it is coming for nobody). Mirrors Combat.threatMap's
        -- own filter, so a body that draws a danger tile also draws a target line and never one without
        -- the other.
        if u.alive and u.side ~= "party" and u.control ~= "none" then
            local ok, intent = pcall(Intent.of, battle.combat, u, intentResolver)
            -- A prediction that throws is no line, never a crashed battle: the preview is a courtesy on
            -- top of the fight, and must never be able to take it down.
            if ok and intent then battle.enemyIntents[u] = intent end
        end
    end
end

-- One cached intent -> a board target line { from, to, kind, retargeted }, or nil when it comes for
-- nobody (a wait/hold). The line leaves the foe's OWN body and points at the mark's -- so it always
-- starts on a unit and reads as "this one is coming for that one". (It deliberately does NOT start
-- from intent.fromTile, the tile the foe would strike FROM after moving: a kiter that steps back to
-- shoot would then start its line on the empty retreat tile, and an approaching melee unit on a stub
-- beside its target instead of a clear line all the way from where it stands.)
local function intentLine(unit, intent, retargeted)
    if not intent or intent.wait or not intent.target or not intent.target.alive then return nil end
    return {
        from = { x = unit.x, y = unit.y },
        to = { x = intent.target.x, y = intent.target.y },
        kind = intent.kind,
        retargeted = retargeted or false,
    }
end

-- The target lines to draw while a step onto (destX, destY) is being weighed -- surface B, the heart
-- of the feature. For each foe that could reach that tile, re-derive its plan with the actor
-- hypothetically standing there: if it would wheel onto the actor its line snaps to the destination
-- (retargeted, drawn hot); if not, its line stays on whoever it is already going for (drawn calm), so
-- a foe busy with someone else reads as safe to walk past.
--
-- Bounded to the foes in dangerSources[tile] -- the handful that can even reach it -- and cached by
-- the previewed tile, so a step held under the cursor costs one replan, not one per frame. computeDanger
-- clears the cache when the board moves.
local function retargetLines(current, destX, destY)
    local key = destX .. "," .. destY
    if battle.retargetKey == key and battle.retargetActor == current then
        return battle.retargetLines
    end
    battle.retargetKey, battle.retargetActor = key, current

    local lines = {}
    local from = battle.dangerSources and battle.dangerSources[key]
    if from and Settings.get("enemy_intent")
        and not (battle.tutorial and Tutorial.hidesDanger(battle.tutorial)) then
        -- Resolve the threatening bodies BEFORE the actor is moved, so a unitAt lookup can't be fooled
        -- by the actor now standing on the previewed tile.
        local foes = {}
        for _, src in ipairs(from) do
            local foe = Combat.unitAt(battle.combat, src.x, src.y)
            if foe and foe.alive and foe ~= current then foes[#foes + 1] = foe end
        end
        -- Nudge the actor onto the previewed tile for the duration of the replan, then restore. This is
        -- the ONE mutation the whole feature makes; it must be undone even if a plan errors, so the
        -- replans run inside a pcall and the restore is unconditional.
        local ox, oy = current.x, current.y
        current.x, current.y = destX, destY
        local ok = pcall(function()
            for _, foe in ipairs(foes) do
                local intent = Intent.of(battle.combat, foe, intentResolver)
                if intent and not intent.wait and intent.target and intent.target.alive then
                    local hitsActor = intent.target == current
                    lines[#lines + 1] = {
                        -- From the foe's own body (not its projected strike tile) to whom it will hit:
                        -- the actor's previewed tile if it would wheel onto us, else its real mark.
                        from = { x = foe.x, y = foe.y },
                        to = hitsActor and { x = destX, y = destY }
                            or { x = intent.target.x, y = intent.target.y },
                        kind = intent.kind,
                        retargeted = hitsActor,
                    }
                end
            end
        end)
        current.x, current.y = ox, oy
        if not ok then lines = {} end
    end

    battle.retargetLines = lines
    return lines
end

-- Resolve a turn the player doesn't drive: an AI unit plans and acts, while an inert one (a decoy,
-- control "none") simply holds position -- it still occupies the turn order and burns a tick, so
-- from the far side of the board it is indistinguishable from a real, cautious unit.
-- Resolve a plan's ACTION against the model, and report whether it spent the turn. Two verbs, because
-- a plan can be aimed at two different kinds of thing: `strike` marks an action aimed at a board
-- OBJECT -- the wall or barrel a planner decided to break its way through (models/ai.lua's clearing
-- pass) -- which Combat.strikeObject resolves, since a barrier is not something an ability can be
-- "used on". Everything else is an ordinary Combat.useItem. Shared by both branches below so the
-- walked and unwalked turns can never learn different verbs.
local function resolvePlanAction(current, act)
    if not act.item then return false end
    if act.strike then
        local ok = Combat.strikeObject(battle.combat, current, act.item, act.tx, act.ty)
        return ok
    end
    return Combat.useItem(battle.combat, current, act.item, act.tx, act.ty, act.windup, nil, act.spend)
end

local function executeEnemyAction()
    local current = battle.current
    -- A player-controlled unit reaches here only through auto-battle, and only while its pause is
    -- still standing -- `autoPending` is cleared the instant the player touches anything, which is
    -- what makes taking the turn back immediate rather than queued behind this call.
    local auto = battle.autoPending == current
    if not current or (Combat.isPlayerControlled(current) and not auto) then return end
    -- A unit somebody ELSE is driving. Its turn arrives over the wire as a command, so this machine
    -- must not decide anything for it -- and the guard has to be explicit, because
    -- Combat.isPlayerControlled is false for a remote unit exactly as it is for an AI one, which
    -- means without this line both peers would cheerfully AI-drive the opponent's whole army and
    -- each watch a different battle. Summons inherit their summoner's control, so a remote
    -- summoner's wolf falls through the same hole; it is caught here too.
    if current.control == "remote" then return end
    battle.autoPending = nil
    if current.control == "none" then
        Combat.pass(battle.combat, current)
        advanceTurn()
        return
    end
    local act = scriptedAction(current) or Combat.planEnemyAction(battle.combat, current)
    -- The plan aims from the tile the unit walks to, so the action waits for the walk to finish.
    local function act_()
        if not current.alive then advanceTurn() return end -- cut down on the approach
        local acted = false
        -- act.windup: the depth an AI rule asked a chargeable wind-up to be held at (models/ai.lua).
        -- act.spend: the gold an AI rule pours into a purchasable blow (Aurea's Gilded Wound). Both nil
        -- for an ordinary action; Combat.useItem/spendPurse clamp them to what the caster can actually pay.
        if act.item then acted = resolvePlanAction(current, act) end
        -- Reposition-only, nothing to do, or an item use that unexpectedly failed: pass so the
        -- turn always ends (paying the real move cost) and never soft-locks on this unit.
        if not acted then Combat.pass(battle.combat, current) end
        advanceTurn()
    end
    -- With an approach, the walk and the action both resolve against the model here, in that order,
    -- and only the playback is left for the clock -- the same shape the player's strike takes above.
    -- Without one, there is nothing to replay and act_ resolves inline as it always did.
    if act.move and startWalk(current, act.move.x, act.move.y, nil) then
        -- After the approach is spent, before the action resolves: only the ground THIS action lays is
        -- held back through the walk, exactly as the player's strike above (holdLanding's `pre`).
        local pre = boardObjects()
        if current.alive then
            local acted = resolvePlanAction(current, act)
            -- Reposition-only, nothing to do, or an item use that unexpectedly failed: pass so the
            -- turn always ends (paying the real move cost) and never soft-locks on this unit.
            if not acted then Combat.pass(battle.combat, current) end
        end
        -- A unit cut down on the approach raised nothing here and just hands the turn on.
        local blow = holdLanding(pre)
        battle.walk.onDone = function() advanceTurn(blow) end
        return
    end
    act_()
end

-- The timeline ghost(s) for aiming ability `item` from the current stand tile (with `pendingMove`
-- already spent this turn folded in). A plain cast lands ONE ghost at its action slot. A channeled
-- cast lands TWO: the slot the spell RESOLVES at (its wind-up) and, past that, the slot the caster
-- next acts at (resolution + the cast's own speed, the initiative resolveCast charges when the
-- wind-up finishes) -- so the player reads both when the spell fires and when they regain control.
--
-- A channel resolves its wind-up ticks out NO MATTER how far the caster walked first: the wind-up is
-- the spell's own, and the move cost is deferred past the resolution (models/combat.lua useItem's
-- channel branch). So `pendingMove` sits out of the resolve slot and lands in the follow-up instead --
-- walking moves the ghost the player regains control at, never the one the blast lands at.
local function abilityGhosts(unit, item, pendingMove, windup)
    local a = item.activeAbility
    local lo, hi = Item.windupRange(a)
    if hi > 0 then
        -- The resolve slot moves with the chosen wind-up: a deeper hold on a chargeable signature
        -- (First Motion) is a longer tell, so the turn-order strip shows its blast landing that much
        -- later -- and, past it, the slot the caster regains control at. `windup` is the TOTAL depth
        -- being previewed (the armed depth, or a hovered item's floor) -- since the fold it is simply
        -- the number of ticks until it lands, with nothing to add to it.
        local resolve = math.max(lo, math.min(hi, windup or lo))
        return {
            { initiative = resolve, label = "channel resolves here" },
            { initiative = resolve + pendingMove + Combat.actionSpeed(unit, a, item),
                label = "then acts here" },
        }
    end
    return { { initiative = pendingMove + Combat.actionSpeed(unit, a, item) } }
end

-- The reposition timeline ghost for a walk to the cursor tile: where the unit's NEXT turn lands if
-- it repositions there, following the steered route's own cost when one is set, else the cheapest
-- path's. nil when the cursor isn't a reachable tile (nothing to walk to, so no ghost). Shared by
-- move mode and an armed reposition.
--
-- A bare move never ends the turn -- the unit still has to act or wait -- so a move-ONLY slot is a
-- position it can never actually rest on. With no action aimed, the honest landing slot is a move
-- THEN a wait/defend (its wait speed folded onto the move cost); aiming a real target replaces this
-- ghost with the action's own slot. Without the wait, the ghost under-reads and the card visibly
-- jumps later the moment the unit waits.
local function moveGhostInitiative(unit)
    local cost = battle.movePath and battle.movePath.cost
    if not cost then
        local node = battle.reachable and battle.reachable[battle.map.cursor.x .. "," .. battle.map.cursor.y]
        cost = node and node.cost
    end
    if not cost then return nil end
    return Combat.waitInitiative(battle.combat, unit, Combat.moveInitiative(unit, cost))
end

-- Compute the turn-order preview + battlefield overlays and hand them to the widgets.
refreshView = function()
    local current = battle.current
    if not current then return end
    local isParty = Combat.isPlayerControlled(current) and not battle.over

    -- A lesson holds its tongue until the student's first turn. Everything before that -- the opening
    -- conversation, and the mentor's own demonstration kill -- belongs to her, and an instruction
    -- panel telling the player what to click while they have no turn to click it in is noise laid
    -- over the one beat that is asking them to watch. Latched rather than tested per frame, so it
    -- never blinks off again during the enemies' turns once the lesson is genuinely under way.
    if isParty then battle.lessonOpen = true end

    -- Before anything reads the grid: a lesson step may be handing the player the very item the next
    -- steps are about, and the item panel drawn this frame has to already show it. (Reinforcements
    -- are NOT fielded here -- they land in resolveAdvance, ahead of the objective check.)
    grantLessonItem()

    -- Hold the weapon sheathed for as long as a tutorial step is asking the player to draw it. The
    -- guard in armDefaultAction only covers the START of a turn, and the arming lesson is reached
    -- MID-turn (the move that precedes it doesn't end the turn) -- by which point the turn-start
    -- auto-arm has long since drawn the sword, and the click being taught would sheathe it instead.
    -- Checked every frame rather than at the one advancement point, so it holds no matter which
    -- path arrives at the step. Arming clears the step before the next frame, so this never fights
    -- the player's own click.
    if battle.tutorial and battle.armedItem and Tutorial.suppressesAutoArm(battle.tutorial) then
        cancelArm(true)
    end

    -- Keep the steerable move-route preview fresh. It runs in move mode AND armed mode: while an
    -- item is armed the player steers the same Advance-Wars route to a chosen stand tile, then aims
    -- the strike, which fires from that tile (see armedActionAt). Cleared otherwise (a hovered-slot
    -- preview, an enemy turn) so a stale route never lingers. Must run before the initiative preview
    -- below, which prices a detour off the route's own cost.
    if isParty and not busy() and (battle.mode == "move" or battle.mode == "armed") then
        updateMovePath(current)
    else
        battle.movePath = nil
    end

    -- Preview the projected initiative the pending action would give the actor. The actor
    -- sits at initiative 0; a move already taken this turn is folded in via the pending move
    -- cost, and a wait previews the delay slot (next unit's initiative + 1). A channeled ability
    -- yields TWO ghosts (resolution + follow-up turn); everything else yields one. See abilityGhosts.
    local ghosts
    local pendingMove = (battle.combat.turn and battle.combat.turn.moveCost) or 0
    if isParty then
        if battle.hoverWait or battle.waitPreview then
            -- Whatever the Wait button actually runs -- a plain delay, or a Focus/Defend/Overwatch
            -- swap with its own speed cost -- so the ghost lands on the same slot the action will.
            -- battle.hoverWait is the mouse hovering the Wait button; battle.waitPreview is the armed
            -- first press of the keyboard Wait (see previewOrConfirmWait) -- both light the same slot.
            ghosts = { { initiative = Combat.waitInitiative(battle.combat, current) } }
        elseif battle.hoverItem and battle.hoverItem.activeAbility then
            -- A hovered (not yet armed) chargeable signature previews at its FLOOR -- where it would
            -- land if armed, which opens at windup.min.
            ghosts = abilityGhosts(current, battle.hoverItem, pendingMove, windupFloor(battle.hoverItem))
        elseif battle.mode == "armed" and battle.armedItem then
            -- Project a landing slot only when the cursor is actually aimed at a cell the armed item
            -- can act on: a valid cast target lands the ability's time-cost ghost(s); a reachable tile
            -- lands a reposition ghost. Aiming empty / out-of-range air commits to nothing, so no ghost
            -- shows -- arming an item alone must not paint a timeline slot before a target is aimed.
            local plan = armedActionAt(battle.map.cursor.x, battle.map.cursor.y)
            if plan and plan.kind == "act" then
                -- A walk-and-strike fires from a stand tile the actor must walk to first, so the
                -- landing slot owes that approach's initiative on top of any move already spent this
                -- turn (plan.entry.moveCost is a raw path cost -- convert it, don't add it straight).
                local approach = Combat.moveInitiative(current, (plan.entry and plan.entry.moveCost) or 0)
                -- The armed depth (battle.windup) rides into the ghost, so tuning the wind-up slides
                -- the channel's resolve slot along the strip live. 0 for a non-chargeable armed item.
                ghosts = abilityGhosts(current, battle.armedItem, pendingMove + approach, battle.windup)
            elseif plan and plan.kind == "move" then
                local w = moveGhostInitiative(current)
                if w then ghosts = { { initiative = w } } end
            end
        elseif battle.mode == "move" then
            local w = moveGhostInitiative(current)
            if w then ghosts = { { initiative = w } } end
        end
    end
    -- Once a move is committed its speed cost is locked in (turn.moveCost), so a ghost stays on the
    -- timeline at that slot -- for the PLAYER between the move and choosing an action, and for an ENEMY
    -- the moment it finishes walking. That committed re-entry is where the actor's card solidifies when
    -- the turn hands off, so the current-turn card fades in place instead of sweeping up out of the
    -- frame. The player-preview branches above override it whenever a specific action/aim is shown.
    -- For the deciding PLAYER with nothing aimed, land the ghost where a move-then-wait actually ends
    -- up (its wait speed folded on), not the bare move slot the turn can never rest on -- so the card
    -- doesn't jump later the instant they wait. An enemy just re-enters at its committed move slot.
    if not ghosts and pendingMove > 0 then
        local slot = isParty and Combat.waitInitiative(battle.combat, current) or pendingMove
        ghosts = { { initiative = slot } }
    end
    -- An action that has committed and is holding for its impact beat (pendingAdvance) already charged
    -- the actor forward, so keep a ghost at that now-real slot -- overriding any move-only ghost above.
    -- Without this the aim preview blinks out the instant the swing lands and only reappears when the
    -- card solidifies at hand-off; instead the ghost stays on the strip through the hit and then morphs
    -- into the actor's real card when the turn ends (the solidify path in ui/combat_panel.lua). A
    -- channeling caster is left to Combat.channelGhosts, which owns the resolve/follow-up picture.
    if isParty and battle.pendingAdvance and current.initiative > 0 and not current.channel then
        ghosts = { { initiative = current.initiative } }
    end
    -- Timeline entries for the panel: the live order, plus a ghost of the actor at each projected
    -- slot while a move/item/wait is being previewed, plus a "then acts here" ghost for every unit
    -- still winding up a channel -- so the resolution + follow-up the aim preview showed stay on the
    -- strip once the cast is committed (Combat.channelGhosts). Both kinds of ghost feed one build.
    local specs = Combat.channelGhosts(battle.combat)
    for _, g in ipairs(ghosts or {}) do
        specs[#specs + 1] = { unit = current, initiative = g.initiative, label = g.label }
    end
    -- The timeline is built lower down, once the hovered action is known: a cast that shoves an enemy's
    -- initiative (a stun/freeze/sleep) adds a ghost of THAT unit's delayed turn to `specs` too, and the
    -- action preview is only resolved after the range overlays below.

    -- Board highlights: the acting unit always, plus whichever unit the timeline is hovering.
    local overlays = { move = {}, range = {} }
    -- The tile a step is being previewed onto, set by whichever branch below is steering one (an armed
    -- walk-and-strike's stand tile, or a plain move into a foe's range). Consumed after the branches to
    -- draw the retarget target lines -- "who comes for me if I stand here" (models/intent.lua).
    local previewTile
    local hoverAbility = battle.hoverItem and battle.hoverItem.activeAbility
    -- Keyboard/pad has no hover, so the selected slot (battle.keySlot) stands in for it: selecting an
    -- ability previews its range the way a mouse hover does -- even when the item can't be ARMED right
    -- now (no line, an unpayable cost). Otherwise a cursor player who picks such a slot sees nothing on
    -- the board, while a mouse player hovering the same slot reads its reach. Mouse play carries no
    -- keySlot, so keyItem stays nil there and hoverAbility above owns the preview -- the two never both apply.
    local keyItem = (not InputMode.isMouse() and battle.keySlot
        and current.char.inventory[battle.keySlot]) or nil
    local keyAbility = keyItem and keyItem.activeAbility
    -- The bands belong to a turn that can still be steered. The instant an action commits, the model
    -- has already charged the initiative and the hand-off is only waiting on the blow to finish
    -- reading (battle.pendingAdvance) -- so a move band and an attack range left up through it invite
    -- a second order that will not be taken. They go now, with the click, rather than when the last
    -- damage number fades. The unit marker, hover and the "Threats" survey below are unaffected: those
    -- describe the board, not what this unit may still do.
    local steerable = battle.pendingAdvance == nil
    if steerable and isParty and battle.throwStage == "dest" then
        -- Landing phase of a two-stage throw: the ONLY overlay is the ray of tiles the grabbed thing can
        -- be sent to. No move band -- the grab already fixed where the actor stands -- and it reads as a
        -- strike (red), since a thrown body/keg is offense wherever it lands.
        overlays.range = battle.throwCells or {}
        overlays.rangeSupport = false
    elseif steerable and isParty and ((battle.mode == "armed" and battle.armedItem) or hoverAbility or keyAbility) then
        -- Armed (the turn-start default, or an explicitly armed item), or previewing a hovered ability
        -- slot: show the EFFECTIVE range -- the movement band PLUS the action's reach beyond it, so the
        -- player reads where the unit can step and where it can act from there. Aiming a cell that needs
        -- an approach previews the walk-and-strike route to the stand tile the action fires from.
        -- A hovered ability slot previews ITS reach even while another item is armed, so the range on
        -- the board always belongs to the ability under the cursor. When the hover ends the preview
        -- item falls back to the armed one and the sets rebuild -- rangeFor tracks what they were
        -- built for, so this costs a recompute only when the previewed ability actually changes.
        local previewItem = (hoverAbility and battle.hoverItem) or (keyAbility and keyItem) or battle.armedItem
        local armed = battle.mode == "armed" and previewItem == battle.armedItem
        local support = armed and battle.armedSupport
            or Combat.isSupportAbility(previewItem.activeAbility)
        if previewItem ~= battle.rangeFor then computeRange(current, previewItem) end

        -- Movement band, split by danger (blue safe / purple risky) exactly like move mode.
        local danger = battle.dangerCells or {}
        local moveKeys, safe, risky = {}, {}, {}
        for _, c in ipairs(battle.moveCells) do
            local k = c.x .. "," .. c.y
            moveKeys[k] = true
            if danger[k] then risky[#risky + 1] = c else safe[#safe + 1] = c end
        end
        overlays.move = safe
        overlays.moveDanger = risky

        -- The action's reach BEYOND the move band, plus any occupied target cell -- the move band
        -- already colours the reachable empty tiles, so this is just the extra tiles a move-then-act
        -- reaches (and the foe/ally you would hit). Green for support, red for a strike.
        local band = {}
        for _, c in ipairs(battle.rangeCells or {}) do
            if not moveKeys[c.x .. "," .. c.y] then band[#band + 1] = c end
        end
        overlays.range = band
        overlays.rangeSupport = support

        -- What the armed item would DO on the aimed cell -- read once here and used twice below: the
        -- blast footprint must not be painted over a cell that is going to walk (a tile-aimed weapon
        -- whose swing connects with nothing resolves as a step), and the approach arrow is drawn from
        -- the same plan. Only for the armed item: a hovered-slot preview commits to nothing.
        local plan = armed and armedActionAt(battle.map.cursor.x, battle.map.cursor.y) or nil
        local walking = plan ~= nil and plan.kind == "move"

        -- An AoE ability paints its blast footprint around the aimed cell, brighter than the wash --
        -- unless the click would step onto that cell instead of swinging at it.
        if not walking then
            overlays.aoe = aoeFootprint(previewItem, battle.map.cursor.x, battle.map.cursor.y)
            overlays.aoeSupport = support -- the blast previews as a buff (green) or a threat (orange) by this
        end

        -- Preview the move to reach the aimed cell, drawn as the same arrow move mode uses: onto the
        -- cell when it's a reposition (empty reachable tile), or to the stand tile the action fires
        -- from when hitting a target there. Nil when the unit is already in place or there's nothing
        -- to do.
        if armed then
            local tx, ty, cells
            if plan and plan.kind == "move" then
                tx, ty, cells = plan.x, plan.y, plan.cells
            elseif plan and plan.kind == "act"
                and (plan.entry.fromX ~= current.x or plan.entry.fromY ~= current.y) then
                tx, ty, cells = plan.entry.fromX, plan.entry.fromY, plan.cells
            end
            if tx then
                -- Draw the steered route to the stand tile when the player has one; otherwise the
                -- shortest approach.
                local route = cells
                if not route then
                    local r = Combat.planMove(battle.combat, current, tx, ty)
                    route = r and r.path or nil
                end
                overlays.path = route
                -- A walk-and-strike that steps the actor onto a threatened tile weighs the same
                -- question a plain move does -- who comes for me if I stand there -- so the retarget
                -- target lines are drawn for the projected stand tile below.
                previewTile = { x = tx, y = ty }
            end
        end
    elseif steerable and isParty then
        -- Hovering a unit previews ITS reach instead of the actor's (Fire Emblem / Triangle
        -- Strategy): the hovered unit's own movement (orange) + attack range (crimson) REPLACE the
        -- actor's blue/red/purple overlays until the cursor leaves it. Cached against the unit it was
        -- built for (battle.inspectFor) so it rebuilds only when the hovered unit changes.
        local inspect = desiredInspectUnit()
        if inspect ~= battle.inspectFor then computeInspect(inspect) end
        if inspect then
            overlays.inspectMove = battle.inspectMoveCells
            overlays.inspectRange = battle.inspectRangeCells
        else
            -- Plain move mode (the unit's default action has been disarmed to move freely): no action
            -- band -- the range is shown while an action is armed, which is the turn-start default. Just
            -- the movement overlay here.
            -- Split the reachable move band by danger: a tile the actor could step to that a foe
            -- could ALSO strike this turn turns purple (the intersection of your movement and an
            -- enemy's attack range), so a step into the line of fire reads; the rest stay blue.
            local danger = battle.dangerCells or {}
            local safe, risky, riskyKeys = {}, {}, {}
            for _, c in ipairs(battle.moveCells) do
                local k = c.x .. "," .. c.y
                if danger[k] then risky[#risky + 1] = c riskyKeys[k] = true else safe[#safe + 1] = c end
            end
            overlays.move = safe
            overlays.moveDanger = risky
            -- The route the actor will walk to the cursor tile, drawn as an arrow over the move wash
            -- (nil unless the cursor is a plain walk target -- see updateMovePath).
            overlays.path = battle.movePath and battle.movePath.cells or nil
            -- A step onto a purple tile -- one the actor can reach that a foe can also strike -- is a
            -- move INTO range, so it draws the retarget target lines below: does each threatening foe
            -- actually come for me if I stand here, or stay on whoever it was already going for?
            local ck = battle.map.cursor.x .. "," .. battle.map.cursor.y
            if riskyKeys[ck] then
                previewTile = { x = battle.map.cursor.x, y = battle.map.cursor.y }
            end
        end
    end
    -- Where whichever route was drawn above actually ENDS. Ground that stops a walk dead (quicksand
    -- mires, and a mired unit is going nowhere else this turn -- Combat.stepMove) would otherwise let
    -- the line promise an approach the board cuts in half; past the stop tile it draws as a ghost.
    -- Asked here, once, so the plain move route and the armed approach route are both told the truth.
    if overlays.path then
        overlays.pathStop = Combat.walkStop(battle.combat, current, overlays.path)
    end
    overlays.current = { x = current.x, y = current.y, unit = current }
    local hover = battle.hoverUnit
    if hover and hover.alive then overlays.hover = { x = hover.x, y = hover.y } end
    -- ...and the board points BACK at the timeline: whoever stands under the tile cursor gets their
    -- strip card ringed in the same cyan (ui/combat_panel's boardHover), so the pair answers "which
    -- one is this" in both directions rather than only card -> board. Read off the CURSOR, not the
    -- mouse, so steering the tile with keyboard/pad lights the card the same way a hover does.
    local boardHover = Combat.unitAt(battle.combat, battle.map.cursor.x, battle.map.cursor.y)
    -- The intent line answers "who is this one coming for" for whichever foe is under the cursor,
    -- from EITHER surface: the timeline strip (battle.hoverUnit) or the board itself. A card hover
    -- sets hoverUnit; a board hover only moves the map cursor, so fall back to the foe standing on
    -- the cursor tile -- parity with the timeline card, which already shows the same read.
    local intentHover = hover
    if not (intentHover and intentHover.alive and intentHover.side ~= "party") then
        local u = Combat.unitAt(battle.combat, battle.map.cursor.x, battle.map.cursor.y)
        if u and u.alive and u.side ~= "party" then intentHover = u end
    end
    -- The foe whose on-body intent badge a bare hover would paint (set in the intent block below), held
    -- back until the aimed action is known so it can be dropped when the actor is striking that foe.
    local hoverIntentFoe

    -- Target lines (models/intent.lua): who each enemy will strike, and what it will do. Three tiers,
    -- in precedence order -- while steering a step the question is "who comes for me HERE", and only
    -- when no step is being weighed does the resting picture (survey or hover) show:
    --   1. a step onto a threatened tile   -> the retarget read for the foes that reach it (surface B)
    --   2. the "Threats" survey toggle on   -> every engaged foe's line at once (decision D1)
    --   3. hovering a single foe            -> just that one's line (surface A / the timeline hover)
    if previewTile then
        local rl = retargetLines(current, previewTile.x, previewTile.y)
        if rl and #rl > 0 then overlays.targetLines = rl end
    end
    if not overlays.targetLines and battle.enemyIntents then
        local lines = {}
        if battle.showEnemyRanges then
            for u, intent in pairs(battle.enemyIntents) do
                local l = intentLine(u, intent)
                if l then lines[#lines + 1] = l end
            end
        elseif intentHover and battle.enemyIntents[intentHover] then
            local l = intentLine(intentHover, battle.enemyIntents[intentHover])
            if l then lines[#lines + 1] = l end
        end
        if #lines > 0 then overlays.targetLines = lines end
    end

    -- The combat log points back at the board: the line under the cursor names its subjects
    -- (Combat.logEvent's units), and each one still standing gets a ring here and a ring on its
    -- timeline card below. A line naming two -- the striker and the struck -- draws a thread between
    -- them as well, so "X takes the blow for Y" reads as a relation and not two unrelated lights.
    -- Resolved BEFORE the panel view is built so both surfaces answer the same hover on the same frame.
    local logUnits = battle.log and battle.log:hoveredUnits()
    local logHighlight
    if logUnits then
        local marks = {}
        for _, u in ipairs(logUnits) do
            -- A unit the line is about may have died since (or be the corpse the line is about): only
            -- a body still on the board has a tile worth ringing.
            if u.alive then marks[#marks + 1] = { x = u.x, y = u.y, unit = u } end
        end
        if #marks > 0 then
            overlays.logSubjects = marks
            logHighlight = {}
            for _, m in ipairs(marks) do logHighlight[m.unit] = true end
        end
    end

    -- "Threats" survey (the left-column toggle): wash EVERY tile any enemy could reach-and-strike
    -- this turn in purple, so the whole danger picture reads at once. During the actor's own move
    -- turn its reachable tiles are left to the move overlay (blue / move-danger purple), so the
    -- survey only fills in the danger BEYOND where the actor can step.
    if battle.showEnemyRanges then
        local moveKeys = {}
        -- Only carve the move band out of the survey while that band is actually drawn -- once the
        -- turn has committed it isn't, and subtracting it would punch holes in the danger picture.
        if steerable and isParty and battle.mode == "move" then
            for _, c in ipairs(battle.moveCells or {}) do moveKeys[c.x .. "," .. c.y] = true end
        end
        local ranges = {}
        for k, c in pairs(battle.dangerCells or {}) do
            if not moveKeys[k] then ranges[#ranges + 1] = c end
        end
        overlays.enemyRanges = ranges
        -- With the whole danger picture up, paint each foe's predicted-intent icon on its own body too
        -- (ui/battle_map's drawIntentBadges) -- the same read its timeline card and target line carry,
        -- so "what is this one about to do" answers off the board without tracing a line to a card. Same
        -- cache both other surfaces read (battle.enemyIntents), so the three can never disagree.
        overlays.intentBadges = battle.enemyIntents
    elseif intentHover and battle.enemyIntents and battle.enemyIntents[intentHover] then
        -- Off the survey, one hovered foe still gets its badge ON THE BODY, alongside the target line
        -- above -- so "what is this one about to do" answers right on the sprite, not only by tracing
        -- its line to a timeline card. A single-entry map: drawIntentBadges keys off each unit, so only
        -- the hovered body is marked. But the decision waits until the aimed action is known below: a
        -- foe the actor is about to STRIKE must not wear its own incoming-damage badge, or that number
        -- (what the foe will deal) reads as the damage the PLAYER would deal. See hoverIntentFoe.
        hoverIntentFoe = intentHover
    end

    -- The ground an enemy's Overwatch stance is holding -- slow to enter and shot at on arrival.
    -- Handed over whole rather than filtered against the move band: the point of the ring is that it
    -- is ground you can still walk into, so hiding the part you can reach would erase exactly the
    -- tiles the warning is about.
    overlays.watched = battle.watchedCells

    -- Traps the party can currently see (its own + detected enemy traps): a per-frame lookup for
    -- click-to-damage (revealedEnemyTrapAt) and the list the renderer draws.
    battle.revealedTraps = Trap.revealedTo(battle.combat, "party")
    battle.trapCells = {}
    for _, t in ipairs(battle.revealedTraps) do battle.trapCells[t.x .. "," .. t.y] = t end
    overlays.traps = battle.revealedTraps

    -- Buried charges (the Saboteur's fuses). Like traps, they are the party's to see when the party
    -- laid them and a hidden threat otherwise, so the board only ever shows the party's own -- an enemy
    -- fuse stays under the ground until it goes off. Filtered here rather than in the widget, which
    -- draws whatever list it is handed, exactly as revealedTraps is decided on this side.
    local charges
    for _, c in ipairs(battle.combat.charges or {}) do
        if c.side == "party" and not c.spent then
            charges = charges or {}
            charges[#charges + 1] = c
        end
    end
    overlays.charges = charges

    -- Hazards (fire/rain/sanctuary) are always visible to both sides, so the renderer draws the whole
    -- live list -- no per-side visibility filter like traps have. shownObjects withholds any a cast
    -- has laid but not yet been seen to land (during its approach walk) -- see holdLanding.
    overlays.hazards = shownObjects(battle.combat.hazards)

    -- The bodies a cast has summoned this turn but whose conjuring blow has not yet played (their
    -- summoner is still walking into range). The map keys unit lookups against this to keep them off the
    -- board -- and out of its arrivals tracker -- until advanceTurn reveals them, so a summon knits in
    -- WITH the cast rather than popping onto the field before the caster has moved. Non-unit members of
    -- the held set (hazards, walls) never match a unit lookup, so handing the whole set over is safe.
    overlays.heldUnits = battle.heldObjects

    -- The statuses a unit CARRIES that are worth painting as ground under it: a burning body should
    -- stand in flame, a frozen one in rime. Only the handful whose blueprint declares an `fx` block
    -- qualify -- the badges are the complete read of a unit's condition, and a unit with six statuses
    -- must not be standing in six fields. The renderer's field pass composites these with whatever
    -- hazard already covers the tile, so a burning unit in the rain shows both (ui/field_fx.lua).
    local unitFields
    for _, u in ipairs(battle.combat.units) do
        -- A summoned body still held off the board (its cast's approach walk is replaying) carries no
        -- ground either -- skip it whole, so its fields arrive with it rather than ahead of it.
        if u.alive and not (battle.heldObjects and battle.heldObjects[u]) then
            -- The body's carried ground has to travel WITH it. The model finishes a whole walk at once
            -- (startWalk), so u.x/u.y is already the destination while the sprite is still sliding in from
            -- the origin -- pin the field to the bare cell and a bleeding unit's field detaches and waits
            -- at the destination through the entire walk. The same slide offset the sprite rides (the one
            -- the damage floaters use too, so it tracks a shove as well as a walk) keeps the field under
            -- the feet. Per-unit, not per-status.
            local offX, offY = battle.fx:slideOffset(u, battle.map.size)
            for _, st in ipairs(u.statuses or {}) do
                -- Skip a field a cast just applied but hasn't been seen to land (held through its
                -- approach walk, like the hazards above) -- it blooms in with the blow, not before it.
                if st.def and st.def.fx and not (battle.heldObjects and battle.heldObjects[st]) then
                    unitFields = unitFields or {}
                    unitFields[#unitFields + 1] = { x = u.x, y = u.y, unit = u, status = st, offX = offX, offY = offY }
                end
            end
        end
    end
    overlays.unitFields = unitFields

    -- Imminent reinforcements: the committed-but-not-yet-landed waves (spawnWaves holds a plan from
    -- LEAD_TICKS before a wave is due). The board marks WHERE the muster walks on and counts down to
    -- WHEN, so the player can read it -- and march a body onto a marked tile to turn that arrival back.
    -- A wave commits early (LEAD_TICKS) so its plan is stable, but the telegraph is HELD BACK until the
    -- muster is one turn out (TICKS_PER_TURN ticks): the warning surfaces inside the last turn only, so
    -- the board is never carrying a long, distant clock. (The deny-by-standing mechanic reads the live
    -- board at fireWave, so a wave can still be turned back whether or not it is currently telegraphed.)
    local reinforcements
    local reinforceCells = {}
    local clock = battle.combat.clock or 0
    for _, st in ipairs(battle.combat.waveState or {}) do
        local ticksUntil = st.committed and (st.nextAt - clock)
        if st.committed and clock < st.nextAt and ticksUntil <= Status.TICKS_PER_TURN then
            local p = st.committed
            local ut = math.max(0, ticksUntil)
            reinforcements = reinforcements or {}
            reinforcements[#reinforcements + 1] = {
                tiles = p.tiles, count = #p.tiles, edge = p.edge,
                ticksUntil = ut,
            }
            -- Per-cell lookup so a hover over a marked landing tile reads the muster (drawTileTooltip),
            -- the same way trapCells/wallCells back their hovers. tiles[i] is where chars[i] lands, so a
            -- tile can name the very body walking onto it. The SOONEST arrival owns a contested tile,
            -- matching the board's one-readout-per-tile rule (ui/battle_map.lua drawReinforcements).
            for i, tile in ipairs(p.tiles) do
                local key = tile.x .. "," .. tile.y
                local prev = reinforceCells[key]
                if not prev or ut < prev.ticksUntil then
                    reinforceCells[key] = { edge = p.edge, ticksUntil = ut,
                        char = p.chars and p.chars[i] }
                end
            end
        end
    end
    -- The same marker for a SCRIPTED arrival. A guided fight walks its reinforcements on at authored
    -- cells rather than off a clock (data/tutorials/*.lua `spawn`, fielded by spawnReinforcements), and
    -- the lesson offers the next step's muster one step early (Tutorial.spawnTelegraph) -- so the
    -- village grunt's landing tile is lit while the player is winding up the very blow that lands it,
    -- and the body appears where the board said it would rather than out of nowhere.
    --
    -- No countdown and no deny, and both omissions are the honest ones: it arrives on a STEP, not at a
    -- tick, so there is no number to quote; and spawnReinforcements walks it on regardless of what
    -- stands there, so the marker must not invite a player to hold the ground. `ticksUntil = nil` is
    -- what carries that to the two readouts -- the tile draws no clock (ui/battle_map.lua) and the
    -- tooltip drops the countdown and the deny line (ui/tile_tooltip.lua).
    --
    -- One entry per landing cell rather than one for the lot: a telegraph carries a single arrival
    -- edge for its tiles, and authored cells need not share one.
    for _, s in ipairs((battle.tutorial and Tutorial.spawnTelegraph(battle.tutorial)) or {}) do
        local def = Character.defs[s.char]
        local fp = Character.normalizeFootprint(def and def.footprint)
        local tile = { x = s.x, y = s.y, w = fp.w, h = fp.h }
        local edge = Combat.nearestEdge(battle.combat, s.x, s.y)
        reinforcements = reinforcements or {}
        reinforcements[#reinforcements + 1] = { tiles = { tile }, count = 1, edge = edge }
        -- A timed muster already on this cell keeps it: it has a countdown to show, which is the
        -- richer readout, and the one-readout-per-tile rule matches the board's.
        local key = s.x .. "," .. s.y
        if not reinforceCells[key] then
            reinforceCells[key] = { edge = edge, char = def }
        end
    end

    overlays.reinforcements = reinforcements
    battle.reinforceCells = reinforceCells

    -- Your OWN ground, lit only while a reinforcement is being placed -- the same overlay the deployment
    -- phase draws, so the invitation reads identically whether it is the opening bell or the moment after
    -- a body dropped. Not lit the rest of the time: a permanently glowing home band would be noise.
    if battle.reinforcePick then overlays.deployZone = battle.reinforcePick.tiles end

    -- Walls (conjured blockers) are always visible to both sides too. Keep a per-frame "x,y" lookup
    -- for click-to-strike (wallAt), mirroring battle.trapCells. The RENDER list withholds a wall a cast
    -- is still walking in to raise (shownObjects); the lookup stays live -- input is held mid-walk, so
    -- there is no click for it to answer either way.
    overlays.walls = shownObjects(battle.combat.walls)
    battle.wallCells = {}
    for _, w in ipairs(battle.combat.walls or {}) do
        if w.alive then battle.wallCells[w.x .. "," .. w.y] = w end
    end

    -- Props (the board's own barrels and crates) are sideless and always visible, so like walls the
    -- renderer gets the whole live list and the click handler gets an "x,y" lookup (propAt). Striking
    -- one is the ONLY way to set off an explosive barrel, so this lookup is what makes "shoot the keg"
    -- a click the player can find.
    overlays.props = shownObjects(battle.combat.props)
    battle.propCells = {}
    for _, p in ipairs(battle.combat.props or {}) do
        if p.alive then battle.propCells[p.x .. "," .. p.y] = p end
    end

    -- Preview resources lost / damage dealt on the turn-order banners: the action under the mouse
    -- (the same one the tile tooltip shows) projects its damage/heal onto every affected unit's
    -- banner and its whole spend -- cost plus a summon's reservation -- onto the actor's banner.
    -- Computed after the range/reach overlays so actionPreviewFor sees the current valid-target sets.
    local bannerPreview
    -- Also the source of truth for the context cursor (battle.cursorKind): the descriptor of what a
    -- click on the hovered cell would do, or nil when nothing is aimed. Cleared each frame so it can't
    -- go stale on the enemy's turn or once the mouse leaves the board.
    battle.hoverAction = nil
    if isParty then
        -- Mouse aims by the pointer; keyboard/pad aims by the board cursor tile -- so the intent read
        -- (banner damage/heal previews AND the context-cursor glyph) tracks whichever device is live.
        local cx, cy
        if InputMode.isMouse() then
            if battle.mouseX then cx, cy = battle.map:cellAt(battle.mouseX, battle.mouseY) end
        else
            cx, cy = battle.map.cursor.x, battle.map.cursor.y
        end
        local action = cx and actionPreviewFor(cx, cy)
        battle.hoverAction = action or nil
        if action then
            bannerPreview = {}
            if action.entries then
                for tgt, e in pairs(action.entries) do
                    bannerPreview[tgt] = { damage = e.damage, heal = e.heal, lethal = e.lethal }
                end
            end
            if action.actor and action.spend and #action.spend > 0 then
                local a = bannerPreview[action.actor] or {}
                a.spend = action.spend
                bannerPreview[action.actor] = a
            end
        end
    end
    -- ...and where the aimed cast would leave the ACTOR, when it moves it: Shadow Step slips to a tile
    -- beside its mark before it cuts, a hit-and-run blow steps back out of reach. The board marks that
    -- tile (ui/battle_map's landing ring), because "where do I end up" is half of what a cast like that
    -- is being weighed on -- the reach band answers where it can be thrown from, and nothing until now
    -- answered where it puts you. The white approach arrow already drawn above ends on the tile the
    -- cast fires from, so the mark picks up from there and the two legs read as one plan.
    if battle.hoverAction and battle.hoverAction.lands then
        local l = battle.hoverAction.lands
        overlays.landing = { x = l.x, y = l.y, fromX = l.fromX, fromY = l.fromY, unit = current }
    end

    -- Now the aimed action is known: paint the hovered foe's intent badge on its body UNLESS the actor
    -- is aiming an offensive strike right at it. Aiming it, its incoming-damage number sits on the very
    -- body being targeted and reads as the damage the PLAYER deals; the tile tooltip already prices that
    -- strike. Out of reach (no offensive plan on it), the badge answers "what will this threat do" -- the
    -- read a bare hover is for. Support casts and repositions don't confuse the number, so they keep it.
    if hoverIntentFoe then
        local a = battle.hoverAction
        local aimingFoe = a and a.target == hoverIntentFoe
            and (a.kind == "attack" or (a.kind == "ability" and not a.support))
        if not aimingFoe then
            overlays.intentBadges = { [hoverIntentFoe] = battle.enemyIntents[hoverIntentFoe] }
        end
    end

    -- Hovering an ability SLOT (the cursor is on the panel, so there's no aimed board action) prices
    -- the same spend onto the actor's bars, beside the range it already previews -- so what a cast
    -- would take reads before committing to arm it, not only once it's aimed.
    if isParty and not bannerPreview and hoverAbility then
        local spend = Combat.abilitySpend(current, hoverAbility)
        if #spend > 0 then bannerPreview = { [current] = { spend = spend } } end
    end

    -- A target whose initiative the hovered action would shift (a stun/freeze/sleep shoving it later, a
    -- hasten pulling an ally earlier) gets its OWN preview ghost, so the strip shows where the hit lands
    -- its turn -- the same "you are here now / you would move to here" the actor's own aim ghost shows.
    -- Skipped when the blow would fell the target (a corpse takes no turn) or when the shift is a
    -- sub-tick sliver, and never for the actor itself (its own slot is the actor ghost above).
    if battle.hoverAction and battle.hoverAction.entries then
        for tgt, e in pairs(battle.hoverAction.entries) do
            if e.initiativeAfter and not e.lethal and tgt ~= current
                and math.abs(e.initiativeAfter - tgt.initiative) > 0.5 then
                local delayed = e.initiativeAfter > tgt.initiative
                local label = e.initiativeCause
                    and (delayed and ("delayed by " .. e.initiativeCause) or (e.initiativeCause .. " frees it"))
                    or (delayed and "delayed to here" or "rushed forward")
                specs[#specs + 1] = { unit = tgt, initiative = e.initiativeAfter, label = label }
            end
        end
    end

    -- Now the strip: the live order plus every ghost gathered above (the actor's aim, in-progress
    -- channels, and any shoved target). Anchor the acting unit at rank 1 until the UI actually hands
    -- off -- the model charges its initiative and rebases the instant it acts (endTurn, inside useItem),
    -- a beat before resolveAdvance switches battle.current, so buildTimeline would otherwise re-rank the
    -- current card and slide it upward mid-attack while its damage still reads.
    local entries = Combat.buildTimeline(battle.combat, specs)
    for i, e in ipairs(entries) do
        if e.unit == current and not e.preview then
            table.remove(entries, i); table.insert(entries, 1, e); break
        end
    end

    battle.panel:setView({
        order = entries, current = current, isPartyTurn = isParty,
        items = Combat.isPlayerControlled(current) and current.char.inventory or {},
        itemOwner = Combat.isPlayerControlled(current) and current.char or nil, -- for adjacency link lines
        armedItem = battle.armedItem,
        waitPreview = battle.waitPreview, -- first-press keyboard Wait: lights the Wait button like a hover
        -- The chargeable wind-up being tuned on the armed signature (nil unless a CHARGEABLE one is
        -- armed), so the actions header can read out how deep the blow is being held. Two numbers,
        -- not three: since the wind-up fields folded, the depth is the commitment the bonus is scored
        -- on (models/item.lua's Item.windupRange). It equals the resolve time at an ordinary tempo, but
        -- Haste/Mired scale the actual tell (Combat.useItem's timeTicks) apart from the depth shown here.
        armedWindup = (function()
            local ab = battle.armedItem and battle.armedItem.activeAbility
            if not Item.isChargeable(ab) then return nil end
            local _, hi = Item.windupRange(ab)
            return { ticks = battle.windup or 0, max = hi }
        end)(),
        showInitiative = battle.showInitiative,
        preview = bannerPreview,
        -- Units the hovered combat-log line is about, so their cards light up with their tiles.
        logHighlight = logHighlight,
        -- The body under the board's tile cursor, so pointing at someone on the field finds them on
        -- the timeline (the mirror of a card hover ringing the body -- overlays.hover above).
        boardHover = boardHover,
        -- Each engaged foe's predicted action (models/intent.lua), so its turn-order card can show
        -- the Slay-the-Spire intent icon + incoming number. Same cache the board's target lines read,
        -- so icon and line can never disagree. Empty when the player has the read switched off.
        intents = battle.enemyIntents,
    })

    -- Telegraph every in-progress channel's blast on the board -- not just the local armed preview, so
    -- an ENEMY winding up Meteor Storm paints the tiles it will hit, and the player can step clear.
    -- Read from unit.channel (the pending payload), independent of whose turn it is.
    local channelAoe, channelSupport
    for _, u in ipairs(battle.combat.units) do
        local ch = u.alive and u.channel
        if ch then
            channelAoe = channelAoe or {}
            -- The first channeler's disposition dresses the telegraph: a supporting working previews as
            -- the green chevrons of the buff it lays, an offensive one as the orange of a threat (several
            -- channelling at once is rare enough that one shared picture beats splitting it by owner).
            if channelSupport == nil then channelSupport = Combat.isSupportAbility(ch.ab) or false end
            -- Call Combat.aoeCells directly rather than aoeFootprint: the footprint helper gates on the
            -- ACTING unit's range set, but this is the channeler's own stored aim, cast turns ago.
            for _, c in ipairs(Combat.aoeCells(battle.combat, ch.ab, ch.tx, ch.ty, u)) do
                channelAoe[#channelAoe + 1] = c
            end
        end
    end
    overlays.channelAoe = channelAoe
    overlays.channelSupport = channelSupport

    overlays.hpPreview = bannerPreview -- per-unit incoming damage/heal, for on-board HP bars

    -- The ground a `reach` or `hold` objective is fought over (Arena.resolveRegion). Painted for the
    -- whole battle, not just while something is armed: an objective tile nobody can see is an
    -- objective nobody can play, and the HUD line above promises "the marked ground".
    --
    -- Which tiles that is per objective type is Combat.objectiveGround's answer, shared with the hover
    -- tooltip (Combat.objectiveTileInfo) so the box that opens describes exactly the ground the wash
    -- painted: the control node's live waypoint (it hops on the clock, so this follows it), the tiles a
    -- defend's protectees currently stand on (read live, since they walk -- the anchor region stays in
    -- obj.tiles for enemy pathing but isn't what the HUD washes), or a reach/hold objective's fixed
    -- ground. Nothing at all once a defend's charge has fallen: that loss is already sealed.
    local obj = battle.combat.objective
    local ground = Combat.objectiveGround(battle.combat)
    if #ground > 0 then
        overlays.objective = ground
        -- Both contested objectives need their progress legible, so the wash reports whether the count
        -- is running: `hold` for the party, `control` for whichever side the LOCAL player commands.
        if obj.type == "control" then
            overlays.objectiveHeld =
                (Combat.controlledBy(battle.combat, ground) == (battle.combat.playerSide or "party")) or nil
        elseif obj.type == "hold" then
            overlays.objectiveHeld = Combat.holdsGround(battle.combat, ground) or nil
        end
    end

    -- Your own lines, outlined quietly for the whole fight (ui/battle_map.lua drawRallyGround) -- but
    -- only while somebody is still on the bench, which Combat.rallyGround decides. It is the standing
    -- statement that replaced the always-there Fall Back plate: the ground says where the move can be
    -- made from, the tile's tooltip says what it does, and the button appears once a body is on it.
    local rally = Combat.rallyGround(battle.combat)
    overlays.rally = #rally > 0 and rally or nil

    -- SEND SOMEONE IN, from the board. While a slot stands open the free rally tiles stop being a quiet
    -- outline and become the control: click one and the chooser opens anchored on it, already knowing
    -- where the body lands. They wear the deployment phase's own breathing fill, because that overlay's
    -- sentence is "an invitation to act NOW" -- which docs/deployment.md reserved for the phase on the
    -- grounds that a permanent glow is noise. An open slot is not permanent. It is the one moment
    -- mid-fight when the phase's sentence is true again, so it gets the phase's mark.
    --
    -- A tile the acting unit could WALK to is left out. Moving home and reinforcing home are both honest
    -- readings of a click on your own back rows, and the move is the older and far more frequent one --
    -- so it keeps every tile it can reach, and this takes only what would otherwise be inert. That makes
    -- the lit set exactly the clickable set: no tile is ever marked for something it will not do.
    battle.reinforceHere = nil
    if not battle.reinforcePick and not battle.over and Combat.canReinforce(battle.combat) then
        local here, cells = {}, {}
        for _, t in ipairs(Combat.reinforceTiles(battle.combat)) do
            if not (battle.reachable and battle.reachable[t.x .. "," .. t.y]) then
                cells[#cells + 1] = t
                here[t.x .. "," .. t.y] = true
            end
        end
        if #cells > 0 then
            battle.reinforceHere = here
            overlays.deployZone = cells
            -- This fill can be a strict SUBSET of the rally ground (the withheld reachable tiles), and
            -- drawRallyGround otherwise stands down entirely the moment a deploy overlay exists. Left
            -- alone, a partial fill would rub the outline off the tiles it does not cover and your lines
            -- would appear to have holes in them. The flag says "some of it, not all" -- so the boundary
            -- keeps tracing the whole zone and the fill marks the live tiles inside it.
            overlays.deployZonePartial = #cells < #rally or nil
        end
    end

    battle.map:setOverlays(overlays)
end

-- ---------------------------------------------------------------------------
-- State callbacks
-- ---------------------------------------------------------------------------

-- The conversation this battle opens with, played over the board before a turn resolves -- or nil for
-- a fight that just starts. ANY battle may have one; the tutorial was only the first caller.
--
-- Three sources, in order, because they answer different questions:
--
--   opts.opening        -- this particular launch. Whoever switched to the battle said so: a quest
--                          map naming a scene for its objective fight, a story beat, a scripted duel.
--   the ENCOUNTER def   -- this KIND of fight, wherever it turns up. `opening` on an encounter
--                          blueprint (data/encounters/*.lua) fires every time that encounter is
--                          engaged, on any map, with no plumbing through the overworld -- the cell
--                          carries the id and the blueprint is looked up right here.
--   the lesson          -- a guided fight's own opening (data/tutorials/*.lua's `opening`).
--
-- First one wins, so a specific launch can override the generic encounter, which can in turn say
-- something a lesson does not.
local function openingConversation(opts)
    if opts.opening then return opts.opening end
    local enc = opts.encounter
    local def = enc and enc.id and EncounterModel.get(enc.id)
    if def and def.opening then return def.opening end
    return battle.tutorial and Tutorial.opening(battle.tutorial) or nil
end

-- ---------------------------------------------------------------------------
-- The deployment phase
-- ---------------------------------------------------------------------------
--
-- Every ordinary battle opens on it: the board is built and the enemy is standing on it, the deploy zone
-- is lit, and the player drags up to Combat.MAX_FIELD of their marching company onto it. Whoever is left
-- on the strip is the bench, and can be rotated in later (models/combat.lua). See docs/deployment.md.
--
-- The phase itself is a widget (ui/deploy_phase.lua) -- it owns the strip, the drag and the placement --
-- and this file owns the two things only the battle can: the RECT the strip lives in (the combat log's,
-- so the two can never drift apart), and what committing MEANS.

-- The gutter under the board, board-width: the combat log's rect, and the deployment strip's.
local function gutterRect()
    local m = battle.map
    if not m then return { x = 0, y = 0, w = 0, h = 0 } end
    local y = m.originY + battle.arena.rows * m.size + 8
    return { x = m.originX, y = y, w = battle.arena.cols * m.size, h = Scale.HEIGHT - y - 8 }
end

-- Everything that used to happen at the bottom of battle.enter, now gated behind the player committing
-- their line. Runs for a SKIPPED phase too (`deploy = false`), where the units were seated by whoever set
-- the fight up -- so there is exactly one path into "the fight is now running".
--
-- `deployed` / `front` / `placed` are nil on that skipped path and supplied by the phase otherwise.
local function commitDeploy(opts, deployed, front, placed)
    if placed then
        -- Resolve the opening now that the line exists: relic traits (front-row scopes included) and the
        -- opening boons a companion ability or a relic queued. states/game.lua owns that logic; battle
        -- only says who is standing where. A fight launched without the callback (a probe, a debug
        -- board) simply gets none, which is what it had before.
        local resolved = opts.resolveOpening and opts.resolveOpening(deployed, front) or {}
        opts.openingBoons = resolved.openingBoons or opts.openingBoons
        -- Stamped BEFORE the bell: Combat.openBattle's Trait.setup attaches every unit's traits (its own
        -- plus whatever is sitting in relicTraits) and only then fires the openers, so a relic's trait is
        -- on the body before anything asks it to react.
        local traits = resolved.relicTraits or opts.relicTraits
        -- The supper the company ate before setting out (models/meal.lua). One platter for everyone
        -- who marched, so unlike the relic traits it needs no per-char map -- and it goes onto the
        -- BENCH too, since a member rotated in mid-fight ate the same meal as the four who opened.
        local meal = opts.meal
        for _, p in ipairs(placed) do
            p.unit.relicTraits = traits and traits[p.char] or nil
            p.unit.meal = meal
        end

        -- Whoever was not placed waits on the bench, in company order, and can be rotated in.
        local standing = {}
        for _, c in ipairs(deployed) do standing[c] = true end
        for _, char in ipairs(opts.party or {}) do
            if not standing[char] then
                Combat.benchUnit(battle.combat,
                    { char = char, relicTraits = traits and traits[char] or nil, meal = meal })
            end
        end

        -- battle.partyUnits is what the spoils roll and the post-fight roster read walk, so it names
        -- everyone who took the field.
        for _, p in ipairs(placed) do
            battle.partyUnits[#battle.partyUnits + 1] = { char = p.char, x = p.x, y = p.y }
        end

        Player.noteDeployed(opts.player, deployed)
        battle.deploy = nil
        battle.map:setOverlays(nil)
    end

    -- Whether this fight has a bench AT ALL, fixed here rather than read live, so the drawer's
    -- Reinforce entry cannot appear and vanish as reserves are spent.
    -- False in every duel, draft and scripted lesson, which field exactly who they were given.
    battle.hasBench = #(battle.combat.bench or {}) > 0

    -- The baseline battle.offerOpenSlot measures a fallen body against: whoever is standing at the bell.
    -- Seeded from the committed line rather than from MAX_FIELD, so a player who deliberately fielded
    -- three and kept a reserve back is not greeted by a chooser before a blow has landed -- the prompt
    -- answers a DROP below this number, and there has not been one.
    battle.lastFieldCount = Combat.fieldCount(battle.combat, battle.combat.playerSide or "party")
    battle.slotOffer = false

    -- Ring the bell: passives, reservations, the stamina refill and every battle-opener trait, once,
    -- with the company standing where it is going to stand. See Combat.openBattle.
    Combat.openBattle(battle.combat)

    -- Opening boons: statuses a run relic (or a companion ability) queued to open this fight under -- a
    -- barrier, Haste, an empower (models/relic.lua's grantBoon). Applied here, once the units are built
    -- and traits are set, so they read as present from the first turn without touching a live combat
    -- action. Matched to their unit by char identity (the same instance game.lua queued them for).
    for _, boon in ipairs(opts.openingBoons or {}) do
        for _, unit in ipairs(battle.combat.units) do
            if unit.side == "party" and unit.char == boon.char and unit.alive then
                Status.apply(battle.combat, unit, boon.id, boon.opts)
                break
            end
        end
    end
    -- A scripted lesson addresses units by name (Tutorial.scriptFor). A party member answers to its
    -- character id, which is unique within a party; an enemy answers to the CELL IT SPAWNED ON,
    -- because a lesson may field several of one blueprint and three identical imps would otherwise
    -- share -- and race for -- a single queue. Stamped here, the one moment x/y still hold the spawn.
    for _, u in ipairs(battle.combat.units) do
        u.scriptKey = (u.side == "party") and u.char.id or (u.x .. "," .. u.y)
    end
    -- A guided fight's turn order is authored, not hoped for: the lesson seats every unit on the
    -- timeline itself (Tutorial.startInitiative). Gear decides the order otherwise, and gear is
    -- tuned for the fiction -- the mentor's mace is slower than the student's sword, so left alone
    -- she cycles behind the very player she is demonstrating to. Rebased afterwards, per
    -- Combat.openBattle's own convention; the seating is not elapsed time, so the clock goes back to 0.
    if Tutorial.paces(battle.tutorial) then
        for _, u in ipairs(battle.combat.units) do
            u.initiative = Tutorial.startInitiative(battle.tutorial, u.scriptKey)
        end
        Combat.rebase(battle.combat)
        battle.combat.clock = 0
    end

    battle.panel = CombatPanel.new(battle.combat, {
        onActivateItem = function(item) armItem(item) end,
        onHoverItem = function(item) battle.hoverItem = item end,
        onHoverUnit = function(unit) battle.hoverUnit = unit end,
        onWait = function() waitTurn() end, -- the long Wait button under the item grid
        onRotate = function() openBenchChooser("rotate") end, -- FALL BACK: trade places with the bench
    })
    battle.panel.fx = battle.fx

    beginTurn()
    refreshView()

    -- Fingerprint the board BEFORE a single turn is taken, as turn 0 -- and AFTER the deployment commit,
    -- because where the company is standing is part of the opening position.
    --
    -- Two peers that disagree about the opening position disagree about everything after it, and a
    -- mismatch discovered on turn 1 is indistinguishable from one caused by the first command. This
    -- separates the two questions: if turn 0 differs, the fight was never the same fight, and the
    -- fault is in setup -- the rosters, the seed, the content -- rather than in anything either
    -- player did.
    if battle.session then
        battle.session:report(0, battle.combat)
        if battle.netLog then
            battle.netLog("opening board hash "
                .. require("models.state_hash").digestOf(battle.combat))
        end
    end
    return true
end

-- The LOADOUT screen, opened over the deployment phase: the same panel the hub's Armory and the
-- overworld's I key open (ui/panels/party.lua), on the same roster and the same stash.
--
-- Gear is the other half of the decision this phase exists for. Where a body should stand is answered
-- against what it is carrying -- a spear wants the second rank, a dagger wants the flank -- and until
-- now the last chance to move an item was a leg of overworld ago, before the player had seen the
-- ground, the enemy line, or the objective. So the screen the answer is changed on is reachable from
-- the screen the question is asked on.
--
-- Modal over the phase, exactly as the Settings overlay is, and required lazily: a fight that skips
-- deployment (a duel, a draft, a scripted lesson) never pays to load the panel.
function battle.openDeployLoadout(player)
    if battle.deployLoadout or not battle.deploy then return end
    local standing = battle.deploy:deployedChars()
    battle.deployLoadout = require("ui.panels.party").new({
        player = player,
        -- The company standing right now wears the rail's amber dot, in the same gold the strip marks
        -- them with a bar -- so "am I kitting someone who is actually in this fight?" is answered on
        -- the screen the kit is changed on.
        fielded = standing,
        -- Rule lists are the city's lesson: before the flight tutorial has reached it, this screen is
        -- the equip screen and nothing else -- the same line states/game.lua draws over the overworld.
        tactics = not battle.tutorial,
        onClose = function()
            battle.deployLoadout = nil
            -- A body snapshots what its gear decides at the moment it is stood up (its initiative is
            -- the average speed of its ability items), so that is re-read now the gear may have
            -- changed. Nobody moves. See DeployPhase:refreshPlacements.
            if battle.deploy then battle.deploy:refreshPlacements() end
        end,
    })
    -- Opened on someone who is actually going to fight, when there is one: the panel's first member is
    -- the roster's first, who may well be on the bench.
    for i, char in ipairs(player.roster or {}) do
        if char == standing[1] then battle.deployLoadout:focusChar(i) break end
    end
end

-- Open the phase, or commit straight through for a caller that already decided placement.
local function openDeployPhase(opts)
    if opts.deploy == false then
        commitDeploy(opts)
        return
    end
    -- Light the ground. The phase's whole board-side statement, and the same overlay a reinforcement
    -- uses later in the fight, so "you may come in here" looks the same at minute zero and at minute
    -- ten (ui/battle_map.lua's drawDeployZone).
    battle.map:setOverlays({ deployZone = battle.combat.deployZone or {} })
    battle.deploy = DeployPhase.new({
        combat = battle.combat, map = battle.map, arena = battle.arena,
        roster = opts.party or {}, player = opts.player, gutter = gutterRect(),
        column = battle.deployControlRect,
        -- The Loadout screen, but only for a fight with a real player (and therefore a stash) behind
        -- it: a probe or a debug board has nothing to open. See battle.openDeployLoadout.
        onLoadout = opts.player and function() battle.openDeployLoadout(opts.player) end or nil,
        -- Whether the fight is played or watched is asked HERE, next to the bell, seeded from the
        -- standing preference (battle.autoAll carries across fights, like the playback speed) and
        -- handed back on the commit -- so the phase's switch and the drawer's Auto entry are one flag
        -- read and written in two places, never two settings that can disagree. A tutorial forbids it
        -- outright (autoAllowed), and the toggle does not draw at all there.
        autoBattle = battle.autoAll, allowAuto = autoAllowed(),
        onCommit = function(deployed, front, placed, auto)
            if autoAllowed() then battle.autoAll = auto and true or false end
            commitDeploy(opts, deployed, front, placed)
        end,
    })
end

function battle.enter(self, opts)
    opts = opts or {}
    battle.onWin = opts.onWin
    -- The defeat panel's two exits (either may be nil). onLoss is "Return to Hub" -- give the fight up
    -- and end the quest; onRetry is "Try Again" -- restart this same fight. The launcher decides which
    -- exist: an overworld fight has both, a tutorial fight has only onRetry (no hub to abandon to yet).
    -- See states/game.lua and states/prologue.lua.
    battle.onLoss = opts.onLoss
    -- What that exit is CALLED. "Return to Hub" is right for a quest, which is abandoned back to the
    -- city; a descent has no city to be returned to, and a button that names one the player cannot reach
    -- is a button that lies about where it goes. The launcher names it (states/game.lua); the default
    -- keeps every existing caller reading exactly as it did.
    battle.lossLabel = opts.lossLabel
    battle.onRetry = opts.onRetry
    -- A phrase naming what the overworld run stands to lose here ("4 items, 210 gold"), shown on the
    -- defeat panel. Passed down rather than computed, since the fight knows nothing about the run.
    battle.lostHaul = opts.lostHaul
    battle.encounter = opts.encounter or { kind = "combat", name = "Battle" }
    battle.prestige = opts.prestige or 1 -- the company's prestige, used to roll the victory spoils
    -- Which house's stock this run's fights salvage in: the quest's SPONSOR, the same resolution the
    -- map's caches use (states/game.lua). Nil on an unsponsored leg -- the prologue -- where a fight
    -- pays craft stock and nothing else.
    battle.houseMaterial = opts.houseMaterial
    -- The level everyone the player did NOT bring is grown to. Enemies and escorted allies run through
    -- the same growth tables the roster does (Growth.spawn), so the far side climbs with the company
    -- instead of staying pinned at blueprint level 1. `floorLevel` is this fight's authored minimum --
    -- the difficulty it may never drop below, however green the party is; a blueprint's own floor and
    -- `scaling = false` are honoured per unit inside Growth.combatantLevel.
    battle.enemyLevel = Growth.levelForPrestige(battle.prestige)
    battle.floorLevel = opts.floorLevel
    battle.fallen = nil                  -- who went down in THIS fight, for the launcher's wounds
    battle.summary = nil                 -- the victory/defeat overlay, once the fight is decided
    battle.logReview = nil               -- the summary's "Review Combat Log" modal, when opened
    battle.settingsMenu = nil            -- the in-battle settings overlay, when opened
    battle.windupChooser = nil           -- the chargeable-swing depth chooser, while a swing is sized
    battle.spendChooser = nil            -- the purchasable-blow money slider, while a swing is priced
    battle.debugMenu = nil               -- the right-click debug context menu (debug builds only)
    battle.debugPickTile = nil           -- while the debug "Move to tile" is awaiting a destination click
    battle.over = false
    battle.showInitiative = true -- initiative numbers on the turn order (F6 toggles)

    -- Draft/PvP chess clock: a real-time budget per side that only runs on that side's turn, so slow
    -- play loses. A REAL-TIME overlay -- the combat model itself stays tick-based and headless; this
    -- lives entirely in the state. Nil in a campaign fight, which is untimed. `battle.isDraft` gates
    -- the extra HUD (the two scores + the clock) so an ordinary battle draws none of it.
    battle.isDraft = opts.draft or nil
    battle.chessClock = opts.chessClock and { party = opts.chessClock, enemy = opts.chessClock } or nil

    -- The bed, and the sting over the top of it. An `objective` encounter is the quest's real fight --
    -- a general, a boss, the Crown -- so it gets its own track; everything else is an ordinary bout on
    -- the way there. An encounter may also name its OWN bed (`encounter.music`) to override that pick --
    -- the Mock Battle is objective-kind (so it draws its hand-picked roster) but wants the ordinary
    -- battle bed, not the boss one. Both are silent until the files exist (models/sound.lua), and
    -- Sound.music is idempotent, so re-entering the same kind of fight does not restart the track.
    Sound.music(battle.encounter.music
        or (battle.encounter.kind == "objective" and "music.boss" or "music.battle"))
    Sound.play("battle.start")

    -- Active party instances (from the player). Matched to their spawns by POSITION rather than by
    -- id: Arena.build binds ids to spawn points in the order it is given them (bindUnits), so index
    -- i of the arena's party is index i of this list. Keying by char.id instead would collapse two
    -- of the same blueprint onto one instance -- which the player's own roster cannot do today, but
    -- a team assembled from a build can, and silently fielding one knight twice is a hard bug to see.
    local party = opts.party or {}
    local partyIds = {}
    for i, char in ipairs(party) do partyIds[i] = char.id end

    -- A guided fight (the prologue's village defense) runs a lesson over the top of the ordinary
    -- battle: it speaks over one unit's head, narrows the board to the action it is asking for, and
    -- drives the units it names itself. Nil in every other battle, which is what every hook below
    -- tests for. See models/tutorial.lua.
    -- A live duel. Nil in every other battle, which is what every netplay hook tests for. The
    -- session is built by whoever set the duel up (it owns the transport and the handshake); this
    -- state only speaks turns to it.
    -- Debug-only: take this side's turns automatically. It exists so a duel can be driven from two
    -- windows with nobody at either keyboard (states/duel_debug.lua), which is the only way to prove
    -- the netplay wiring without two people. Refused outright in a release build.
    battle.autoPilot = opts.autoPilot and require("models.debug").enabled or nil
    battle.autoPilotTimer = 0
    battle.netLog = opts.netLog -- optional: where a duel's turn/hash trace goes (debug harness)

    battle.session = opts.session
    if battle.session then
        battle.session.onCommand = function(cmd) netApplyRemote(cmd) end
        battle.session.onDesync = function(n, mine, theirs)
            notify("Desynchronised on turn " .. tostring(n) .. " -- the duel cannot continue.")
            -- Through the model's own log, which the panel reads. (An earlier version called a
            -- method the log does not have, so the one path that reports a desync crashed on the
            -- first real one -- the error handler failing exactly when it was needed.)
            Combat.logEvent(battle.combat, "system",
                "Desync on turn " .. tostring(n) .. ": " .. tostring(mine) .. " vs " .. tostring(theirs))
            if battle.netLog then
                battle.netLog("DESYNC turn " .. tostring(n) .. " mine=" .. tostring(mine)
                    .. " theirs=" .. tostring(theirs))
            end
            battle.over = true
        end
        battle.session.onClosed = function(reason)
            notify("Duel ended: " .. tostring(reason))
            battle.over = true
        end
    end

    battle.tutorial = opts.tutorial and Tutorial.new(opts.tutorial) or nil
    battle.lessonOpen = battle.tutorial == nil -- see refreshView: a lesson stays quiet until it is the student's turn

    -- The board is reproducible from this number alone, so whoever starts the fight owns it: an
    -- ordinary battle rolls a fresh one, a replayed bug report passes the one it recorded, and two
    -- players in the same duel are handed the same seed and build the same ground from it.
    local seed = opts.seed or Arena.randomSeed()
    -- `encounterKind` picks the fight TIER -- skirmish or set-piece (Arena.enemyCap). A field on the
    -- existing ctx table rather than a new local: this file sits within a couple of declarations of
    -- Lua 5.1's 200-local ceiling, and crossing it is a compile error naming an unrelated line.
    local ctx = { prestige = opts.prestige or 1, biome = opts.biome, quest = opts.quest,
        encounterKind = opts.encounter and opts.encounter.kind }
    battle.arena = Arena.build(ctx, specFor(opts, partyIds, seed))

    -- Combat unit lists: { char = <instance>, x, y }.
    --
    -- The PARTY's is filled in one of two ways, and this is the fork the deployment phase turns on:
    --   * `deploy == false` -- a scripted fight (the prologue, a lesson), a duel, a draft or a build
    --     match. Placement was decided by whoever set the fight up, so the arena's bound spawns ARE the
    --     party and the fight opens on them, exactly as it always did.
    --   * otherwise -- an ordinary campaign battle. Nothing is seated here at all: the board is built
    --     with the enemy on it and no party, and the player stands their company through the deployment
    --     phase (openDeployPhase below). The arena's bound spawns survive as that phase's auto-fill, so
    --     "Auto" puts everyone exactly where this branch would have.
    battle.partyUnits, battle.enemyUnits = {}, {}
    battle.deployEnabled = opts.deploy ~= false
    if not battle.deployEnabled then
        for i, u in ipairs(battle.arena.party) do
            -- A tutorial may take a party member out of the player's hands (the mentor demonstrating the
            -- lesson she just gave). Combat.new already honours a per-unit control override on the party
            -- side -- the same seam escorted allies use -- so she stays a party unit for the objective
            -- and the turn order, and simply isn't player-controlled.
            battle.partyUnits[#battle.partyUnits + 1] = {
                char = party[i], x = u.x, y = u.y,
                control = battle.tutorial and Tutorial.controlFor(battle.tutorial, u.id) or nil,
                -- Trait ids this member's run relics grant (models/relic.lua), keyed by char identity in
                -- states/game.lua; Trait.attach folds them in with the char's own. Nil when the member wears
                -- none, or in a fight with no relics carried (a tutorial leg, a duel).
                relicTraits = opts.relicTraits and opts.relicTraits[party[i]] or nil,
                -- The quest's meal (models/meal.lua). Nil on every fight launched outside a campaign
                -- run -- a duel, a draft, a build match -- which is the correct reading: nobody ate.
                meal = opts.meal,
            }
        end
    end
    -- Escorted allies fight on the party's side but are not the player's characters (they
    -- are not in partyById), so they get fresh instances and run themselves. A `protect`
    -- objective points at one of these; see Arena.build and Combat.evaluate.
    -- Scaled like the far side, not left at level 1: an escort is what a `protect` objective is won or
    -- lost on, and a blueprint-level survivor standing in a late-campaign fight would be a body that
    -- falls to the first blow through no decision of the player's.
    for _, u in ipairs(battle.arena.allies or {}) do
        battle.partyUnits[#battle.partyUnits + 1] =
            { char = Growth.spawn(u.id, battle.enemyLevel, battle.floorLevel), x = u.x, y = u.y, control = "ai" }
    end
    -- The far side is normally minted fresh from blueprint ids. `opts.enemyChars` hands over live
    -- instances instead -- a stored build's team, carrying the levelling, the gear placement and
    -- above all the aiRules its author wrote (models/build.lua). Bound by position, the same way the
    -- party is, because specFor made those characters' ids the composition the arena was seated from.
    -- Control stays the default for the enemy side, which is what makes their author's gambits the
    -- thing actually driving them: AI.rulesFor reads char.aiRules first.
    local enemyChars = opts.enemyChars
    for i, u in ipairs(battle.arena.enemies) do
        battle.enemyUnits[#battle.enemyUnits + 1] = {
            -- `enemyChars` are handed over already levelled by their author (models/build.lua
            -- normalizes a duel team itself), so they are taken as-is; a blueprint id is grown here.
            char = (enemyChars and enemyChars[i]) or Growth.spawn(u.id, battle.enemyLevel, battle.floorLevel),
            x = u.x, y = u.y,
        }
    end

    -- Built but not OPENED when a deployment phase is coming: the ground, the enemy and the objective are
    -- all real from this moment (so the phase draws the board the player is actually about to fight on),
    -- but no passive has been applied and no battle-opener trait has fired. Combat.openBattle does that
    -- once, in commitDeploy, when the company is standing where the player put them. See models/combat.lua.
    battle.combat = Combat.new(battle.arena, battle.partyUnits, battle.enemyUnits,
        { deferOpen = battle.deployEnabled,
          -- A draft match or a duel has a person on the other side, so the AI plays to win the
          -- objective rather than to be a fight the player can defend against. See AI.spared.
          versus = (opts.draft or opts.session) and true or nil })

    -- The battle purse: the pot the greed (rogue) money kit spends in-fight (fx.spendPurse ->
    -- Combat.spendPurse), and the pot the debug "Add gold" tool funds. EVERY battle gets one now, so a
    -- money ability works -- and can be topped up for testing -- in a campaign fight, a draft, a duel or
    -- a mock battle alike. combat.lua never learns what backs it; it only calls get()/spend()/add()
    -- (models/combat.lua, Combat.purseAvailable). The backing store is chosen by context, in priority:
    --   1. opts.purse -- a caller-supplied wallet. A draft passes one over its DraftRun.gold (see
    --      models/draft_match.lua) so a draft money ability spends real run gold and the debug tool
    --      funds it; that gold is discarded at round end anyway (DraftRun.advanceRound), so spending it
    --      mid-fight costs nothing banked.
    --   2. the campaign bank -- a real campaign fight (no draft, no session) with an active Player.
    --      Closes over Player.active rather than caching a number, so a spend lands on the real bank and
    --      the ability reads the balance live as it draws it down.
    --   3. a transient in-battle pot -- everything else (a duel, a player-less mock battle). Starts
    --      empty (fund it with the debug Add gold tool, or seed it via opts.startingGold) and is
    --      discarded with the fight, so it never touches real or run gold.
    if opts.purse then
        battle.combat.purse = opts.purse
    elseif not opts.draft and not battle.session and Player.active then
        local player = Player.active
        battle.combat.purse = {
            get = function() return player.gold or 0 end,
            spend = function(n) Player.spendGold(player, n) end,
            -- Credit the campaign bank. Only the debug "Add gold" tool reaches this (a fight never gives
            -- the party gold mid-battle); it lets that tool fund a party caster's real pot rather than a
            -- coffer the party never reads. See ui/panels/debug_menu.lua goldPage.
            add = function(n) Player.addGold(player, n) end,
        }
    else
        local bank = opts.startingGold or 0
        battle.combat.purse = {
            get = function() return bank end,
            spend = function(n) bank = math.max(0, bank - (n or 0)) end,
            add = function(n) bank = bank + (n or 0) end,
        }
    end

    -- Which side THIS machine is holding. "party" in every campaign battle -- and in a duel, the
    -- side this player drives, which is the enemy side for whoever joined. Everything else follows
    -- from it: win and loss are spoken from here (Combat.evaluate), the local player commands these
    -- units, and the far side becomes "remote" so nothing here decides anything for them.
    --
    -- Only applied when there is a session. Without one, an enemy is an enemy and the AI runs it.
    battle.combat.playerSide = opts.playerSide or "party"
    if battle.session then
        for _, unit in ipairs(battle.combat.units) do
            unit.control = (unit.side == battle.combat.playerSide) and "player" or "remote"
        end
    end
    -- The player's stash, by reference: Combat.steal appends here when a party thief's own 3x3 grid
    -- has no room, so the item is the player's the moment it's lifted, win or lose.
    battle.combat.stash = opts.stash
    -- One animation controller for the battle, shared into the board and the turn strip so damage
    -- floaters, HP drain, sprite reactions and card jiggle/fade all read the same state.
    battle.fx = CombatFx.new()
    -- Clear any screen effects the last fight left standing -- the defeat grey most of all, so a retry
    -- opens on a full-colour board rather than the grey the loss faded to (ui/screen_fx.lua).
    ScreenFx.reset()
    battle.pendingAdvance = nil
    -- A technique award parked by the last fight must never surface over this one's opening board:
    -- it names a unit from a company that may not even be on this field (see releaseGrowthAward).
    battle.pendingAward = nil
    -- The hamburger starts closed every fight: it is a transient drawer, not a remembered preference,
    -- and a battle that opened over its own tooltip column would be a worse first frame than one that
    -- didn't. See MENU_BUTTON / menuBottom.
    battle.menuOpen = false
    -- Nothing is open over the deployment phase yet. Cleared here rather than trusted to have been
    -- closed, so a fight retried out of the defeat panel cannot inherit the last one's Loadout screen.
    battle.deployLoadout = nil
    -- Auto-battle playback speed carries across fights as a preference (like autoAll itself), so a
    -- player who likes 3x keeps it -- but seed it the first time so battle.update's multiply is safe.
    battle.autoSpeed = battle.autoSpeed or 1
    -- Timed reinforcements (objective.waves): each wave's firing state (count + next tick) rides on the
    -- combat, because the win conditions read it too (Combat.allWavesArrived). Cleared per battle so a
    -- replayed fight starts with every wave still pending; the context beside it is what a wave's
    -- `composition(ctx)` scales itself against. See spawnWaves.
    battle.combat.waveState = {}
    battle.encounterCtx = ctx
    battle.map = BattleMap.new(battle.arena,
        { combat = battle.combat, leftMargin = LEFT_W, rightMargin = PANEL_W,
          tileSize = BOARD_TILE, topMargin = BOARD_TOP })
    battle.map.fx = battle.fx
    -- The board's point-effect controller (impact bursts, spell blooms, bolts in flight) is shared into
    -- the animation controller, which spawns from it as it plays out each blow. See ui/burst_fx.lua.
    battle.fx.bursts = battle.map.bursts
    battle.panel = nil -- built by commitDeploy, once there is a company to draw a turn strip for
    -- The read-only kit card for a foe assayed by the Assayer's Eye (ui/inventory_peek.lua). `peekUnit`
    -- is the foe currently in focus; see updatePeekFocus (kept open while the cursor is over the foe or
    -- the card itself).
    battle.peek = InventoryPeek.new()
    battle.peekUnit = nil
    -- The log toggles into a thin, board-width strip in the bottom gutter, directly under the board.
    -- The deployment phase borrows exactly this rect for the company strip (gutterRect), which is why
    -- the geometry lives in one function rather than being written out twice.
    local g = gutterRect()
    battle.log = CombatLog.new(battle.combat, { x = g.x, y = g.y, w = g.w, h = g.h })

    -- The deployment phase, or straight into the fight for a caller that already decided placement.
    -- Opened here but not INTERACTED with until the opening conversation below is dismissed -- a scene is
    -- a global overlay on a frozen state (main.lua), so it plays over the lit zone and the player chooses
    -- their line with whatever it just told them.
    openDeployPhase(opts)

    -- Last, once the board is fully built: the fight may open with a scene played OVER it. A
    -- conversation is a global overlay on a frozen state (see main.lua), so the lane, the party and
    -- every enemy on it sit there behind the box, and not a single turn resolves until the player
    -- dismisses it themselves. That is the whole reason it is fielded here rather than as a beat
    -- before the battle: said on a black screen it would be backstory, and said over the board it is
    -- the fight being pointed at.
    -- Staging is asked for HERE rather than declared by the scene, because it is a fact about the
    -- screen the scene lands on and not about the scene -- and the two kinds of battle want opposite
    -- things.
    --
    -- A LESSON's opening shares the screen with the teaching UI: the mentor's panel and the coach
    -- bubble are about to speak from the same board, so the scene goes in the free gutter under the
    -- board -- the same rect ui/tutorial_prompt.lua occupies, with the same insets -- and takes the
    -- compact `overScene` staging so the lesson's speech and the scene's speech land in exactly the
    -- same place rather than an inch apart.
    --
    -- Every OTHER battle opens with the ordinary conversation UI: full-screen staging, busts, title,
    -- the box across the bottom, exactly as a scene reads anywhere else in the game. Outside the
    -- tutorial there is no coaching for it to line up with, and borrowing the lesson's gutter panel
    -- made a story beat look like an instruction. The board still sits frozen behind it (a
    -- conversation is a global overlay, see main.lua), so the fight is still the thing being pointed
    -- at -- it is just pointed at in the game's own voice.
    local opening = openingConversation(opts)
    if opening then
        -- Never fold a queued party-join banner onto an opening, whichever staging it takes. A
        -- "[<name> has joined your Party]" line is a roster beat and belongs in a scripted scene
        -- somebody wrote it into -- the oath in "Ashes", Saber's turn in "The Gatekeeper" -- not
        -- tacked onto the last words before a fight starts. Holding it lets the join land in the next
        -- authored scene instead: Rowan, recruited to fight the village battle, is announced in
        -- "Ashes" after it (models/conversation.lua's drainJoins).
        local stage = { deferJoins = true }
        if battle.tutorial then
            local boardBottom = battle.map.originY + battle.arena.rows * battle.map.size
            local x = LEFT_W + GUTTER_PAD
            local y = boardBottom + GUTTER_GAP
            stage.overScene = true
            stage.box = {
                x = x, y = y,
                w = Scale.WIDTH - PANEL_W - GUTTER_PAD - x,
                h = Scale.HEIGHT - GUTTER_BOTTOM - y,
            }
        end
        Conversation.play(opening, nil, nil, stage)
    end
end

-- A red edge-vignette that deepens as the player's most-wounded standing unit nears death, and clears
-- the moment nobody is in the red. Meaning rather than motion, so it holds under reduced effects; it
-- reads the player's OWN side only, since a bloodied enemy is good news. A slow pulse keeps it alive
-- rather than a flat wash. See ui/screen_fx.lua. Skipped once the fight is decided (the defeat grey or
-- the victory panel owns the frame then).
--
-- OFF unless the player asks for it (`danger_vignette`, models/settings.lua): a red wash closing over
-- the board is the loudest thing on the screen and the HP bars already carry the warning. The gate
-- lives here rather than in ScreenFx.vignette because the verb is general -- this is the one caller
-- that means "you are dying", and only that meaning is optional. Clearing on the way out matters: a
-- player who flicks the toggle off mid-fight must not be left with the last edge frozen on screen.
local function updateDangerVignette()
    if battle.over or battle.summary then return end
    local worst = 1
    for _, u in ipairs(battle.combat.units) do
        if u.alive and u.side == battle.combat.playerSide then
            local hp = u.char.stats.health
            if hp and hp.max > 0 then worst = math.min(worst, hp.current / hp.max) end
        end
    end
    if worst >= 0.30 or Settings.get("danger_vignette") ~= true then
        ScreenFx.vignette(0)
    else
        -- 0 at the 30% threshold up to a firm edge as it approaches 0, with a slow breath over it.
        local depth = (0.30 - worst) / 0.30
        local pulse = 0.85 + 0.15 * math.sin((battle.map.time or 0) * 3)
        ScreenFx.vignette(depth * 0.55 * pulse, { 0.6, 0.05, 0.05 })
    end
end

-- Bank what the action just fed onto the reward the board will show, and clear the model's one-shot so
-- it is shown exactly once. Drained HERE, in update, rather than at each of the five Combat.useItem call
-- sites: an action can be committed by a click, by the keyboard slot path, by the steered-route path,
-- or by a queued command (auto-battle), and every one of them would otherwise need its own copy of
-- this. The model banks synchronously inside useItem, so the award is here the same frame.
--
-- ONE one-shot: `techniqueAward`, "+2 Ninja" / "+2 Knight" -- what this action banked on the ledger
-- that both bills the Forge and apportions the next level-up (Combat.awardTechnique). There used to be
-- a second, quieter floater for the class vote, because technique only spoke for discipline stock --
-- locked content on 233 of 638 items -- so an opening hand of plain gear floated nothing at all. Every
-- house banks the same currency now, so there is one thing to say and one way to say it.
--
-- It is only PARKED here, not shown: see releaseGrowthAward.
local function bankGrowthAward()
    local combat = battle.combat
    if not combat then return end

    local award = combat.techniqueAward
    if not award then return end
    combat.techniqueAward = nil
    -- The key is a class id OR a discipline id, so resolve it the way every other surface does:
    -- "plague_knight" is "Plague Knight", which title-casing alone would render "Plague_knight".
    local key = award.discipline
    local name = Discipline.displayName(key) or (key:gsub("^%l", string.upper))
    battle.pendingAward = { unit = award.unit, text = "+" .. award.amount .. " " .. name }
end

-- Float a parked award -- but only once the action that earned it has finished being an action.
--
-- It is a damage number in every respect but timing: the same channel (CombatFx:floatText), the same
-- drift and fade, amber rather than the damage reds or the heal green because that is the accent this
-- UI reserves for what is live and earned. It lands on the CASTER while damage lands on the TARGET.
--
-- What changed is WHEN. It used to go out the instant it was banked -- one more piece of amber text
-- thrown up in the same frame as the reds, the burst, the shake and the HP drain -- and it was there
-- without ever being seen, competing with the loudest half-second on the screen and losing. So it
-- waits, the way FFT and Fire Emblem make the EXP/JP readout wait: the blow lands, the numbers float
-- off, the bars stop moving, and only THEN does the ledger speak, over a board with nothing else on it.
-- Nothing about the number is louder; it simply gets the screen to itself.
--
-- The gate is the whole animation, not a timer: every reaction settled (fx:busy), every bar arrived
-- (hpSettled), every number gone (floatersDone), nobody mid-walk, and the impact beat elapsed. Those
-- are the same conditions the hand-off itself waits on -- which is the point. The award floats into the
-- gap between them and the turn moving, and because it is a floater the hand-off then waits on IT
-- (floatersDone again), so the turn never restages over a number still on the board.
local function releaseGrowthAward()
    local award = battle.pendingAward
    if not award then return end
    -- The fight is decided: the summary panel owns the frame now, and it reports the whole fight's
    -- ledger anyway. Drop it rather than float a number under a victory banner.
    if battle.over or battle.summary then battle.pendingAward = nil; return end
    if walking() then return end
    if battle.pendingAdvance and battle.pendingAdvance.hold > 0 then return end
    if battle.fx:busy() or not battle.fx:hpSettled() or not battle.fx:floatersDone() then return end
    battle.pendingAward = nil
    battle.fx:floatText(award.unit, award.text, Theme.accentAmber)
end

function battle.update(dt)
    -- The settings overlay freezes the fight: only the menu ticks, the board holds exactly where it
    -- was, and closing the overlay resumes from there. Nothing below runs while it is up.
    if battle.settingsMenu then
        battle.settingsMenu:update(dt)
        return
    end

    -- The deployment phase holds the fight before it starts: no turn is running, no unit is acting, and
    -- there is nothing to advance. Only the board ticks, so its cursor and hover still feel live while
    -- the player drags their company onto it.
    if battle.deploy then
        -- The Loadout screen is modal over the phase (openDeployLoadout): while it is up the board
        -- behind it is not being pointed at, so only the panel ticks.
        if battle.deployLoadout then battle.deployLoadout:update(dt) else battle.map:update(dt) end
        return
    end

    bankGrowthAward()
    releaseGrowthAward()
    -- NOTE the wind-up chooser is deliberately NOT a freeze: it is a small slider over the aimed tile,
    -- and the board + turn-order strip behind it are its preview. The view has to keep refreshing so
    -- that sliding the depth (which writes battle.windup) slides the channel's resolve slot along the
    -- strip live. Player input is still walled off -- every input handler routes to the chooser first --
    -- so nothing on the board can be touched while it is up; only the passive preview keeps ticking.

    -- The chess clock runs on REAL time (this dt, before the gameplay scaling below), and only for the
    -- LOCAL player while it is their live decision -- the side to move, actually in hand (not an
    -- auto-battling or remote unit). It pauses during the opponent's turn and while a summary is up. Run
    -- it out and the fight is conceded, exactly as a forfeit would. (A live duel's remote clock arrives
    -- as a command; v1 vs a bot only the human is on the clock, which is what this guards for.)
    if battle.chessClock and not battle.over and not battle.summary and battle.current then
        local side = battle.current.side
        if side == (battle.combat.playerSide or "party") and Combat.isPlayerControlled(battle.current) then
            battle.chessClock[side] = battle.chessClock[side] - dt
            if battle.chessClock[side] <= 0 then
                battle.chessClock[side] = 0
                Combat.logEvent(battle.combat, "system", "Out of time.")
                lose()
            end
        end
    end

    -- Hit-stop: a killing blow freezes the SIMULATION for a beat (ui/screen_fx.lua sets the scale to 0),
    -- so the whole board holds while the death registers, then resumes. Only the gameplay clock is
    -- scaled -- ScreenFx's own shake/flash/freeze decays advance on real dt back in main.lua, so the
    -- freeze ends on its own and its shake still plays. A summary overlay ignores it (the fight is over).
    if not battle.summary then dt = dt * ScreenFx.timeScale() end

    -- Whole-side auto-battle can run fast-forwarded: the speed cycler scales the ENTIRE gameplay clock
    -- (think-pauses, walks, hit animations, fx), so 2x/3x is a true fast-forward of the fight, not just
    -- a shorter AI delay. Only while autoAll -- the player's own turns always play at 1x. Multiplied
    -- after the hit-stop scale so a killing blow still freezes (0 * speed == 0).
    if battle.autoAll and not battle.summary then dt = dt * (battle.autoSpeed or 1) end

    -- The victory/defeat overlay animates over the frozen board (map/fx still tick below so the frame
    -- keeps breathing behind it).
    if battle.summary then battle.summary:update(dt) end

    -- Drain the duel before anything else, so a turn the other player took is applied at the top of
    -- the frame rather than a frame late. It hands remote commands over through onCommand, and it is
    -- gated behind the same `busy()` the local player's input is: a remote turn must not land in the
    -- middle of a walk that is still playing back, or two turns would animate over each other.
    if battle.session and not busy() then battle.session:update() end

    -- Debug autopilot: wait out this side's turns so a two-window duel runs with nobody driving.
    if battle.autoPilot and not battle.over and not busy() and battle.current
        and Combat.isPlayerControlled(battle.current) then
        battle.autoPilotTimer = battle.autoPilotTimer + dt
        if battle.autoPilotTimer >= 0.4 then
            battle.autoPilotTimer = 0
            waitTurn()
        end
    end

    battle.map:update(dt)
    battle.fx:update(dt)
    updateDangerVignette()
    -- Age out a refusal notice. Independent of the turn/animation clock: it is UI chrome about a
    -- click that never became an action, so nothing on the board waits on it.
    if battle.notice then
        battle.notice.life = battle.notice.life - dt
        if battle.notice.life <= 0 then battle.notice = nil end
    end
    -- Same for the tutorial's correction, which rides in the mentor's panel instead of the banner.
    if battle.tutorialNudge then
        battle.tutorialNudge.life = battle.tutorialNudge.life - dt
        if battle.tutorialNudge.life <= 0 then battle.tutorialNudge = nil end
    end
    if walking() then
        updateWalk(dt) -- a walk holds the AI clock: whoever is on their feet finishes first
    elseif battle.pendingAdvance then
        -- An action just resolved: hold until the reaction beat elapses AND the sprite reactions finish
        -- AND the HP bars stop draining AND the damage numbers have floated away, then hand off (or fire
        -- win/loss). Holding the WHOLE damage animation keeps it from bleeding into the turn-order
        -- restage, so the hit reads fully and THEN the turn moves as its own beat. The technique award
        -- rides the same test twice: releaseGrowthAward (top of this update) floats it the frame these
        -- clear, which re-arms floatersDone -- so the reward gets its own beat between the two, and the
        -- restage still waits for it. Checked before the channel/AI branches so the just-acted unit can't
        -- take a second action while its hit still reads.
        battle.pendingAdvance.hold = battle.pendingAdvance.hold - dt
        if battle.pendingAdvance.hold <= 0 and not battle.fx:busy()
            and battle.fx:hpSettled() and battle.fx:floatersDone() then
            resolveAdvance()
        end
    elseif battle.benchChooser or battle.reinforcePick then
        -- The fight is waiting on the player: a card is up asking who comes on, or the board is asking
        -- where they land. The two branches BELOW this one are the only things that move a battle
        -- forward without input -- a channel detonating and the AI's think-pause -- and either resolving
        -- behind the card would play a turn the player never saw. That was survivable while the chooser
        -- was something they went to the drawer to open; now that a broken line raises it on its own,
        -- and the blow that broke it was usually an enemy's, it is the common path.
        --
        -- A branch that does nothing rather than an early return: the board, fx and notices above still
        -- tick, so the frame keeps breathing behind the card. This holds the simulation, not the screen.
        -- (The mandatory last-stand prompt sits under the same guard, and wants it for the same reason.)
    elseif not battle.over and battle.current and battle.current.channel then
        -- The current unit is mid-channel: once the timeline has finished reshuffling into the new
        -- order, count the think-pause down, then detonate the spell and hand off. Checked before the
        -- AI branch so a player's own channel resolves too (a player channeler is player-controlled,
        -- so the AI branch below would skip it).
        if battle.panel:cardsSettled() then
            battle.resolveTimer = (battle.resolveTimer or 0) - dt
            if battle.resolveTimer <= 0 then
                Combat.resolveChannel(battle.combat, battle.current)
                advanceTurn()
            end
        end
    -- `control ~= "remote"`: a unit the other player drives has no think-pause to run down, because
    -- nothing here is going to think for it. Its turn arrives as a command. executeEnemyAction
    -- refuses one too, so this is belt and braces -- but a countdown that never fires anything is
    -- the kind of thing that reads as a hang, and the second guard costs a comparison.
    elseif not battle.over and battle.current and battle.current.control ~= "remote"
        and (not Combat.isPlayerControlled(battle.current) or battle.autoPending == battle.current) then
        -- Hold the enemy's think-pause until the turn-strip cards have settled, so a fast chain of
        -- AI turns never resolves out from under the card animation (the card would otherwise pop to
        -- full size mid-slide). The player's own turn isn't gated -- input is already held elsewhere.
        -- An auto-battling player unit rides the same clock, so it reads on screen exactly like any
        -- other unit taking its turn.
        if battle.panel:cardsSettled() then
            battle.aiTimer = (battle.aiTimer or 0) - dt
            if battle.aiTimer <= 0 then executeEnemyAction() end
        end
    end
    refreshView()
    -- After refreshView so the strip sees THIS turn's order: the new acting card snaps into the
    -- framed slot (no tall card left mid-pile) and the rest slide from where they were.
    battle.panel:update(dt)
end

-- Resolve a tutorial step's anchor -- the thing its coaching is pointing at -- to a rect in the
-- logical 1280x720 space, plus the region the bubble is allowed to live in. Three kinds, because the
-- lesson points at three different sorts of thing:
--
--   cell -- a board tile (the one to step onto)
--   unit -- a living character by id, nearest the acting unit when several answer to it (three demon
--           grunts share an id; the one being taught about is the one within reach)
--   item -- a slot in the combat panel's 3x3 grid, found by item id in the acting unit's inventory
--
-- Returns nil when the anchor names something that isn't on screen right now (an item the unit is
-- not carrying, a character already dead), so the bubble simply doesn't draw rather than pointing
-- at empty space.
local function coachTarget(anchor)
    if not anchor then return nil end
    local map = battle.map
    if anchor.kind == "cell" then
        local px, py = map:cellToPixel(anchor.x, anchor.y)
        return { x = px, y = py, w = map.size, h = map.size }, "board"
    elseif anchor.kind == "unit" then
        local best, bestDist
        for _, u in ipairs(battle.combat.units) do
            if u.alive and u.char.id == anchor.char then
                local d = battle.current
                    and (math.abs(u.x - battle.current.x) + math.abs(u.y - battle.current.y)) or 0
                if not bestDist or d < bestDist then best, bestDist = u, d end
            end
        end
        if not best then return nil end
        local px, py = map:cellToPixel(best.x, best.y)
        return { x = px, y = py, w = map.size, h = map.size }, "board"
    elseif anchor.kind == "item" then
        local current = battle.current
        if not (current and Combat.isPlayerControlled(current)) then return nil end
        for slot = 1, Character.MAX_INVENTORY do
            local item = current.char.inventory[slot]
            if item and item.id == anchor.id then
                local sx, sy, sw, sh = battle.panel:slotRect(slot)
                return { x = sx, y = sy, w = sw, h = sh }, "panel"
            end
        end
    elseif anchor.kind == "turn" then
        -- A card in the turn order. The one anchor that points at the INTERFACE rather than at the
        -- battlefield, and it earns that: the initiative timeline is the only system in the game a
        -- player cannot learn by looking at the board, so the lesson about it has to point at the
        -- strip itself -- at the avatar's own card for the resource bars it carries, and at a
        -- stunned foe's for the slot it just slid down to.
        for _, u in ipairs(battle.combat.units) do
            if u.alive and u.char.id == anchor.char then
                local cx, cy, cw, ch = battle.panel:cardRect(u)
                if cx then return { x = cx, y = cy, w = cw, h = ch }, "panel" end
            end
        end
    end
    return nil
end

-- The interface half of the tutorial: a bubble pinned to the thing the current step is about. Kept
-- separate from the mentor's panel on purpose -- see data/tutorials/village.lua for why the fiction
-- and the instruction are not allowed to share a mouth.
function battle.drawCoach()
    if not lessonAddressesPlayer() then return end
    local coach = Tutorial.coach(battle.tutorial)
    if not coach then return end
    local rect, region = coachTarget(coach.anchor)
    if not rect then return end
    -- A bubble over the board is kept clear of both columns; one over the panel may use the panel's
    -- full width, since that is the only place it can go.
    -- A bubble over the board is kept clear of both columns and prefers a flank, so it doesn't park
    -- on top of the lane the lesson is about; one over the panel has no room beside a slot in a
    -- 320px column, so it goes above.
    local bounds = region == "panel"
        and { x = Scale.WIDTH - PANEL_W + 4, y = 4, w = PANEL_W - 8, h = Scale.HEIGHT - 8 }
        or { x = LEFT_W + 8, y = BOARD_TOP - 4,
             w = Scale.WIDTH - PANEL_W - LEFT_W - 16, h = Scale.HEIGHT - BOARD_TOP }
    -- Every living body on the board, so the bubble can settle where it hides the fewest of them.
    -- Only for a board anchor: over the panel there is nowhere else to go anyway.
    local avoid
    if region == "board" then
        avoid = {}
        for _, u in ipairs(battle.combat.units) do
            if u.alive then
                local ux, uy = battle.map:cellToPixel(u.x, u.y)
                avoid[#avoid + 1] = { x = ux, y = uy, w = battle.map.size, h = battle.map.size }
            end
        end
    end
    CoachBubble.draw(coach.text, rect, {
        bounds = bounds,
        prefer = region == "panel" and "above" or "side",
        avoid = avoid,
        key = coach.key, -- the button to press, drawn as a cap rather than written into the sentence
    })
end

-- Decide which assayed foe (if any) the inventory-peek card should show this frame. The card stays
-- open while the cursor rests on the foe OR on the card itself, so the player can travel from one to
-- the other to hover its items; hovering some OTHER unit dismisses it, while hovering empty ground
-- (or the card) leaves it be. A foe that has fallen drops focus.
function battle.updatePeekFocus()
    local mx, my = battle.mouseX, battle.mouseY
    if battle.peekUnit and not battle.peekUnit.alive then battle.peekUnit = nil end
    if not mx then return end
    -- Over the card already: keep it, so its own slots stay hoverable.
    if battle.peekUnit and battle.peek:contains(mx, my) then return end
    -- The unit under the cursor, from either surface: the timeline strip, else the board tile.
    local hovered = battle.panel:unitAt(mx, my)
    if not hovered then
        local cx, cy = battle.map:cellAt(mx, my)
        if cx then hovered = Combat.unitAt(battle.combat, cx, cy) end
    end
    if hovered then
        if hovered.side ~= "party" and hovered.alive and Combat.inventoryRevealed(hovered) then
            battle.peekUnit = hovered
        else
            battle.peekUnit = nil -- a different unit (or an un-assayed foe) dismisses the card
        end
    end
    -- hovered == nil (empty ground, a side column): leave peekUnit as it was -- the card is sticky.
end

-- Draw the inventory-peek card for the focused foe, anchored to its board token and clamped to the
-- board region (clear of both side columns). Drawn over the board but under the tooltip pass, so a
-- hovered slot's ItemTooltip lands on top.
function battle.drawPeek()
    local u = battle.peekUnit
    if not (u and u.alive) then return end
    local m = battle.map
    local ax = m.originX + (u.x - 0.5) * m.size
    local ay = m.originY + (u.y - 0.5) * m.size
    battle.peek:draw(u, ax, ay, LEFT_W, Scale.WIDTH - PANEL_W)
end

function battle.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    -- Before the bell: the board with the deploy zone lit and the company in the gutter. The SCREEN is
    -- the same screen -- left column, hamburger, the encounter's name and objective over the board --
    -- because the deployment phase is a beat of this battle and not a lobby in front of it, and the
    -- boxes the phase docks into that column (its tile/occupant hover) need the column drawn under
    -- them. What is left out is the fight's own furniture, which has nothing to report yet: no turn
    -- strip (nobody is acting), no combat log (nothing has happened), and a drawer holding only what
    -- means anything before the bell (drawDeployMenu).
    if battle.deploy then
        battle.drawLeftColumn()
        battle.map:draw()
        battle.drawEncounterLines(LEFT_W, Scale.WIDTH - LEFT_W - PANEL_W)
        battle.drawDeployMenu()
        battle.deploy:draw({ x = LEFT_W, w = Scale.WIDTH - LEFT_W - PANEL_W, dockTop = menuBottom() })
        -- The Loadout screen, over the phase and under the settings overlay: gear is a decision about
        -- this fight, so it is taken on this screen rather than a leg of overworld ago.
        if battle.deployLoadout then battle.deployLoadout:draw() end
        -- Opened from that drawer, and modal over the phase exactly as it is over the fight.
        if battle.settingsMenu then battle.drawSettingsOverlay() end
        love.graphics.setColor(1, 1, 1)
        return
    end

    battle.updatePeekFocus()
    battle.drawLeftColumn()
    battle.map:draw()
    -- Keyboard / pad aiming: the OS pointer is idle, so the context-cursor glyph (sword / wand /
    -- heal / boots / reticle -- whatever a confirm would do) is drawn CENTRED on the aimed tile, so
    -- the same intent the mouse reads under its pointer rides the board cursor. Only when the player
    -- controls the turn and something actionable is aimed -- otherwise the tile cursor stands alone.
    if not InputMode.isMouse() and not battle.over and not busy()
        and battle.current and Combat.isPlayerControlled(battle.current) then
        local kind = battle.boardCursorKind()
        if kind then
            local tx, ty = battle.map:cellToPixel(battle.map.cursor.x, battle.map.cursor.y)
            local half = battle.map.size / 2
            Cursor.draw(kind, tx + half, ty + half)
        end
    end
    battle.fx:drawFloaters(battle.map) -- damage / heal numbers, above the board
    battle.drawPeek() -- the assayed-foe kit card, over the board and under the tooltip pass
    battle.panel:draw()
    battle.drawHud()
    battle.log:draw()
    -- The tutorial's instruction panel shares the gutter under the board with the combat log, and is
    -- drawn after it: a lesson the player is mid-way through outranks a log they can toggle back.
    -- Same rule as the coach bubble: the mentor's direction is a direction, so it waits for a turn
    -- the player can follow it in. She goes quiet while she and the demons take theirs.
    if lessonAddressesPlayer() then
        local prompt = Tutorial.narration(battle.tutorial)
        -- A live correction displaces the mentor's standing line until it ages out. She scolds; the
        -- coach bubble below goes on saying which thing to click.
        if prompt and battle.tutorialNudge then
            prompt = { speaker = prompt.speaker, text = battle.tutorialNudge.text, alert = true }
        end
        TutorialPrompt.draw(battle.combat, prompt, {
            leftMargin = LEFT_W, rightMargin = PANEL_W,
            boardBottom = battle.map.originY + battle.arena.rows * battle.map.size,
        })
        battle.drawCoach()
    end
    battle.drawNotice()

    -- Status tooltip, drawn last so it sits above both the board and the panel. The panel is on
    -- top where the two overlap, so it wins the hit-test; its tooltip may extend to the screen
    -- edge, while a board tooltip is kept clear of the panel (rightMargin).
    local mx, my = battle.mouseX, battle.mouseY
    -- When the cursor is over the open combat log, that panel owns the hover: it draws its own
    -- item/status/breakdown tooltip during its draw pass, so the board's tile tooltip must not also
    -- fire here and stack on top of it.
    if battle.windupChooser or battle.spendChooser then
        -- The wind-up / spend modal owns the frame: no board / panel tooltip bleeds behind it.
    elseif not InputMode.isMouse() and battle.keySlot then
        -- Keyboard / pad play: the mouse isn't driving, so nothing is hovered -- float the selected slot's
        -- tooltip anchored to the slot itself, so a numpad/pad press reads the item the way a hover would.
        local cur = battle.current
        local item = cur and Combat.isPlayerControlled(cur) and cur.char.inventory[battle.keySlot]
        if item then
            local sx, sy, sw, sh = battle.panel:slotRect(battle.keySlot)
            ItemTooltip.draw(item, sx + sw / 2, sy + sh / 2, Scale.WIDTH, cur)
        end
    elseif mx and InputMode.isMouse() and not battle.log:contains(mx, my) then
        -- An assayed foe's kit card owns the hover while the cursor is over it: a slot shows that item's
        -- full tooltip (priced against nobody -- it isn't the player's to cast), and the rest of the card
        -- swallows the tile tooltip so the board underneath it doesn't bleed through.
        local peekItem = battle.peekUnit and battle.peek:itemAt(mx, my)
        local overPeek = battle.peekUnit and battle.peek:contains(mx, my)
        local st = not overPeek and battle.panel:statusAt(mx, my)
        local boardSt = not overPeek and not st and battle.map:statusAt(mx, my)
        local item = not overPeek and not st and not boardSt and battle.panel:itemAt(mx, my)
        if peekItem then
            ItemTooltip.draw(peekItem, mx, my, Scale.WIDTH - PANEL_W, nil)
        elseif overPeek then
            -- over the card but not a slot: no other tooltip
        elseif st then
            StatusTooltip.draw(st, mx, my, Scale.WIDTH)
        elseif boardSt then
            StatusTooltip.draw(boardSt, mx, my, Scale.WIDTH - PANEL_W)
        elseif item then
            -- A panel item slot under the cursor shows its details tooltip. Pass the acting unit
            -- so the tooltip can flag an ability it can't currently afford.
            ItemTooltip.draw(item, mx, my, Scale.WIDTH, battle.current)
        else
            -- A turn-order strip entry shows that unit's stats tooltip; otherwise a battlefield
            -- tile under the cursor shows its terrain + occupant tooltip.
            local stripUnit = battle.panel:unitAt(mx, my)
            if stripUnit and stripUnit.alive then
                battle.drawUnitTooltip(stripUnit, mx, my, Scale.WIDTH)
            else
                battle.drawTileTooltip(mx, my)
            end
        end
    end

    -- The victory/defeat overlay owns the frame once the fight is decided: drawn last, over the
    -- frozen board, HUD and every tooltip.
    if battle.summary then battle.summary:draw() end
    -- The log-review modal sits above even the summary panel (drawn last of all).
    if battle.logReview then battle.drawLogReview() end
    -- The settings overlay sits above everything, over the frozen fight.
    if battle.settingsMenu then battle.drawSettingsOverlay() end
    -- The wind-up chooser, when a chargeable swing is being sized, sits above the frozen board too.
    if battle.windupChooser then battle.windupChooser:draw() end
    -- The spend chooser is the same kind of modal for a purchasable blow (The Gilded Wound).
    if battle.spendChooser then battle.spendChooser:draw() end
    -- The bench chooser, while a rotation or a reinforcement is picking who comes on.
    if battle.benchChooser then battle.benchChooser:draw() end
    -- The right-click debug menu (debug builds only) sits on top of every board overlay.
    if battle.debugMenu then battle.debugMenu:draw() end
    -- While the debug "Move to tile" picker is armed, a banner tells the player the next click lands it.
    if Debug.enabled and battle.debugPickTile then
        local f = Theme.body(16)
        love.graphics.setFont(f)
        local msg = "Debug: click a tile to move  (right-click / Esc cancels)"
        local w = f:getWidth(msg) + 20
        local bx = math.floor((Scale.WIDTH - w) / 2)
        Theme.plate(bx, 12, w, 30, Theme.R)
        Theme.set(Theme.accentAmber)
        love.graphics.print(msg, bx + 10, 12 + (30 - f:getHeight()) / 2)
        love.graphics.setColor(1, 1, 1)
    end
end

-- The in-battle settings modal: a dim scrim over the frozen fight, a titled panel, the shared
-- SettingsMenu list, the highlighted option's description, a control hint, and an X to close.
function battle.drawSettingsOverlay()
    local p = battle.settings
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, Theme.R, Theme.R)

    love.graphics.setFont(overlayTitleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Settings", p.x, p.y + 16, p.w, "center")

    battle.settingsMenu:draw()

    -- The highlighted row's description, in the gutter below the list.
    local item = battle.settingsMenu:selectedItem()
    if item and item.description then
        love.graphics.setFont(overlayBodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf(item.description, p.x + 30, p.y + p.h - 66, p.w - 60, "left")
    end

    love.graphics.setFont(overlayBodyFont)
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "D-pad: move    A / Left / Right: change    B: close"
        or "Arrows: move    Enter / Left / Right or click: change    Esc: close"
    love.graphics.printf(hint, p.x, p.y + p.h - 28, p.w, "center")

    battle.settingsClose:draw()
    love.graphics.setColor(1, 1, 1)
end

-- Full-height, scrollable read of the fight's combat log, opened from the summary panel's "Review
-- Combat Log" button. A dim scrim over the panel, a titled frame, the log inside it, and an X back.
function battle.drawLogReview()
    local r = battle.logReview
    if not r then return end
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Combat Log", r.x, r.y + 12, r.w, "center")
    r.log:draw()
    r.close:draw()
    love.graphics.setColor(1, 1, 1)
end

-- The refusal notice: why the last activation was turned down (see notify). A red-rimmed banner
-- centred low over the board -- under the units, clear of the HUD text up top and of both side
-- columns -- that fades out over its final half-second. Nothing to click: it is a message, not a
-- prompt, so it never takes input away from the turn underneath it.
function battle.drawNotice()
    local notice = battle.notice
    if not notice then return end
    local alpha = math.min(1, notice.life / 0.5) -- hold full, then fade over the last half-second
    local boardX = LEFT_W
    local boardW = Scale.WIDTH - LEFT_W - PANEL_W

    love.graphics.setFont(hudFont)
    local w = math.min(boardW - 40, hudFont:getWidth(notice.text) + 32)
    local h = 34
    local x = boardX + (boardW - w) / 2
    local y = Scale.HEIGHT - 96

    love.graphics.setColor(0.20, 0.08, 0.10, 0.92 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.85, 0.35, 0.35, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.88, 0.88, alpha)
    love.graphics.printf(notice.text, x, y + h / 2 - 8, w, "center")
    love.graphics.setColor(1, 1, 1)
end

-- Terrain + occupant tooltips for the battlefield tile under (mx, my). No-op when the mouse is off
-- the board. Docked into the left column as SEPARATE stacked boxes so the terrain reads on its own,
-- distinct from whatever stands on it: the terrain box sits at the bottom, the occupant (a unit's
-- side + pools + stats, or a revealed trap's owner + HP) in its own box above it, and the action
-- preview above that. All span the column's full width. Kept clear of the combat panel (maxRight).
function battle.drawTileTooltip(mx, my)
    local cx, cy = battle.map:cellAt(mx, my)
    if not cx then return end
    local cell = battle.arena.tiles[cy] and battle.arena.tiles[cy][cx]
    if not cell then return end
    local unit = Combat.unitAt(battle.combat, cx, cy)
    -- Combat.unitAt reports only the LIVING; a fallen body still lies on its tile and has no less to
    -- say. When no living unit stands here, read the two fallen layers directly so a hover over a
    -- downed enemy still opens its readout: an incapacitated body inside its rescue window (with the
    -- Downed clock ticking on it), or one that has gone cold to a corpse. Incapacitated takes
    -- precedence -- it is the body still worth acting on.
    local body = not unit and (Combat.downedAt(battle.combat, cx, cy)
        or Combat.corpseAt(battle.combat, cx, cy))
    local trap = battle.trapCells and battle.trapCells[cx .. "," .. cy]
    local wall = battle.wallCells and battle.wallCells[cx .. "," .. cy]
    local prop = battle.propCells and battle.propCells[cx .. "," .. cy]
    local reinforce = battle.reinforceCells and battle.reinforceCells[cx .. "," .. cy]
    -- Whatever a click here would do (attack / move / place a trap / strike a trap or a barrel) is
    -- named by a companion panel on top, and its damage/heal is previewed on the occupant's resource
    -- bars (a unit's HP for a strike/heal, or a trap's or prop's HP for a strike on one).
    local action = actionPreviewFor(cx, cy)
    local preview
    if action then
        if action.kind == "strikeTrap" then
            preview = { damage = action.trapDamage, lethal = action.trapLethal }
        else
            preview = action.entry
        end
    end

    local maxRight = Scale.WIDTH - PANEL_W
    local W = LEFT_W - 32 -- full column width (16px margins each side)
    -- The stack's ceiling follows the hamburger menu: nearly the whole column while it is closed,
    -- pushed down to clear the entries while it is open.
    local dockTop, gap, exGap = menuBottom(), 8, 4

    -- Marked objective ground (the amber/green wash) rides on the TERRAIN info rather than in the
    -- occupant box, for two reasons: the terrain box never yields to a crowded column, and the read
    -- matters most on a tile that already has a body on it -- standing on the node is not holding it.
    -- WATCHED GROUND: what an enemy's Overwatch stance adds to the cost of entering this tile, for the
    -- unit whose turn it is (Combat.watchTax -- it is 0 for everybody when nobody holds the stance,
    -- which is nearly always). It rides on the terrain box because that is where a tile's price is
    -- already read, and because the tax IS terrain as far as the Dijkstra is concerned. Without this
    -- the only sign of the mechanic is a move overlay that quietly reaches less far than expected.
    local actor = battle.current
    local watched = actor and Combat.watchTax(battle.combat, actor, cx, cy) or 0
    local terrainInfo = { cell = cell, bonus = Combat.fieldBonus(battle.combat, cx, cy),
                          hazards = Hazard.allAt(battle.combat, cx, cy),
                          watched = watched > 0 and watched or nil,
                          objective = Combat.objectiveTileInfo(battle.combat, cx, cy),
                          -- Rally ground rides here for the same reason the objective does: the terrain
                          -- box never yields, and the read matters MOST on a tile with one of your own
                          -- bodies already on it -- that is the moment falling back is a live option.
                          rally = Combat.rallyTileInfo(battle.combat, cx, cy) }
    local objInfo
    -- Same precedence actionPreviewFor picks a strike target with (trap, then wall, then prop), so the
    -- box that opens describes the very thing a click would hit.
    if unit and unit.char then objInfo = { unit = unit, preview = preview }
    elseif body and body.char then objInfo = { unit = body, preview = preview }
    elseif trap then objInfo = { trap = trap, preview = preview }
    elseif wall then objInfo = { wall = wall, preview = preview }
    elseif prop then objInfo = { prop = prop, preview = preview }
    -- Lowest precedence: a bare landing tile (nobody standing on it yet) reads as the incoming muster.
    -- A unit already on the tile wins the box -- it has turned the wave back, and its own readout is the
    -- more useful thing to show.
    elseif reinforce then objInfo = { reinforce = reinforce } end

    -- The EXCHANGE, in resolution order (bottom-up, so the list reads last-beat-first): the counters
    -- that answer after the blow, then the blow, then any reflex that answers BEFORE it (Keen Senses).
    -- Stacked upward, reading the column downward reads the beats in the order they play out. Each is
    -- its own box: an answer is a second action in the trade, not a footnote on yours.
    local exchange = {}
    if action then
        local before, after = {}, {}
        for _, c in ipairs(action.counters or {}) do
            if c.first then before[#before + 1] = c else after[#after + 1] = c end
        end
        for i = #after, 1, -1 do exchange[#exchange + 1] = ActionPreview.counterAction(after[i], action) end
        exchange[#exchange + 1] = action
        for i = #before, 1, -1 do exchange[#exchange + 1] = ActionPreview.counterAction(before[i], action) end
    end

    -- The column is a fixed height and the content isn't: a wordy terrain box, a long status list and
    -- a two-reflex exchange together overrun it, and boxes clamped at dockTop would then draw over
    -- each other. So measure first and let a box yield -- but never the terrain. The board draws the
    -- occupant twice over (its token, its HP bar, its status badges) and the tile it stands on not at
    -- all beyond a flat colour, so terrain is the one thing here that has no second reading anywhere
    -- on screen. It always draws; the OCCUPANT is the valve, since losing it costs the player only a
    -- detail view of something already in front of them.
    local budget = Scale.HEIGHT - 8 - dockTop
    for _, a in ipairs(exchange) do budget = budget - ActionPreview.measure(a) - exGap end
    local objH = objInfo and (TileTooltip.measure(objInfo, W) + gap) or 0
    local terrainH = TileTooltip.measure(terrainInfo, W) + gap
    local showObj = objInfo ~= nil and objH + terrainH <= budget

    -- Terrain box at the very bottom of the column. Any hazards on the tile ride along on the same
    -- info so they read as a section directly above the terrain (and below the occupant box).
    local topBox = TileTooltip.draw(terrainInfo, mx, my, maxRight,
        { dock = true, dockX = 16, dockTop = dockTop, width = W })

    -- Occupant (unit or trap) in its own box, separated from the terrain by a gap.
    if showObj then
        local objBox = TileTooltip.draw(objInfo, mx, my, maxRight,
            { dock = true, dockX = 16, dockTop = dockTop, width = W,
              dockBottom = (topBox and topBox.y or Scale.HEIGHT - 8) - gap })
        if objBox then topBox = objBox end
    end

    -- Then the exchange, each box anchored above the last. A tighter gap than the one between the
    -- reference boxes below: these are beats of a single trade and read as one unit.
    local exOpts = { placement = "above", dockTop = dockTop, width = W, gap = exGap }
    -- With every reference box dropped there is nothing to anchor to: start from the column floor.
    topBox = topBox or { x = 16, y = Scale.HEIGHT - 8 + exGap, w = W, h = 0 }
    for _, a in ipairs(exchange) do
        topBox = ActionPreview.draw(a, topBox, maxRight, exOpts) or topBox
    end
end

-- Stats tooltip for a unit hovered on the turn-order strip: the same widget as the tile hover, but
-- fed only the unit (no tile), so it shows the character's stats alone without terrain. `maxRight`
-- is the full screen width since a strip hover sits over the panel (the tooltip flips left of the
-- cursor to stay on-screen).
function battle.drawUnitTooltip(unit, mx, my, maxRight)
    TileTooltip.draw({ unit = unit }, mx, my, maxRight or Scale.WIDTH)
end

-- Backdrop for the left column (mirrors the right combat panel). The buttons and the docked
-- tile/action tooltips render on top of it; the board is centred in the gap to its right.
function battle.drawLeftColumn()
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", 0, 0, LEFT_W, Scale.HEIGHT)
    Theme.set(Theme.frame)
    love.graphics.setLineWidth(1)
    love.graphics.line(LEFT_W, 0, LEFT_W, Scale.HEIGHT)
    love.graphics.setColor(1, 1, 1)
end

-- The hamburger itself: three bars, brighter while the menu is open so its state reads at a
-- glance (the same on/off treatment the toggles below use). Drawn on every screen the left column
-- appears on -- the fight, and the deployment phase before it.
function battle.drawMenuButton()
    local menuOpen = battle.menuOpen
    if menuOpen then Theme.set(Theme.panel) else Theme.set(Theme.panel2) end
    love.graphics.rectangle("fill", MENU_BUTTON.x, MENU_BUTTON.y, MENU_BUTTON.w, MENU_BUTTON.h, 6, 6)
    Theme.set(Theme.frame, menuOpen and 1 or 0.7)
    love.graphics.rectangle("line", MENU_BUTTON.x, MENU_BUTTON.y, MENU_BUTTON.w, MENU_BUTTON.h, 6, 6)
    if menuOpen then Theme.set(Theme.ink) else Theme.set(Theme.muted) end
    love.graphics.setLineWidth(2)
    for i = 0, 2 do
        local by = MENU_BUTTON.y + 11 + i * 7
        love.graphics.line(MENU_BUTTON.x + 10, by, MENU_BUTTON.x + MENU_BUTTON.w - 10, by)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

-- Every left-column button shares one themed look: a slate plate with a bone-gold frame + ink
-- label when off, and the control's OWN accent on the border + label when active, so the toggle
-- state still reads by colour.
function battle.drawMenuEntry(btn, label, on, accent)
    Theme.set(on and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(on and 1.5 or 1)
    if on then love.graphics.setColor(accent[1], accent[2], accent[3]) else Theme.set(Theme.frame) end
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
    if on then love.graphics.setColor(accent[1], accent[2], accent[3]) else Theme.set(Theme.ink) end
    love.graphics.setFont(hudFont)
    love.graphics.printf(label, btn.x, btn.y + btn.h / 2 - 8, btn.w, "center")
end

-- The drawer as the DEPLOYMENT phase wears it: the same hamburger in the same corner, opening on the
-- one entry that means something before the bell (see deploySettingsButton). The column's controls are
-- part of the screen's furniture, not the fight's, so they stand before the first turn as after it.
function battle.drawDeployMenu()
    battle.drawMenuButton()
    if not battle.menuOpen then return end
    battle.drawMenuEntry(battle.deploySettingsButton, "Settings", false, { 0.70, 0.70, 0.78 })
end

function battle.drawHud()
    -- Centre the HUD text over the board region (the gap between the two side columns), not the
    -- whole window, so title/objective/hint sit squarely above the battlefield.
    local boardX = LEFT_W
    local boardW = Scale.WIDTH - LEFT_W - PANEL_W

    battle.drawMenuButton()

    -- The entries only exist while the menu is open -- closed, the column below the hamburger is the
    -- tooltips' (and a click there falls through to them, see mousepressed).
    if not battle.menuOpen then
        battle.drawHudText(boardX, boardW)
        return
    end

    -- Forfeit is a danger action -- its frame + label stay a muted red even when idle.
    battle.drawMenuEntry(forfeitButton, "Forfeit", true, { 0.78, 0.45, 0.45 })

    local logOn = battle.log and battle.log.visible
    battle.drawMenuEntry(logButton, logOn and "Log ✓" or "Log", logOn, { 0.55, 0.80, 0.55 })

    local rangesOn = battle.showEnemyRanges
    battle.drawMenuEntry(rangesButton, rangesOn and "Threats ✓" or "Threats", rangesOn, { 0.72, 0.45, 0.92 })

    -- Auto is hidden entirely during a tutorial fight -- the student must take their own turns.
    local autoOn = battle.autoAll
    if autoAllowed() then
        battle.drawMenuEntry(autoButton, autoOn and "Auto ✓" or "Auto", autoOn, { 0.42, 0.80, 0.82 })
    end

    -- Playback-speed cycler, paired to the right of Auto and only while Auto is on.
    if autoOn and autoAllowed() then
        battle.drawMenuEntry(speedButton, tostring(battle.autoSpeed or 1) .. "x", true, { 0.42, 0.80, 0.82 })
    end

    -- Reinforce: only in a fight that HAS a bench, and lit only while a slot is actually open. Greyed
    -- the rest of the time rather than hidden, so the option is something the player learns is there
    -- before the moment they need it.
    if battle.hasBench then
        local canReinforce = Combat.canReinforce(battle.combat)
        battle.drawMenuEntry(reinforceButton, "Reinforce", canReinforce, { 0.42, 0.66, 0.92 })
    end

    -- Settings: a plain entry (never a toggle state), opening the overlay over the paused fight.
    battle.drawMenuEntry(settingsButton, "Settings", false, { 0.70, 0.70, 0.78 })

    -- Debug-only instant-win shortcut, sat where Main Menu used to be. (No "Lose" twin: Forfeit is it.)
    if Debug.enabled then
        battle.drawMenuEntry(winButton, "Win", true, { 0.45, 0.75, 0.50 })
    end

    battle.drawHudText(boardX, boardW)
end

-- The first two of the board's three top lines: which fight this is, and what wins it. Split out of
-- drawHudText because the DEPLOYMENT phase draws exactly these two and then its own third line -- what
-- the fight is and what it is won by is the whole basis of where to stand, so it is on screen while
-- that decision is being made, at the same two y's it keeps once the bell rings.
function battle.drawEncounterLines(boardX, boardW)
    love.graphics.setFont(titleFont)
    local name = battle.encounter.name or "Battle"
    local cx, cyTitle = boardX + boardW / 2, 20 + titleFont:getHeight() / 2
    local halfTitle = titleFont:getWidth(name) / 2
    Theme.crest(cx - halfTitle - 20, cyTitle, 9)
    Theme.crest(cx + halfTitle + 20, cyTitle, 9)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(name, boardX, 20, boardW, "center")

    battle.drawObjective(boardX, 52, boardW)
    if battle.isDraft then battle.drawControlHud(boardX, boardW) end
end

-- The board's own three top lines (encounter name, objective, control hint), split out of drawHud so
-- the collapsed menu can skip straight to them without repeating the block. Centred over the
-- battlefield region, never the whole window, so they sit squarely above the board.
function battle.drawHudText(boardX, boardW)
    battle.drawEncounterLines(boardX, boardW)

    -- Contextual control hint, worded for the device last used, so it never names an input the player
    -- can't reach: mouse phrasing ("Click..."), keyboard phrasing (Enter confirm, Tab aim, number keys
    -- switch, Esc cancel) and pad-button phrasing (D-pad cursor + face buttons: A confirm, Y switch,
    -- X wait, B cancel; the bumpers step the aim). The armed line surfaces the keyboard/pad target
    -- assist -- Tab / LB·RB cycle the valid targets the selection just auto-aimed at.
    local pad = InputMode.isGamepad()
    local kbd = InputMode.isKeyboard()
    local hint
    local lesson = battle.tutorial and Tutorial.step(battle.tutorial)
    if lesson and battle.current and Combat.isPlayerControlled(battle.current) and not battle.over then
        -- Under a lesson the ordinary hint is worse than useless: it lists items and Wait alongside
        -- the move, three of which the gate is about to refuse. And the instruction is already on
        -- screen twice over -- Rowan's panel and the coach bubble pinned to the thing itself. So this
        -- line simply stands down rather than repeating one of them a third time.
        hint = ""
    elseif battle.current and Combat.isPlayerControlled(battle.current) and not battle.over then
        if battle.mode == "armed" then
            local name = (battle.armedItem and battle.armedItem.name) or "it"
            -- More than one valid target in reach: the selection auto-aimed at the nearest, and cycling
            -- the ring now buys something. With one (or none) the cycle hint is left off.
            local canAim = #targetCells() > 1
            -- A chargeable signature (The First Motion) does not strike on this confirm: it raises the
            -- wind-up chooser, where the depth is picked and the blow committed. Word the verb so the
            -- player expects that panel rather than an immediate swing.
            local chargeable = battle.armedItem and Item.isChargeable(battle.armedItem.activeAbility)
            local set = chargeable and "set the wind-up" or nil
            if pad then
                local verb = battle.armedTile and ("Aim a tile, A to " .. (set or ("place " .. name)))
                    or battle.armedSupport and "A on an ally to support"
                    or ("A on a target to " .. (set or "strike"))
                hint = verb .. (canAim and "  ·  LB/RB to aim" or "")
                    .. "  ·  Y to switch  ·  B to cancel"
            elseif kbd then
                local verb = battle.armedTile and ("Move to a tile, Enter to " .. (set or ("place " .. name)))
                    or battle.armedSupport and "Enter on an ally to support"
                    or ("Enter on a target to " .. (set or "strike"))
                hint = verb .. (canAim and "  ·  Tab to aim next" or "")
                    .. "  ·  number keys to switch  ·  Esc to cancel"
            else -- mouse
                local verb = battle.armedTile and ("Click a tile to " .. (set or ("place " .. name)))
                    or battle.armedSupport and "Click an ally to support"
                    or ("Click a target to " .. (set or "strike"))
                hint = verb .. "  ·  click the item / Esc to cancel"
            end
        elseif Combat.hasMoved(battle.combat) then
            hint = pad and "A on a foe in range to attack  ·  Y to switch item  ·  X to hold this turn"
                or kbd and "Enter on a foe in range to attack  ·  number keys to switch  ·  Space to hold this turn"
                or "Click a foe in range to attack  ·  click an item  ·  Wait to hold this turn"
        else
            hint = pad and "A on a blue tile to move  ·  a foe in red range to attack  ·  Y to arm  ·  X to delay"
                or kbd and "Enter on a blue tile to move  ·  a foe in red range to attack  ·  number keys to arm  ·  Space to delay"
                or "Click a blue tile to move  ·  a foe in red range to attack  ·  an item  ·  Wait to delay"
        end
    else
        hint = "Enemy acting..."
    end
    -- Hint sits just under the objective (a third top line) so the bottom gutter is free for
    -- the toggle-able combat log. Small font so the longest hint stays on one line, clear of the
    -- board top.
    love.graphics.setFont(hintFont)
    Theme.set(Theme.muted)
    love.graphics.printf(hint, boardX, 82, boardW, "center")
    love.graphics.setColor(1, 1, 1)
end

-- Cancel a pending auto-battle turn and hand the unit back to the player. Called from every input
-- entry point: the promise the Tactics tab makes is "press anything to take over", and a promise that
-- only holds for some keys is worse than not making it. Returns true when a turn was reclaimed, but
-- the input still falls through and does its normal job -- the player who clicked a tile to interrupt
-- meant to click that tile.
local function reclaimAutoTurn()
    if not battle.autoPending then return false end
    battle.autoPending = nil
    battle.aiTimer = nil
    Combat.logEvent(battle.combat, "info",
        (battle.current and battle.current.char.name or "Unit") .. " -- control taken back")
    return true
end

-- Flip the whole-side auto-battle flag (the menu's Auto entry / the V key / gamepad A). Turning it ON arms the
-- unit that is up right now, if that unit is the player's and its turn is still open, so the button
-- feels immediate rather than waiting for the next turn boundary. Turning it OFF reclaims any pending
-- auto turn, handing the current unit straight back.
local function toggleAutoAll()
    if not autoAllowed() then return end
    battle.autoAll = not battle.autoAll
    if battle.autoAll then
        local current = battle.current
        if current and not battle.over and not battle.autoPending
            and Combat.isPlayerControlled(current) and current.control ~= "remote" then
            battle.aiTimer = AI_DELAY
            battle.autoPending = current
        end
    else
        reclaimAutoTurn()
    end
end

-- Step the auto-battle playback speed to the next rung of SPEED_STEPS, wrapping 3x back to 1x. Only
-- meaningful while autoAll is on (its button hides otherwise); callers gate on that. Deliberately
-- does not touch autoPending -- see the speedButton note: changing pace is not taking the turn back.
local function cycleAutoSpeed()
    local cur = battle.autoSpeed or 1
    local idx = 1
    for i, v in ipairs(SPEED_STEPS) do if v == cur then idx = i break end end
    battle.autoSpeed = SPEED_STEPS[idx % #SPEED_STEPS + 1]
end

function battle.keypressed(key)
    -- The settings overlay is the top-most modal: it eats every key while it is up. Esc closes it
    -- (never forfeits the fight underneath), the rest work the list. Above the deployment phase too,
    -- since the phase's own drawer opens it -- a modal a screen raised is a modal over that screen.
    if battle.settingsMenu then
        if key == "escape" then closeSettings() else battle.settingsMenu:keypressed(key) end
        return
    end
    -- The deployment phase owns every other input until the player commits their line. It is not a modal
    -- over the fight -- it is what the screen IS before the fight starts -- so it simply takes the key.
    -- The Loadout screen IS a modal over it, and closes itself on Esc.
    if battle.deployLoadout then battle.deployLoadout:keypressed(key); return end
    if battle.deploy then battle.deploy:keypressed(key); return end
    -- The bench chooser owns the keyboard while someone is being picked off the bench.
    if battle.benchChooser then battle.benchChooser:keypressed(key); return end
    -- The wind-up chooser eats every key while a chargeable swing is being sized (arrows/+- adjust,
    -- Enter commits the blow, Esc backs out and leaves it armed).
    if battle.spendChooser then battle.spendChooser:keypressed(key); return end
    if battle.windupChooser then battle.windupChooser:keypressed(key); return end
    if battle.debugMenu then battle.debugMenu:keypressed(key); return end
    if battle.debugPickTile and key == "escape" then battle.debugPickTile = nil; return end
    if battle.logReview then
        if key == "escape" or key == "l" then closeLogReview()
        elseif key == "up" or key == "pageup" then battle.logReview.log:wheelmoved(0, 1)
        elseif key == "down" or key == "pagedown" then battle.logReview.log:wheelmoved(0, -1)
        end
        return
    end
    if battle.summary then battle.summary:keypressed(key); return end
    -- Speed cycler (F): handled BEFORE reclaimAutoTurn so fast-forwarding the AI does not count as
    -- taking the turn back. Only while auto is running -- otherwise F falls through as an ordinary key.
    if key == "f" and battle.autoAll then cycleAutoSpeed(); return end
    reclaimAutoTurn()
    if key == "f5" then
        Arena.save(battle.arena, (battle.arena.biome or "arena") .. "_" .. os.time())
        return
    end
    if key == "f6" then -- debug: toggle initiative (timeline) numbers on the turn order
        battle.showInitiative = not battle.showInitiative
        return
    end
    if key == "l" then -- toggle the combat log (works whether or not the battle is over)
        battle.log:toggle()
        return
    end
    if key == "t" then -- toggle the all-enemy-attack-ranges danger overlay
        battle.showEnemyRanges = not battle.showEnemyRanges
        return
    end
    if key == "v" then -- toggle whole-side auto-battle (hand the player's units to the AI)
        -- NOT "a": that belongs to WASD cursor movement (ui/battle_map -- the "A" is left), so the
        -- keyboard auto toggle sits on V. The on-screen Auto button and gamepad A are unchanged.
        toggleAutoAll()
        return
    end
    -- Scroll the turn-order strip toward later / earlier turns (read-only, so allowed once the
    -- battle is over too).
    if key == "pageup" then
        battle.panel:scrollBy(1)
        return
    elseif key == "pagedown" then
        battle.panel:scrollBy(-1)
        return
    end
    if battle.over then return end
    -- Any key but the Wait keys drops a pending Wait preview: aiming, moving, arming, cancelling -- all
    -- mean the player no longer means to wait, so the next Space/0 arms the preview afresh rather than
    -- confirming a stale one. (Page-scroll returns above, so paging the strip leaves the preview intact.)
    if not (key == "space" or key == "0" or key == "kp0") then battle.waitPreview = false end
    if key == "return" or key == "kpenter" then
        confirm()
    elseif key == "space" then
        -- Space confirms the highlighted action, like Enter -- but with nothing aimed at the cursor
        -- (no move/target/strike lit) it falls back to the two-press Wait, so a bare press still ends the
        -- turn rather than doing nothing. actionPreviewFor mirrors confirm()'s branching exactly, so "a
        -- move is highlighted" is precisely "it returns a plan here". A live action confirms outright; the
        -- Wait fallback previews on the first press and commits on the second (previewOrConfirmWait).
        local cursor = battle.map.cursor
        if actionPreviewFor(cursor.x, cursor.y) then confirm() else previewOrConfirmWait() end
    elseif key == "tab" then
        -- Cycle the aim through the valid targets (Shift+Tab steps back). A no-op when there is nothing
        -- to aim at -- Wait still lives on Space / 0 / numpad-0, so the turn is never stranded.
        cycleTarget(love.keyboard.isDown("lshift", "rshift") and -1 or 1)
    elseif key == "kp0" or key == "0" then
        previewOrConfirmWait()
    elseif key == "escape" then
        -- A throw's landing phase backs up to its grab phase first; otherwise Esc disarms (or forfeits).
        if throwStepBack() then return end
        if battle.mode == "armed" then cancelArm()
        elseif not tutorialRefuses("forfeit") then lose() end
    elseif KEYPAD_SLOT[key] then
        armSlot(KEYPAD_SLOT[key]) -- numpad, mapped by physical position to the 3x3 item grid
    elseif key:match("^[1-9]$") then
        armSlot(tonumber(key))
    else
        battle.map:keypressed(key)
    end
end

-- Typed characters feed the debug menu's list filter (its "type-to-search" box); nothing else in
-- battle reads text input.
function battle.textinput(t)
    if battle.debugMenu then battle.debugMenu:textinput(t); return end
end

function battle.gamepadpressed(joystick, button)
    -- The settings overlay first, on the deployment phase as in the fight (see keypressed).
    if battle.settingsMenu then
        if button == "b" then closeSettings() else battle.settingsMenu:gamepadpressed(joystick, button) end
        return
    end
    if battle.deployLoadout then battle.deployLoadout:gamepadpressed(joystick, button); return end
    if battle.deploy then battle.deploy:gamepadpressed(joystick, button); return end
    if battle.benchChooser then battle.benchChooser:gamepadpressed(joystick, button); return end
    -- The wind-up chooser owns the pad while a chargeable swing is being sized (D-pad / bumpers adjust,
    -- A commits, B backs out).
    if battle.spendChooser then battle.spendChooser:gamepadpressed(joystick, button); return end
    if battle.windupChooser then battle.windupChooser:gamepadpressed(joystick, button); return end
    if battle.debugMenu then battle.debugMenu:gamepadpressed(joystick, button); return end
    if battle.logReview then
        if button == "b" or button == "y" then closeLogReview()
        elseif button == "dpup" then battle.logReview.log:wheelmoved(0, 1)
        elseif button == "dpdown" then battle.logReview.log:wheelmoved(0, -1)
        end
        return
    end
    if battle.summary then battle.summary:gamepadpressed(joystick, button); return end
    -- Right-stick click cycles the auto playback speed while auto is running -- handled before the
    -- reclaim so it fast-forwards rather than seizing the turn (mirrors the F key / speed button).
    if button == "rightstick" and battle.autoAll then cycleAutoSpeed(); return end
    reclaimAutoTurn()
    if button == "leftshoulder" then
        -- While aiming: the bumpers step the aim through the valid targets (LB back, RB forward).
        -- Disarmed, the left bumper toggles the combat log as usual (allowed even when the battle is
        -- over). A chargeable signature's DEPTH is no longer tuned here -- that choice moved to the
        -- modal that opens on confirm (openWindupChooser), which owns the bumpers while it is up.
        if battle.mode == "armed" and cycleTarget(-1) then return end
        battle.log:toggle()
        return
    end
    if button == "rightshoulder" then
        if battle.mode == "armed" and cycleTarget(1) then return end
        battle.panel:cyclePage() -- page the turn-order strip, wrapping back to the actor
        return
    end
    if button == "leftstick" then -- toggle the all-enemy-attack-ranges danger overlay
        battle.showEnemyRanges = not battle.showEnemyRanges
        return
    end
    if battle.over then return end
    if button == "a" or button == "start" then
        confirm()
    elseif button == "x" then
        waitTurn()
    elseif button == "b" then
        if throwStepBack() then return end -- landing phase -> grab phase, before a full disarm
        if battle.mode == "armed" then cancelArm()
        elseif not tutorialRefuses("forfeit") then lose() end
    elseif button == "back" then
        if not tutorialRefuses("forfeit") then lose() end
    elseif button == "y" then
        cycleAbilityItem()
    else
        battle.map:gamepadpressed(joystick, button)
    end
end

-- Soft tick as the pointer crosses onto a new left-column button (the hamburger, or a drawer entry
-- while it is open). Fires on the crossing only, so resting on a button is silent. Shared by the fight
-- and the deployment phase, which wears the same column.
function battle.menuHoverCue(x, y)
    local hb = hoveredMenuButton(x, y)
    if hb and hb ~= battle.hoverMenuBtn then Sound.play("ui.move") end
    battle.hoverMenuBtn = hb
end

function battle.mousemoved(x, y, dx, dy)
    battle.mouseX, battle.mouseY = x, y -- drives the status tooltip (board + panel hit-tests)
    if battle.settingsMenu then
        battle.settingsMenu:mousemoved(x, y)
        battle.settingsClose:mousemoved(x, y)
        return
    end
    if battle.deployLoadout then battle.deployLoadout:mousemoved(x, y); return end
    if battle.deploy then
        battle.menuHoverCue(x, y) -- the pre-bell drawer is hoverable like any other left-column button
        battle.deploy:mousemoved(x, y)
        return
    end
    if battle.benchChooser then battle.benchChooser:mousemoved(x, y); return end
    if battle.spendChooser then battle.spendChooser:mousemoved(x, y); return end
    if battle.windupChooser then battle.windupChooser:mousemoved(x, y); return end
    if battle.debugMenu then battle.debugMenu:mousemoved(x, y); return end
    battle.menuHoverCue(x, y)
    battle.log:mousemoved(x, y)         -- drives the combat log's damage-breakdown hover
    if battle.logReview then
        battle.logReview.log:mousemoved(x, y)
        battle.logReview.close:mousemoved(x, y)
        return
    end
    if battle.summary then battle.summary:mousemoved(x, y); return end
    -- Hovering the panel's Wait button previews the delay slot on the timeline.
    local overPanel = battle.panel:mousemoved(x, y)
    battle.hoverWait = battle.panel.waitHover and battle.current
        and Combat.isPlayerControlled(battle.current) and not battle.over and not walking() or false
    if overPanel then return end
    battle.map:mousemoved(x, y)
end

-- The wheel scrolls the turn-order strip from anywhere it makes sense: over the right panel OR over
-- the board (the two places the player watches the timeline from). The open combat log claims it
-- first when the cursor is inside it, so its own history still scrolls; contains() is false while
-- the log is closed, so a wheel over the board falls through to the strip.
function battle.wheelmoved(dx, dy)
    if battle.settingsMenu then return end -- the short list needs no scroll; swallow it
    -- The deployment strip owns the wheel while the phase is up: the company is the whole roster and
    -- an unbounded one overflows the strip, which then pages sideways (ui/deploy_phase.lua).
    if battle.deployLoadout then battle.deployLoadout:wheelmoved(dx, dy); return end
    if battle.deploy then battle.deploy:wheelmoved(dx, dy); return end
    if battle.benchChooser then battle.benchChooser:wheelmoved(dx, dy); return end
    -- The wind-up chooser owns the wheel while it is up: scrolling tunes the depth on the rung ladder.
    if battle.spendChooser then battle.spendChooser:wheelmoved(dx, dy); return end
    if battle.windupChooser then battle.windupChooser:wheelmoved(dx, dy); return end
    if battle.debugMenu then battle.debugMenu:wheelmoved(dx, dy); return end
    if battle.logReview then battle.logReview.log:wheelmoved(dx, dy); return end
    if battle.summary then return end -- the overlay has no scroll of its own; swallow it
    if battle.mouseX and battle.log:contains(battle.mouseX, battle.mouseY) then
        battle.log:wheelmoved(dx, dy)
        return
    end
    battle.panel:wheelmoved(dx, dy)
end

-- Open the right-click debug menu over the cell under (x, y). Debug builds only (the sole caller
-- gates on Debug.enabled). Reads the tile and any living unit on it, so the menu can offer the unit
-- page or the terrain page; the callbacks let it clear itself, arm a tile pick, and refresh the view.
local function openDebugMenu(x, y)
    local cx, cy = battle.map:cellAt(x, y)
    if not cx then return end
    battle.debugMenu = DebugMenu.new({
        x = x, y = y,
        combat = battle.combat,
        tile = { x = cx, y = cy },
        unit = Combat.unitAt(battle.combat, cx, cy),
        onClose = function() battle.debugMenu = nil end,
        onPickTile = function(fn) battle.debugMenu = nil; battle.debugPickTile = fn end,
        refresh = function() refreshView() end,
    })
end

function battle.mousepressed(x, y, button)
    -- The settings overlay, opened from the pre-bell drawer, is modal over the deployment phase (see
    -- keypressed) -- so it is asked before the phase is, and the shared block below handles it.
    if battle.deployLoadout and not battle.settingsMenu then
        battle.deployLoadout:mousepressed(x, y, button)
        return
    end
    if battle.deploy and not battle.settingsMenu then
        -- The left column's hamburger works before the bell exactly as it does during the fight: it
        -- toggles the drawer, its one entry opens Settings, and a click that missed both folds the
        -- drawer away and still falls THROUGH to the phase, so the drag it was aimed at is not eaten.
        if button == 1 and pointIn(MENU_BUTTON, x, y) then
            battle.menuOpen = not battle.menuOpen
            return
        end
        if battle.menuOpen and button == 1 and pointIn(battle.deploySettingsButton, x, y) then
            openSettings()
            return
        end
        if battle.menuOpen and not overMenuEntry(x, y) then battle.menuOpen = false end
        battle.deploy:mousepressed(x, y, button)
        return
    end
    if battle.benchChooser then battle.benchChooser:mousepressed(x, y, button); return end
    -- Placing a reinforcement: the next board click on a lit tile lands them. A click anywhere else --
    -- or a right-click -- puts the pick back on the bench rather than stranding the player in a mode.
    -- Except on the last-stand prompt, which cannot be backed out of (see openBenchChooser): there the
    -- click is simply ignored until it lands on ground somebody can come in on.
    if battle.reinforcePick then
        local cx, cy = battle.map:cellAt(x, y)
        if button == 1 and cx then
            reinforceAt(battle.reinforcePick.index, cx, cy)
        elseif not battle.reinforcePick.mandatory then
            battle.reinforcePick = nil
            refreshView()
        end
        return
    end
    -- The settings overlay is the top-most modal: its X or a click on the dim backdrop closes it, a
    -- click on a row works the list, and nothing falls through to the board underneath.
    if battle.settingsMenu then
        if battle.settingsClose:mousepressed(x, y, button) then
            closeSettings()
        elseif button == 1 and not pointIn(battle.settings, x, y) then
            closeSettings()
        else
            battle.settingsMenu:mousepressed(x, y, button)
        end
        return
    end
    -- The wind-up chooser is the top-most modal while a chargeable swing is sized: a rung, the steppers,
    -- Confirm, the X, or a click on the dim backdrop all work it; nothing reaches the board beneath.
    if battle.spendChooser then battle.spendChooser:mousepressed(x, y, button); return end
    if battle.windupChooser then battle.windupChooser:mousepressed(x, y, button); return end
    -- The debug context menu (debug builds only) is modal over the board while it is up.
    if battle.debugMenu then battle.debugMenu:mousepressed(x, y, button); return end
    -- The log-review modal (over the summary) claims the click first: the X or a click outside its
    -- frame closes it back to the panel; a click inside is inert (the log scrolls by wheel).
    if battle.logReview then
        local r = battle.logReview
        local inFrame = x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
        if r.close:mousepressed(x, y, button) or (button == 1 and not inFrame) then closeLogReview() end
        return
    end
    -- The summary overlay swallows every click while it is up (it sits over the forfeit/log buttons
    -- and the board, which mousepressed does NOT gate on battle.over).
    if battle.summary then battle.summary:mousepressed(x, y, button); return end
    -- Speed cycler, handled before reclaimAutoTurn so a click on it fast-forwards the AI instead of
    -- handing the turn back. Only live while the drawer is open AND auto is running (its own draw gate).
    if battle.menuOpen and battle.autoAll and button == 1 and pointIn(speedButton, x, y) then
        cycleAutoSpeed()
        return
    end
    reclaimAutoTurn()
    -- A click is a fresh intent: drop any armed keyboard Wait preview so it can't confirm on a later
    -- Space/0. The mouse Wait button runs its own one-click path (onWait) and needs no preview here.
    battle.waitPreview = false
    -- A click on the assayed-foe kit card is swallowed here: the card floats OVER the board, so an
    -- unguarded click would fall through and attack whatever tile sits under it.
    if battle.peekUnit and battle.peek:contains(x, y) then return end
    if button == 1 and pointIn(MENU_BUTTON, x, y) then
        battle.menuOpen = not battle.menuOpen
        return
    end
    -- The entries are only clickable while the menu is open -- closed, their rects are the tooltip
    -- column's, and a click there must fall through rather than fire an invisible Forfeit. The
    -- toggles deliberately leave the menu open so their ✓ state can be read after the press.
    if battle.menuOpen and button == 1 then
        if pointIn(forfeitButton, x, y) then
            if not tutorialRefuses("forfeit") then lose() end
            return
        end
        if pointIn(logButton, x, y) then
            battle.log:toggle()
            return
        end
        if pointIn(rangesButton, x, y) then
            battle.showEnemyRanges = not battle.showEnemyRanges
            return
        end
        if autoAllowed() and pointIn(autoButton, x, y) then
            toggleAutoAll()
            return
        end
        if battle.hasBench and pointIn(reinforceButton, x, y) then
            openBenchChooser("reinforce")
            return
        end
        if pointIn(settingsButton, x, y) then
            openSettings()
            return
        end
        if Debug.enabled and pointIn(winButton, x, y) then
            if not battle.over then win() end
            return
        end
    end
    -- Any click that missed the drawer folds it away again -- it is a transient menu, and leaving it
    -- standing over its own tooltip column because the player looked elsewhere is the wrong default.
    -- The click still falls THROUGH to whatever it landed on (log, panel, board): dismissing a drawer
    -- the player wasn't aiming at should cost them nothing, least of all the move they just made.
    if battle.menuOpen and not overMenuEntry(x, y) then battle.menuOpen = false end
    -- A click inside the open log panel is consumed by it (it must not fall through to a
    -- move/attack on the battlefield beneath).
    if battle.log:contains(x, y) then return end
    if battle.panel:mousepressed(x, y, button) then return end
    -- Debug builds only. The "Move to tile" action arms a one-shot tile picker: the next left-click on
    -- the board is the destination, not a move/attack. Right-click (or Esc, in keypressed) cancels it.
    if Debug.enabled and battle.debugPickTile then
        if button == 1 then
            local cx, cy = battle.map:cellAt(x, y)
            if cx then battle.debugPickTile(cx, cy); refreshView() end
        end
        battle.debugPickTile = nil
        return
    end
    -- Right-click on the board opens the context-sensitive debug menu (unit vs terrain under the cell).
    if Debug.enabled and button == 2 then openDebugMenu(x, y); return end
    if battle.map:mousepressed(x, y, button) then confirm() end
end

-- Only the wind-up slider cares about a mouse release (to end a rung drag); everything else on the
-- board is press-driven.
function battle.mousereleased(x, y, button)
    if battle.settingsMenu then return end -- the modal took the press; the release is not the board's
    -- The Loadout screen is drag-driven (stash to grid), so its release matters as much as the phase's.
    if battle.deployLoadout then battle.deployLoadout:mousereleased(x, y, button); return end
    if battle.deploy then battle.deploy:mousereleased(x, y, button); return end
    if battle.spendChooser then battle.spendChooser:mousereleased(x, y, button); return end
    if battle.windupChooser then battle.windupChooser:mousereleased(x, y, button) end
    if battle.debugMenu then battle.debugMenu:mousereleased(x, y, button) end
end

-- Which context cursor to show under the mouse (see ui/cursor.lua). Mirrors mousepressed's region
-- precedence: a hand over the clickable UI (the left-column buttons, the open log, the right combat
-- panel), then the board -- where the stashed hoverAction (what a click would DO, from refreshView)
-- picks the glyph. While it's not the player's turn, the board reads "wait". Only consulted when the
-- mouse is the active device (main.lua gates on InputMode.isMouse()).
function battle.cursorKind()
    local mx, my = battle.mouseX, battle.mouseY
    if not mx then return "arrow" end
    if battle.settingsMenu then
        if battle.settingsClose:contains(mx, my) then return "hand" end
        return battle.settingsMenu:mouseOverItem(mx, my) and "hand" or "arrow"
    end
    if battle.deployLoadout then return battle.deployLoadout:cursorKind(mx, my) end
    if battle.deploy then
        -- The column's hamburger and its open entry are clickable before the bell too.
        if pointIn(MENU_BUTTON, mx, my) or overMenuEntry(mx, my) then return "hand" end
        return battle.deploy:cursorKind(mx, my)
    end
    if battle.logReview then
        return battle.logReview.close:contains(mx, my) and "hand" or "arrow"
    end
    if battle.benchChooser then return battle.benchChooser:cursorKind(mx, my) end
    if battle.spendChooser then return battle.spendChooser:cursorKind(mx, my) end
    if battle.windupChooser then return battle.windupChooser:cursorKind(mx, my) end
    if battle.debugMenu then return battle.debugMenu:cursorKind(mx, my) end
    if battle.summary then return battle.summary:cursorKind(mx, my) end
    -- Off the board: the clickable UI wants a pointing hand.
    if pointIn(MENU_BUTTON, mx, my) or overMenuEntry(mx, my)
        or battle.log:contains(mx, my) or battle.panel:contains(mx, my) then
        return "hand"
    end
    if battle.over then return "arrow" end
    -- Lit rally ground with a slot open: a click here opens the chooser, and it does so on EITHER side's
    -- turn -- so the hand has to outrank the "wait" the enemy's turn would otherwise show. Read straight
    -- off the same lookup confirm() claims the press with, so the pointer cannot promise a click the
    -- board would then refuse.
    if battle.reinforceHere and not busy() then
        local rx, ry = battle.map:cellAt(mx, my)
        if rx and battle.reinforceHere[rx .. "," .. ry] then return "hand" end
    end
    -- Enemy turn, a walk animation, or a channel resolving: a board click does nothing.
    if busy() or (battle.current and not Combat.isPlayerControlled(battle.current)) then
        return battle.map:cellAt(mx, my) and "wait" or "arrow"
    end
    if not battle.hoverAction then return "arrow" end -- a board tile with no valid action
    return battle.boardCursorKind() or "arrow"
end

-- The context-cursor glyph for whatever the stashed hoverAction would DO on the aimed cell, or nil
-- when nothing actionable is aimed. Shared by cursorKind (mouse: drawn at the pointer) and the
-- keyboard/pad path (drawn centred on the cursor tile, see battle.draw), so both surfaces read the
-- exact same intent off the one hoverAction.
function battle.boardCursorKind()
    local a = battle.hoverAction
    if not a then return nil end
    if a.kind == "move" then return a.blink and "blink" or "move" end
    if a.kind == "strikeTrap" then return "break" end
    if a.kind == "place" then return "target" end
    -- Striking or offensively casting on a foe: a sword for a physical hit, a wand for a magical
    -- one. The turn auto-arms the actor's default action, so an ordinary weapon attack arrives as
    -- an armed "ability" too -- the tag, not the kind, is what tells a sword swing from a spell.
    if a.kind == "attack" or (a.kind == "ability" and not a.support) then
        return itemHasTag(a.item, "magical") and "cast" or "attack"
    end
    if a.kind == "ability" and a.support then return "heal" end
    return nil
end

return battle
