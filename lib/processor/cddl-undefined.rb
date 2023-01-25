require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"
require_relative "./cddl-expander.rb"

class CDDL
  def cddl_undefined
    # currently only works on expanded...
    cddl2 = self
    cddl2.expand_generics
    used = {}
    gen_used = {}
    def_gen = {}
    cddl2.rules.each do |k, v|
      def_gen[k[0]] = true if Array === k
      cddl2.visit(v) do |p, &block|
        case p
        in ["gen", name, *_gen_args]
          gen_used[name] = true
        in ["name", name]
          used[name] = true
        else
          false
        end
      end
    end
    [used.keys.reject {|name| cddl2.rules[name] || prelude.rules[name]},
     gen_used.keys.reject {|name| def_gen[name] }]
  end
end
