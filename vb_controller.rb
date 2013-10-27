require 'rubygems'
require 'open4'
require 'shell'

class VbController

	def initialize(vm_folder)
		@vm_folder = vm_folder
	end
	
	def import(ovf_path, name)
		# this should be an ovf or ova which is configured for the host. Set the netwokring to bridged and make sure the
		# box starts just fine
		run_and_wait("VBoxManage import #{ovf_path} --vsys 0 --vmname #{name}")
	end
	
	def start(name)
		# configure the box. 
		# NOTE: this only works for Macs for now. need to find a way of getting the best NIC name
#		run_and_wait("VBoxManage modifyvm #{name} --nic1 bridged --bridgeadapter1 en1")
		
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

	def get_nics
		local_run("ifconfig | awk -F: '/^en/ { print $1 }'")
	end
	
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
				# kill pid if its still exists
				# we should now do this externally
				#Process.kill(what is the quit id?, pid) rescue nil
				{ :ok => false, :error => "Command was timed-out after #{timeout} seconds", :timeout => true }
			end
		else
			{ :ok => true }
		end
	end
	
	def run_and_wait(command)
		local_run(command, :should_wait => true)
	end
	
	def run(command)
		puts "Running #{command}"
		system(command)
	end
	
end

c = VbController.new("/Users/khashsajadi/VirtualBox VMs")
#c.import('/Users/khashsajadi/Desktop/boom.ova', 'boom')
#c.start('boom')
#c.shutdown('boom')
