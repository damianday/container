module container.dlist;

import std.traits;
import std.range.primitives;
import std.experimental.allocator;
import std.experimental.allocator.mallocator : Mallocator;
import std.stdio;

public struct DList(T, Alloc = Mallocator)
{
private:
    static struct Node
    {
        T       data;
        Node*   next;
        Node*   prev;

        this(T pData, Node* pNext = null, Node* pPrev = null)
        {
            data = pData;
            next = pNext;
            prev = pPrev;
        }
    }
    alias Node* PNode;

private:
    static if (stateSize!Alloc) Alloc _allocator;
    else alias _allocator = Alloc.instance;
    PNode _head = null;
    PNode _currNode = null;
    PNode _tail = null;
    size_t _currentPos = 0;
    size_t _counter = 0;

    /*public this(DList!T list)
    {
        for ( int nLoops = 0; nLoops < list.ListLength(); nLoops++ )
        {
            T* tempT = new T;
            tempt.data = list.Current();
            AddNode(tempT);
        }
    }*/

public:
    ~this()
    {
        this.clear();
    }

    void add(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        auto node = _allocator.make!Node(value);
        if (_tail !is null)
        {
            _tail.next  = node;
            node.next   = node;
            node.prev   = _tail;
            _tail       = _tail.next;
        }
        else
        {
            _head       = node;
            _head.prev  = _head;
            _head.next  = _head;
            _tail       = _head;
            _currNode   = _head;
        }
        _counter++;
    }

    void add(E)(E values)
        if (isInputRange!E && isImplicitlyConvertible!(ElementType!E, T))
    {
        foreach(value; values)
            add(value);
    }

    bool remove_current()
    {
        if (_currNode is null)
            return false;

        _currNode.prev.next = _currNode.next;
        _currNode.next.prev = _currNode.prev;

        auto node = _currNode;
        _currNode = _currNode.next;
        if ( node is _currNode )             // Current = Tail ?
        {
            _tail = _tail.prev;
            _currNode = _currNode.prev;
            _currNode.next = _currNode;
            _currentPos--;
            if ( _currNode is node )         // Current = Head = Tail ?
            {
                _head = null;
                _tail = null;
                _currNode = null;
                _currentPos = 0;
            }
        }
        else if (node is _head)               // Current  = Head ?
        {
            _head = node.next;
            _currNode = node.next;
            _currNode.prev = _currNode;
            if ( node is _head )          // Current = Head = Tail ?
            {
                _head = null;
                _tail = null;
                _currNode = null;
                _currentPos = 0;
            }
        }
        _allocator.dispose(node);
        _counter--;

        return true;
    }

    bool remove(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        if (_counter > 0)
        {
            move_current_to_top();
            foreach (immutable i; 0 .. _counter)
            {
                if (value is get_current_data())
                    return remove_current();
                move_next();
            }
        }

        return false;
    }

    ptrdiff_t find(E)(E value)
        if (isImplicitlyConvertible!(E, T))
    {
        ptrdiff_t index = -1;

        if (_counter > 0)
        {
            move_current_to_top();
            foreach (immutable i; 0 .. _counter)
            {
                if (value is get_current_data())
                {
                    index = i;
                    break;
                }
                move_next();
            }
        }

        return index;
    }

    size_t move_next()
    {
        if ( (_currNode !is null) && (_currNode.next !is null) )
        {
            auto node = _currNode;
            _currNode = node.next;
            _currentPos = (_currentPos<_counter) ? _currentPos+1: _counter;
        }

        return _currentPos;
    }

    size_t move_previous()
    {
        auto node = _currNode;
        _currNode = node.prev;
        _currentPos = (_currentPos>1) ? _currentPos-1: 1;

        if (_currentPos == 0)
            move_current_to_top();

        return _currentPos;
    }

    size_t move(ptrdiff_t movement)
    {
        if (movement > 0)
        {
            foreach (immutable i; 0 .. movement)
                move_next();
        }
        else
        {
            movement = (-movement);
            foreach (immutable i; 0 .. movement)
                move_previous();
        }
        return _currentPos;
    }

    size_t move_current_to_position(size_t index)
    {
        if (index > length() - 1)
            move_current_to_tail();
        else if (index <= 0)
            move_current_to_top();
        else
        {
            move(index - _currentPos);
        }

        return _currentPos;
    }

    void move_current_to_top()
    {
        _currNode = _head;
        _currentPos = 0;
    }

    void move_current_to_tail()
    {
        _currNode = _tail;
        _currentPos = _counter-1;
    }

