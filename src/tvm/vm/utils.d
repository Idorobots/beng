module tvm.vm.utils;

import std.container;
import std.algorithm : min;
import core.time : TickDuration;

import lfds611;

alias size_t time_t;

class PriorityQueue(T, alias comparator = "a < b") {
    private enum allowDuplicates = true;
    private RedBlackTree!(T, comparator, allowDuplicates) impl;

    this(T[] elements...) {
        this.impl = redBlackTree!(comparator, allowDuplicates, T)(elements);
    }

    @property T next() {
        return this.impl.front;
    }

    void enqueue(T element) {
        this.impl.insert(element);
    }

    bool dequeue(ref T result) {
        if(!this.empty) {
            result = this.next;
            this.impl.removeFront();
            return true;
        }
        return false;
    }

    T dequeue() {
        T result;
        assert(this.dequeue(result), "Tried dequeueing() an empty PriorityQueue!");
        return result;
    }

    @property size_t length() {
        return this.impl.length;
    }

    @property bool empty() {
        return this.impl.empty;
    }

    auto opSlice() {
        return this.impl[];
    }
}

shared class LockFreeQueue(T) if(T.sizeof <= (void*).sizeof) {
    private lfds611_queue_state* impl;

    this(size_t size) {
        if(!lfds611_queue_new(&this.impl, size)) {
            assert(0, "Unable to create a LockFreeQueue!");
        }
    }

    this(T[] elements...) {
        this(elements.length);

        foreach(ref element; elements) {
            enqueue(element);
        }
    }

    ~this() {
        extern(C) static void rm(void*, void*) { }
        lfds611_queue_delete(this.impl, &rm, null);
    }

    void enqueue(T element) {
        lfds611_queue_use(this.impl);

        if(!lfds611_queue_guaranteed_enqueue(this.impl, *cast(void**) &element)) {
            assert(0, "Adding an element to a LockFreeQueue failed!");
        }
    }

    bool dequeue(ref T result) {
        lfds611_queue_use(this.impl);

        T tmp = void;
        if(lfds611_queue_dequeue(this.impl, cast(void**) &tmp)) {
            result = tmp;
            return true;
        }
        return false;
    }

    T dequeue() {
        assert(0, "Can't safely dequeue() elements from a LockFreeQueue!");
    }

    @property T next() {
        assert(0, "The next() operation is not supported by LockFreeQueue!");
    }

    @property bool empty() {
        assert(0, "The empty() operation is not supported by LockFreeQueue!");
    }

    @property size_t length() {
        assert(0, "The length() operation is not supported by LockFreeQueue!");
    }

    auto opSlice() {
        assert(0, "The slice() operation is not supported by LockFreeQueue!");
    }
}

time_t currentTime() {
    return TickDuration.currSystemTick().to!("usecs", time_t);
}

time_t deltaTime(time_t t1, time_t t2) {
    return (t2 > t1) ? (t2 - t1) : 0;
}
