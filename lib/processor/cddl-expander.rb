require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  def substitute(prod, parms, args, &block)
    subs = Hash[parms.zip(args)]
    visit(prod) do |p, &block1|
      case p
      in ["gen", name, *gen_args]
        [true, gen_apply(name, gen_args, &block1)]
      in ["name", name]
        if replacement = subs[name]
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
      if Array === name
        @gen[name[0]] = [name[1..-1], prod]
      end
    end
    p @gen if $options.verbose
    @gen.each do |k, v|
      namep = v[0]
      fail unless rules[[k, *namep]] == v[1]
      rules.delete([k, *namep])
    end
    @new_rules = {}
    rules.each do |name, prod|
      fail if Array === name
      @new_rules[name] = expand_prod(prod)
    end
    p @new_rules if $options.verbose
    @rules = @new_rules
  end
end