    void clear()
    {
        if (_counter > 0)
        {
            foreach (immutable i; 0 .. _counter)
            {
                auto node = _head;
                if (node is null) break;
                _head = _head.next;
                _allocator.dispose(node);
            }
        }

        _head = null;
        _tail = null;
        _currNode = null;
        _currentPos = 0;
        _counter = 0;
    }


    ref T get_current_data()
    {
        return _currNode.data;
    }

    size_t length()
    {
        return _counter;
    }

    size_t position()
    {
        return _currentPos;
    }

    bool is_current_tail()
    {
        if (_currNode is _tail)
            return true;
        else
            return false;
    }

    bool is_current_head()
    {
        if (_currNode is _head)
            return true;
        else
            return false;
    }

    bool is_empty()
    {
        if (_head is null)
            return true;
        else
            return false;
    }

    size_t opDollar() const
    {
        return _counter;
    }

    int opApply (int delegate(ref T value) dg)
    {
        int result = 0;

        if (_counter > 0)
        {
            move_current_to_top();
            foreach (immutable i; 0 .. _counter)
            {
                result = dg (get_current_data());
                if (result != 0) break;
                move_next();
            }
        }

        return false;
    }

    int opApply (int delegate(size_t index, ref T value) dg)
    {
        int result = 0;

        if (_counter > 0)
        {
            move_current_to_top();
            foreach (immutable i; 0 .. _counter)
            {
                result = dg (i, get_current_data());
                if (result != 0) break;
                move_next();
            }
        }

        return false;
    }

    int opApplyReverse (int delegate(ref T value) dg)
    {
        int result = 0;

        if (_counter > 0)
        {
            move_current_to_tail();
            foreach (immutable i; 0 .. _counter)
            {
                result = dg (get_current_data());
                if (result != 0) break;
                move_previous();
            }
        }

        return false;
    }

    int opApplyReverse (int delegate(size_t index, ref T value) dg)
    {
        int result = 0;

        if (_counter > 0)
        {
            move_current_to_tail();
            foreach (immutable i; 0 .. _counter)
            {
                result = dg (i, get_current_data());
                if (result != 0) break;
                move_previous();
            }
        }

        return false;
    }
}


unittest
{
    // Test add
    DList!int l;
    l.add(1);
    l.add(2);
    l.add(3);

    assert(l.length() == 3);
}

unittest
{
    // Test add range
    DList!int l;
    l.add([1, 2, 3, 4, 5]);

    assert(l.length() == 5);
}

unittest
{
    // Test remove
    DList!int l;
    l.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);


    if (!l.is_empty())
    {
        l.move_current_to_top();
        foreach (immutable i; 0 .. l.length())
        {
            auto value = l.get_current_data();

            if (value == 2 || value == 8)
                l.remove_current();
            else
                l.move_next();
        }
    }

    assert(l.length() == 8);
}

unittest
{
    // Test clear
    DList!int l;
    l.add([1, 2, 3, 4]);

    assert(l.length() == 4);
    assert(l.is_empty() == false);

    l.clear();

    assert(l.length() == 0);
    assert(l.is_empty() == true);
}

unittest
{
    // Test find
    DList!int l;
    l.add([1, 2, 3, 4, 5]);

    assert(l.find(2) == 1);
    assert(l.find(4) == 3);
}

unittest
{
    // Test remove
    DList!int l;
    l.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    l.remove(2);
    l.remove(8);
    assert(l.length() == 8);

    /*if (!l.is_empty())
    {
        l.move_current_to_top();
        foreach (immutable i; 0 .. l.length())
        {
            auto value = l.get_current_data();
            writeln(value);
            l.move_next();
        }
    }*/
}

unittest
{
    // Test foreach
    DList!int l;
    l.add([1, 2, 3, 4]);

    int n = 0;
    foreach (value; l)
        n += value;
    assert(n == 10);
}

unittest
{
    // Test foreach
    DList!int l;
    l.add([1, 2, 3]);

    int n = 0;
    foreach (index, value; l)
        n += value;
    assert(n == 6);
}

unittest
{
    // Test foreach reverse
    DList!int l;
    l.add([1, 2, 3, 4]);

    int n = 0;
    foreach_reverse (value; l)
        n += value;
    assert(n == 10);
}

unittest
{
    // Test foreach reverse
    DList!int l;
    l.add([1, 2, 3]);

    int n = 0;
    foreach_reverse (index, value; l)
        n += value;
    assert(n == 6);
}
