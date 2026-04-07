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
const Accessor = @import("Accessor.zig").Accessor;

engine: SoundEngine.Params = .{},
bass1: DigiBass.Params = .{},
bass2: DigiBass.Params = .{},
drums: DrumMachine.Params = .{},
delay: StereoFeedbackDelay.Params = .{},
mixer: [Mixer.nchannels]Mixer.Channel.Params = [1]Mixer.Channel.Params{.{}} ** Mixer.nchannels,

pub fn copy(self: *const @This()) @This() {
    const mixer: [Mixer.nchannels]Mixer.Channel.Params = undefined;
    for (0..mixer.len) |i| {
        mixer[i] = self.mixer[i].copy();
    }
    return .{
        .engine = self.engine.copy(),
        .bass1 = self.bass1.copy(),
        .bass2 = self.bass2.copy(),
        .drums = self.drums.copy(),
        .delay = self.delay.copy(),
        .mixer = mixer,
    };
}

pub fn assume(self: *@This(), other: *const @This()) void {
    self.engine.assume(other.engine.copy());
    self.bass1.assume(other.bass1.copy());
    self.bass2.assume(other.bass2.copy());
    self.drums.assume(other.drums.copy());
    self.delay.assume(other.delay.copy());
    for (0..Mixer.nchannels) |i| self.mixer[i].assume(other.mixer[i].copy());
}

pub fn assumeNoTempo(self: *@This(), other: *const @This()) void {
    self.engine.set(.drive, other.engine.get(.drive));
    self.engine.set(.mutes, other.engine.get(.mutes));
    self.engine.set(.swing, other.engine.get(.swing));
    self.bass1.assume(other.bass1.copy());
    self.bass2.assume(other.bass2.copy());
    self.drums.assume(other.drums.copy());
    self.delay.assume(other.delay.copy());
    for (0..Mixer.nchannels) |i| self.mixer[i].assume(other.mixer[i].copy());
}
