---
layout: post
category: python
title: "Correcting Common Misuses of Python's 'NoReturn' in Typing"
heading: "I have been using Python typing's 'NoReturn' wrong"
description: A basic overview of my misunderstanding of Pythons NoReturn Type.
---
I am a huge fan of python's new typing module which was introduced in version
3.5 see the version overview
[here](https://docs.python.org/3/whatsnew/3.5.html). The addition of this
module gives us a range of tools to help people read and understand your code
in the future.

Since I have started using typing I have been adding argument types, and return
types to almost all of my public functions. One that keeps popping up is
`NoReturn`, and as it turns out I have been using it wrong.

## My Mistake

I had completely forgotten about Python's implicit returns. Almost no function in
python actually returns nothing... In my mind for what ever reason I thought
that if I don't explicitly return something then the `NoReturn` typing makes
sense, however this is not the case.

Below is an example of a function that I *thought* should be typed as `NoReturn`
but was very wrong:

```python
def foobar():
    print("BAZBAR")
```

The above function does not *explicitly* return anything, but python will add
an implicit return of `None` when it ends. You can see this by assigning the
return value of that function to a variable eg: `rtn = foobar()` then see the
type by running `type(rtn)`, you should get `<class 'NoneType'>` back! This is
an example of python adding `return None` at the end of your function.

## So what is `NoReturn` for?

The goal of the `NoReturn` type is to signify that calling this function will
end all further processing, it is the point of NO RETURN! This type should be
used in functions that will raise an exception, or a function that ends the
program, below are a few examples.

### Examples of `NoReturn` used correctly

```python
def raise_error() -> NoReturn:
    """
    Always raise an error.
    """
    raise RuntimeError("An Error occurred")

def quit_program() -> NoReturn:
   """
   Quit the process running this code.
   """
   import sys
   sys.exit()
```

I now need to go over 100s of lines of code, and fix this mistake!  To fix this
mistake, I will need to go though all the instances where I have put `NoReturn`
and if in reality the function ends processing, then I will leave it as it is.
In most cases though I will need to replace `-> NoReturn` with `-> None `.

## So what did I learn?

I could have avoided this if I just RTFM a little better! The python docs are a
great resource, and I should have read the `NoReturn` section more carefully.
You can find the docs on `NoReturn`
[here](https://docs.python.org/3/library/typing.html#typing.NoReturn).

----
Tags:
Python, Typing, Mistakes
