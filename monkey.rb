require 'pty'
require 'sys/proctable'

class VimInstance

    # run vim using a pseudo-tty 
    def initialize
        @master, slave = PTY.open
        read, @write = IO.pipe
        @pid = spawn("vim", :in=>read, :out=>slave)
        read.close     # we dont need the read
        slave.close    # or the slave
    end

    def is_running
        !PTY::check(@pid, false)
    end

    def send_keystroke(char)
        @write.puts char
    end

    # vim sometimes spawns a subprocess, which can block the simulation
    def has_child
        @child = Sys::ProcTable.ps.select{ |pe| pe.ppid == @pid }
	@child.any?
    end

    def terminate_child
        %x[kill #{@child[0].pid}] 
        "killing vim's child process %s pid=%d" % [@child[0].cmdline, @child[0].pid]
    end

    # read vim's output so it won't block
    def read_output
        begin
            @master.read_nonblock(1)
            rescue IO::WaitReadable
        end
    end

    def close_pipes
        @write.close
        @master.close
    end

end 

class MonkeyWorker
   # ASCII character range via http://www.december.com/html/spec/ascii.html
   # and then converted to octal notation and left-padded
    def initialize
        @chars = (0..127).map{|c|c.chr}
        @chars[26]=0.chr
        @memory = [nil] * 5 # initialize the empty array
        @counter = 0
    end

    def random_keystroke
        @counter += 1
        char = @chars.sample(1).first
        # Let's keep track of the characters we sent, but no more than the last 5
        @memory << char
        @memory = @memory[-5..-1]
	char
    end

    def memory
        @memory
    end  

    def counter
        @counter
    end
end

start_tick = Time.now
last_tick = start_tick

monkeys = MonkeyWorker.new
vim = VimInstance.new

if vim.is_running
    puts "Vim is running."
end

loop do
    vim.send_keystroke(monkeys.random_keystroke)
    vim.read_output
    if Time.now - last_tick > 1
        puts "count=%d elapsed=%d" % [monkeys.counter, Time.now - start_tick]
	last_tick = Time.now
	if vim.has_child
	    puts vim.terminate_child
	end
    end
    if !vim.is_running
        puts "Vim has terminated."
        vim.close_pipes
        break
    end 
end

puts "It took %d keystrokes to exit vim after %d seconds. The winning exit combo was: %s" % [monkeys.counter, Time.now - start_tick, monkeys.memory]

