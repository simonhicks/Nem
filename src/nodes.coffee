{puts} = require 'sys'
{printable_array} = require './helpers'

# convenience functions
spaces = (n) ->
  spaces = ""
  spaces += " " for i in [0...n]
  spaces

send_chain = (receiver, chain) ->
  for msg in chain
    receiver = receiver.send(msg)
  receiver

compile_list = (list, indent) ->
  compiled = []
  if list?
    for i in list
      do (i) ->
        compiled.push(i.compile(indent))
  compiled

exports.Origin = class Origin
  constructor: (@parent=null) ->
    @origin = this

  specials:
      '+': (receiver) ->
        new ArithmeticNode(receiver, '+')
      '*': (receiver) ->
        new ArithmeticNode(receiver, '*')
      '-': (receiver) ->
        new ArithmeticNode(receiver, '-')
      '/': (receiver) ->
        new ArithmeticNode(receiver, '/')
      get: (receiver, field) ->
        new FieldAccess(receiver, field)
      'do': (receiver, code...) ->
        new Block(receiver, code...)
      'if': (receiver, code...) ->
        new IfNode(receiver, code...)
      'else': (receiver, code...) ->
        new ElseNode(receiver, code...)
      'function': (receiver, args...) ->
        new FunctionNode(receiver, args...)
      'array': (receiver, args...) ->
        new ArrayNode(receiver, args...)
      'elsif': (receiver, cond, code...) ->
        new ElsifNode(receiver, cond, code...)
      'var': (receiver, idents...) ->
        new VarNode(receiver, idents...)
      'while': (receiver, cond, code...) ->
        new WhileNode(receiver, cond, code...)
      '?:': (receiver, cnd, thn, els) ->
        new TernaryOperatorNode(receiver, cnd, thn, els)
      'return': (receiver, item) ->
        new ReturnNode(receiver, item)
      'new': (receiver, item) ->
        new NewNode(receiver, item)
      '!': (receiver, item) ->
        new NotNode(receiver, item)
      'splice': (receiver, args...) ->
        send_chain(receiver, args[0][0])
      'macro': (receiver, name, arg_list, body...) ->
        f = eval("(" + (new FunctionNode(receiver, arg_list, body...)).compile() + ")")
        f_name = send_chain(receiver, name).compile()
        receiver.specials[f_name] = (receiver, args...) ->
          send_chain(receiver, f(args...))
        new JSExpr(receiver, "")

  send: (message) ->
    if message[0].constructor is Array
      @chain_send(message)
    else if message[0] is "IDENT" and @__is_special(message[1])
      @__get_special(message[1])(this, message[2]...)
    else
      @[message[0].toLowerCase() + "_send"](message)

  chain_send: (chain) ->
    compiled = send_chain(@origin, chain).compile()
    this.send(['EXPR', compiled])
  
  number_send: (message) ->
    new Literal(this, message[1])

  string_send: (message) ->
    new Literal(this, message[1])

  regexp_send: (message) ->
    new Literal(this, message[1])

  ident_send: (message) ->
    new Ident(this, message)

  expr_send: (message) ->
    if this.constructor is Origin
      new JSExpr(this, message[1])
    else
      throw 'CompileError: EXPR messages can only be sent to Origin'

  __is_special: (name) ->
    if (@specials ?= {}).hasOwnProperty(name)
      true
    else if this.constructor is Origin
      false
    else
      @constructor.__super__.constructor::__is_special(name)
      
  __get_special: (name) ->
    if (spec = @specials[name])?
      spec
    else
      @constructor.__super__.constructor::__get_special(name)

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    spaces(indent) + 'this'



exports.Literal = class Literal extends Origin
  constructor: (@parent, @value) ->
    @origin = @parent.origin

  ident_send: (message) ->
    new CallChain(this, message)

  number_send: (message) ->
    new FieldAccess(this, [message]) # we embed the message in an array since FieldAccess expects a chain

  string_send: (message) ->
    new FieldAccess(this, [message])

  wrap: ->
    this

  compile: (indent=0) ->
    spaces(indent) + @value

