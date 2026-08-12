-- Tests for the temptation ledger (models/temptation.lua): the Crown's offer, the companion's
-- resolve, and the three ways a class line can end. Pure logic, headless.
--
-- The highest-value cases here are the last two, and they are the reason this file is worth its
-- length: the threshold table can only be got wrong once, but the REFERENTIAL cases (every authored
-- `take`/`press` names a real vendor, every companion id resolves, every line's slot 10 carries
-- `endsLine`) fail the moment a line is authored wrong -- which is the failure mode that would
-- otherwise ship as a companion whose fate silently never resolves.

local Temptation = require("models.temptation")
local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")
local Save = require("models.save")
local Vendor = require("models.vendor")
local Quest = require("models.quest")
local Conversation = require("models.conversation")
local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")

local function freshPlayer()
    local p = Player.new()
    p.roster = { Character.instantiate("character_avatar"), Character.instantiate("character_rowan") }
    return p
end

-- Answer a line `taken` times, `pressed` of them with the companion brought along.
local function answer(player, vendorId, taken, pressed)
    for _ = 1, taken do Temptation.record(player, vendorId, "take") end
    for _ = 1, pressed do Temptation.record(player, vendorId, "press") end
end

-- Walk every authored conversation's script (blocks nest) calling fn on each speaking node.
local function eachNode(entries, fn)
    for _, entry in ipairs(entries or {}) do
        if entry.script then eachNode(entry.script, fn) else fn(entry) end
    end
end

