module container.vector;

import core.stdc.string;
import std.traits;
import std.range.primitives;
import std.algorithm;
import std.experimental.allocator;
import std.experimental.allocator.mallocator : Mallocator;
import std.stdio;



public struct Vector(T, Alloc = Mallocator)
{
private:
    static if (stateSize!Alloc) Alloc _allocator;
    else alias _allocator = Alloc.instance;
    T[] _payload = null;
    size_t _count = 0;

private:
    size_t getCapacity()
    {
        return _payload.length;
    }
    
    void setCapacity(size_t cap)
    {
        ptrdiff_t offset = cap - getCapacity();
        if (offset == 0)
            return;

        if (cap < _count)
            _count = cap;

        if (offset > 0)
            assert(_allocator.expandArray(_payload, offset));
        else
            assert(_allocator.shrinkArray(_payload, -offset));
    }
    
    void setCount(size_t ACount)
    {
        if (ACount < 0)
            assert(0);
        if (ACount > getCapacity())
            setCapacity(ACount);
        if (ACount < _count)
            deleteAt(ACount, _count - ACount);
        _count = ACount;
    }
    
    void grow(size_t howMuch)
    {
        if (howMuch > getCapacity())
        {
            ptrdiff_t newCount = getCapacity();
            if (newCount == 0)
                newCount = howMuch;
            else
            {
                do
                {
                    newCount = newCount * 2;
                    if (newCount < 0)
                        assert(0);
                } while (newCount < howMuch);
            }
            setCapacity(newCount);
        }
    }
    

public:
    this(size_t capacity)
    {
        this._count = 0;
        this._payload = _allocator.makeArray!T(capacity);
    }
    
    ~this()
    {
        this.clear();
        _allocator.dispose(_payload);
    }
    
    size_t add(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        grow(_count + 1);
        immutable index = _count;
        _payload[_count] = value;
        ++_count;
        return index;
    }

    alias add addBack;
    
    void add(E)(E values)
        if (isInputRange!E && isImplicitlyConvertible!(ElementType!E, T))
    {
        insertAt(_count, values);
    }
    
    size_t addFirst(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        immutable index = _count;
        insertAt(0, value);
        return index;
    }
    
    void insertAt(E)(size_t index, E value)
        if (isImplicitlyConvertible!(E, T))
    {
        if ((index < 0) || (index > _count))
            assert(0);

        grow(_count + 1);
        if (index != _count)
        {
            memmove(_payload.ptr+(index + 1), _payload.ptr+index, (_count - index) * T.sizeof);
            //memset(_payload.ptr+index, 0, T.sizeof);
            _payload[index] = T.init;
        }
        _payload[index] = value;
        _count++;
    }
    
    void insertAt(E)(size_t index, E values)
        if (isInputRange!E && isImplicitlyConvertible!(ElementType!E, T))
    {
        if ((index < 0) || (index > _count))
            assert(0);

        grow(_count + values.length);
        if (index != _count)
        {
            memmove(_payload.ptr+(index + values.length), _payload.ptr+index, (_count - index) * T.sizeof);
            initializeAll(_payload[index .. index + values.length]);
        }

        values.copy(_payload[index .. index + values.length]);

        _count += values.length;
    }
    
    ptrdiff_t remove(T value)
    {
        auto index = indexOf(value);
        if (index >= 0)
            deleteAt(index);
        return index;
    }
    
    void deleteAt(size_t index)
    {
        if ((index < 0) || (index >= _count))
            assert(0);
        T oldItem = _payload[index];
        _payload[index] = T.init;
        --_count;
        if (index != _count)
        {
            memmove(_payload.ptr+index, _payload.ptr+(index + 1), (_count - index) * T.sizeof);
            _payload[_count] = T.init;
        }
    }
    
    void deleteAt(size_t index, int ACount)
    {
        //T[] oldItems;
        ptrdiff_t tailCount;

        if (ACount == 0)
            return;
        
        if ((index < 0) || (ACount < 0) || (index + ACount > _count)
            || (index + ACount < 0))
            assert(0);
        
        //oldItems.length = ACount;
        //memmove(oldItems.ptr, _payload.ptr+index, ACount * T.sizeof);

        tailCount = _count - (index + ACount);
        if (tailCount > 0)
        {
            memmove(_payload.ptr+index, _payload.ptr+(index + ACount), tailCount * T.sizeof);
            initializeAll(_payload[(_count - ACount) .. (_count - ACount) + ACount]);
        }
        else
        {
            initializeAll(_payload[index .. index + ACount]);
        }
        _count -= ACount;
    }
    
    T extract(T value)
    {
        immutable index = indexOf(value);
        T result;
        if (index < 0)
            result = T.init;
        else
        {
            result = _payload[index];
            deleteAt(index);
        }
        
        return result;
    }

    void exchange(size_t lhs, size_t rhs)
    {
        swap(_payload[lhs], _payload[rhs]);
    }
    
    void move(size_t current, size_t new_index)
    {
        if (current == new_index)
            return;
        if ((new_index < 0) || (new_index >= _count))
            assert(0);

        swap(_payload[current], _payload[new_index]);
    }

    T front()
    {
        return _payload[0];
    }
    
    T back()
    {
        return _payload[_count - 1];
    }
    
    void clear()
    {
        _count = 0;
        setCapacity(0);

        /*if (_allocator.empty() == Ternary.no)
        {
            static if (hasMember!(IAllocator, "deallocate"))
                _allocator.deallocate(_payload);
        }*/
        _allocator.deallocate(_payload);
    }

    bool contains(T value)
    {
        return indexOf(value) >= 0;
    }
    
