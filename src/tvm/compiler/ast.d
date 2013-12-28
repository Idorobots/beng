module tvm.compiler.ast;

import std.string;
import std.conv : to;
import std.range;

class SemanticError : Exception {
    this(string what) {
        super(what);
    }
}

class Expression {
    // Type predicates, etc:
    protected mixin template Predicate(T, bool p = true, bool over = true) {
        mixin((over ? "override " : "") ~ "bool is" ~ T.stringof ~ "() { return " ~ p.stringof ~"; }");
    }

    mixin Predicate!(Expression, true, false);
    mixin Predicate!(Symbol, false, false);
    mixin Predicate!(Number, false, false);
    mixin Predicate!(Pair, false, false);
    mixin Predicate!(String, false, false);
    mixin Predicate!(Variable, false, false);
    mixin Predicate!(Application, false, false);
    mixin Predicate!(Primop, false, false);
    mixin Predicate!(Conditional, false, false);
    mixin Predicate!(Definition, false, false);

    // Type coercion:
    protected mixin template Coercion(T, bool possible = true, bool over = true) {
        mixin((over ? "override " : "") ~ T.stringof ~ " " ~ "as" ~ T.stringof ~ "() {" ~
              (possible
               ? "return this;"
               : "throw new SemanticError(\"Tried converting \" ~ this.toString() ~
                                         \" to a " ~ T.stringof ~ "!\");")
              ~ "}");
    }

    mixin Coercion!(Expression, true, false);
    mixin Coercion!(Symbol, false, false);
    mixin Coercion!(Number, false, false);
    mixin Coercion!(Pair, false, false);
    mixin Coercion!(String, false, false);
    mixin Coercion!(Variable, false, false);
    mixin Coercion!(Application, false, false);
    mixin Coercion!(Primop, false, false);
    mixin Coercion!(Conditional, false, false);
    mixin Coercion!(Definition, false, false);

    // Factory:
    static Expression build(double n) {
        return new Number(n);
    }

    static Expression build(string s) {
        return new String(s);
    }

    static Expression build(Expression e) {
        return e;
    }

    // Utils:
    bool isNil() {
        return false;
    }

    override string toString() {
        return format("%x", (*cast(size_t*) &this));
    }

    double toNumber() {
        throw new SemanticError("Tried converting " ~ this.toString() ~ " to a number!");
    }
}

class Number : Expression {
    private double number;

    this(double number) {
        this.number = number;
    }

    mixin Predicate!Number;
    mixin Coercion!Number;

    override string toString() {
        return to!string(number);
    }

    override double toNumber() {
        return number;
    }
}

class Symbol : Expression {
    private string symbol;

    this(string symbol) {
        this.symbol = symbol;
    }

    mixin Predicate!Symbol;
    mixin Coercion!Symbol;

    override string toString() {
        return symbol;
    }
}

class String : Expression {
    private string str;

    this(string str) {
        this.str = str;
    }

    mixin Predicate!String;
    mixin Coercion!String;

    override string toString() {
        return "\"" ~ str ~ "\"";
    }

    string dstring() {
        return str;
    }
}

class Pair : Expression {
    private Expression _car, _cdr;

    this(Expression car, Expression cdr) {
        this._car = car;
        this._cdr = cdr;
    }

    mixin Predicate!Pair;
    mixin Coercion!Pair;

    override bool isNil() {
        return (_car is null || _cdr is null);
    }

    override string toString() {
        if(isNil())
            return "()";

        string makeString(Pair p) {
            auto pcar = p.car;
            auto pcdr = p.cdr;

            if(pcdr.isPair()) {
                Pair next = pcdr.asPair();
                if(next.isNil()) {
                    return pcar.toString();
                } else {
                    return pcar.toString ~ " " ~ makeString(next);
                }
            } else {
                return pcar.toString() ~ " . " ~ pcdr.toString();
            }
        }
        return "(" ~ makeString(this) ~ ")";
    }

    @property Expression car() {
        if(isNil()) throw new SemanticError("Tried accessing the car part of a ()!");
        return _car;
    }

    @property Expression cdr() {
        if(isNil()) throw new SemanticError("Tried accessing the cdr part of a ()!");
        return _cdr;
    }
}

class Variable : Expression {
    string name;

    this(string name) {
        this.name = name;
    }

    mixin Predicate!Variable;
    mixin Coercion!Variable;

    override string toString() {
        return "$" ~ name;
    }
}

class Application : Expression {
    Expression operator, operand;

    this(Expression operator, Expression operand) {
        this.operator = operator;
        this.operand = operand;
    }

    this(Expression[] expressions) {
        if(expressions.length == 2) {
            this.operator = expressions[0];
            this.operand = expressions[1];
        } else if(expressions.length > 2) {
            this.operator = new Application(expressions[0..$-1]);
            this.operand = expressions[$-1];
        } else {
            throw new SemanticError("Malformed application!");
        }
    }

    mixin Predicate!Application;
    mixin Coercion!Application;

    override string toString() {
        return format("#apply{%s, %s}", operator.toString(), operand.toString());
    }
}

class Primop : Expression {
    string name;
    Expression[] args;

    this(string name, Expression[] args...) {
        this.name = name;
        this.args = args;
    }

    mixin Predicate!Primop;
    mixin Coercion!Primop;

    override string toString() {
        string str;
        if(args.length > 0) {
            foreach(arg; args[0..$-1]) {
                str ~= arg.toString() ~ ", ";
            }
            str ~= args[$-1].toString();
        }

        return format("#primop{%s, %s}", name, str);
    }
}

class Conditional : Expression {
    Expression condition, then, otherwise;

    this(Expression cond, Expression then, Expression else_) {
        this.condition = cond;
        this.then = then;
        this.otherwise = else_;
    }

    mixin Predicate!Conditional;
    mixin Coercion!Conditional;

    override string toString() {
        return format("#cond{%s, %s, %s}", condition.toString(), then.toString(), otherwise.toString());
    }
}

class Definition : Expression {
    string name;
    string[] args;
    Expression body_;

    this(string name, string[] args, Expression body_) {
        this.name = name;
        this.args = args;
        this.body_ = body_;
    }

    mixin Predicate!Definition;
    mixin Coercion!Definition;

    override string toString() {
        string str;

        if(args.length > 0) {
            foreach(arg; args[0..$-1]) {
                str ~= arg ~ ", ";
            }
            str ~= args[$-1];
        }

        return format("#def{%s, [%s], %s}", name, str, body_.toString());
    }
}