module main;

import std.stdio;
import std.file : readText;
import std.typecons;
import std.getopt : getopt;
import std.c.stdlib : exit;
import std.algorithm : max;
import std.concurrency;
import std.random : uniform;

import tvm.tvm;

void handle(string name, string source, SyntaxError e) {
    auto token = e.token;
    auto preamble = format("%s(%d, %d): ", name, token.line+1, token.column);

    writeln(preamble, "Syntax Error: ", e.msg, "\n");

    foreach(i; 0 .. preamble.length) write(" ");
    foreach(i; 0 .. source.length - token.offset - token.column) {
        auto c = source[token.offset - token.column + i];
        write(c);
        if(c == '\n') break;
    }

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
}

void main(string[] args) {
    enum VM_VERSION = "v.0.1.0";

    enum Debug {scan, parse, sema, codegen, run}
    Debug debugVM = Debug.run;

    // Default VM configuration:
    TVMConfig config;
    config.smpNum = 4;
    config.smpMSGqSize = 16;
    config.smpPreemptionTime = 100_000;    // 100 ms
    config.smpSpinTime = 10_000;           // 10 ms
    config.smpSleepTime = 1_000_000_000;   // 1000 seconds
    config.uProcHeapSize = 256;
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
              tuple(1UL, 262144UL, config.uProcHeapSize),
              &config.uProcHeapSize),
        tuple("-P --uproc-default-priority=LEVEL",
              "The default priority level of a spawned user uProc.",
              tuple(0UL, cast(size_t) TVMMicroProc.PRIORITY_MASK, config.uProcDefaultPriority),
              &config.uProcDefaultPriority),
        tuple("   --debug=OPTION",
              "Toggles various debuging options. Available options: scan, parse, sema, codegen, run, default value: run.",
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

            writef(format("%%-%ds %%s", size),
                   option, meaning);
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
    string source;

    try {
        file = args[1];
        source = readText(file);

        final switch(debugVM) {
            case Debug.scan:
                foreach(token; Scanner(source)) {
                    writeln(token);
                }
                break;

            case Debug.parse:
                foreach(expr; parse(source)) {
                    writeln(expr);
                }
                break;

            case Debug.sema:
                assert(0, "Implement this already :(");

            case Debug.codegen:
                assert(0, "Implement this already :(");

            case Debug.run:
                // TODO Compile the source and send (main) to thisTid.

                auto smps = [thisTid];

                // Spawn the SMPs & run the program.
                for(uint i = 1; i < config.smpNum; ++i) {
                    smps ~= spawn(&schedule, format("SMP%d", i), config);
                }

                TVMContext first = null;

                for(uint i = 0; i < 10; ++i) {
                    auto t = currentTime();
                    auto header = TVMObject(i);
                    auto nil = cast(TVMPointer) null;
                    auto alloc = new shared TVMAllocator!GCAllocator(config.uProcHeapSize);
                    auto msgq = new shared LockFreeQueue!TVMValue(config.uProcMSGqSize);

                    auto uProc = new shared TVMMicroProc(header,           // header
                                                         nil,              // code
                                                         nil,              // stack
                                                         nil,              // env
                                                         nil,              // vstack
                                                         alloc,            // alloc
                                                         msgq,             // msgq
                                                         i % 63 + 1,       // flags
                                                         t + i * 100_000); // runtime
                    if(first is null) {
                        first = uProc;
                    } else {
                        TVMValue v = void;
                        v.rawPtr = cast(TVMPointer) uProc;
                        first.msgq.enqueue(v);
                    }

                    send(smps[uniform(0, config.smpNum)], uProc);
                }

                schedule("SMP0", config);
                break;
        }
    } catch (SyntaxError e) {
        handle(file, source, e);
    } catch (SemanticError e) {
        handle(file, source, e);
    } catch (Exception e) {
        writeln(e.msg);
    }
}