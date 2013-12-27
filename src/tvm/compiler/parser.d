module tvm.compiler.parser;

import std.string;
import std.conv;

import tvm.compiler.tokens;
import tvm.compiler.scanner;
import tvm.compiler.ast;

struct Filtered(Scanner) {
  private:
    Scanner scanner;

    void skipWhitespace() {
        auto token = scanner.front();

        while(token.type == TokenType.WHITESPACE || token.type == TokenType.COMMENT) {
            scanner.popFront();
            token = scanner.front;
        }
    }

  public:
    this(Scanner scanner) {
        this.scanner = scanner;
    }

    @property bool empty() {
        skipWhitespace();
        return scanner.empty;
    }

    @property auto front() {
        skipWhitespace();
        return scanner.front;
    }

    void popFront() {
        scanner.popFront();
    }
}

struct Parser(Scanner) {
  private:
    Pair NIL;
    Scanner scanner;
    Expression lastParse;
    bool seenEOF;

    Token currToken() {
        auto token = scanner.front;
        if(token.type == TokenType.EOF) {
            // FIXME I have a weird feeling that this could be done better...
            if(seenEOF)
                throw new SyntaxError("End of file reached during parsing.", token);
            seenEOF = true;
        }

        return token;
    }

    void nextToken() {
        scanner.popFront();
    }

    void parse() {
        Token token = currToken();

        switch(token.type) {
            case TokenType.LPAREN:
                parseList(TokenType.RPAREN);
                break;
            case TokenType.LBRACKET:
                parseList(TokenType.RBRACKET);
                break;
            case TokenType.LCURLY:
                parseList(TokenType.RCURLY);
                break;
            case TokenType.SYMBOL:
            case TokenType.NUMBER:
            case TokenType.STRING:
                parseAtom(token);
                break;
            case TokenType.QUOTE:
            case TokenType.QUASIQUOTE:
            case TokenType.UNQUOTE:
                parseSpecial(token);
                break;
            case TokenType.EOF:
                // Do nothing
                break;
            default:
                throw new SyntaxError(format("Unexpected token: %s %s", token.type, token.value), token);
        }
    }

    void parseList(TokenType delimiter) {
        nextToken();
        if(currToken().type == delimiter) {
            nextToken();
            lastParse = NIL;
            return;
        }

        Expression[] list;

        parse();
        list ~= lastParse;

        while(currToken().type != delimiter && currToken().type != TokenType.DOT) {
            parse();
            list ~= lastParse;
        }

        if(currToken().type == delimiter) {
            nextToken();
            lastParse = NIL;
        } else {
            nextToken();
            parse();
            if(currToken().type != delimiter) {
                throw new SyntaxError("Malformed dotted list literal.", currToken());
            }
            nextToken();
        }

        for(size_t i = 1; i <= list.length; ++i) {
            lastParse = new Pair(list[$ - i], lastParse);
        }
    }

    void parseAtom(Token token) {
        switch(token.type) {
            case TokenType.SYMBOL:
                lastParse = new Symbol(token.value);
                break;
            case TokenType.NUMBER:
                lastParse = new Number(to!double(token.value));
                break;
            case TokenType.STRING:
                lastParse = new String(token.value);
                break;
            default: break;
        }
        nextToken();
    }

    void parseSpecial(Token token) {
        string symbol;

        switch(token.type) {
            case TokenType.QUOTE:
                symbol = "quote";
                break;
            case TokenType.QUASIQUOTE:
                symbol = "qasiquote";
                break;
            case TokenType.UNQUOTE:
                symbol = "unquote";
                break;
            default: break;
        }

        nextToken();
        parse(); // lastParse is now the next item.

        lastParse = new Pair(new Symbol(symbol), new Pair(lastParse, NIL));
    }

  public:
    this(Scanner scanner) {
        this.scanner = scanner;
        this.NIL = new Pair(null, null);
        parse();
    }

    @property bool empty() {
        return seenEOF;
    }

    @property Expression front() {
        return lastParse;
    }

    void popFront() {
        parse();
    }
}

auto filter(T)(T tokens) {
    return Filtered!T(tokens);
}

auto parse(T)(T tokens) {
    return Parser!T(tokens);
}