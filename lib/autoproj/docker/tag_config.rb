module Autoproj
    module Docker
        # A tag configuration
        #
        # This specializes ImageConfig for a given image tag (instead of simply
        # a whole image)
        #
        # It allows to override / remove configuration variables that are
        # defined globally on the image configuration, but need to be modified
        # for this specific tag
        #
        # It is usually created and configured using ImageConfig#tag
        class TagConfig < ImageConfig
            # @return [String] the tag name
            attr_reader :tag_name
            # @return [String] the tag of the docker image
            attr_reader :docker_tag_name

            def initialize(image_name, tag_name)
                super(image_name)
                @tag_name = tag_name
                @docker_tag_name = tag_name
            end

            # Sets or gets the tag name used in the generated image
            def docker_tag_name(name = nil)
                if name
                    @docker_tag_name = name
                end
                @docker_tag_name
            end

            # Remove a configuration variable that exists on the tag's parent image
            def remove_config(name)
                variables[name] = nil
            end

            def pretty_print(pp)
                pp.text "#{name}:#{tag_name}"
                pp.nest(2) do
                    pp.breakable
                    pp.text "docker: #{docker_name}:#{docker_tag_name}"
                    pp.breakable
                    pp.text "tags"
                    pp.nest(2) do
                        variables.each do |k, v|
                            pp.breakable
                            pp.text "#{k}=#{v}"
                        end
                    end
                end
            end
        end
    end
end

