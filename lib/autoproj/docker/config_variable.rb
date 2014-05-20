module Autoproj
    # Class handling possible configurations
    class ConfigVariable
        # @return [String] the variable name
        attr_reader :name
        # @return [Array] the set of possible values
        attr_reader :values

        def initialize(name)
            @name = name
            @values = Array.new
        end

        def add(v)
            values << v
        end
    end
end
