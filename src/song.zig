// Copyright (C) 2025  Philip Linde
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

const DrumPattern = @import("DrumPattern.zig");
const BassPattern = @import("BassPattern.zig");
const Snapshot = @import("Snapshot.zig");

pub var bass_patterns: [256]BassPattern = undefined;
pub var drum_patterns: [256]DrumPattern = undefined;
pub var snapshots: [256]Snapshot = undefined;

pub var bass1_arrange: [256]u8 = undefined;
pub var bass2_arrange: [256]u8 = undefined;
pub var drum_arrange: [256]u8 = undefined;

pub fn init() void {
    bass_patterns = [1]BassPattern{.{}} ** 256;
    drum_patterns = [1]DrumPattern{.{}} ** 256;
    snapshots = [1]Snapshot{.{}} ** 256;

    bass1_arrange = [1]u8{0xff} ** 256;
    bass2_arrange = [1]u8{0xff} ** 256;
    drum_arrange = [1]u8{0xff} ** 256;

    for (0..256) |i| snap_map[i] = @intCast(i);
}

// The snap map isn't saved
pub var snap_map: [256]u8 = undefined;

pub fn findEmptyUnusedBassPattern() ?u8 {
    // Index all used patterns
    var used: [255]bool = [1]bool{false} ** 255;
    for (&bass1_arrange) |*idx| {
        const pat = @atomicLoad(u8, idx, .seq_cst);
        if (pat != 0xff) used[pat] = true;
    }
    for (&bass2_arrange) |*idx| {
        const pat = @atomicLoad(u8, idx, .seq_cst);
        if (pat != 0xff) used[pat] = true;
    }

    for (bass_patterns[0..255], 0..) |*pat, i| {
        if (used[i]) continue;
        if (pat.empty()) return @intCast(i);
    }

    return null;
}

pub fn findEmptyUnusedDrumPattern() ?u8 {
    // Index all used patterns
    var used: [255]bool = [1]bool{false} ** 255;
    for (&drum_arrange) |*idx| {
        const pat = @atomicLoad(u8, idx, .seq_cst);
        if (pat != 0xff) used[pat] = true;
    }

    for (drum_patterns[0..255], 0..) |*pat, i| {
        if (used[i]) continue;
        if (pat.empty()) return @intCast(i);
    }

    return null;
}
