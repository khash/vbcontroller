require 'rubygems'
require 'open4'
require 'net/http'
require 'fileutils'

class VbController

	def initialize(vm_folder)
		@vm_folder = vm_folder
		@local_vm_folder = File.expand_path('~/.vbcontroller')
		
		FileUtils.mkdir_p(@local_vm_folder)
	end
	
	def start(name)
		# import it from repo if not available
		unless is_available?(name)
			download(name)
		end
		
		import(File.join(@local_vm_folder, name, "#{name}.ova"), name)
		
			# start the box
		run("VBoxManage startvm #{name}")
		
		# get and return the IP
		ip = run_and_wait("VBoxManage guestproperty get #{name} '/VirtualBox/GuestInfo/Net/0/V4/IP' | awk '{ print $2 }'")
		puts ip
		
		return ip
	end
	
	def shutdown(name)
		# shutdown
		run_and_wait("VBoxManage controlvm #{name} poweroff")
		
		# unregister
		run_and_wait("VBoxManage unregistervm '#{@vm_folder}/#{name}/#{name}.vbox'")
		
		run_and_wait("rm -rf '#{@vm_folder}/#{name}'")
	end
	
	private

	def local_run(cmd, options = {})
		timeout = options[:timeout]
		should_wait = options[:should_wait] || true
		
		puts "Attempting to run #{cmd}" 
		pid, stdin, stdout, stderr = Open4::popen4(cmd)

		if should_wait
			begin
				Timeout.timeout(timeout) do
					ignored, status = Process::waitpid2 pid
					if status.exitstatus == 0
						std_err = stderr.read
						std_err = std_err.strip unless std_err.nil? || std_err.empty?
						{ :ok => true, :data => stdout.read.strip, :stderr => std_err }
					else
						{ :ok => false, :error => stderr.read.strip, :timeout => false }
					end
				end
			rescue Timeout::Error
				{ :ok => false, :error => "Command was timed-out after #{timeout} seconds", :timeout => true }
			end
		else
			{ :ok => true }
		end
	end
	
	def download(name)
		# make the folder
		FileUtils.mkdir_p(File.join(@local_vm_folder, name))
		
		Net::HTTP.start("http://vboxes.cloud66.com") do |http|
			resp = http.get("#{name}.ova")
			open(File.join(@local_vm_folder, name, "#{name}.ova"), "w") do |file|
				file.write(resp.body)
			end
		end
	end
	
	def import(ova_path, name)
		# this should be an ova which is configured for the host. Set the netwokring to bridged and make sure the
		# box starts just fine
		run_and_wait("VBoxManage import #{ova_path} --vsys 0 --vmname #{name}")
	end

	def run_and_wait(command)
		local_run(command, :should_wait => true)
	end
	
	def is_available?(name)
		# do we have it locally?
		File.exists?(File.join(@local_vm_folder, name, "#{name}.ova"))
	end
	
	def run(command)
		puts "Running #{command}"
		system(command)
	end
	
end