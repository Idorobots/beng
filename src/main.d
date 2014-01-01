module main;

import std.stdio;
import std.file : readText;
import std.typecons;
import std.getopt : getopt;
import std.c.stdlib : exit;
import std.algorithm : max;
import std.concurrency;
import std.random : uniform;
import std.traits : EnumMembers;
import std.typecons : Tuple;
import std.typetuple : TypeTuple;
import core.memory;

import tvm.tvm;

void handle(string name, string source, SyntaxError e) {
    auto token = e.token;
    auto preamble = format("%s(%d, %d): ", name, token.line+1, token.column);

    writeln(preamble, "Syntax Error: ", e.msg, "\n");

    foreach(i; 0 .. preamble.length) write(" ");
    foreach(i; 0 .. source.length - token.offset - token.column) {
        if((token.offset - token.column + i) >= source.length) break;
        auto c = source[token.offset - token.column + i];
        if(c == '\n') break;
        write(c);
    }
    write("\n");

    foreach(i; 0 .. preamble.length + token.column)
        write(" ");
    write("^");

    if(token.value.length > 0)
        foreach(i; 0 .. token.value.length - 1)
            write("~");
    writeln("\n");
}

void handle(string name, string source, SemanticError e) {
    writeln(name, ": Semantic Error: ", e.msg);

    debug(verbose) {
        writeln(e.info);
    }
}

void handle(string name, string source, RuntimeError e) {
    writeln(name, ": Runtime Error: ", e.msg);

    debug(verbose) {
        writeln(e.info);
    }
}

