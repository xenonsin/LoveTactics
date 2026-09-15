-- THE WAIT BUTTON SAYS WHAT IT WILL DO (ui/combat_panel.lua's CombatPanel.waitNote).
--
-- Every other plate in the battle panel is an item, and an item answers for itself under the cursor.
-- The bottom lane's button is chrome wearing a verb, and for a long while that verb was the whole
-- reading: WAIT, or DEFEND, or a song title, with no way to ask what any of them did. The kit that
-- swapped the button is somewhere else on the grid, and a player who has not gone looking for it is
-- being asked to press a word.
--
-- Driven through waitNote rather than the draw, for the reason tests/tile_tooltip_spec.lua gives: the
-- lines ARE what the player reads, and they read here without a window or a font. The three things
-- this file is actually guarding:
--
--   * the first line is Combat.WAIT_SWAP_NOTE's and nothing else -- the SAME sentence the granting
--     item's own tooltip prints, because a button and an item giving two accounts of one press is how
--     a player learns to trust neither;
--   * that sharing is real, not a copy that happens to match today (the last case reads the tooltip's
--     own source and fails if the sentences ever move back into it);
--   * the figures are the LIVE ones, resolved at the item's forge level, never a Curve printed as an
--     address and never the blueprint's ramp.

local Character = require("models.character")
local Combat = require("models.combat")
local CombatPanel = require("ui.combat_panel")
local Item = require("models.item")
local Status = require("models.status")

-- A body carrying one thing. The wait swap is found by Combat.waitBehavior walking the grid, so the
-- slot does not matter -- only that the item is an INSTANCE, which is what resolves its curves.
local function bearer(itemId)
    local char = Character.instantiate("character_knight")
    char.inventory = {}
    if itemId then char.inventory[1] = Item.instantiate(itemId) end
    return { char = char, side = "party", alive = true, x = 1, y = 1 }
end

local function joined(lines) return table.concat(lines, " ") end

-- Does any line carry `needle`? Plain find, so a figure like "+5" matches literally -- and case-blind,
-- because which clause leads the figures sentence depends on what the kit declares, and the leading one
-- is raised to a capital. A case's business is that the figure is THERE, not which clause opened.
local function says(lines, needle)
    return joined(lines):lower():find(needle:lower(), 1, true) ~= nil
end

-- The reading, with its opening sentence checked against the shared one. Every case wants both, and
-- the check is the whole point of the file, so it is not left to be remembered case by case.
local function noteFor(unit, kind)
    local title, lines = CombatPanel.waitNote(unit)
    assert(lines[1] == Combat.WAIT_SWAP_NOTE[kind],
        "the button opens on its own sentence rather than the shared one:\n  button: "
            .. tostring(lines[1]) .. "\n  shared: " .. tostring(Combat.WAIT_SWAP_NOTE[kind]))
    return title, lines
end

return {
    {
        name = "a body with no wait swap reads the plain delay: what it ends, and where it puts you back",
        fn = function()
            local title, lines = noteFor(bearer(nil), "delay")
            assert(title == "Wait", "the plain button is titled " .. tostring(title))
            -- The one thing a player cannot guess: Wait is not "skip". It is a re-entry just behind the
            -- next body, which is the entire reason to press it -- and the reason NOT to, when the next
            -- body is the one you were hoping to move before. `delay` is the one stance no item grants,
            -- so this sentence exists nowhere else in the game and nothing else would ever say it.
            assert(says(lines, "just behind the next body"),
                "the delay never says where it puts you: " .. joined(lines))
            -- ...and the half that makes a long walk expensive. Combat.wait floors the new initiative at
            -- the move cost already spent (models/combat.lua), so a wait after a march is not free.
            assert(says(lines, "already walked"), "the walked ground is not mentioned: " .. joined(lines))
        end,
    },
    {
        name = "a shield's Defend quotes the brace it will actually plant, and who else gets the wall",
        fn = function()
            local unit = bearer("armor_oathkeeper_shield")
            local title, lines = noteFor(unit, "defend")
            assert(title == "Defend", "a shield's button is titled " .. tostring(title))

            -- The LIVE number, off the instantiated shield -- not the Curve.ramp its blueprint authors.
            -- A curve reaching the player's prose prints as "table: 0x...", which is the failure this
            -- assertion exists for; the figure has to be the one Combat.defend hands the status.
            local brace = unit.char.inventory[1].waitBehavior.defense
            assert(type(brace) == "number", "the instantiated shield never resolved its brace")
            assert(says(lines, "braces +" .. tostring(brace)),
                "the brace reads as something other than " .. tostring(brace) .. ": " .. joined(lines))
            assert(not joined(lines):find("table:", 1, true), "a curve leaked into the reading")

            -- `covers` is what makes bracing a formation decision rather than a private one, and it is
            -- invisible everywhere else on this screen.
            assert(says(lines, "beside you"), "the tower shield never says it covers the line: " .. joined(lines))
        end,
    },
    {
        name = "a staff's Focus quotes the mana restored -- and the health an overchannelled one takes for it",
        fn = function()
            local unit = bearer("weapon_overchannelled_staff")
            local title, lines = noteFor(unit, "focus")
            assert(title == "Focus", "a staff's button is titled " .. tostring(title))

            local mana = unit.char.inventory[1].waitBehavior.mana
            assert(type(mana) == "number", "the instantiated staff never resolved its mana")
            assert(says(lines, "restores " .. tostring(mana)), "the meditation reads no figure: " .. joined(lines))

            -- THE TOLL IS THE POINT OF THE ASSERTION. This staff pays for its deeper mana out of the
            -- meditating body, and a button that says only FOCUS and costs health is the single worst
            -- surprise the swap can hand anyone. It is a cost, so it is said before the press.
            assert(says(lines, "costs you 8 health"), "the staff never names what it takes: " .. joined(lines))
        end,
    },
    {
        name = "Overwatch reads the stamina each shot spends, the ground it makes dear, and when it lapses",
        fn = function()
            local unit = bearer("utility_overwatch_scope")
            local title, lines = noteFor(unit, "overwatch")
            assert(title == "Overwatch", "the scope's button is titled " .. tostring(title))

            local wb = unit.char.inventory[1].waitBehavior
            assert(says(lines, tostring(wb.stamina)), "each shot's stamina is unquoted: " .. joined(lines))
            -- The zone tax is a half of this stance that exists nowhere on the board's own readouts:
            -- an enemy pays it stepping beside the watcher, and the player choosing WHERE to watch is
            -- the one who needs to know.
            assert(says(lines, "step onto"), "the watched ground's tax is unsaid: " .. joined(lines))
            -- And when it ends, because a stance that lapses on your own next turn is not a wall.
            assert(says(lines, "lapses"), "the watch never says it lapses: " .. joined(lines))
        end,
    },
    {
        name = "Gather reads the force it banks for the next blow",
        fn = function()
            local unit = bearer("utility_centering_charm")
            local title, lines = noteFor(unit, "gather")
            assert(title == "Gather", "the charm's button is titled " .. tostring(title))
            local power = unit.char.inventory[1].waitBehavior.power
            assert(type(power) == "number", "the instantiated charm never resolved its power")
            assert(says(lines, "stores +" .. tostring(power)), "the coil reads no figure: " .. joined(lines))
        end,
    },
    {
        name = "the horn's button is titled with the air it will sound, and the note says which air comes after",
        fn = function()
            local unit = bearer("utility_hunting_horn")
            local wb = unit.char.inventory[1].waitBehavior
            local first = wb.songs[1]

            local title, lines = noteFor(unit, "perform")
            -- The PLATE names the air, not the verb (CombatPanel.waitLabel), so the gloss over it has to
            -- name the same thing -- a box titled "Perform" over a button reading "The Chase" is two
            -- names for one press.
            assert(title == first.name, "the horn's button is titled " .. tostring(title))
            assert(says(lines, tostring(Status.defs[first.status].name)),
                "the air never says what it lands: " .. joined(lines))
            assert(says(lines, "within " .. tostring(wb.earshot)), "earshot is unquoted: " .. joined(lines))

            -- THE ORDER IS THE COST. A cycling button that names only the next air hides the decision
            -- the horn actually asks -- how many turns to the one you wanted -- so the note points on.
            assert(says(lines, "next air: " .. wb.songs[2].name),
                "the cycle never says what follows: " .. joined(lines))

            -- ...and the title follows the cursor rather than standing still: sound one air and the
            -- button is the next one's, which is the whole reason the label is a song name.
            unit.songIndex = 1
            local second = CombatPanel.waitNote(unit)
            assert(second == wb.songs[2].name,
                "after one air the button still reads " .. tostring(second))
        end,
    },
    {
        name = "no wait swap in the catalog glosses as a blank box or prints a raw id",
        fn = function()
            -- A sweep rather than six hand-written cases: a new stance kind, or a named shield that
            -- hands out a status nobody authored a def for, both land here rather than shipping a
            -- button whose reading is empty or reads "status_defending" at the player.
            local seen = {}
            for id, def in pairs(Item.defs) do
                if def.waitBehavior then
                    local unit = bearer(id)
                    local kind = unit.char.inventory[1].waitBehavior.kind
                    local title, lines = noteFor(unit, kind)
                    local text = joined(lines)
                    assert(type(title) == "string" and title ~= "",
                        id .. " puts no word on the button")
                    assert(not text:find("table:", 1, true), id .. " leaks a curve into its reading: " .. text)
                    assert(not text:find("status_", 1, true), id .. " prints a raw status id: " .. text)
                    assert(not text:find("hazard_", 1, true), id .. " prints a raw hazard id: " .. text)
                    assert(not text:find("nil", 1, true), id .. " prints a nil into its reading: " .. text)
                    seen[kind] = true
                end
            end
            -- The sweep is only worth what it walks: every kind Combat's wait dispatch can run has to
            -- have been exercised by it, or a whole stance is passing untested.
            for _, kind in ipairs({ "defend", "focus", "overwatch", "gather", "perform" }) do
                assert(seen[kind], "no item in the catalog exercises the " .. kind .. " reading")
            end
        end,
    },
    {
        name = "the item tooltip prints the shared sentence rather than keeping its own copy of it",
        fn = function()
            -- THE SHARING HAS TO BE STRUCTURAL. Every case above compares the button's opening line to
            -- Combat.WAIT_SWAP_NOTE, which proves the button reads it -- and proves nothing whatever
            -- about the item tooltip, where these five sentences were born and where a copy of them
            -- would go on matching for exactly as long as nobody edited either side. So the file is
            -- read: the sentences must be GONE from it, and the shared table named in their place.
            local src = assert(love.filesystem.read("ui/item_tooltip.lua"), "ui/item_tooltip.lua is readable")
            assert(src:find("Combat.WAIT_SWAP_NOTE", 1, true),
                "the item tooltip no longer reads the shared wait-swap sentence at all")
            for kind, sentence in pairs(Combat.WAIT_SWAP_NOTE) do
                -- The opening clause is enough to catch a re-inlined copy, and unlike the whole
                -- sentence it survives a line wrap in the source.
                local opener = sentence:sub(1, 24)
                assert(not src:find(opener, 1, true),
                    "the " .. kind .. " sentence has been written back into ui/item_tooltip.lua ('"
                        .. opener .. "...'), so the button and the item can drift again")
            end
        end,
    },
}
