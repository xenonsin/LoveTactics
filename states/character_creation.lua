-- Character creation: who the avatar is, asked at the front of a New Game. One step: the NAME
-- (ui/name_entry.lua).
--
-- IT IS BACK AT THE FRONT (2026-10-16). For a stretch it was the Charter's roll, filled in after the first
-- fight; the author moved it back to where it used to be, after the opening narration and before the first
-- fight on floor one (states/prologue.lua's beat list), so the name exists before anybody says it. It
-- returns to the prologue through prologue.resume.
--
-- IT ASKS NO CLASS, NO LOOK AND NO PEOPLE, and all three were asked here once. The avatar starts as a
-- Novice and earns every class afterwards, one at a time, as an achievement (a deed + a Charter Seal) -- so
-- a trade picked on the first page would hand over what the rest of the game is built to make you earn.
-- The look went with it: the default body is worn (Player.applyAvatarBody still runs). The PEOPLE went
-- last (2026-10-16, the author's call): once creation moved in front of the first fight, a race's stat
-- line and grid grant (Character.setRace) were on the body the lesson in data/tutorials/village.lua is
-- counted against, and it broke for seven of the eight peoples. The avatar is the blueprint's human.
-- Character.setRace and the per-body save of `race` stay on disk with no caller in play.
--
-- There is no Back: behind the name is only the opening narration.

local NameEntry = require("ui.name_entry")
local Player = require("models.player")

local creation = {}

local widget

local function avatarOf(player)
    for _, char in ipairs((player and player.roster) or {}) do
        if char.id == "character_avatar" then return char end
    end
    return nil
end

-- The name is written onto the live avatar, and the prologue picks up where it left off.
local function finish(name)
    local p = Player.active
    local avatar = avatarOf(p)
    if p then p.name = name or p.name end
    if avatar and name then avatar.name = name end
    Player.applyAvatarBody(p)
    require("states.prologue").resume()
end

function creation.enter()
    widget = NameEntry.new({
        prompt = "What's your name?",
        text = Player.active and Player.active.name or nil,
        onSubmit = finish,
    })
end

function creation.update(dt)
    widget:update(dt)
end

-- The name step draws its own full screen (field + on-screen keyboard).
function creation.draw()
    widget:draw()
end

function creation.mousemoved(x, y)
    widget:mousemoved(x, y)
end

function creation:cursorKind(x, y)
    return widget:cursorKind(x, y)
end

function creation.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

function creation.wheelmoved(dx, dy)
    if widget.wheelmoved then widget:wheelmoved(dx, dy) end
end

function creation.keypressed(key)
    widget:keypressed(key)
end

-- Typed letters arrive here, not through keypressed.
function creation.textinput(t)
    widget:textinput(t)
end

function creation.gamepadpressed(joystick, button)
    widget:gamepadpressed(joystick, button)
end

return creation
