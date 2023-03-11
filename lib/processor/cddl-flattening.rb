require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  ID_RE = /\A[A-Za-z@_$]([-.]*[A-Za-z@_$0-9])*\z/
  MOGRIFIED_ID_RE = /\A\$\.[A-Za-z@_$]([-.]*[A-Za-z@_$0-9])*\z/
  def flattening_key_name(key, value, env = nil)
    case key
    in ["enum", ["mem", ["text", ID_RE => text], _]]
      [false, text]
    in ["text", ID_RE => text]
      [false, text]
    in ["number", /\A0|[-]?[1-9][0-9]*\z/ => intval] if env
      [true, "$.#{env}$#{intval}"]
    else
      [false]
    end
  end
  def flattening_occurrences
    symtab = Hash.new { |h, k| h[k] = [] }
    rules.each do |name, prod|
      visit(prod) do |here|
        case here
        in ["mem", key, value]
          _labeled, keyname = flattening_key_name(key, value, false)
          if keyname
            symtab[keyname] << [name, keyname]
            false
          end
        else
          false
        end
      end
    end
    symtab
  end
  def flattening_mogrify(name, prod, symtab, alias_rules)
    step1 = visit(prod) do |here|
        case here
        in ["mem", key, value]
          ### mogrify
          labeled, keyname = flattening_key_name(key, value, name)
          if keyname
            new_name =
              unless labeled
                syment = symtab[keyname]
                fail keyname unless Array === syment
                if syment.size == 1
                  "$.#{keyname}"
                else
                  "$.#{name}$#{keyname}"
                end
              else
                keyname
              end
            new_value2 = flattening_mogrify(new_name, value, symtab, alias_rules)
            fail [alias_rules, new_name].inspect if alias_rules[new_name] # XXX
            alias_rules[new_name] = new_value2
            [true, ["mem", key, ["name", new_name]]]
          end
        else
          false
        end
      end
    step2 = visit(step1) do |here|
      case here
      in ["enum", ["mem", ["text", ID_RE], ["name", MOGRIFIED_ID_RE => new_name]]]
        [true, ["name", new_name]]
      else
        false
      end
    end
    step2
  end
  def flattening_replace(symtab)
    alias_rules = {}
    new_rules = Hash[rules.map do |name, prod|
                       [name,
                        flattening_mogrify(name, prod, symtab, alias_rules)]
                     end]
    new_rules.merge(alias_rules)
  end
  def flattening
    symtab = flattening_occurrences
    # warn "*** SYMTAB #{symtab.inspect}"
    rules.replace(flattening_replace(symtab))
  end
end
