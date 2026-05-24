// Copyright (C) 2025-2026  Philip Linde
//
// This file is part of Pocket Acid.
//
// Pocket Acid is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Pocket Acid is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Pocket Acid.  If not, see <https://www.gnu.org/licenses/>.

const ADREnv = @import("ADREnv.zig");
const midi = @import("midi.zig");
const std = @import("std");
const MonoLegato = @import("MonoLegato.zig");
const MonoVoiceManager = @import("MonoVoiceManager.zig");
const DigiBass = @This();
const Smoother = @import("Smoother.zig");
const ADEnv = @import("ADEnv.zig");
const a = @import("access.zig");

pub const Params = struct {
    pub const Type = enum(u8) { pd, fm };

    sound_type: Type = .pd,

    timbre: f32 = 0.5 - 0.125,
    mod_depth: f32 = 0.5,

    res: f32 = 1,
    feedback: f32 = 0,

    decay: f32 = 0.2,
    accentness: f32 = 0.3,
};

const param_smooth_time = 0.1;
const bend_smooth_time = 0.01;

channel: u4,
params: *const Params,

bend: f32 = 0,
phase: f32 = 0,
prev_phase: f32 = 0,
res_phase: f32 = 0,
res2_phase: f32 = 0,
legato: MonoLegato = .{ .time = 0.06 },
man: MonoVoiceManager = .{},
amp_env: ADREnv = .{},
prev: f32 = 0,
prev_res: f32 = 0,
mod_env: ADEnv = .{},
prev_gate: bool = false,
current_mul: f32 = 1,

bend_smooth: Smoother = .{},

accentness_smooth: Smoother = .{},
res_smooth: Smoother = .{},
timbre_smooth: Smoother = .{},
feedback_smooth: Smoother = .{},
mod_smooth: Smoother = .{},

pub fn short(self: *DigiBass) void {
    self.accentness_smooth.short(a.get(self.params, .accentness));
    self.timbre_smooth.short(a.get(self.params, .timbre));
    self.res_smooth.short(a.get(self.params, .res));
    self.mod_smooth.short(a.get(self.params, .mod_depth));
    self.feedback_smooth.short(a.get(self.params, .feedback));
}

pub inline fn next(self: *DigiBass, srate: f32) f32 {
    return switch (a.get(self.params, .sound_type)) {
        .fm => self.nextFM(srate),
        .pd => self.nextPD(srate),
    };
}

pub inline fn nextFM(self: *DigiBass, srate: f32) f32 {
    const accentness_raw = self.accentness_smooth.next(a.get(self.params, .accentness), param_smooth_time, srate);
    const bend = self.bend_smooth.next(self.bend, bend_smooth_time, srate);
    const timbre = self.timbre_smooth.next(a.get(self.params, .timbre), param_smooth_time, srate);
    const res = self.res_smooth.next(a.get(self.params, .res), param_smooth_time, srate);
    const mod = self.mod_smooth.next(a.get(self.params, .mod_depth), param_smooth_time, srate);
    const feedback = self.feedback_smooth.next(a.get(self.params, .feedback), param_smooth_time, srate);
    const state = self.legato.next(self.man.state, srate);

    if (self.man.state.gate and !self.prev_gate) {
        self.mod_env.trigger();
        if (self.amp_env.current == 0) self.phase = 0;
    }
    self.prev_gate = self.man.state.gate;

    const accentness = if (state.velocity >= 96) accentness_raw else 0;
    const mp: ADEnv.Params = if (accentness > 0)
        .{
            .attack = 0.05,
            .decay = 0.2,
            .attack_shape = 0,
            .decay_shape = 0,
        }
    else
        .{
            .attack = 0,
            .decay = a.get(self.params, .decay),
            .attack_shape = 0.5,
            .decay_shape = 0.5,
        };
    const mod_env = self.mod_env.next(&mp, srate);

    const fb = self.prev * feedback * 0.5;

    const pitch = state.pitch + bend;

    const amod = lerp(mod, 1, accentness);
    const nt = normal(timbre);
    const total_mod = lerp(nt * nt, 1, lerp(0, accentness * 4, nt * nt)) * lerp(1, mod_env, amod);

    const rp = res * res * res;
    const phase_mul = self.phase * (1 + 16 * rp);

    const freq = 440.0 * std.math.pow(f32, 2.0, (pitch - 69) / 12);
    defer {
        self.phase += freq / srate;
        if (self.phase >= 1) {
            self.phase -= 1;
            self.current_mul = 1 + @round(res * res * 12);
        }
    }

    const amp_env_params: ADREnv.Params = .{
        .attack = 0.0001,
        .decay = 3,
        .release = 0.03,
    };

    const amp = self.amp_env.next(&amp_env_params, state.gate, srate);

    const falloff = if (timbre < 0.5)
        1 - self.phase * self.phase * self.phase
    else
        1;

    const mod_wave = if (timbre < 0.5)
        @sin(self.phase * phase_mul * std.math.tau)
    else
        @sin(self.phase * self.current_mul * std.math.tau);

    const mod_total = mod_wave * 8 * total_mod * falloff + fb;
    self.prev = clamp(@sin(std.math.tau * (self.phase + mod_total))) * amp;
    return self.prev;
}

