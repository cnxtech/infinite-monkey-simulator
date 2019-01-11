require 'sys/proctable'

MEMORY_LEN = 16

# set trigger to force generation of the exit sequence for testing
TRIGGER = 0

LIMIT_TOTAL = 0
LIMIT_CPS = 128
LIMIT_TIMEOUT = 0
LIMIT_SLEEP = 0.001

class VimInstance

    def initialize

	# save startup time for elapsed time calculation
	@start_tick = Time.now
        @key_count = 0

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
	#STDERR.puts "sending %s" % char
	# return number of keys sent
	ret = 0
	# if the pipe is open, send the key
        if !@closed	
	    begin
	        # print the key to STDOUT
	        print char
	        # send it to vim
                @to_vim_input.print char
	        @key_count += 1
	        ret = 1
	    rescue Errno::EPIPE
	        STDERR.puts "\nError: EPIPE after %s keys" % @key_count	
	        close_pipe
		exit -3
	    end
	end
	ret
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

    def elapsed_seconds
	Time.now - @start_tick
    end

    def count
        @key_count
    end

end 

class MonkeyWorker
   # ASCII character range via http://www.december.com/html/spec/ascii.html
   # and then converted to bytes
    def initialize

	@count = 0
        @chars = (0..127).map{|c|c.chr}
	# CTRL-Z causes shell job control suspension, suppress it
        @chars[26]=0.chr

        @memory = [nil] * MEMORY_LEN # initialize the empty array

    end

    def random_keystroke
	@count += 1
	if TRIGGER>0 and @count==TRIGGER  
	    char = 27.chr
	elsif TRIGGER>0 and @count==TRIGGER+1
	    char = ":"
	elsif TRIGGER>0 and @count==TRIGGER+2
	    char = "q"
	elsif TRIGGER>0 and @count==TRIGGER+3
            char = "!"
	elsif TRIGGER>0 and @count==TRIGGER+4
            char = 13.chr
	elsif
	# select one of the chars at random
            char = @chars.sample(1).first
	end
        # Let's keep track of the characters we sent, but no more than the last 5
        @memory << char
        @memory = @memory[-MEMORY_LEN..-1]
	char
    end

    def memory
        @memory
    end  

end


if ARGV.length > 0
    # if a seed is passed as an argument, use it
    seed = Integer(ARGV[0])
else
    # otherwise generate a new random seed
    seed = Random.new_seed
end

STDERR.puts("Seed=%d" % seed)
puts("Seed=%d" % seed)
srand(seed)

monkeys = MonkeyWorker.new
vim = VimInstance.new

if vim.is_running?
    STDERR.puts "Vim is running."
end

sleep(1)

next_status = Time.now + 1
cps = 0

while vim.is_running?

    # send a random key to the vim process
    if (LIMIT_CPS==0 or cps<LIMIT_CPS) and (LIMIT_TOTAL==0 or vim.count<LIMIT_TOTAL)
        cps += vim.send_keystroke(monkeys.random_keystroke)
    end

    if LIMIT_TOTAL>0 and vim.count>=LIMIT_TOTAL
        STDERR.puts "\nError: Limit exceeded at %d keystrokes" % vim.count
	exit -2
    end

    if LIMIT_SLEEP > 0
        sleep(LIMIT_SLEEP)
    end

    if Time.now > next_status
	    STDERR.print "%s %d %d     \r" % [vim.elapsed, vim.count, cps]
	cps = 0
	next_status += 1

	while vim.has_child?
	    puts vim.terminate_child
	end

	if LIMIT_TIMEOUT>0 and vim.elapsed_seconds>LIMIT_TIMEOUT
	    STDERR.puts "\nError: Timeout after %d keystrokes" % vim.count
	    exit -1
	end
    end
end

STDERR.puts "\nSuccess! Vim has terminated."
vim.close_pipe

STDERR.puts "It took %d keystrokes to exit vim after %s" % [vim.count, vim.elapsed]
STDERR.puts "The winning exit combo was: %s" % [monkeys.memory]

exit 0
