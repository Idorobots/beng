module eval.gc.gc;

import eval.gc.memory;

void mark(ObjectHeader* that) {
    if(!that.isSticky()) {
        that.refCount = cast(ushort) (that.refCount + 1);
    }
}

void unmark(ObjectHeader* that) {
    if(!that.isSticky()) {
        that.refCount = cast(ushort) (that.refCount - 1);
    }
}

bool isMarked(ObjectHeader* that) {
    return that.refCount > 0;
}

bool isSticky(ObjectHeader* that) {
    return that.refCount == ushort.max;
}
