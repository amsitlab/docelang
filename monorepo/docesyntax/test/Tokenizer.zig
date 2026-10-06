const std = @import("std");
const docesyntax = @import("docesyntax");
const Tokenizer = docesyntax.Tokenizer;
const Token = Tokenizer.Token;

fn expectTags(buf: [:0]const u8, expected: []const u8) !void {
    //std.debug.print("{{\n {s}\n}}", .{buf});
    var t: Tokenizer = .{
        .buf = buf,
    };
    var it = std.mem.tokenizeScalar(u8, expected, ' ');
    while (it.next()) |name| {
        const token = t.next();
        try std.testing.expectEqualStrings(name, @tagName(token.tag));
    }
    try std.testing.expectEqual(.@"[eof]", t.next().tag);
}


test "[eof]" {
    try expectTags("", "");
    try expectTags("\x00", "[invalid]");
    try expectTags("\t\r\n", "");
}

test "[invalid]" {
    // contains \0 before eof.
    try expectTags("\x00a", "[invalid]");
    // ident startwith digit
}

test "[ident]" {
    try expectTags("a", "[ident]");
    try expectTags("A", "[ident]");
    try expectTags("a0", "[ident]");
    try expectTags("_", "[ident]");
    try expectTags("_0", "[ident]");
    try expectTags("a_", "[ident]");
}

test "function call" {
    try expectTags("fx()", "[ident] ( )");
    try expectTags("StructBuilder(){}", "[ident] ( ) { }");
}

test "keyword with bang (let!)" {
    try expectTags("let!", "let!");
    try expectTags("foo!", "[ident] !");
    try expectTags("true!=false", "[ident] != [ident]");

}

test "operator <" {
    try expectTags("a < b", "[ident] < [ident]");
    try expectTags("a <= b", "[ident] <= [ident]");
}
test "operator >" {
    try expectTags("a > b", "[ident] > [ident]");
    try expectTags("a >= b", "[ident] >= [ident]");
}

test "operator =" {
    try expectTags("=", "=");
    try expectTags("a = b", "[ident] = [ident]");
    try expectTags("let a = b", "let [ident] = [ident]");
    try expectTags("let! a = b", "let! [ident] = [ident]");
}

test "operator !=" {
    try expectTags("a != b", "[ident] != [ident]");
    try expectTags(
        \\a ! =
        \\ b
        ,
        "[ident] ! = [ident]"
    );
}

test "operator => " {
    try expectTags("=>", "=>");
    try expectTags("a => b", "[ident] => [ident]");
    try expectTags(
        \\(a, b) => {
        \\    a == b
        \\}
        ,
        "( [ident] , [ident] ) => { [ident] == [ident] }"
    );
}

test "operator +" {
    try expectTags("+", "+");
    try expectTags(
        "a + b",
        "[ident] + [ident]"
    );
}

test "operator +=" {
    try expectTags("+=", "+=");
    try expectTags("+=+", "+= +");
    try expectTags(
        "a += b",
        "[ident] += [ident]"
    );
}

test "operator -" {
    try expectTags("-", "-");
    try expectTags(
        "a - b",
        "[ident] - [ident]"
    );
}

test "operator -=" {
    try expectTags("-=", "-=");
    try expectTags("-=- ", "-= -");
    try expectTags(
        "a -= b",
        "[ident] -= [ident]"
    );
}

test "operator *" {
    try expectTags("*", "*");
    try expectTags(
        "a * b",
        "[ident] * [ident]"
    );
}

test "operator *=" {
    try expectTags("*=", "*=");
    try expectTags("*=*", "*= *");
    try expectTags(
        "a *= b",
        "[ident] *= [ident]"
    );
}

test "operator /" {
    try expectTags("/", "/");
    try expectTags(
        "a / b",
        "[ident] / [ident]"
    );
}

test "operator /=" {
    try expectTags("/=", "/=");
    try expectTags("/=/", "/= /");
    try expectTags(
        "a /= b",
        "[ident] /= [ident]"
    );
}

test "operator %" {
    try expectTags("%", "%");
    try expectTags(
        "a % b",
        "[ident] % [ident]"
    );
}

test "operator %=" {
    try expectTags("%=", "%=");
    try expectTags("%=%", "%= %");
    try expectTags(
        "a %= b",
        "[ident] %= [ident]"
    );
}

test "operator .*" {
    try expectTags(".*", ".*");
    try expectTags(". *", ". *");
    try expectTags("ident.*", "[ident] .*");
    try expectTags("ident. *", "[ident] . *");
    try expectTags("ident . *", "[ident] . *");
}

test "operator .?" {
    try expectTags(".?", ".?");
    try expectTags(". ?", ". ?");
    try expectTags("ident.?", "[ident] .?");
    try expectTags("ident. ?", "[ident] . ?");
    try expectTags("ident . ?", "[ident] . ?");
}

test "operator . with literals" {
    try expectTags(".{}", ". { }");
    try expectTags("a.new()", "[ident] . [ident] ( )");
    try expectTags("p.*.x", "[ident] .* . [ident]");
    try expectTags("p.* = 1", "[ident] .* = [number]");
    try expectTags("p.*+=1", "[ident] .* += [number]");
    try expectTags("p.?.*", "[ident] .? .*");
    try expectTags("1.*", "[number] .*");
}

