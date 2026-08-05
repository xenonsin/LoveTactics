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
            -- Asserted on the GENERIC body at the head of each shelf. A class silhouette is that body's
            -- property now: the named occupants of the same shelf (Saber, Rowan, Kaya, Ren) are lifted
            -- out by CHARACTER_SILHOUETTE, or every knight in the game reads as every other one.
            assert(slug("character_fighter") == "delapouite/sword-brandish", "fighter -> sword-brandish")
            assert(slug("character_knight") == "delapouite/knight-banner", "knight -> knight-banner")
            assert(slug("character_archer") == "delapouite/archer", "hunter -> archer")
            assert(slug("character_alchemist") == "lorc/bubbling-flask", "alchemist -> bubbling-flask")
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
            assert(slug("character_wolf_grunt") == "lorc/wolf-head", "wolf_grunt -> wolf head")
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
            local dl, dlid = resolve("character_demon_grunt")
            assert(Char.kindOf(dl, dlid) == "demon", "demon_grunt is a demon")
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
            -- The master used to keep the rank swordman body deliberately -- he holds at the gate rather
            -- than driving the column. That read cost him a body of his own (he was pixel-identical to a
            -- bandit), so he now wears the trade he leads instead: still not the wagon, still not a mook.
            assert(slug("character_caravan_master") == "lorc/trade", "the master reads as the trade, not a mook")
        end,
    },
    {
        -- The whole point of the boss silhouette: a classless general is otherwise a rank swordman, and
        -- only the gold badge would tell them apart. The overlord figure lifts them.
        name = "a classless boss (a general) is lifted to the overlord silhouette",
        fn = function()
            -- Asserted on a SYNTHETIC classless boss rather than borrowed off a real blueprint. It used to
            -- be character_bandit_chief, until the bestiary pass made him a Thief with a class and a
            -- discipline (docs/bestiary.md) and this test failed for a content reason rather than a
            -- composer one. A rule about the guesser should be fixtured on the guesser's inputs: the lift
            -- catches a boss that is classless and has earned no body of its own, and that is now stated
            -- directly instead of depending on some particular mook staying anonymous forever.
            assert(Char.slugFor({ boss = true }, "nameless_warband_boss") == Char.BOSS_SILHOUETTE,
                "a rank classless boss -> overlord")
            assert(Char.BOSS_SILHOUETTE ~= Char.HUMANOID_DEFAULT, "the boss figure must differ from the rank one")
            assert(slug("character_general_gluttony") == "lorc/gluttony", "a general reads as its sin, not the lift")
            assert(slug("character_general_greed") == "delapouite/coins-pile", "... and no two of them agree")
        end,
    },
    {
        -- ... but a boss that HAS a class keeps its role look -- Amana is priest + boss, and should read
        -- priest, not overlord. Class wins; the gold badge still marks the boss.
        name = "a classed boss keeps its class silhouette, not the overlord",
        fn = function()
            local def, id = resolve("character_priest")
            assert(def.class == "priest", "fixture: the generic priest")
            assert(Char.slugFor(def, id) == "lorc/prayer", "priest -> prayer")
            local am, amid = resolve("character_amana")
            assert(am.class == "priest" and am.boss, "fixture: amana is a priest boss")
            assert(Char.slugFor(am, amid) ~= Char.BOSS_SILHOUETTE, "a classed boss is never lifted to the overlord")
        end,
    },
    {
        -- The whole point of the discipline tier: a discipline's exemplar wears its OWN body, distinct
        -- from its class shelf. necromancer/summoner/etc. are all class = mage but must not share the
        -- wizard token. Keyed off the exemplar pointer in data/disciplines/*.lua.
        name = "a discipline's exemplar reads as its discipline silhouette, not its class",
        fn = function()
            assert(slug("character_necromancer") == "delapouite/skull-staff", "necromancer -> skull staff, not wizard")
            assert(slug("character_champion") == "lorc/laurel-crown", "champion -> laurel crown")
            assert(slug("character_totemist") == "delapouite/totem", "totemist -> totem, over its priest class")
            assert(slug("character_ninja") == "darkzaitzev/ninja-head", "ninja -> ninja head")
            -- the five freshly-authored exemplar bodies resolve to their discipline too
            assert(slug("character_apothecary") == "delapouite/remedy", "apothecary -> remedy")
            assert(slug("character_elementalist") == "delapouite/prism", "elementalist -> prism")
            assert(slug("character_exorcist") == "lorc/holy-symbol", "exorcist -> holy symbol")
            assert(slug("character_beastmaster") == "lorc/hound", "beastmaster -> hound")
        end,
    },
    {
        -- A discipline exemplar that is also a boss reads as the DISCIPLINE, not the overlord lift -- the
        -- gold badge (compose(), not slugFor) still marks it a boss. warlord regressed here once.
        name = "a discipline exemplar that is a boss keeps its discipline silhouette, not the overlord",
        fn = function()
            local def, id = resolve("character_warlord")
            assert(def.boss, "fixture: the warlord is a boss")
            assert(Char.slugFor(def, id) == "lorc/tattered-banner", "warlord -> banner, not overlord")
        end,
    },
    {
        -- The exemplar pointer, not a substring, is what fires the discipline tier -- so a lookalike id is
        -- untouched and a former exemplar (the generic mage, no longer Elementalist's) falls back to class.
        name = "the discipline tier fires only for the exemplar, never a lookalike id",
        fn = function()
            assert(slug("character_demon_champion") ~= "lorc/laurel-crown", "demon_champion is not the Champion")
            assert(slug("character_demon_champion") == "delapouite/devil-mask", "it is its own demon body")
            assert(slug("character_mage") == "delapouite/wizard-face", "the generic mage is no discipline's exemplar")
            assert(Char.disciplineFor("champion") == "champion", "the exemplar maps to its discipline")
            assert(Char.disciplineFor("demon_champion") == nil, "a lookalike maps to nothing")
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
    {
        -- THE invariant this whole tier exists for: no two blueprints wear the same body. It used to be
        -- badly false -- 51 of the blueprints resolved to 15 pictures, so the seven sin generals were one
        -- token and eight knights were another, and a player could not tell the Road-Captain from Rowan.
        -- Because the tiers below are bucket-wide (a class, a kind, `boss`), a NEW blueprint silently
        -- joins whichever bucket it derives into and re-collides -- which is exactly what this catches.
        -- The fix is one line in CHARACTER_SILHOUETTE, never art.
        name = "no two characters resolve to the same silhouette",
        fn = function()
            -- The deliberate exceptions: the same character in two blueprints, which must READ the same.
            local ALIAS = { character_saber_bout = "character_saber" }
            local owner, clashes = {}, {}
            for key, def in pairs(defs) do
                local s = Char.slugFor(def, Char.tokenId(key))
                local held = owner[s]
                if not held then
                    owner[s] = key
                elseif ALIAS[key] ~= held and ALIAS[held] ~= key then
                    clashes[#clashes + 1] = string.format("%s and %s both wear %s", held, key, s)
                end
            end
            assert(#clashes == 0, "silhouettes collide:\n    " .. table.concat(clashes, "\n    "))
        end,
    },
    {
        -- The other half of uniqueness, and the half that bites even when the silhouettes differ: the
        -- composer writes ONE file per distinct def.sprite and lets later blueprints ride along on it
        -- (see M.run). So two blueprints naming one path can never be told apart on the board no matter
        -- what they resolve to -- the Trapper wore the Bandit's art that way, which is where this started.
        name = "no two characters share a sprite file",
        fn = function()
            local ALIAS = { character_saber_bout = "character_saber" }
            local owner, clashes = {}, {}
            for key, def in pairs(defs) do
                local path = def.sprite
                if path then
                    local held = owner[path]
                    if not held then
                        owner[path] = key
                    elseif ALIAS[key] ~= held and ALIAS[held] ~= key then
                        clashes[#clashes + 1] = string.format("%s and %s both load %s", held, key, path)
                    end
                end
            end
            assert(#clashes == 0, "sprite paths collide:\n    " .. table.concat(clashes, "\n    "))
        end,
    },
}