void main(string[] args) {
    enum VM_VERSION = "v.0.1.0";
    enum Debug {scan, filter, parse, transform, optimize, objects, compile, interpret, run,}
    Debug debugVM = Debug.run;

    // Default VM configuration:
    TVMConfig config;
    config.smpNum = 4;
    config.smpMSGqSize = 16;
    config.smpPreemptionTime = 100_000;    // 100 ms
    config.smpSpinTime = 10_000;           // 10 ms
    config.smpSleepTime = 1_000_000_000;   // 1000 seconds
    config.uProcHeapSize = 0;              // FIXME Currently a bug prevents non-zero values.
    config.uProcMSGqSize = 8;
    config.uProcDefaultPriority = (TVMMicroProc.PRIORITY_MASK + 1) / 2;

    // HERE BE DRAGONS
    auto opt = [
        tuple("-n --smp-num=NUM",                    // Option syntax.
              "The number of SMP threads to run.",   // Option description.
              tuple(1UL, 256UL, config.smpNum),      // Accepted range, default value.
              &config.smpNum),                       // Pointer to the config.
        tuple("-m --smp-msgq-size=SIZE",
              "The size in messages of the pre-allocated SMP message queue.",
              tuple(1UL, 65535UL, config.smpMSGqSize),
              &config.smpMSGqSize),
        tuple("   --smp-max-preeption-time=TIME",
              "The maximal uProc preeption time in microseconds. This will be normalized by the number of uProcs ready to run.",
              tuple(10_000UL, 1_000_000UL, config.smpPreemptionTime),
              &config.smpPreemptionTime),
        tuple("   --smp-spin-time=TIME",
              "The SMP spin-wait time in microseconds.",
              tuple(1_000UL, 1_000_000UL, config.smpSpinTime),
              &config.smpSpinTime),
        tuple("   --smp-sleep-time=TIME",
              "The SMP sleep time in microseconds when no work is scheduled.",
              tuple(1_000UL, 1_000_000_000UL, config.smpSleepTime),
              &config.smpSleepTime),
        tuple("-M --uproc-msgq-size=SIZE",
              "The size in messages of the pre-allocated uProc message queue.",
              tuple(1UL, 65535UL, config.uProcMSGqSize),
              &config.uProcMSGqSize),
        tuple("-H --uproc-heap-chunk=SIZE",
              "The size in words of a heap chunk pre-allocated for a uProc.",
              tuple(0UL, 262144UL, config.uProcHeapSize),
              &config.uProcHeapSize),
        tuple("-P --uproc-default-priority=LEVEL",
              "The default priority level of a spawned user uProc.",
              tuple(0UL, cast(size_t) TVMMicroProc.PRIORITY_MASK, config.uProcDefaultPriority),
              &config.uProcDefaultPriority),
        tuple("   --debug=OPTION",
              "Toggles various debuging options. Available options: [scan, filter, parse, transform, optimize, objects, compile, interpret, run], default value: run.",
              tuple(0UL, 0UL, 0UL),
              cast(time_t*) null),
        tuple("-v --version",
              "Print the version number of this release.",
              tuple(0UL, 0UL, 0UL),
              cast(time_t*) null),
        tuple("-h --help",
              "Print this message.",
              tuple(0UL, 0UL, 0UL),
              cast(time_t*) null)];

    void checkConfig() {
        void assertInRange(T)(T field, Tuple!(T, T, T) range) {
            if(field < range[0] || field > range[1]) throw new Exception("");
        }

        foreach(option; opt) {
            auto ptr = option[3];
            auto range = option[2];

            if(ptr !is null) {
                assertInRange(*ptr, range);
            }
        }
    }

    void versionNum(string ver) {
        writeln(VM_VERSION);
        exit(0);
    }

    void usage(string help) {
        writeln("ThesisVM (TVM) ", VM_VERSION);
        writeln("Licensed under the MIT license. See LICENSE for details.");
        writeln("Copyright (C) 2013 Kajetan Rzepecki <kajtek@idorobots.org>");
        writeln();

        writeln("USAGE: ", args[0], " [OPTIONS] file.tvmir");
        writeln();

        size_t size = 0;
        foreach(vals; opt) {
            auto option = vals[0];
            size = max(size, option.length);
        }

        writeln("OPTIONS:");
        foreach(vals; opt) {
            auto option = vals[0];
            auto meaning = vals[1];
            auto range = vals[2];

            writef(format("%%-%ds %%s", size), option, meaning);
            if(range[0] != range[1]) {
                writefln(" Accepted value range: [%s, %s], default value: %s.",
                         range[0], range[1], range[2]);
            } else {
                writeln();
            }
        }

        exit(0);
    }

    try {
        // FIXME Use opt[] somehow.
        getopt(
            args,
            // SMP related:
            "smp-num|n", &config.smpNum,
            "smp-msgq-size|m", &config.smpMSGqSize,
            "smp-max-preeption-time", &config.smpPreemptionTime,
            "smp-spin-time", &config.smpSpinTime,
            "smp-sleep-time", &config.smpSleepTime,

            // uProc related:
            "uproc-msgq-size|M", &config.uProcMSGqSize,
            "uproc-heap-size|H", &config.uProcHeapSize,
            "uproc-default-priority|P", &config.uProcDefaultPriority,

            // Other:
            "debug", &debugVM,
            "version|v", &versionNum,
            "help|h", &usage
               );

        checkConfig();
    } catch (Exception e) {
        usage("");
    }

    // Read & compile the source files.
    if(args.length < 2) {
        usage("");
    }

    string file;
    string source = "
# Arithmetic:
(define (+ a b) (primop + a b))
(define (- a b) (primop - a b))
(define (* a b) (primop * a b))
(define (/ a b) (primop / a b))
(define (mod a b) (primop mod a b))
(define (pow a b) (primop pow a b))
(define (inc n) (primop inc n))
(define (dec n) (primop dec n))

# Logic:
(define (= a b) (primop = a b))
(define (< a b) (primop < a b))
(define (> a b) (primop > a b))
(define (>= a b) (primop >= a b))
(define (<= a b) (primop <= a b))
(define (not a) (if (null? a) 1 ()))
(define (and a b) (if a (if b b ()) ()))
(define (or a b) (if a a (if b b ())))

# List operations:
(define (null) (primop null))
(define (null? p) (primop null? p))
(define (car p) (primop car p))
(define (cdr p) (primop cdr p))
(define (cons a b) (primop cons a b))

# Actor model:
(define (self) (primop self))
(define (send uproc msg) (primop send uproc msg))
(define (recv timeout) (primop recv timeout))

# Utils:
(define (print what) (primop print what))
(define (sleep time) (primop sleep time))
(define (typeof what) (primop typeof what))";

    try {
        file = args[1];
        source ~= readText(file);

        final switch(debugVM) {
            case Debug.scan:
                foreach(token; scan(source)) {
                    writeln(token);
                }
                break;

            case Debug.filter:
                foreach(token; filter(scan(source))) {
                    writeln(token);
                }
                break;

            case Debug.parse:
                foreach(expr; parse(filter(scan(source)))) {
                    writeln(expr);
                }
                break;

            case Debug.transform:
                foreach(expr; transform(parse(filter(scan(source))))) {
                    writeln(expr);
                }
                break;

            case Debug.optimize:
                foreach(expr; optimize(transform(parse(filter(scan(source)))))) {
                    writeln(expr);
                }
                break;

            case Debug.objects:
                /*static*/ foreach(T; TypeTuple!(void*, TVMValue, TVMObject, TVMSymbol,
                                                 TVMPair, TVMClosure, TVMMicroProc))
                {
                    writeln(T.stringof, ".sizeof = ", T.sizeof, ",");
                }
                writeln();

                auto lst = list(GCAllocator.it, value(1), value(2), value(3));
                auto pr = pair(GCAllocator.it, value(use(lst)), value(use(lst)));
                auto lambda = closure(GCAllocator.it, value(pr), value(lst));
                free(GCAllocator.it, lst);

                writeln(print(lambda));
                break;

            case Debug.compile:
                auto namesEnv = compile(GCAllocator.it,
                                        optimize(transform(parse(filter(scan(source))))));
                auto names = namesEnv[0];
                auto env = namesEnv[1];

                foreach(name; names) {
                    TVMValue closure = asPair(env).car;
                    TVMValue rest = asPair(env).cdr;
                    env = rest.ptr;
                    writeln(name, ": ", print(closure));
                }
                break;
            case Debug.interpret:
                auto t = currentTime();
                auto uProc = new shared TVMMicroProc(config.uProcHeapSize,
                                                     config.uProcMSGqSize,
                                                     cast(ubyte) config.uProcDefaultPriority,
                                                     t);
                auto a = uProc.alloc;

                // Compile the source code...
                auto namesEnv = compile(a, optimize(transform(parse(filter(scan(source))))));
                auto names = namesEnv[0];
                auto env = namesEnv[1];

                // ...remember to pass some args to the boot code.
                auto argList = value(nil());
                foreach(arg; args) {
                    argList = value(pair(a, value(symbol(a, arg)), argList));
                }

                auto cont = closure(a, value(list(a, value(push(a, argList)))), value(env));
                auto halt = closure(a, value(list(a, value(halt(a)))), value(env));

                uProc.code = list(a, value(enter(arg(), a, assoc("main", names))));
                uProc.env = env;
                uProc.stack = list(a, value(cont), value(halt));

                // So we don't run into many problems...
                config.smpNum = 1;
                register("SMP0", thisTid);

                for(;;) {
                    writeln("step: ", step(currentTime(), uProc, config));
                    readln();
                }

            case Debug.run:
                // Create a root uProc...
                auto t = currentTime();
                auto uProc = new shared TVMMicroProc(config.uProcHeapSize,
                                                     config.uProcMSGqSize,
                                                     cast(ubyte) config.uProcDefaultPriority,
                                                     t);
                auto a = uProc.alloc;

                // Compile the source code...
                auto namesEnv = compile(a, optimize(transform(parse(filter(scan(source))))));
                auto names = namesEnv[0];
                auto env = namesEnv[1];

                // ...remember to pass some args to the boot code.
                auto argList = value(nil());
                foreach(arg; args) {
                    argList = value(pair(a, value(symbol(a, arg)), argList));
                }

                auto cont = closure(a, value(list(a, value(push(a, argList)))), value(env));
                auto halt = closure(a, value(list(a, value(halt(a)))), value(env));

                uProc.code = list(a, value(enter(arg(), a, assoc("main", names))));
                uProc.env = env;
                uProc.stack = list(a, value(cont), value(halt));

                // Spawn the SMPs...
                for(uint i = 1; i < config.smpNum; ++i) {
                    spawn(&schedule, format("SMP%d", i), config);
                }

                // Execute the process
                send(thisTid, asMicroProc(use(uProc)));
                schedule("SMP0", config);
                break;
        }
    } catch (SyntaxError e) {
        handle(file, source, e);
    } catch (SemanticError e) {
        handle(file, source, e);
    } catch (RuntimeError e) {
        handle(file, source, e);
    } catch (Exception e) {
        writeln(e.msg);

       debug(verbose) {
            writeln(e.info);
        }
    }
}