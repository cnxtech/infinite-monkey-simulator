require 'sys/proctable'

MEMORY_LEN = 16

class VimInstance

    def initialize

	# save startup time for elapsed time calculation
	@start_tick = Time.now

	# create a pipe for vim's stdin
        from_vim_input, @to_vim_input = IO.pipe

	# spawn vim as a child process, using the pipe for stdin
        @pid = spawn("vim", :in=>from_vim_input, :out=>"/dev/null", :err=>"/dev/null")

	# close our copy of vim's end of the pipe
	from_vim_input.close

	@closed = false
    end

    def is_running?
        # waitpid returns nil if no child exit code is available
        !Process.waitpid(@pid, Process::WNOHANG)
    end

    def send_keystroke(char)
        begin
	    print char
            @to_vim_input.print char
	#rescue Errno::EPIPE
	#    STDERR.puts "pipe error."	
	end
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
	@closed = true
    end

    def elapsed
        Time.at(Time.now - @start_tick).utc.strftime("%H:%M:%S")
    end

end 

class MonkeyWorker
   # ASCII character range via http://www.december.com/html/spec/ascii.html
   # and then converted to bytes
    def initialize


        @chars = (0..127).map{|c|c.chr}
	# CTRL-Z causes shell job control suspension, suppress it
        @chars[26]=0.chr

        @memory = [nil] * MEMORY_LEN # initialize the empty array
        @counter = 0

	@kill_chars = [':', 'q', 10.chr]

    end

    def next_keystroke
        char = @kill_chars[@counter]
        @counter += 1
        char	
    end

    def random_keystroke
        @counter += 1
	# select one of the chars at random
        char = @chars.sample(1).first
        # Let's keep track of the characters we sent, but no more than the last 5
        @memory << char
        @memory = @memory[-MEMORY_LEN..-1]
	char
    end

    def memory
        @memory
    end  

    def counter
        @counter
    end

    def seed
	@seed
    end

end


STDERR.puts("len=%d ARGV=%s" % [ARGV.length, ARGV])

if ARGV.length > 0
    seed = ARGV[0].to_i
    STDERR.puts("command line seed = %f" % seed)
else
    seed = Random.new_seed
    STDERR.puts("random seed = %f" % seed)
end

STDERR.puts("Seed=%f" % seed)
srand(seed)

monkeys = MonkeyWorker.new
vim = VimInstance.new

if vim.is_running?
    STDERR.puts "Vim is running."
end

loop do
    if vim.is_running?
        vim.send_keystroke(monkeys.random_keystroke)
        #vim.read_output
        if Time.now - last_tick > 1
            print "count=%d elapsed=%s\r" % [monkeys.counter, Time.at(Time.now - start_tick).utc.strftime("%H:%M:%S")]
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

STDERR.puts "It took %d keystrokes to exit vim after %s" % [monkeys.counter, vim.elapsed]
STDERR.puts "The winning exit combo was: %s" % [monkeys.memory]
