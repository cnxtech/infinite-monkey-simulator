#!/usr/bin/ruby -w

# frozen_string_literal: true

#----------------------------------------------------------------------------
#
# Infinite Monkey Simulator
#
# Starts a vim process, then sends it random keystrokes until it terminates
#
# https://github.com/rstms/infinite-monkey-simulator
#
#----------------------------------------------------------------------------

require 'sys/proctable'

MEMORY_LEN = 16

# set trigger to force generation of the exit sequence for testing
TRIGGER = 0

LIMIT_TOTAL = 0
LIMIT_CPS = 128 
LIMIT_TIMEOUT = 60
LIMIT_SLEEP = 0.001

# VimInstance encapsulates the vim process
class VimInstance
  def initialize
    # save startup time for elapsed time calculation
    @start_tick = Time.now
    @key_count = 0

    # create a pipe for vim's stdin
    from_vim_input, @to_vim_input = IO.pipe

    # spawn vim as a child process, using the pipe for stdin
    @pid = spawn(
      'vim',
      :in  => from_vim_input,
      :out => '/dev/null',
      :err => '/dev/null'
    )

    # close our copy of vim's end of the pipe
    from_vim_input.close

    @output = open('./keys', 'w')
  end

  def running?
    # waitpid returns nil if no child exit code is available
    !Process.waitpid(@pid, Process::WNOHANG)
  end

  def send_keystroke(char)
    begin
      @output.print char         # write to the keys file
      @to_vim_input.print char   # send it to vim
      @key_count += 1
    rescue Errno::EPIPE
      puts format(
        "\nError: EPIPE after %<count>s keys",
        count: @key_count
      )
      close_pipe
      exit(-3)
    end
  end

  # vim sometimes spawns a subprocess which can block the simulation
  def child?
    # filter the process table for process that have our pid as a parent
    @child = Sys::ProcTable.ps.select { |pe| pe.ppid == @pid }
    @child.any?
  end

  def terminate_child
    # kill the first process found in the child process list
    Process.kill('TERM', @child[0].pid)
    format(
      "killing vim's child process %<cmd>s pid=%<pid>d",
      cmd: @child[0].cmdline,
      pid: @child[0].pid
    )
  end

  def close_pipe
    # close our end of the child process stdin pipe
    @to_vim_input.close
    @output.close
  end

  def elapsed
    Time.at(Time.now - @start_tick).utc.strftime('%H:%M:%S')
  end

  def elapsed_seconds
    Time.now - @start_tick
  end

  def count
    @key_count
  end
end

# MonkeyWorker is the monkey typing random keys into vim
class MonkeyWorker
  def initialize
    @count = 0
    # set up an array of ASCII character codes 0-127
    @chars = (0..127).map { |c| c.chr }
    # CTRL-Z causes shell job control suspension, suppress it
    @chars[26] = 0.chr
    @memory = [nil] * MEMORY_LEN # initialize the empty array

    @tchars = [27.chr, ':', 'q', '!', 13.chr]
  end

  def random_keystroke
    @count += 1
    # spoof the generation of the vim exit sequence for testing
    if TRIGGER.positive? && @count >= TRIGGER && @count - TRIGGER < @tchars.length
      char = @tchars[@count - TRIGGER]
    else
      char = @chars.sample(1).first
    end
    @memory << char
    @memory = @memory[-MEMORY_LEN..-1]
    char
  end

  def memory
    @memory
  end
end

if ARGV.empty?
  seed = Random.new_seed
else
  seed = Integer(ARGV[0])
end

puts format('Seed=%<seed>d', seed: seed)
open('seed', 'w') { |f| f.puts format('%<seed>d', seed: seed) }
srand(seed)

monkeys = MonkeyWorker.new
vim = VimInstance.new

puts 'Vim is running.' if vim.running?

sleep(1)

next_status = Time.now + 1
cps = 0

while vim.running?

  if (LIMIT_CPS.zero? || cps < LIMIT_CPS) \
      && (LIMIT_TOTAL.zero? || vim.count < LIMIT_TOTAL)
    vim.send_keystroke(monkeys.random_keystroke)
    cps += 1
  end

  if LIMIT_TOTAL.positive? && vim.count >= LIMIT_TOTAL
    puts format(
      "\nError: Limit exceeded at %<count>d keystrokes",
      count: vim.count
    )
    vim.close_pipe
    exit(-2)
  end

  sleep(LIMIT_SLEEP) if LIMIT_SLEEP.positive?

  next if Time.now < next_status

  print format(
    "%<elapsed>s %<count>d %<cps>d     \r",
    elapsed: vim.elapsed,
    count: vim.count,
    cps: cps
  )
  cps = 0
  next_status += 1

  puts vim.terminate_child while vim.child?

  if LIMIT_TIMEOUT.positive? && vim.elapsed_seconds >= LIMIT_TIMEOUT
    puts format(
      "\nError: Timeout after %<count>d keystrokes",
      count: vim.count
    )
    vim.close_pipe
    exit(-1)
  end
end

puts "\nSuccess! Vim has terminated."
vim.close_pipe

puts format(
  'It took %<count>d keystrokes to exit vim after %<elapsed>s',
  count: vim.count,
  elapsed: vim.elapsed
)
puts format(
  'The winning exit combo was: %<memory>s',
  memory: monkeys.memory
)

exit 0
