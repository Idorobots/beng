module tvm.compiler.tokens;

enum TokenType : ubyte {
    EOF,
    COMMENT,
    WHITESPACE,
    LPAREN,
    RPAREN,
    LBRACKET,
    RBRACKET,
    LCURLY,
    RCURLY,
    SYMBOL,
    NUMBER,
    STRING,
    QUOTE,
    QUASIQUOTE,
    UNQUOTE,
    DOT
}

struct Token {
    TokenType type;
    size_t line, column, offset;
    string value;

    this(TokenType type, size_t line, size_t column, size_t offset, string value = "") {
        this.type = type;
        this.line = line;
        this.column = column;
        this.offset = offset;
        this.value = value;
    }
}