module tvm.compiler.codegen;

import std.traits : ParameterTypeTuple;
import std.typecons : tuple;
import std.algorithm : reverse;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.primops;
import tvm.vm.gc;

// FIXME This probably should be moved to the AST.
// FIXME But it's so elegant...
private auto typeDispatch(T, Cs...)(T value, Cs callbacks) {
    /*static*/ foreach(i, C; Cs) {
        if((cast(ParameterTypeTuple!C[0]) value) !is null) {
            return callbacks[i](cast(ParameterTypeTuple!C[0]) value);
        }
    }
    throw new SemanticError("Can't compile that!");
}

private TVMValue prefix(Allocator)(Allocator a, size_t n, TVMValue withWhat, TVMValue rest) {
    if(n == 0) return rest;
    else       return value(pair(a, withWhat, prefix(a, n-1, withWhat, rest)));
}

TVMPointer compileDefinition(Allocator)(Allocator a, Definition def, string[] env) {
    auto args = def.args;
    reverse(args);
    auto body_ = def.body_;

    // NOTE Args will be pushed in reverse order onto the stack.
    auto code = prefix(a, args.length, value(take(a)), compileR(a, body_, args ~ env));

    // NOTE The environment will be updated later.
    return closure(a, code, value(nil()));
}

long assoc(string what, string[] where) {
    foreach(i, w; where) {
        if(what == w) return i;
    }
    throw new SemanticError("Undefined variable `" ~ what ~ "'.");
}

TVMValue compileR(Allocator)(Allocator a, Expression e, string[] env) {
    return typeDispatch(
        e,
        (Variable var) {
            auto v = compileA(a, var, env);
            return value(list(a, value(enter(v[0], a, v[1]))));
        },
        (Application app) {
            auto operand = compileA(a, app.operand, env);
            return value(pair(a, value(next(operand[0], a, operand[1])), compileR(a, app.operator, env)));
        },
        (Expression expr) {
            return compileB(a, expr, env, value(nil()));
        });
}

TVMValue compileV(Allocator)(Allocator a, Expression e, string[] env) {
    return typeDispatch(
        e,
        (Variable var) {
            return value(assoc(var.name, env));
        },
        (Symbol sym) {
            return value(symbol(a, sym.toString()));
        },
        (String str) {
            return value(symbol(a, str.dstring()));
        },
        (Number num) {
            return value(cast(long) num.toNumber());
        },
        (Pair pr) {
            if(pr.isNil()) return value(nil());
            else           return value(pair(a,
                                             compileV(a, pr.car, env),
                                             compileV(a, pr.cdr, env)));
        });
}

auto compileA(Allocator)(Allocator a, Expression e, string[] env) {
    return typeDispatch(
        e,
        (Variable var) {
            return tuple(arg(), compileV(a, var, env));
        },
        (Symbol sym) {
            return tuple(val(), compileV(a, sym, env));
        },
        (String str) {
            return tuple(val(), compileV(a, str, env));
        },
        (Number num) {
            return tuple(val(), compileV(a, num, env));
        },
        (Pair pr) {
            return tuple(val(), compileV(a, pr, env));
        },
        (Expression expr) {
            return tuple(code(), value(compileR(a, expr, env)));
        });
}

TVMValue compileB(Allocator)(Allocator a, Expression e, string[] env, TVMValue continuation) {
    return typeDispatch(
        e,
        (Symbol sym) {
            return value(pair(a, value(push(a, compileV(a, sym, env))), continuation));
        },
        (String str) {
            return value(pair(a, value(push(a, compileV(a, str, env))), continuation));
        },
        (Number num) {
            return value(pair(a, value(push(a, compileV(a, num, env))), continuation));
        },
        (Pair pr) {
            return value(pair(a, value(push(a, compileV(a, pr, env))), continuation));
        },
        (Primop op) {
            auto name = op.name;
            auto args = op.args;

            if(primopDefined(name)) {
                auto ret = value(pair(a, value(primop(a, primopOffset(name))), continuation));

                foreach(arg; args) {
                    ret = compileB(a, arg, env, ret);
                }
                return ret;
            } else {
                throw new SemanticError("Unknown primitive operation `" ~ name ~ "'.");
            }
        },
        (Conditional conditional) {
            auto cond_ = conditional.condition;
            auto then_ = conditional.then;
            auto else_ = conditional.otherwise;

            auto c = value(cond(a,
                                pair(a,
                                     compileR(a, then_, env),
                                     compileR(a, else_, env))));

            return compileB(a, cond_, env, value(pair(a, c, continuation)));
        },
        (Expression expr) {
            return value(pair(a, value(next(code(), a, continuation)), compileR(a, expr, env)));
        });
}

private string[] collectEnv(Expression[] expressions) {
    string[] env;

    foreach(expr; expressions) {
        env ~= expr.asDefinition().name;
    }

    return env;
}

private Expression[] takeAll(E)(E expressions) {
    Expression[] exprs;

    foreach(expr; expressions) {
        exprs ~= expr;
    }

    return exprs;
}

private void updateEnvs(TVMPairPtr defs, TVMPointer env) {
    if(isNil(defs)) return;

    TVMValue car = defs.car;
    auto closure = asClosure(car.ptr);

    // NOTE Each pointer has to be accounted for.
    closure.env = value(use(env));

    TVMValue rest = defs.cdr;

    if(isPointer(rest)) updateEnvs(asPair(rest.ptr), env);
    else                assert(0, "Malformed environment.");
}

auto compile(Allocator, E)(Allocator a, E expressions) {
    auto exprs = takeAll(expressions);
    auto names = collectEnv(exprs);
    reverse(names);

    auto env = nil();

    foreach(expr; exprs) {
        env = pair(a, value(compileDefinition(a, expr.asDefinition(), names)), value(env));
    }

    updateEnvs(asPair(env), asObject(env));
    return tuple(names, env);
}