pub inline fn nextPD(self: *DigiBass, srate: f32) f32 {
    const accentness_raw = self.accentness_smooth.next(a.get(self.params, .accentness), param_smooth_time, srate);
    const bend = self.bend_smooth.next(self.bend, bend_smooth_time, srate);
    const timbre = self.timbre_smooth.next(a.get(self.params, .timbre), param_smooth_time, srate);
    const res = self.res_smooth.next(a.get(self.params, .res), param_smooth_time, srate);
    const mod = self.mod_smooth.next(a.get(self.params, .mod_depth), param_smooth_time, srate);
    const feedback = self.feedback_smooth.next(a.get(self.params, .feedback), param_smooth_time, srate);
    const state = self.legato.next(self.man.state, srate);

    const res2_amp = r2a: {
        const flat_timbre = @max(0, timbre * 2 - 1);
        const ix = (1 - flat_timbre * 16);
        break :r2a @min(1, 1 - ix * ix * ix);
    };

    if (self.man.state.gate and !self.prev_gate) {
        self.mod_env.trigger();
    }
    self.prev_gate = self.man.state.gate;

    const accentness = if (state.velocity >= 96) accentness_raw else 0;
    const mp: ADEnv.Params = if (accentness > 0)
        .{
            .attack = 0.05,
            .decay = 0.2,
            .attack_shape = 1,
            .decay_shape = 0.5,
        }
    else
        .{
            .attack = 0,
            .decay = a.get(self.params, .decay),
            .attack_shape = 0.5,
            .decay_shape = 0.5,
        };
    const mod_env = self.mod_env.next(&mp, srate);

    const fb = self.prev * feedback;

    const pitch = state.pitch + bend;

    const amod = lerp(mod, 1, accentness);
    const nt = normal(timbre);
    const nt4 = 1 - (1 - nt) * (1 - nt) * (1 - nt);
    const total_mod = lerp(nt, 1, lerp(0, accentness, nt4)) * lerp(1, mod_env, amod);

    const res_freq = 440.0 * std.math.pow(f32, 2.0, (total_mod * 96 + 32 - 69) / 12);
    defer self.res_phase = @mod(self.res_phase + res_freq / srate, 1);
    defer self.res2_phase = @mod(self.res2_phase + res_freq / srate, 1);

    const freq = 440.0 * std.math.pow(f32, 2.0, (pitch - 69) / 12);
    defer {
        const new_phase = @mod(self.phase + freq / srate, 1);

        if (new_phase < self.phase) self.res_phase = 0;
        if (@mod(new_phase * 2, 1) < @mod(self.phase * 2, 1)) self.res2_phase = 0;

        self.phase = new_phase;
    }

    const amp_env_params: ADREnv.Params = .{
        .attack = 0.0001,
        .decay = 3,
        .release = 0.03,
    };

    const amp = self.amp_env.next(&amp_env_params, state.gate, srate);

    const falloff = falloffFunc(self.phase, res);
    const falloff2 = falloffFunc(@mod(self.phase + 0.5, 1), res);
    const nt_notrack = total_mod * (1 - clamp01((pitch - 24) / 96));
    const t: OscType = if (timbre > 0.5) .sqr else .saw;
    self.prev_res = 2 * res * falloff * falloff * falloff * @sin(self.res_phase * std.math.tau);
    self.prev_res += res2_amp * (-2 * res * falloff2 * falloff2 * falloff2 * @sin(self.res2_phase * std.math.tau));
    self.prev = clamp((pdparams(clamp01(nt_notrack), t).wave(self.phase + fb) * 1 + self.prev_res)) * amp;
    return self.prev;
}

