require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  def constant_evaluate(rhs)
    case rhs
    in ["number", n]
      [true, eval(n)]
    in ["text", n]
      [true, n]
    in ["name", n]
      if nv = rules[n]
        constant_evaluate(nv)
      end
    else
      [false]
    end
  end
  def extract_constants
    nr = {}
    rules.each do |k, v|
      isconstant, value = constant_evaluate(v)
      nr[k] = value if isconstant
    end
    nr
  end
end
