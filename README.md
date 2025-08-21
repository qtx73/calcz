# calc — a tiny expression calculator in Zig

`calc` is a small CLI evaluator for arithmetic expressions, written in Zig.
It supports integers, floating‑point numbers, exponential notation, parentheses, unary signs, binary operators `+ - * / % ^`, mathematical functions, and built-in constants.
You can also inspect the token stream and the abstract syntax tree (AST) for debugging.

**Highlights**

* Works with **`i64` integers** and **`f64` floats**
* Accepts input via **command‑line argument** or **STDIN (up to 1 MiB)**
* **Mathematical functions**: `abs`, `sqrt`, `pow`, `sin`, `cos`, `tan`, `log`, `ln`
* **Built-in constants**: `pi`, `e`
* `--tokens` and `--ast` flags for introspection
* **Public API** for library usage

---

## Install / Build

Requires a recent Zig (stable) toolchain.

**Run directly (single file, e.g. `main.zig`)**

```bash
# Run
zig run src/main.zig -- "1 + 2*3"

# Build a release binary
zig build
./zig-out/bin/calc "2 ^ 10"
```
---

## Usage

```
calc [--tokens] [--ast] <expr>
# or (when no <expr> is given) read the expression from STDIN
echo "1 + (2 * 3)" | calc
```

Flags:

* `--tokens` – print the token stream, one per line
* `--ast` – print the AST as an ASCII tree

When reading from STDIN, leading/trailing whitespace (including newlines) is trimmed. Maximum STDIN size is 1 MiB.

---

## Mathematical Functions

The calculator supports the following mathematical functions:

| Function | Description | Example |
|----------|-------------|---------|
| `abs(x)` | Absolute value | `abs(-5)` → `5` |
| `sqrt(x)` | Square root | `sqrt(16)` → `4` |
| `pow(x,y)` | Power (x^y) | `pow(2,3)` → `8` |
| `sin(x)` | Sine (radians) | `sin(pi/2)` → `1` |
| `cos(x)` | Cosine (radians) | `cos(0)` → `1` |
| `tan(x)` | Tangent (radians) | `tan(pi/4)` → `1` |
| `log(x)` | Base-10 logarithm | `log(100)` → `2` |
| `ln(x)` | Natural logarithm | `ln(e)` → `1` |

**Function Notes:**
- All trigonometric functions expect angles in **radians**
- `sqrt(x)` requires `x ≥ 0`
- `log(x)` and `ln(x)` require `x > 0`
- Functions return floating-point results

---

## Built-in Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `pi` | 3.14159... | Mathematical constant π |
| `e` | 2.71828... | Euler's number |

**Examples:**
```bash
calc "pi * 2"           # 6.283185307179586e+00
calc "e ^ 2"            # 7.38905609893065e+00
calc "sin(pi/2)"        # 1e+00
calc "ln(e)"            # 1e+00
```

---

## Debug output

### Tokens

```bash
$ ./calc --tokens "sqrt(abs(-16))"
identifier(sqrt)
(
identifier(abs)
(
sub
number(16)
)
)
eof
```

### AST

```bash
$ ./calc --ast "sin(pi/2)"
sin()
└── div
    ├── variable(pi)
    └── number(2)
```

> The final result is written to **stdout**. Debug information is printed via `std.debug.print` (stderr).

---

## Grammar & precedence

**Grammar (recursive‑descent; `^` is right‑associative)**

```
Expr         := AddSub
AddSub       := MulDiv { ('+' | '-') MulDiv }
MulDiv       := Prefix { ('*' | '/' | '%') Prefix }
Prefix       := { ('+' | '-') } Power        // multiple signs allowed; weaker than Power
Power        := Primary { '^' Prefix }?       // right-associative
Primary      := number | '(' Expr ')' | FunctionCall | Variable
FunctionCall := FunctionName '(' Expr [',' Expr] ')'
Variable     := Identifier  // Currently: pi, e
```
---

