module tvm.vm.primops;

import std.math;
import std.typecons : tuple;
import std.stdio;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.interpreter;
import tvm.vm.gc;
import tvm.compiler.printer;

alias TVMPrimop = time_t function (time_t time, TVMContext uProc);

auto take(size_t n)(TVMContext uProc) {
    TVMValue[n] args;
    foreach(i, ref arg; args) {
        arg = nth(uProc.alloc, i, uProc.vstack);
    }
    return args;
}

void fail() {
    throw new RuntimeError("Type mismatch.");
}

auto enforce(alias predicate, Ts)(Ts values) {
    /*static*/ foreach(i, val; values) {
        if(!predicate(val)) fail();
    }
    return values;
}

auto swap(size_t n)(TVMContext uProc, TVMValue val) {
    static if(n == 0) {
        uProc.vstack = push(uProc.alloc, val, uProc.vstack);
    } else {
        uProc.vstack = pop(uProc.alloc, uProc.vstack);
        swap!(n-1)(uProc, val);
    }
}

// Arithmetic
time_t add(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(args[0].floating + args[1].floating));
    return 0;
}

time_t sub(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(args[0].floating - args[1].floating));
    return 0;
}

time_t mult(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(args[0].floating * args[1].floating));
    return 0;
}

time_t div(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(args[0].floating / args[1].floating));
    return 0;
}

time_t mod(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(fmod(args[0].floating, args[1].floating)));
    return 0;
}

time_t pow(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, value(args[0].floating ^^ args[1].floating));
    return 0;
}

time_t inc(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!1(uProc));
    swap!1(uProc, value(args[0].floating + 1));
    return 0;
}

time_t dec(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!1(uProc));
    swap!1(uProc, value(args[0].floating - 1));
    return 0;
}

// Logic:
time_t eq(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, args[0].floating == args[1].floating ? value(1.0) : value(nil()));
    return 0;
}

time_t less(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, args[0].floating < args[1].floating ? value(1.0) : value(nil()));
    return 0;
}

time_t greater(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, args[0].floating > args[1].floating ? value(1.0) : value(nil()));
    return 0;
}

time_t leq(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, args[0].floating <= args[1].floating ? value(1.0) : value(nil()));
    return 0;
}

time_t geq(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!2(uProc));
    swap!2(uProc, args[0].floating >= args[1].floating ? value(1.0) : value(nil()));
    return 0;
}

// List operations:
time_t mknil(time_t time, TVMContext uProc) {
    uProc.vstack = push(uProc.alloc, value(nil()), uProc.vstack);
    return 0;
}

time_t nullp(time_t time, TVMContext uProc) {
    auto args = take!1(uProc);
    swap!1(uProc, isNil(args[0]) ? value(1) : value(nil()));
    return 0;
}

time_t cons(time_t time, TVMContext uProc) {
    auto args = take!2(uProc);
    swap!2(uProc, value(pair(uProc.alloc, use(args[0]), use(args[1]))));
    return 0;
}

time_t car(time_t time, TVMContext uProc) {
    auto args = take!1(uProc);

    if(!isPointer(args[0]) || !isPair(args[0].ptr)) fail();
    auto pair = asPair(args[0].ptr);

    if(isNil(pair)) swap!1(uProc, value(nil()));
    else            swap!1(uProc, value(use(pair.car)));

    return 0;
}

time_t cdr(time_t time, TVMContext uProc) {
    auto args = take!1(uProc);

    if(!isPointer(args[0]) || isNil(args[0]) || !isPair(args[0].ptr)) fail();
    auto pair = asPair(args[0].ptr);

    if(isNil(pair)) swap!1(uProc, value(nil()));
    else            swap!1(uProc, value(use(pair.cdr)));

    return 0;
}

// Actor model:
time_t thisUProc(time_t time, TVMContext uProc) {
    uProc.vstack = push(uProc.alloc, value(use(uProc)), uProc.vstack);
    return 0;
}

time_t sendMsg(time_t time, TVMContext uProc) {
    auto args = take!2(uProc);

    if(!isPointer(args[0]) || isNil(args[0]) || !isMicroProc(args[0].ptr)) fail();

    auto otherUProc = asMicroProc(args[0].ptr);
    otherUProc.msgq.enqueue(use(args[1]));

    swap!2(uProc, use(args[1]));
    return 0;
}

time_t recvMsg(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!1(uProc)); // FIXME Should be integer.
    auto t = 1000 * cast(long) args[0].floating;

    TVMValue v;
    if(uProc.msgq.dequeue(v)) {
        swap!1(uProc, v);
        return 0;
    } else {
        swap!1(uProc, value(nil()));
        return time + t;
    }
}

// Misc:
time_t typeOf(time_t time, TVMContext uProc) {
    auto args = take!1(uProc);
    auto t = args[0].type;
    if(isPointer(args[0])) t += 1 + asObject(args[0].ptr).type;

    swap!1(uProc, value(cast(double) t)); // FIXME Should be integer.
    return 0;
}

time_t sleep(time_t time, TVMContext uProc) {
    auto args = enforce!isFloating(take!1(uProc));
    auto t = 1000 * cast(long) args[0].floating;
    // NOTE Doesn't pop the vstack on purpose.
    return time + t;
}

time_t print(time_t time, TVMContext uProc) {
    auto args = take!1(uProc);
    writeln(tvm.compiler.printer.print(args[0]));
    // NOTE Doesn't pop the vstack on purpose.
    return 0;
}

enum Primops = [tuple("+", &add, 2), tuple("-", &sub, 2), tuple("*", &mult, 2), tuple("/", &div, 2),
                tuple("mod", &mod, 2), tuple("pow", &pow, 2), tuple("inc", &inc, 1), tuple("dec", &dec, 1),
                tuple("=", &eq, 2), tuple("<", &less, 2), tuple(">", &greater, 2), tuple("<=", &leq, 2),
                tuple(">=", &geq, 2), tuple("null?", &nullp, 1), tuple("null", &mknil, 0),
                tuple("cons", &cons, 2), tuple("car", &car, 1), tuple("cdr", &cdr, 1),
                tuple("typeof", &typeOf, 1), tuple("sleep", &sleep, 1), tuple("print", &print, 1),
                tuple("self", &thisUProc, 0), tuple("send", &sendMsg, 2), tuple("recv", &recvMsg, 1)];

long primopOffset(string name) {
    /*static*/ foreach(i, primop; Primops) {
        if(primop[0] == name) return i;
    }
    return -1;
}

bool primopDefined(string name) {
    return primopOffset(name) != -1;
}

string primopName(size_t offset) {
    if(offset < Primops.length) return Primops[offset][0];
    assert(0, "Bad primop offset.");
}

TVMPrimop primopFun(size_t offset) {
    if(offset < Primops.length) return Primops[offset][1];
    assert(0, "Bad primop offset.");
}

uint primopArity(size_t offset) {
    if(offset < Primops.length) return Primops[offset][2];
    assert(0, "Bad primop offset.");
}
