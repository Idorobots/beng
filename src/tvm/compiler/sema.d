module tvm.compiler.sema;

import tvm.compiler.ast;
import tvm.compiler.parser;

struct Transformer(Parser) {
    private Parser parser = void;

    this(Parser parser) {
        this.parser = parser;
    }

    @property bool empty() {
        return this.parser.empty;
    }

    @property auto front() {
        return transformTopLevel(parser.front);
    }

    void popFront() {
        this.parser.popFront();
    }
}

private Expression[] extractExprs(Pair p, Expression[] acc = []) {
    if(p.isNil()) return acc;
    else          return extractExprs(p.cdr().asPair(), acc ~ p.car());
}

private string[] symbolsToString(Expression[] exprs) {
    string[] symbols;
    foreach(expr; exprs) {
        symbols ~= expr.asSymbol().toString();
    }
    return symbols;
}

Expression transformTopLevel(Expression e) {
    try {
        if(e.asPair().car().asSymbol().toString() == "define") {
            auto nameArgs = e.asPair().cdr().asPair().car(); // (cadr e)

            // LISPER OF DISAPPROVAL GAZES UPON THIS CODE
            auto name = nameArgs.asPair().car().asSymbol().toString();                   // (car nameArgs)
            auto args = symbolsToString(extractExprs(nameArgs.asPair().cdr().asPair())); // (cdr nameArgs)
            auto body_ = e.asPair.cdr().asPair().cdr().asPair().car();                   // (caddr e)

            return new Definition(name, args, transformExpression(body_));
        } else {
            throw new SemanticError("Only definitions are allowend in the top-level.");
        }
    } catch (SemanticError error) {
        throw new SemanticError("Invalid top-level definition: " ~ e.toString() ~ ". " ~ error.msg);
    }
}

Expression transformExpression(Expression e) {
    if(e.isPair() && !e.isNil()) return transformCompound(e.asPair());
    else if(e.isSymbol())        return new Variable(e.toString());
    else                         return e;
}

private Expression[] transformExprs(Expression[] exprs) {
    foreach(ref expr; exprs) {
        expr = transformExpression(expr);
    }
    return exprs;
}

Expression transformCompound(Pair e) {
    auto car = e.car();
    auto cdr = e.cdr();

    if(car.isSymbol()) {
        switch(car.toString()) {
            case "quote":
                try {
                    return cdr.asPair().car();
                } catch (SemanticError error) {
                    throw new SemanticError("Can't quote nothing!");
                }

            case "if":
                auto cond = cdr.asPair();
                auto then = cond.cdr().asPair();
                auto else_ = then.cdr().asPair();
                return new Conditional(transformExpression(cond.car()),
                                       transformExpression(then.car()),
                                       transformExpression(else_.car()));

            case "primop":
                auto args = extractExprs(cdr.asPair().cdr().asPair());
                string name = cdr.asPair().car().asSymbol().toString();
                return new Primop(name, transformExprs(args));

            case "spawn":
                try {
                    auto fun = cdr.asPair().car().asSymbol().toString();
                    auto arg = cdr.asPair().cdr().asPair().car();
                    return new Spawn(fun, arg);
                } catch (SemanticError error) {
                    throw new SemanticError("Can only spawn named functions!");
                }

            default:
                return transformApplication(e);
        }
    }
    else return transformApplication(e);
}

Expression transformApplication(Expression e) {
    auto exprs = extractExprs(e.asPair());

    switch(exprs.length) {
        case 0:
            throw new SemanticError("Bad application: " ~ e.toString() ~ ".");

        case 1:
            return new Application(transformExpression(exprs[0]),
                                   new Pair(null, null));

        default:
            return new Application(transformExprs(exprs));
    }
}

auto transform(E)(E expressions) {
    return Transformer!E(expressions);
}