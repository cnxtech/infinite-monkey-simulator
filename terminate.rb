require 'pty'

master, slave = PTY.open
read, write = IO.pipe
pid = spawn("vim", :in=>read, :out=>slave)
read.close     # we dont need the read
slave.close    # or the slave

if !PTY::check(pid, false)
  puts "Vim is running."
end 

# send terminate sequence to vim through PTY
write.puts ":q\n"

loop do
    if PTY::check(pid, false)
        puts "Vim has terminated."
        break
    end 
end

write.close
master.close
