local State = require("states")

local game = {}

local player = {
    x = 400,
    y = 300,
    radius = 20,
    speed = 200,
}

-- Clickable "Back" button so a mouse-only player can leave the scene without
-- reaching for Esc.
local backButton = { x = 16, y = 16, w = 96, h = 36 }

local function backContains(x, y)
    return x >= backButton.x and x <= backButton.x + backButton.w
        and y >= backButton.y and y <= backButton.y + backButton.h
end

function game.update(dt)
    if love.keyboard.isDown("w") then player.y = player.y - player.speed * dt end
    if love.keyboard.isDown("s") then player.y = player.y + player.speed * dt end
    if love.keyboard.isDown("a") then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("d") then player.x = player.x + player.speed * dt end
end

function game.draw()
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", player.x, player.y, player.radius)

    -- Back button.
    love.graphics.setColor(0.20, 0.23, 0.32)
    love.graphics.rectangle("fill", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", backButton.x, backButton.y, backButton.w, backButton.h, 6, 6)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf("Back", backButton.x, backButton.y + backButton.h / 2 - 8,
        backButton.w, "center")
    love.graphics.setColor(1, 1, 1)
end

function game.mousepressed(x, y, button)
    if button == 1 and backContains(x, y) then
        State.switch(require("states.menu"))
    end
end

function game.keypressed(key)
    if key == "escape" then
        State.switch(require("states.menu"))
    end
end

return game
