local State = require("states")
local Menu = require("ui.menu")
local Player = require("models.player")
local Scale = require("scale")
local Theme = require("ui.theme")
local ScreenFx = require("ui.screen_fx")

local menu = {}

local titleFont = Theme.display(48)
local hintFont = Theme.body(16)

-- Two independent menus: the main one (centered, the shipped screen) and, in a dev build, a compact
-- debug column pinned to the top-left corner. They are separate widgets so debug entries can never
-- grow the main list past the bottom of the screen, and so adding one doesn't shift the real menu.
-- `focus` names which of the two keyboard/gamepad drives; Tab swaps, hovering either one claims it.
local widget
local debugWidget
local focus = "main"

-- Debug menu entries (jump into a battle, run string extraction) for development. Reads the one
-- build-wide switch (models/debug.lua) rather than keeping its own copy: the same flag now decides
-- whether a debug-only network transport exists, and two booleans that mean "is this a dev build"
-- is one of them shipped wrong.
local DEBUG = require("models.debug").enabled

-- Debug: the pool the mock battle rolls loadouts from -- every shoppable item, i.e. everything a
-- player could actually end up holding. Excluded: natural weapons (a beast's fangs are its body, not
-- gear) and bound signature relics (they belong to one bearer and Character.reconcileBound would put
-- them back anyway). Built once, sorted by id so a given roll is reproducible from a seed.
local function randomizablePool()
    local Item = require("models.item")
    local pool = {}
    for id, def in pairs(Item.defs) do
        if not Item.isBound(def) and Item.archetype(def) ~= "natural" then
            pool[#pool + 1] = id
        end
    end
    table.sort(pool)
    return pool
end

-- Debug: replace `char`'s authored loadout with random gear, leaving bound cells (a signature relic)
-- as the blueprint placed them. Every free cell gets an item -- a full grid is the point, since it is
-- adjacency that makes items interesting -- and the first free cell is forced to a weapon so the unit
-- always has a real strike to open with. `taken` is shared across the party and each id is drawn at
-- most once into it, so no item repeats within a grid or between units. Consumables roll a random
-- stack depth. A repair pass then makes every `requiresAdjacent` ability in the grid actually
-- castable (see below) -- a roll of dead abilities exercises nothing.
local function randomizeLoadout(char, pool, taken)
    local Character = require("models.character")
    local Item = require("models.item")
    local Combat = require("models.combat")

    local weapons = {}
    for _, id in ipairs(pool) do
        if Item.defs[id].type == "weapon" then weapons[#weapons + 1] = id end
    end

    for cell = 1, Character.MAX_INVENTORY do
        local held = char.inventory[cell]
        if held then taken[held.id] = true end
    end

    -- Draw without replacement: `ids` is a candidate list, already-taken entries are skipped.
    local function draw(ids)
        local available = {}
        for _, id in ipairs(ids) do
            if not taken[id] then available[#available + 1] = id end
        end
        if #available == 0 then return nil end
        local id = available[love.math.random(#available)]
        taken[id] = true
        local def = Item.defs[id]
        local qty = Item.isStackable(def) and love.math.random(1, Item.maxStack(def)) or 1
        return Item.instantiate(id, qty)
    end

    char.defaultActionSlot = nil
    for cell = 1, Character.MAX_INVENTORY do
        if not Item.isBound(char.inventory[cell]) then
            local weaponCell = char.defaultActionSlot == nil
            char.inventory[cell] = draw(weaponCell and weapons or pool)
            if weaponCell and char.inventory[cell] then char.defaultActionSlot = cell end
        end
    end

    -- An ability that names a neighbor (Power Shot's "adjacent ranged") is blocked outright where the
    -- fill happened not to drop one beside it, so the roll would keep handing units abilities they
    -- can't cast. Each offender is repaired in place: first by SWAPPING a matching item already in
    -- the grid next to it -- which keeps the roll's spread and the ability itself -- and only if no
    -- swap helps, by redrawing that cell as something satisfied where it sits. Bound cells never move.
    local function unmetCount()
        local n = 0
        for cell = 1, Character.MAX_INVENTORY do
            local it = char.inventory[cell]
            if it and not Combat.adjacencyMetAt(char, it, cell) then n = n + 1 end
        end
        return n
    end

    local function movable(cell)
        return char.inventory[cell] ~= nil and not Item.isBound(char.inventory[cell])
    end

    -- Swap a `req`-matching item into one of `cell`'s neighbors. Accepted only when the grid ends with
    -- fewer unmet requirements than it started with, so a swap that merely moves the block onto the
    -- donor's own ability is reverted rather than traded for.
    local function swapNeighborIn(cell, req)
        local before = unmetCount()
        for _, nb in ipairs(Character.adjacentIndices(cell)) do
            for donor = 1, Character.MAX_INVENTORY do
                if donor ~= cell and donor ~= nb and movable(nb) and movable(donor)
                    and Combat.matchesAdjacency(char.inventory[donor], req) then
                    char.inventory[nb], char.inventory[donor] = char.inventory[donor], char.inventory[nb]
                    if unmetCount() < before then return true end
                    char.inventory[nb], char.inventory[donor] = char.inventory[donor], char.inventory[nb]
                end
            end
        end
        return false
    end

    -- Candidates for `cell` that need nothing this grid can't already give them. A weapon cell stays
    -- a weapon, so repairing one can't leave the unit without a strike to open with.
    local function satisfiedHere(cell, weaponsOnly)
        local ids = {}
        for _, id in ipairs(weaponsOnly and weapons or pool) do
            local def = Item.defs[id]
            if Combat.adjacencyMetAt(char, def, cell) then ids[#ids + 1] = id end
        end
        return ids
    end

    local pinned = char.defaultActionSlot and char.inventory[char.defaultActionSlot]
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory[cell]
        local ab = item and item.activeAbility
        local req = ab and ab.requiresAdjacent
        if req and movable(cell) and not Combat.adjacencyMetAt(char, item, cell) then
            if not swapNeighborIn(cell, req) then
                taken[item.id] = nil -- back into the pool: this grid has no room for it
                char.inventory[cell] = draw(satisfiedHere(cell, item.type == "weapon"))
            end
        end
    end

    -- The pin follows the item the fill chose, wherever a swap moved it. If the repair drew it away
    -- entirely, drop the pin: Combat.defaultAction falls back to the first grid weapon on its own.
    char.defaultActionSlot = pinned and Character.slotIndex(char, pinned) or nil
end

-- Debug: drop straight into a battle with a stock party and a small enemy roster (mirrors the
-- objective-battle opts states/game.lua builds), so combat can be exercised without a full run.
-- Loadouts are rolled fresh each time (see randomizeLoadout) so repeated runs exercise a spread of
-- items rather than the same four authored grids. One `taken` set spans the party, so the four grids
-- between them show 36 distinct items.
-- `layout` optionally names a hand-authored board (data/arenas/<id>.lua) instead of rolling one --
-- how the Field Gallery below drops onto its own map without needing a quest to carry it.
local function startMockBattle(layout)
    local Character = require("models.character")
    local pool = randomizablePool()
    local taken = {}
    local party = {}
    for _, id in ipairs({ "character_rowan", "character_mage", "character_archer", "character_priest" }) do
        local char = Character.instantiate(id)
        randomizeLoadout(char, pool, taken)
        party[#party + 1] = char
    end
    State.switch(require("states.battle"), {
        -- Objective-kind so it draws its hand-picked roster (the objective block below), but it is a
        -- practice bout, not a boss -- so it asks for the ordinary battle bed rather than music.boss.
        encounter = { kind = "objective", music = "music.battle" },
        biome = "castle",
        prestige = 3,
        party = party,
        quest = { map = { biome = "castle", objective = {
            name = layout and "Field Gallery" or "Mock Battle",
            layout = layout,
            composition = function() return { "character_bandit", "character_bandit", "character_champion" } end,
            win = { type = "killAll" },
        } } },
        -- No hub/quest to return to: send both outcomes back to the menu.
        onWin = function() State.switch(require("states.menu")) end,
        onLoss = function() State.switch(require("states.menu")) end,
    })
end

-- Debug: the ANIMATION GALLERY -- every sprite clip the board can play, running at once on a board
-- arranged for looking at them. Sibling of the Field Gallery above and built the same way (a `fixed`
-- arena named by a mock battle); see data/arenas/animation_gallery.lua for what each body is doing and
-- what each row is arranged to prove.
--
-- Three things separate it from an ordinary mock battle, all of them in service of "it must hold
-- still":
--   * `deploy = false` commits the arena's own placement straight through. The gallery is a LAYOUT --
--     which body stands where is the whole statement -- and a deployment phase would hand that to
--     whoever opened it.
--   * every enemy is set to `control = "none"` -- the game's own word for a body nobody drives (a
--     scripted prop, a charmed-off construct). It hands its turn straight on, so the gallery never
--     dissolves into a fight, and Combat.threatMap skips it, so seven foes in a rank do not wash the
--     whole board red with threat tint. `timeless` would have stopped the turns too and left the
--     threat picture standing; this stops both, and it is the flag that already means this.
--   * the party carries NO kit and outspeeds everything, so it holds the opening turn and holds it.
-- Loadouts are not randomized here the way the mock battle's are -- they are emptied. What is being
-- looked at is the body, and a default action arming itself would throw an aim overlay across the
-- board: exactly the clutter the arena's plain ground exists to avoid.
local function startAnimationGallery()
    local Character = require("models.character")
    local CLIPS = {
        -- clip, and the period it repeats on. Deliberately not multiples of each other -- see the
        -- arena header on why a rank that fires together is its own kind of lockstep.
        { "walk", 1.7 }, { "attack", 1.1 }, { "hit", 1.3 }, { "heavy", 1.9 },
        { "cast", 1.5 }, { "selfcast", 2.1 }, { "death", 2.3 },
    }
    local party = {}
    for i, id in ipairs({ "character_rowan", "character_mage", "character_archer", "character_priest" }) do
        local char = Character.instantiate(id)
        char.inventory = {}          -- see the header: an armed default action would cover the board
        char.defaultActionSlot = nil
        -- ...and neither may the MOVE band, which is the other overlay a held turn paints. A body that
        -- cannot walk highlights only the tile it is standing on. Nothing in the gallery walks: the
        -- one clip that looks like walking is played on the rank above, as a clip.
        char.stats.movement = 0
        -- Ahead of every body on the board, so the opening turn is the party's and it keeps it.
        char.stats.speed = 90 + i
        party[#party + 1] = char
    end

    State.switch(require("states.battle"), {
        encounter = { kind = "objective", music = "music.battle" },
        biome = "castle",
        prestige = 3,
        party = party,
        deploy = false, -- the arena's own placement, committed straight through
        quest = { map = { biome = "castle", objective = {
            name = "Animation Gallery",
            layout = "animation_gallery",
            composition = function()
                -- One body per driven clip, all the same blueprint on purpose: identical tokens mean
                -- the ONLY difference down the rank is the motion, which is what is being compared.
                local list = {}
                for _ = 1, #CLIPS do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        } } },
        onWin = function() State.switch(require("states.menu")) end,
        onLoss = function() State.switch(require("states.menu")) end,
    })

    -- Wired AFTER the switch, because that is when the bodies exist: `deploy = false` seats everyone
    -- during enter(), so combat.units is populated by the time this runs.
    local battle = require("states.battle")
    local foes = {}
    for _, u in ipairs(battle.combat.units) do
        if u.side ~= "party" then foes[#foes + 1] = u end
    end
    table.sort(foes, function(a, b) return a.x < b.x end) -- left to right, matching the arena header
    for i, u in ipairs(foes) do
        u.control = "none" -- stands there and is looked at: passes its turn, threatens nothing
        local clip = CLIPS[i]
        if clip and battle.fx then
            -- Aimed at the idle rank below, so a lunge, a recoil and a collapse all read against
            -- something that is actually on the board rather than a phantom tile.
            battle.fx:loopClip(u, clip[1], { x = u.x, y = u.y + 3 }, clip[2])
        end
    end
end

-- Debug: run the localization string extractor (stamps ids + syncs data/lang/strings.lua). Same as
-- `lovec . extract-strings`; surfaced here so it can be run from a normal windowed session. Reports
-- the outcome in a short status line (there is no console under love.exe).
local function runExtractStrings()
    local ok, err = pcall(function() require("tools.extract_strings").run() end)
    menu.status = ok and "Extracted strings -> data/lang/strings.lua" or ("Extract failed: " .. tostring(err))
    menu.statusTimer = 5
end

-- Debug: start a New Game and open the hub city with Act 0 already paid out -- the prologue's grants
-- applied (states/prologue.lua's `skip`) but none of its scenes, fights or overworld leg played. The
-- two character-creation steps go with it, so the avatar wears body 1 and the blueprint's own name:
-- what this button is for is reaching the city, not being somebody in particular.
local function skipPrologue()
    Player.start(true) -- discards any save, exactly as New Game does
    require("states.prologue").skip(Player.active)
    Player.save()
    State.switch(require("states.hub"))
end

-- Built on entry, not at require time: whether "Continue" belongs on the menu depends on
-- whether a save exists, and that can change while the game is running (starting a new
-- game writes one; there is no save until the first quest is completed or purchase made).
local function buildMenu()
    local items = {}

    if Player.hasSave() then
        items[#items + 1] = {
            label = "Continue",
            action = function()
                Player.start()
                -- A save made mid-quest carries a resumable overworld run (models/save.lua): drop the
                -- player straight back onto that map where they quit, rather than home to the hub. Consumed
                -- once here (cleared so a bounce back to the menu doesn't re-resume a stale descriptor).
                local run = Player.active and Player.active.resumeRun
                if run then
                    Player.active.resumeRun = nil
                    State.switch(require("states.game"), run.quest, nil, Player.active, nil, run)
                else
                    State.switch(require("states.hub"))
                end
            end,
        }
    end

    items[#items + 1] = {
        label = "New Game",
        action = function()
            Player.start(true) -- discards any save
            -- Character creation (pick the avatar's body, then name it) opens a New Game; it hands off to the
            -- prologue -- for now, straight to the hub. See states/character_creation.lua.
            State.switch(require("states.character_creation"))
        end,
    }

    -- THE DESCENT IS THE POST-GAME, and this is the door. It appears once the campaign has actually been
    -- beaten (Player.hasFinishedCampaign, banked at the `endsCampaign` seam rather than at New Game+),
    -- and not before.
    --
    -- That placement is the whole point rather than a convenience. A descent walks in with one body and
    -- picks up its company on the floors, banks nothing back, and levels on its own per-character XP --
    -- so it is not campaign
    -- progression and the city was rightly the wrong door for it. But "not campaign progression" is not
    -- the same as "not for players": an endless, self-contained run that strips you back to nothing is
    -- exactly what a finished campaign should open onto, and while it sat in the debug column the ending
    -- had nowhere to land. The gate also means a first-time player still meets a menu that only knows how
    -- to start or resume the campaign, which is what the reasoning below was protecting.
    --
    -- Draft stays in the debug column: it is a separate competitive mode rather than the far end of this
    -- one, so finishing the campaign is not what earns it.
    -- THE DESCENT IS NOT A MENU ENTRY ANY MORE. It was the post-campaign mode, entered from here with a
    -- company of its own; it is the GAME now -- the prologue walks you into the capital and a sponsor at
    -- the gate sends you down (states/gate.lua, reached from the city). A second door with its own save
    -- semantics is exactly how two paths drift, so there is one.

    -- The main menu is otherwise what a player meets first, and it is for starting or resuming the
    -- campaign rather than for picking between modes. Anything still being built lives in the debug
    -- column below (buildDebugMenu), which is also where a shipping build stops offering it at all.
    items[#items + 1] = {
        label = "Settings",
        action = function() State.switch(require("states.settings"), menu) end,
    }

    items[#items + 1] = {
        label = "Exit To Desktop",
        action = function() love.event.quit() end,
    }

    return Menu.new(items, { startY = 280 })
end

-- The dev-build corner column. Small buttons in their own left-hand gutter, clear of the title and
-- of the centered main menu; nil in a shipping build, and every caller below tolerates that.
local DEBUG_BUTTON_W = 220
local DEBUG_MARGIN = 16

local function buildDebugMenu()
    if not DEBUG then return nil end
    return Menu.new({
        -- Straight into the city with Act 0 already paid for: the avatar and Rowan at the level the
        -- prologue's four fights pay, the road's kit in the stash, and the hub open in free play. The
        -- grants are the prologue's own (states/prologue.lua's `skip`), so what this hands over cannot
        -- drift from what playing it hands over.
        { label = "Skip Prologue", action = skipPrologue },
        -- DRAFT, alone now. It shares none of the campaign's progression and is still being built, which
        -- is what this column is for: a mode lives here until it is worth putting in front of a player.
        --
        -- The Descent left it by being promoted rather than finished. It is no longer a mode beside the
        -- campaign, it IS the campaign -- the prologue walks you into the capital and a sponsor at the
        -- gate sends you down -- so it is reached from the city like anything else the player does
        -- (states/gate.lua), and a debug door onto it would be a second entry with its own save
        -- semantics.
        { label = "Draft", action = function() State.switch(require("states.draft")) end },
        { label = "Mock Battle", action = function() startMockBattle() end },
        -- Every tile-field pattern on one board, for looking at the shader rather than arguing about
        -- it. See data/arenas/field_gallery.lua for what each row is arranged to prove.
        { label = "Field Gallery", action = function() startMockBattle("field_gallery") end },
        -- Every sprite clip on one board, for the same reason and in the same shape: the board's
        -- animation is code rather than a rig, and code seen for a fifth of a second mid-fight cannot
        -- be judged. See data/arenas/animation_gallery.lua.
        { label = "Animation Gallery", action = startAnimationGallery },
        { label = "Character Editor", action = function() State.switch(require("states.debug_editor")) end },
        -- The credits roll is otherwise reachable only by finishing the campaign, which makes it the
        -- least-looked-at screen in the game and the one carrying a licence obligation (the
        -- game-icons.net attribution). `newGamePlus = false`: there is no run behind this, so the
        -- carry-forward offer would have nothing to carry.
        { label = "Credits", action = function() State.switch(require("states.credits"), { newGamePlus = false }) end },
        { label = "Extract Strings", action = runExtractStrings },
    }, {
        buttonWidth = DEBUG_BUTTON_W,
        buttonHeight = 34,
        spacing = 8,
        startY = DEBUG_MARGIN + 22, -- below the "Debug" caption
        centerX = DEBUG_MARGIN + DEBUG_BUTTON_W / 2,
        font = hintFont,
    })
end

-- The widget keyboard and gamepad currently drive.
local function focused()
    if focus == "debug" and debugWidget then return debugWidget end
    return widget
end

-- Focus is exclusive: exactly one column carries the highlight, so it always reads as the row
-- Enter will press.
local function setFocus(which)
    focus = which
    widget:setFocused(focus == "main")
    if debugWidget then debugWidget:setFocused(focus == "debug") end
end

function menu.enter()
    -- Drop whatever screen effect the last state left standing -- the defeat grey above all. A lost
    -- battle desaturates the frame and hands the panel's exit straight here (a mock battle), so
    -- without this the title screen comes back drained to a colourless near-black and stays
    -- that way: nothing else ever clears it. The hub, the draft and a battle all reset on entry for
    -- the same reason (ui/screen_fx.lua).
    ScreenFx.reset()
    require("models.sound").music("music.menu")
    widget = buildMenu()
    debugWidget = buildDebugMenu()
    setFocus("main")
end

function menu.update(dt)
    -- Only the focused widget gets update(): it polls the analog stick, and two menus polling it
    -- would move both selections at once. The other still needs its rectangles laid out.
    focused():update(dt)
    if debugWidget then
        (focus == "debug" and widget or debugWidget):layout()
    end
    if menu.statusTimer and menu.statusTimer > 0 then
        menu.statusTimer = menu.statusTimer - dt
    end
end

function menu.draw()
    local screenW = Scale.WIDTH

    -- Fill the logical area explicitly (letterbox bars are cleared to black, so setBackgroundColor
    -- can't be used): the theme's atmospheric ground behind the title + menu.
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("LoveTactics", 0, 120, screenW, "center")

    widget:draw()

    if debugWidget then
        love.graphics.setFont(hintFont)
        Theme.set(Theme.muted)
        love.graphics.print("Debug", DEBUG_MARGIN, DEBUG_MARGIN)
        debugWidget:draw()
    end

    if Player.hasSave() then
        love.graphics.setFont(hintFont)
        Theme.set(Theme.muted)
        love.graphics.printf("New Game erases your save.", 0, Scale.HEIGHT - 48, screenW, "center")
    end

    -- Transient debug status (e.g. the result of Extract Strings).
    if menu.status and menu.statusTimer and menu.statusTimer > 0 then
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.55, 0.8, 0.6)
        love.graphics.printf(menu.status, 0, Scale.HEIGHT - 24, screenW, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- Hovering a column claims focus, so the highlight the mouse leaves behind is the one the keyboard
-- picks up from.
function menu.mousemoved(x, y)
    if debugWidget and debugWidget:mouseOverItem(x, y) then
        setFocus("debug")
        debugWidget:mousemoved(x, y)
    elseif widget:mouseOverItem(x, y) then
        setFocus("main")
        widget:mousemoved(x, y)
    end
end

-- Hand over a menu button, arrow elsewhere (see ui/cursor.lua).
function menu:cursorKind(x, y)
    if widget:mouseOverItem(x, y) then return "hand" end
    if debugWidget and debugWidget:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function menu.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
    if debugWidget then debugWidget:mousepressed(x, y, button) end
end

function menu.keypressed(key)
    if key == "tab" and debugWidget then
        setFocus(focus == "main" and "debug" or "main")
        return
    end
    focused():keypressed(key)
end

function menu.gamepadpressed(joystick, button)
    if (button == "leftshoulder" or button == "rightshoulder") and debugWidget then
        setFocus(focus == "main" and "debug" or "main")
        return
    end
    focused():gamepadpressed(joystick, button)
end

return menu
