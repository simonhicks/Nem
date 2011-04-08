{printable_array, eq, expect, expect_error} = require('../src/helpers')
{Origin, Ident} = require('../src/nodes')
{puts} = require 'sys'

o = new Origin()

# basic call chain stuff
expect('compiling an uncalled ident', 'foo', ->
  id = new Ident(o, ['IDENT', 'foo'])
  id.compile()
)
expect('compiling a called ident, without args', 'bar()', ->
  id = new Ident(o, ['IDENT', 'bar', []])
  id.compile()
)
expect('sending and compiling a simple message', 'foo', ->
  o.send(['IDENT', 'foo']).compile()
)
expect('sending and compiling a called message', 'baz()', ->
  o.send(['IDENT', 'baz', []]).compile()
)
expect('compiling a called ident with an arg', 'foo(bar)', ->
  o.send(['IDENT', 'foo', [[['IDENT', 'bar']]]]).compile()
)
expect('compiling a called ident with two args', 'foo(1, 2)', ->
  o.send(['IDENT', 'foo', [[['NUMBER', 1]], [['NUMBER', 2]]]]).compile()
)
expect('sending a message chain', 'foo.bar(baz)', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar', [[['IDENT', 'baz']]]]).compile()
)
expect('sending a longer message chain', 'foo.bar().baz.blagh()', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar', []]).send(['IDENT', 'baz']).send(['IDENT', 'blagh', []]).compile()
)
expect('sending a number to origin', '3', ->
  o.send(['NUMBER', 3]).compile()
)
expect('number.method()', '3.method()', ->
  o.send(['NUMBER', 3]).send(['IDENT', 'method', []]).compile()
)
expect('sending a string literal', '"this is a string"', ->
  o.send(['STRING', '"this is a string"']).compile()
)
expect('sending a regexp literal', '/asdf/g', ->
  o.send(['REGEXP', '/asdf/g']).compile()
)
expect('sending a number to a callchain', 'foo.bar[1]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar']).send(['NUMBER', 1]).compile()
)
expect('sending a string to a callchain', 'foo.bar["asdf"]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'bar']).send(['STRING', '"asdf"']).compile()
)

# dynamic field access
expect('accessing a field using a variable', 'foo[bar]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'get', [[['IDENT', 'bar']]]]).compile()
)
expect('accessing a field using a chain', 'foo[bar.baz]', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'get', [[['IDENT', 'bar'], ['IDENT', 'baz']]]]).compile()
)
expect('implicit this when get is sent to origin', 'this[bar]', ->
  o.send(['IDENT', 'get', [[['IDENT', 'bar']]]]).compile()
)