class PrefixOperatorNode extends Literal
  constructor: (@parent, @chain=null) ->
    @wrapped = false
    @origin = @parent.origin
    @chain = @origin.send(@chain) if @chain?

  expr_send: (message) ->
    new JSExpr(this, message[1])

  send: (message) ->
    if @wrapped
      super(message)
    else
      if @chain?
        @chain = @chain.send(message)
      else
        @chain = @origin.send(message)
      this

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    if @wrapped
      spaces(indent) + "(" + @operator + " " + @chain.wrap().compile() + ")"
    else
      spaces(indent) + @operator + " " + @chain.wrap().compile()

class ArithmeticNode extends Literal
  constructor: (@parent, @operator) ->
    @wrapped = false
    @chain = null
    @origin = @parent.origin

  send: (message) ->
    @chain = @origin.send(message)
    new JSExpr(@parent, this.compile())

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    if @wrapped
      spaces(indent) + "(" + @parent.wrap().compile() + " " + @operator + " " + @chain.wrap().compile() + ")"
    else
      spaces(indent) + @parent.wrap().compile() + " " + @operator + " " + @chain.wrap().compile()

exports.ReturnNode = class ReturnNode extends PrefixOperatorNode
  operator: "return"

exports.NewNode = class NewNode extends PrefixOperatorNode
  operator: "new"

exports.NotNode = class NotNode extends PrefixOperatorNode
  operator: "!"

exports.Ident = class Ident extends Literal
  constructor: (@parent, @message) ->
    @origin = @parent.origin

  specials:
    '=': (receiver) ->
      new SimpleAssignmentNode(receiver)

  wrap: ->
    this

  compile: (indent=0) ->
    name = @message[1]
    args = (send_chain(@origin, chain).wrap() for chain in @message[2]) if @message[2]
    if args?
      spaces(indent) + name + "(#{compile_list(args, 0).join(', ')})"
    else
      spaces(indent) + name


exports.SimpleAssignmentNode = class SimpleAssignmentNode extends PrefixOperatorNode
  operator: '='

  nest: ->
    this
  
  compile: (indent=0) ->
    if @wrapped
      spaces(indent) + "(" + @parent.compile() + " " + @operator + " " + @chain.wrap().compile() + ")"
    else
      spaces(indent) + @parent.compile() + " " + @operator + " " + @chain.wrap().compile()

exports.CallNode = class CallNode extends Origin
  constructor: (@parent, @arg_list) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    args = (send_chain(@origin, chain).wrap() for chain in @arg_list) if @arg_list?
    @parent.compile(indent) + "(#{compile_list(args, 0).join(', ')})"

exports.CallChain = class CallChain extends Ident
  constructor: (@parent, @message) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    new_call = new Ident(@parent, @message)
    @parent.wrap().compile(indent) + "." + new_call.compile()

exports.FieldAccess = class FieldAccess extends Ident
  constructor: (@parent, @lookup_chain) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    lookup = send_chain(@origin, @lookup_chain)
    spaces(indent) + @parent.wrap().compile(indent) + '[' + lookup.wrap().compile(indent) + ']'

exports.Block = class Block extends Origin
  constructor: (@parent, @code...) ->
    @origin = @parent.origin

  compile: (indent=0) ->
    code = (send_chain(@parent, chain) for chain in @code)
    (compile_list(code, indent).join(";\n") + ";").replace(/;+/g, ";")

exports.IfNode = class IfNode extends Literal
  constructor: (@parent, @condition, @code...) ->
    @origin = @parent.origin

  wrap: ->
    the_func = new FunctionNode(@parent, [['IDENT', 'array', []]], [['IDENT', 'if', [@condition, @code...]]]).wrap()
    new CallNode(the_func)

  compile: (indent=0) ->
    condition = send_chain(@origin, @condition)
    spaces(indent) + "if (#{condition.wrap().compile(0)}) {\n#{(new Block(@origin, @code...)).compile(indent + 2)}\n" + spaces(indent) + "}"