test "comment line" {
    try expectTags("//", "");
    try expectTags("//a\n", "");
    try expectTags("//a\t\r\n", "");
    try expectTags("// this is comment", "");
    try expectTags(
        \\// this is skipped
        \\a
        ,
        "[ident]"
    );
    try expectTags(
        \\// wrapping ident with comment
        \\a // <-- ident
        \\// this should be skipped
        ,
        "[ident]"
    );
    try expectTags(
        \\// repeating comment line
        \\// this is skipped
        \\// also this
        ,
        ""
    );

    try expectTags("// comment contains \x00 null-terminated", "[invalid]");

}

test "raw string line" {
    try expectTags("\\\\abc", "[raw_string]");
    try expectTags("\\\\", "[raw_string]");
    try expectTags("\\\\abc\n\\\\def", "[raw_string] [raw_string]");
    try expectTags("  \\\\abc\n  \\\\def\n", "[raw_string] [raw_string]");
    try expectTags("\\\\ \"x\" // bukan komentar", "[raw_string]");
    try expectTags("a \\\\ x\nb", "[ident] [raw_string] [ident]");
    try expectTags("\\", "[invalid]");
    try expectTags("\\x", "[invalid]");
    try expectTags("\\\n", "[invalid]");
}

test "raw string CRLF" {
    try expectTags("\\\\abc\r\n\\\\def", "[raw_string] [raw_string]");
    try expectTags("\\\\\r\n", "[raw_string]");
    try expectTags("\\\\abc\r", "[invalid]");
    try expectTags("\\\\ab\rc", "[invalid]");
    try expectTags("\\\\a\tb", "[invalid]");           // decline
}

test "string literal" {
    try expectTags("\"abc\"", "[string]");
    try expectTags("\"\"", "[string]");
    try expectTags("\"a\\\"b\"", "[string]");
    try expectTags("\"a\\\\\"", "[string]");
    try expectTags("\"a\\nb\"", "[string]");
    try expectTags("\"é\"", "[string]");
    try expectTags("\"// not comment\"", "[string]");
    try expectTags("\"a\" \"b\"", "[string] [string]");

    try expectTags("\"", "[invalid]");
    try expectTags("\"a", "[invalid]");
    try expectTags("\"a\nb\"", "[invalid] [ident] [invalid]");
    try expectTags("\"\\", "[invalid]");              // escape at end
    try expectTags("\"a\\\n", "[invalid]");           // escape then newline

    try expectTags("\"a\tb\"", "[invalid]");          // tab literal declined
    try expectTags("\"a\x01b\"", "[invalid]");
    try expectTags("\"a\x7fb\"", "[invalid]");
    try expectTags("\"a\x00b\"", "[invalid]");        // contain null-terminator
    try expectTags("\"a\x01b\" c", "[invalid]");
}


test "raw identifier" {
    try expectTags("@\"let\"", "[raw_ident]"); // not keyword
    try expectTags("@\"a b\"", "[raw_ident]");
    try expectTags("@\"\"", "[raw_ident]"); // should error in parser
    try expectTags("a @\"b\" c", "[ident] [raw_ident] [ident]");
    try expectTags("@\"let\"!", "[raw_ident] !");
    try expectTags("@", "[invalid]");
    try expectTags("@x", "[invalid]");
    try expectTags("@\"abc", "[invalid]");
    try expectTags("@\"a\nb\"", "[invalid] [ident] [invalid]");
}

test "char literal" {
    try expectTags("'a'", "[char]");
    try expectTags("'\\n'", "[char]");
    try expectTags("'\\''", "[char]");
    try expectTags("'\\\\'", "[char]");
    try expectTags("'é'", "[char]");
    try expectTags("'\"'", "[char]");
    try expectTags("'a' 'b'", "[char] [char]");
    try expectTags("''", "[char]");
    try expectTags("'ab'", "[char]");

    try expectTags("'", "[invalid]");
    try expectTags("'a", "[invalid]");
    try expectTags("'a\nb'", "[invalid] [ident] [invalid]");
    try expectTags("'\\", "[invalid]");
    try expectTags("'\\\n", "[invalid]");
    try expectTags("'\t'", "[invalid]");
    try expectTags("'\x01'", "[invalid]");
    try expectTags("'a\x00b'", "[invalid]");
}


