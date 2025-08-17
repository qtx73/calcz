### Overview

The program is a **tiny calculator** written in Zig. It reads an arithmetic expression (like `1 + 2 * (3 - 4)`), turns it into tokens, builds an **abstract syntax tree (AST)**, optionally prints the tokens or the tree, and then evaluates the result.

---

### Step by Step

1. **Tokenization**
   The input string is broken into *tokens*:

   * numbers (`123`)
   * operators (`+`, `-`, `*`)
   * parentheses (`(`, `)`)
   * an end marker (`EOF`)

   Example: `"1 + 2*3"` → `NUMBER(1)`, `PLUS`, `NUMBER(2)`, `MUL`, `NUMBER(3)`, `EOF`.

2. **Parsing**
   It uses a **recursive descent parser** to turn the token list into an AST.
   Grammar rules:

   * `Expr := AddSub`
   * `AddSub := Mul { ('+'|'-') Mul }`
   * `Mul := Unary { '*' Unary }`
   * `Unary := ('+'|'-' Unary) | Primary`
   * `Primary := number | '(' Expr ')'`

   This ensures operator precedence (`*` before `+`/`-`) and correct handling of parentheses and unary `+`/`-`.

3. **AST (Abstract Syntax Tree)**
   The AST represents the structure of the expression.
   For `1 - 2 * 3`, the tree looks like:

   ```
   Sub
   ├── number(1)
   └── Mul
       ├── number(2)
       └── number(3)
   ```

4. **Evaluation**
   The AST is recursively evaluated:

   * A `number` returns its value.
   * `add`, `sub`, `mul` compute left/right recursively.
   * `pos` just returns the child.
   * `neg` negates the child.

   So for `1 - 2 * 3` → result is `-5`.

5. **Command-line Options**

   * `--tokens`: print the tokens.
   * `--ast`: print the AST.
   * Otherwise, it just prints the final result.

---

### Example Runs

```bash
$ zig build run -- "1+2*3"
7

$ zig build run -- --tokens "(2+3)*4"
(
NUMBER(2)
PLUS
NUMBER(3)
)
MUL
NUMBER(4)
EOF

$ zig build run -- --ast "1 - 2 * 3"
Sub
├── number(1)
└── Mul
   ├── number(2)
   └── number(3)
```
