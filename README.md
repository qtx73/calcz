# calc — a tiny expression calculator in Zig

`calc` is a small CLI evaluator for arithmetic expressions, written in Zig.
It supports integers, floating‑point numbers, exponential notation, parentheses, unary signs, and the binary operators `+ - * / % ^`.
You can also inspect the token stream and the abstract syntax tree (AST) for debugging.

**Highlights**

* Works with **`i64` integers** and **`f64` floats**
* Accepts input via **command‑line argument** or **STDIN (up to 1 MiB)**
* `--tokens` and `--ast` flags for introspection

---

## Install / Build

Requires a recent Zig (stable) toolchain.

**Run directly (single file, e.g. `calc.zig`)**

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

When reading from STDIN, leading/trailing whitespace (including newlines) is trimmed. Maximum STDIN size is 1 MiB.

---

## Debug output

### Tokens

```bash
$ ./calc --tokens "1 + (2 * 3.5)"
number(1)
add
(
number(2)
mul
number(3.5)
)
eof
```

### AST

```bash
$ ./calc --ast "1 + 2*3"
add
├── number(1)
└── mul
   ├── number(2)
   └── number(3)
```

> The final result is written to **stdout**. Debug information is printed via `std.debug.print` (stderr).

---

## Grammar & precedence

**Grammar (recursive‑descent; `^` is right‑associative)**

```
Expr    := AddSub
AddSub  := MulDiv { ('+' | '-') MulDiv }
MulDiv  := Prefix { ('*' | '/' | '%') Prefix }
Prefix  := { ('+' | '-') } Power        // multiple signs allowed; weaker than Power
Power   := Primary { '^' Prefix }?       // right-associative
Primary := number | '(' Expr ')'
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
* **Unary `+/-`:** preserves the value’s type (negating an integer returns an integer; negating a float returns a float).

---

## Errors you might see

* `DivisionByZero` — in `/` or `%`
* `FloatModulo` — `%` with any float operand
* `Overflow` — checked integer `+ - *` overflowed `i64`
* `ExpectedPrimary` — expected a number or `(` but found something else
* `ExpectedRParen` — missing `)`
* `TrailingInput` — leftover tokens after a complete expression
* `InvalidCharacter` — unrecognized character during tokenization (e.g., `@`, `#`, `$`)

The program exits non‑zero on errors.

---

## Quick reference

```
# Run
calc "1 + 2*3"

# STDIN
echo "2 ^ 0.5" | calc

# Tokens
calc --tokens "(1 + 2) * 3"

# AST
calc --ast "1 + 2*3"

# Right-associative power
calc "2 ^ 3 ^ 2"     # 512

# Unary sign vs power
calc "-2^2"          # -4
calc "(-2)^2"        # 4

# Error examples
calc "10 % 2.0"      # FloatModulo
calc "1@2"           # InvalidCharacter
```
