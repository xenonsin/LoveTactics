-- Regression guard for the character-token composer's GUESSING (tools/char_compose.lua) -- the same
-- "which picture does this blueprint resolve to?" contract the item pipeline guards for families.
--
-- Only the pure logic is exercised (kindOf / slugFor / tintFor / elementOf / tokenId): it
-- touches no love.graphics and no resvg, so a wrong guess turns a test red without rendering anything.
-- Deliberately NOT asserted here: that a resolved slug names a file on disk. The game-icons set lives
-- under vendor/ (gitignored, fetched by tools/icons/fetch.ps1), so a fresh clone has no icons and a
-- file-existence check would fail for reasons that have nothing to do with the guessing.

local Registry = require("models.registry")
local Char = require("tools.char_compose")

local defs = Registry.load("data/characters", "data.characters")

-- The runtime always feeds slugFor the tokenId (blueprint key minus the `character_` prefix), because
-- that is the string the keyword scan reads ("fire_elemental" -> element "fire"). Mirror that here.
local function resolve(key)
    local def = assert(defs[key], "no such blueprint: " .. tostring(key))
    return def, Char.tokenId(key)
end

local function slug(key)
    local def, id = resolve(key)
    return Char.slugFor(def, id)
end

local KNOWN_KINDS = {
    humanoid = true, beast = true, elemental = true,
    construct = true, demon = true, undead = true, object = true,
}

