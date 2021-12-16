module Sord
  class Commentator
    # @return [Boolean]
    attr_accessor :keep_original_comments

    # @return [Parlour::TypedObject]
    attr_accessor :typed_object

    # @return [YARD::CodeObjects::NamespaceObject]
    attr_accessor :item

    # @return [YARD::Docstring::DocstringParser]
    attr_accessor :parser

    # @return [Array<String>]
    attr_accessor :docs

    # @param [YARD::CodeObjects::NamespaceObject] item
    # @param [Parlour::TypedObject] typed_object
    # @param [Boolean] keep_original_comments
    def initialize(item:, typed_object:, keep_original_comments:)
      self.keep_original_comments = keep_original_comments
      self.typed_object = typed_object
      self.item = item
    end

    # Adds comments to an object based on a docstring.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @param [Parlour::TypedObject] typed_object
    # @return [void]
    def self.add(item:, typed_object:, keep_original_comments:)
      new(
        item: item,
        typed_object: typed_object,
        keep_original_comments: keep_original_comments
      ).add
    end

    def add
      if keep_original_comments
        typed_object.add_comments(item.docstring.all.split("\n"))
      else
        add_comments_from_yard
      end
    end

    private

    def add_comments_from_yard
      self.parser = YARD::Docstring.parser
      parser.parse(item.docstring.all)
      self.docs = parser.text.split("\n")

      add_param_tags
      add_return_tags
      add_example_tags
      add_note_tags
      add_see_tags

      # fix: yard text may contains multiple line. should deal \n.
      # else generate text will be multiple line and only first line is commented
      self.docs =
        docs.flat_map { |line| line.empty? ? [''] : line.split("\n") }
      typed_object.add_comments(docs)
    end

    def add_see_tags
      see_tags = parser.tags.select { |tag| tag_for?(tag, 'see') }
      docs << '' if blank_line_required?(see_tags)
      see_tags.each do |see_tag|
        docs << '' if docs.last != ''

        # Output note/deprecated/see in the form of:
        # _@see_ `B` — Lorem ipsum.
        # _@see_ `B`
        if see_tag.text.nil?
          docs << "_@see_ `#{see_tag.name}`"
        else
          docs << "_@see_ `#{see_tag.name}` — #{see_tag.text}"
        end
      end
    end

    def add_note_tags
      notice_tags =
        parser.tags.select do |tag|
          tag_for?(tag, 'note') || tag_for?(tag, 'deprecated')
        end
      docs << '' if blank_line_required?(notice_tags)
      notice_tags.each do |notice_tag|
        docs << '' if docs.last != ''

        # Output note/deprecated/see in the form of:
        # _@note_ — Lorem ipsum.
        # _@note_
        if notice_tag.text.nil?
          docs << "_@#{notice_tag.tag_name}_"
        else
          docs << "_@#{notice_tag.tag_name}_ — #{notice_tag.text}"
        end
      end
    end

    # Add a blank line if there's anything before the params.
    def blank_line_required?(tags)
      docs.last != '' && docs.length.positive? && tags.length.positive?
    end

    def add_example_tags
      examples = parser.tags.select { |tag| tag_for?(tag, 'example') }
      docs unless examples.length.positive?
      examples.each do |example|
        # Only add a blank line if there's anything before the example.
        docs << '' if docs.length.positive?

        # Include the example's 'name' if there is one.
        unless example.name.nil? || example.name == ''
          docs << example.name
        end
        docs << '```ruby'
        docs.concat(example.text.split("\n"))
        docs << '```'
      end
    end

    def add_return_tags
      returns =
        parser.tags.select do |tag|
          tag_for?(tag, 'return') && !tag.text.nil? && tag.text.strip != ''
        end
      docs << '' if blank_line_required?(returns)
      returns.each do |retn|
        docs << '' if docs.last != '' && docs.length.positive?

        # Output returns in the form of:
        # _@return_ — Lorem ipsum.
        docs << "_@return_ — #{retn.text}"
      end
    end

    def add_param_tags
      params =
        parser.tags.select { |tag| tag_for?(tag, 'param') && !tag.name.nil? }
      docs << '' if blank_line_required?(params)
      params.each do |param|
        docs << '' if docs.last != '' && docs.length.positive?

        # Output params in the form of:
        # _@param_ `foo` — Lorem ipsum.
        # _@param_ `foo`
        if param.text.nil? || param.text == ''
          docs << "_@param_ `#{param.name}`"
        else
          docs <<
            "_@param_ `#{param.name}` — #{param.text.gsub("\n", ' ')}"
        end
      end
    end

    def tag_for?(tag, name)
      tag.tag_name == name && tag.is_a?(YARD::Tags::Tag)
    end
  end
end
