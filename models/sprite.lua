-- Memoized sprite loader. Def files store asset paths (strings); instances
-- resolve them to shared love.graphics Image objects through this cache so the
-- same file is only loaded once.
--
-- Loading is tolerant: if the asset is missing, or love.graphics is unavailable
-- (e.g. a headless test), the original path string is returned instead of an
-- Image so callers never crash before the art exists.

local Sprite = {}

local cache = {}

function Sprite.load(path)
    if path == nil then return nil end
    if cache[path] ~= nil then return cache[path] end

    local image = path -- fallback: keep the path if it can't be loaded
    -- ASK BEFORE LOADING, rather than loading and catching the failure. The pcall below is still
    -- the backstop, but it must not be the ordinary route for missing art: under love.js a failed
    -- newImage does not merely raise a Lua error, it leaves the runtime unable to continue -- the
    -- frame finishes, the main loop is never scheduled again, and the canvas freezes on its last
    -- frame with no error anywhere. One absent portrait was enough to make New Game unplayable on
    -- the web while the same blueprint loaded fine on the desktop. getInfo keeps the whole art
    -- debt on the tolerated path it was always meant to be on (see the header).
    local missing = love and love.filesystem and love.filesystem.getInfo
        and not love.filesystem.getInfo(path)
    if not missing and love and love.graphics and love.graphics.newImage then
        local ok, result = pcall(love.graphics.newImage, path)
        if ok then image = result end
    end

    cache[path] = image
    return image
end

return Sprite