pub inline fn falloffFunc(phase: f32, factor: f32) f32 {
    return @max(0, 1 - phase / @max(0.01, factor));
    // return 1 - phase;
}

pub fn handleMidiEvent(self: *DigiBass, event: midi.Event) void {
    if ((event.channel() orelse return) != self.channel) return;
    switch (event) {
        .note_on => |e| self.man.noteOn(e.pitch, e.velocity),
        .note_off => |e| self.man.noteOff(e.pitch),
        .pitch_wheel => |m| self.bend = 2 * (@as(f32, @floatFromInt(m.value)) - 8192) / 8192,
        else => {},
    }
}

pub fn mod_env_params(accentness: f32, user_params: ADEnv.Params) ADEnv.Params {
    return .{ .time = lerp(user_params.time, 0.2, accentness), .shape = user_params.shape };
}

fn lerp(x: f32, y: f32, m: f32) f32 {
    return (1 - m) * x + m * y;
}

inline fn clamp01(x: f32) f32 {
    return @max(0, @min(1, x));
}

inline fn clamp(x: f32) f32 {
    return @max(-1, @min(1, x));
}

inline fn dual(control: f32) struct { x: f32, y: f32 } {
    return if (control >= 0.5)
        .{ .x = normal(control), .y = 0 }
    else
        .{ .y = normal(control), .x = 0 };
}

fn normal(control: f32) f32 {
    return if (control >= 0.5)
        (control - 0.5) * 2
    else
        1 - control * 2;
}

const OscType = enum { sqr, saw };

fn pdparams(control: f32, t: OscType) Pd {
    return switch (t) {
        .sqr => .{ .x = (1 - logize3(control)), .y = 1, .p = 1, .n = 1 }, // Square
        .saw => .{ .x = 0.5 - (0.5 * logize3(control)), .y = 0.5, .p = 1, .n = 0 }, // Saw
    };
}

fn cross(phase: f32, mod: f32, v: f32) f32 {
    const w = v * 16 + 1;
    const low = @floor(w);
    const high = low + 1;
    const mix = w - low;

    const p2p = phase * std.math.tau;

    const low_out = @sin(p2p * (low + mod));
    const high_out = @sin(p2p * (high + mod));
    const mix_out = (1 - mix) * low_out + mix * high_out;

    return mix_out;
}

inline fn logize3(x: f32) f32 {
    const m = 1 - x;
    return 1 - m * m * m;
}

pub const Pd = struct {
    x: f32 = 0.5,
    y: f32 = 0.5,
    n: f32 = 0,
    p: f32 = 0,
    q: f32 = 1,

    pub fn wave(self: Pd, ph: f32) f32 {
        const ph_mod = @mod(ph, 1);
        return @sin((self.p * 0.25 + self.phase(ph_mod)) * std.math.tau * self.q);
    }

    inline fn phase(self: Pd, ph: f32) f32 {
        const n = self.n + 1;
        return @mod(self.singlePhase(ph * n) / n, n);
    }

    inline fn singlePhase(self: Pd, ph: f32) f32 {
        const mp = @mod(ph, 1);
        return @floor(ph) + if (mp < self.x)
            mp * (self.y / self.x)
        else
            (mp - self.x) * ((1 - self.y) / (1 - self.x)) + self.y;
    }
};
