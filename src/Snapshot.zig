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

const Params = @import("Params.zig");

enabled: bool = false,
params: Params = .{},

pub fn upload(self: *@This(), params: *const Params) void {
    @atomicStore(bool, &self.enabled, false, .seq_cst);
    self.params.assume(params);
    @atomicStore(bool, &self.enabled, true, .seq_cst);
}

pub fn delete(self: *@This()) void {
    @atomicStore(bool, &self.enabled, false, .seq_cst);
    @atomicStore(usize, &self.params.drums.kit, 0, .seq_cst);
}

pub fn active(self: *const @This()) bool {
    return @atomicLoad(bool, &self.enabled, .seq_cst);
}
