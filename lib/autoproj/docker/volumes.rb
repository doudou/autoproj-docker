module Autoproj
    module Docker
        # Representation of the action of mounting a volume from a named volume
        # container
        class VolumeFrom
            # @return [String] name of the volume container that should be
            #   mounted
            attr_reader :name

            def initialize(name)
                @name = name
            end

            # Mounts the volume on the following image and return an image ID
            #
            # @param [String] the source image ID
            # @return [String] the generated image ID
            def apply(image_name)
                container_id = Docker.run('run', "-d", "--volumes-from=#{name}", image_name, "true").strip
                Docker.run('wait', container_id)
                Docker.run('commit', container_id).strip
            end
        end

        class VolumeMount
            # @return [String] name of the local directory that should be
            #   mounted in the container
            attr_reader :local_dir
            # @return [String] name of the container directory on which
            #   {#local_dir} should be mounted
            attr_reader :container_dir

            def initialize(local_dir, container_dir)
                @local_dir, @container_dir = local_dir, container_dir
            end

            # Mounts the volume on the following image and return an image ID
            #
            # @return [String] the generated image ID
            def apply(image_name)
                container_id = Docker.run('run', "-d", "-v", "#{local_dir}:#{container_dir}", image_name, "true").strip
                Docker.run('wait', container_id)
                Docker.run('commit', container_id).strip
            end
        end
    end
end

