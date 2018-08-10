require "ffi"
require "rbconfig"

module DockerToolkit
module ChildProcess
  module Windows
    module Lib
      extend FFI::Library

      def self.msvcrt_name
        host_part = RbConfig::CONFIG['host_os'].split("_")[1]
        manifest  = File.join(RbConfig::CONFIG['bindir'], 'ruby.exe.manifest')

        if host_part && host_part.to_i > 80 && File.exists?(manifest)
          "msvcr#{host_part}"
        else
          "msvcrt"
        end
      end

      ffi_lib "kernel32", msvcrt_name
      ffi_convention :stdcall


    end # Library
  end # Windows
end # ChildProcess
end DockerToolkit

require "docker_toolkit/childprocess/windows/lib"
require "docker_toolkit/childprocess/windows/structs"
require "docker_toolkit/childprocess/windows/handle"
require "docker_toolkit/childprocess/windows/io"
require "docker_toolkit/childprocess/windows/process_builder"
require "docker_toolkit/childprocess/windows/process"
