#!/usr/bin/env ruby
require "childprocess"
require 'English'

module DockerToolkit

class Watcher
  def initialize
    @lock = Mutex.new

    @procs = []
    @code = 0
    @crashed = false
    @threads = []
    @who = nil
    @stopping = false
  end

  def stop_all
    @stopping = true

    terminating = @procs.reject do |meta|
      meta[:handled] || meta[:process].exited?
    end
    
    terminating.each do |meta|
      ::Process.kill 'TERM', meta[:process].pid
    end

    terminating.each do |meta|
      begin
        meta[:process].poll_for_exit(10)
      rescue ChildProcess::TimeoutError
        meta[:process].stop(1)
        meta[:stdout].close
        meta[:stderr].close
      end
    end

    if !@crashed
      meta = @procs.detect do |meta|
        meta[:process].crashed?
      end

      if meta
        @crashed = true
        @code = meta[:process].exit_code
        @who = meta[:cmd]
      end
    end

  end


  def add *cmd
    process = ChildProcess.build(*cmd)

    rerr, werr = IO.pipe
    rout, wout = IO.pipe

    process.io.stdout = wout
    process.io.stderr = werr

    @procs.push(
      cmd: cmd,
      process: process,
      stdout: rout,
      stderr: rerr
    )
  end

  def synchro_readline io, out
    str = io.gets
    @lock.synchronize{out.puts str}
    true
  rescue => e
    false
  end

  def log msg
    puts "[watcher]: #{msg}"
  end

  def error msg
    STDERR.puts "[watcher]: Error: #{msg}"
  end


  def exec 
    %w[EXIT QUIT].each do |sig|
      trap(sig) do
        stop_all
      end
    end 


    %w[INT TERM].each do |sig|
      trap(sig) do
        with_tab do 
          log "Catch #{sig}: try exits gracefully.."
          stop_all
        end
      end
    end 

    trap("CLD") do |*args|
      unhandled = @procs.reject do |meta|
        meta[:handled] || !meta[:process].exited?
      end

      unhandled.any? do |meta|
        log "Child finished"
        log "  Process[#{meta[:pid]}]: #{meta[:cmd]}"
        log "    status: #{meta[:process].crashed? ? 'crashed' : 'exited'}"
        log "    code:   #{meta[:process].exit_code}"

        meta[:handled] = true
        meta[:stdout].close
        meta[:stderr].close

        if !@crashed && meta[:process].crashed?
          @crashed = true
          @code = meta[:process].exit_code
          @who = meta[:cmd]
        end

        if !@stopping
          log "Try exits gracefully.."
          stop_all
        end
        
        true
      end 
    end

    @procs.each do |meta|
      @threads << Thread.new(meta[:stdout], STDOUT) do |io, out|
        loop do
          break unless synchro_readline(io, out)
        end
      end

      @threads << Thread.new(meta[:stderr], STDERR) do |io, out|
        loop do
          break unless synchro_readline(io, out)
        end
      end

      meta[:pid] = meta[:process].start.pid
    end

    begin
      yield if block_given?
    rescue => e
      @crashed = true
      @code = 1
      error e.inspect
      log "Try exits gracefully.."
      stop_all
    end

    @threads.map(&:join)

    if @crashed
      @code = [@code || 0, 1].max
    end

    exit(@code || 0)
  end


end

end



