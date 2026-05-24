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

const Tokenizer = @This();

reader: *std.io.Reader,
buf: []u8,
n: usize = 0,
again: ?u8 = null,
mode: enum {
    normal,
    normal_escaped,
    string,
    string_escaped,
    comment,
} = .normal,

fn append(self: *Tokenizer, ch: u8) !void {
    if (self.n >= self.buf.len) return error.TokenTooLong;

    self.buf[self.n] = ch;
    self.n += 1;
}

fn emit(self: *Tokenizer) ?[]u8 {
    defer self.n = 0;
    if (self.n == 0) return null;
    return self.buf[0..self.n];
}

fn consume(self: *Tokenizer, ch: u8) !?[]u8 {
    switch (self.mode) {
        .normal => switch (ch) {
            '\n', '\r', ' ', '\t' => return self.emit(),
            '{', '}', ':', '[', ']' => {
                if (self.n > 0)
                    self.again = ch
                else
                    try self.append(ch);
                return self.emit();
            },
            '#' => {
                if (self.n > 0) {
                    self.again = ch;
                    return self.emit();
                }
                self.mode = .comment;
            },
            '\\' => self.mode = .normal_escaped,
            '"' => self.mode = .string,
            else => try self.append(ch),
        },
        .normal_escaped => {
            try self.append(ch);
            self.mode = .normal;
        },
        .string => switch (ch) {
            '"' => {
                defer self.mode = .normal;
                return self.emit();
            },
            '\\' => self.mode = .string_escaped,
            else => try self.append(ch),
        },
        .string_escaped => {
            try self.append(ch);
            self.mode = .string;
        },
        .comment => if (ch == '\n') {
            self.mode = .normal;
        },
    }
    return null;
}

fn nextByte(self: *Tokenizer) !?u8 {
    if (self.again) |peeked| {
        self.again = null;
        return peeked;
    }
    var ch: [1]u8 = undefined;
    const nread = try self.reader.readSliceShort(&ch);
    if (nread == 0) return null;
    return ch[0];
}

pub fn next(self: *Tokenizer) !?[]u8 {
    while (try self.nextByte()) |ch| {
        if (try self.consume(ch)) |token| {
            return token;
        }
    }
    return try self.consume('\n');
}

test "Tokenizer" {
    var stream = std.io.Reader.fixed("{a\\ x: 10 b: \"hejsan \\\"hoppsan\\\"\"}");

    var tokenbuf: [32]u8 = undefined;
    var t = Tokenizer{
        .reader = &stream,
        .buf = &tokenbuf,
    };

    const expected = [_][]const u8{
        "{", "a x", ":", "10", "b", ":", "hejsan \"hoppsan\"", "}",
    };

    var i: usize = 0;
    while (try t.next()) |token| {
        try std.testing.expectEqualStrings(expected[i], token);
        i += 1;
    }
    try std.testing.expect(i == expected.len);
}
