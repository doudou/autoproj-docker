module Autoproj
    module Docker
        # Main build class
        class Build
            # @return [String] the build name
            attr_reader :build_name
            # @return [String] pattern used to generate image names. The pattern
            #   can contain one %s placeholder which is going to be replaced by
            #   the build name. The generated images are tagged using the source
            #   image names (such as image_name-tag_name)
            attr_reader :generated_image_pattern
            # @return [String] the directory containing data that should be
            #   available in the docker image. The files in this directory are
            #   available in the docker image inside the ressources/
            #   subdirectory
            attr_reader :ressources_dir
            # @return [ERB] the Dockerfile template
            attr_reader :dockerfile_template
            # @return [Array<TagConfig>] the set of docker images on which we
            #   should build
            attr_reader :images

            def self.load(build_name, generated_image_pattern, config_dir, images)
                template = ERB.new(File.read(File.join(config_dir, "Dockerfile.#{build_name}")))
                new(build_name, generated_image_pattern, File.join(config_dir, 'ressources'), template, images)
            end

            def initialize(name, generated_image_pattern, ressources_dir, dockerfile_template, images)
                @build_name, @generated_image_pattern, @ressources_dir, @dockerfile_template, @images =
                    name, generated_image_pattern, ressources_dir, dockerfile_template, images
            end

            def generated_image_name(image)
                generated_image_pattern % [build_name]
            end
            def generated_tag_name(image)
                "%s-%s" % [image.name, image.tag_name]
            end

            def progress(msg)
                puts msg
            end

            def run
                Dir.mktmpdir do |dir|
                    FileUtils.cp_r ressources_dir, File.join(dir, "ressources")
                    images.each do |image|
                        values = image.variables.map do |k, v|
                            if v.values.size > 1
                                raise ArgumentError, "something fishy: variable #{k} has more than one value"
                            elsif v.values.empty?
                                raise ArgumentError, "something fishy: variable #{k} has no value"
                            end
                            v.values.first
                        end
                        context = Struct.new(:image, *image.variables.keys).
                            new(image, *values)

                        template = self.dockerfile_template
                        dockerfile = context.instance_eval do
                            template.result(binding)
                        end
                        dockerimage = generated_image_name(image)
                        dockertag   = generated_tag_name(image)
                        File.open(File.join(dir, "Dockerfile"), 'w') do |io|
                            io.write dockerfile
                        end
                        progress "generating new image #{dockerimage}:#{dockertag} using #{build_name}"
                        pid = Process.spawn(
                            Hash.new,
                            "docker.io", "build", "-t", "#{dockerimage}:#{dockertag}", dir)
                        Process.wait(pid)
                    end
                end
            end

            def to_s; build_name end
        end
    end
end
