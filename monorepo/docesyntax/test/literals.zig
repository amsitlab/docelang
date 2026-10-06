const std = @import("std");
const literals = @import("docesyntax").literals;
const Kind = literals.Kind;

fn expectInvalid(src: []const u8) !void {
    if (literals.validate(.number, src) == null) {
        std.debug.print("diterima padahal seharusnya ditolak: {s}\n", .{src});
        return error.TestUnexpectedResult;
    }
}

fn expectValid(src: []const u8) !void {
    if (literals.validate(.number, src)) |f| {
        std.debug.print("ditolak padahal seharusnya valid: {s} ({any})\n", .{ src, f });
        return error.TestUnexpectedResult;
    }
}

fn expectAllInvalid(comptime kind: Kind, cases: []const []const u8) !void {
    var bad: usize = 0;
    for (cases) |src| {
        if (literals.validate(kind, src) == null) {
            std.debug.print("must be rejected but [accepted]: {s}\n", .{src});
            bad += 1;
        }
    }
    if (bad > 0) return error.TestUnexpectedResult;
}

fn expectAllValid(comptime kind: Kind, cases: []const []const u8) !void {
    var bad: usize = 0;
    for (cases) |src| {
        if (literals.validate(kind, src)) |f| {
            std.debug.print("must be accepted but [rejected]: {s} {any}\n", .{src, f});
            bad += 1;
        }
    }
    if (bad > 0) return error.TestUnexpectedResult;
}

test "number: valid" {
    const cases = [_][]const u8{
        "0",        "123",         "1_000",       "0.5",
        "1.5e10",   "1e-3",        "1E+3",        "1_0.0_1e1_0",
        "0b1010",   "0b1010_0101", "0o777",       "0o7_7",
        "0xff",     "0xDEAD_beef", "0x1.8p3",     "0x1p-2",
        "0xA.Bp+1", "0x1e",
    };
    for (cases) |src| try expectValid(src);
}

test "number: accept by lexer, reject by validator" {
    const cases = [_][]const u8{
        "0123",   // leading zero
        "0abc",
        "12abc",
        "1_",     // underscore di akhir
        "1__0",   // underscore berulang
        "0x",     // tidak ada digit
        "0X1",    // prefix huruf besar
        "0B1",
        "0b2",    // digit di luar basis
        "0o8",
        "1e",     // eksponen kosong
        "1e+",
        "0x1p",
        "1.5.3",
        "1e5.3",  // titik setelah eksponen
        "1e+5.3",
        "0x1p+3.5",
        "0xFF.foo",
    };
    //for (cases) |src| try expectInvalid(src);
    try expectAllInvalid(.number, &cases);
}

test "number: period after exponent reported identically on every zig version" {
    const f = literals.validate(.number, "1e5.3").?;
    try std.testing.expect(f == .period_after_exponent);
    try std.testing.expectEqual(@as(@TypeOf(f.period_after_exponent), 3), f.period_after_exponent);
}

test "char: valid" {
    const cases = [_][]const u8{
        "'a'", "'\\n'", "'\\''", "'\\\\'", "'é'", "'\"'",
        "'\\x41'", "'\\u{1F601}'", "'😀'",
    };
    try expectAllValid(.char, &cases);
}

test "char: accept by lexer, reject by validator" {
    const cases = [_][]const u8{
        "''",           // kosong
        "'ab'",         // lebih dari satu karakter
        "'\\y'",        // escape tidak dikenal
        "'\\x4'",       // hex kurang digit
        "'\\x41z'",
        "'\\u'",
        "'\\u{}'",
        "'\\u{FFFFFF}'",
        "'\\u{41'",
    };
    try expectAllInvalid(.char, &cases);
}

test "string: valid" {
    const cases = [_][]const u8{
        "\"\"", "\"abc\"", "\"é\"", "\"\\\"\"", "\"\\\\\"", "\"\\'\"",
        "\"a\\nb\"", "\"\\x41\"", "\"\\u{1F601}\"",
        "\"a\\nb\\x41\\u{1F601}c\"", // beberapa escape berurutan
        "@\"let\"", "@\"a b\"",
    };
    try expectAllValid(.string, &cases);
}

test "string: accept by lexer, reject by validator" {
    const cases = [_][]const u8{
        "\"\\y\"",
        "\"\\x4\"",
        "\"a\\xZZ\"",
        "\"\\u\"",
        "\"\\u{}\"",
        "\"\\u{FFFFFF}\"",
        "\"\\u{41\"",
        "@\"\\q\"",
    };
    try expectAllInvalid(.string, &cases);
}
