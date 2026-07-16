// Copyright (C) 2026  Philip Linde
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

const std = @import("std");
const Kit = @import("Kit.zig");
const BufString = @import("bufstring.zig").BufString;

pub const Slot = struct {
    name: BufString(8) = .{},
    kit: Kit = undefined,
};

var kits: [256]Slot = undefined;
var n: usize = 0;

pub fn reset() void {
    n = 0;
}

pub fn register(name: []const u8, kit: Kit) !void {
    if (n == kits.len) return error.TooManyKits;

    try kits[n].name.set(name);
    kits[n].kit = kit;
    n += 1;
}

pub fn next(i: usize) usize {
    if (i < n - 1) return i + 1;
    return i;
}

pub fn prev(i: usize) usize {
    if (i > 0) return i - 1;
    return i;
}

pub fn get(index: usize) *const Slot {
    return &kits[index];
}

pub fn idx(name: []const u8) !usize {
    for (0..n) |i| {
        if (std.mem.eql(u8, name, kits[i].name.slice())) {
            return i;
        }
    }

    return error.NoSuchKit;
}
