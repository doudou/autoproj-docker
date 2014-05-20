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

            def initialize(image_name, tag_name)
                super(image_name)
                @tag_name = tag_name
            end

            # Remove a configuration variable that exists on the tag's parent image
            def remove_config(name)
                variables[name] = nil
            end
        end
    end
end

