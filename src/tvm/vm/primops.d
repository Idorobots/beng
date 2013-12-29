module tvm.vm.primops;

import std.math;
import std.typecons : tuple;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.interpreter;
import tvm.vm.gc;

alias TVMPrimop = time_t function (time_t time, TVMContext uProc);

auto take(size_t n)(TVMContext uProc) {
    TVMValue[n] args;
    foreach(i, ref arg; args) {
        arg = nth(uProc.alloc, i, uProc.vstack);
    }
    return args;
}

auto enforce(alias predicate, Ts)(Ts values) {
    /*static*/ foreach(i, val; values) {
        if(!predicate(val)) throw new RuntimeError("Type mismatch.");
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
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer + args[1].integer));
    return 0;
}

time_t sub(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer - args[1].integer));
    return 0;
}

time_t mult(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer * args[1].integer));
    return 0;
}

time_t div(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer / args[1].integer));
    return 0;
}

time_t mod(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer % args[1].integer));
    return 0;
}

time_t pow(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, value(args[0].integer ^^ args[1].integer));
    return 0;
}

time_t inc(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!1(uProc));
    // FIXME Should use coercion and integers.
    swap!1(uProc, value(args[0].integer + 1));
    return 0;
}

time_t dec(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!1(uProc));
    // FIXME Should use coercion and integers.
    swap!1(uProc, value(args[0].integer - 1));
    return 0;
}

// Logic:
time_t eq(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, args[0].integer == args[1].integer ? value(1) : value(nil()));
    return 0;
}

time_t less(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, args[0].integer < args[1].integer ? value(1) : value(nil()));
    return 0;
}

time_t greater(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, args[0].integer > args[1].integer ? value(1) : value(nil()));
    return 0;
}

time_t leq(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, args[0].integer <= args[1].integer ? value(1) : value(nil()));
    return 0;
}

time_t geq(time_t time, TVMContext uProc) {
    auto args = enforce!isInteger(take!2(uProc));
    // FIXME Should use coercion and integers.
    swap!2(uProc, args[0].integer >= args[1].integer ? value(1) : value(nil()));
    return 0;
}

// TODO null? null cons car cdr
// TODO self, recv, send, spawn, sleep
// TODO typeof equal?

enum Primops = [tuple("+", &add), tuple("-", &sub), tuple("*", &mult), tuple("/", &div),
                tuple("mod", &mod), tuple("pow", &pow), tuple("inc", &inc), tuple("dec", &dec),
                tuple("=", &eq), tuple("<", &less), tuple(">", &greater),
                tuple("<=", &leq), tuple(">=", &geq)];

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