## Semantics

* **Numeric literals:** decimal numbers with optional exponential notation (e.g., `123`, `3.14`, `1e3`, `2.5E-4`). Both `e` and `E` are supported for exponents, with optional `+` or `-` signs.
* **Type promotion:**

  * Integer `+ - *` integer → integer (checked; overflow → error)
  * If either side is a float, `+ - *` → float
* **Division `/`:** always performed in `f64` (integer operands are promoted). Division by zero → error.
* **Modulo `%`:** only allowed for **integer** operands. Right operand `0` → error. Any float operand → error.
* **Power `^`:** both sides are promoted to `f64` and evaluated via `std.math.pow`. Fractional and negative exponents are allowed; the result is a float.
* **Unary `+/-`:** preserves the value's type (negating an integer returns an integer; negating a float returns a float).
* **Functions:** all mathematical functions return `f64` results. Function arguments are automatically promoted to `f64` when needed.
* **Constants:** built-in constants (`pi`, `e`) are `f64` values.

---

## Errors you might see

* `DivisionByZero` — in `/`, `%`, or when a function encounters division by zero
* `FloatModulo` — `%` with any float operand
* `Overflow` — checked integer `+ - *` overflowed `i64`
* `ExpectedPrimary` — expected a number, `(`, function, or constant but found something else
* `ExpectedRParen` — missing `)`
* `TrailingInput` — leftover tokens after a complete expression
* `InvalidCharacter` — unrecognized character during tokenization (e.g., `@`, `#`, `$`)
* `InvalidFunctionArgument` — invalid argument to a function (e.g., `sqrt(-1)`, `log(0)`)
* `WrongArgumentCount` — incorrect number of arguments to a function
* `UnknownVariable` — reference to an undefined variable or constant

The program exits non‑zero on errors.

## Quick reference

```bash
# Basic arithmetic
calc "1 + 2*3"

# Functions
calc "sqrt(16)"          # 4e+00
calc "abs(-42)"          # 42
calc "pow(2, 8)"         # 256e+00

# Trigonometry (radians)
calc "sin(pi/2)"         # 1e+00
calc "cos(0)"            # 1e+00
calc "tan(pi/4)"         # 1e+00

# Logarithms
calc "log(1000)"         # 3e+00
calc "ln(e^2)"           # 2e+00

# Constants
calc "pi * 2"            # 6.283185307179586e+00
calc "e^2"               # 7.38905609893065e+00

# Complex expressions
calc "sqrt(sin(pi/6)^2 + cos(pi/6)^2)"  # 1e+00

# STDIN
echo "2 ^ 0.5" | calc

# Tokens
calc --tokens "sin(pi)"

# AST
calc --ast "sqrt(abs(-16))"

# Right-associative power
calc "2 ^ 3 ^ 2"         # 512

# Unary sign vs power
calc "-2^2"              # -4
calc "(-2)^2"            # 4

# Error examples
calc "10 % 2.0"          # FloatModulo
calc "sqrt(-1)"          # InvalidFunctionArgument
calc "unknown_func(1)"   # ExpectedPrimary
calc "1@2"               # InvalidCharacter
```

---

## Library Usage

The calculator provides a public API for use as a library:

```zig
const std = @import("std");
const calc = @import("main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const debug_options = calc.DebugOptions{
        .show_tokens = false,
        .show_ast = false,
    };
    
    const result = try calc.calculate(allocator, "sqrt(16) + sin(pi/2)", debug_options);
    
    switch (result) {
        .integer => |i| std.debug.print("Result: {d}\n", .{i}),
        .float => |f| std.debug.print("Result: {e}\n", .{f}),
    }
}
```

**API Functions:**
- `calculate(allocator, expression, debug_options)` — Main calculation function
- `DebugOptions` — Struct for controlling debug output (`show_tokens`, `show_ast`)
- `Value` — Union type representing either `i64` or `f64` results

---
