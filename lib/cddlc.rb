require_relative "parser/cddl-util.rb"
require_relative "processor/cddl-visitor.rb"
require_relative 'processor/cddl-undefined.rb'

class CDDL
  @@parser = CDDLGRAMMARParser.new

  DATA_DIR = Pathname.new(__FILE__) + "../../data/"
  # empty string is for CDDL::DATA_DIR
  CDDL_INCLUDE_PATH = ENV["CDDL_INCLUDE_PATH"] || ".:"

  def self.cddl_include_path
    CDDL_INCLUDE_PATH.split(":", -1).map {_1 == "" ? CDDL::DATA_DIR : Pathname.new(_1)}
  end

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

  # (keeps only renamed rules)
  def rename(rename_map)
    rules.replace(
      Hash[rename_map.map do |o, n|
             [n, visit(rules[o]) do |prod|
                case prod
                in ["name", *] | ["gen", *]
                  prod[1] = rename_map[prod[1]] || prod[1]
                else
                end
                false
              end]
           end])
  end

  SAFE_FN = /\A[-._a-zA-Z0-9]+\z/

  def self.from_cddl(s)
    ast = @@parser.parse s
    if !ast
      fail self.reason(@@parser, s)
    end
    if $options.cddl2
      directives = s.lines.grep(/^;# /).map(&:chomp).map{|l| l.sub(/^;#\s+/, '').split(/\s+/)}
      # puts directives.to_yaml
    end
    ret = CDDL.new(ast, directives)

    if $options.cddl2
      ret.directives.each do |di|
        preferred_tag = nil
        case di
        in ["include" => dir, docref]
        in ["include" => dir, docref, "as", preferred_tag]
        in ["import" => dir, docref]
        in ["import" => dir, docref, "as", preferred_tag]
        else
          warn "** Can't parse include directive #{di.inspect}"
          next
        end
        unless docref =~ SAFE_FN
          warn "** skipping unsafe filename #{docref}"
          next
        end
        puts "PREFERRED_TAG #{preferred_tag}" if $options.verbose
        puts "DOCREF #{docref}" if $options.verbose
        fn = docref.downcase << ".cddl"

        io = nil
        CDDL::cddl_include_path.each do |path|
          begin
            io = (path + fn).open
            break
          rescue Errno::ENOENT
            next
          end
        end
        unless io
          warn "** include file #{fn} not found in #{CDDL::cddl_include_path.map(&:to_s)}"
          next
        end

        include_file = io.read
        included_cddl = CDDL.from_cddl(include_file)
        if preferred_tag
          included_cddl = included_cddl.deep_clone # needed?
          renamed_names = included_cddl.rules.keys
          name_rename = Hash[
            renamed_names.map { |o|
              n = "#{preferred_tag}.#{o}"
              warn "** Warning: renamed name #{n} already in #{fn}" if included_cddl.rules[n]
              [o, n]}]
          included_cddl.rename(name_rename)
        end

        case dir
        in "import"
          warn "** IMPORTING #{fn}" if $options.verbose
          undef_rule = nil
          loop do
            undef_rule = ret.cddl_undefined # XXX square...
            # p undef_rule
            got_more = false
            undef_rule.each do |name|
              if rule = included_cddl.rules[name]
                ret.rules[name] = rule
                warn "IMPORTED #{name} from #{fn}" if $options.verbose
                got_more = true
              end
            end
            break unless got_more
          end
          if preferred_tag
            undef_rule.each do |name|
              warn "** Warning: undefined reference #{name} without namespace prefix is defined in namespaced imported module #{fn}" if name_rename[name]
            end
          end
        in "include"
          warn "** INCLUDING #{fn}" if $options.verbose
          included_cddl.rules.each do |k, v|
            if old = ret.rules[k]
              if old != v
                warn "** included rule #{k} = #{v} would overwrite #{old}"
              end
            else
              ret.rules[k] = v
            end
          end
        end
      end
    end
    ret
  end

  attr_accessor :ast, :tree, :directives
  def initialize(ast_, directives_ = [])
    @ast = ast_
    @tree = ast.ast
    @rules = nil                # only fill in if needed
    @directives = directives_
  end

  def deep_clone
    Marshal.load(Marshal.dump(self))
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
          parmnames = name[2..-1]
          name = name[1]        # XXX update val with parm/arg
          val = ["parm", parmnames,
                 visit(val) do |p|
                   case p
                   in ["name", nm]
                     if ix = parmnames.index(nm)
                       [true, ["arg", ix]]
                     end
                   else
                     false
                   end
                 end]
        else
          fail name
        end
        @rules[name] =
          if (old = @rules[name]) && old != val
            fail "duplicate rule for name #{name} #{old.inspect} #{val.inspect}" unless cho
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

  def prelude
    if @prelude.nil?
      @prelude = CDDL.from_cddl(File.read(DATA_DIR + "prelude.cddl"))

    end
    @prelude
  end
end
