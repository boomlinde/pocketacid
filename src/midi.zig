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

pub const In = struct {
    status: u8 = 0,
    buf: [2]u7 = undefined,
    buflen: usize = 0,
    sysex: bool = false,

    pub fn consume(self: *In, packet: u8) ?Event {
        // Realtime messages
        if (packet >= 0xf8) {
            return Event.decode(packet, self.buf[0..self.buflen]);
        }

        // SysEx
        if (packet == 0xf0) {
            self.sysex = true;
            self.status = 0;
            self.buflen = 0;
            return .sysex_begin;
        }
        if (packet == 0xf7) {
            self.sysex = false;
            self.status = 0;
            self.buflen = 0;
            return .sysex_end;
        }

        // System common and channel messages
        if (packet >= 0x80) {
            self.status = packet;
            self.sysex = false;
            defer self.buflen = 0;
            return Event.decode(packet, self.buf[0..self.buflen]);
        }

        if (self.sysex) return .{ .sysex_data = @intCast(packet) };

        if (self.buflen < self.buf.len) {
            self.buf[self.buflen] = @intCast(packet);
            self.buflen += 1;
        }

        if (Event.decode(self.status, self.buf[0..self.buflen])) |m| {
            self.buflen = 0;
            return m;
        }

        return null;
    }

    pub fn reset(self: *In) void {
        self.* = .{};
    }
};

