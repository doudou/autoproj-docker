module Autoproj
    module Docker
        # A whole configuration
        class Config
            # The set of known build images
            attr_reader :images
            # The directory containing both the Dockerfile templates and a
            # ressources/ directory that should be available inside the docker
            # image
            attr_accessor :config_dir
            # The set of builds defined
            attr_reader :builds

            def self.load(config_file)
                config_dir = File.expand_path(File.dirname(config_file))
                config = new(config_dir)
                config.instance_eval(File.read(config_file), config_file, 1)
                config
            end

            def initialize(config_dir)
                @config_dir = config_dir
                @images = Array.new
                @builds = Hash.new
            end

            # Sets or gets the docker username under which new images should be saved
            #
            # @overload username
            #   @return [String] the docker username
            # @overload username(name)
            #   @param [String] name the new username
            #   @return [String] the new docker username
            def username(name = nil)
                if !name then @username
                else @username = name
                end
            end

            # Defines a new build image
            #
            # A build image is a common set of builds that are generated using
            # the same docker image (can be different tags of the same image,
            # though). They share the same configuration variables and so on.
            #
            # It is usually one operating system (as e.g. ubuntu)
            #
            # @param [String] name the image name
            # @return [ImageConfig] the image configuration
            def image(name)
                image = ImageConfig.new(name)
                if block_given?
                    image.instance_eval(&proc)
                end
                images << image
                image
            end

            # Define a build
            #
            # A build is what is actually run to transform the docker images
            # into what autoproj-docker is meant to do.
            #
            # @param [String] name the image name
            # @yieldparam [TagConfig] a tag configuration
            # @yieldreturn [Boolean] true if the build should proceed on this
            #   tag, false otherwise
            # @return [ImageConfig] the image configuration
            def build(name, &filter)
                if !File.exists?(File.join(config_dir, "Dockerfile.#{name}"))
                    raise ArgumentError, "there is no Dockerfile.#{name} in #{config_dir}"
                end
                builds[name] = filter || proc { true }
            end

            # Resolves the raw configuration into a proper list of Build objects
            def resolve
                all_images = images.inject(Array.new) do |all, image|
                    all.concat(image.resolve)
                end
                builds.map do |build_name, filter|
                    applicable_images = all_images.find_all { |img| filter[img] }
                    Build.load(build_name,
                               "#{username}/%s",
                               config_dir,
                               applicable_images)
                end
            end
        end
    end
end
