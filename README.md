### Overview

The program is a **tiny calculator** written in Zig. It reads an arithmetic expression (like `1.5 + 2 * (3 - 4)`), turns it into tokens, builds an **abstract syntax tree (AST)**, optionally prints the tokens or the tree, and then evaluates the result.

It supports:
*   Integers and floating-point numbers.
*   Operators: `+`, `-`, `*`, `/`, `%`, `^` (power).
*   Parentheses for grouping.
*   Unary `+` and `-`.

---

### Step by Step

1.  **Tokenization**
    The input string is broken into *tokens*:

    *   numbers (`123`, `1.23`)
    *   operators (`+`, `-`, `*`, `/`, `%`, `^`)
    *   parentheses (`(`, `)`)
    *   an end marker (`EOF`)

    Example: `"1 + 2*3"` → `NUMBER(1)`, `PLUS`, `NUMBER(2)`, `MUL`, `NUMBER(3)`, `EOF`.

2.  **Parsing**
    It uses a **recursive descent parser** to turn the token list into an AST.
    The grammar rules ensure correct operator precedence:

    *   `Expr := AddSub`
    *   `AddSub := MulDiv { ('+'|'-') MulDiv }`
    *   `MulDiv := Power { ('*'|'/'|'%') Power }`
    *   `Power := Unary { '^' Unary }`
    *   `Unary := ('+'|'-') Unary | Primary`
    *   `Primary := number | '(' Expr ')'`

3.  **AST (Abstract Syntax Tree)**
    The AST represents the structure of the expression.
    For `1 - 2 * 3`, the tree looks like:

    ```
    Sub
    ├── number(1)
    └── Mul
        ├── number(2)
        └── number(3)
    ```

4.  **Evaluation**
    The AST is recursively evaluated:

    *   A `number` returns its value.
    *   Binary operators (`+`, `-`, `*`, etc.) compute their left and right children recursively.
    *   Unary `+` returns its child's value, and unary `-` negates it.
    *   Division (`/`) always produces a float.
    *   Modulo (`%`) requires integer operands.
    *   Power (`^`) is calculated using floating-point math.
    *   Errors like division by zero are handled.

5.  **Command-line Options**

    *   `--tokens`: print the tokens.
    *   `--ast`: print the AST.
    *   Otherwise, it just prints the final result.

---

### Example Runs

```bash
$ zig build
$ ./zig-out/bin/calc "1+2*3"
7

$ ./zig-out/bin/calc "1.5 * (2 + 3)"
7.5

$ ./zig-out/bin/calc "10 % 3"
1

$ ./zig-out/bin/calc "2 ^ 10"
1024

$ ./zig-out/bin/calc --tokens "(2+3)*4"
(
NUMBER(2)
PLUS
NUMBER(3)
)
MUL
NUMBER(4)
EOF
20

$ ./zig-out/bin/calc --ast "1 - 2 * 3"
Sub
├── number(1)
└── Mul
   ├── number(2)
   └── number(3)
-5
```