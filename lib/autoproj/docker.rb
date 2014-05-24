require 'erb'
require 'yaml'
require 'optparse'
require 'tmpdir'

require 'autoproj/docker/config'
require 'autoproj/docker/config_variable'
require 'autoproj/docker/image_config'
require 'autoproj/docker/tag_config'
require 'autoproj/docker/build'
require 'autoproj/docker/clean'
require 'autoproj/docker/volumes'

module Autoproj
    module Docker
        # @return [String] the path to the docker executable. Defaults to
        #   docker.io (the name of it on Debian/Ubuntu)
        attr_accessor :docker
        module_function :docker
        @docker = 'docker.io'

        class RunError < RuntimeError; end

        def self.run(*args)
            result = `#{docker} '#{args.join("' '")}'`
            if !$?.success?
                raise RunError, "failed to run #{args.join(" ")}"
            end
            result
        end
    end
end

