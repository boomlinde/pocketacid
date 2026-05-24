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

const DigiBass = @import("DigiBass.zig");
const DrumMachine = @import("DrumMachine.zig");
const SoundEngine = @import("SoundEngine.zig");
const StereoFeedbackDelay = @import("StereoFeedbackDelay.zig");
const Mixer = @import("Mixer.zig");
const a = @import("access.zig");

engine: SoundEngine.Params = .{},
bass1: DigiBass.Params = .{},
bass2: DigiBass.Params = .{},
drums: DrumMachine.Params = .{},
delay: StereoFeedbackDelay.Params = .{},
mixer: [Mixer.nchannels]Mixer.Channel.Params = [1]Mixer.Channel.Params{.{}} ** Mixer.nchannels,

pub fn copy(self: *const @This()) @This() {
    const mixer: [Mixer.nchannels]Mixer.Channel.Params = undefined;
    for (0..mixer.len) |i| {
        mixer[i] = a.copy(&self.mixer[i]);
    }
    return .{
        .engine = a.copy(&self.engine),
        .bass1 = a.copy(&self.bass1),
        .bass2 = a.copy(&self.bass2),
        .drums = a.copy(&self.drums),
        .delay = a.copy(&self.delay),
        .mixer = mixer,
    };
}

pub fn assume(self: *@This(), other: *const @This()) void {
    a.assume(&self.engine, a.copy(&other.engine));
    a.assume(&self.bass1, a.copy(&other.bass1));
    a.assume(&self.bass2, a.copy(&other.bass2));
    a.assume(&self.drums, a.copy(&other.drums));
    a.assume(&self.delay, a.copy(&other.delay));
    for (0..Mixer.nchannels) |i| a.assume(&self.mixer[i], a.copy(&other.mixer[i]));
}

pub fn assumeNoTempo(self: *@This(), other: *const @This()) void {
    a.set(&self.engine, .drive, a.get(&other.engine, .drive));
    a.set(&self.engine, .mutes, a.get(&other.engine, .mutes));
    a.set(&self.engine, .swing, a.get(&other.engine, .swing));
    a.assume(&self.bass1, a.copy(&other.bass1));
    a.assume(&self.bass2, a.copy(&other.bass2));
    a.assume(&self.drums, a.copy(&other.drums));
    a.assume(&self.delay, a.copy(&other.delay));
    for (0..Mixer.nchannels) |i| a.assume(&self.mixer[i], a.copy(&other.mixer[i]));
}
