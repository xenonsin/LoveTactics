-- Audio COMMISSION list generator: run with
--
--     & "E:\LOVE\lovec.exe" . audio-commission
--
-- Turns data/sounds.lua into docs/audio-commission.md -- the brief an audio author (or you) works
-- from: every cue the game asks for, its target length, its mix trim, and one line saying what it is
-- and when it fires. The SPEC lives on each cue as `length`/`desc` fields, so this doc is GENERATED
-- and can never drift from what the game actually plays: add or remove a cue, regenerate, done. It is
-- the audio twin of the icon pipeline's generated docs/credits-icons.md.
--
-- Deliberately split from `. audio-report`: the report is the ephemeral on-DISK count (what is still
-- outstanding, printed to the console), this is the stable SPEC (what each cue must BE, committed as a
-- doc). Same split art keeps between tools/art_report.lua and docs/art-assets.md.
--
-- Writes into the PROJECT tree via io.open (love.filesystem.write can only reach the save dir), exactly
-- as tools/icon_build.lua does.

local M = {}

local OUT = "docs/audio-commission.md"

-- Bucket display order (music first: the largest, most expensive lift). Matches tools/audio_report.lua.
local ORDER = { "music", "ui", "battle", "quest" }

-- One human line per bucket, so the generated doc reads as a brief rather than a bare dump.
local BUCKET_BLURB = {
    music = "Streamed, looping beds -- one per place the player spends time. Seamless loops (tail meets head, no click); 44.1kHz stereo. `music.credits` is the one that ENDS.",
    ui    = "The shared menu widget (mouse/keyboard/gamepad). Modelled on classic Final Fantasy menus: clean synth blips, not clicks. Mono, 44.1kHz.",
    battle = "One-shot per combat event, including the 11 damage-type impacts. Short and readable -- the player triggers dozens per fight, often stacked. Mono, 44.1kHz.",
    quest = "Progress stings -- the moments the game marks. Mono, 44.1kHz.",
}

local function bucketOf(id)
    return (id:match("^([^.]+)")) or "other"
end

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- Group the cue table into ordered buckets of sorted cue ids.
local function grouped(cues)
    local byBucket = {}
    for id in pairs(cues) do
        local b = bucketOf(id)
        byBucket[b] = byBucket[b] or {}
        byBucket[b][#byBucket[b] + 1] = id
    end
    for _, ids in pairs(byBucket) do table.sort(ids) end

    local names, seen = {}, {}
    for _, name in ipairs(ORDER) do
        if byBucket[name] then names[#names + 1] = name; seen[name] = true end
    end
    local rest = {}
    for name in pairs(byBucket) do if not seen[name] then rest[#rest + 1] = name end end
    table.sort(rest)
    for _, name in ipairs(rest) do names[#names + 1] = name end
    return names, byBucket
end

-- A markdown table cell: escape the pipe so a `desc` can never break the row.
local function cell(s)
    return tostring(s or ""):gsub("|", "\\|")
end

function M.render(cues)
    local names, byBucket = grouped(cues)

    local total = 0
    for _, ids in pairs(byBucket) do total = total + #ids end

    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    line("# Audio commission list")
    line("")
    line("> **Generated** from [../data/sounds.lua](../data/sounds.lua) by "
        .. "`& \"E:\\LOVE\\love.exe\" . audio-commission` (use `lovec.exe` for console output). "
        .. "**Do not hand-edit** -- change a cue's `length`/`desc` in `data/sounds.lua` and regenerate. "
        .. "Direction, format, sourcing and the on-disk count live in "
        .. "[audio-assets.md](audio-assets.md) (and `. audio-report`).")
    line("")
    line(string.format("**%d cues** across %d buckets. Each row is one sound to source or record; "
        .. "`Trim` is the in-engine mix level (blank = full), applied on top of a file delivered at a "
        .. "consistent working loudness.", total, #names))
    line("")

    for _, name in ipairs(names) do
        local ids = byBucket[name]
        line(string.format("## %s — %d", name, #ids))
        line("")
        if BUCKET_BLURB[name] then line(BUCKET_BLURB[name]); line("") end
        line("| Cue | File | Length | Trim | Brief |")
        line("|---|---|---|---|---|")
        for _, id in ipairs(ids) do
            local def = cues[id]
            local trim = def.volume and string.format("%.2g", def.volume) or ""
            line(string.format("| `%s` | `%s` | %s | %s | %s |",
                cell(id), cell(def.file), cell(def.length or "—"), trim, cell(def.desc or "—")))
        end
        line("")
    end

    return table.concat(out, "\n") .. "\n", total
end

function M.run()
    local ok, cues = pcall(require, "data.sounds")
    if not ok or type(cues) ~= "table" then
        print("audio-commission: could not load data/sounds.lua")
        return
    end

    local text, total = M.render(cues)
    local path = projectPath(OUT)
    local file, err = io.open(path, "w")
    if not file then
        print("audio-commission: could not write " .. OUT .. ": " .. tostring(err))
        return
    end
    file:write(text)
    file:close()
    print(string.format("audio-commission: wrote %s (%d cues)", OUT, total))
end

return M
