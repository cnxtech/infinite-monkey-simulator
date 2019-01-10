require 'pty'

master, slave = PTY.open
read, write = IO.pipe
pid = spawn("vim", :in=>read, :out=>slave)
read.close     # we dont need the read
slave.close    # or the slave

if !PTY::check(pid, false)
  puts "Vim is running."
end 

start_tick = Time.now
# send terminate sequence to vim through PTY
write.puts ":q\n"

counter = 0
loop do
    if PTY::check(pid, false)
	puts "count=%d elapsed=%d" % [counter, Time.now - start_tick]
        puts "Vim has terminated."
        break
    end 
    counter += 1
end

write.close
master.close
