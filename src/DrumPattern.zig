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

const std = @import("std");
const Mutes = @import("DrumMachine.zig").Mutes;
const Kit = @import("Kit.zig");
const NextPrevEnum = @import("NextPrevEnum.zig").NextPrevEnum;

pub const maxlen = 16;

pub const types = [_]DrumType{
    .bd,
    .sd,
    .ch,
    .oh,
    .lt,
    .ht,
    .cy,
    .rs,
    .cp,
    .ac,
    .rr,
};

pub const Step = packed struct(u16) {
    bd: bool = false,
    sd: bool = false,
    ch: bool = false,
    oh: bool = false,
    lt: bool = false,
    ht: bool = false,
    cy: bool = false,
    rs: bool = false,
    cp: bool = false,
    ac: bool = false,
    rr: bool = false,

    _: u5 = 0,

    pub inline fn assume(self: *Step, new: Step) void {
        @atomicStore(Step, self, new, .seq_cst);
    }

    pub inline fn copy(self: *const Step) Step {
        return @atomicLoad(Step, self, .seq_cst);
    }

    pub fn get(self: *const Step, t: DrumType) bool {
        return switch (t) {
            inline else => |v| @field(self.copy(), @tagName(v)),
        };
    }

    pub fn set(self: *Step, t: DrumType, value: bool) void {
        var c = self.copy();
        switch (t) {
            inline else => |v| @field(c, @tagName(v)) = value,
        }
        @atomicStore(Step, self, c, .seq_cst);
    }

    pub fn toggle(self: *Step, t: DrumType) void {
        const v = self.get(t);
        self.set(t, !v);
    }
};

pub const DrumType = enum {
    bd,
    sd,
    ch,
    oh,
    lt,
    ht,
    cy,
    rs,
    cp,
    ac,
    rr,

    pub fn muted(comptime self: DrumType, mutes: Mutes) bool {
        return switch (self) {
            .bd => mutes.get(.bd),
            .sd => mutes.get(.sd),
            .ch => mutes.get(.hhcy),
            .oh => mutes.get(.hhcy),
            .lt => mutes.get(.tm),
            .ht => mutes.get(.tm),
            .cy => mutes.get(.hhcy),
            .rs => mutes.get(.rscp),
            .cp => mutes.get(.rscp),
            .ac => false,
            .rr => false,
        };
    }

    pub fn str(self: DrumType) []const u8 {
        return switch (self) {
            .rr => "\xfa\xfa",
            inline else => |v| @tagName(v),
        };
    }

    pub fn next(self: *DrumType) void {
        return NextPrevEnum(@This(), false).next(self);
    }

    pub fn prev(self: *DrumType) void {
        return NextPrevEnum(@This(), false).prev(self);
    }
};

steps: [maxlen]Step = [1]Step{.{}} ** maxlen,
len: u8 = maxlen,

pub fn empty(self: *const @This()) bool {
    const default = Step{};
    for (&self.steps) |*step| {
        if (step.copy() != default) return false;
    }
    return true;
}

pub fn copy(self: *const @This()) @This() {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    var steps: [maxlen]Step = undefined;

    for (0..maxlen) |i| steps[i] = self.steps[i].copy();

    return .{ .len = len, .steps = steps };
}

pub fn assume(self: *@This(), other: *const @This()) void {
    for (0..maxlen) |i| self.steps[i].assume(other.steps[i]);
    @atomicStore(u8, &self.len, other.len, .seq_cst);
}

pub fn incLength(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new = @min(maxlen, len + 1);
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub fn decLength(self: *@This()) void {
    const len = @atomicLoad(u8, &self.len, .seq_cst);
    const new: u8 = if (len <= 1) 1 else len - 1;
    @atomicStore(u8, &self.len, new, .seq_cst);
}

pub inline fn length(self: *const @This()) u8 {
    return @atomicLoad(u8, &self.len, .seq_cst);
}

test Step {
    const t = std.testing;

    var x = Step{};

    x.set(.sd, true);
    try t.expect(x.get(.sd));
    x.set(.sd, false);
    try t.expect(!x.get(.sd));
}
