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

const std = @import("std");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");
const Theme = @import("Theme.zig");
const FontType = @import("CharDisplay.zig").FontType;

const configname = "settings.cfg";

theme: Theme.Id = .term,
swapbuttons: bool = false,
font: FontType = .mcr,
autoadvance: bool = true,
samples: u16 = 1024,
fullscreen: bool = false,
joyless: bool = false,
project: u8 = 0x00,

pub fn load(self: *@This(), dir: std.fs.Dir) !void {
    const file = dir.openFile(configname, .{ .mode = .read_only }) catch |err| {
        if (err == error.FileNotFound) return else return err;
    };
    defer file.close();

    var tokenbuf: [64]u8 = undefined;
    var tokenizer = Tokenizer{
        .reader = file.reader().any(),
        .buf = &tokenbuf,
    };

    const parser = Parser{ .tokenizer = &tokenizer };

    self.* = try parser.expect(@This());
}

pub fn save(self: *const @This(), dir: std.fs.Dir) !void {
    const file = try dir.createFile(configname ++ ".tmp", .{});
    const writer = file.writer().any();
    defer file.close();

    try Parser.serialize(self.*, writer);
    try writer.writeAll("\n");
    try dir.rename(configname ++ ".tmp", configname);
}
