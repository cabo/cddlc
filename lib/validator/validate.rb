# requires for CBOR

require 'cbor-pure' unless defined?(CBOR::Tagged)
require 'half'

# requires for control operators
require 'cbor-deterministic'
require 'regexp-examples'
require 'abnftt'
require 'base64'
require 'base32'
require 'base45_lite'
require 'scanf'

# Hmm:
#!/usr/bin/env RUBY_THREAD_VM_STACK_SIZE=5000000 ruby


class CDDL

#  DATA_DIR = Pathname.new(__FILE__).split[0] + '../../data'
#  PRELUDE = File.read("#{DATA_DIR}/prelude.cddl") -> #prelude -- parsed

  MANY = Float::INFINITY

  MAX_RECURSE = 128              # XXX

  CDDLC_INVENT = ENV["CDDLC_INVENT"]
  CDDLC_DEBUG = ENV["CDDLC_DEBUG"]

  FEATURE_REJECT_RE = /\A\^/
  # CDDLC_FEATURE_OK=cbor,^json
  CDDLC_FEATURE_OK, CDDLC_FEATURE_REJECT =
                   if ok = ENV["CDDLC_FEATURE_OK"]
                     ok.split(/,\s*/)
                       .partition{|s| s[0] !~ FEATURE_REJECT_RE}
                       .map {|l| Hash[l.map {|feature|
                                        [feature.sub(FEATURE_REJECT_RE, ''),
                                         true]}]}
                   else
                     [{}, {}]
                   end

  REGEXP_FOR_STRING = Hash.new {|h, k|
    h[k] = Regexp.new("\\A(?:#{k})\\z")
  }

  ABNF_PARSER_FOR_STRING = Hash.new {|h, k|
    grammar = "cddl-t0p--1eve1-f0r--abnf = " << k # XXX
    h[k] = ABNF.from_abnf(grammar)
  }

  ABNF_ENCODING_FOR_CONOP = {
    ".abnf" => Encoding::UTF_8,
    ".abnfb" => Encoding::BINARY
  }


  # library:

  def remove_indentation(s)
    l = s.lines
    indent = l.grep(/\S/).map {|l| l[/^\s*/].size}.min
    l.map {|l| l.sub(/^ {0,#{indent}}/, "")}.join
  end

  # [success, item, info, sublist (a/m/t)]
  # [true, item, annos, sub-results [kv]]
  # [false, item, error, sub-results [kv]]
  # separate bad specs (always fails) from non-matching specs

  def validate(item)
    @rootrule ||= @rules.keys.first
    # boxify item
    validate1(item, ["name", @rootrule])
  end

  def numval(s)
    Integer(s) rescue Float(s)
  end

  def validate1(item, where)
    pp [:VALIDATE1, item, where].inspect if CDDLC_DEBUG
    anno = nil
    case where
    in ["name", name]
      # invent or error out if !rules[name]
      rhs = rules[name]
      unless rhs
        if s = CDDLC_INVENT
          s = "_" if s == ""
          rules[name] = rhs = ["text", "#{s}-#{name}"]
        else
          return [false, item, {undefined: [name]}, []]
        end
      end
      r = validate1(item, rhs)
      case r
      in [true, item, _annos, _sub]
        [true, item, {name: name}, [r]]
      in [false, item, error, _sub]
        [false, item, {nomatch: [name, error]}, [r]]
      else
        fail [:MALFORMED_R, r, item, rhs].inspect
      end
    in ["number", num]
      val = numval(num)
      if !(item.eql? val)            # TODO: 0.0 vs. -0.0
        [false, item, {wrongnumber: [item, val, num]}, []]
      else
        [true, item, {}, []]
      end
    in ["text", val]
      if !(item.eql? val)            # check text vs. bytes
        [false, item, {wrongtext: [item, val]}, []]
      else
        [true, item, {}, []]
      end
    in ["bytes", val]
      # XXX Need to fix abnftt to yield correct value
      if !(item.eql? val)            # check text vs. bytes
        [false, item, {wrongtext: [item, val]}, []]
      else
        [true, item, {}, []]
      end
    in ["tcho", *choices]
      nomatches = []
      choices.each do |where|
        r = validate1(item, where)
        if r[0]
          pp [:TCHO, item, where, r] if CDDLC_DEBUG
          return r
        end
        nomatches << r
      end
      [false, item, nomatches, [r]]
    in ["prim"]
      [true, item, {}, []]
    in ["prim", 0]
      simple_result(Integer === item && item >= 0 && item <= 0xffffffffffffffff,
                    item, where, :wrongnumber)
    in ["prim", 1]
      simple_result(Integer === item && item < 0 && item >= -0x10000000000000000,
                    item, where, :wrongnumber)
    in ["prim", 2]
      simple_result(String === item && item.encoding == Encoding::BINARY,
                    item, where, :wrongbytes)
    in ["prim", 3]
      simple_result(String === item && item.encoding != Encoding::BINARY, # cheat
                    item, where, :wrongtext)
    in ["prim", 6, *wh2]
      warn [:WH2, wh2].inspect
      d = if Integer === item
            biggify(item)
          else
            item
          end
      # XXX validate tag against headnum if present
      if CBOR::Tagged === d
        r0 = if Integer === wh2[0]
               simple_result(d.tag == wh2[0], d.tag, wh2[0], :wrongtag)
             else validate1(d.tag, wh2[0])
             end
        r1 = validate1(d.data, wh2[1])
        if r0[0] && r1[0]
          [true, item, {}, []]  # XXX add diagnosics
        else
          [false, item, {wrongtag: [item, where]}, [r0, r1]]
        end
      else
        [false, item, {not_a_tag: [item, where]}, []]
      end
    in ["prim", 7, *ai]
    # t, v = extract_value(where)  --           if t --             v.eql? d -- 
      headnum = case item
                when Float
                  FLOAT_AI_FROM_SIZE[item.to_cbor.size]
                when CBOR::Simple
                  item.value
                when false
                  20
                when true
                  21
                when nil
                  22
                end
      if Array === ai[0]        # CDDL for head number
        validate1(headnum, ai[0])
      else
        simple_result(
          ai[0].nil? ||
          ai[0] == headnum,
          item, where, :wrong7)
      end
    in ["op", op, lhs, rhs]
      case op
      in ".." | "..."
        rex = RANGE_EXCLUDE_END[op]
        lhss, lhsv, lhst = extract_value(lhs)
        rhss, rhsv, rhst = extract_value(rhs)
        if !lhss || !rhss
          [false, item, {UNSPECIFIC_RANGE: [op, lhs, rhs]}, []]
        elsif lhst != rhst
          [false, item, {INCOHERENT_RANGE: [op, lhs, rhs]}, []]
        else
          st = scalar_type(item)
          if lhst != st
            [false, item, {rangetype: [op, lhs, rhs]}, []]
          else
            rg = Range.new(lhsv, rhsv, rex)
            simple_result(
              rg.include?(item),
              item, where, :out_of_range)
          end
        end
      in ".cat" | ".det" | ".plus"
        s, v, t = extract_value(where)
        pp [:CAT_DET_PLUS, s, v, t, item, scalar_type(item)] if CDDLC_DEBUG
        if s
          simple_result(s && scalar_type(item) == t && item == v,
                      item, where, :no_match)
        else
          [false, item, v, []]
        end
      in ".size"
        anno = :lhs
        r = validate1(item, lhs)
        if r[0]
          case item
            when Integer
              ok, v, vt = extract_value(rhs)
              if ok && vt == :int
                simple_result((item >> (8*v)) == 0,
                              item, where, :toolarge)
              end
            when String
              validate1(item.bytesize, rhs)
            else
              false
          end
        end
      in ".bits"
        anno = :lhs
        r = validate1(item, lhs)
        if r[0]
            if String === item
              simple_result(
                item.each_byte.with_index.all? { |b, i|
                  bit = i << 3
                  8.times.all? { |nb|
                    b[nb] == 0 || validate1(bit+nb, rhs)[0] # collect
                  }
                },
                item, where, :unwanted_bit_set)
            elsif Integer === item
              if item >= 0
                ok = true
                i = 0
                d = item
                while ok && d > 0
                  if d.odd?
                    ok &&= validate1(i, rhs)[0] # collect
                  end
                  d >>= 1; i += 1
                end
                simple_result(ok,
                              item, where, :unwanted_bit_set)
              end
            end
        end
      in ".default"
        # anno = :lhs
        r = validate1(item, lhs)
        # TO DO
        unless @default_warned
          warn "*** Ignoring .default for now."
          @default_warned = true
        end
        r
      in ".feature"
        r = validate1(item, lhs)
        if r[0]
          nm, det = extract_feature(rhs, d)
          if CDDLC_FEATURE_REJECT[nm]
            [false, item, {:rejected_feature => [nm, det]}, []]
          else
            [true, item, {:accepted_feature => [nm, det]}, []]
          end
        end

      in ".regexp"
        anno = :lhs
        r = validate1(item, lhs)
        if r[0]
          if String === item
              ok, v, vt = extract_value(rhs)
              if ok && :text == vt
                re = REGEXP_FOR_STRING[v]
                # pp re if CDDLC_DEBUG
                simple_result(item.match(re),
                              item, where, :regexp_not_matched)
              end
          end
        end
      in ".abnf" | ".abnfb"
        anno = :lhs
        r = validate1(item, lhs)
        if r[0]
            if String === item
              ok, v, vt = extract_value(rhs)
              # pp [:abnfex, rhs, ok, v, vt] if CDDLC_DEBUG
              if ok && (:text == vt || :bytes == vt)
                begin
                  ABNF_PARSER_FOR_STRING[v].validate(
                    item.dup.force_encoding(ABNF_ENCODING_FOR_CONOP[op]).codepoints.pack("U*"))
                  [true, item, {abnf: [v]}, [r]]
                rescue => e
                  # warn "*** #{e}" # XXX
                  [false, item, {abnf_not_matched: [v, e.to_s.force_encoding(Encoding::UTF_8)] }, [r]]
                end
              end
            end
        end

      else
        fail [:CONTROL_UNIMPLEMENTED, op, item, where].inspect
      end
    else
      warn [:UNIMPLEMENTED, item, where].inspect
      exit 1
    end || [false, item, {anno => [item, where]}, []]
  end

def scalar_type(item)
  case item
  in NilClass
    :null
  in FalseClass | TrueClass
    :bool
  in Integer
    :int
  in Float
    :float
  in String if item.encoding == Encoding::BINARY
    :bytes
  in String
    :text
  else
    nil
  end
end

FLOAT_AI_FROM_SIZE = {3 => 25, 5 => 26, 9 => 27}
SIMPLE_VALUE = {
  [:prim, 7, 20] => [true, false, :bool],
  [:prim, 7, 21] => [true, true, :bool],
  [:prim, 7, 22] => [true, nil, :nil],
}
SIMPLE_VALUE_SIMPLE = Set[23] + (0..19) + (32..255)
RANGE_EXCLUDE_END = {".." => false, "..." => true}

def simple_result(check, item, where, anno)
  if check
    [true, item, {}, []]
  else
    [false, item, {anno => [item, where]}, []]
  end
end

def biggify(d)                  # stand-in for real stand-ins
  t = 2               # assuming only 2/3 match an Integer
  if d < 0
    d = ~d
    t = 3
  end
  CBOR::Tagged.new(t, d == 0 ? "".b : d.digits(256).reverse!.pack("C*"))
end

def extract_bytes(bsqual, bsval)
  if bsqual == ""
    bsval.b
  else
    bsclean = bsval.gsub(/\s/, "")
    case bsqual
    in /\Ah\z/i
      bsclean.chars.each_slice(2).map{ |x| Integer(x.join, 16).chr("BINARY") }.join.b
    in /\Ab64\z/i
      begin
        Base64.urlsafe_decode64(bsclean)
      rescue ArgumentError => e
        {base64_error: [bsclean, e.to_s]}
      end
    else
      warn "*** Can't handle byte string type #{bsqual.inspect} yet"
    end
  end
end

def extract_value(wh)
  case wh
  in x if a = SIMPLE_VALUE[x]
    SIMPLE_VALUE[x]
  in ["number", num]
    [true, Integer(num), :int] rescue [true, Float(num), :float]
  in ["text", val]
    [true, val, :text]
  in ["bytes", val, _orig]
    eb = extract_bytes(*val)
    if String === eb
      [true, extract_bytes(*val), :bytes]
    else
      [false, eb]
    end
  in ["op", ".cat" | ".det" | ".plus", lhs, rhs]
    op = wh[1]
    expected_type = op == ".plus" ? Numeric : String;
    lhss, lhsv, lhst = extract_value(lhs)
    rhss, rhsv, rhst = extract_value(rhs)
    if !lhss || !rhss
      [false, {%i'UNSPECIFIC_#{op}' => [op, lhs, rhs]}]
    elsif [lhsv, rhsv].any? {!(expected_type === _1)}
      [false, {%i'BAD_TYPES_#{op}' => [op, lhs, rhs]}]
    else
      if op == ".det"
        lhsv = remove_indentation(lhsv)
        rhsv = remove_indentation(rhsv)
      end
      case [lhst, rhst]
      in [:text, :text] | [:bytes, :bytes]
        [true, lhsv + rhsv]
      in [:bytes, :text]
        [true, (lhsv + rhsv.b).b]
      in [:text, :bytes]
        result = lhsv + rhsv.force_encoding(Encoding::UTF_8)
        if result.valid_encoding?
          [true, result]
        else
          [false, {text_encoding_not_utf8: [lhst, lhsv, rhst, rhsv]}]
        end
      in [:int, _]
        [true, lhsv + Integer(rhsv)]
      in [:float, _]
        [true, lhsv + rhsv]
      end << lhst
    end
  else
    [false]
  end
end

def extract_array(t)
  case t
  in ["ary", ["seq", *members]]
  else
    return [false]
  end
  [true, *members.map { |el|
     case el
     in ["mem", _cut, _any, el4]
       ok, v, vt = extract_value(el4)
       return [false] unless ok
       [v, vt]
     else
       return [false]
     end
   }]
end


def extract_feature(control, d)
  ok, v, vt = extract_value(control)
  if ok
    nm = v
    det = d
    warn "*** feature controller should be a string: #{control.inspect}" unless :text == vt || :bytes == vt
  else
    ok, *v = extract_array(control)
    if ok && v.size == 2
      nm = v[0][0]
      det = v[1][0]
      warn "*** first element of feature controller should be a string: #{control.inspect}" unless String === nm
    else
      warn "*** feature controller not implemented: #{control.inspect}"
    end
  end
  [nm, det]
end

end
