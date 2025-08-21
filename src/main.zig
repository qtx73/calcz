const std = @import("std");

const TokenKind = enum {
    number,
    add,
    sub,
    mul,
    div,
    mod,
    pow,
    lparen,
    rparen,
    identifier,
    comma,
    eof,
};

const TokenizeError = error{
    InvalidCharacter,
    InvalidNumber,
    Overflow,
} || std.mem.Allocator.Error;

pub const Value = union(enum) {
    integer: i64,
    float: f64,
};

const Token = struct {
    kind: TokenKind,
    value: Value = .{ .integer = 0 },
    string: ?[]const u8 = null, // For identifiers
    // Position information: byte offsets in input [start, end)
    start: usize = 0,
    end: usize = 0,
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isSpace(c: u8) bool {
    // Allow all whitespace characters (space, tab, newline, CR, VT, etc.)
    return std.ascii.isWhitespace(c);
}

fn isSign(c: u8) bool {
    return c == '+' or c == '-';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isAlphaNum(c: u8) bool {
    return isAlpha(c) or isDigit(c) or c == '_';
}

const NumberScanResult = struct {
    valid: bool,
    end_pos: usize,
    has_dot: bool,
    has_exp: bool,
};

fn scanNumber(input: []const u8, start: usize) NumberScanResult {
    if (start >= input.len) return .{ .valid = false, .end_pos = start, .has_dot = false, .has_exp = false };

    var i = start;
    var has_dot = false;
    var has_exp = false;
    var digits_seen = false;

    // Integer part
    while (i < input.len and isDigit(input[i])) {
        digits_seen = true;
        i += 1;
    }

    // Decimal point + fractional part (optional)
    if (i < input.len and input[i] == '.') {
        has_dot = true;
        i += 1;

        var frac_seen = false;
        while (i < input.len and isDigit(input[i])) {
            frac_seen = true;
            i += 1;
        }
        if (frac_seen) digits_seen = true;
    }

    // Exponent part (e/E [+-]? DIGITS+) — only allowed when we have digits in integer/fractional part
    if (digits_seen and i < input.len and (input[i] == 'e' or input[i] == 'E')) {
        var j = i + 1;

        // Optional sign after e/E
        while (j < input.len and isSign(input[j])) j += 1;

        var exp_seen = false;
        while (j < input.len and isDigit(input[j])) {
            exp_seen = true;
            j += 1;
        }

        if (exp_seen) {
            has_exp = true;
            i = j; // consume up to exponent part
        }
        // If no digits after e/E, don't consume the 'e' - it's not part of the number
    }

    const valid = digits_seen and (start < i);
    return .{ .valid = valid, .end_pos = i, .has_dot = has_dot, .has_exp = has_exp };
}

fn isValidNumberFormat(slice: []const u8) bool {
    if (slice.len == 0) return false;

    const result = scanNumber(slice, 0);
    return result.valid and result.end_pos == slice.len;
}

fn tokenize(allocator: std.mem.Allocator, input: []const u8) TokenizeError!std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];

        if (isSpace(c)) {
            i += 1;
            continue;
        }

        if (c == '+') {
            try tokens.append(.{ .kind = .add, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '-') {
            try tokens.append(.{ .kind = .sub, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '*') {
            try tokens.append(.{ .kind = .mul, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '/') {
            try tokens.append(.{ .kind = .div, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '%') {
            try tokens.append(.{ .kind = .mod, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '^') {
            try tokens.append(.{ .kind = .pow, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == '(') {
            try tokens.append(.{ .kind = .lparen, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == ')') {
            try tokens.append(.{ .kind = .rparen, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (c == ',') {
            try tokens.append(.{ .kind = .comma, .start = i, .end = i + 1 });
            i += 1;
            continue;
        }

        if (isAlpha(c)) {
            const start = i;
            while (i < input.len and isAlphaNum(input[i])) {
                i += 1;
            }
            const slice = input[start..i];
            try tokens.append(.{
                .kind = .identifier,
                .string = slice,
                .start = start,
                .end = i,
            });
            continue;
        }

        if (isDigit(c) or c == '.') {
            const start = i;
            const scan_result = scanNumber(input, i);

            if (!scan_result.valid) {
                return error.InvalidNumber;
            }

            i = scan_result.end_pos;
            const slice = input[start..i];

            if (scan_result.has_dot or scan_result.has_exp) {
                const val = std.fmt.parseFloat(f64, slice) catch return error.InvalidNumber;
                try tokens.append(.{
                    .kind = .number,
                    .value = .{ .float = val },
                    .start = start,
                    .end = i,
                });
            } else {
                const val = std.fmt.parseInt(i64, slice, 10) catch return error.InvalidNumber;
                try tokens.append(.{
                    .kind = .number,
                    .value = .{ .integer = val },
                    .start = start,
                    .end = i,
                });
            }
            continue;
        }

        return error.InvalidCharacter;
    }

    try tokens.append(.{ .kind = .eof, .start = input.len, .end = input.len });
    return tokens;
}

const Node = union(enum) {
    number: Value,
    add: struct { left: *const Node, right: *const Node },
    sub: struct { left: *const Node, right: *const Node },
    mul: struct { left: *const Node, right: *const Node },
    div: struct { left: *const Node, right: *const Node },
    mod: struct { left: *const Node, right: *const Node },
    pow: struct { left: *const Node, right: *const Node },
    pos: struct { child: *const Node },
    neg: struct { child: *const Node },
    function_call: struct { name: []const u8, args: []const *const Node },
};
const NodeKind = std.meta.Tag(Node);

const ParseError = error{
    ExpectedPrimary,
    ExpectedRParen,
    TrailingInput,
    InvalidBinaryKind,
    InvalidUnaryKind,
} || std.mem.Allocator.Error;

fn computeLineCol(input: []const u8, pos: usize) struct {
    line: usize,
    col: usize,
    line_start: usize,
    line_end: usize,
} {
    const p = if (pos <= input.len) pos else input.len;
    var line_no: usize = 1;
    var i: usize = 0;
    while (i < p) : (i += 1) {
        if (input[i] == '\n') line_no += 1;
    }
    var line_start = p;
    while (line_start > 0 and input[line_start - 1] != '\n') line_start -= 1;

    var line_end = p;
    while (line_end < input.len and input[line_end] != '\n') line_end += 1;

    const col = (p - line_start) + 1;
    return .{ .line = line_no, .col = col, .line_start = line_start, .line_end = line_end };
}

fn printDiagAt(input: []const u8, pos: usize, what: []const u8) void {
    const info = computeLineCol(input, pos);
    const line_slice = input[info.line_start..info.line_end];

    std.debug.print("error: {s}\n", .{what});
    std.debug.print(" --> {d}:{d}\n", .{ info.line, info.col });
    std.debug.print("{d} | {s}\n", .{ info.line, line_slice });
    std.debug.print("  | ", .{});
    var k: usize = 1;
    while (k < info.col) : (k += 1) std.debug.print(" ", .{});
    std.debug.print("^\n", .{});
}

fn tokenKindToStr(kind: TokenKind) []const u8 {
    return switch (kind) {
        .number => "number",
        .add => "'+'",
        .sub => "'-'",
        .mul => "'*'",
        .div => "'/'",
        .mod => "'%'",
        .pow => "'^'",
        .lparen => "'('",
        .rparen => "')'",
        .identifier => "identifier",
        .comma => "','",
        .eof => "end of input",
    };
}

fn handleTokenizeError(input: []const u8, err: TokenizeError) void {
    switch (err) {
        error.InvalidNumber => {
            // Find the position of the invalid number by re-tokenizing until we hit the error
            var i: usize = 0;
            while (i < input.len) {
                const c = input[i];
                if (isSpace(c)) {
                    i += 1;
                    continue;
                }
                if (c == '+' or c == '-' or c == '*' or c == '/' or
                    c == '%' or c == '^' or c == '(' or c == ')')
                {
                    i += 1;
                    continue;
                }
                if (isDigit(c) or c == '.') {
                    const start = i;
                    const scan_result = scanNumber(input, i);

                    if (!scan_result.valid) {
                        printDiagAt(input, start, "invalid number format");
                        return;
                    }

                    i = scan_result.end_pos;
                    continue;
                }
                printDiagAt(input, i, "invalid character");
                return;
            }
        },
        error.InvalidCharacter => {
            // Find the position of the invalid character
            var i: usize = 0;
            while (i < input.len) {
                const c = input[i];
                if (isSpace(c)) {
                    i += 1;
                    continue;
                }
                if (c == '+' or c == '-' or c == '*' or c == '/' or c == '%' or c == '^' or c == '(' or c == ')') {
                    i += 1;
                    continue;
                }
                if (isDigit(c) or c == '.') {
                    while (i < input.len and (isDigit(input[i]) or input[i] == '.')) {
                        i += 1;
                    }
                    continue;
                }
                printDiagAt(input, i, "invalid character");
                return;
            }
        },
        else => {
            std.debug.print("tokenize error: {s}\n", .{@errorName(err)});
        },
    }
}

fn handleParseError(parser: *const Parser, err: ParseError) void {
    switch (err) {
        error.ExpectedPrimary => {
            var buf: [96]u8 = undefined;
            const msg = std.fmt.bufPrint(
                &buf,
                "expected number or '(' but got {s}",
                .{tokenKindToStr(parser.last_got)},
            ) catch "expected primary";
            printDiagAt(parser.input, parser.error_pos, msg);
        },
        error.ExpectedRParen => {
            printDiagAt(parser.input, parser.error_pos, "expected ')'");
        },
        error.TrailingInput => {
            var buf: [96]u8 = undefined;
            const msg = std.fmt.bufPrint(
                &buf,
                "unexpected token after expression: {s}",
                .{tokenKindToStr(parser.last_got)},
            ) catch "trailing input";
            printDiagAt(parser.input, parser.error_pos, msg);
        },
        error.InvalidBinaryKind => {
            printDiagAt(parser.input, parser.error_pos, "internal parser error: invalid binary operator");
        },
        error.InvalidUnaryKind => {
            printDiagAt(parser.input, parser.error_pos, "internal parser error: invalid unary operator");
        },
        else => {
            std.debug.print("parse error: {s}\n", .{@errorName(err)});
        },
    }
}

fn newNumber(alloc: std.mem.Allocator, v: Value) ParseError!*Node {
    const n = try alloc.create(Node);
    n.* = .{ .number = v };
    return n;
}

fn newBinary(alloc: std.mem.Allocator, kind: NodeKind, l: *Node, r: *Node) ParseError!*Node {
    switch (kind) {
        .add, .sub, .mul, .div, .mod, .pow => {},
        else => return error.InvalidBinaryKind,
    }
    const n = try alloc.create(Node);
    n.* = switch (kind) {
        .add => .{ .add = .{ .left = l, .right = r } },
        .sub => .{ .sub = .{ .left = l, .right = r } },
        .mul => .{ .mul = .{ .left = l, .right = r } },
        .div => .{ .div = .{ .left = l, .right = r } },
        .mod => .{ .mod = .{ .left = l, .right = r } },
        .pow => .{ .pow = .{ .left = l, .right = r } },
        else => return error.InvalidBinaryKind,
    };
    return n;
}

fn newUnary(alloc: std.mem.Allocator, kind: NodeKind, child: *Node) ParseError!*Node {
    switch (kind) {
        .pos, .neg => {},
        else => return error.InvalidUnaryKind,
    }
    const n = try alloc.create(Node);
    n.* = switch (kind) {
        .pos => .{ .pos = .{ .child = child } },
        .neg => .{ .neg = .{ .child = child } },
        else => unreachable,
    };
    return n;
}

fn newFunctionCall(alloc: std.mem.Allocator, name: []const u8, args: []const *const Node) ParseError!*Node {
    const n = try alloc.create(Node);
    n.* = .{ .function_call = .{ .name = name, .args = args } };
    return n;
}

fn isKnownFunction(name: []const u8) bool {
    const functions = [_][]const u8{ "abs", "sqrt", "pow", "sin", "cos", "tan", "log", "ln" };
    for (functions) |func| {
        if (std.mem.eql(u8, name, func)) return true;
    }
    return false;
}

const Parser = struct {
    tokens: []const Token,
    pos: usize = 0,
    alloc: std.mem.Allocator,
    // for error reporting
    input: []const u8,
    error_pos: usize = 0,
    last_got: TokenKind = .eof,

    fn peek(self: *Parser) Token {
        return self.tokens[self.pos];
    }
    fn advance(self: *Parser) void {
        if (self.pos < self.tokens.len - 1) self.pos += 1;
    }

    pub fn parse(self: *Parser) ParseError!*Node {
        const node = try self.parseAddSub();
        const t = self.peek();
        if (t.kind != .eof) {
            self.last_got = t.kind;
            self.error_pos = t.start;
            return error.TrailingInput;
        }
        return node;
    }

    // Grammar
    // Expr    := AddSub
    // AddSub  := MulDiv { ('+' | '-') MulDiv }
    // MulDiv  := Prefix { ('*' | '/' | '%') Prefix }
    // Prefix  := { ('+' | '-') } Power        // Multiple signs allowed, weaker than Power
    // Power   := Primary { '^' Prefix }?       // Right associative
    // Primary := number | '(' Expr ')'
    fn parseAddSub(self: *Parser) ParseError!*Node {
        var left = try self.parseMulDiv();
        while (true) {
            switch (self.peek().kind) {
                .add => {
                    self.advance();
                    const right = try self.parseMulDiv();
                    left = try newBinary(self.alloc, .add, left, right);
                },
                .sub => {
                    self.advance();
                    const right = try self.parseMulDiv();
                    left = try newBinary(self.alloc, .sub, left, right);
                },
                else => break,
            }
        }
        return left;
    }

    fn parseMulDiv(self: *Parser) ParseError!*Node {
        var left = try self.parsePrefix();
        while (true) {
            switch (self.peek().kind) {
                .mul => {
                    self.advance();
                    const right = try self.parsePrefix();
                    left = try newBinary(self.alloc, .mul, left, right);
                },
                .div => {
                    self.advance();
                    const right = try self.parsePrefix();
                    left = try newBinary(self.alloc, .div, left, right);
                },
                .mod => {
                    self.advance();
                    const right = try self.parsePrefix();
                    left = try newBinary(self.alloc, .mod, left, right);
                },
                else => break,
            }
        }
        return left;
    }

    fn parsePrefix(self: *Parser) ParseError!*Node {
        switch (self.peek().kind) {
            .add => {
                self.advance();
                const child = try self.parsePrefix();
                return try newUnary(self.alloc, .pos, child);
            },
            .sub => {
                self.advance();
                const child = try self.parsePrefix();
                return try newUnary(self.alloc, .neg, child);
            },
            else => return self.parsePower(),
        }
    }

    fn parsePower(self: *Parser) ParseError!*Node {
        var left = try self.parsePrimary();
        if (self.peek().kind == .pow) {
            self.advance();
            const right = try self.parsePrefix(); // Right associative: recurse into parsePrefix
            left = try newBinary(self.alloc, .pow, left, right);
        }
        return left;
    }

    fn parsePrimary(self: *Parser) ParseError!*Node {
        const t = self.peek();
        switch (t.kind) {
            .number => {
                self.advance();
                return try newNumber(self.alloc, t.value);
            },
            .lparen => {
                self.advance();
                const node = try self.parseAddSub();
                const rparen_tok = self.peek();
                if (rparen_tok.kind != .rparen) {
                    self.last_got = rparen_tok.kind;
                    self.error_pos = rparen_tok.start;
                    return error.ExpectedRParen;
                }
                self.advance();
                return node;
            },
            .identifier => {
                const name = t.string.?;
                self.advance();

                // Check if this is a function call
                if (self.peek().kind == .lparen) {
                    if (!isKnownFunction(name)) {
                        self.last_got = .identifier;
                        self.error_pos = t.start;
                        return error.ExpectedPrimary;
                    }
                    return try self.parseFunctionCall(name);
                } else {
                    // Unknown identifier (not a function call)
                    self.last_got = .identifier;
                    self.error_pos = t.start;
                    return error.ExpectedPrimary;
                }
            },
            else => {
                self.last_got = t.kind;
                self.error_pos = t.start;
                return error.ExpectedPrimary;
            },
        }
    }

    fn parseFunctionCall(self: *Parser, name: []const u8) ParseError!*Node {
        // Consume '('
        self.advance();

        var args = std.ArrayList(*const Node).init(self.alloc);
        defer args.deinit();

        // Handle empty argument list
        if (self.peek().kind == .rparen) {
            self.advance();
            const args_slice = try args.toOwnedSlice();
            return try newFunctionCall(self.alloc, name, args_slice);
        }

        // Parse first argument
        const first_arg = try self.parseAddSub();
        try args.append(first_arg);

        // Parse additional arguments (for functions like pow(x,y))
        while (self.peek().kind == .comma) {
            self.advance(); // consume comma
            const arg = try self.parseAddSub();
            try args.append(arg);
        }

        // Expect closing parenthesis
        if (self.peek().kind != .rparen) {
            self.last_got = self.peek().kind;
            self.error_pos = self.peek().start;
            return error.ExpectedRParen;
        }
        self.advance();

        const args_slice = try args.toOwnedSlice();
        return try newFunctionCall(self.alloc, name, args_slice);
    }
};

// We draw vertical guide bars per depth.
// Adjust if trees can be deeper.
const MAX_DEPTH: usize = 128;
const Guides = [MAX_DEPTH]bool;

// Prints the textual label for a node.
fn printNodeLabel(n: *const Node) void {
    switch (n.*) {
        .number => |v| switch (v) {
            .integer => |i| std.debug.print("number({d})\n", .{i}),
            .float => |f| std.debug.print("number({e})\n", .{f}),
        },
        .add => std.debug.print("add\n", .{}),
        .sub => std.debug.print("sub\n", .{}),
        .mul => std.debug.print("mul\n", .{}),
        .div => std.debug.print("div\n", .{}),
        .mod => std.debug.print("mod\n", .{}),
        .pow => std.debug.print("pow\n", .{}),
        .pos => std.debug.print("pos\n", .{}),
        .neg => std.debug.print("neg\n", .{}),
        .function_call => |f| std.debug.print("{s}()\n", .{f.name}),
    }
}

// Print indentation up `depth`, using `guides[i]` to decide
// whether a vertical bar "|  " must be drawn at level `i`.
fn printIndent(guides: *const Guides, depth: usize) void {
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        if (guides.*[i]) {
            std.debug.print("|  ", .{});
        } else {
            std.debug.print("   ", .{});
        }
    }
}

// Recursively print the children of 'n' as an ASCII tree.
fn printChildren(n: *const Node, guides: *Guides, depth: usize) void {
    // Collect this node's children as a slice of pointers.
    const children: []const *const Node = switch (n.*) {
        .number => &[_]*const Node{},
        .add => |b| &[_]*const Node{ b.left, b.right },
        .sub => |b| &[_]*const Node{ b.left, b.right },
        .mul => |b| &[_]*const Node{ b.left, b.right },
        .div => |b| &[_]*const Node{ b.left, b.right },
        .mod => |b| &[_]*const Node{ b.left, b.right },
        .pow => |b| &[_]*const Node{ b.left, b.right },
        .pos => |b| &[_]*const Node{b.child},
        .neg => |b| &[_]*const Node{b.child},
        .function_call => |f| f.args,
    };

    // Iterate with indices to know if a child is the last one.
    for (children, 0..) |child, idx| {
        const is_last = idx == children.len - 1;

        // 1) Indentation for all ancestor depths.
        printIndent(guides, depth);

        // 2) Branch connector at this depth.
        std.debug.print("{s}", .{if (is_last) "└── " else "├── "});

        // 3) Child label itself.
        printNodeLabel(child);

        // 4) Let descendants know if a guide bar must continue at `depth`.
        guides.*[depth] = !is_last;

        // 5) Recurse into the child's subtree.
        printChildren(child, guides, depth + 1);
    }
}

// Entry point for printing a whole tree
fn printNode(root: *const Node) void {
    var guides = std.mem.zeroes(Guides);
    printNodeLabel(root);
    printChildren(root, &guides, 0);
}

pub const EvalError = error{
    DivisionByZero,
    NegativeExponent,
    Overflow,
    FloatModulo,
    InvalidFunctionArgument,
    WrongArgumentCount,
};

// Debug options for the calculate function
const DebugOptions = struct {
    show_tokens: bool = false,
    show_ast: bool = false,
};

// High-level public API for calculating mathematical expressions
pub fn calculate(allocator: std.mem.Allocator, expression: []const u8, debug_options: DebugOptions) !Value {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const ast_alloc = arena.allocator();

    var tokens = tokenize(allocator, expression) catch |err| {
        handleTokenizeError(expression, err);
        return err;
    };
    defer tokens.deinit();

    // Debug: show tokens if requested
    if (debug_options.show_tokens) {
        for (tokens.items) |t| switch (t.kind) {
            .number => switch (t.value) {
                .integer => |i| std.debug.print("number({d})\n", .{i}),
                .float => |f| std.debug.print("number({e})\n", .{f}),
            },
            .add => std.debug.print("add\n", .{}),
            .sub => std.debug.print("sub\n", .{}),
            .mul => std.debug.print("mul\n", .{}),
            .div => std.debug.print("div\n", .{}),
            .mod => std.debug.print("mod\n", .{}),
            .pow => std.debug.print("pow\n", .{}),
            .lparen => std.debug.print("(\n", .{}),
            .rparen => std.debug.print(")\n", .{}),
            .identifier => std.debug.print("identifier({s})\n", .{t.string.?}),
            .comma => std.debug.print(",\n", .{}),
            .eof => std.debug.print("eof\n", .{}),
        };
    }

    var parser = Parser{ .tokens = tokens.items, .alloc = ast_alloc, .input = expression };
    const ast = parser.parse() catch |err| {
        handleParseError(&parser, err);
        return err;
    };

    // Debug: show AST if requested
    if (debug_options.show_ast) {
        printNode(ast);
    }

    return try eval(ast);
}

fn eval(n: *const Node) EvalError!Value {
    switch (n.*) {
        .number => |v| return v,
        .add => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            switch (l) {
                .integer => |li| switch (r) {
                    .integer => |ri| {
                        const res = std.math.add(i64, li, ri) catch return error.Overflow;
                        return Value{ .integer = res };
                    },
                    .float => |rf| {
                        return Value{ .float = @as(f64, @floatFromInt(li)) + rf };
                    },
                },
                .float => |lf| switch (r) {
                    .integer => |ri| {
                        return Value{ .float = lf + @as(f64, @floatFromInt(ri)) };
                    },
                    .float => |rf| {
                        return Value{ .float = lf + rf };
                    },
                },
            }
        },
        .sub => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            switch (l) {
                .integer => |li| switch (r) {
                    .integer => |ri| {
                        const res = std.math.sub(i64, li, ri) catch return error.Overflow;
                        return Value{ .integer = res };
                    },
                    .float => |rf| {
                        return Value{ .float = @as(f64, @floatFromInt(li)) - rf };
                    },
                },
                .float => |lf| switch (r) {
                    .integer => |ri| {
                        return Value{ .float = lf - @as(f64, @floatFromInt(ri)) };
                    },
                    .float => |rf| {
                        return Value{ .float = lf - rf };
                    },
                },
            }
        },
        .mul => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            switch (l) {
                .integer => |li| switch (r) {
                    .integer => |ri| {
                        const res = std.math.mul(i64, li, ri) catch return error.Overflow;
                        return Value{ .integer = res };
                    },
                    .float => |rf| {
                        return Value{ .float = @as(f64, @floatFromInt(li)) * rf };
                    },
                },
                .float => |lf| switch (r) {
                    .integer => |ri| {
                        return Value{ .float = lf * @as(f64, @floatFromInt(ri)) };
                    },
                    .float => |rf| {
                        return Value{ .float = lf * rf };
                    },
                },
            }
        },
        .div => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            const lf = switch (l) {
                .integer => |li| @as(f64, @floatFromInt(li)),
                .float => |f| f,
            };
            const rf = switch (r) {
                .integer => |ri| @as(f64, @floatFromInt(ri)),
                .float => |f| f,
            };
            if (rf == 0) return error.DivisionByZero;
            return Value{ .float = lf / rf };
        },
        .mod => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            switch (l) {
                .integer => |li| switch (r) {
                    .integer => |ri| {
                        if (ri == 0) return error.DivisionByZero;
                        return Value{ .integer = @rem(li, ri) };
                    },
                    .float => return error.FloatModulo,
                },
                .float => return error.FloatModulo,
            }
        },
        .pow => |b| {
            const l = try eval(b.left);
            const r = try eval(b.right);
            const lf = switch (l) {
                .integer => |li| @as(f64, @floatFromInt(li)),
                .float => |f| f,
            };
            const rf = switch (r) {
                .integer => |ri| @as(f64, @floatFromInt(ri)),
                .float => |f| f,
            };
            return Value{ .float = std.math.pow(f64, lf, rf) };
        },
        .pos => |b| {
            return try eval(b.child);
        },
        .neg => |b| {
            const c = try eval(b.child);
            return switch (c) {
                .integer => |i| Value{ .integer = -i },
                .float => |f| Value{ .float = -f },
            };
        },
        .function_call => |f| {
            return try evalFunction(f.name, f.args);
        },
    }
}

fn evalFunction(name: []const u8, args: []const *const Node) EvalError!Value {
    // Helper function to convert Value to f64
    const toFloat = struct {
        fn call(v: Value) f64 {
            return switch (v) {
                .integer => |i| @as(f64, @floatFromInt(i)),
                .float => |f| f,
            };
        }
    }.call;

    if (std.mem.eql(u8, name, "abs")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        return switch (arg) {
            .integer => |i| Value{ .integer = if (i < 0) -i else i },
            .float => |f| Value{ .float = @abs(f) },
        };
    } else if (std.mem.eql(u8, name, "sqrt")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        if (f < 0) return error.InvalidFunctionArgument;
        return Value{ .float = std.math.sqrt(f) };
    } else if (std.mem.eql(u8, name, "pow")) {
        if (args.len != 2) return error.WrongArgumentCount;
        const arg1 = try eval(args[0]);
        const arg2 = try eval(args[1]);
        const f1 = toFloat(arg1);
        const f2 = toFloat(arg2);
        return Value{ .float = std.math.pow(f64, f1, f2) };
    } else if (std.mem.eql(u8, name, "sin")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        return Value{ .float = std.math.sin(f) };
    } else if (std.mem.eql(u8, name, "cos")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        return Value{ .float = std.math.cos(f) };
    } else if (std.mem.eql(u8, name, "tan")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        return Value{ .float = std.math.tan(f) };
    } else if (std.mem.eql(u8, name, "log")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        if (f <= 0) return error.InvalidFunctionArgument;
        return Value{ .float = std.math.log10(f) };
    } else if (std.mem.eql(u8, name, "ln")) {
        if (args.len != 1) return error.WrongArgumentCount;
        const arg = try eval(args[0]);
        const f = toFloat(arg);
        if (f <= 0) return error.InvalidFunctionArgument;
        return Value{ .float = std.math.log(f64, std.math.e, f) };
    } else {
        // This should never happen since we check isKnownFunction in the parser
        return error.InvalidFunctionArgument;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const galloc = gpa.allocator();

    var args = std.process.args();
    _ = args.next(); // exe name

    var show_tokens = false;
    var show_ast = false;
    var expr: []const u8 = undefined;
    var expr_set = false;

    // stdin buffer to hold input read from stdin (lifetime management)
    var stdin_buf: ?[]u8 = null;
    defer if (stdin_buf) |buf| galloc.free(buf);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--tokens")) {
            show_tokens = true;
        } else if (std.mem.eql(u8, arg, "--ast")) {
            show_ast = true;
        } else {
            expr = arg;
            expr_set = true;
        }
    }

    if (!expr_set) {
        // If no arguments provided, read from stdin with 1MiB limit
        const MAX_STDIN: usize = 1 << 20;
        const stdin = std.io.getStdIn();
        const raw = try stdin.readToEndAlloc(galloc, MAX_STDIN);
        stdin_buf = raw; // Keep buffer alive until main() ends
        // Trim leading/trailing whitespace (including newlines)
        expr = std.mem.trim(u8, raw, " \t\r\n");
        if (expr.len == 0) {
            std.debug.print("usage: calc [--tokens] [--ast] <expr>\n", .{});
            return;
        }
        expr_set = true;
    }

    // Create debug options based on command line flags
    const debug_options = DebugOptions{
        .show_tokens = show_tokens,
        .show_ast = show_ast,
    };

    // Calculate the result using the unified API
    const result = calculate(galloc, expr, debug_options) catch {
        // Error messages have already been printed by the error handlers
        std.process.exit(1);
    };

    // Output final result to stdout
    const stdout = std.io.getStdOut().writer();
    switch (result) {
        .integer => |i| try stdout.print("{d}\n", .{i}),
        .float => |f| try stdout.print("{e}\n", .{f}),
    }
}
