module Sord
  module Resolver
    def self.prepare
      # Construct a hash of class names to full paths
      @@names_to_paths ||= YARD::Registry.all(:class)
        .map { |item| [item.name, item.path] }
        .group_by(&:first)
        .to_h
    end

    def self.paths_for(name)
      prepare
      @@names_to_paths[name]
    end

    def self.path_for(name)
      paths_for(name).one? ? paths_for(name).first : nil
    end

    def self.builtin_classes
      Object.constants
        .map(&:to_s)
        .select { |x| /[a-z]/ === x }
    end

    def self.resolvable?(name, item, include_builtins = true)
      # Check if it's a builtin
      return true if include_builtins && builtin_classes.include?(name)

      name_parts = name.split('::')

      current_context = item
      loop do
        # Try to find that class in this context
        path_followed_context = current_context
        name_parts.each do |name_part|
          path_followed_context = path_followed_context&.child(name_part)
        end

        # Return true if we found the constant we're looking for here
        return true if path_followed_context

        # Move up one context
        return false if current_context.root?
        current_context = current_context.parent
      end
    end
  end
end
