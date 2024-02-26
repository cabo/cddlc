require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  MOGRIFIED_ID_RE = /\A\$\.[A-Za-z@_$]([-.]*[A-Za-z@_$0-9])*\z/
  def flattening_key_name(key, value, env = nil)
    case key
    in ["enum", ["mem", _cut, ["text", IDENTIFIER_RE => text], _]]
      [false, text]
    in ["text", IDENTIFIER_RE => text]
      [false, text]
    in ["number", INT_RE => intval] if env
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
        in ["mem", _cut, key, value]
          _labeled, keyname = flattening_key_name(key, value, false)
          if keyname
            symtab[keyname] << [name, value]
            false
          end
        else
          false
        end
      end
    end
    symtab_replacements = Hash[symtab.map do |k, v|
      s = Set[*v.map{_2}]
      # warn "** #{k} #{s.inspect}"
      if s.size == 1
        [k, [[v.map{|k, v| k}.join("|"), s.first]]]
      end
    end.compact]
    # warn "** symtab_replacements: #{symtab_replacements.inspect}" if $options.verbose
    symtab.merge(symtab_replacements)
  end
  def flattening_mogrify(name, prod, symtab, alias_rules)
    step1 = visit(prod) do |here|
        case here
        in ["mem", cut, key, value]
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
            new_name2 = new_name
            n = 0
            while ar = alias_rules[new_name2] and ar != new_value2
              n += 1
              new_name2 = new_name << "@" << n.to_s
            end
            alias_rules[new_name2] = new_value2
            [true, ["mem", cut, key, ["name", new_name2]]]
          end
        else
          false
        end
      end
    step2 = visit(step1) do |here|
      case here
      in ["enum", ["mem", _cut, ["text", IDENTIFIER_RE], ["name", MOGRIFIED_ID_RE => new_name2]]]
        [true, ["name", new_name2]]
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
    PP.pp(["*** SYMTAB", symtab], STDERR) if $options.verbose
    rules.replace(flattening_replace(symtab))
  end
end
