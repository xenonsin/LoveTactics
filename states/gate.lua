-- THE GATE: the town at the mouth of the descent, and the other half of the loop.
--
-- A descent used to be one push with no way to stop pushing. It has a way out now -- you walk back to
-- the stair you came down by (states/game.lua's `ascent` stop) -- and this is what is up there when you
-- do: a hole in the ground, and a look at the company before they go back into it.
--
--   the roster    who is going down, and what shape they are in
--   the stair     back down to the floor the company climbed out of
--
-- AND NOTHING ELSE. The inn, the store and the hiring hall were rows on this menu once, which put three
-- towns' worth of business at the mouth of a stair. They are cards in the CITY now (data/buildings/),
-- and the split is the reference's own: Wizardry's castle holds the tavern, the inn, Boltac's and the
-- temple, and the dungeon entrance sits at the edge of town where there is nothing to do but enter.
--
-- AFTER A WIPE this is where the game lands -- at the temple, with the whole company alive, whole, and
-- carrying nothing. Whole because being above ground is what sets a bone now (models/wound.lua), so
-- what a wipe takes is the haul and the run and not the bodies' next expedition as well.
-- Everything they had is in a heap on the floor they fell on (models/descent.lua's
-- `drops`), so the next expedition has somewhere it very much wants to go. Dark Souls' bloodstain, and
-- the only thing that stops "climb out" and "die" being the same move.

local State = require("states")
local Choice = require("ui.panels.choice")
local Descent = require("models.descent")
local Gate = require("models.gate")
local Player = require("models.player")
local Scale = require("scale")
local Menu = require("ui.menu")
local Theme = require("ui.theme")
local SeedReadout = require("ui.seed_readout") -- the numbers behind the stair, in a dev build only
local Picker = require("ui.expedition_picker") -- four plates over the company; who goes down
local CoachBubble = require("ui.coach_bubble") -- the first visit's one instruction, pinned to the row
local TutorialNote = require("ui.panels.tutorial_note") -- ...and the window that explains the tally
local Locale = require("models.locale")        -- ...and the key cap it wears, or nil on the mouse

-- The hint bags this screen draws its words from (data/conversations/tutorial/), by id rather than
-- played as scenes. See models/locale.lua's Locale.node.
local CITY = "conversation_tutorial_city"
local NOTES = "conversation_tutorial_notes"

local gate = {}

local titleFont = Theme.display(34)
local headFont = Theme.display(17)
local bodyFont = Theme.body(14)
local smallFont = Theme.body(13)

-- Iselle's tally, in the right-hand column under the purse. Beside the gold rather than over the stair
-- on purpose: this screen is a LEDGER the player reads before committing, and the tally is the other
-- entry in it. Held at file scope so the arrival beat fires on a real change (ui/count_meter.lua).
-- KEPT WIRED, NOT DRAWN. The tally is parked (Descent.COUNT_PARKED) so nothing draws this any more;
-- it is still built and still ticked so that clearing that one flag brings the meter back with its
-- arrival beat intact, which is what separates a park from a deletion.
local countMeter = require("ui.count_meter").new()

-- ---------------------------------------------------------------------------
-- Going down
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- Going down, and starting over
-- ---------------------------------------------------------------------------

-- THE STAIR IS WHERE AN EXPEDITION BEGINS, so it is where the rollback point is taken.
--
-- `run.entry` is the company exactly as it walked in, and what a wipe puts on the floor is measured
-- against it (Player.takeAtRisk). Clearing it here makes states/game.lua's enter take a fresh one at the
-- mouth of the floor, which is the only reading of "what this expedition found" a player would accept:
-- the blade bought at the store, the body pulled at the hall and the night at the inn all happened in
-- TOWN, with banked gold, and none of them is a find that a bad fight downstairs can spill.
--
-- Carrying the climb-out snapshot back down instead -- which is what happened before, since the run
-- keeps `entry` and enter only falls back when it is nil -- meant everything bought between two
-- descents was still provisional, and a company that spent its winnings kitting out at the Gate would
-- lose the kit on the next floor. Climbing out banks; going down starts the next bet.
--
-- Floor to floor is untouched: that is a fresh enter with no Gate in between, `run.entry` is still set,
-- and re-snapshotting there would bank a run's finds just for walking downstairs.
-- `startFloor` is the stair to walk in by, and it only means anything on a FRESH expedition: a company
-- resuming one is standing where it stopped, and re-seating it would teleport a party mid-descent.
local function descend(startFloor)
    gate.panel = nil
    -- The first visit's coach bubble is spent HERE, by the deed, not by the screen having been looked
    -- at -- the same rule the city's door coaching keeps (states/hub.lua). Saved with the descent so a
    -- player who quits on floor one does not come back up to be taught the button again.
    if not Descent.gateCoached(gate.player) then
        Descent.markGateCoached(gate.player)
        Player.save()
    end
    local run = gate.run or Descent.new(gate.player)
    -- THE STAIR THEY PICKED. Seated onto the run rather than passed to Descent.new, because enter has
    -- already built it -- the picker above needs a run to read the company off. Guarded on `gate.fresh`
    -- so the row can never move a company that is already down there (see the header).
    if startFloor and gate.fresh then
        run.floor = math.max(1, math.min(Descent.entryFloor(gate.player), startFloor))
    end
    run.entry = nil
    Player.active = gate.player
    State.switch(require("states.game"), Descent.floorQuest(run, gate.player), nil, gate.player)
end

-- ---------------------------------------------------------------------------
-- The screen
-- ---------------------------------------------------------------------------

-- ONE THING HAPPENS HERE AND IT IS GOING DOWN.
--
-- This screen carried the inn, the store and the hiring hall as menu rows, which was three towns' worth
-- of business conducted at the mouth of a stair. They are cards in the CITY now (data/buildings/), and
-- the split is the reference's own: Wizardry's castle holds the tavern, the inn, Boltac's and the
-- temple, and the dungeon entrance sits out at the edge of town where there is nothing to do but enter.
--
-- What is left is the stair, the way back, and a readout of who is about to walk down it -- which stays
-- because the last thing a player wants before committing is to see the shape their company is in.
-- THE PICKER IS A BOARD, NOT A LIST (ui/expedition_picker.lua).
--
-- This asked with toggle rows first, and rows are the wrong shape for it. A party has POSITIONS in it
-- and a company is a thing you look across; a column of ticked labels says neither, and reads as a
-- settings screen for a decision that is really "these four, and that one stays home". Four plates over
-- the roster says it in one glance, and the body moves between them.
--
-- The two actions stay a menu underneath. Tab (or a shoulder) moves focus between the two, which is the
-- same hand-off ui/panels/party.lua keeps between a character's grid and the stash.
function gate:build()
    gate.picker = Picker.new({
        x = Scale.WIDTH / 2 - 260, y = 206,
        player = gate.player, run = gate.run,
        onChange = function() gate:build() end,
    })

    local items = {}
    if Gate.canDescend(gate.player, gate.run) then
        -- THE STAIRS YOU HAVE OPENED, and on a fresh expedition there may be two of them.
        --
        -- A company that has mapped its way down to floor five walks back in AT floor five -- Wizardry's
        -- shaft, Wizardry Variants Daphne's elevator (Descent.entryFloor). Re-walking four cleared
        -- floors to reach the one you stopped on is the map book's cost with none of its benefit, and
        -- it gets worse every trip.
        --
        -- BOTH ROWS ARE NAMED AND BOTH ARE ALWAYS LEGAL when a deeper stair exists -- no fold, no
        -- default that hides the other (ui/menu.lua's own standard). Going in at the top is a real
        -- choice rather than a worse one: the floors above re-arm (Descent.rearmFloor), so the shallow
        -- end is where a thin company goes to come back up heavier.
        --
        -- ONE ROW WHEN THERE IS ONE STAIR, which is every company's first trip and every resumed
        -- expedition -- a control appears only where it can be used.
        local deep = gate.fresh and Descent.entryFloor(gate.player) or Descent.depth(gate.run)
        items[#items + 1] = {
            label = "Down to floor " .. deep,
            action = function() descend(deep) end,
            -- THE ONE ROW THE FIRST VISIT COACHES. Marked here rather than found by index, because the
            -- row above it is conditional and an index would silently move (see gate.draw).
            coach = true,
        }
        if gate.fresh and deep > 1 then
            items[#items + 1] = {
                label = "Down to floor 1",
                action = function() descend(1) end,
            }
        end
    end
    -- THERE IS NO "WAIT A DAY" ROW, and its deletion is the design rather than a tidy-up.
    --
    -- It existed to let a company too hurt to descend reach the morning that would mend them, because
    -- the only other way to spend a day was to walk into the stair -- a cure on the far side of the
    -- fight you were too hurt to take.
    --
    -- IT STAYS DELETED EVEN THOUGH RESTING IS BACK (the Ward, 2026-09-16), because the circularity it
    -- patched is GONE rather than solved. A rest is priced in DESCENTS now, served by Gate.night as the
    -- company walks down -- so the way to pass the time is to go, with whoever is standing. You never
    -- need the resting body to descend, which is the exact thing that made a wait button necessary. A
    -- control draws where it can be used, and this one still cannot.
    --
    -- AND NOTHING IS SOLD HERE EITHER. "Widen the mule" was a row on this menu and is gone for the same
    -- reason the inn and the store are: this screen is a hole in the ground and a look at the company,
    -- not a counter. The mule's ladder (models/mule.lua) still exists -- it just does not get bought at
    -- the mouth of the stair.
    -- THE BOOK, and it opens HERE rather than from a door in the city, because the question it answers
    -- is asked at the mouth of the stair: what am I going down for (models/bestiary.lua,
    -- docs/drops.md). It is a record the company keeps, not a counter somebody stands behind, so it
    -- wants no building, no keeper and no unlock.
    --
    -- Drawn unconditionally. An empty book is not a missing control -- it says what fills it in, which
    -- is exactly what a player who has never opened it needs to read.
    items[#items + 1] = { label = "The Book", action = function()
        gate.panel = require("ui.panels.bestiary").new({
            player = gate.player,
            onClose = function() gate.panel = nil end,
        })
    end }

    items[#items + 1] = { label = "Back to the City", action = function()
        State.switch(require("states.hub"))
    end }
    gate.menu = Menu.new(items, {
        -- 28 BECAME 48 to reserve the band the pack line draws in (see gate.draw). Both numbers are
        -- measured off the picker's own height, so the caption and the menu move together and neither
        -- can land on the other when the roster row grows.
        startY = gate.picker.y + gate.picker:height() + 48,
        buttonHeight = 44, spacing = 12,
    })
    gate.focus = gate.focus or "picker"
end

function gate.enter(self, opts)
    opts = opts or {}
    gate.player = opts.player or Player.active
    -- STANDING HERE IS BEING OUT OF THE HOLE, so the company is topped back up -- to the ceiling a
    -- wound leaves them, not through it (models/wound.lua's healShare).
    --
    -- THE BONES ARE NOT SET HERE ANY MORE. Wound.clear stood beside this line and an expedition's
    -- injuries ended the moment anybody stood on either town screen. They end at the Ward now
    -- (data/buildings/the_ward.lua) -- free if you rest them off, paid if you want them gone today --
    -- and the stair is emphatically not the Ward: a company that walks down to look at the hole and
    -- climbs back out has not been treated by doing so.
    -- THE RUN LIVES ON THE PLAYER, and that is the whole of the descent joining the campaign save.
    --
    -- It used to be a throwaway profile in a file of its own (Descent.FILE), because the descent was a
    -- separate game mode that banked nothing. It is the game now: the prologue's avatar and the Rowan
    -- sworn beside her walk into this city and down this stair, so there is ONE company, ONE save, and
    -- the floor stack rides on the player like everything else it owns.
    -- FLOORS AN OLDER GENERATOR LAID ARE THROWN AWAY HERE (Descent.pruneStaleFloors), which is the one
    -- moment it is safe: nobody is standing on a floor, and the company is about to be handed a fresh
    -- one anyway. A board kept from before a pass existed is a photograph of an older dungeon -- the
    -- newest half of the floor simply never appears on it, with nothing on screen to say why.
    --
    -- SAID OUT LOUD when it happens, because it takes maps the player drew. Anything they had left
    -- lying on one of those floors is in the stash rather than gone.
    local stale, rescued = Descent.pruneStaleFloors(gate.player)
    local staleNotice
    if (stale or 0) > 0 then
        staleNotice = "The rift has shifted. " .. stale ..
            (stale == 1 and " floor is" or " floors are") .. " not as you mapped them"
            .. ((rescued or 0) > 0
                and (", and what you had left down there is back in the stash.")
                or ".")
        Player.save()
    end

    local fresh = not (opts.run or gate.player.descentRun)
    -- Kept on the state because gate:build reads it: which stairs the menu may offer depends on whether
    -- this is a new expedition or one already standing on a floor (see the descend rows).
    gate.fresh = fresh
    gate.run = opts.run or gate.player.descentRun or Descent.new(gate.player)
    gate.player.descentRun = gate.run
    -- A FRESH EXPEDITION OPENS A FRESH PURSE (models/scrip.lua). Scrip is the run's own coin: it is
    -- handed out by the floors, spent at their stops, and burned at whatever exit the company takes, so
    -- the number a run starts on is a constant rather than something carried in from town.
    --
    -- ON THE FRESH BRANCH ONLY. A company standing at this screen mid-expedition -- resumed from a save,
    -- or woken here after a wipe with the run intact -- keeps what it has not spent; topping them back
    -- up to the opening would pay a company for having been beaten, and would make the Gate a place to
    -- refill by climbing the stair and turning round.
    if fresh then gate.player.gold = math.max(gate.player.gold or 0, Descent.OPENING_GOLD) end
    gate.panel = nil
    gate.wiped = opts.wiped
    -- WHAT A ROUT ACTUALLY COST, said on the screen the company wakes up on.
    --
    -- This read "The company went down on floor N. They are still there, and so is everything they were
    -- carrying." Both halves were false: the bodies wake HERE (that is what this screen is), and for a
    -- stretch after the pile system was deleted nothing at all stayed behind. The haul stays behind
    -- again (models/descent.lua's Descent.dropPack), and nothing else does -- so the line names the
    -- floor, the number of pieces and where they are, because those three are the whole of what the
    -- player has to decide about.
    --
    -- SILENT ON THE PACK WHEN THERE IS NONE. A company that wiped carrying nothing it had found lost
    -- nothing, and telling them their pack is waiting would send them down for an empty tile.
    --
    -- AND IT QUOTES NO COUNT, because the readout beside the purse already does (see gate.draw) and it
    -- keeps doing so on every visit after this one. What this line is FOR is the half the readout
    -- cannot say: that the rout took nothing they owned. That is the sentence a player needs in the
    -- five seconds after losing a company, and it is worth the whole width of the screen on its own.
    gate.notice = nil
    if opts.wiped then
        local pack
        for _, p in ipairs(Descent.lostPacks(gate.player)) do
            if p.floor == opts.wiped then pack = p break end
        end
        gate.notice = "The company was routed on floor " .. opts.wiped .. ". They walked out with "
            .. "everything they walked in with"
            .. (pack and "; what they found down there stayed where they fell." or ".")
    end
    -- THE TWO NOTICES COEXIST. A company can wake here routed AND find the rift re-laid, and the
    -- block above owns this band by clearing it -- so the stale-floor line is appended rather than
    -- assigned, or a rout would silently swallow the one message that explains a map going missing.
    if staleNotice then
        gate.notice = gate.notice and (gate.notice .. "  " .. staleNotice) or staleNotice
    end
    require("models.sound").music("music.menu")
    require("ui.screen_fx").reset()
    gate:build()

    -- THE TALLY EXPLAINS ITSELF, ONCE, THE FIRST TIME IT IS ON SCREEN -- which is the first time the
    -- company has turned back, since that mark is what draws the meter at all (Descent.everClimbedOut,
    -- set the instant the stair is taken). So by the time this opens, the marks are already behind it.
    --
    -- A WINDOW RATHER THAN A BUBBLE, because the tally is a FEATURE and not a control: a number, three
    -- rules that move it and a failure state at the top. A tail on the readout can say "this climbs when
    -- you come up"; it cannot say what filling it costs. See ui/panels/tutorial_note.lua for where that
    -- line is drawn. The descend row keeps its bubble -- "press this" is exactly what a bubble is for.
    --
    -- It replaces a ten-line scene in which Iselle stood at the stair and said the same thing in
    -- character. The mark is spent when the window is CLOSED (a modal has certainly been read), and it
    -- is saved there rather than passed through the switch, which would not survive a quit.
    --
    -- PARKED WITH THE THING IT TEACHES (Descent.COUNT_PARKED). The window opened on the first climb-out
    -- and explained a meter that no longer moves and is no longer drawn -- a tutorial for a feature the
    -- player will never see, and the most confusing possible kind, since it describes a breach that
    -- cannot happen. The mark is deliberately NOT spent on the way past: a company that never saw the
    -- window is still owed it if the tally is ever un-parked.
    if not Descent.COUNT_PARKED
        and Descent.everClimbedOut(gate.player) and not Descent.tallyTaught(gate.player) then
        -- The words live in data/conversations/tutorial/conversation_tutorial_notes.lua, like every
        -- other line the tutorial speaks, so they are stamped and translated with no wiring here. The
        -- window quotes no figure and so takes no tokens: the count's constants belong on the meter
        -- drawn beside it, not welded into a clause a translator cannot move and that goes stale the
        -- day the constant does.
        gate.panel = TutorialNote.new({
            title = Locale.line(NOTES, "tally_title"),
            body = Locale.line(NOTES, "tally_body"),
            onClose = function()
                gate.panel = nil
                Descent.markTallyTaught(gate.player)
                Player.save()
            end,
        })
    end
end

function gate.update(dt)
    countMeter:update(dt)
    if gate.panel then
        if gate.panel.update then gate.panel:update(dt) end
    elseif gate.menu then
        gate.menu:update(dt)
    end
end

function gate.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Gate", 0, 48, Scale.WIDTH, "center")

    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("A counter, a lamp, and a hole in the ground.", 0, 94, Scale.WIDTH, "center")

    if gate.notice then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.accentAmber)
        love.graphics.printf(gate.notice, Scale.WIDTH / 2 - 340, 126, 680, "center")
    end

    -- WHO GOES DOWN, and the count is the whole header. The list itself is the menu (gate:build's
    -- rosterRows) -- it reads and it chooses, because drawing the eight names twice to do those two
    -- jobs separately would be two lists of the same company.
    --
    -- The count is here rather than on a row because it is the thing that explains a press that did
    -- nothing: at four of four, another name simply does not take.
    local p = gate.player or {}
    love.graphics.setFont(headFont)
    Theme.set(Theme.ink)
    local going = #Descent.party(gate.run, gate.player)
    love.graphics.printf("Who goes down   " .. going .. " / " .. Descent.PARTY_MAX,
        Scale.WIDTH / 2 - 340, 178, 330, "left")
    if #(p.roster or {}) == 0 then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody.", Scale.WIDTH / 2 - 340, 208, 300, "left")
    elseif gate.picker then
        gate.picker:draw()
    end

    love.graphics.setFont(headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf((p.gold or 0) .. " gold", Scale.WIDTH / 2 + 40, 178, 300, "right")

    -- ...and the other half of the ledger, which is the map rather than the tally.
    --
    -- The count meter stood here and is parked with it (Descent.COUNT_PARKED). What belongs at the mouth
    -- of the stair now is how much of it this company has drawn -- the same figure the city's plate
    -- carries, said where the decision it informs is actually taken (see the descend rows in build).
    local mapped = Descent.mapped(p)
    if mapped > 0 then
        love.graphics.setFont(Theme.body(13))
        Theme.set(Theme.muted)
        love.graphics.printf("Mapped to floor " .. mapped .. " of " .. Descent.FLOORS,
            Scale.WIDTH / 2 + 40, 250, 300, "right")
        love.graphics.setColor(1, 1, 1)
    end

    -- WHAT IS STILL LYING DOWN THERE, and it stands on this screen rather than only in the rout's
    -- notice, because the notice is shown once and a pack outlives the session that dropped it. A
    -- player who quits after a bad night and comes back tomorrow has to be able to find out where their
    -- gear is without dying again to be told.
    --
    -- IN THE WARNING COLOUR, not the muted one: this is the only thing on the screen that is costing
    -- the player something right now (ui/theme.lua's accentWeapon, the hostile/attention family).
    local packs = Descent.lostPacks(p)
    if #packs > 0 then
        local line
        if #packs == 1 then
            line = "Your pack lies on floor " .. packs[1].floor ..
                   " -- " .. packs[1].count .. (packs[1].count == 1 and " piece" or " pieces")
        else
            local n, floors = 0, {}
            for i, pk in ipairs(packs) do n = n + pk.count; floors[i] = pk.floor end
            line = n .. " pieces lie on floors " .. table.concat(floors, ", ")
        end
        love.graphics.setFont(Theme.body(13))
        Theme.set(Theme.accentWeapon)
        love.graphics.printf(line, Scale.WIDTH / 2 + 40, 274, 300, "right")
        love.graphics.setColor(1, 1, 1)
    end

    -- WHAT THEY CAN REACH DOWN THERE, said before the stair rather than discovered at the bottom of it.
    --
    -- The stash does not come down (states/game.lua's Use panel, Player.partyRestoratives) -- a trip is
    -- supplied by what the four who walk down are carrying in their grids. A player who learns that rule
    -- by opening an empty Use panel on floor four has been taught it by being punished, which is the one
    -- way this game does not teach. One line, on the screen where the pack is still changeable.
    --
    -- MEASURED OFF THE PICKER RATHER THAN PLACED. It was authored at a fixed y = 250 and drew straight
    -- through the four expedition plates, which start at 206 and are as tall as the roster under them.
    -- The picker owns that rect and is the only thing that knows how tall it is, so this sits under
    -- whatever it turns out to be -- and the menu below is measured off the same number, so the two
    -- cannot drift apart.
    if gate.picker then
        love.graphics.setFont(Theme.body(13))
        Theme.set(Theme.muted)
        love.graphics.printf("They carry what is in their grids. The stash stays here.",
            gate.picker.x, gate.picker.y + gate.picker:height() + 6, 520, "left")
        love.graphics.setColor(1, 1, 1)
    end

    if gate.menu then gate.menu:draw() end

    -- THE FIRST VISIT'S ONE INSTRUCTION, pinned to the row that takes them down.
    --
    -- This replaces a whole scene. A sponsor used to be standing at the top of the stair the first time
    -- the company walked in, and the last thing she did was tell them to go down -- twenty lines to
    -- deliver one instruction the player could not otherwise guess. The instruction is now a bubble on
    -- the button, which is where an instruction belongs (ui/coach_bubble.lua is the half of the tutorial
    -- allowed to say "click"), and it is spent by the DEED: it stands until they actually descend, so a
    -- player who walks in, reads the company over and walks back out is coached again next time.
    --
    -- Not drawn under a panel or over the hover card -- a modal owns the screen it opened, and a bubble
    -- pointing at a button behind it is pointing at nothing the player can press.
    if not gate.panel and gate.menu and not Descent.gateCoached(gate.player) then
        for _, item in ipairs(gate.menu.items) do
            if item.coach and item.x then
                -- Authored with a leading {select} (conversation_tutorial_city.lua); coachLine hands
                -- back the sentence without it plus the cap to draw, or the whole thing in words when
                -- the device has no button worth drawing.
                local text, key = Locale.coach(CITY, "gate_stair")
                CoachBubble.draw(text, { x = item.x, y = item.y, w = item.w, h = item.h },
                                 { prefer = "above", key = key })
                break
            end
        end
    end


    -- The hovered body's card, LAST of the screen's own layers. A full one is most of the screen tall
    -- (ui/body_tooltip.lua), so drawn with the company it would be clipped by the two buttons under it;
    -- and it is skipped entirely while a panel is up, since a modal owns the screen it opened over.
    if gate.picker and not gate.panel then gate.picker:drawHover() end

    if gate.panel then gate.panel:draw() end

    -- The numbers behind the stair, in a development build only (ui/seed_readout.lua). Here as well as
    -- on the board because this is the screen a descent is COMMITTED from: the rift below is dealt
    -- before the stair is taken, so a run can be written down -- or recognised as one already seen --
    -- without walking into it first.
    SeedReadout.draw(gate.player, gate.run)
end

-- ---------------------------------------------------------------------------
-- Input: the panel owns it while one is open, else the menu
-- ---------------------------------------------------------------------------

local function route(name, ...)
    local target = gate.panel or gate.menu
    if target and target[name] then return target[name](target, ...) end
end

-- THE PICKER GETS FIRST REFUSAL ON THE MOUSE, and the menu takes whatever it declines. A pointer needs
-- no focus model -- it is already pointing at the thing it means -- so the Tab hand-off below exists
-- only for the two inputs that cannot.
local function pickerFirst(name, ...)
    if gate.panel then return route(name, ...) end
    local p = gate.picker
    if p and p[name] and p[name](p, ...) then return true end
    return route(name, ...)
end

function gate.mousemoved(x, y)
    if not gate.panel and gate.picker then gate.picker:mousemoved(x, y) end
    return route("mousemoved", x, y)
end
function gate.mousepressed(x, y, b) return pickerFirst("mousepressed", x, y, b) end
function gate.mousereleased(x, y, b)
    if gate.panel then return route("mousereleased", x, y, b) end
    if gate.picker then return gate.picker:mousereleased(x, y, b) end
end
function gate.wheelmoved(dx, dy) return route("wheelmoved", dx, dy) end
function gate:cursorKind(x, y)
    local target = gate.panel or gate.menu
    if target and target.cursorKind then return target:cursorKind(x, y) end
    return "arrow"
end

-- TAB AND THE SHOULDERS MOVE BETWEEN THE TWO HALVES of this screen -- the plates and the two actions --
-- which is the hand-off ui/panels/party.lua already keeps between a character's grid and the stash. It
-- exists for the keyboard and the pad alone; a pointer is always already on the half it means.
local function toggleFocus()
    gate.focus = (gate.focus == "menu") and "picker" or "menu"
    return true
end

function gate.keypressed(key)
    if gate.panel then return route("keypressed", key) end
    if key == "escape" then
        -- A held body is put down before the screen is left, or Escape would mean two things at once.
        if gate.picker and gate.picker.held then gate.picker.held = nil return true end
        return State.switch(require("states.hub"))
    end
    if key == "tab" then return toggleFocus() end
    if gate.focus == "picker" and gate.picker and gate.picker:keypressed(key) then return true end
    return route("keypressed", key)
end

function gate.gamepadpressed(joystick, button)
    if gate.panel then return route("gamepadpressed", joystick, button) end
    if button == "leftshoulder" or button == "rightshoulder" then return toggleFocus() end
    if button == "b" then
        if gate.picker and gate.picker.held then gate.picker.held = nil return true end
        return State.switch(require("states.hub"))
    end
    if gate.focus == "picker" and gate.picker
        and gate.picker:gamepadpressed(joystick, button) then return true end
    return route("gamepadpressed", joystick, button)
end

return gate
