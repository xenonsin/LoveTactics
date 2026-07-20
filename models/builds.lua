-- Where builds live: publishing your own, and finding somebody else's to fight.
--
-- This is deliberately a thin seam over a BACKEND rather than a pile of file handling. Today the
-- backend is the local disk, which is enough to play the whole feature single-machine; the intended
-- end state is a server that collects builds and hands them back out. When that arrives it replaces
-- `Builds.backend` and nothing above this line changes -- not the hub panel, not the party picker,
-- not the battle entry. Keeping the swap to one table is the entire point of the module.
--
-- A backend is four functions over opaque string ids:
--   write(id, source)  -- store; overwrite if it exists
--   read(id)           -- the source string, or nil
--   list()             -- every id it holds
--   remove(id)         -- delete; optional
--
-- Sources are what Build.encode produces, so a backend never needs to understand a build -- it moves
-- text around. That is also what makes the server version boring to write.

local Build = require("models.build")

local Builds = {}

-- ---------------------------------------------------------------------------
-- Local disk backend (the default)
-- ---------------------------------------------------------------------------

local DIR = "builds"

local LocalDisk = {}

function LocalDisk.write(id, source)
    love.filesystem.createDirectory(DIR)
    return love.filesystem.write(DIR .. "/" .. id .. ".lua", source)
end

function LocalDisk.read(id)
    local path = DIR .. "/" .. id .. ".lua"
    if not love.filesystem.getInfo(path) then return nil end
    return love.filesystem.read(path)
end

function LocalDisk.list()
    local out = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        local id = name:match("^(.+)%.lua$")
        if id then out[#out + 1] = id end
    end
    table.sort(out) -- a stable order, so a listing does not reshuffle between visits
    return out
end

function LocalDisk.remove(id)
    return love.filesystem.remove(DIR .. "/" .. id .. ".lua")
end

Builds.LocalDisk = LocalDisk
Builds.backend = LocalDisk

-- ---------------------------------------------------------------------------
-- Publishing
-- ---------------------------------------------------------------------------

-- An author's id turned into something safe to use as a filename, and stable enough that the same
-- player always lands on the same one. Anything outside a conservative set becomes an underscore --
-- a SteamID is digits, but a local id might be a typed name, and a build must never be able to
-- write outside its own directory because somebody called themselves "../../save".
local function slug(authorId)
    return (tostring(authorId or "anonymous"):gsub("[^%w%-_]", "_"))
end

-- The id a given author's build is stored under. One build per author, by design: pressing Play PvP
-- publishes the team you are playing NOW, and a pile of a player's abandoned drafts is not a
-- matchmaking pool, it is a backlog of teams nobody chose to stand behind.
function Builds.idFor(authorId)
    return "build_" .. slug(authorId)
end

-- Publish `build` (a snapshot from Build.from), replacing this author's previous one.
-- Returns the id, or nil plus a reason.
function Builds.publish(build)
    if type(build) ~= "table" then return nil, "not a build" end
    local authorId = build.author and build.author.id
    if not authorId then return nil, "a build must say who made it" end

    -- Encode before writing so a build that cannot be serialized fails HERE, loudly, rather than
    -- being discovered later by whoever tried to fight it.
    local ok, source = pcall(Build.encode, build)
    if not ok then return nil, "could not encode build: " .. tostring(source) end

    local id = Builds.idFor(authorId)
    local wrote = Builds.backend.write(id, source)
    if wrote == false then return nil, "could not store build" end
    return id
end

-- ---------------------------------------------------------------------------
-- Finding one to fight
-- ---------------------------------------------------------------------------

-- Every build worth offering, newest-agnostic and already proven fightable.
--
-- `opts.excludeAuthor` drops that author's own build -- always pass it. Facing a mirror of your own
-- team and your own gambits is not an opponent; it is a puzzle you wrote the answer to.
--
-- A build that fails to decode or restore is SKIPPED rather than raised: it is somebody else's file,
-- possibly from a newer version or naming content this install does not have (see Build.restore),
-- and one unreadable entry must not take the whole list down with it. Restoring here rather than at
-- the last moment means a build handed back from this function is one that can actually be fought.
function Builds.eligible(opts)
    opts = opts or {}
    local out = {}
    for _, id in ipairs(Builds.backend.list()) do
        local source = Builds.backend.read(id)
        local snap = source and Build.decode(source)
        local authorId = snap and snap.author and snap.author.id
        if snap and not (opts.excludeAuthor and authorId == opts.excludeAuthor) then
            if Build.restore(snap) then
                out[#out + 1] = { id = id, build = snap }
            end
        end
    end
    return out
end

-- One of them, or nil when there is nobody to fight yet. `rng` is injectable so a caller that wants
-- a reproducible opponent (a replay, a spec) can supply one; it defaults to math.random.
function Builds.pick(opts)
    local pool = Builds.eligible(opts)
    if #pool == 0 then return nil end
    local roll = (opts and opts.rng) or math.random
    return pool[roll(#pool)]
end

return Builds