test "number: batas token" {
    try expectTags("0", "[number]");
    try expectTags("42", "[number]");
    try expectTags("3.14", "[number]");
    try expectTags("1_000", "[number]");
    try expectTags("1 2", "[number] [number]");
    try expectTags("a+1", "[ident] + [number]");
    try expectTags("b - -3", "[ident] - - [number]");

    try expectTags("1e5", "[number]");
    try expectTags("1e+3", "[number]");
    try expectTags("1.5e-3", "[number]");
    try expectTags("0e+3", "[number]");

    try expectTags("0x1F", "[number]");
    try expectTags("0x1e+3", "[number] + [number]");   // `e` di hex adalah digit
    try expectTags("0X1E+3", "[number] + [number]");
    try expectTags("0b1e+1", "[number] + [number]");

    try expectTags("1e+x", "[number] + [ident]");      // tanda tidak ditelan
    try expectTags("1e", "[number]");
    try expectTags("1e+", "[number] +");

    // lolos lexer, ditolak validator
    try expectTags("0123", "[number]");
    try expectTags("0abc", "[number]");
    try expectTags("1_", "[number]");
    try expectTags("0x", "[number]");
    try expectTags("1.5.3", "[number]");
    try expectTags("12abc + 1", "[number] + [number]");
}

test "number: hex float" {
    try expectTags("0x1.8p3", "[number]");
    try expectTags("0x1p-2", "[number]");
    try expectTags("0x1P+2", "[number]");
    try expectTags("0xA.Bp0", "[number]");
    try expectTags("0x1.8", "[number]");          // tanpa eksponen: lolos lexer, validator yang memutuskan
    try expectTags("0x.8p1", "[number]");         // tanpa digit sebelum titik
    try expectTags("0xFF_FF.0Fp1", "[number]");

    try expectTags("0x1e+3", "[number] + [number]");   // `e` di hex adalah digit
    try expectTags("0x1p+x", "[number] + [ident]");    // tanda tidak ditelan
    try expectTags("0x1p", "[number]");
    try expectTags("0x1p+", "[number] +");
    try expectTags("0x1.8p3 + 1", "[number] + [number]");

    try expectTags("0xFF.foo", "[number]");            // ambiguitas yang dibahas di atas
    try expectTags("0X1.8P3", "[number]");             // prefix besar, ditolak validator
}

test "number: radix biner and octal" {
    try expectTags("0b1.1", "[number] . [number]");
    try expectTags("0o7p+1", "[number] + [number]");
    try expectTags("0b1010_0101", "[number]");
}

test "number: valid zig literals are a single token" {
    const cases = [_][:0]const u8{
        "0",           "123",         "1_000",       "0.5",
        "1.5e10",      "1e-3",        "1E+3",        "1_0.0_1e1_0",
        "0b1010",      "0b1010_0101", "0o777",       "0o7_7",
        "0xff",        "0xDEAD_beef", "0x1.8p3",     "0x1p-2",
        "0xA.Bp+1",    "0x1e",
    };
    for (cases) |src| {
        var t: Tokenizer = .{ .buf = src };
        const tok = t.next();
        try std.testing.expectEqual(Token.Tag.@"[number]", tok.tag);
        try std.testing.expectEqual(@as(Token.Offset, @intCast(src.len)), tok.loc.end);
        try std.testing.expectEqual(Token.Tag.@"[eof]", t.next().tag);
    }
}

test "number: token boundaries" {
    {
        var t: Tokenizer = .{ .buf = "0x1e+5" };
        const a = t.next();
        try std.testing.expectEqual(@as(Token.Offset, 4), a.loc.end);
        try std.testing.expectEqual(Token.Tag.@"+", t.next().tag);
        try std.testing.expectEqual(Token.Tag.@"[number]", t.next().tag);
    }
    {
        // "1e+x" -> "1e" (validator menolak), "+", "x"
        var t: Tokenizer = .{ .buf = "1e+x" };
        try std.testing.expectEqual(@as(Token.Offset, 2), t.next().loc.end);
        try std.testing.expectEqual(Token.Tag.@"+", t.next().tag);
        try std.testing.expectEqual(Token.Tag.@"[ident]", t.next().tag);
    }
}

// Perbedaan disengaja dari std/zig/tokenizer.zig (master). Kalau test ini
// gagal, berarti lexer berubah perilaku, bukan sekadar refactor.
test "number: beda disengaja dari tokenizer Zig" {
    // Zig menelan tanda +/- setelah e/E/p/P tanpa cek digit dan tidak
    // memperlakukan `e` di hex sebagai digit, jadi keduanya satu token di Zig.
    try expectTags("0x1e+3", "[number] + [number]");
    try expectTags("1e+x", "[number] + [ident]");

    // Zig menelan huruf setelah titik (`1.foo` satu token). Di sini `.` adalah
    // akses anggota, jadi angka berhenti sebelum titik kalau bukan disusul digit.
    try expectTags("1.foo", "[number] . [ident]");
    try expectTags("1..2", "[number] . . [number]");

    // Lexer longgar: `.` + digit diterima di mana saja setelah angka dimulai,
    // validator yang menolaknya. Zig berhenti di `.` setelah eksponen bertanda
    // atau setelah pecahan, mis. `1.5.3` jadi `1.5` `.` `3`.
    try expectTags("1.5.3", "[number]");
    try expectTags("1e+5.3", "[number]");
    try expectTags("0x1p+3.5", "[number]");
}

// Sama dengan Zig, dikunci supaya tidak berubah.
test "number: titik sebelum operator postfix" {
    try expectTags("1.*", "[number] .*");
    try expectTags("1.?", "[number] .?");
    try expectTags("1e5.3", "[number]");
}