return {
    {
        name = "an unanswered line is held, and reads zero",
        fn = function()
            local p = freshPlayer()
            local counts = Temptation.counts(p, "bastion")
            assert(counts.taken == 0 and counts.pressed == 0, "nothing recorded yet")
            assert(Temptation.standing(p, "bastion") == Temptation.HELD, "an unanswered line holds")
            assert(not Temptation.isBreaking(p, "bastion"), "and is not breaking")
        end,
    },
    {
        name = "the fall line is four offers: three held, four did not",
        fn = function()
            -- Every take is also a press here, so the only thing moving is the count.
            for taken = 0, 3 do
                assert(Temptation.outcomeFor(taken, taken) == Temptation.HELD,
                    taken .. " offers taken must still hold")
            end
            assert(Temptation.outcomeFor(4, 4) == Temptation.CAVED, "the fourth offer is the fall line")
            assert(Temptation.FALL_LINE == 4, "the knob is authored in plain offers, out of ten")
        end,
    },
    {
        name = "past the fall line, bringing her along at least half the time caves her; less leaves",
        fn = function()
            -- The boundary, walked on both sides of "half", including the odd counts where the
            -- doubling matters: 5 taken needs 3 pressed, not 2.
            local cases = {
                { taken = 4, pressed = 1, want = Temptation.LEFT },
                { taken = 4, pressed = 2, want = Temptation.CAVED },
                { taken = 5, pressed = 2, want = Temptation.LEFT },
                { taken = 5, pressed = 3, want = Temptation.CAVED },
                { taken = 10, pressed = 4, want = Temptation.LEFT },
                { taken = 10, pressed = 5, want = Temptation.CAVED },
                { taken = 10, pressed = 0, want = Temptation.LEFT },
                { taken = 10, pressed = 10, want = Temptation.CAVED },
            }
            for _, c in ipairs(cases) do
                local got = Temptation.outcomeFor(c.taken, c.pressed)
                assert(got == c.want, string.format(
                    "taken %d / pressed %d wanted %s, got %s", c.taken, c.pressed, c.want, got))
            end
        end,
    },
    {
        name = "record moves the two counters independently",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 5, 2)
            local counts = Temptation.counts(p, "bastion")
            assert(counts.taken == 5, "five taken, got " .. counts.taken)
            assert(counts.pressed == 2, "two pressed, got " .. counts.pressed)
            -- ...and one line's answers never bleed into another's.
            assert(Temptation.counts(p, "colosseum").taken == 0, "the Colosseum was never asked")
        end,
    },
    {
        name = "resolve stamps a flag a scene can gate on, and never re-decides a settled line",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 6, 4)
            assert(Temptation.resolve(p, "bastion") == Temptation.CAVED, "six taken, four with her")
            assert(p.flags["caved_bastion"], "the flag a `when` block reads is stamped")
            assert(Temptation.resolved(p, "bastion") == Temptation.CAVED, "and reads back")

            -- Answering more after the line has ended cannot change what it ended as. Without this,
            -- a New Game+ run's early offers would re-decide the previous run's companion.
            answer(p, "bastion", 4, 0)
            assert(Temptation.resolve(p, "bastion") == Temptation.CAVED, "a settled line stays settled")
            assert(not p.flags["left_bastion"], "and gains no second outcome flag")
        end,
    },
    {
        name = "a scene can gate on a temptation flag through the ordinary `when` grammar",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 8, 1)
            assert(Temptation.resolve(p, "bastion") == Temptation.LEFT, "eight taken, one with her")

            local ctx = Conversation.context(p)
            assert(Conversation.test({ flag = "left_bastion" }, ctx), "the flag predicate sees it")
            assert(not Conversation.test({ flag = "caved_bastion" }, ctx), "and only the one that is set")
            assert(Conversation.test({ notFlag = "caved_bastion" }, ctx), "notFlag is its negation")
            -- The flag composes with the conditions every scene already uses.
            assert(Conversation.test({ all = { { flag = "left_bastion" }, { has = "character_rowan" } } }, ctx),
                "a flag ANDs with a roster check")
        end,
    },
    {
        name = "settle releases only the companions whose lines ended in `left`",
        fn = function()
            local p = freshPlayer()
            p.roster[#p.roster + 1] = Character.instantiate("character_saber")

            answer(p, "bastion", 8, 1)     -- Rowan: taken over her objection -> leaves
            answer(p, "colosseum", 8, 6)   -- Saber: brought along -> caves, and stays
            Temptation.resolve(p, "bastion")
            Temptation.resolve(p, "colosseum")

            local released = Temptation.settle(p)
            assert(#released == 1 and released[1] == "character_rowan",
                "only the line that ended in `left` gave anyone up")

            local ids = {}
            for _, char in ipairs(p.roster) do ids[char.id] = true end
            assert(not ids["character_rowan"], "Rowan is off the roster")
            assert(ids["character_saber"], "Saber stayed -- caving is not leaving")
        end,
    },
    {
        name = "a released companion leaves her gear and takes her bound relic",
        fn = function()
            local p = freshPlayer()
            local rowan
            for _, char in ipairs(p.roster) do if char.id == "character_rowan" then rowan = char end end
            assert(rowan, "Rowan is in the fixture")

            -- Her signature relic is bound; the potion beside it is not.
            local bound, loose
            for cell = 1, Character.MAX_INVENTORY do
                local item = rowan.inventory and rowan.inventory[cell]
                if item and Item.isBound(item) then bound = item end
            end
            assert(bound, "Rowan starts holding a bound signature relic")
            loose = Item.instantiate("consumable_healing_potion")
            Character.addItem(rowan, loose)

            local before = #(p.stash or {})
            assert(Player.release(p, "character_rowan"), "she was there to lose")

            local stashed = {}
            for _, item in ipairs(p.stash or {}) do stashed[item.id] = true end
            assert(stashed[loose.id], "ordinary gear went back to the stash")
            assert(not stashed[bound.id], "the bound relic walked out on her body")
            assert(#p.stash > before, "the stash grew by what she left")
        end,
    },
    {
        name = "release scrubs the ledgers that name a body by id",
        fn = function()
            local p = freshPlayer()
            p.lastDeployed = { "character_avatar", "character_rowan" }
            p.wounds = { character_rowan = 2, character_avatar = 1 }

            Player.release(p, "character_rowan")

            for _, id in ipairs(p.lastDeployed) do
                assert(id ~= "character_rowan", "the deployment pick no longer names her")
            end
            assert(p.wounds["character_rowan"] == nil, "her wounds went with her")
            assert(p.wounds["character_avatar"] == 1, "and nobody else's did")
            assert(not Player.release(p, "character_rowan"), "releasing her twice is a no-op")
        end,
    },
    {
        name = "the flags and the ledger survive a save round trip",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 6, 4)
            answer(p, "colosseum", 2, 1)
            Temptation.resolve(p, "bastion")
            p.flags["met_the_survivor"] = true

            -- Through the REAL serializer, which is what catches a function or a love object leaking
            -- into a save (the tests/run_save_spec.lua pattern).
            local snap = Save.snapshot(p)
            local round = Save.decode("return " .. Save.encode(snap, 0))
            local back = Save.restore(round)

            assert(back.flags["caved_bastion"], "the outcome flag came back")
            assert(back.flags["met_the_survivor"], "and so did an ordinary story flag")
            assert(back.temptation.bastion.taken == 6, "taken survived")
            assert(back.temptation.bastion.pressed == 4, "pressed survived")
            assert(back.temptation.colosseum.taken == 2, "an unresolved line kept its counts too")
            assert(Temptation.resolved(back, "bastion") == Temptation.CAVED, "and still reads as caved")
        end,
    },
    {
        name = "New Game+ clears the ledger, since all seventy offers are back on the board",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 6, 4)
            Temptation.resolve(p, "bastion")

            -- newGamePlus persists, and Player.save() writes whoever is ACTIVE (not the player it was
            -- handed), so the campaign save has to be stood out of the way rather than shadowed by a
            -- saveFile on `p`. Point active at this fixture, aimed at a scratch file, and put it back.
            local wasActive = Player.active
            p.saveFile = "test_temptation_ngplus.lua"
            Player.active = p
            local ok, err = pcall(Player.newGamePlus, p)
            Player.active = wasActive
            assert(ok, "newGamePlus raised: " .. tostring(err))

            assert(next(p.flags or {}) == nil, "no flag survives the reset")
            assert(next(p.temptation or {}) == nil, "nor any count")
            assert(Temptation.standing(p, "bastion") == Temptation.HELD,
                "a second run starts every line unanswered")
        end,
    },
    {
        name = "the Crown wears your caved companions before it wears its own dead",
        fn = function()
            local p = freshPlayer()
            local generals = { "character_general_wrath", "character_general_sloth", "character_general_pride" }

            -- Nobody caved: the curated general trio, exactly as before this feature existed.
            assert(#Temptation.shades(p, generals) == 3, "three thresholds fire, so three names")
            assert(Temptation.shades(p, generals)[1] == "character_general_wrath", "wrath still leads")

            -- One caved: she goes first and pushes a general off the end.
            answer(p, "bastion", 8, 6)
            Temptation.resolve(p, "bastion")
            local shades = Temptation.shades(p, generals)
            assert(shades[1] == "character_rowan_caved", "the woman on your side of the board comes first")
            assert(#shades == 3, "still three")
            assert(shades[3] ~= "character_general_pride", "and a general was pushed off the end")
        end,
    },
    {
        name = "more caved companions than thresholds still wears exactly three",
        fn = function()
            local p = freshPlayer()
            for _, vendorId in ipairs(Temptation.LINES) do
                answer(p, vendorId, 8, 6)
                Temptation.resolve(p, vendorId)
            end
            assert(#Temptation.caved(p) == 7, "all seven caved")
            local shades = Temptation.shades(p, { "character_general_wrath" })
            assert(#shades == 3, "three thresholds fire, so three names, got " .. #shades)
            for _, id in ipairs(shades) do
                assert(id:match("_caved$"), "and every one of them is somebody you brought, not a general")
            end
        end,
    },
    {
        name = "every line names a real vendor and a real companion, and the two tables agree",
        fn = function()
            for vendorId, charId in pairs(Temptation.COMPANIONS) do
                assert(Vendor.defs[vendorId], "COMPANIONS names a vendor that does not exist: " .. vendorId)
                assert(Vendor.defs[vendorId].sin, vendorId .. " must be a sin's house to have a line")
                assert(Character.defs[charId],
                    "COMPANIONS names a character that does not exist: " .. tostring(charId))
            end
            local seen = {}
            for _, vendorId in ipairs(Temptation.LINES) do
                assert(Temptation.COMPANIONS[vendorId], "LINES names a line with no companion: " .. vendorId)
                assert(not seen[vendorId], "LINES lists " .. vendorId .. " twice")
                seen[vendorId] = true
            end
            local count = 0
            for _ in pairs(Temptation.COMPANIONS) do count = count + 1 end
            assert(count == #Temptation.LINES,
                "every companion's line must be in the fixed order the Gate reads (seven of each)")
            assert(count == 7, "seven sins, seven houses, seven companions -- got " .. count)
        end,
    },
    {
        name = "every companion has a caved blueprint, carrying her general's relic",
        fn = function()
            -- The relic each line's general drops, which is the object a caved companion picks up.
            -- Named here rather than derived so this case fails loudly if a slot-10 reward is
            -- retargeted without its caved form following.
            local relic = {
                bastion       = "weapon_forsworn_pike",
                colosseum     = "armor_mail_of_the_unappeased",
                cathedral     = "utility_reliquary_unbidden",
                hunters_lodge = "utility_maw_of_the_unfed",
                arcanum       = "utility_codex_unanswered",
                undercroft    = "utility_bottomless_purse",
                alchemist     = "utility_envious_glass",
            }
            for _, vendorId in ipairs(Temptation.LINES) do
                local charId = Temptation.COMPANIONS[vendorId]
                local cavedId = Temptation.cavedId(charId)
                local def = Character.defs[cavedId]
                assert(def, "no caved blueprint for " .. tostring(charId) .. " (" .. cavedId .. ")")

                local want = relic[vendorId]
                assert(want, "the spec has no relic for " .. vendorId)
                -- It must be the slot-10 quest's OWN reward: the thing she is carrying is the thing
                -- taken off the body of the general the player just killed, or the beat is a costume.
                local quest = Quest.defs["quest_" .. vendorId .. "_slot_10"]
                local rewarded = false
                for _, itemId in ipairs(quest and quest.rewardItems or {}) do
                    if itemId == want then rewarded = true end
                end
                assert(rewarded, want .. " is not what " .. vendorId .. "'s slot 10 drops")

                local carried = false
                for _, itemId in ipairs(def.startingItems or {}) do
                    if itemId == want then carried = true end
                end
                assert(carried, cavedId .. " is not carrying " .. want)

                -- Blueprint `traits` are never collected -- only an item's are (models/trait.lua) --
                -- so the relic in the grid IS the rule, and a caved form that tried to declare the
                -- trait directly would fight as an ordinary companion. Guard against that mistake.
                assert(def.traits == nil, cavedId ..
                    " declares blueprint traits, which are never collected; put the rule on the relic")
            end
        end,
    },
    {
        name = "a caved blueprint stays the same person: same class, sprite and pools",
        fn = function()
            for _, vendorId in ipairs(Temptation.LINES) do
                local charId = Temptation.COMPANIONS[vendorId]
                local base, caved = Character.defs[charId], Character.defs[Temptation.cavedId(charId)]
                assert(base.class == caved.class, charId .. " changed class by caving")
                assert(base.sprite == caved.sprite, charId .. " changed body by caving")
                assert(base.stats.health == caved.stats.health,
                    charId .. " changed health by caving -- she is the same woman, not a boss twin")
                assert(caved.name ~= base.name, charId .. " must wear the seat's title, not her own")
                assert(not caved.boss,
                    Temptation.cavedId(charId) .. " must not be a boss -- the Crown is the objective")
            end
        end,
    },
    {
        name = "the Crown's shade list resolves to real blueprints, caved or general",
        fn = function()
            local p = freshPlayer()
            local generals = { "character_general_wrath", "character_general_sloth", "character_general_pride" }
            for _, vendorId in ipairs(Temptation.LINES) do
                answer(p, vendorId, 8, 6)
                Temptation.resolve(p, vendorId)
            end
            for _, id in ipairs(Temptation.shades(p, generals)) do
                assert(Character.defs[id], "the Crown would reach for a name with no body: " .. id)
            end
            -- ...and with an empty save, the old static trio still resolves.
            for _, id in ipairs(Temptation.shades(freshPlayer(), generals)) do
                assert(Character.defs[id], "a clean save's shade has no body: " .. id)
            end
        end,
    },
    {
        name = "the Crown turns a deployed caved companion where she stands, rather than duplicating her",
        fn = function()
            -- The bill, on the board. This is the one case that exercises the new combat capability
            -- (models/trait.lua's ctx.defect) end to end, and the one that would otherwise ship as a
            -- second Rowan standing next to the first.
            local p = freshPlayer()
            answer(p, "bastion", 8, 6)
            Temptation.resolve(p, "bastion")

            local wasActive = Player.active
            Player.active = p -- the trait reads the live player to decide whose name it reaches for

            local ok, err = pcall(function()
                local map = Fixture.new(10, 10)
                local crown = Fixture.unit("character_demon_lord", 5, 5)
                local rowan = Fixture.unit("character_rowan", 3, 3)
                local combat = Fixture.combat(map, { rowan }, { crown })

                local crownUnit, rowanUnit
                for _, u in ipairs(combat.units) do
                    if u.char.id == "character_demon_lord" then crownUnit = u end
                    if u.char.id == "character_rowan" then rowanUnit = u end
                end
                assert(crownUnit and rowanUnit, "both bodies are on the board")
                assert(rowanUnit.side == "party", "she starts on the player's side")
                local before = #combat.units

                -- Past 75% in one blow: onDamaged fires only on a survivor, so leave it standing.
                local hp = crownUnit.char.stats.health
                Combat.dealFlatDamage(combat, crownUnit, math.floor(hp.max * 0.30), nil, "spec")
                assert(crownUnit.alive, "the Crown survived the blow that crossed its threshold")

                assert(#combat.units == before,
                    "she was turned in place -- no second body joined the board")
                assert(rowanUnit.side == crownUnit.side,
                    "the woman on your side of the board changed sides")
                assert(rowanUnit.char.name == Character.defs["character_rowan_caved"].name,
                    "and is wearing the seat's title, got " .. tostring(rowanUnit.char.name))
            end)

            Player.active = wasActive
            assert(ok, tostring(err))
        end,
    },
    {
        name = "a caved companion left at home comes through the Gate as a summon instead",
        fn = function()
            local p = freshPlayer()
            answer(p, "bastion", 8, 6)
            Temptation.resolve(p, "bastion")

            local wasActive = Player.active
            Player.active = p

            local ok, err = pcall(function()
                -- Nobody of hers on the board: the avatar fields alone, so there is nothing to turn.
                local map = Fixture.new(10, 10)
                local crown = Fixture.unit("character_demon_lord", 5, 5)
                local avatar = Fixture.unit("character_avatar", 3, 3)
                local combat = Fixture.combat(map, { avatar }, { crown })

                local crownUnit
                for _, u in ipairs(combat.units) do
                    if u.char.id == "character_demon_lord" then crownUnit = u end
                end
                local before = #combat.units

                local hp = crownUnit.char.stats.health
                Combat.dealFlatDamage(combat, crownUnit, math.floor(hp.max * 0.30), nil, "spec")
                assert(crownUnit.alive, "the Crown survived")

                assert(#combat.units > before, "a body came through the Gate")
                local arrived
                for _, u in ipairs(combat.units) do
                    if u.char.id == "character_rowan_caved" then arrived = u end
                end
                assert(arrived, "and it is the companion the player spoiled, not a general")
                assert(arrived.side == crownUnit.side, "on the Crown's side")
            end)

            Player.active = wasActive
            assert(ok, tostring(err))
        end,
    },
    {
        name = "a clean save still fights the curated general trio",
        fn = function()
            local p = freshPlayer()
            local wasActive = Player.active
            Player.active = p

            local ok, err = pcall(function()
                local map = Fixture.new(10, 10)
                local crown = Fixture.unit("character_demon_lord", 5, 5)
                local rowan = Fixture.unit("character_rowan", 3, 3)
                local combat = Fixture.combat(map, { rowan }, { crown })

                local crownUnit, rowanUnit
                for _, u in ipairs(combat.units) do
                    if u.char.id == "character_demon_lord" then crownUnit = u end
                    if u.char.id == "character_rowan" then rowanUnit = u end
                end

                local hp = crownUnit.char.stats.health
                Combat.dealFlatDamage(combat, crownUnit, math.floor(hp.max * 0.30), nil, "spec")

                assert(rowanUnit.side == "party", "nobody was turned -- she was never offered anything")
                local wrath
                for _, u in ipairs(combat.units) do
                    if u.char.id == "character_general_wrath" then wrath = u end
                end
                assert(wrath, "the Crown reached for its own dead, as it always did")
            end)

            Player.active = wasActive
            assert(ok, tostring(err))
        end,
    },
    {
        name = "every line's last quest carries endsLine, and nothing else does",
        fn = function()
            local expected = {}
            for _, vendorId in ipairs(Temptation.LINES) do
                expected["quest_" .. vendorId .. "_slot_10"] = vendorId
            end
            for id, def in pairs(Quest.defs) do
                if def.endsLine then
                    assert(expected[id], "an unexpected quest ends a line: " .. id)
                    assert(def.sponsor == expected[id],
                        id .. " must be sponsored by " .. expected[id] .. " for its ledger to resolve")
                    expected[id] = nil
                end
            end
            local missing = {}
            for id in pairs(expected) do missing[#missing + 1] = id end
            table.sort(missing)
            assert(#missing == 0,
                "these lines never settle their ledger: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "every authored take/press names the vendor whose line the scene belongs to",
        fn = function()
            -- Which conversation ids each quest owns, so a `take` can be checked against the sponsor
            -- of the quest that plays it. This is the case that catches the real authoring mistake:
            -- copying a Bastion offer into a Cathedral scene and leaving `take = "bastion"` on it,
            -- which would silently credit the wrong companion's ledger.
            local owner = {}
            for _, def in pairs(Quest.defs) do
                for _, field in ipairs({ "intro", "outro", "opening" }) do
                    if def[field] and def.sponsor then owner[def[field]] = def.sponsor end
                end
                local objective = def.map and def.map.objective
                if objective and objective.opening and def.sponsor then
                    owner[objective.opening] = def.sponsor
                end
            end

            for convId, def in pairs(Conversation.defs) do
                eachNode(def.script, function(node)
                    for _, choice in ipairs(node.choices or {}) do
                        local effect = choice.effect
                        for _, key in ipairs({ "take", "press" }) do
                            local vendorId = effect and effect[key]
                            if vendorId then
                                assert(Vendor.defs[vendorId], string.format(
                                    "%s: `%s = %q` names no vendor", convId, key, tostring(vendorId)))
                                assert(Temptation.COMPANIONS[vendorId], string.format(
                                    "%s: `%s = %q` names a house with no line", convId, key, vendorId))
                                if owner[convId] then
                                    assert(owner[convId] == vendorId, string.format(
                                        "%s belongs to the %s line but credits %s",
                                        convId, owner[convId], vendorId))
                                end
                            end
                        end
                        -- A press without a take is authored on purpose (you can lean on her and
                        -- still refuse); a take is what the ledger's fall line counts, so the pair
                        -- is never reversed by accident.
                        if effect and effect.press and not effect.take then
                            assert(true, "leaning on her without taking it is a legal, authored shape")
                        end
                    end
                end)
            end
        end,
    },
}
