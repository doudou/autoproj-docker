module Autoproj
    module Docker
        # Main build class
        class Build
            # @return [String] the build name
            attr_reader :build_name
            # @return [String] the directory containing data that should be
            #   available in the docker image. The files in this directory are
            #   available in the docker image inside the ressources/
            #   subdirectory
            attr_reader :ressources_dir
            # @return [String] the directory in which the log files should be
            #   saved
            attr_reader :logfile_dir
            # @return [ERB] the Dockerfile template
            attr_reader :dockerfile_template

            # @return [String] the username under which the generated docker
            #   images should be stored. It is effective only if
            #   {#target_id_pattern} uses it, which is the default
            attr_reader :username
            # @return [#call] object used to generate the source ID based
            #   on the build configuration and image.
            attr_accessor :source_id_generator
            # @return [#call] object used to generate the target ID based
            #   on the build configuration and image.
            attr_accessor :target_id_generator

            # @overload filter { |image| ... }
            #   Sets a filter block, that is a filter object that, given an
            #   ImageConfig object returns whether it should be built (true) or
            #   not (false)
            #
            # @overload filter
            #   Returns the current filter block
            def filter
                if block_given?
                    @filter = proc
                else
                    @filter
                end
            end

            def self.default_source_id_generator(build, image)
                [image.docker_name, image.docker_tag_name].compact.join(":")
            end

            def self.default_target_id_generator(build, image, options = Hash.new)
                variables = image.metadata.dup
                variables.delete 'image_name'
                variables.delete 'docker_image_name'
                variables.delete 'tag_name'
                variables.delete 'docker_tag_name'
                Array(options[:ignore]).each do |key|
                    variables.delete key
                end
                variables = variables.map { |k, v| "#{k}=#{v}" }
                "#{build.username}/#{build.build_name}:#{image.name}-#{image.tag_name}_#{variables.join("_")}"
            end

            def self.load(build_name, username, config_dir)
                template = ERB.new(File.read(File.join(config_dir, "Dockerfile.#{build_name}")))
                new(build_name, username, File.join(config_dir, 'ressources'), template)
            end

            def initialize(name, username, ressources_dir, dockerfile_template)
                @build_name, @username, @ressources_dir, @dockerfile_template =
                    name, username, ressources_dir, dockerfile_template
                @logfile_dir = File.expand_path(File.join('..', 'log'), ressources_dir)
                @source_id_generator = self.class.method(:default_source_id_generator)
                @target_id_generator = self.class.method(:default_target_id_generator)
                @filter = proc { true }
            end

            def metadata
                Hash['build_name' => build_name]
            end

            def pretty_print(pp)
                pp.text build_name
            end

            # @return the autoproj-docker build from which this build should
            #   start
            # @see from_build
            attr_reader :source_build

            # Declares that this build should use the images already created by
            # another autoproj-docker build
            #
            # It is assumed that the builds share the same target_id_generator
            # and username
            #
            # @option options [Array<String>] :ignore list of metadata entries
            #    that should be ignored to find the original build. This is needed
            #    if the new build has a different set of configuration options than
            #    the original one
            def from_build(name, options = Hash.new)
                @source_build = [name, options]
            end

            def generate_source_id(image)
                if source_build
                    source_build_name, options = source_build
                    fake_build = Struct.new :build_name, :username
                    fake_build = fake_build.new(source_build_name, username)
                    target_id_generator.call(fake_build, image, options).strip
                else
                    source_id_generator.call(self, image).strip
                end
            end

            def generate_target_id(image)
                target_id_generator.call(self, image).strip
            end

            module TemplateProcessing
                def process_template(file)
                    content = ERB.new(File.read(file)).result(binding)
                    File.open(File.join(dir, file), 'w') do |io|
                        io.write content
                    end
                    file
                end
            end

            def generate_dockerfile(dir, source_image_id, target_image_id, image)
                values = image.variables.map do |k, v|
                    if v.values.size > 1
                        raise ArgumentError, "something fishy: variable #{k} has more than one value"
                    elsif v.values.empty?
                        raise ArgumentError, "something fishy: variable #{k} has no value"
                    end
                    v.values.first
                end
                context = Struct.new(:dir, :source_image_id, :target_image_id, :image, *image.variables.keys).
                    new(dir, source_image_id, target_image_id, image, *values)
                context.extend TemplateProcessing

                template = self.dockerfile_template
                context.instance_eval do
                    template.result(binding)
                end
            end

            def progress(msg)
                puts msg
            end

            def run(images)
                Dir.mktmpdir do |dir|
                    FileUtils.cp_r ressources_dir, File.join(dir, "ressources")
                    images.each do |image|
                        if !filter[image]
                            progress "filtered out: #{image} on build #{build_name}"
                            next
                        end

                        source_image_id = generate_source_id(image)
                        target_image_id = generate_target_id(image)

                        # Now apply any volume mounts
                        source_image_id = image.volumes.inject(source_image_id) do |id, vol|
                            vol.apply(id)
                        end

                        dockerfile = generate_dockerfile(dir, source_image_id, target_image_id, image)
                        File.open(File.join(dir, "Dockerfile"), 'w') do |io|
                            io.write dockerfile
                        end
                        logfile_basename = target_image_id.gsub(/[^\w]/, '_')
                        logfile_path = File.join(logfile_dir, "#{logfile_basename}.log")
                        FileUtils.mkdir_p(File.dirname(logfile_path))
                        progress "generating new image #{target_image_id} using #{build_name}"
                        progress "  output redirected to #{logfile_path}"
                        pid = File.open(logfile_path, 'w') do |logfile|
                            Process.spawn(
                                Hash.new,
                                "docker.io", "build", '--no-cache', "-t", "#{target_image_id}", dir,
                                STDOUT => logfile, STDERR => logfile)
                        end
                        Process.wait(pid)
                        result = $?
                        if result.success?
                            progress "  success"
                        else
                            progress "  failed"
                        end
                    end
                end
            end

            def to_s; build_name end

            def self.parse_filters(*args)
                filters = args.map do |filter_str|
                    case filter_str
                    when /=/ # exact filter
                        var_name, matcher = filter_str.split("=")
                    when /~/ # regexp filter
                        var_name, matcher = filter_str.split("~")
                        matcher = Regexp.new(matcher)
                    end
                    puts "matching #{var_name} with #{matcher}"
                    [var_name, matcher]
                end

                lambda do |build, image|
                    meta = build.metadata.merge(image.metadata)
                    filters.all? do |var_name, matcher|
                        if value = meta[var_name]
                            matcher === value.to_s
                        else false
                        end
                    end
                end
            end
        end
    end
end

