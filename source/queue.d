module container.queue;

import std.traits;
import std.range.primitives;
import std.algorithm;
import std.experimental.allocator;
import std.experimental.allocator.mallocator : Mallocator;

// Queue implemented over array, using wrapping.
public struct Queue(T, Alloc = Mallocator)
{
private:
    //IAllocator _allocator;
    static if (stateSize!Alloc) Alloc _allocator;
    else alias _allocator = Alloc.instance;
    size_t _head = 0;
    size_t _tail = 0;
    size_t _count = 0;
    T[] _payload = null;
    
private:
    void grow()
    {
        ptrdiff_t newCap;

        newCap = getCapacity() * 2;
        if (newCap == 0)
            newCap = 4;
        else if (newCap < 0)
            assert(0);
        setCapacity(newCap);
    }
    
    void setCapacity(size_t cap)
    {
        ptrdiff_t tailCount, offset;

        if (cap < _count)
            assert(0);

        offset = cap - getCapacity();
        if (offset == 0)
            return;
  
        // If head <= tail, then part of the queue wraps around
        // the end of the array; don't introduce a gap in the queue.
        if ((_head < _tail) || ((_head == _tail) && (_count > 0)))
            tailCount = getCapacity() - _tail;
        else
            tailCount = 0;
  
        if (offset > 0)
        {
            assert(_allocator.expandArray(_payload, offset));
        }
        if (tailCount > 0)
        {
            _payload[(_tail + offset) .. (_tail + offset) + tailCount] = _payload[_tail .. (_tail + tailCount)];
            if (offset > 0)
                initializeAll(_payload[_tail .. _tail + offset]);
            else if (offset < 0)
                initializeAll(_payload[_count .. _count + (- offset)]);

            /*memmove(_payload.ptr+(_tail + offset), _payload.ptr+_tail, tailCount * T.sizeof);
            if (offset > 0)
                memset(_payload.ptr+_tail, 0, offset * T.sizeof);
            else if (offset < 0)
                memset(_payload.ptr+_count, 0, (- offset) * T.sizeof);*/
            _tail += offset;
        }
        else if (_tail > 0)
        {
            if (_count > 0)
            {
                _payload[0 .. _count] = _payload[_tail .. (_tail + _count)];
                initializeAll(_payload[_count .. _count + _tail]);

                //memmove(_payload.ptr, _payload.ptr+_tail, _count * T.sizeof);
                //memset(_payload.ptr+_count, 0, _tail * T.sizeof);
            }
            _head -= _tail;
            _tail = 0;
        }
        if (offset < 0)
        {
            assert(_allocator.shrinkArray(_payload, - offset));
        }
    }
    
    size_t getCapacity()
    {
        return _payload.length;
    }
    
public:
    //@disable this();

    this(size_t capacity)
    {
        //_allocator = allocator;
        _head = 0;
        _tail = 0;
        _count = 0;
        _payload = _allocator.makeArray!T(capacity);
    }

    ~this()
    {
        dispose();
    }

    void dispose()
    {
        clear();
        //_allocator.dispose(_payload);
    }
    
    bool contains(T item)
    {
        auto index = _tail;
        auto qcount = _count;

        while (qcount-- > 0)
        {
            if (item is T.init)
            {
                if (_payload[index] is T.init)
                {
                    return true;
                }
            }
            else
            {
                if (_payload[index] !is T.init && (_payload[index] is item))
                {
                    return true;
                }
            }
            index = (index + 1) % getCapacity();
        }
        return false;
    }
    
    void enqueue(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        if (_count == getCapacity())
            grow();
        _payload[_head] = value;
        _head = (_head + 1) % getCapacity();
        ++_count;
    }

    void enqueue(E)(E values)
        if (isInputRange!E && isImplicitlyConvertible!(ElementType!E, T))
    {
        for (; !values.empty; values.popFront())
            enqueue(values.front);
    }
    
    T dequeue()
    {
        if (_count == 0)
            assert(0);
        T result = _payload[_tail];
        _payload[_tail] = T.init;
        _tail = (_tail + 1) % getCapacity();
        --_count;
        return result;
    }
    
    T peek()
    {
        if (_count == 0)
            assert(0);
        return _payload[_tail];
    }
    
    void clear()
    {
        while (_count > 0)
            dequeue();
        _head = 0;
        _tail = 0;
        _count = 0;

        /*static if (hasMember!(Alloc, "empty"))
        {
            if (_allocator.empty() == Ternary.no)
            {
                static if (hasMember!(Alloc, "deallocate"))
                    _allocator.deallocate(_payload);
            }
        }*/
        _allocator.deallocate(_payload);
    }
    
    void trim()
    {
        setCapacity(_count);
    }
    
    // Getter and setter
    //IAllocator allocator() { return _allocator; }
    //void allocator(IAllocator a) { /*assert(empty);*/ _allocator = a; }
    size_t length() { return _count; }
    size_t capacity() { return getCapacity(); }
    void capacity(size_t value) { setCapacity(value); }
    bool empty() { return _count == 0; }
}

unittest
{
    // Test Enqueue
    Queue!(int) q;
    q.enqueue(1);
    q.enqueue(2);
    q.enqueue(3);
    
    assert(q.length() == 3);
}

unittest
{
    // Test Enqueue range
    Queue!int q;
    q.enqueue([1, 2, 3, 4, 5]);
    
    assert(q.length() == 5);
}


unittest
{
    // Test Dequeue
    Queue!int q;
    q.enqueue([1, 2, 3]);
    
    while (q.length() > 0)
        q.dequeue();
    
    assert(q.length() == 0);
}

unittest
{
    // Test remove_all
    Queue!int q;
    q.enqueue([1, 2, 3, 4, 5]);

    q.clear();
    
    assert(q.length() == 0);
}

unittest
{
    // Test Trim
    Queue!int q;
    q.enqueue([1, 2, 3, 4, 5]);
    assert(q.capacity() >= 5);
    assert(q.length() == 5);
    
    while (q.length() > 1)
        q.dequeue();
    
    assert(q.capacity() >= 5);
    assert(q.length() == 1);

    q.trim();
    assert(q.capacity() == q.length());
}

unittest
{
    // Test contains
    Queue!int q;
    q.enqueue([1, 2, 3, 4, 5]);
    
    assert(q.contains(3) == true);
    assert(q.contains(10) == false);
}