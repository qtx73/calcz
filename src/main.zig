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
    eof,
};

const Token = struct {
    kind: TokenKind,
    value: i64 = 0,
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t';
}

fn tokenize(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Token) {
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
            try tokens.append(.{ .kind = .add });
            i += 1;
            continue;
        }

        if (c == '-') {
            try tokens.append(.{ .kind = .sub });
            i += 1;
            continue;
        }

        if (c == '*') {
            try tokens.append(.{ .kind = .mul });
            i += 1;
            continue;
        }

        if (c == '/') {
            try tokens.append(.{ .kind = .div });
            i += 1;
            continue;
        }

        if (c == '%') {
            try tokens.append(.{ .kind = .mod });
            i += 1;
            continue;
        }

        if (c == '^') {
            try tokens.append(.{ .kind = .pow });
            i += 1;
            continue;
        }

        if (c == '(') {
            try tokens.append(.{ .kind = .lparen });
            i += 1;
            continue;
        }

        if (c == ')') {
            try tokens.append(.{ .kind = .rparen });
            i += 1;
            continue;
        }

        if (isDigit(c)) {
            const start = i;
            while (i < input.len and isDigit(input[i])) : (i += 1) {}
            const slice = input[start..i];
            const val = try std.fmt.parseInt(i64, slice, 10);
            try tokens.append(.{ .kind = .number, .value = val });
            continue;
        }

        return error.InvalidCharacter;
    }

    try tokens.append(.{ .kind = .eof });
    return tokens;
}

const Node = union(enum) {
    number: i64,
    add: struct { left: *const Node, right: *const Node },
    sub: struct { left: *const Node, right: *const Node },
    mul: struct { left: *const Node, right: *const Node },
    div: struct { left: *const Node, right: *const Node },
    mod: struct { left: *const Node, right: *const Node },
    pow: struct { left: *const Node, right: *const Node },
    pos: struct { child: *const Node },
    neg: struct { child: *const Node },
};
const NodeKind = std.meta.Tag(Node);

const ParseError = error{
    ExpectedPrimary,
    ExpectedRParen,
    TrailingInput,
    InvalidBinaryKind,
    InvalidUnaryKind,
} || std.mem.Allocator.Error;

fn newNumber(alloc: std.mem.Allocator, v: i64) ParseError!*Node {
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

const Parser = struct {
    tokens: []const Token,
    pos: usize = 0,
    alloc: std.mem.Allocator,

    fn peek(self: *Parser) Token {
        return self.tokens[self.pos];
    }
    fn advance(self: *Parser) void {
        if (self.pos < self.tokens.len - 1) self.pos += 1;
    }

    pub fn parse(self: *Parser) ParseError!*Node {
        const node = try self.parseAddSub();
        if (self.peek().kind != .eof)
            return error.TrailingInput;
        return node;
    }

    // Expr := AddSub
    // AddSub := MulDiv { ('+' | '-') MulDiv }
    // MulDiv := Power { ('*' | '/' | '%') Power }
    // Power := Unary { '^' Unary }
    // Unary := ('+' | '-') Unary | Primary
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
        var left = try self.parsePower();
        while (true) {
            switch (self.peek().kind) {
                .mul => {
                    self.advance();
                    const right = try self.parsePower();
                    left = try newBinary(self.alloc, .mul, left, right);
                },
                .div => {
                    self.advance();
                    const right = try self.parsePower();
                    left = try newBinary(self.alloc, .div, left, right);
                },
                .mod => {
                    self.advance();
                    const right = try self.parsePower();
                    left = try newBinary(self.alloc, .mod, left, right);
                },
                else => break,
            }
        }
        return left;
    }

    fn parsePower(self: *Parser) ParseError!*Node {
        var left = try self.parseUnary();
        if (self.peek().kind == .pow) {
            self.advance();
            const right = try self.parseUnary();
            left = try newBinary(self.alloc, .pow, left, right);
        }
        return left;
    }

    fn parseUnary(self: *Parser) ParseError!*Node {
        const t = self.peek();
        switch (t.kind) {
            .add => {
                self.advance();
                const child = try self.parseUnary();
                return try newUnary(self.alloc, .pos, child);
            },
            .sub => {
                self.advance();
                const child = try self.parseUnary();
                return try newUnary(self.alloc, .neg, child);
            },
            else => return self.parsePrimary(),
        }
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
                if (self.peek().kind != .rparen)
                    return error.ExpectedRParen;
                self.advance();
                return node;
            },
            else => return error.ExpectedPrimary,
        }
    }
};

