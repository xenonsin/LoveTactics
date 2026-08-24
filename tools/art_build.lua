-- The art build: regenerate everything composed, then let drawn art win.
--
--     & "E:\LOVE\lovec.exe" . art-build           # regenerate + overlay + stamp the manifest
--     & "E:\LOVE\lovec.exe" . art-build overlay    # copy art/ over assets/ only
--     & "E:\LOVE\lovec.exe" . art-build stale      # exit 1 if assets/ is behind its inputs
--
-- WHY THIS EXISTS, and why it is a copy rather than a guard.
--
-- The obvious way to protect commissioned art from the composer is to make the composer skip files that
-- already exist -- which is what `char-compose assets` does today, and what `icon-compose assets` was
-- about to be taught. It is the wrong instinct, and it fails in both directions at once:
--
--   * It blocks the thing the override exists for. Drop a new silhouette in art/bases/ and a
--     skip-if-exists composer regenerates nothing, so the delivered glyph changes not one pixel on
--     screen. The whole point of a base swap is that it propagates.
--   * It silently pins stale output. There are 64 committed char tokens under assets/chars/, so
--     `char-compose assets` has been skipping them for good: edit a silhouette table and those 64 keep
--     their old picture while the other 135 update. Same root cause, opposite symptom.
--
-- So precedence is BUILD ORDER, not a filesystem check:
--
--   1. compose everything, unconditionally -- assets/ is generated output and wholly disposable
--   2. copy art/ over assets/ -- drawn art wins because it lands second
--
-- Which also retires a convention that was being held in a human's memory: docs/art-assets.md used to warn
-- that "bespoke art belongs on its own path" because re-running the composer would overwrite it. Under the
-- overlay, commissioned art is not in the composer's write path at all, and it is tracked in git besides
-- (assets/ is gitignored -- that is correct for generated output and was quietly wrong for paid work).
--
-- art/bases/ is the one subtree NOT copied: those SVGs are pipeline INPUT, consumed by the composers
-- through tools/icon_source.lua, not art the game loads.

local Hash = require("tools.art_hash")

local M = {}

local ART_ROOT = "art"
local ASSET_ROOT = "assets"
local MANIFEST = "assets/.art-manifest"

-- art/bases/ holds base SVGs the composers read; everything else under art/ is finished art the game
-- loads by path. Returns the assets/ path a given art/ file overlays onto, or nil if it is input.
function M.overlayTarget(path)
    local rel = path:match("^" .. ART_ROOT .. "/(.+)$")
    if not rel then return nil end
    if rel == "bases" or rel:match("^bases/") then return nil end
    return ASSET_ROOT .. "/" .. rel
end

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function ensureDir(rel)
    local built
    for part in rel:gmatch("[^/]+") do
        built = built and (built .. "/" .. part) or part
        if not love.filesystem.getInfo(built) then
            os.execute(string.format('mkdir "%s" 2>nul', projectPath(built):gsub("/", "\\")))
        end
    end
end

-- Binary copy. love.filesystem cannot write outside the save directory, so both halves go through io.
local function copyFile(srcRel, dstRel)
    local src, serr = io.open(projectPath(srcRel), "rb")
    if not src then return nil, tostring(serr) end
    local data = src:read("*a")
    src:close()

    ensureDir(dstRel:match("^(.*)/[^/]+$") or ASSET_ROOT)
    local dst, derr = io.open(projectPath(dstRel), "wb")
    if not dst then return nil, tostring(derr) end
    dst:write(data)
    dst:close()
    return true
end

-- Every file under art/, recursively. Sorted so a run is deterministic and its log is diffable.
local function walk(rel, acc)
    acc = acc or {}
    local items = love.filesystem.getDirectoryItems(rel)
    table.sort(items)
    for _, name in ipairs(items) do
        local child = rel .. "/" .. name
        local info = love.filesystem.getInfo(child)
        if info and info.type == "directory" then
            walk(child, acc)
        elseif info then
            acc[#acc + 1] = child
        end
    end
    return acc
end

local function overlay()
    if not love.filesystem.getInfo(ART_ROOT) then
        print("  art/ does not exist -- nothing drawn to overlay yet")
        return 0, 0
    end

    local copied, failed, inputs = 0, 0, 0
    for _, path in ipairs(walk(ART_ROOT)) do
        local target = M.overlayTarget(path)
        if not target then
            inputs = inputs + 1
        else
            local ok, err = copyFile(path, target)
            if ok then
                copied = copied + 1
            else
                failed = failed + 1
                print("  FAIL " .. path .. " -- " .. tostring(err))
            end
        end
    end
    print(string.format("  overlaid %d drawn file(s) onto %s/  (%d base SVG(s) left as pipeline input)",
        copied, ASSET_ROOT, inputs))
    return copied, failed
end

local function readManifest()
    if not love.filesystem.getInfo(MANIFEST) then return nil end
    local raw = love.filesystem.read(MANIFEST)
    return raw and raw:match("hash%s*=%s*([0-9a-f]+)") or nil
end

local function writeManifest(hash, fields)
    local text = table.concat({
        "-- GENERATED by `. art-build`. The fingerprint of the inputs assets/ was last built from.",
        "-- Compare with `. art-build stale`. See tools/art_hash.lua for what goes into it.",
        "hash = " .. hash,
        "fields = " .. tostring(fields),
        "",
    }, "\n")
    ensureDir(ASSET_ROOT)
    local file, err = io.open(projectPath(MANIFEST), "w")
    if not file then
        print("  could not stamp the manifest: " .. tostring(err))
        return
    end
    file:write(text)
    file:close()
end

function M.run(args)
    local mode = {}
    for _, a in ipairs(args or {}) do mode[a] = true end

    if mode.stale then
        local hash, fields = Hash.inputs()
        local stamped = readManifest()
        print("")
        if not stamped then
            print("  assets/ carries no build manifest -- it has never been built, or was built before")
            print("  `. art-build` existed. Run `. art-build`.")
            print(string.format("  inputs now: %s (%d fields)", hash, fields))
            love.event.quit(1)
            return
        end
        if stamped ~= hash then
            print("  STALE -- assets/ was built from different inputs than the ones on disk now.")
            print("  built from: " .. stamped)
            print(string.format("  inputs now: %s (%d fields)", hash, fields))
            print("")
            print("  A blueprint, a layer table or a base SVG has moved since the last build. Run")
            print("  `. art-build`. (A re-tier pass does this every time: `repRank` drives the frame")
            print("  thickness and the tier pips, so rebalancing invalidates the art it touched.)")
            love.event.quit(1)
            return
        end
        print("  FRESH -- assets/ matches its inputs (" .. hash .. ", " .. fields .. " fields)")
        return
    end

    if mode.overlay then
        print("")
        print("Overlaying drawn art over generated")
        local _, failed = overlay()
        print("")
        if failed > 0 then love.event.quit(1) end
        return
    end

    -- The full build. Composing is unconditional in both stages -- `force` on the char composer is what
    -- turns off its skip-if-exists, without which the 64 committed tokens would never refresh.
    print("")
    print("Art build -- 1/3  composing item icons")
    require("tools.icon_compose").run({ "assets" })

    print("Art build -- 2/3  composing character tokens")
    require("tools.char_compose").run({ "assets", "force" })

    print("Art build -- 3/3  overlaying drawn art")
    local _, failed = overlay()

    local hash, fields = Hash.inputs()
    writeManifest(hash, fields)
    print(string.format("  stamped %s (%s, %d fields)", MANIFEST, hash, fields))
    print("")
    if failed > 0 then love.event.quit(1) end
end

M.overlay = overlay

return M
