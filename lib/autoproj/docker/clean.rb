module Autoproj
    module Docker
        def self.clean
            containers = `docker.io ps -a`.split("\n")
            if !$?.success?
                raise "failed to run docker ps -a"
            end
            containers.shift
            containers = containers.map do |line|
                line.strip.split(/\s+/).first
            end
            puts "removing #{containers.size} containers"
            if !containers.empty?
                system("docker.io", "rm", *containers)
            end

            images = `docker.io images`.split("\n")
            if !$?.success?
                raise "failed to run docker images"
            end
            images = images.map do |line|
                if line =~ /^<none>/
                    line.split(/\s+/)[2]
                end
            end.compact
            puts "removing #{images.size} images"
            if !images.empty?
                system("docker.io", "rmi", *images)
            end
        end
    end
end
