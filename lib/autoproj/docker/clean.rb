module Autoproj
    module Docker
        def self.clean
            # Look for a .dockerkeep command
            if File.exists?(".dockerkeep")
                keep_pattern = File.readlines(".dockerkeep").
                    map do |line|
                        line = line.strip
                        next if line.empty? || line =~ /^#/
                        Regexp.new(line)
                    end.compact
            end

            containers = `docker.io ps -a`.split("\n").
                map { |line| line.strip }
            if !$?.success?
                raise "failed to run docker ps -a"
            end
            containers.shift
            containers = containers.
                find_all { |line| !keep_pattern.any? { |rx| rx === line } }.
                map { |line| line.strip.split(/\s+/).first }
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
