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
const std = @import("std");

pub const JoyMode = enum {
    timbre_mod,
    res_feedback,
    decay_accent,

    pub const Pair = struct {
        x: u8,
        y: u8,
    };

    pub fn next(self: *JoyMode) void {
        self.* = switch (self.*) {
            .timbre_mod => .res_feedback,
            .res_feedback => .decay_accent,
            .decay_accent => .timbre_mod,
        };
    }

    pub fn fromShort(short: []const u8) !JoyMode {
        if (std.mem.eql(u8, short, "tm"))
            return .timbre_mod;
        if (std.mem.eql(u8, short, "rf"))
            return .res_feedback;
        if (std.mem.eql(u8, short, "da"))
            return .decay_accent;
        return error.BadJoyModeStr;
    }

    pub fn toShort(self: JoyMode) []const u8 {
        return switch (self) {
            .timbre_mod => "tm",
            .res_feedback => "rf",
            .decay_accent => "da",
        };
    }

    pub fn str(self: JoyMode) []const u8 {
        return switch (self) {
            .timbre_mod => "timbre/env:",
            .res_feedback => "res/feedback:",
            .decay_accent => "decay/accent:",
        };
    }

    pub fn values(self: JoyMode, params: *const DigiBass.Params) Pair {
        const FloatPair = struct { x: f32, y: f32 };
        const v: FloatPair = switch (self) {
            .timbre_mod => .{
                .y = params.get(.timbre),
                .x = params.get(.mod_depth),
            },
            .res_feedback => .{
                .y = params.get(.res),
                .x = params.get(.feedback),
            },
            .decay_accent => .{
                .y = params.get(.decay),
                .x = params.get(.accentness),
            },
        };

        return .{
            .x = @intFromFloat(@round(v.x * 0xff)),
            .y = @intFromFloat(@round(v.y * 0xff)),
        };
    }
};
