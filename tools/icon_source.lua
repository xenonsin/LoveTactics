-- Where a composed icon's BASE SILHOUETTE comes from -- the one seam between the pipeline and the set
-- that answers it.
--
-- Both composers (tools/icon_compose.lua, tools/char_compose.lua) name their silhouettes by SLUG
-- ("lorc/broadsword"), and until now a slug named a file under vendor/game-icons and nowhere else --
-- which made the shipped look inseparable from game-icons.net. It is separable: a slug is an ADDRESS,
-- and this module decides which set answers it. Two roots, in order:
--
--   art/bases/<slug>.svg           commissioned, tracked, ships    <- preferred
--   vendor/game-icons/<slug>.svg   CC BY 3.0, gitignored, dev only <- fallback
--
-- So a delivered glyph takes over everywhere its slug is used the moment it lands -- one file re-skins
-- every icon that reduces to it -- and the vendored set keeps standing in for the slugs nobody has drawn
-- yet. The commission can therefore be accepted a glyph at a time and the exposure watched down to zero
-- (`. art-source`), rather than landing as one all-or-nothing swap.
--
-- Nothing downstream changes, because the SVG contract is the contract either root must meet:
--
--   * viewBox="0 0 512 512"
--   * a single flat foreground fill of #fff -- the composers substitute that fill to tint the layer, so
--     multi-colour or gradient art silently defeats the tint channel
--   * no background rect (BG_PATH below is stripped if present, the way game-icons ships one)
--   * transparent, readable as a silhouette at 64px and again greyed
--
-- The surgery that turns such a file into drop-in markup lived twice, once per composer, with a comment
-- in the second saying "same surgery as icon_compose.foreground". It lives here once now.

local M = {}

M.ART_ROOT = "art/bases"
M.VENDOR_ROOT = "vendor/game-icons"

-- Search order. ROOTS[1] is authoritative: a commissioned glyph must win over the vendored one, or
-- delivering art would change nothing on screen. tests/art_pipeline_spec.lua pins the order.
M.ROOTS = {
    { name = "art", path = M.ART_ROOT },
    { name = "vendor", path = M.VENDOR_ROOT },
}

-- game-icons ships a full-canvas background rect ahead of the foreground paths. Ours must not, but it
-- is stripped either way so a glyph exported from their editor drops in unmodified.
M.BG_PATH = '<path d="M0 0h512v512H0z"/>'

-- A well-formed slug is "<author>/<name>" -- the vendored set's own layout, kept for the commissioned
-- one so a slug means the same thing in both and a swap needs no remapping table.
function M.wellFormed(slug)
    return type(slug) == "string" and slug:match("^[%w][%w%-]*/[%w][%w%-]*$") ~= nil
end

function M.pathFor(slug, rootPath)
    return rootPath .. "/" .. slug .. ".svg"
end

-- Locate a slug. Returns path, root name ("art" | "vendor"); or nil plus why. Callers that only want to
-- know WHICH set answered (the source audit) read the second return and never the bytes.
function M.locate(slug)
    for _, root in ipairs(M.ROOTS) do
        local path = M.pathFor(slug, root.path)
        if love.filesystem.getInfo(path) then return path, root.name end
    end
    return nil, "no such icon in art/bases or vendor/game-icons: " .. tostring(slug)
end

function M.read(slug)
    local path, root = M.locate(slug)
    if not path then return nil, root end
    local raw = love.filesystem.read(path)
    if not raw then return nil, "unreadable: " .. path end
    return raw, root
end

-- Pull the recoloured foreground out of a base SVG: drop the <svg> wrapper, drop the full-canvas
-- background rect if there is one, recolour the #fff foreground to `tint`. Returns the inner markup (a
-- run of <path>s) ready to nest in a <g>, plus which root answered; or nil plus why.
function M.foreground(slug, tint)
    local raw, root = M.read(slug)
    if not raw then return nil, root end
    local inner = raw:match("<svg[^>]*>(.*)</svg>")
    if not inner then return nil, "unexpected SVG layout: " .. slug end
    inner = inner:gsub(M.BG_PATH:gsub("%p", "%%%0"), "", 1)
    -- Recolour explicit #fff fills; the enclosing <g fill> the composers add catches any path that
    -- inherited instead of declaring.
    inner = inner:gsub('fill="#fff"', string.format('fill="%s"', tint))
    return inner, root
end

return M
