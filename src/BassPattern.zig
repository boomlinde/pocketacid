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

pub const maxlen = 16;

pub const off: u4 = 0xf;

len: u8 = 16,
base: u7 = 48,
steps: [maxlen]Step = [1]Step{.{}} ** maxlen,

pub fn empty(self: *const @This()) bool {
    const default = Step{};
    for (&self.steps) |*step| {
        if (step.copy() != default) return false;
    }
    return true;
}

pub fn copy(self: *const @This()) @This() {
    const len = self.length();
    const base = @atomicLoad(u7, &self.base, .seq_cst);
    var steps: [maxlen]Step = undefined;

    for (0..maxlen) |i| steps[i] = self.steps[i].copy();

    return .{ .len = len, .base = base, .steps = steps };
}

pub fn assume(self: *@This(), other: *const @This()) void {
    for (0..maxlen) |i| self.steps[i].assume(other.steps[i]);
    @atomicStore(u8, &self.len, other.len, .seq_cst);
    @atomicStore(u7, &self.base, other.base, .seq_cst);
}

pub inline fn length(self: *const @This()) u8 {
    return @atomicLoad(u8, &self.len, .seq_cst);
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

pub fn incBase(self: *@This()) void {
    const old = @atomicLoad(u7, &self.base, .seq_cst);
    if (old < 103) @atomicStore(u7, &self.base, old + 1, .seq_cst);
}

pub fn decBase(self: *@This()) void {
    const old = @atomicLoad(u7, &self.base, .seq_cst);
    if (old > 12) @atomicStore(u7, &self.base, old - 1, .seq_cst);
}

pub inline fn getBase(self: *const @This()) u7 {
    return @atomicLoad(u7, &self.base, .seq_cst);
}

pub const Step = packed struct(u8) {
    pitch: u4 = off,
    octup: bool = false,
    octdown: bool = false,
    slide: bool = false,
    accent: bool = false,

    pub inline fn assume(self: *Step, new: Step) void {
        @atomicStore(Step, self, new, .seq_cst);
    }

    pub inline fn copy(self: *const Step) Step {
        return @atomicLoad(Step, self, .seq_cst);
    }

    pub inline fn active(self: *const Step) bool {
        const s = self.copy();
        return s.pitch != off;
    }

    pub inline fn delete(self: *Step) void {
        self.assume(.{});
    }

    pub fn midi(self: Step, base: u7) ?u7 {
        if (self.pitch == off) return null;
        var result = base;
        result +|= self.pitch;
        if (self.octup) result +|= 12;
        if (self.octdown) result -|= 12;
        return result;
    }
};
