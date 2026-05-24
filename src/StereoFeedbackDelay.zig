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

const FractionalDelayLine = @import("FractionalDelayLine.zig");
const a = @import("access.zig");
const Frame = @import("Mixer.zig").Frame;
const Smoother = @import("Smoother.zig");

const smooth_time = 0.5;

pub const Params = struct {
    time: u8 = 0x30,
    feedback: u8 = 0x80,
    duck: u8 = 0,
};

left: FractionalDelayLine,
right: FractionalDelayLine,

params: *const Params,
smoothed_delay_time: Smoother = .{},

pub fn next(self: *@This(), in: Frame, bpm: f32, duck: f32, srate: f32) Frame {
    const time = @as(f32, @floatFromInt(a.get(self.params, .time))) / 16;
    const feedback = @as(f32, @floatFromInt(a.get(self.params, .feedback))) / 0x100;
    const duck_level = @as(f32, @floatFromInt(a.get(self.params, .duck))) / 0xff;

    const smoothed = self.smoothed_delay_time.next(calcDelayTime(time, bpm), smooth_time, srate);

    const prev_left = self.left.out(smoothed * srate * 1.01);
    const prev_right = self.right.out(smoothed * srate * 0.99);

    self.left.feed(prev_left * feedback + in.left);
    self.right.feed(prev_right * feedback + in.right);

    const total_duck = (1 - duck_level) + duck * duck_level;

    return .{ .left = prev_left * total_duck, .right = prev_right * total_duck };
}

pub fn calcDelayTime(steps: f32, bpm: f32) f32 {
    const steps_per_second = 4 * bpm / 60;
    return steps / steps_per_second;
}