// We draw vertical guide bars per depth.
// Adjust if trees can be deeper.
const MAX_DEPTH: usize = 128;
const Guides = [MAX_DEPTH]bool;

// Prints the textual label for a node.
fn printNodeLabel(n: *const Node) void {
    switch (n.*) {
        .number => |v| std.debug.print("number({d})\n", .{v}),
        .add => std.debug.print("add\n", .{}),
        .sub => std.debug.print("sub\n", .{}),
        .mul => std.debug.print("mul\n", .{}),
        .div => std.debug.print("div\n", .{}),
        .mod => std.debug.print("mod\n", .{}),
        .pow => std.debug.print("pow\n", .{}),
        .pos => std.debug.print("pos\n", .{}),
        .neg => std.debug.print("neg\n", .{}),
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

const EvalError = error{
    DivisionByZero,
    NegativeExponent,
    Overflow,
};

// Helper function for integer power calculation
fn intPow(base: i64, exp: i64) !i64 {
    if (exp < 0) return error.NegativeExponent;
    if (exp == 0) return 1;

    var result: i64 = 1;
    var b = base;
    var e = exp;

    while (e > 0) {
        if (@rem(e, 2) == 1) {
            result = std.math.mul(i64, result, b) catch return error.Overflow;
        }
        b = std.math.mul(i64, b, b) catch return error.Overflow;
        e = @divTrunc(e, 2);
    }

    return result;
}

fn eval(n: *const Node) EvalError!i64 {
    switch (n.*) {
        .number => |v| return v,
        .add => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return std.math.add(i64, l, r) catch return error.Overflow;
        },
        .sub => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return std.math.sub(i64, l, r) catch return error.Overflow;
        },
        .mul => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return std.math.mul(i64, l, r) catch return error.Overflow;
        },
        .div => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            if (r == 0) return error.DivisionByZero;
            return @divTrunc(l, r);
        },
        .mod => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            if (r == 0) return error.DivisionByZero;
            return @rem(l, r);
        },
        .pow => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return try intPow(l, r);
        },
        .pos => |b| {
            const c: i64 = try eval(b.child);
            return c;
        },
        .neg => |b| {
            const c: i64 = try eval(b.child);
            return std.math.mul(i64, -1, c) catch return error.Overflow;
        },
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const galloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(galloc);
    defer arena.deinit();
    const ast_alloc = arena.allocator();

    var args = std.process.args();
    _ = args.next(); // exe name

    var show_tokens = false;
    var show_ast = false;
    var expr: []const u8 = undefined;
    var expr_set = false;

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
        std.debug.print("usage: calc [--tokens] [--ast] <expr>\n", .{});
        return;
    }

    var toks = try tokenize(galloc, expr);
    defer toks.deinit();

    if (show_tokens) {
        for (toks.items) |t| switch (t.kind) {
            .number => std.debug.print("number({d})\n", .{t.value}),
            .add => std.debug.print("add\n", .{}),
            .sub => std.debug.print("sub\n", .{}),
            .mul => std.debug.print("mul\n", .{}),
            .div => std.debug.print("div\n", .{}),
            .mod => std.debug.print("mod\n", .{}),
            .pow => std.debug.print("pow\n", .{}),
            .lparen => std.debug.print("(\n", .{}),
            .rparen => std.debug.print(")\n", .{}),
            .eof => std.debug.print("eof\n", .{}),
        };
    }

    var p = Parser{ .tokens = toks.items, .alloc = ast_alloc };
    const ast = try p.parse();

    if (show_ast) {
        printNode(ast);
    }

    const result: i64 = try eval(ast);

    // Output final result to stdout
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{d}\n", .{result});
}
