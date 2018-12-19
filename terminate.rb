require 'pty'

master, slave = PTY.open
read, write = IO.pipe
pid = spawn("vim", :in=>read, :out=>slave)
read.close     # we dont need the read
slave.close    # or the slave

if !PTY::check(pid, false)
  p "vim is running"
end 

# send terminate sequence to vim through PTY
#write.puts ":q\n"

write.puts "[5>_\x17"
puts "[5>_\x17"

loop do
    if PTY::check(pid, false)
        p "vim has terminated"
        break
    end 
end

write.close
master.close
