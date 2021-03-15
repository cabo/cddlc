require_relative "parser/cddl-util.rb"

class CDDL
  @@parser = CDDLGRAMMARParser.new

  def self.reason(parser, s)
    reason = [parser.failure_reason]
    parser.failure_reason =~ /^(Expected .+) after/m
    reason << "#{$1.gsub("\n", '<<<NEWLINE>>>')}:" if $1
    if line = s.lines.to_a[parser.failure_line - 1]
      reason << line
      reason << "#{'~' * (parser.failure_column - 1)}^"
    end
    reason.join("\n")
  end

  def self.from_cddl(s)
    ast = @@parser.parse s
    if !ast
      fail self.reason(@@parser, s)
    end
    CDDL.new(ast)
  end

  attr_accessor :ast, :tree
  def initialize(ast_)
    @ast = ast_
    @tree = ast.ast
    @rules = nil                # only fill in if needed
  end

  RULE_OP_TO_CHOICE = {"/=" => "tcho", "//=" => "gcho"}

  def rules
    if @rules.nil?              # memoize
      @rules = {}
      fail unless @tree.first == "cddl"
      @tree[1..-1].each do |x|
        op, name, val, rest = x
        cho = RULE_OP_TO_CHOICE[op]
        fail rest if rest
        fail name unless Array === name
        case name[0]
        when "name"
          fail unless name.size == 2
          name = name[1]
        when "gen"
          name = name[1..-1]
        else
          fail name
        end
        @rules[name] =
          if old = @rules[name]
            fail "duplicate rule for name #{name}" unless cho
            if Array === old && old[0] == cho
              old.dup << val
            else
              [cho, old, val]
            end
          else
            val
          end
      end
      # warn "** rules #{rules.inspect}"
    end
    @rules
  end

end
