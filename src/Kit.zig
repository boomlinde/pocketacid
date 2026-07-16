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

pub fn parse(src: []const u8) !Kit {
    const eql = std.mem.eql;

    var bd = false;
    var sd = false;
    var ch = false;
    var oh = false;
    var oc = false;
    var lt = false;
    var ht = false;
    var cy = false;
    var xx = false;
    var yy = false;

    var out: Kit = undefined;

    var r = std.io.Reader.fixed(src);

    if (!eql(u8, try r.take(4), "PKIT")) return error.InvalidKit;

    while (!(bd and sd and ch and oh and oc and lt and ht and cy and xx and yy)) {
        const slot = try r.take(2);

        if (eql(u8, slot, "bd")) {
            bd = true;
            const len = try r.takeInt(u32, .little);
            out.bd = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "sd")) {
            sd = true;
            const len = try r.takeInt(u32, .little);
            out.sd = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "ch")) {
            ch = true;
            const len = try r.takeInt(u32, .little);
            out.ch = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "oh")) {
            oh = true;
            const len = try r.takeInt(u32, .little);
            out.oh = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "oc")) {
            oc = true;
            const len = try r.takeInt(u32, .little);
            out.choh = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "lt")) {
            lt = true;
            const len = try r.takeInt(u32, .little);
            out.lt = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "ht")) {
            ht = true;
            const len = try r.takeInt(u32, .little);
            out.ht = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "cy")) {
            cy = true;
            const len = try r.takeInt(u32, .little);
            out.cy = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "xx")) {
            xx = true;
            const len = try r.takeInt(u32, .little);
            out.xx = try r.take(len);
            continue;
        }

        if (eql(u8, slot, "yy")) {
            yy = true;
            const len = try r.takeInt(u32, .little);
            out.yy = try r.take(len);
            continue;
        }

        return error.InvalidKit;
    }

    return out;
}
