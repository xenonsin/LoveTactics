-- The pixel shader the overworld fog of war is drawn with (ui/overworld_map.lua). Where the board's
-- fog was a flat black rectangle per hidden tile, this makes the undiscovered expanse a slow churn of
-- dark mist -- sampled in BOARD space so a contiguous unexplored region roils as one mass rather than
-- as a grid of identical squares, the same trick shaders/field.lua uses to make a multi-tile hazard
-- read as one patch of ground.
--
-- Deliberately small: no pattern switch (fog is one thing) and no edge feathering (the fog's job is to
-- HIDE, and a hard tile boundary against the revealed world is correct -- you can see exactly as far as
-- you have walked). Two tiers ride in on uAlpha: the near-opaque dark over never-seen ground, and the
-- lighter veil over ground seen once but now out of sight.
--
-- Built to the house contract: plain string data at require-time (ui/overworld_map.lua compiles it
-- lazily under a pcall and latches back to the flat rects on failure), noise shared from shaders/noise.

local Noise = require("shaders.noise")

local Fog = {}

Fog.source = [[
uniform float uTime;
uniform float uAlpha;   // the tier's base opacity (near-1 unseen, ~0.5 the dimmed veil)
uniform vec2  uCell;     // this tile's BOARD coordinate, so the churn is continuous across tiles
]] .. Noise.source .. [[

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 P = uCell + tc;
    // Two octaves drifting in different directions: a slow, heavy roll rather than a shimmer.
    float a = fbm(P * 1.6 + vec2(uTime * 0.05, uTime * 0.03));
    float b = fbm(P * 3.1 - vec2(uTime * 0.04, uTime * 0.06));
    float churn = mix(a, b, 0.5);
    // The mist is near-black, lifting to a cold charcoal in its thicker folds so the roll is visible.
    vec3 rgb = mix(vec3(0.015, 0.015, 0.022), vec3(0.05, 0.05, 0.075), churn);
    // Modulate the opacity a little with the churn so the veil breathes; never enough to reveal what
    // it hides -- an unseen tile stays unreadable.
    float a2 = uAlpha * (0.88 + 0.12 * churn);
    return vec4(rgb, a2);
}
]]

return Fog
