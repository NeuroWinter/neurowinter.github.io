---
layout: post
category: python
title: "Mastering Python 3.8: Positional-Only Arguments Explained"
heading: Python3.8 Positional-only arguments
description: A overview and look at use cases for Positional-only arguments introduced in Python3.8
---

## Introduction

I have always been of the mind that explicit is much better than implicit. For
this reason, I have almost always included Python's keyword-only arguments when
defining a function.


My reasoning behind this is I feel that I should always know what I am passing
into a function and how it’s intended to be used. Below is an example:

```python

def divide(*, numerator: int, denominator: int) -> float:
    """
    Divide numerator by denominator, return float.
    """
    return numerator/denominator

```


In this example, you **must** define which parameter use named keyword
arguments, eg `divide(numerator=100, denominator=50)`. If you try calling the
function without doing this eg `divide(100,50)`, you will get the following
error: `TypeError: divide() takes 0 positional arguments but 2 were given`.
This forces the user to be explicit.


However, this is only a good strategy when your variable names carry meaning
like in the division example. Not all variables do carry important information.
However, we can see this in many built-in python functions for example, `len`.
The name of the variable in len's definition is `obj`. This makes perfect
sense since we are trying to find the length of an object. Because this is
implicit and well-known knowledge, it would be silly to force a user to pass in
`obj` when calling `len`.


Now you could say, in the case of functions like `len`, let's just not
include the keyword-only argument. Doing so means that the user does not
**have** to define it as a keyword, but a user still can. Giving a user the
ability to do this can have some detrimental effects. It means that users can
call the function in two different ways, either `len(list_object)` or
`len(obj=list_object)`. Why not be explicit in how you want your function
to be called?


This is where Python3.8's Positional-only argument comes in! As a part of [PEP
570](https://www.python.org/dev/peps/pep-0570/) the `/` argument. This argument
will force all arguments preceding it, to be positional only, meaning that the
user **must** provide them as positional arguments and not give them as
keyword arguments.


## Trivia on the `/` character
It is important to remember that it is *all elements preceding the /*


Interesting bit of trivia on the choice of the `/` character:

> Alternative proposal: how about using '/' ? It's kind of the opposite of '*'
> which means "keyword argument", and '/' is not a new character.
[Guido van Rossum in 2012](https://mail.python.org/pipermail/python-ideas/2012-March/014364.html)

## Example function using positional-only arguments

With this new tool in our tool belt, we can define functions like this:

```python
def add_ints(a: int, b: int, /) -> int:
    """
    Add the two passed in ints and return the result.
    """
    return a+b
```

With the function defined above, you can only call it like this: `add_ints(1,5)`
and not like this: `add_ints(a=1, b=5)`. If you call it like the latter way, you
will get the following error:
`TypeError: add_ints() got some positional-only arguments passed as keyword arguments: 'a, b'`

## Combining positional-only arguments with keyword-only arguments

You can also use this in conjunction with the keyword-only argument for even
more explicit goodness. But doing so will complicate the API into the function;
forcing the user to pass in different arguments in different ways would be
very frustrating.

The power of the positional only shows itself when you are defining functions
that are used regularly with a small argument list. We looked at the `len`
example above, which is the perfect example of where the positional
only argument should be used. The goal is to reduce the effort required
to parse the code mentally.  If you see `"foo1bar".split(sep="1")` that takes a
little longer to read than `"foo1bar".split("1")`. This is just because, as a
collective, we are all used to the arguments for these functions.

The use case for positional arguments only is relatively small, and I think it
should be used very sparingly, as you run the risk of getting the function
users to jump through hoops just to use your function.
