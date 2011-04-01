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
    @specials = {
      get: (receiver, field) ->
        new FieldAccess(receiver, field)
      'do': (receiver, code...) ->
        new Block(receiver, code...)
      'if': (receiver, code...) ->
        new IfNode(receiver, code...)
      'else': (receiver, code...) ->
        new ElseNode(receiver, code...)
      'function': (receiver, arg_list, code...) ->
        new FunctionNode(receiver, arg_list, code...)
      'array': (receiver, args...) ->
        new ArrayNode(receiver, args...)
      'elsif': (receiver, cond, code...) ->
        new ElsifNode(receiver, cond, code...)
      'var': (receiver, idents...) ->
        new VarNode(receiver, idents...)
    }

  send: (message) ->
    if message[0] is "IDENT" and @__is_special(message[1])
      @__get_special(message[1])(this, message[2]...)
    else
      @[message[0].toLowerCase() + "_send"](message)
  
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
    else
      @parent?.__is_special(name)
      
  __get_special: (name) ->
    @specials[name] ? @parent.__get_special(name)

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    spaces(indent) + 'this'



exports.Literal = class Literal extends Origin
  constructor: (@parent, @value) ->

  ident_send: (message) ->
    new CallChain(this, message)

  wrap: ->
    this

  compile: (indent=0) ->
    spaces(indent) + @value



exports.Ident = class Ident extends Literal
  constructor: (@parent, @message) ->
    @origin = @parent.origin

  number_send: (message) ->
    new FieldAccess(this, [message]) # we embed the message in an array since FieldAccess expects a chain

  string_send: (message) ->
    new FieldAccess(this, [message])

  wrap: ->
    this

  compile: (indent=0) ->
    name = @message[1]
    args = (send_chain(@origin, chain) for chain in @message[2]) if @message[2]
    if args?
      spaces(indent) + name + "(#{compile_list(args, 0).join(', ')})"
    else
      spaces(indent) + name



exports.CallNode = class CallNode extends Origin
  constructor: (@parent, @arg_list) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    args = (send_chain(@origin, chain) for chain in @arg_list) if @arg_list?
    @parent.compile(indent) + "(#{compile_list(args, 0).join(', ')})"



exports.CallChain = class CallChain extends Ident
  constructor: (@parent, @message) ->
    @origin = @parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    new_call = new Ident(@parent, @message)
    spaces(indent) + @parent.compile(indent) + "." + new_call.compile(indent)



exports.FieldAccess = class FieldAccess extends Ident
  constructor: (@parent, @lookup_chain) ->
    @origin = parent.origin

  wrap: ->
    this

  compile: (indent=0) ->
    lookup = send_chain(@origin, @lookup_chain)
    spaces(indent) + @parent.compile(indent) + '[' + lookup.compile(indent) + ']'



exports.Block = class Block extends Origin
  constructor: (@parent, @code...) ->
    @origin = @parent.origin

  compile: (indent=0) ->
    code = (send_chain(@parent, chain) for chain in @code)
    compile_list(code, indent).join(";\n") + ";"



exports.IfNode = class IfNode extends Origin
  constructor: (@parent, @condition, @code...) ->
    @origin = @parent.origin

  wrap: ->
    the_func = new FunctionNode(@parent, [['IDENT', 'array', []]], [['IDENT', 'if', [@condition, @code...]]]).wrap()
    new CallNode(the_func)

  compile: (indent=0) ->
    condition = send_chain(@origin, @condition)
    spaces(indent) + "if (#{condition.compile(0)}) {\n#{(new Block(@origin, @code...)).compile(indent + 2)}\n" + spaces(indent) + "}"



exports.ElseNode = class ElseNode extends Origin
  constructor: (@parent, @code...) ->
    @origin = @parent.origin

  compile: (indent=0) ->
    "else {\n" + (new Block(@origin, @code...)).compile(indent + 2) + "\n}"



exports.FunctionNode = class FunctionNode extends Origin
  constructor: (@parent, @arg_list, @code...) ->
    @wrapped = false
    @origin = @parent.origin

  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    # retrieve te arg list from the arg_list message
    arg_list = send_chain(@parent, @arg_list).value
    # construct the AST
    arg_list = (send_chain(@parent, a) for a in arg_list)
    # and compile it
    compiled_args = compile_list(arg_list, 0).join(", ")
    basic = "function (#{compiled_args}) {\n" + (new Block(@origin, @code...)).compile(indent + 2) + "\n" + spaces(indent) + "}"
    if @wrapped then "(#{basic})" else basic



exports.ArrayNode = class ArrayNode extends Literal
  constructor: (@parent, @value...) ->
    @wrapped = false
  
  wrap: ->
    @wrapped = true
    this

  compile: (indent=0) ->
    value = (send_chain(@parent, v) for v in @value)
    basic = spaces(indent) + "[" + compile_list(value).join(", ") + "]"
    if @wrapped then "(#{basic})" else basic



exports.ElsifNode = class ElsifNode extends IfNode
  wrap: ->
    throw "CompileError: You can't wrap elsif on its own"

  compile: (indent=0) ->
    'else ' + super(indent)

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
    if @wrapped then "(#{@value})" else @value