pub const Event = union(enum) {
    pub fn channel(self: Event) ?u4 {
        switch (self) {
            inline else => |v| {
                if (@typeInfo(@TypeOf(v)) != .@"struct") return null;
                if (@hasField(@TypeOf(v), "channel")) return v.channel;
            },
        }
        return null;
    }

    fn decode(status: u8, data: []u7) ?Event {
        return switch (status & 0xf0) {
            0x80 => Encodable(NoteOff).decode(status, data),
            0x90 => Encodable(NoteOn).decode(status, data),
            0xa0 => Encodable(PolyphonicAftertouch).decode(status, data),
            0xb0 => Encodable(ControlChange).decode(status, data),
            0xc0 => Encodable(ProgramChange).decode(status, data),
            0xd0 => Encodable(ChannelAftertouch).decode(status, data),
            0xe0 => Encodable(PitchWheel).decode(status, data),
            0xf0 => switch (status) {
                // SysEx
                0xf0 => Encodable(SysexBegin).decode(status, data),
                0xf7 => Encodable(SysexEnd).decode(status, data),

                // MTC
                0xf1 => Encodable(QuarterFrame).decode(status, data),

                // System Common
                0xf2 => Encodable(SongPointer).decode(status, data),
                0xf3 => Encodable(SongSelect).decode(status, data),
                0xf6 => Encodable(TuneRequest).decode(status, data),

                // System realtime
                0xf8 => Encodable(TimingClock).decode(status, data),
                0xf9 => Encodable(MeasureEnd).decode(status, data),
                0xfa => Encodable(Start).decode(status, data),
                0xfb => Encodable(Continue).decode(status, data),
                0xfc => Encodable(Stop).decode(status, data),
                0xfe => Encodable(ActiveSensing).decode(status, data),
                0xff => Encodable(Reset).decode(status, data),

                else => null,
            },
            else => null,
        };
    }
    pub const NoteOff = struct {
        channel: u4,
        pitch: u7,
        velocity: u7,
        const status_mask = 0x80;
    };

    pub const NoteOn = struct {
        channel: u4,
        pitch: u7,
        velocity: u7,
        const status_mask = 0x90;
    };

    pub const PolyphonicAftertouch = struct {
        channel: u4,
        pitch: u7,
        pressure: u7,
        const status_mask = 0xa0;
    };

    pub const ControlChange = struct {
        channel: u4,
        controller: u7,
        value: u7,
        const status_mask = 0xb0;
    };

    pub const ProgramChange = struct {
        channel: u4,
        program: u7,
        const status_mask = 0xc0;
    };

    pub const ChannelAftertouch = struct {
        channel: u4,
        pressure: u7,
        const status_mask = 0xd0;
    };

    pub const PitchWheel = struct {
        channel: u4,
        value: u14,
        const status_mask = 0xe0;
    };

    pub const SongSelect = struct {
        song: u7,
        const status_mask = 0xf3;
    };

    pub const SongPointer = struct {
        value: u14,
        const status_mask = 0xf2;
    };

    pub const QuarterFrame = struct {
        value: u7,
        const status_mask = 0xf1;
    };

    pub const SysexBegin = struct {
        const status_mask = 0xf0;
    };

    pub const SysexEnd = struct {
        const status_mask = 0xf7;
    };

    pub const TuneRequest = struct {
        const status_mask = 0xf6;
    };

    pub const TimingClock = struct {
        const status_mask = 0xf8;
    };

    pub const MeasureEnd = struct {
        const status_mask = 0xf9;
    };

    pub const Start = struct {
        const status_mask = 0xfa;
    };

    pub const Continue = struct {
        const status_mask = 0xfb;
    };

    pub const Stop = struct {
        const status_mask = 0xfc;
    };

    pub const ActiveSensing = struct {
        const status_mask = 0xfe;
    };

    pub const Reset = struct {
        const status_mask = 0xff;
    };

    fn Encodable(comptime T: type) type {
        const std = @import("std");
        const len = lenblk: {
            var l: usize = 0;
            for (std.meta.fields(T)) |field| {
                if (std.mem.eql(u8, field.name, "channel"))
                    continue;
                l += switch (field.type) {
                    u7 => 1,
                    u14 => 2,
                    else => @compileError("unexpected type " ++ @typeName(field.type)),
                };
            }
            break :lenblk l;
        };
        return struct {
            inline fn decode(status: u8, data: []u7) ?Event {
                if (data.len < len) return null;
                var v: T = undefined;
                if (@hasField(T, "channel"))
                    v.channel = @intCast(status & 0xf);

                comptime var idx = 0;
                inline for (std.meta.fields(T)) |field| {
                    switch (field.type) {
                        u7 => {
                            @field(v, field.name) = data[idx];
                            idx += 1;
                        },
                        u14 => {
                            @field(v, field.name) = data14(data[idx], data[idx + 1]);
                            idx += 2;
                        },
                        u4 => {},
                        else => @compileError("unexpected type " ++ @typeName(field.type)),
                    }
                }

                inline for (std.meta.fields(Event)) |field| {
                    if (field.type == T) return @unionInit(Event, field.name, v);
                }

                @compileError("not a Event field");
            }

            pub fn encode(self: T, buf: *EncodingBuf) ![]u8 {
                const arr = self.bytes();
                for (arr) |b| {
                    try buf.append(b);
                }
                return buf.emit();
            }

            pub fn bytes(self: T) [T.size()]u8 {
                var out: [T.size()]u8 = undefined;

                out[0] = (if (@hasField(T, "channel"))
                    T.status_mask | self.channel
                else
                    T.status_mask);
                var idx: usize = 1;
                inline for (std.meta.fields(T)) |field| {
                    switch (field.type) {
                        u4 => {},
                        u7 => {
                            out[idx] = @field(self, field.name);
                            idx += 1;
                        },
                        u14 => {
                            const v = @field(self, field.name);
                            out[idx] = @intCast(v & 0x7f);
                            idx += 1;
                            out[idx] = @intCast(v >> 7);
                            idx += 1;
                        },
                        else => @compileError("unexpected type " ++ @typeName(field.type)),
                    }
                }
                return out;
            }

            pub inline fn size() usize {
                comptime var s: usize = 1;
                inline for (std.meta.fields(T)) |field| switch (field.type) {
                    u4 => {},
                    u7 => s += 1,
                    u14 => s += 2,
                    else => @compileError("bad midi event field"),
                };
                return s;
            }
        };
    }

    note_off: NoteOff,
    note_on: NoteOn,
    polyphonic_aftertouch: PolyphonicAftertouch,
    control_change: ControlChange,
    program_change: ProgramChange,
    channel_aftertouch: ChannelAftertouch,
    pitch_wheel: PitchWheel,
    sysex_begin: SysexBegin,
    sysex_data: u7,
    sysex_end: SysexEnd,
    song_pointer: SongPointer,
    song_select: SongSelect,
    tune_request: TuneRequest,
    quarter_frame: QuarterFrame,
    timing_clock: TimingClock,
    measure_end: MeasureEnd,
    start: Start,
    @"continue": Continue,
    stop: Stop,
    active_sensing: ActiveSensing,
    reset: Reset,
};

