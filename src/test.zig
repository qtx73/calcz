const std = @import("std");
const testing = std.testing;
const main = @import("main.zig");

// Helper function to evaluate a mathematical expression and return the result
fn evalExpression(allocator: std.mem.Allocator, expr: []const u8) !main.Value {
    return try main.calculate(allocator, expr, .{});
}

// Helper function to test integer results
fn testIntegerResult(allocator: std.mem.Allocator, expr: []const u8, expected: i64) !void {
    const result = try evalExpression(allocator, expr);
    switch (result) {
        .integer => |actual| try testing.expectEqual(expected, actual),
        .float => |f| {
            // Allow integer results to be returned as floats if they're whole numbers
            try testing.expectEqual(@as(f64, @floatFromInt(expected)), f);
        },
    }
}

// Helper function to test float results
fn testFloatResult(allocator: std.mem.Allocator, expr: []const u8, expected: f64) !void {
    const result = try evalExpression(allocator, expr);
    switch (result) {
        .integer => |i| try testing.expectEqual(expected, @as(f64, @floatFromInt(i))),
        .float => |actual| try testing.expectApproxEqRel(expected, actual, 1e-10),
    }
}

// Test basic addition
test "basic addition" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "2 + 3", 5);
    try testIntegerResult(allocator, "10 + 20", 30);
    try testIntegerResult(allocator, "0 + 5", 5);
    try testFloatResult(allocator, "2.5 + 3.5", 6.0);
    try testFloatResult(allocator, "1 + 2.5", 3.5);
}

// Test basic subtraction
test "basic subtraction" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "5 - 3", 2);
    try testIntegerResult(allocator, "10 - 20", -10);
    try testIntegerResult(allocator, "0 - 5", -5);
    try testFloatResult(allocator, "5.5 - 2.5", 3.0);
    try testFloatResult(allocator, "10 - 2.5", 7.5);
}

// Test basic multiplication
test "basic multiplication" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "2 * 3", 6);
    try testIntegerResult(allocator, "4 * 5", 20);
    try testIntegerResult(allocator, "0 * 10", 0);
    try testFloatResult(allocator, "2.5 * 4", 10.0);
    try testFloatResult(allocator, "3.14 * 2", 6.28);
}

// Test basic division
test "basic division" {
    const allocator = testing.allocator;
    try testFloatResult(allocator, "6 / 2", 3.0);
    try testFloatResult(allocator, "10 / 4", 2.5);
    try testFloatResult(allocator, "7.5 / 2.5", 3.0);
    try testFloatResult(allocator, "1 / 3", 1.0 / 3.0);
}

// Test modulo operation
test "modulo operation" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "7 % 3", 1);
    try testIntegerResult(allocator, "10 % 4", 2);
    try testIntegerResult(allocator, "15 % 5", 0);
    try testIntegerResult(allocator, "8 % 3", 2);
}

// Test power operation
test "power operation" {
    const allocator = testing.allocator;
    try testFloatResult(allocator, "2 ^ 3", 8.0);
    try testFloatResult(allocator, "3 ^ 2", 9.0);
    try testFloatResult(allocator, "5 ^ 0", 1.0);
    try testFloatResult(allocator, "2 ^ 0.5", std.math.sqrt(2.0));
    try testFloatResult(allocator, "4 ^ 0.5", 2.0);
}

// Test unary operators
test "unary operators" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "+5", 5);
    try testIntegerResult(allocator, "-5", -5);
    try testIntegerResult(allocator, "+-5", -5);
    try testIntegerResult(allocator, "-+5", -5);
    try testIntegerResult(allocator, "--5", 5);
    try testFloatResult(allocator, "+3.14", 3.14);
    try testFloatResult(allocator, "-3.14", -3.14);
}

// Test operator precedence
test "operator precedence" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "2 + 3 * 4", 14); // 2 + (3 * 4) = 14
    try testIntegerResult(allocator, "10 - 2 * 3", 4); // 10 - (2 * 3) = 4
    try testFloatResult(allocator, "2 ^ 3 * 4", 32.0); // (2 ^ 3) * 4 = 32
    try testFloatResult(allocator, "2 * 3 ^ 2", 18.0); // 2 * (3 ^ 2) = 18
}

// Test parentheses
test "parentheses" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "(2 + 3) * 4", 20);
    try testIntegerResult(allocator, "2 * (3 + 4)", 14);
    try testIntegerResult(allocator, "(10 - 2) / (3 + 1)", 2);
    try testFloatResult(allocator, "(2 + 3) ^ 2", 25.0);
    try testIntegerResult(allocator, "((2 + 3) * 4) - 5", 15);
}

// Test complex expressions
test "complex expressions" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "2 + 3 * 4 - 5", 9); // 2 + 12 - 5 = 9
    try testFloatResult(allocator, "2.5 * (3 + 1) / 2", 5.0); // 2.5 * 4 / 2 = 5.0
    try testFloatResult(allocator, "3 ^ 2 + 4 ^ 2", 25.0); // 9 + 16 = 25
    try testIntegerResult(allocator, "(5 + 3) * 2 - 10 % 3", 15); // 8 * 2 - 1 = 15
}

// Test right associativity of power operator
test "power right associativity" {
    const allocator = testing.allocator;
    try testFloatResult(allocator, "2 ^ 3 ^ 2", 512.0); // 2 ^ (3 ^ 2) = 2 ^ 9 = 512
    try testFloatResult(allocator, "3 ^ 2 ^ 2", 81.0); // 3 ^ (2 ^ 2) = 3 ^ 4 = 81
}

// Test mixed integer and float operations
test "mixed integer and float operations" {
    const allocator = testing.allocator;
    try testFloatResult(allocator, "5 + 2.5", 7.5);
    try testFloatResult(allocator, "10.0 - 3", 7.0);
    try testFloatResult(allocator, "4 * 2.5", 10.0);
    try testFloatResult(allocator, "7.5 / 3", 2.5);
}

// Test expressions with whitespace
test "expressions with whitespace" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "  2  +  3  ", 5);
    try testIntegerResult(allocator, "\t5\t*\t4\t", 20);
    try testIntegerResult(allocator, " ( 2 + 3 ) * 4 ", 20);
}

// Test zero operations
test "zero operations" {
    const allocator = testing.allocator;
    try testIntegerResult(allocator, "0 + 5", 5);
    try testIntegerResult(allocator, "5 - 0", 5);
    try testIntegerResult(allocator, "0 * 100", 0);
    try testFloatResult(allocator, "0 / 5", 0.0);
    try testIntegerResult(allocator, "0 % 5", 0);
    try testFloatResult(allocator, "0 ^ 5", 0.0);
    try testFloatResult(allocator, "5 ^ 0", 1.0);
}

// Test error cases
test "division by zero error" {
    const allocator = testing.allocator;
    try testing.expectError(main.EvalError.DivisionByZero, evalExpression(allocator, "5 / 0"));
    try testing.expectError(main.EvalError.DivisionByZero, evalExpression(allocator, "10 % 0"));
}

test "float modulo error" {
    const allocator = testing.allocator;
    try testing.expectError(main.EvalError.FloatModulo, evalExpression(allocator, "5.5 % 2"));
    try testing.expectError(main.EvalError.FloatModulo, evalExpression(allocator, "10 % 2.5"));
}
