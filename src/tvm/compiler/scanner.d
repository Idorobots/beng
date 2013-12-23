module tvm.compiler.scanner;

import std.stdio;

import std.container;
import std.uni;
import std.utf;

import tvm.compiler.tokens;

class SyntaxError : Exception {
    Token token;

    this(string what, Token offender) {
        super(what);
        token = offender;
    }
}

struct Scanner {
  private:
    string input;
    size_t currLine, currColumn, currOffset;
    SList!Token mismatchStack;
    Token lastToken;

    bool isAny(string values)(char c) {
        foreach(v; values) {
            if(c == v) return true;
        }
        return false;
    }

    void scan() {
        auto c = input[currOffset];
        auto n = currOffset+1 == input.length ? 0 : input[currOffset+1];

        if(c == 0)          return scanEOF();
        if(isAny!"([{"(c))  return scanOpenParen(c);
        if(isAny!")]}"(c))  return scanCloseParen(c);
        if(isAny!".',`"(c)) return scanSpecial(c);
        if(isWhite(c))      return scanWhitespace();
        if(isAny!"#"(c))    return scanComment();
        if(isAny!"\""(c))   return scanString();
        if(isNumber(c)
           || isAny!"-"(c)
           && isNumber(n))  return scanNumber();
        return scanSymbol();
    }
    void scanEOF() {
        lastToken = Token(TokenType.EOF, currLine, currColumn, currOffset);
    }

    void scanOpenParen(char paren) {
        TokenType type;

        switch(paren) {
            case '(':
                type = TokenType.LPAREN;
                break;
            case '[':
                type = TokenType.LBRACKET;
                break;
            case '{':
                type = TokenType.LCURLY;
                break;
            default: break;
        }
        auto token = Token(type, currLine, currColumn, currOffset, paren ~ "");

        mismatchStack.insertFront(token);
        lastToken = token;
        currOffset++;
        currColumn++;
    }

    void scanCloseParen(char paren) {
        auto token = Token(TokenType.RPAREN, currLine, currColumn, currOffset, paren ~ "");
        auto type = TokenType.LPAREN;

        switch(paren) {
            case ')':
                break;
            case ']':
                token.type = TokenType.RBRACKET;
                type = TokenType.LBRACKET;
                break;
            case '}':
                token.type = TokenType.RCURLY;
                type = TokenType.LCURLY;
                break;
            default: break;
        }

        if(mismatchStack.empty || mismatchStack.front.type != type) {
            throw new SyntaxError("Mismatched parentheses: " ~ paren, token);
        } else {
            mismatchStack.removeFront();
        }

        lastToken = token;
        currOffset++;
        currColumn++;
    }

    void scanSpecial(char special) {
        TokenType type;

        switch(special) {
            case '.':
                type = TokenType.DOT;
                break;
            case '\'':
                type = TokenType.QUOTE;
                break;
            case '`':
                type = TokenType.QUASIQUOTE;
                break;
            case ',':
                type = TokenType.UNQUOTE;
                break;
            default: break;
        }

        lastToken = Token(type, currLine, currColumn, currOffset, special ~ "");
        currOffset++;
        currColumn++;
    }

    void scanWhitespace() {
        auto offset = currOffset;
        auto line = currLine;
        auto column = currColumn;

        char c = input[currOffset];

        while(currOffset < input.length && isWhite(c)) {
            if(c == '\n') {
                currLine++;
                currColumn = 0;
            } else {
                currColumn++;
            }
            ++currOffset;
            if(currOffset < input.length)
                c = input[currOffset];
        }

        lastToken = Token(TokenType.WHITESPACE, line, column, offset, input[offset..currOffset]);
    }

    void scanComment() {
        auto offset = currOffset;

        while(input[currOffset++] != '\n') {}

        lastToken = Token(TokenType.COMMENT, currLine, currColumn, offset, input[offset..currOffset]);

        currLine++;
        currColumn = 0;
    }

    void scanString() {
        auto offset = currOffset;
        auto line = currLine;
        auto column = currColumn;

        currOffset++;

        while(input[currOffset] != '\"') {
            // TODO Escape sequences.
            if(input[currOffset] == '\n') {
                currLine++;
                currColumn = 0;
            } else {
                currColumn++;
            }
            currOffset++;
        }
        currOffset++;

        auto str = (offset+1 >= currOffset-1) ? "" : input[offset+1 .. currOffset-1];
        lastToken = Token(TokenType.STRING, line, column, offset, str);
    }

    void scanNumber() {
        auto offset = currOffset;

        // TODO Hex, etc.
        while(isNumber(input[++currOffset])) {}
        if(input[currOffset] == '.') {
            currOffset++;
            while(isNumber(input[++currOffset])) {}
        }

        lastToken = Token(TokenType.NUMBER, currLine, currColumn, offset, input[offset..currOffset]);

        currColumn += currOffset - offset;
    }

    void scanSymbol() {
        auto offset = currOffset;
        auto column = currColumn;

        char c = input[currOffset];
        while(!isAny!",`'."(c) && !isAny!"([{}])"(c) && !isWhite(c)) {
            c = input[++currOffset];
            currColumn++;
        }

        lastToken = Token(TokenType.SYMBOL, currLine, column, offset, input[offset..currOffset]);
    }

  public:
    this(string input) {
        try {
            validate(input);
        } catch (UTFException e) {
            throw new SyntaxError("Invalid Unicode character sequence, unable to parse.",
                                  Token(TokenType.WHITESPACE, 0, 0, 0));
        }
        this.input = input ~ "\0";

        scan();
    }

    @property bool empty() {
        return lastToken.type == TokenType.EOF;
    }

    @property Token front() {
        return lastToken;
    }

    void popFront() {
        scan();
    }
}
