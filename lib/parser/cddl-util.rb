require 'treetop'
require_relative './cddlgrammar'

class Treetop::Runtime::SyntaxNode
  def ast
    fail "undefined_ast #{inspect}"
  end
  def ast1                      # devhack
    "#{inspect[10..20]}--#{text_value[0..15]}"
  end
  def mkgen(name, genparm)
    nm = name.text_value
    if el = genparm.elements
      ["gen", nm, *genparm.ast] # XXX
    else
      ["name", nm]
    end
  end
  def wrapop(op, first, rest)
    a = first.ast
    b = rest.map(&:ast)
    if b.size != 0
      [op, a, *b]
    else
      a
    end
  end
  def wrapop0(op, all)
    a = all.map(&:ast)
    if a.size == 1
      a[0]
    else
      [op, *a]
    end
  end
  def tvtoi(el, default)
    v = el.text_value
    if v == ''
      default
    else
      v.to_i
    end
  end
  def repwrap(el, val)
    if el.text_value == ''
      val
    else
      ["rep", *el.ast, val]
    end
  end
end
