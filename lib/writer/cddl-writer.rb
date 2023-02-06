require_relative "../cddlc.rb"

class CDDL

  def write_lhs(k, parmnames)
    if parmnames
      "#{k}<#{parmnames.join(", ")}>"
    else
      k
    end
  end

  # precedence:
  # 0: // gcho
  # 1: , seq
  # 2: / tcho -> (type1)
  # 3: (type1) .xxx op -> type2
  # 4: type2

  def prec_check(inner, targetprec, prec, indent_s)
    if targetprec > prec
      "(#{inner.gsub("\n", "\n" << indent_s)})" # XXX embedded byte strings
    else
      inner
    end
  end

  def write_rhs(v, targetprec = 0, indent = 0, pn = [])
    # pn = parmnames
#    warn "** #{v.inspect}"
    indent_p = "  " * indent
    indent += 1
    indent_s = "  " * indent
    prec, ret =
    case v
    in ["parm", parmnames, type]
      [4, write_rhs(type, 2, indent, parmnames)]
    in ["arg", Integer => num]
      [4, pn[num] || "id$#{num}"]
    in ["name", id]
      [4, id]
    in ["gen", id, *parms]  # oops -- namep vs. namea; ouch
      [4, "#{id}<#{parms.map{write_rhs(_1, 2, indent, pn)}.join(", ")}>"]
    in ["tcho", *types]
      [2, types.map{write_rhs(_1, 3, indent, pn)}.join(" / ")]
    in ["gcho", *groups]
      [0, groups.map{write_rhs(_1, 2, indent, pn)}.join(" // ")]
    in ["op", op, l, r]
      [3, "#{write_rhs(l, 3, indent, pn)} #{op} #{write_rhs(r, 3, indent, pn)}"]
    in ["map", group]
      [4, "{#{write_rhs(group, 0, indent, pn)}}"]
    in ["ary", group]
      [4, "[#{write_rhs(group, 0, indent, pn)}]"]
    in ["unwrap", namep]
      [4, "~#{write_rhs(namep, 4, indent, pn)}"]
    in ["enum", ["name", _name] => namep]
      [4, "&#{write_rhs(namep, 4, indent, pn)}"]
    in ["enum", ["gen", _name, *types] => namep]
      [4, "&#{write_rhs(namep, 4, indent, pn)})"]
    in ["enum", group]
      [4, "&(#{write_rhs(group, 0, indent, pn)})"]
    in ["prim"]
      [4, "#"]
    in ["prim", maj]
      [4, "##{maj}"]
    in ["prim", maj, min]
      [4, "##{maj}.#{min}"]
    in ["prim", 6, Integer => tag, type]
      [4, "#6.#{tag}(#{write_rhs(type, 0, indent, pn)})"]
    in ["prim", 6, nil, type]
      [4, "#6(#{write_rhs(type, 0, indent, pn)})"]
# prim: extension for #6.<i>(t)
    in ["seq", *groups]
      case groups.size
      when 0; [4, ""]
      # when 1; "#{write_rhs(g[0], targetprec, indent, pn)}"
      else
        [1, "\n#{indent_p}#{groups.map{write_rhs(_1, 1, indent, pn)}.join(",\n#{indent_p}")},\n"]
      end
    in ["rep", s, e, group]
      occur = case [s, e]
              in [1, 1];     ""
              in [0, 1];     "? "
              in [0, false]; "* "
              in [1, false]; "+ "
              else
                "#{s}*#{e || ""}"
              end
      [1, "#{occur}#{write_rhs(group, 2, indent, pn)}"]
    in ["mem", nil, t2]
      [2, write_rhs(t2, 2, indent, pn)]
    in ["mem", t1, t2]
      [2, "#{write_rhs(t1, 2, indent, pn)} => #{write_rhs(t2, 2, indent, pn)}"]
    in ["text", t]
      [4, "\"#{t}\""]              # XXX escape
    in ["number", t]
      [4, t.to_s]
    end
    prec_check(ret, targetprec, prec, indent_s)
  end

  def to_s
    rules.map {|k, v|
      parmnames = false
      case v
      in ["parm", parmnames, _type]
      else
      end
      "#{write_lhs(k, parmnames)} = #{write_rhs(v, 2)}" # 2: parenthesize groups
    }.join("\n")
  end

end
