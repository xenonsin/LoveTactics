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

-- Is there actually a file at `path`? Sprite.load cannot answer this: it is TOLERANT by design and
-- hands back the path string when the art is missing, which is exactly right for "draw it if it is
-- there" and exactly wrong for "choose between two files". A caller picking a variant has to know which
-- of the two exists BEFORE it loads one, or it gets a string where the drawer wanted an image and falls
-- through to whatever that surface's no-art placeholder is (the board's bare letter disc).
--
-- Answered off love.filesystem rather than off a load attempt, for the reason the loader's own comment
-- gives at length: under love.js a failed newImage does not raise, it kills the main loop. Asking is
-- free and never touches the graphics device -- so this is also true under the headless tests, where
-- love.graphics is absent but the filesystem is not, and a spec can assert which file a body resolves to
-- without a window. No love.filesystem at all (a bare Lua host) answers false, which lands every caller
-- on its ordinary sprite.
function Sprite.exists(path)
    if type(path) ~= "string" then return false end
    return not not (love and love.filesystem and love.filesystem.getInfo
        and love.filesystem.getInfo(path))
end

return Sprite