exports.ElseNode = class ElseNode extends Origin
  constructor: (@parent, @code...) ->
    @origin = @parent.origin

  compile: (indent=0) ->
    spaces(indent) + "else {\n" + (new Block(@origin, @code...)).compile(indent + 2) + "\n}"

exports.FunctionNode = class FunctionNode extends Origin
  constructor: (@parent, args...) ->
    if args[0][0][1] isnt 'array'
      # create a named function
      @name = args[0]
      @arg_list = args[1]
      @code = args[2..]
    else
      # create an anonymous function
      @name = false
      @arg_list = args[0]
      @code = args[1..]
    @wrapped = false
    @origin = @parent.origin

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    # retrieve the arg list from the arg_list message
    arg_list = send_chain(@parent, @arg_list).value
    # construct the AST
    arg_list = (send_chain(@parent, a) for a in arg_list)
    # and compile it
    compiled_args = compile_list(arg_list, 0).join(", ")
    # retrieve and compile the name
    name = if @name then (send_chain(@parent, @name).compile() + " ") else ""
    basic = "function #{name}(#{compiled_args}) {\n" + (new Block(@origin, @code...)).compile(indent + 2) + "\n" + spaces(indent) + "}"
    spaces(indent) + if @wrapped then "(#{basic})" else basic

exports.ArrayNode = class ArrayNode extends Literal
  constructor: (@parent, @value...) ->
    @origin = @parent.origin
    @wrapped = false

  specials: 
    '=': (receiver) ->
      new ArrayAssignmentNode(receiver)
  
  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    value = (send_chain(@parent, v) for v in @value)
    basic = "[" + compile_list(value).join(", ") + "]"
    spaces(indent) + if @wrapped then "(#{basic})" else basic

exports.ArrayAssignmentNode = class ArrayAssignmentNode extends PrefixOperatorNode
  nest: ->
    @nested = true
    this

  compile: (indent=0) ->
    if @nested?
      exprs = []
      ref = @chain.compile()
      for ident, idx in @parent.value
        do (ident, idx) =>
          exprs.push(send_chain(@origin, ident).send(['IDENT', '=']).send(['EXPR', ref]).send(['IDENT', 'get', [[['NUMBER', idx]]]]).nest().compile())
    else
      exprs = ["var __ref = " + @chain.compile()]
      for ident, idx in @parent.value
        do (ident, idx) =>
          exprs.push(send_chain(@origin, ident).send(['IDENT', '=']).send(['IDENT', '__ref']).send(['IDENT', 'get', [[['NUMBER', idx]]]]).nest().compile())
    spaces(indent) + exprs.join(";\n" + spaces(indent))

exports.ElsifNode = class ElsifNode extends IfNode
  wrap: ->
    throw "CompileError: You can't wrap elsif on its own"

  compile: (indent=0) ->
    spaces(indent) + 'else ' + super()

exports.VarNode = class VarNode extends Origin
  constructor: (@parent, @idents...)->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    ids = compile_list(send_chain(@parent, ch) for ch in @idents, 0).join(", ")
    spaces(indent) + "var " + ids

exports.JSExpr = class JSExpr extends Literal
  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    spaces(indent) + if @wrapped then "(#{@value})" else @value

exports.WhileNode = class WhileNode extends IfNode
  wrap: ->
    the_func = new FunctionNode(@parent, [['IDENT', 'array', []]], [['IDENT', 'while', [@condition, @code...]]]).wrap()
    new CallNode(the_func)

  compile: (indent=0) ->
    condition = send_chain(@origin, @condition)
    spaces(indent) + "while (#{condition.compile(0)}) {\n#{(new Block(@origin, @code...)).compile(indent + 2)}\n" + spaces(indent) + "}"



exports.TernaryOperatorNode = class TernaryOperatorNode extends Origin
  constructor: (@parent, @cnd, @thn, @els) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    cnd = send_chain(@origin, @cnd).wrap().compile(indent)
    thn = send_chain(@origin, @thn).wrap().compile(indent)
    els = send_chain(@origin, @els).wrap().compile(indent)
    spaces(indent) + cnd + " ? " + thn + " : " + els
