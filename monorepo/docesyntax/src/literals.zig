const std = @import("std");
const numlit = std.zig.number_literal;
const strlit = std.zig.string_literal;
pub const NumberError = numlit.Error;
pub const EscapeError = strlit.Error;


pub const Kind = enum {
    number,
    char,
    string,
};


pub fn Failure(comptime kind: Kind) type {
    return switch(kind){
        .number => NumberError,
        .char, .string => EscapeError,
    };
}

// https://codeberg.org/ziglang/zig/issues/36161
// for zig version <= 0.16.0 (also 0.17.0-dev)
// {{{
const std_accept_period_after_exponent = blk: {
    const probes = [_][]const u8{"1e3.5", "1e+5.3", "0x1p+3.5"};
    for (probes) |p| switch(numlit.parseNumberLiteral(p)) {
        .failure => {},
        .int, .float, .big_int => break :blk true,
    };
    break :blk false;
};

fn periodAfterExponent(slice: []const u8) ?usize {
    const is_hex = slice.len > 1 and slice[0] == '0' and (slice[1] == 'x' or slice[1] == 'X');
    var seen_exp = false;
    for (slice, 0..) |c, i| {
        switch (c) {
            'e', 'E' => if(!is_hex) {
                seen_exp = true;
            },
            'p', 'P' => if(is_hex) {
                seen_exp = true;
            },
            '.' => if (seen_exp) return i,
            else => {},
        }
    }
    return null;
}
// }}}


fn validateNumber(slice: []const u8) ?NumberError {
    if (std_accept_period_after_exponent) {
        if (periodAfterExponent(slice)) |i| {
            return .{ .period_after_exponent = i};
        }
    }
    return switch (numlit.parseNumberLiteral(slice)) {
        .failure => |f| f,
        .int, .float, .big_int => null,
    };

}

fn validateChar(slice: []const u8) ?EscapeError {
    if (slice.len < 3 or slice[0] != '\'' or slice[slice.len - 1] != '\'') {
        return .{ .expected_single_quote = 1 };
    }
    if (slice[1] != '\\') {
        const n = std.unicode.utf8ByteSequenceLength(slice[1]) catch 1;
        if (slice.len != n + 2) return .{ .expected_single_quote = 1 + n };
    }
    return switch(std.zig.parseCharLiteral(slice)) {
        .success => null,
        .failure => |f| f,
    };
}

fn validateString(slice: []const u8) ?EscapeError {
    const body: usize = if (slice[0] == '@') 2 else 1;
    const close = slice.len - 1;
    var i: usize = body;
    while (i < close) {
        if (slice[i] != '\\') {
            i += 1;
            continue;
        }
        var offset: usize = i;
        switch (strlit.parseEscapeSequence(slice, &offset)) {
            .success => i = offset,
            .failure => |f| return f,
        }
    }
    return null;
}

pub fn validate(
    comptime kind: Kind,
    slice: []const u8
) ?Failure(kind) {

    return switch(kind) {
        .number => validateNumber(slice),
        .char => validateChar(slice),
        .string => validateString(slice),
    };
}
