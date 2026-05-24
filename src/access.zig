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

pub fn get(o: anytype, comptime field: FieldEnum(@TypeOf(o.*))) FieldType(@TypeOf(o.*), field) {
    const T = @TypeOf(o.*);
    const FT = FieldType(T, field);

    if (comptime isArray(FT)) {
        var out: FT = undefined;

        for (&@field(o, @tagName(field)), 0..) |*p, i| {
            out[i] = if (comptime isAccessor(@TypeOf(p.*)))
                copy(p)
            else
                @atomicLoad(@TypeOf(p.*), p, .seq_cst);
        }
        return out;
    }

    return if (comptime isAccessor(FT))
        copy(&@field(o, @tagName(field)))
    else
        @atomicLoad(FT, &@field(o, @tagName(field)), .seq_cst);
}

pub fn copy(o: anytype) @TypeOf(o.*) {
    const T = @TypeOf(o.*);
    const E = FieldEnum(T);
    var out: T = undefined;
    inline for (std.meta.fields(E)) |f| {
        @field(out, f.name) = get(o, @field(E, f.name));
    }

    return out;
}

pub fn assume(o: anytype, prototype: @TypeOf(o.*)) void {
    const E = FieldEnum(@TypeOf(o.*));
    inline for (std.meta.fields(E)) |f| {
        set(o, @field(E, f.name), @field(prototype, f.name));
    }
}

pub inline fn set(o: anytype, comptime field: FieldEnum(@TypeOf(o.*)), value: FieldType(@TypeOf(o.*), field)) void {
    const T = @TypeOf(o.*);
    const FT = FieldType(T, field);

    if (comptime isAccessor(FT))
        assume(&@field(o, @tagName(field)), value)
    else
        @atomicStore(FT, &@field(o, @tagName(field)), value, .seq_cst);
}

// Only set if the value hasn't changed since first accessing it
pub inline fn setCmp(o: anytype, comptime field: FieldEnum(@TypeOf(o.*)), value: FieldType(@TypeOf(o.*), field), old: FieldType(@TypeOf(o.*), field)) void {
    const T = @TypeOf(o.*);
    const FT = FieldType(T, field);

    const ti = @typeInfo(FT);

    switch (ti) {
        .float => |fti| {
            const IT = std.meta.Int(.unsigned, fti.bits);
            _ = @cmpxchgStrong(
                IT,
                @as(*IT, @ptrCast(&@field(o, @tagName(field)))),
                @bitCast(old),
                @bitCast(value),
                .seq_cst,
                .seq_cst,
            );
        },
        else => {
            _ = @cmpxchgStrong(FT, &@field(o, @tagName(field)), old, value, .seq_cst, .seq_cst);
        },
    }
}

fn isArray(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .array => true,
        else => false,
    };
}

fn isAccessor(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| s.layout == .auto,
        else => false,
    };
}

test "access" {
    const t = std.testing;

    const Inner = struct {
        a: f32 = 100,
        b: u8 = 7,
    };

    const Struct = struct {
        i: Inner = .{},
        a: f32 = 0,
        b: u8 = 1,
        c: usize = 2,
    };
    var v = Struct{};

    try t.expectEqual(0, get(&v, .a));
    try t.expectEqual(1, get(&v, .b));
    try t.expectEqual(2, get(&v, .c));

    set(&v, .a, 31.5);
    set(&v, .b, 255);
    set(&v, .c, 555);

    assume(&v.i, .{ .b = 9 });
    try t.expectEqual(9, get(&v.i, .b));

    try t.expectEqual(31.5, get(&v, .a));
    try t.expectEqual(255, get(&v, .b));
    try t.expectEqual(555, get(&v, .c));

    try t.expectEqual(v.i, get(&v, .i));

    try t.expectEqual(v, copy(&v));
}

pub fn FieldEnum(comptime Struct: type) type {
    @setEvalBranchQuota(10_000);
    const struct_fields = std.meta.fields(Struct);
    var enum_fields: [struct_fields.len]std.builtin.Type.EnumField = undefined;
    for (struct_fields, 0..) |field, i| {
        enum_fields[i] = .{ .name = field.name, .value = i };
    }
    return @Type(.{ .@"enum" = .{
        .decls = &.{},
        .tag_type = std.math.IntFittingRange(0, enum_fields.len - 1),
        .fields = &enum_fields,
        .is_exhaustive = true,
    } });
}

test FieldEnum {
    const Struct = struct {
        a: f32,
        b: u8,
        c: struct { z: u8, x: u8 },
    };

    const Enum1: FieldEnum(Struct) = .a;
    const Enum2: FieldEnum(Struct) = .b;
    const Enum3: FieldEnum(Struct) = .c;
    _ = Enum1;
    _ = Enum2;
    _ = Enum3;
}

pub fn FieldType(comptime Struct: type, comptime field: FieldEnum(Struct)) type {
    const s: Struct = undefined;
    return @TypeOf(@field(s, @tagName(field)));
}

test FieldType {
    const t = std.testing;

    const SubStruct = struct { x: f32, y: f32 };
    const Struct = struct { a: f32, b: u8, c: SubStruct };
    try t.expectEqual(f32, FieldType(Struct, .a));
    try t.expectEqual(u8, FieldType(Struct, .b));
    try t.expectEqual(SubStruct, FieldType(Struct, .c));
}
