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
            def tag(tag_name)
                tag = TagConfig.new(name, tag_name)
                if block_given?
                    tag.instance_eval(&block)
                end
                tags[tag_name] = tag
            end

            # Return the list of TagConfig objects that represent what has been defined
            def resolve
                tags = self.tags
                if tags.empty?
                    tags = [['latest', TagConfig.new(name, 'latest')]]
                end
                tags.map do |_, tag|
                    resolved = TagConfig.new(tag.name, tag.tag_name)
                    resolved.docker_name(docker_name)
                    resolved.variables.merge!(variables)
                    resolved.variables.merge!(tag.variables)
                    resolved.variables.delete_if do |_, t|
                        !t
                    end
                    resolved
                end
            end
        end
    end
end