# code blocks
expect('creating blocks of code', 'foo();\nbar();', ->
  o.send(['IDENT', 'do', [[['IDENT', 'foo', []]], [['IDENT', 'bar', []]]]]).compile()
)
expect('sending a block as a message', 'foo.bar();\nfoo.baz();', ->
  o.send(['IDENT', 'foo']).send(['IDENT', 'do', [[['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)

# if/else

# if(foo
#   bar()
#   baz()
# )
expect('conditional execution', 'if (foo) {\n  bar();\n  baz();\n}', ->
  o.send(['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)
# else(
#   do_something(1, 2)
# )
expect('else...', 'else {\n  do_something(1, 2);\n}', ->
  o.send(['IDENT', 'else', [[['IDENT', 'do_something', [[['NUMBER', 1]], [['NUMBER', 2]]]]]]]).compile()
)

# functions
# function([], alert("Hello World!"))
expect('an anonymous function w/o args', 'function () {\n  alert("Hello World!");\n}', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array', []]], [['IDENT', 'alert', [[['STRING', '"Hello World!"']]]]]]]).compile()
)

# arrays
expect('an array', '[1, 2, 3]', ->
  o.send(['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]],[['NUMBER', 3]]]]).compile()
)

# function([a, b]
#   alert(a)
#   alert(b)
# )
expect('an anonymous function w/ args', 'function (a, b) {\n  alert(a);\n  alert(b);\n}', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array', [[['IDENT', 'a']], [['IDENT', 'b']]]]], [['IDENT', 'alert', [[['IDENT', 'a']]]]], [['IDENT', 'alert', [[['IDENT', 'b']]]]]]]).compile()
)

# wrapping things so they can be used as expressions
expect('wrapping a function', '(function () {\n  null;\n})', ->
  o.send(['IDENT', 'function', [[['IDENT', 'array',[]]], [['IDENT', 'null']]]]).wrap().compile()
)
expect('wrapping an if in a self calling function', '(function () {\n  if (foo) {\n    bar();\n  };\n})()', ->
  o.send(['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'bar', []]]]]).wrap().compile()
)
expect('wrapping origin returns origin', 'this', ->
  o.wrap().compile()
)
expect('wrapping an array adds parens', '([1, 2, 3])', ->
  o.send(['IDENT', 'array', [[['NUMBER', 1]],[['NUMBER', 2]],[['NUMBER', 3]]]]).wrap().compile()
)
expect('wrapping a number does nothing', '1', ->
  o.send(['NUMBER', 1]).wrap().compile()
)
expect('wrapping a string does nothing', '"asdf"', ->
  o.send(['STRING', '"asdf"']).wrap().compile()
)

# elsif
expect('else if', 'else if (foo) {\n  bar();\n}', ->
  o.send(['IDENT', 'elsif', [[['IDENT', 'foo']], [['IDENT','bar', []]]]]).compile()
)
expect_error('can\'t wrap else if on it\'s own', "CompileError: You can't wrap elsif on its own", ->
  o.send(['IDENT', 'elsif', [[['IDENT', 'foo']], [['IDENT','bar', []]]]]).wrap().compile()
)

# var
expect('a var declaration', 'var a', ->
  o.send(['IDENT', 'var', [[['IDENT', 'a']]]]).compile()
)
expect('multiple var declarations', 'var a, b, c', ->
  o.send(['IDENT', 'var', [[['IDENT', 'a']], [['IDENT', 'b']], [['IDENT', 'c']]]]).compile()
)

# expr messages get sent straight through when sent to origin
expect('expr message', 'blah blah blah', ->
  o.send(['EXPR', 'blah blah blah']).compile()
)
# but they can't be sent to anything else
expect_error('expr message error', 'CompileError: EXPR messages can only be sent to Origin', ->
  o.send(['IDENT', 'foo']).send(['EXPR', 'blah blah blah']).compile()
)

# while
expect('while loop', 'while (foo) {\n  alert("hello");\n}', ->
  o.send(['IDENT', 'while', [[['IDENT', 'foo']], [['IDENT', 'alert',[[['STRING', '"hello"']]]]]]]).compile()
)
expect('wrapped while loop', '(function () {\n  while (foo) {\n    alert("hello");\n  };\n})()', ->
  o.send(['IDENT', 'while', [[['IDENT', 'foo']], [['IDENT', 'alert',[[['STRING', '"hello"']]]]]]]).wrap().compile()
)

# named functions
expect('named functions', 'function Blagh () {\n  alert("BLAGH!");\n}', ->
  o.send(['IDENT', 'function', [[['IDENT', "Blagh"]], [['IDENT', 'array', []]], [['IDENT', 'alert', [[['STRING', '"BLAGH!"']]]]]]]).compile()
)
expect('wrapped named functions', '(function Blagh () {\n  alert("BLAGH!");\n})', ->
  o.send(['IDENT', 'function', [[['IDENT', "Blagh"]], [['IDENT', 'array', []]], [['IDENT', 'alert', [[['STRING', '"BLAGH!"']]]]]]]).wrap().compile()
)

# ternary operator
expect('ternary operator', 'foo ? bar() : baz()', ->
  o.send(['IDENT', '?:', [[['IDENT', 'foo']], [['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)
expect('wrapping a ternary operator', 'foo ? bar() : baz()', ->
  o.send(['IDENT', '?:', [[['IDENT', 'foo']], [['IDENT', 'bar', []]], [['IDENT', 'baz', []]]]]).compile()
)

# returns
expect('return', 'return a', ->
  o.send(['IDENT', 'return']).send(['IDENT', 'a']).compile()
)
expect('returning a chain', 'return a.b().c', ->
  o.send(['IDENT', 'return']).send(['IDENT', 'a']).send(['IDENT', 'b', []]).send(['IDENT', 'c']).compile()
)


# automatic wrapping
# alert(if(foo, return bar()))
expect('automatic wrapping of args', 'alert((function () {\n  if (foo) {\n    return bar();\n  };\n})())', ->
  o.send(['IDENT', 'alert', [[['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'return'], ['IDENT', 'bar', []]]]]]]]).compile()
)
expect('automatic wrapping of method args', 'obj.method((function () {\n  if (foo) {\n    return bar();\n  };\n})())', ->
  o.send(['IDENT', 'obj']).send(['IDENT', 'method', [[['IDENT', 'if', [[['IDENT', 'foo']], [['IDENT', 'return'], ['IDENT', 'bar', []]]]]]]]).compile()
)
expect('automatic wraping in a call chain', '(function () {\n  if (a) {\n    b;\n  };\n})().c()', ->
  o.send(['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]).send(['IDENT', 'c', []]).compile()
)
expect('automatic wrapping in field access', '(function () {\n  if (a) {\n    b;\n  };\n})()[0]', ->
  o.send(['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]).send(['NUMBER', 0]).compile()
)
expect('automatic wrapping in a get method', 'blah[(function () {\n  if (a) {\n    b;\n  };\n})()]', ->
  o.send(['IDENT', 'blah']).send(['IDENT', 'get', [[['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]]]]).compile()
)
expect('automatic wrapping for if node, conditions', 'if ((function () {\n  if (a) {\n    b;\n  };\n})()) {\n  c();\n}', ->
  o.send(['IDENT', 'if', [[['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]], [['IDENT', 'c', []]]]]).compile()
)
expect('automatic wrapping for elsif', 'else if ((function () {\n  if (a) {\n    b;\n  };\n})()) {\n  c();\n}', ->
  o.send(['IDENT', 'elsif', [[['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]], [['IDENT', 'c', []]]]]).compile()
)
expect('automatic wrapping in ternary operator', '(function () {\n  if (a) {\n    b;\n  };\n})() ? (function () {\n  if (c) {\n    d;\n  };\n})() : (function () {\n  if (e) {\n    f;\n  };\n})()', ->
  o.send(['IDENT', '?:', [[['IDENT', 'if', [[['IDENT', 'a']], [['IDENT', 'b']]]]], [['IDENT', 'if', [[['IDENT', 'c']], [['IDENT', 'd']]]]], [['IDENT', 'if', [[['IDENT', 'e']], [['IDENT', 'f']]]]]]]).compile()
)

# prefix operators
expect('new operator', 'new Object()', ->
  o.send(['IDENT', 'new']).send(['IDENT', 'Object', []]).compile()
)
expect('not operator', '! a', ->
  o.send(['IDENT', '!']).send(['IDENT', 'a']).compile()
)

# bracketted operations
expect('not in a chain without brackets', '! foo.bar', ->
  o.send(['IDENT', '!']).send(['IDENT', 'foo']).send(['IDENT', 'bar']).compile()
)
expect('using brackets to change the order of execution', '(new Foo()).bar', ->
  # (new Foo()) bar
  o.send([['IDENT', 'new'], ['IDENT', 'Foo', []]]).send(['IDENT', 'bar']).compile()
)
expect('sending a bracketed form', '(! (foo.bar)).baz', ->
  # (! (foo bar)) baz
  o.send([['IDENT', '!'], [['IDENT', 'foo'], ['IDENT', 'bar']]]).send(['IDENT','baz']).compile()
)

# arithmetic
expect('adding numbers', '1 + 2', ->
  o.send(['NUMBER', 1]).send(['IDENT', '+']).send(['NUMBER', 2]).compile()
)
expect('multiplying', '2 * 3', ->
  o.send(['NUMBER', 2]).send(['IDENT', '*']).send(['NUMBER', 3]).compile()
)
expect('wrapped arithmetic', '(1 + 2)', ->
  o.send(['NUMBER', 1]).send(['IDENT', '+']).send(['NUMBER', 2]).wrap().compile()
)
expect('using brackets with arithmetic', '2 * (3 + 4)', ->
  o.send(['NUMBER', 2]).send(['IDENT', '*']).send([['NUMBER', 3], ['IDENT', "+"], ['NUMBER', 4]]).compile()
)
expect('using brackets with arithmetic', '(2 * (3 + 4)) + 5', ->
  o.send(['NUMBER', 2]).send(['IDENT', '*']).send([['NUMBER', 3], ['IDENT', "+"], ['NUMBER', 4]]).send(['IDENT', '+']).send(['NUMBER', 5]).compile()
)

# splice
# obj splice((foo bar baz)) should be equivalent to obj foo bar baz
# then we can use it in the expansion of #{...}
expect('splice', 'obj.foo.bar().baz', ->
  o.send(['IDENT', 'obj']).send(['IDENT', 'splice', [[[['IDENT', 'foo'], ['IDENT', 'bar', []], ['IDENT', 'baz']]]]]).compile()
)

# creating macros
macro_name = [["IDENT", "unless"]]
macro_args = [["IDENT", "array", [[["IDENT", "cond"]], [["IDENT", "body"]]]]]
splice_chain = [['IDENT', 'array', [[['STRING', '"IDENT"']], [['STRING', '"splice"']], [['IDENT', 'array', [[['IDENT', 'array', [[[['IDENT', 'cond']]]]]]]]]]]]
cond_chain = [['IDENT', 'array', [[['IDENT', 'array', [[['STRING', '"IDENT"']], [['STRING', '"!"']]]]], splice_chain]]]
body_chain = [['IDENT', 'array', [[['IDENT', 'array', [[['STRING', '"IDENT"']], [['STRING', '"splice"']], [['IDENT', 'array', [[['IDENT', 'array', [[[['IDENT', 'body']]]]]]]]]]]]]]]
macro_body = [["IDENT", "array", [[["IDENT", "array", [[["STRING", '"IDENT"']], [["STRING", '"if"']], [['IDENT', 'array', [cond_chain, body_chain]]]]]]]]]
macro_def = ["IDENT", "macro", [macro_name, macro_args, [['IDENT', 'return', [macro_body]]]]]
expect('defining a macro','''
  if ((! foo)) {
    bar.baz();
  }''', ->
  tmp = new Origin()
  tmp.send(macro_def)
  tmp.send(['IDENT', 'unless', [[['IDENT', 'foo']], [['IDENT', 'bar'], ['IDENT', 'baz', []]]]]).compile()
)

# basic assignment
expect('simple assignment', 'a = 1', ->
  o.send(['IDENT', 'a']).send(['IDENT', '=']).send(['NUMBER', 1]).compile()
)
expect('chained assignment', 'a = (b = 1)', ->
  o.send(['IDENT', 'a']).send(['IDENT', '=']).send(['IDENT', 'b']).send(['IDENT', '=']).send(['NUMBER', 1]).compile()
)
expect('wrapping assignments', '(foo = bar()).baz()', ->
  o.send([['IDENT', 'foo'], ['IDENT', '='], ['IDENT', 'bar', []]]).send(['IDENT', 'baz', []]).compile()
)

# array destructuring
expect('array destructuring', 'var __ref = foo();\na = __ref[0];\nb = __ref[1]', ->
  # [a, b] = foo()
  o.send(['IDENT', 'array', [[['IDENT', 'a']], [['IDENT', 'b']]]]).send(['IDENT', '=']).send(['IDENT', 'foo', []]).compile()
)
expect('nested array destructuring', 'var __ref = foo();\na = __ref[0];\ns = (__ref[1])[0];\nd = (__ref[1])[1]', ->
  # [a, [s, d]] = foo()
  puts o.send(['IDENT', 'array', [[['IDENT', 'a']], [['IDENT', 'array', [[['IDENT', 's']], [['IDENT', 'd']]]]]]]).send(['IDENT', '=']).send(['IDENT', 'foo', []]).compile()
  o.send(['IDENT', 'array', [[['IDENT', 'a']], [['IDENT', 'array', [[['IDENT', 's']], [['IDENT', 'd']]]]]]]).send(['IDENT', '=']).send(['IDENT', 'foo', []]).compile()
)


# TODO think about #wrap for blocks
# TODO make this work... if (foo, blah()) else( blah())
# TODO and this... if (foo, blah()) else if(boo, blah)
