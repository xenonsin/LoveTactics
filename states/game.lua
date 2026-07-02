local State = require("states")

local game = {}

local player = {
    x = 400,
    y = 300,
    radius = 20,
    speed = 200,
}

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
end

function game.keypressed(key)
    if key == "escape" then
        State.switch(require("states.menu"))
    end
end

return game
