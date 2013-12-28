module tvm.vm.scheduler;

import std.concurrency;
import core.time : dur;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.allocator;
import tvm.vm.interpreter;

struct TVMConfig {
    // NOTE Ranges are checked on startup.
    size_t smpNum;
    size_t smpMSGqSize;
    time_t smpPreemptionTime;
    time_t smpSpinTime;
    time_t smpSleepTime;
    size_t uProcHeapSize;
    size_t uProcMSGqSize;
    size_t uProcDefaultPriority;
}

bool procScheduler(T)(T a, T b) {
    return a.vRunTime < b.vRunTime;
}

bool waitScheduler(T)(T a, T b) {
    return a.wakeTime < b.wakeTime;
}

void schedule(string name, TVMConfig config) {
    register(name, thisTid);
    setMaxMailboxSize(thisTid, config.smpMSGqSize, OnCrowding.throwException);

    // The RUNq.
    auto RUNq = new PriorityQueue!(TVMContext, procScheduler!TVMContext)();
    // The WAITq.
    auto WAITq = new PriorityQueue!(TVMContext, waitScheduler!TVMContext)();
    // The lower bound of VTime.
    time_t minVRunTime = 0;

    time_t dispatchWAITq(time_t dt = 0) {
        debug(verbose) {
            import std.stdio;
            writeln(currentTime(), " ", name, " dispatching WAITq for ", dt, " us...");
        }

        auto currTime = currentTime();
        auto finishTime = currTime + dt;
        time_t sleepFor = config.smpSleepTime; // We assume there won't be any work to do.

        do {
            // Nothing more to do so we either gonna wait for a bit
            // or execute the newly scheduled uProcs.
            if(WAITq.empty) return sleepFor;

            auto wakeTime = WAITq.next.wakeTime;
            currTime = currentTime();

            if(currTime >= wakeTime) {
                // We add the next uProc to the run queue & make sure it won't clog the SMP.
                auto uProc = WAITq.dequeue();
                uProc.vRunTime = minVRunTime;
                RUNq.enqueue(uProc);

                // We also make sure to start running the newly scheduled uProcs right away.
                sleepFor = 0;
            } else if(wakeTime >= finishTime) {
                // We determined that we can safely wait for the next uProc
                // so it's not worth spin-waiting here.
                return min(sleepFor, deltaTime(currTime, wakeTime));
            }
        } while(currTime < finishTime);

        return 0;
    }

    time_t dispatchMSGq(time_t dt = 0) {
        debug(verbose) {
            import std.stdio;
            writeln(currentTime(), " ", name, " dispatching MSGq for ", dt, " us...");
        }

        auto startTime = currentTime();
        auto finishTime = startTime + dt;

        if(receiveTimeout(dur!"usecs"(dt),
                          // FIXME Actually implement these.
                          (TVMContext p) {
                              debug(verbose) {
                                  import std.stdio;
                                  writeln(currentTime(), " ", name, " spawned a process...");
                              }

                              WAITq.enqueue(p);
                          }))
        {
            // Could possibly wait a bit longer...
            return deltaTime(currentTime(), finishTime);
        } else {
            // Finished waiting.
            return 0;
        }
    }

    for(;;) {
        if(RUNq.empty) {
            // No immediate work to be done so we'll spin for a while
            // and try to determine when some uProcs will wake up.
            dispatchMSGq(dispatchWAITq(config.smpSpinTime));
        } else {
            // A fair share of SMP time for the next uProc is the preeption time
            // normalized by the number of ready uProcs.
            auto fairShare = config.smpPreemptionTime / RUNq.length;
            auto uProc = RUNq.dequeue();

            debug(verbose) {
                import std.stdio;
                writeln(currentTime(), " ", name, " running uProc #",
                        uProc.priority, " for ", fairShare, " us...");
            }

            time_t wakeTime = 0;
            auto startTime = currentTime();
            auto currTime = startTime;
            auto finishTime = startTime + fairShare;
            size_t steps = 0;

            do {
                currTime = currentTime();

                // Execute the uProc.
                wakeTime = step(currTime, uProc);
                ++steps;

                // Stop executing the uProc if a sleep has been requested.
            } while(wakeTime == 0 && currTime < finishTime);

            auto finalTime = currentTime();
            debug(verbose) {
                import std.stdio;
                writeln(currentTime(), " ", name, " executed ", steps,
                        " steps of uProc #", uProc.priority, "...");
            }

            // Runtime is incremented by the fair share of this uProc.
            uProc.runtime += deltaTime(startTime, finalTime);

            // The new minVRunTime ensures that any newly added uProcs execute
            // shortly after currently leftmost uProcs.
            minVRunTime = uProc.vRunTime;

            switch(wakeTime) {
                case 0:
                    // uProc is still ready to execute.
                    RUNq.enqueue(uProc);
                    break;

                case TVMMicroProc.MAX_SLEEP_TIME:
                    // FIXME uProc is sleeping indefinitely and may get GCed later.
                    uProc.wakeTime = wakeTime;
                    WAITq.enqueue(uProc);
                    break;

                default:
                    // uProc requested to sleep for a certain ammount of time.
                    uProc.wakeTime = wakeTime;
                    WAITq.enqueue(uProc);
            }
        }

        debug(verbose) {
            import std.stdio;
            import tvm.compiler.printer;

            write(currentTime(), " ", name, " RUNq:  ", RUNq.length, " - ");
            foreach(uProc; RUNq[]) {
                write(toString(uProc), ", ");
            }
            writeln();

            write(currentTime(), " ", name, " WAITq: ", WAITq.length, " - ");
            foreach(uProc; WAITq[]) {
                write(toString(uProc), ", ");
            }
            writeln();
        }

        // Ensure all uProcs are awake & all messages are processed for the next iteration.
        dispatchWAITq();
        dispatchMSGq();
    }
}