return {
    {
        name = "tokenId strips the character_ prefix (so the token lands at the sprite's path)",
        fn = function()
            assert(Char.tokenId("character_amana") == "amana", "prefix should be stripped")
            assert(Char.tokenId("character_fire_elemental") == "fire_elemental", "only the leading prefix")
        end,
    },
    {
        name = "a class humanoid resolves to its class silhouette",
        fn = function()
            -- Each of the seven shelves has a body of its own, so no two disciplines share a look --
            -- the archer (hunter) and Rowan (knight) used to both come out the generic swordman.
            assert(slug("character_saber") == "delapouite/sword-brandish", "fighter -> sword-brandish")
            assert(slug("character_rowan") == "delapouite/knight-banner", "knight -> knight-banner")
            assert(slug("character_archer") == "delapouite/archer", "hunter -> archer")
            assert(slug("character_ren") == "lorc/bubbling-flask", "alchemist -> bubbling-flask")
            assert(slug("character_mage") == "delapouite/wizard-face", "mage -> wizard face")
            -- The generic body stays the plain swordman -- distinct from the fighter's raised blade --
            -- so a classless mook never wears a discipline's silhouette.
            assert(slug("character_bandit") == "cathelineau/swordman", "classless -> swordman default")
            -- The player's avatar is classless too, but reads as a person of its own, not a rank mook.
            assert(slug("character_avatar") == "delapouite/person", "avatar -> person, not swordman")
        end,
    },
    {
        name = "a creature name-match wins over the humanoid fallback",
        fn = function()
            -- boar/wolf carry no class, so without the CREATURE_MATCH pass they would fall to the
            -- generic swordman; the direct match is what makes a boar token look like a boar.
            assert(slug("character_boar") == "caro-asercion/boar", "boar -> boar")
            assert(slug("character_wolf_alpha") == "lorc/wolf-head", "wolf_alpha -> wolf head")
        end,
    },
    {
        name = "an elemental resolves to its element silhouette and tint",
        fn = function()
            local def, id = resolve("character_fire_elemental")
            assert(Char.kindOf(def, id) == "elemental", "fire_elemental is an elemental")
            assert(Char.elementOf(id) == "fire", "its element word is fire")
            assert(Char.slugFor(def, id) == "carl-olsen/flame", "fire elemental -> flame")
            assert(Char.tintFor(def, id) == "#ef7d4a", "fire tint")
        end,
    },
    {
        name = "a demon/undead resolves by kind",
        fn = function()
            local dl, dlid = resolve("character_demon_lord")
            assert(Char.kindOf(dl, dlid) == "demon", "demon_lord is a demon")
            assert(Char.slugFor(dl, dlid) == "lorc/daemon-skull", "demon -> daemon skull")
            local mg, mgid = resolve("character_miller_ghost")
            assert(Char.kindOf(mg, mgid) == "undead", "miller_ghost is undead")
            assert(Char.slugFor(mg, mgid) == "lorc/ghost", "ghost -> ghost")
        end,
    },
    {
        name = "an object resolves to its terrain-register glyph",
        fn = function()
            local def, id = resolve("character_banner")
            assert(Char.kindOf(def, id) == "object", "banner is an object")
            assert(Char.slugFor(def, id) == "delapouite/flag-objective", "banner -> flag")
        end,
    },
    {
        -- The escort/defend NPCs earn a body of their own so they don't read as the rank swordman the
        -- units guarding them wear. The caravan is the wagon it drives (wood-tinted via `kind`); the
        -- survivor is a raised-hands plea. The caravan MASTER keeps the default, holding at the gate.
        name = "the escort/defend NPCs resolve to their own silhouettes",
        fn = function()
            assert(slug("character_survivor") == "sbed/help", "survivor -> raised-hands plea")
            assert(slug("character_caravan_driver") == "delapouite/caravan", "caravan_driver -> wagon")
            local cd, cdid = resolve("character_caravan_driver")
            assert(Char.tintFor(cd, cdid) == "#c9b58a", "the caravan is wood-tinted, not steel")
            assert(slug("character_caravan_master") == Char.HUMANOID_DEFAULT, "the master keeps the rank body")
        end,
    },
    {
        -- The whole point of the boss silhouette: a classless general is otherwise a rank swordman, and
        -- only the gold badge would tell them apart. The overlord figure lifts them.
        name = "a classless boss (a general) is lifted to the overlord silhouette",
        fn = function()
            assert(slug("character_general_wrath") == Char.BOSS_SILHOUETTE, "wrath general -> overlord")
            assert(slug("character_warlord") == Char.BOSS_SILHOUETTE, "warlord -> overlord")
            assert(Char.BOSS_SILHOUETTE ~= Char.HUMANOID_DEFAULT, "the boss figure must differ from the rank one")
        end,
    },
    {
        -- ... but a boss that HAS a class keeps its role look -- Amana is priest + boss, and should read
        -- priest, not overlord. Class wins; the gold badge still marks the boss.
        name = "a classed boss keeps its class silhouette, not the overlord",
        fn = function()
            local def, id = resolve("character_amana")
            assert(def.class == "priest" and def.boss, "fixture: amana is a priest boss")
            assert(Char.slugFor(def, id) == "lorc/prayer", "priest boss -> prayer, not overlord")
        end,
    },
    {
        -- The `kind` override is the correction seam (the icon pipeline's overrides.lua, in miniature):
        -- a wrongly-guessed body is fixed with one line rather than any art.
        name = "an explicit kind override wins over the derived kind",
        fn = function()
            -- `bandit` has no creature match and no class, so it would derive as humanoid; the override
            -- makes it a beast and the silhouette follows. (survivor/caravan_driver now carry name-matches
            -- of their own, so they no longer serve as the "falls through to humanoid" example.)
            local def, id = resolve("character_bandit")
            local forced = {}
            for k, v in pairs(def) do forced[k] = v end
            forced.kind = "beast"
            assert(Char.kindOf(def, id) == "humanoid", "bandit derives as humanoid without an override")
            assert(Char.kindOf(forced, id) == "beast", "the override wins")
            assert(Char.slugFor(forced, id) == "lorc/wolf-head", "beast -> wolf head silhouette")
        end,
    },
    {
        -- The load-bearing invariant: EVERY shipped blueprint resolves to a real slug/tint, so no
        -- character can slip through to a nil silhouette that would crash compose(). A new blueprint that
        -- resolves to nothing turns this red the moment it is added.
        name = "every character blueprint resolves to a non-empty slug and tint",
        fn = function()
            local count = 0
            for key, def in pairs(defs) do
                local id = Char.tokenId(key)
                local s, t = Char.slugFor(def, id), Char.tintFor(def, id)
                assert(type(s) == "string" and #s > 0, key .. " resolved to no silhouette")
                assert(type(t) == "string" and t:sub(1, 1) == "#", key .. " resolved to no tint")
                assert(KNOWN_KINDS[Char.kindOf(def, id)] or def.kind, key .. " resolved to an unknown kind")
                count = count + 1
            end
            assert(count > 40, "expected the full character roster, saw only " .. count)
        end,
    },
}
