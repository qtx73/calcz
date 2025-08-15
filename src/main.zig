const std = @import("std");

const TokenKind = enum {
    number,
    add,
    sub,
    mul,
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

fn tokenize(allocator: std.mem.Allocator, input: []const u8)
    !std.ArrayList(Token) {
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
    
fn newBinary(alloc: std.mem.Allocator, kind: NodeKind,
    l: *Node, r: *Node) ParseError!*Node {
    switch (kind) {
        .add, .sub, .mul => {},
        else => return error.InvalidBinaryKind,
    }
    const n = try alloc.create(Node);
    n.* = switch (kind) {
        .add => .{ .add = .{ .left = l, .right = r } },
        .sub => .{ .sub = .{ .left = l, .right = r } },
        .mul => .{ .mul = .{ .left = l, .right = r } },
        else => return error.InvalidBinaryKind,
    };
    return n;
}

fn newUnary(alloc: std.mem.Allocator, kind: NodeKind,
    child: *Node) ParseError!*Node {
    switch (kind) {
        .pos, .neg => {},
        else => return error.InvalidUnaryKind
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

    // Expr := Addsub
    // Addsub := Mul { ('+ | '-') Mul }
    // Mul := Unary { '*' Unary }
    // Unary := ('+'|'-' Unary) | Primary
    // Primary :=  number | '(' Expr ')'
    fn parseAddSub(self: *Parser) ParseError!*Node {
        var left = try self.parseUnary();
        while (true) {
            switch (self.peek().kind) {
                .add => {
                    self.advance();
                    const right = try self.parseMul();
                    left = try newBinary(self.alloc, 
                        .add, left, right);
                },
                .sub => {
                    self.advance();
                    const right = try self.parseMul();
                    left = try newBinary(self.alloc, 
                        .sub, left, right);
                },
                else => break,
            }
        }
        return left;
    }

    fn parseMul(self: *Parser) ParseError!*Node {
        var left = try self.parsePrimary();
        while (self.peek().kind == .mul) {
            self.advance();
            const right = try self.parseUnary();
            left = try newBinary(self.alloc, .mul, left, right);
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

fn printNode(n: *const Node, indent: usize) void {
    for (0..indent) |_| std.debug.print(" ", .{});
    switch (n.*) {
        .number => |v| std.debug.print("Number({d})\n", .{v}),
        .add => |b| {
            std.debug.print("Add\n", .{});
            printNode(b.left, indent + 1);
            printNode(b.right, indent + 1);
        },
        .sub => |b| {
            std.debug.print("Sub\n", .{});
            printNode(b.left, indent + 1);
            printNode(b.right, indent + 1);
        },
        .mul => |b| {
            std.debug.print("Mul\n", .{});
            printNode(b.left, indent + 1);
            printNode(b.right, indent + 1);
        },
        .pos => |b| {
            std.debug.print("Pos\n", .{});
            printNode(b.child, indent + 1);
        },
        .neg => |b| {
            std.debug.print("Neg\n", .{});
            printNode(b.child, indent + 1);
        },
    }
}

fn eval(n: *const Node) !i64 {
    switch (n.*) {
        .number => |v| return v,
        .add => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return l + r;
        },
        .sub => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return l - r;
        },
        .mul => |b| {
            const l: i64 = try eval(b.left);
            const r: i64 = try eval(b.right);
            return l * r;
        },
        .pos => |b| {
            const c: i64 = try eval(b.child);
            return c;
        },
        .neg => |b| {
            const c: i64 = try eval(b.child);
            return -1 * c;
        }
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
    const expr = args.next() orelse {
        std.debug.print("usage: calc <expr>\n", .{});
    return;
    };

    var toks = try tokenize(galloc, expr);
    defer toks.deinit();

    for (toks.items) |t| switch (t.kind) {
        .number => std.debug.print("NUMBER({d})\n", .{t.value}),
        .add => std.debug.print("PLUS\n", .{}),
        .sub => std.debug.print("MINUS\n", .{}),
        .mul => std.debug.print("MUL\n", .{}),
        .lparen => std.debug.print("(\n", .{}),
        .rparen => std.debug.print(")\n", .{}),
        .eof => std.debug.print("EOF\n", .{}),
    };

    var p = Parser{ .tokens = toks.items, .alloc = ast_alloc };
    const ast = try p.parse();
    printNode(ast, 0);

    const result: i64 = try eval(ast);
    
    std.debug.print("{d}\n", .{ result });
}

