module Autoproj
    # Class handling possible configurations
    class ConfigVariable
        # @return [String] the variable name
        attr_reader :name
        # @return [Array] the set of possible values
        attr_reader :values
        # @return [Array] the set of metadata names that should be used in place
        #   of the value in #values
        attr_reader :metadata

        def initialize(name)
            @name = name
            @values = Array.new
            @metadata = Array.new
        end

        def add(v, options = Hash.new)
            values << v
            meta =
                if options.has_key?(:metadata)
                    options[:metadata]
                else v
                end
            metadata << meta
        end
    end
end
