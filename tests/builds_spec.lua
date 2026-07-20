-- Tests for models/builds.lua: publishing a build and finding one to fight.
--
-- Run against an in-memory backend rather than the disk one. That is not a convenience -- it is the
-- claim the module is making. If the storage seam is narrow enough to swap for a table here, it is
-- narrow enough to swap for a server later, which is the whole reason the module exists.
--
-- Pure logic, runs headless.

local Builds = require("models.builds")
local Build = require("models.build")
local Character = require("models.character")
local Item = require("models.item")

-- The four functions a backend owes, over a plain table.
local function memoryBackend()
    local files = {}
    return {
        files = files,
        write = function(id, source) files[id] = source return true end,
        read = function(id) return files[id] end,
        list = function()
            local ids = {}
            for id in pairs(files) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
        remove = function(id) files[id] = nil return true end,
    }
end

-- Swap the backend for the duration of `fn`, always putting the real one back.
local function withBackend(backend, fn)
    local saved = Builds.backend
    Builds.backend = backend
    local ok, err = pcall(fn)
    Builds.backend = saved
    if not ok then error(err, 0) end
end

local function teamFor(authorName)
    local c = Character.instantiate("character_knight")
    c.name = authorName .. "'s knight"
    c.inventory = {}
    Character.addItem(c, Item.instantiate("weapon_iron_sword"))
    c.aiRules = {
        { enabled = true, priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "exists" } },
    }
    return { c }
end

local function buildBy(id, name)
    return Build.from(teamFor(name or id), { author = { id = id, name = name or id }, prestige = 4 })
end

return {
    {
        name = "publishing stores a build under a stable id and reads back the same team",
        fn = function()
            local backend = memoryBackend()
            withBackend(backend, function()
                local id = assert(Builds.publish(buildBy("author-a", "Ana")))
                assert(id == Builds.idFor("author-a"), "the id should be derived from the author")
                assert(backend.files[id], "and something should actually have been written")

                local pool = Builds.eligible()
                assert(#pool == 1, "one build published, one found")
                assert(pool[1].build.author.name == "Ana", "and it is hers")
            end)
        end,
    },
    {
        -- Pressing Play PvP publishes the team you are standing behind now. A pile of a player's
        -- abandoned drafts is a backlog, not a matchmaking pool.
        name = "publishing again replaces that author's build rather than piling up",
        fn = function()
            local backend = memoryBackend()
            withBackend(backend, function()
                Builds.publish(buildBy("author-a", "Ana"))
                Builds.publish(buildBy("author-a", "Ana"))
                Builds.publish(buildBy("author-a", "Ana"))

                local count = 0
                for _ in pairs(backend.files) do count = count + 1 end
                assert(count == 1, "one author, one build, got " .. count)
            end)
        end,
    },
    {
        -- The rule the whole feature turns on. A mirror of your own team and your own gambits is
        -- not an opponent; it is a puzzle you already wrote the answer to.
        name = "a player is never offered their own build",
        fn = function()
            withBackend(memoryBackend(), function()
                Builds.publish(buildBy("me", "Keno"))
                Builds.publish(buildBy("them", "Vasska"))

                local pool = Builds.eligible({ excludeAuthor = "me" })
                assert(#pool == 1, "only the other player's build should be offered")
                assert(pool[1].build.author.id == "them", "and it should be theirs")

                for _ = 1, 20 do
                    local picked = Builds.pick({ excludeAuthor = "me" })
                    assert(picked and picked.build.author.id == "them",
                        "picking should never land on your own build")
                end
            end)
        end,
    },
    {
        name = "with nobody else published there is simply no opponent",
        fn = function()
            withBackend(memoryBackend(), function()
                Builds.publish(buildBy("me", "Keno"))
                assert(#Builds.eligible({ excludeAuthor = "me" }) == 0, "an empty pool is empty")
                assert(Builds.pick({ excludeAuthor = "me" }) == nil,
                    "and picking from it gives nothing rather than erroring")
            end)
        end,
    },
    {
        -- Somebody else's file, possibly from a newer version or naming content this install does
        -- not have. One bad entry must not take the listing down with it.
        name = "an unreadable build is skipped, not fatal",
        fn = function()
            local backend = memoryBackend()
            withBackend(backend, function()
                Builds.publish(buildBy("good", "Ana"))
                backend.files["build_garbage"] = "this is not lua at all {{{"
                backend.files["build_future"] =
                    "return { version = 999, author = { id = \"x\" }, party = {} }"

                local pool = Builds.eligible()
                assert(#pool == 1, "only the readable build should survive the listing")
                assert(pool[1].build.author.id == "good", "and it is the good one")
            end)
        end,
    },
    {
        -- eligible() restores before offering, so anything it hands back can actually be fought.
        name = "a build naming content this install lacks never reaches the pool",
        fn = function()
            local backend = memoryBackend()
            withBackend(backend, function()
                local broken = buildBy("ghost", "Ghost")
                broken.party[1].inventory[1] = { id = "item_that_was_deleted", quantity = 1 }
                backend.write(Builds.idFor("ghost"), Build.encode(broken))
                Builds.publish(buildBy("good", "Ana"))

                local pool = Builds.eligible()
                assert(#pool == 1, "the unfightable build should be filtered out before it is offered")
                assert(pool[1].build.author.id == "good", "leaving the one that works")
            end)
        end,
    },
    {
        name = "a build with no author is refused, because it could never be kept from anyone",
        fn = function()
            withBackend(memoryBackend(), function()
                local anon = Build.from(teamFor("nobody"), {})
                local id, why = Builds.publish(anon)
                assert(id == nil, "an unattributed build should not publish")
                assert(why and why:find("who made it"), "and should say why: " .. tostring(why))
            end)
        end,
    },
    {
        -- A rule carrying a closure cannot be written. Better to fail at the moment somebody
        -- publishes than to leave a corrupt entry for whoever tries to fight it.
        name = "a build that cannot be encoded fails at publish, not at fight time",
        fn = function()
            withBackend(memoryBackend(), function()
                local bad = buildBy("author-a", "Ana")
                bad.party[1].aiRules[1].whenFn = function() return true end
                local id, why = Builds.publish(bad)
                assert(id == nil, "it should refuse to publish")
                assert(why and why:find("encode"), "and name the problem: " .. tostring(why))
            end)
        end,
    },
    {
        name = "an author id can never escape the builds directory",
        fn = function()
            withBackend(memoryBackend(), function()
                local id = Builds.idFor("../../save")
                assert(not id:find("%.%."), "no traversal should survive: " .. id)
                assert(not id:find("/"), "and no separators either: " .. id)
            end)
        end,
    },
    {
        name = "picking is reproducible when the caller supplies the roll",
        fn = function()
            withBackend(memoryBackend(), function()
                Builds.publish(buildBy("a", "Ana"))
                Builds.publish(buildBy("b", "Bo"))
                Builds.publish(buildBy("c", "Cy"))

                local first = Builds.pick({ rng = function() return 1 end })
                local same = Builds.pick({ rng = function() return 1 end })
                local third = Builds.pick({ rng = function() return 3 end })
                assert(first.id == same.id, "the same roll should land on the same opponent")
                assert(third.id ~= first.id, "and a different roll on a different one")
            end)
        end,
    },
}
