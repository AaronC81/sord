require 'stringio'

module Sord
  module Resolver
    def self.prepare
      # Construct a hash of class names to full paths
      @@names_to_paths ||= YARD::Registry.all(:class)
        .group_by(&:name)
        .map { |k, v| [k.to_s, v.map(&:path)] }
        .to_h
        .merge(builtin_classes.map { |x| [x, [x]] }.to_h) do |k, a, b|
          a | b
        end
    end

    def self.paths_for(name)
      prepare
      (@@names_to_paths[name.split('::').last] || [])
        .select { |x| x.end_with?(name) }
    end

    def self.path_for(name)
      paths_for(name).one? ? paths_for(name).first : nil
    end

    def self.builtin_classes
      # This prints some deprecation warnings, so suppress them
      prev_stderr = $stderr
      $stderr = StringIO.new

      Object.constants
        .select { |x| Object.const_get(x).is_a?(Class) }
        .map(&:to_s)
    rescue
      $stderr = prev_stderr
    end

    def self.resolvable?(name, item)
      name_parts = name.split('::')

      current_context = item
      current_context = current_context.parent \
        until current_context.is_a?(YARD::CodeObjects::NamespaceObject)

      matching_paths = []

      loop do
        # Try to find that class in this context
        path_followed_context = current_context
        name_parts.each do |name_part|
          path_followed_context = path_followed_context&.child(
            name: name_part, type: [:class, :method, :module]
          )
        end

        # Return true if we found the constant we're looking for here
        matching_paths |= [path_followed_context.path] if path_followed_context

        # Move up one context
        break if current_context.root?
        current_context = current_context.parent
      end

      return (builtin_classes.include?(name) && matching_paths.empty?) ||
        (matching_paths.one? && !builtin_classes.include?(name))
    end
  end
end
