module compiler.parser.parse;

import compiler.parser.parser;
import compiler.parser.scanner;
import compiler.parser.ast;

Expression[] parse(string program) {
    auto parser = Parser(Scanner(program));

    Expression[] result;

    foreach(expr; parser) {
        result ~= expr;
    }

    return result;
}