fn data14(d1: u7, d2: u7) u14 {
    return (@as(u14, d2) << 7) | @as(u14, d1);
}

test In {
    const t = @import("std").testing;
    const data = [_]u8{
        0x93, 0x12, 0xf8, 0x34, // Note on interrupted by clock
        0xf8, 0x56, 0x78, 0xf8, // Clock followed by running note on and clock
        0xe2, 0xf8, 0x01, 0x7f, // Pitch wheel interrupted by clock
        0xf0, 0x12, 0x34, 0xf8, // SysEx interrupted by clock
        0x56, 0x67, 0x55, 0xf7, // SysEx end
        0x81, 0x44, 0xf8, 0x33, // Note Off interrupted by clock
    };

    var in = In{};
    var idx: usize = 0;

    const expected = [_]Event{
        .timing_clock,
        .{ .note_on = .{ .channel = 3, .pitch = 0x12, .velocity = 0x34 } },
        .timing_clock,
        .{ .note_on = .{ .channel = 3, .pitch = 0x56, .velocity = 0x78 } },
        .timing_clock,
        .timing_clock,
        .{ .pitch_wheel = .{ .channel = 2, .value = 0b1111111_0000001 } },
        .sysex_begin,
        .{ .sysex_data = 0x12 },
        .{ .sysex_data = 0x34 },
        .timing_clock,
        .{ .sysex_data = 0x56 },
        .{ .sysex_data = 0x67 },
        .{ .sysex_data = 0x55 },
        .sysex_end,
        .timing_clock,
        .{ .note_off = .{ .channel = 1, .pitch = 0x44, .velocity = 0x33 } },
    };

    for (data) |b| if (in.consume(b)) |message| {
        try t.expectEqualDeep(expected[idx], message);
        idx += 1;
    };
    try t.expectEqual(expected.len, idx);
}

pub const EncodingBuf = struct {
    buf: []u8,
    written: usize = 0,
    total_written: usize = 0,

    pub fn append(self: *EncodingBuf, b: u8) !void {
        if (self.written >= self.buf.len)
            return error.EncodingBufFull;
        self.buf[self.written] = b;
        self.written += 1;
        self.total_written += 1;
    }

    pub fn emit(self: *EncodingBuf) []u8 {
        const out = self.buf[0..self.written];
        self.buf = self.buf[self.written..self.buf.len];
        self.written = 0;
        return out;
    }
};

test EncodingBuf {
    const t = @import("std").testing;

    var buf: [4]u8 = undefined;
    var eb = EncodingBuf{ .buf = &buf };

    try eb.append(0x12);
    try eb.append(0x34);
    try t.expectEqual(2, eb.written);
    try t.expectEqual(2, eb.total_written);
    try t.expectEqualSlices(u8, &[_]u8{ 0x12, 0x34 }, eb.emit());
    try eb.append(0x45);
    try eb.append(0x67);
    try t.expectEqual(2, eb.written);
    try t.expectEqual(4, eb.total_written);
    try t.expectEqualSlices(u8, &[_]u8{ 0x45, 0x67 }, eb.emit());
    try t.expectError(error.EncodingBufFull, eb.append(0x45));
}
