
const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Loc,


    pub const Offset = u32;
    pub const Loc = struct {
        beg: Offset,
        end: Offset,
    };

    pub const Tag = enum (u8) {
        @"[eof]",
        @"[invalid]",
        @"[ident]",
        @"[raw_ident]",
        @"[doc_container]",
        @"[doc_decl]",
        @"[string]",
        @"[raw_string]",
        @"[char]",
        @"[number]",

        @"and",
        @"fun",
        @"fun!",
        @"let",
        @"let!",
        @"mut",
        @"or",

        @"if",
        @"else",
        @"elseif",


        @"(",
        @")",
        @"{",
        @"}",
        @"[",
        @"]",
        @":",
        @",",
        @";",
        @"?",
        @"@",

        @"!",
        @"!=",

        @"<",
        @"<=",

        @">",
        @">=",

        @"=",
        @"==",
        @"=>",

        @"+",
        @"+=",

        @"-",
        @"-=",

        @"*",
        @"*=",

        @"/",
        @"/=",

        @"%",
        @"%=",

        @".",
        @".*",
        @".?",


        pub fn bang(self: Tag) ?Tag {
            return switch (self) {
                .@"let" => .@"let!",
                .@"fun" => .@"fun!",
                else    => null
            };
        }
    };

    const KEYWORDS: std.StaticStringMap(Tag) = .initComptime(.{
        .{"and", .@"and"},
        .{"fun", .@"fun"},
        .{"let", .@"let"},
        .{"mut", .@"mut"},
        .{"or",  .@"or" },

        .{"if", .@"if"},
        .{"else", .@"else"},
        .{"elseif", .@"elseif"},

    });

    pub fn keyword(word: []const u8) ?Tag {
        return KEYWORDS.get(word);
    }

    pub fn slice(t: Token, src: Buffer) []const u8 {
        return src[t.loc.beg .. t.loc.end];
    }
};


const State = enum (u8) {
    eof,
    invalid,
    start,
    ident,
    bang,
    greater,
    less,
    equal,
    plus,
    minus,
    asterisk,
    slash,
    percent,
    period,

    comment_line,
    backslash,
    raw_string,
    string,
    string_escape,
    char,
    char_escape,
    at,
    number,
    number_radix,
    number_hex,

};


pub const Buffer = [:0]const u8;
pub const Tokenizer = @This(); // struct {
    buf: Buffer,
    idx: Token.Offset = 0,
//}

