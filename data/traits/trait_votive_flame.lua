-- Votive Flame: a channel the bearer resolves spends its Radiance as wind-up it did not have to wait
-- for, a tick for every two points (Engine.onChannelResolve reads the `votiveFlame` flag). The Theurge
-- holds a holy working and lets it grow; banked grace is how it grows without the waiting.
return {
    name = "Votive Flame",
    description = "When your channel resolves, consume all Radiance: it counts 1 more tick held per 2 Radiance.",
    votiveFlame = true,
}
