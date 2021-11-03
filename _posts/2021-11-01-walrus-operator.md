---
layout: post
category: python
---
The Walrus operator `:=` goal is to allow a user to name variables and use them
in expressions with ease. It takes the form of `NAME := expr`. Below is an
example:

```python
while data := file.read(1024):
    process(data)
```

In this example, each time the while loop is run, data will be set to the output
of `file.read(1024)` until there is no data left to read. Each loop will run
the process function on each 1024 chunk of data. While this is a super simple
example, it shows that you can assign the output of an expression
`file.read(1024)` to a variable in the while expression.

This Operator also allows a user to reuse an expression in the case of regex
matching.

```python
import re
pattern = re.compile("foo")
if (match := pattern.search("This is just foobar")) is not None:
    print(match.group())
```

We are saving one line of code by using the walrus operator, as you can see
here. Since an alternative way of writing this is:


```python
import re
pattern = re.compile("foo")
match   = pattern.search("This is just foobar")
if match is not None:
    print(match.group())
```

Obviously, in real-world examples, you would be doing more than just printing.

Links:
https://www.python.org/dev/peps/pep-0572/