pub fn next(t: *Tokenizer) Token {
    var token: Token = .{
        .tag = .@"[invalid]",
        .loc = .{
            .beg = t.idx,
            .end = t.idx,
        }
    };

    to: switch(State.start) {
        .eof => if (t.buf.len == t.idx) {
            return .{
                .tag = .@"[eof]",
                .loc = .{ .beg = t.idx, .end = t.idx },
            };
        } else {
            continue :to .invalid;
        },
        .invalid => {
            t.idx += 1;
            token.tag = .@"[invalid]";
            switch (t.buf[t.idx]) {
                0, '\n' => {},
                else => continue :to .invalid,
            }
        },
        .start => switch(t.buf[t.idx]) {
            0 => continue :to .eof,
            ' ', '\t', '\r', '\n' => {
                t.idx += 1;
                token.loc.beg = t.idx;
                continue :to .start;
            },
            '(' => {
                t.idx += 1;
                token.tag = .@"(";
            },
            ')' => {
                t.idx += 1;
                token.tag = .@")";
            },
            '{' => {
                t.idx += 1;
                token.tag = .@"{";
            },
            '}' => {
                t.idx += 1;
                token.tag = .@"}";
            },
            '[' => {
                t.idx += 1;
                token.tag = .@"[";
            },
            ']' => {
                t.idx += 1;
                token.tag = .@"]";
            },
            ':' => {
                t.idx += 1;
                token.tag = .@":";
            },
            ',' => {
                t.idx += 1;
                token.tag = .@",";
            },
            ';' => {
                t.idx += 1;
                token.tag = .@";";
            },
            '?' => {
                t.idx += 1;
                token.tag = .@"?";
            },

            '@' => continue :to .at,
            '!' => continue :to .bang,
            '<' => continue :to .less,
            '>' => continue :to .greater,
            '=' => continue :to .equal,
            '+' => continue :to .plus,
            '-' => continue :to .minus,
            '*' => continue :to .asterisk,
            '/' => continue :to .slash,
            '%' => continue :to .percent,
            '.' => continue :to .period,
            '\\'=> continue :to .backslash,
            '"' => {
                token.tag = .@"[string]";
                continue :to .string;
            },
            '\'' => {
                token.tag = .@"[char]";
                continue :to .char;
            },
            'a'...'z',
            'A'...'Z',
            '_' => {
                token.tag = .@"[ident]";
                continue :to .ident;
            },
            '0' => switch(t.buf[t.idx + 1]) {
                'b', 'o',
                'B', 'O', => {
                    t.idx += 1; // consume '[boxBOX]'
                    token.tag = .@"[number]";
                    continue :to .number_radix;
                },
                'x', 'X' => {
                    token.tag = .@"[number]";
                    t.idx += 1;
                    continue :to .number_hex;
                },
                else => {
                    token.tag = .@"[number]";
                    continue :to .number;
                },
            },
            '1'...'9' => {
                token.tag = .@"[number]";
                continue :to .number;
            },
            else => continue :to .invalid,
        }, // start
        .ident => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                'a'...'z',
                'A'...'Z',
                '0'...'9',
                '_' => continue :to .ident,
                else => {
                    const ident = t.buf[token.loc.beg .. t.idx];
                    if (Token.keyword(ident)) |keyword| {
                        token.tag = keyword;
                        if (t.buf[t.idx] == '!') {
                            if (keyword.bang()) |kw_bang| {
                                t.idx += 1;
                                token.tag = kw_bang;
                            }
                        }
                    }
                }
            }
        }, // .ident
        .bang => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"!=";
                },
                else => token.tag = .@"!",
            }
        }, // bang
        .less => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"<=";
                },
                else => token.tag = .@"<",
            }
        },
        .greater => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@">=";
                },
                else => token.tag = .@">",
            }
        },
        .equal => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"==";
                },
                '>' => {
                    t.idx += 1;
                    token.tag = .@"=>";
                },
                else => token.tag = .@"=",
            }
        },
        .plus =>  {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"+=";
                },
                else => token.tag = .@"+",
            }
        },
        .minus =>  {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"-=";
                },
                else => token.tag = .@"-",
            }
        },
        .asterisk =>  {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"*=";
                },
                else => token.tag = .@"*",
            }
        },
        .slash =>  {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"/=";
                },
                '/' => continue :to .comment_line,
                else => token.tag = .@"/",
            }
        },
        .percent =>  {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '=' => {
                    t.idx += 1;
                    token.tag = .@"%=";
                },
                else => token.tag = .@"%",
            }
        },
        .period => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '*' => {
                    t.idx += 1;
                    token.tag = .@".*";
                },
                '?' => {
                    t.idx += 1;
                    token.tag = .@".?";
                },
                else => token.tag = .@".",
            }
        },

        .comment_line => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                '\n' => continue :to .start,
                0 => continue :to .eof,
                else => continue :to .comment_line,
            }
        },
        .backslash => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                '\\' => {
                    token.tag = .@"[raw_string]";
                    continue :to .raw_string;
                },
                0, '\n' => {}, // invalid
                else => continue :to .invalid,
            }
        },

        .at => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                '"' => {
                    token.tag = .@"[raw_ident]";
                    continue :to .string;
                },
                0, '\n' => {},
                else => continue :to .invalid,
            }
        },
        .raw_string => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                0 => if (t.idx < t.buf.len) {
                    continue :to .invalid;
                },
                '\n' => {},
                '\r' => if (t.buf[t.idx + 1] != '\n') {
                    continue :to .invalid;
                },
                0x01 ... 0x09,
                0x0b ... 0x0c,
                0x0e ... 0x1f,
                0x7f => continue :to .invalid,
                else => continue :to .raw_string,
            }
        },

        .string => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                0 => if (t.idx < t.buf.len) {
                    // null-terminated
                    continue :to .invalid;
                } else {
                    // Unfinished/Unterminated
                    token.tag = .@"[invalid]";
                },
                '\n' => token.tag = .@"[invalid]",
                '\\' => continue :to .string_escape,
                // terminated
                '"' => t.idx += 1,
                0x01 ... 0x09,
                0x0b ... 0x1f,
                0x7f => continue :to .invalid,
                else => continue :to .string,
            }
        },
        .string_escape => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                0, '\n' => token.tag = .@"[invalid]",
                0x01 ... 0x09,
                0x0b ... 0x1f,
                0x7f => continue :to .invalid,
                else => continue :to .string,
            }
        },
        .char => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                0 => if (t.idx < t.buf.len) {
                    continue :to .invalid;
                } else {
                    token.tag = .@"[invalid]";
                },
                '\n' => token.tag = .@"[invalid]",
                '\\' => continue :to .char_escape,
                '\'' => t.idx += 1,
                0x01 ... 0x09,
                0x0b ... 0x1f,
                0x7f => continue :to .invalid,
                else => continue :to .char,

            }
        },
        .char_escape => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                0 => if (t.idx < t.buf.len) {
                    continue :to .invalid;
                } else {
                    token.tag= .@"[invalid]";
                },
                '\n' => token.tag = .@"[invalid]",
                0x01 ... 0x09,
                0x0b ... 0x1f,
                0x7f => continue :to .invalid,
                else => continue :to .char,
            }
        },

        .number_radix => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                '0'...'9',
                'a'...'z',
                'A'...'Z',
                '_' => continue :to .number_radix,
                else => {},
            }
        },
        .number => {
            t.idx += 1;
            switch (t.buf[t.idx]) {
                '0'...'9',
                '_',
                'a'...'d',
                'f'...'z',
                'A'...'D',
                'F'...'Z' => continue :to .number,
                'e', 'E' => switch(t.buf[t.idx + 1]) {
                    '-', '+' => switch(t.buf[t.idx + 2]) {
                        '0'...'9' => {
                            t.idx += 1; // consume [-+]
                            continue :to .number;
                        },

                        else => {
                            // token ended before [-+]
                            // eg:
                            // 1e+x -> [number] + [ident]
                            continue :to .number;
                        },
                    },
                    else => continue :to .number,
                },
                '.' => switch(t.buf[t.idx + 1]) {
                    '0'...'9' => continue :to .number,
                    else => {},
                },
                else => {},
            }
        }, // number
        .number_hex => {
            t.idx += 1;
            switch(t.buf[t.idx]) {
                '0'...'9',
                'a'...'o', 'q'...'z',
                'A'...'O', 'Q'...'Z',
                '_' => continue :to .number_hex,
                'p', 'P' => switch(t.buf[t.idx + 1]) {
                    '-', '+' => switch(t.buf[t.idx + 2]){
                        '0'...'9' => {
                            t.idx += 1;
                            continue :to .number_hex;
                        },
                        else => continue :to .number_hex,
                    },
                    else => continue :to .number_hex,
                },
                '.' => switch(t.buf[t.idx + 1]) {
                    '0'...'9',
                    'a'...'f',
                    'A'...'F' => continue :to .number_hex,
                    else => {},
                },
                else => {},
            }
        } // number_hex
    }

    token.loc.end = t.idx;
    return token;
}
