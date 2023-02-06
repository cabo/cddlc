require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"
require_relative "./cddl-expander.rb"

class CDDL
  def cddl_extract_names(prod, &name_used)
    visit(prod) do |p|
      case p
        in ["gen", name, *_gen_args]
          name_used.call(name)
          false
        in ["name", name]
          name_used.call(name)
          false
        else
          false
      end
    end
  end

  def cddl_add_used_by(prod, used)
    cddl_extract_names(prod) do |name|
      used[name] = true
    end
  end

  def cddl_undefined
    # currently only works on expanded...
    cddl2 = self.deep_clone                # needs deep-clone
    cddl2.expand_generics
    used = {}
    cddl2.rules.each do |k, v|
      fail unless String === k
      cddl2.cddl_add_used_by(v, used)
    end
    used.keys.reject {|name| cddl2.rules[name] || prelude.rules[name]}
  end
end
