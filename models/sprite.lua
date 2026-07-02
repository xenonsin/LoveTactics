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
    if love and love.graphics and love.graphics.newImage then
        local ok, result = pcall(love.graphics.newImage, path)
        if ok then image = result end
    end

    cache[path] = image
    return image
end

return Sprite
