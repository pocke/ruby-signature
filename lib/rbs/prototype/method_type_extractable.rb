module RBS
  module Prototype
    module MethodTypeExtractable
      def function_return_type_from_body(node)
        body = node.children[2]
        return Types::Bases::Nil.new(location: nil) unless body

        literal_to_type(body)
      end

      def literal_to_type(node)
        case node.type
        when :STR
          lit = node.children[0]
          if lit.match?(/\A[ -~]+\z/)
            Types::Literal.new(literal: lit, location: nil)
          else
            BuiltinNames::String.instance_type
          end
        when :DSTR, :XSTR
          BuiltinNames::String.instance_type
        when :DSYM
          BuiltinNames::Symbol.instance_type
        when :DREGX
          BuiltinNames::Regexp.instance_type
        when :TRUE
          BuiltinNames::TrueClass.instance_type
        when :FALSE
          BuiltinNames::FalseClass.instance_type
        when :NIL
          Types::Bases::Nil.new(location: nil)
        when :LIT
          lit = node.children[0]
          name = lit.class.name
          case lit
          when Symbol
            if lit.match?(/\A[ -~]+\z/)
              Types::Literal.new(literal: lit, location: nil)
            else
              BuiltinNames::Symbol.instance_type
            end
          when Integer
            Types::Literal.new(literal: lit, location: nil)
          else
            type_name = TypeName.new(name: name, namespace: Namespace.root)
            Types::ClassInstance.new(name: type_name, args: [], location: nil)
          end
        when :ZLIST, :ZARRAY
          BuiltinNames::Array.instance_type([untyped])
        when :LIST, :ARRAY
          elem_types = node.children.compact.map { |e| literal_to_type(e) }
          t = types_to_union_type(elem_types)
          BuiltinNames::Array.instance_type([t])
        when :DOT2, :DOT3
          types = node.children.map { |c| literal_to_type(c) }
          type = range_element_type(types)
          BuiltinNames::Range.instance_type([type])
        when :HASH
          list = node.children[0]
          if list
            children = list.children.compact
          else
            children = []
          end

          key_types = []
          value_types = []
          children.each_slice(2) do |k, v|
            key_types << literal_to_type(k)
            value_types << literal_to_type(v)
          end

          if key_types.all? { |t| t.is_a?(Types::Literal) }
            fields = key_types.map { |t| t.literal }.zip(value_types).to_h
            Types::Record.new(fields: fields, location: nil)
          else
            key_type = types_to_union_type(key_types)
            value_type = types_to_union_type(value_types)
            BuiltinNames::Hash.instance_type([key_type, value_type])
          end
        else
          untyped
        end
      end

      def types_to_union_type(types)
        return untyped if types.empty?
        return untyped if types.include?(untyped)

        Types::Union.new(types: types.uniq, location: nil)
      end

      def range_element_type(types)
        types = types.reject { |t| t == untyped }
        return untyped if types.empty?

        types = types.map do |t|
          if t.is_a?(Types::Literal)
            type_name = TypeName.new(name: t.literal.class.name, namespace: Namespace.root)
            Types::ClassInstance.new(name: type_name, args: [], location: nil)
          else
            t
          end
        end.uniq

        if types.size == 1
          types.first
        else
          untyped
        end
      end

      def untyped
        @untyped ||= Types::Bases::Any.new(location: nil)
      end
    end
  end
end