    ptrdiff_t indexOf(T value)
    {
        foreach (immutable index; 0 .. _count)
            if (_payload[index] is value)
                return index;
        return -1;
    }
    
    ptrdiff_t lastIndexOf(T value)
    {
        foreach_reverse (immutable index; 0 .. _count)
            if (_payload[index] is value)
                return index;
        return -1;
    }
    
    void reverse(size_t index, size_t ACount)
    {
        if ((index < 0) || (ACount < 0) || (_count - index < ACount))
            assert(0);

        size_t start = index;
        size_t end = ACount - 1;
        while (start < end)
        {
            swap(_payload[start], _payload[end]);
            ++start;
            --end;
        }
    }
    
    void reverse()
    {
        reverse(0, _count);
    }

    void trimExcess()
    {
        setCapacity(_count);
    }

    size_t opDollar() const
    {
        return _count;
    }

    T opIndex(size_t index)
    {
        if ((index < 0) || (index >= _count))
            assert(0);
        return _payload[index];
    }
    
    void opIndexAssign(T value, size_t index)
    {
        if ((index < 0) || (index >= _count))
            assert(0);

        _payload[index] = value;
    }

    T[] opSlice()
    {
        return _payload[0 .. _count];
    }

    T[] opSlice(size_t x, size_t y)
    {
        return _payload[x .. y];
    }
        
    int opApply (int delegate(ref size_t index, ref T value) dg)
    {
        int result = 0;
        size_t n = 0;
        while (true)
        {
            if (n >= _count) break;
            result = dg (n, _payload[n]);
            if (result != 0) break;
            ++n;
        }
        return result;
    }
    
    int opApply (int delegate(ref T value) dg)
    {
        int result = 0;
        size_t n = 0;
        while (true)
        {
            if (n >= _count) break;
            result = dg (_payload[n]);
            if (result != 0) break;
            ++n;
        }
        return result;
    }

    // Getter and setter
    size_t count() { return _count; }
    void count(size_t value) { setCount(value); }
    size_t capacity() { return getCapacity(); }
    void capacity(size_t value) { setCapacity(value); }
    bool empty() { return _count == 0; }
}

unittest
{
    // Test add
    Vector!int list;
    list.add(1);
    list.add(2);
    list.add(3);
    
    assert(list.count() == 3);
    assert(list[] == [1, 2, 3]);
}

unittest
{
    // Test AddRange
    Vector!int list;
    list.add([1, 2, 3, 4, 5]);
    
    assert(list.count() == 5);
    assert(list[] == [1, 2, 3, 4, 5]);
}

unittest
{
    // Test Insert
    Vector!int list;
    list.add([1, 2, 3]);

    assert(list.count() == 3);
    assert(list[] == [1, 2, 3]);
    
    list.insertAt(0, 99);
    assert(list.count() == 4);
    assert(list[] == [99, 1, 2, 3]);

    
    list.insertAt(0, 50);
    assert(list[0] == 50);
    
    list.insertAt(list.count(), 100);
    assert(list[list.count()-1] == 100);
}

unittest
{
    // Test Insert
    Vector!int list;
    list.insertAt(0, 99);
    
    assert(list[0] == 99);
}

unittest
{
    // Test Insert
    Vector!int list;
    list.add([1, 2, 3]);
    list.insertAt(0, [4, 5, 6]);
    
    assert(list[0] == 4, "Vector InsertRange wrong 1");
    assert(list[1] == 5, "Vector InsertRange wrong 2");
    assert(list[2] == 6, "Vector InsertRange wrong 3");
}

unittest
{
    // Test Clear
    Vector!int list;
    list.add([1, 2, 3]);
    list.clear();
    
    assert(list.count() == 0);
}

unittest
{
    // Test Delete
    Vector!int list;
    list.add([1, 2, 3]);
    list.deleteAt(1);
    
    assert(list.count() == 2);
    assert(list.front() == 1);
    assert(list.back() == 3);
}

unittest
{
    // Test Remove
    Vector!int list;
    list.add([100, 500, 300]);
    list.remove(500);
    
    assert(list.count() == 2, "Vector Remove wrong count");
    assert(list.front() == 100, "Vector First wrong");
    assert(list.back() == 300, "Vector Last wrong");
}

unittest
{
    // Test DeleteRange
    Vector!int list;
    list.add([1, 2, 3, 4, 5, 6]);
    list.deleteAt(1, 4);
    
    assert(list.count() == 2, "Vector DeleteRange wrong count");
    assert(list.front() == 1, "Vector First wrong");
    assert(list.back() == 6, "Vector Last wrong");
}

unittest
{
    // Test Reverse
    Vector!int list;
    list.add([1, 2, 3]);
    
    list.reverse();
    
    assert(list[] == [3, 2, 1]);
}

unittest
{
    // Test First, Last
    Vector!int list;
    list.add([1, 2, 3]);
    
    assert(list.front() == 1);
    assert(list.back() == 3);
}

unittest
{
    // Test Contains
    Vector!int list;
    list.add([1, 2, 3]);
    
    bool found1 = list.contains(2);
    bool found2 = list.contains(5);
    
    assert(found1 == true);
    assert(found2 == false);
}

unittest
{
    // Test IndexOf, LastIndexOf
    Vector!int list;
    list.add([1, 2, 3, 4, 5, 5, 6]);
    
    int index1 = list.indexOf(5);
    int index2 = list.lastIndexOf(5);
    
    assert(index1 == 4);
    assert(index2 == 5);
}

unittest
{
    // Test TrimExcess
    Vector!int list;
    list.setCapacity(50);
    
    assert(list.count() != list.capacity());
    
    list.trimExcess();
    
    assert(list.count() == list.capacity());
}