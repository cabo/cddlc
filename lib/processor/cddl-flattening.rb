require_relative "../cddlc.rb"
require_relative "./cddl-visitor.rb"

class CDDL
  def flatten_prod(prod)
    visit(prod) do |p, &block|
      case p
      in ["gen", name, *gen_args]
        [true, gen_apply(name, gen_args, &block)]
      else
        [false]
      end
    end
  end
  def flattening_key_name(key, value)
    case key
    in nil
    in ["enum", enum]
      warn "*** ENUM #{enum.inspect}"
    in ["text", text]
      # symtab[text] += 1
      text
    else
    end
  end
  def flattening_occurrences
    symtab = Hash.new(0)
    rules.each do |name, prod|
      visit(prod) do |here|
        case here
        in ["mem", key, value]
          ### mogrify
          keyname = flattening_key_name(key, value)
          if keyname
            # Todo: check whether this even needs a flattening; e.g., unique names should be fine
            # case value
            # in ["name", _name]
            # else
              symtab[keyname] += 1
            # end
            false
          end
        else
          false
        end
      end
    end
    symtab
  end
  def flattening
    symtab = flattening_occurrences
    warn "*** SYMTAB #{symtab.inspect}"
  end
end
