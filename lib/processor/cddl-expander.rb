require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  def substitute(prod, parms, subs, &block)
    visit(prod) do |p, &block1|
      case p
      in ["gen", name, *gen_args] # XXX
        [true, gen_apply(name, gen_args, &block1)]
      in ["arg", num]
        if replacement = subs[num]
          [true, visit(expand_prod(replacement), &block)]
        end
      else
        false
      end
    end
  end
  def gen_apply(gen_name, gen_args, &block)
    gen_parms, gen_prod = @gen[gen_name]
    fail "** no generic for #{gen_name}<#{gen_args}>" unless gen_parms
    substitute(gen_prod, gen_parms, gen_args, &block)
  end
  def expand_prod(prod)
    visit(prod) do |p, &block|
      case p
      in ["gen", name, *gen_args]
        [true, gen_apply(name, gen_args, &block)]
      else
        [false]
      end
    end
  end
  def expand_generics
    @gen = {}
    rules.each do |name, prod|
      case prod
      in ["parm", parmnames, type]
        if prod[0] == "parm"
          @gen[name] = [parmnames, type]
        end
      else
      end
    end
    warn "@gen = #{@gen.inspect}" if $options.verbose
    @gen.each do |k, v|
      parmnames = v[0]
      fail unless rules[k] == ["parm", parmnames, v[1]]
      rules.delete(k)
    end
    @new_rules = {}
    rules.each do |name, prod|
      fail if Array === name
      @new_rules[name] = expand_prod(prod)
    end
    warn "@new_rules = #{@new_rules.inspect}" if $options.verbose
    @rules = @new_rules
  end
end
