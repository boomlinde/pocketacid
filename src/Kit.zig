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

const Kit = @This();

bd: []const u8,
sd: []const u8,
ch: []const u8,
oh: []const u8,
lt: []const u8,
ht: []const u8,
cy: []const u8,
xx: []const u8,
yy: []const u8,
choh: []const u8,

pub const n_notes = 10;

pub const Id = enum(u7) {
    R6,
    R7,
    R8,
    R9,
    N1,

    pub fn resolve(self: Id) *const Kit {
        return switch (self) {
            .R6 => &R6,
            .R7 => &R7,
            .R8 => &R8,
            .R9 => &R9,
            .N1 => &N1,
        };
    }

    pub fn str(self: Id) []const u8 {
        return @tagName(self);
    }
};

const rs808 = @embedFile("assets/samples/rs808.raw");
const cp808 = @embedFile("assets/samples/cp808.raw");
pub const R6 = Kit{
    .bd = @embedFile("assets/samples/bd606.raw"),
    .ch = @embedFile("assets/samples/ch606.raw"),
    .oh = @embedFile("assets/samples/oh606.raw"),
    .cy = @embedFile("assets/samples/cy606.raw"),
    .ht = @embedFile("assets/samples/hi606.raw"),
    .lt = @embedFile("assets/samples/lo606.raw"),
    .sd = @embedFile("assets/samples/sd606.raw"),
    .xx = rs808,
    .yy = cp808,
    .choh = @embedFile("assets/samples/choh606.raw"),
};

const oh909 = @embedFile("assets/samples/oh909.raw");
pub const R9 = Kit{
    .bd = @embedFile("assets/samples/bd909.raw"),
    .ch = @embedFile("assets/samples/ch909.raw"),
    .oh = oh909,
    .cy = @embedFile("assets/samples/cy909.raw"),
    .ht = @embedFile("assets/samples/hi909.raw"),
    .lt = @embedFile("assets/samples/lo909.raw"),
    .sd = @embedFile("assets/samples/sd909.raw"),
    .xx = @embedFile("assets/samples/rs909.raw"),
    .yy = @embedFile("assets/samples/cp909.raw"),
    .choh = oh909,
};

const oh808 = @embedFile("assets/samples/oh808.raw");
pub const R8 = Kit{
    .bd = @embedFile("assets/samples/bd808.raw"),
    .ch = @embedFile("assets/samples/ch808.raw"),
    .oh = oh808,
    .cy = @embedFile("assets/samples/cy808.raw"),
    .ht = @embedFile("assets/samples/hi808.raw"),
    .lt = @embedFile("assets/samples/lo808.raw"),
    .sd = @embedFile("assets/samples/sd808.raw"),
    .xx = rs808,
    .yy = cp808,
    .choh = oh808,
};

const oh707 = @embedFile("assets/samples/oh707.raw");
pub const R7 = Kit{
    .bd = @embedFile("assets/samples/bd707.raw"),
    .ch = @embedFile("assets/samples/ch707.raw"),
    .oh = oh707,
    .cy = @embedFile("assets/samples/cy707.raw"),
    .ht = @embedFile("assets/samples/hi707.raw"),
    .lt = @embedFile("assets/samples/lo707.raw"),
    .sd = @embedFile("assets/samples/sd707.raw"),
    .xx = @embedFile("assets/samples/rs707.raw"),
    .yy = @embedFile("assets/samples/cp707.raw"),
    .choh = oh707,
};

const n1_oh = @embedFile("assets/samples/ns_oh.raw");
pub const N1 = Kit{
    .bd = @embedFile("assets/samples/ns_bd.raw"),
    .ch = @embedFile("assets/samples/ns_ch.raw"),
    .oh = n1_oh,
    .cy = @embedFile("assets/samples/ns_cy.raw"),
    .ht = @embedFile("assets/samples/ns_ht.raw"),
    .lt = @embedFile("assets/samples/ns_lt.raw"),
    .sd = @embedFile("assets/samples/ns_sd.raw"),
    .xx = @embedFile("assets/samples/ns_xx.raw"),
    .yy = @embedFile("assets/samples/ns_yy.raw"),
    .choh = n1_oh,
};
