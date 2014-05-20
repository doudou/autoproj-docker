module Autoproj
    module Docker
        # A build image
        #
        # Builds images are sets of builds that are all created from the same
        # docker image, under the same image name
        #
        # It can represent multiple builds as autoproj-docker works in a matrix
        # way (as e.g. jenkins). The #variables hash contains all the matrix
        # dimensions as well as their possible values. Specific builds can
        # constrain which parts of the matrix apply to itself.
        class ImageConfig
            # The user-visible name of the image
            attr_reader :name
            # The set of tags configured on this image
            attr_reader :tags
            # The set of configuration variables
            attr_reader :variables

            def initialize(name)
                @name   = name
                @docker_name = name
                @tags   = Hash.new
                @variables = Hash.new
            end

            # Sets or gets the docker image that is the source of all of the sub-images
            def docker_name(name = nil)
                if name
                    @docker_name = name
                else @docker_name
                end
            end

            # Sets up a configuration variable that will be applied on every tag.
            # It can be overriden on a specific tag
            def config(name, &block)
                config = ConfigVariable.new(name)
                if block
                    config.instance_eval(&block)
                end
                variables[name] = config
            end

            # Sets up a tag
            #
            # The provided block can be used to override some configuration
            # variables
            def tag(tag_name, &block)
                tag = TagConfig.new(name, tag_name)
                tag.docker_name(docker_name)
                if block_given?
                    tag.instance_eval(&block)
                end
                tags[tag_name] = tag
            end

            def resolve_variable_matrix(variables)
                if variables.empty?
                    return [yield(Hash.new)].flatten
                end

                variables = variables.dup
                key, values = variables.shift
                values.values.map do |v|
                    config_variable = ConfigVariable.new(key)
                    config_variable.values[0] = v
                    resolve_variable_matrix(variables) do |resolved_v|
                        yield(Hash[key => config_variable].merge(resolved_v))
                    end
                end.flatten
            end

            # Return the list of TagConfig objects that represent what has been defined
            def resolve
                tags = self.tags
                if tags.empty?
                    tags = [['latest', TagConfig.new(name, 'latest')]]
                end
                tags.map do |_, tag|
                    variables = self.variables.dup
                    variables.merge! tag.variables
                    variables.delete_if { |_, t| !t }

                    resolve_variable_matrix(variables) do |var|
                        resolved = TagConfig.new(tag.name, tag.tag_name)
                        resolved.docker_name(tag.docker_name)
                        resolved.docker_tag_name(tag.docker_tag_name)
                        resolved.variables.merge!(var)
                        resolved
                    end
                end.flatten
            end
        end
    end
end

