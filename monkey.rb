require 'pty'
require 'sys/proctable'

class VimInstance

    def initialize

	# create a pipe for vim's stdin
        from_vim_input, @to_vim_input = IO.pipe

	# spawn vim as a child process, using the pipe for stdin
        @pid = spawn("vim", :in=>from_vim_input, :out=>"/dev/null", :err=>"/dev/null")

	# close our copy of vim's end of the pipe
	from_vim_input.close
    end

    def is_running?
        !PTY::check(@pid, false)
    end

    def send_keystroke(char)
        @to_vim_input.puts char
    end

    # vim sometimes spawns a subprocess which can block the simulation
    def has_child?
	# filter the process table for process that have our pid as a parent
        @child = Sys::ProcTable.ps.select{ |pe| pe.ppid == @pid }
	@child.any?
    end

    def terminate_child
	# kill the first process found in the child process list
        %x[kill #{@child[0].pid}] 
        "killing vim's child process %s pid=%d" % [@child[0].cmdline, @child[0].pid]
    end

    def close_pipe
	# close our end of the child process stdin pipe
        @to_vim_input.close
    end

end 

class MonkeyWorker
   # ASCII character range via http://www.december.com/html/spec/ascii.html
   # and then converted to bytes
    def initialize
        @chars = (0..127).map{|c|c.chr}
	# CTRL-Z causes shell job control suspension, suppress it
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

if vim.is_running?
    puts "Vim is running."
end

loop do
    if vim.is_running?
        vim.send_keystroke(monkeys.random_keystroke)
        #vim.read_output
        if Time.now - last_tick > 1
            puts "count=%d elapsed=%d" % [monkeys.counter, Time.now - start_tick]
	    last_tick = Time.now
	    if vim.has_child?
	        puts vim.terminate_child
	    end
       end
    else
        puts "Vim has terminated."
        vim.close_pipe
        break
    end 
end

puts "It took %d keystrokes to exit vim after %d seconds. The winning exit combo was: %s" % [monkeys.counter, Time.now - start_tick, monkeys.memory]

