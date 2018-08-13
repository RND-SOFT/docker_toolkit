#!/usr/bin/env ruby

module DockerToolkit

  module Runner

    def error(message)
      STDERR.puts "Error: #{message}"
    end

    def die(message)
      error(message)
      exit 1
    end

    def load_envs(string, env = ENV)
      envs Dotenv::Parser.new(string).call
      envs.each_pair do |k, v|
        env[k] = v
      end
      envs
    end

    def execute(cmd)
      `#{cmd}`
    end

    def execute!(cmd, error = nil)
      output = execute(cmd)
      $CHILD_STATUS.success? || die(error || "Can't execute: #{cmd}")
      output
    end

    def ensure_env_defined!(key, env = ENV)
      env.key?(key) || die("Environment variable #{key} must present!")
      env[key]
    end

  end

end
