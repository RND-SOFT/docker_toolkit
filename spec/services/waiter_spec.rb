require 'tmpdir'
require 'socket'
require 'English'
require 'securerandom'

RSpec.describe 'waiter.rb' do
  let(:waiter){ File.join($root, '../', 'bin', 'waiter.rb') }
  let(:waiter_cmd){ "#{waiter} -t3 -i1 --quiet " }

  around :each do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        example.run
      end
    end
  end

  def with_tcp_server
    terminate = false
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]

    thread = Thread.new do
      loop do
        break if terminate
        client = begin
          server.accept_nonblock
        rescue IO::EAGAINWaitReadable
          sleep 1
          nil
        end

        if client
          client.puts "Hello\n\n"
          client.close
        end
      end
    end

    yield(port)
  ensure
    terminate = true
    thread.terminate unless thread.join(2)
  end

  context 'TCP' do
    around :each do |example|
      with_tcp_server do |port|
        @port = port
        example.run
      end
    end

    let(:content){ SecureRandom.hex }
    let(:result_file){ "#{SecureRandom.hex}.result" }
    let(:exec_cmd){ "echo '#{content}' > #{result_file}" }

    it 'wait for TCP timedout' do
      system("#{waiter_cmd} --tcp localhost:#{@port + 11} -- #{exec_cmd}")
      expect($CHILD_STATUS.success?).to be_falsey
      expect(File.read(result_file)).not_to be eq content
    end

    it 'wait for TCP ok' do
      system("#{waiter_cmd} --tcp localhost:#{@port} -- #{exec_cmd}")
      expect($CHILD_STATUS.success?).to be_truthy
      expect(File.read(result_file).strip).to eq content
    end
  end
end
