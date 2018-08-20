#!/usr/bin/env ruby

require 'English'

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
      envs = Dotenv::Parser.new(string).call
      envs.each_pair do |k, v|
        env[k] = v
      end
      envs
    end

    def execute(cmd)
      puts "Executing: #{cmd}"
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

    def envsubst(*paths)
      paths = paths.flatten.map{|c| c.to_s.strip }.reject(&:empty?)
      paths.each do |path|
        Dir.glob("#{path}/**/*.in") do |templ|
          output = templ.sub(/\.in$/, '')
          cmd = "cat '#{templ}' | envsubst > '#{output}'"
          system(cmd) || die("envsubst failed: #{cmd}")
        end
      end
    end

    def envsubst_file(templ, output = nil)
      output ||= templ.sub(/\.in$/, '')
      die('filename must ends with .in or output must be provided') if output.strip == templ.strip
      cmd = "cat '#{templ}' | envsubst > '#{output}'"
      system(cmd) || die("envsubst failed: #{cmd}")
    end

  end

end
