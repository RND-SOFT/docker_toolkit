require_relative File.join($root, '../', 'lib', 'docker_toolkit.rb')

RSpec.describe DockerToolkit::Watcher do
  context 'examples' do
    ENV['PATH']="#{File.join($root, '../', 'bin')}:#{ENV['PATH']}"
    ENV['PATH']="#{File.join($root, 'fixtures', 'watcher')}:#{ENV['PATH']}"

    Dir.chdir File.join($root, 'fixtures', 'watcher') do
      Dir.glob('*.rb').sort.each do |file|
        name, exit_code = File.basename(file, '.rb').split('_')

        it "example #{name} with exit code #{exit_code}" do
          system("#{file} &> /dev/null")
          status = $?
          expect(status.exitstatus).to eq exit_code.to_i
        end

      end
    end

  end
end
