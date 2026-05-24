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

pub fn DumbPool(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        const Slot = struct {
            value: T = undefined,
            free: bool = true,
        };

        const Iter = struct {
            pool: *Self,
            idx: usize,

            pub fn next(self: *@This()) ?*T {
                while (self.idx < size) : (self.idx += 1) {
                    if (self.pool.pool[self.idx].free) continue;
                    defer self.idx += 1;
                    return &self.pool.pool[self.idx].value;
                }
                return null;
            }
        };

        pool: [size]Slot,

        pub fn init() Self {
            var self = Self{
                .pool = undefined,
            };

            for (0..self.pool.len) |i| self.pool[i] = .{};
            return self;
        }

        pub fn alloc(self: *Self) !*T {
            for (&self.pool) |*slot| {
                if (slot.free) {
                    slot.free = false;
                    return &slot.value;
                }
            }
            return error.NoFreeSlots;
        }

        pub fn free(self: *Self, addr: *T) void {
            const ptr: *Slot = @fieldParentPtr("value", addr);
            self.pool[sliceIndex(Slot, ptr, &self.pool)].free = true;
        }

        pub fn iter(self: *Self) Iter {
            return .{
                .pool = self,
                .idx = 0,
            };
        }
    };
}

fn sliceIndex(comptime T: type, addr: *const T, slice: []const T) usize {
    return @divTrunc(@intFromPtr(addr) - @intFromPtr(&slice[0]), @sizeOf(T));
}

test "DumbPool" {
    const expectError = @import("std").testing.expectError;
    const expect = @import("std").testing.expect;

    var v = DumbPool(i32, 2).init();

    const addr1 = try v.alloc();
    const addr2 = try v.alloc();
    addr1.* = 2;
    addr2.* = 4;
    try expect(addr1 != addr2);
    try expectError(error.NoFreeSlots, v.alloc());
    v.free(addr1);
    const addr3 = try v.alloc();
    addr3.* = 3;
    try expect(addr3 == addr1);

    var i = v.iter();
    var found3 = false;
    var found4 = false;
    var foundOther = false;
    while (i.next()) |value| {
        if (value.* == 3)
            found3 = true
        else if (value.* == 4)
            found4 = true
        else
            foundOther = true;
    }
    try expect(found3);
    try expect(found4);
    try expect(!foundOther);
}
