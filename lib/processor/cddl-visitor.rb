require_relative "../cddlc.rb"

class CDDL
  def visit_all(prod_array, &block)
    prod_array.map {|prod| visit(prod, &block)}
  end
  def visit(prod, &block)
    done, ret = block.call(prod, &block)
    if done
      return ret
    end

    case prod
    in ["parm", parmnames, prod]
      ["parm", parmnames, visit(prod, &block)]
    in ["gen", name, *types]
      ["gen", name, *visit_all(types, &block)]
    in ["op", op, *prods]
      ["op", op, *visit_all(prods, &block)]
    in ["map", prod]
      ["map", visit(prod, &block)]
    in ["ary", prod]
      ["ary", visit(prod, &block)]
    in ["gcho", *prods]
      ["gcho", *visit_all(prods, &block)]
    in ["tcho", *prods]
      ["tcho", *visit_all(prods, &block)]
    in ["seq", *prods]
      ["seq", *visit_all(prods, &block)]
    in ["enum", prod]
      ["enum", visit(prod, &block)]
    in ["unwrap", prod]
      ["unwrap", visit(prod, &block)] # XXX, this may need to be bottled in a rule
    in ["prim", prod, *prods]
      ["prim", visit(prod, &block), *visit_all(prods, &block)]
    in ["mem", cut, *prods]
      ["mem", cut, *visit_all(prods, &block)]
    in ["rep", s, e, prod]
      ["rep", s, e, visit(prod, &block)]
    else
      prod
    end
  end
end
