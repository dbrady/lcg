#!/usr/bin/env ruby
# tortoise_and_hare_lcg.rb <a> <c> <m> - Prove that LCG uses the full period of m
SECONDS_PER_MINUTE = 60
SECONDS_PER_HOUR = SECONDS_PER_MINUTE * 60
SECONDS_PER_DAY = SECONDS_PER_HOUR * 24

class LinearCongruentialGenerator
  attr_accessor :seed
  attr_reader :a, :c, :m

  def initialize(a, c, m, seed=0)
    @a, @c, @m, @seed = a, c, m, seed
  end

  def next
    @seed = (a * seed + c) % m
    # puts "Next returning #{@seed}"
    @seed
  end
end

KEYSPACE = ("0".."9").to_a + ("A".."Y").to_a - %w(0 1 5 O I S Z)
KEYSPACE_REGEX = /^[#{KEYSPACE*''}]+$/
BASE = KEYSPACE.size
PARTITION_LETTER = "B"

class Numeric
  def to_request_key
    # puts "#{self}.to_request_key:"
    str = ""
    s = self.dup
    while s > 0
      digit = s % BASE
      str += KEYSPACE[digit]
      s /= BASE
      # puts "    #{digit} -> #{KEYSPACE[digit]} ---> #{s}"
    end
    # pad with 0's if small (where 0 means "A")
    # 8 digits with partition letter
    str += KEYSPACE[0] while str.size < 7
    str += PARTITION_LETTER
    # 6 digits (without caring about starting with a letter)
    # str += KEYSPACE[0] while str.size < 6
    str.reverse
  end

  def to_elapsed_time
    seconds = self.dup
    time = ""
    if seconds >= SECONDS_PER_DAY
      days = seconds / SECONDS_PER_DAY
      time += "#{days}d "
      seconds -= days * SECONDS_PER_DAY
    end

    hours = seconds / SECONDS_PER_HOUR
    time += "%d:" % hours
    seconds -= hours * SECONDS_PER_HOUR

    minutes = seconds / SECONDS_PER_MINUTE
    time += "%02d:" % minutes
    seconds -= minutes * SECONDS_PER_MINUTE

    time += "%02d" % seconds
  end

  def localize
    to_s
      .reverse
      .chars
      .to_a
      .each_slice(3)
      .map(&:join)
      .join(',')
      .reverse
  end
end

class String
  def to_request_id
    raise "Illegal chars: Cannot convert string" unless self =~ KEYSPACE_REGEX
    # puts "#{self}.to_request_id:"
    num = 0
    s = self.split(//)
    # 8 digits - pop off partition letter
    s.shift
    # this next bit as a one-liner:
    # num = num * BASE + KEYSPACE[s.shift] until s.empty?
    until s.empty?
      digit = s.shift
      pos = KEYSPACE.index(digit)
      # puts "    #{digit} -> #{pos}"
      num *= BASE
      num += pos
    end
    num
  end
end

if $0 == __FILE__
  # lcg = LinearCongruentialGenerator.new(11499917550, 5749958779, 17249876309)
  # format = "%11d -> %s -> %11d"
  # puts format % [lcg.seed, lcg.seed.to_request_key, lcg.seed.to_request_key.to_request_id]
  # 10.times do
  #   n = lcg.next
  #   key = n.to_request_key
  #   back = key.to_request_id
  #   puts format % [n, key, back]
  # end

  # a = 81
  # c = 37
  # m = 100
  # ticker_interval = 10

  # a =  66_681
  # c =  33_343
  # m = 100_000
  # ticker_interval = 10_000

  # a =  6_666_681
  # c =  3_333_373
  # m = 10_000_000
  # ticker_interval = 100_000

  # 6-digit (uses correct key size for starting with letters only, but allows
  #          request keys to start with letters because screw you that's
  #          why. This is just here to give me a rough ballpark of how much
  #          longer the "real" test will take to run. [Answer: this runs in
  #          1:25, and the 7-digit keyspace is 38x larger, but the 7-digit code
  #          also runs about 3-4x slower, presumably because it's working with
  #          much bigger numbers. A straight scaleup would take about 1:40:00
  #          but watching the progress bar I'm thinking it's going to be closer
  #          to 4.25-4.5 hours--longer if it slows down as it runs, which it had
  #          better not as my algos use static memory, we're not growing and
  #          shrinking collections and flopping things around as we go.)
  # a = 300_830_399
  # c = 150_415_127
  # m = 451_245_278
  # ticker_interval = 10_000_000

  a = 11_499_917_550
  c =  5_749_958_779
  m = 17_249_876_309
  ticker_interval = 100_000_000

  # turns out this is REALLY slow
  # tortoise = LinearCongruentialGenerator.new(a, c, m)
  # hare = LinearCongruentialGenerator.new(a, c, m)
  tortoise = hare = 0

  counter = 0
  success = true
  start = Time.now
  number_size = m.localize.size
  ticker_format = "    Passing %#{number_size}s / %#{number_size}s (%6.2f%%, elapsed time %s)"

  puts "Starting at #{start.strftime('%F %T')}..."
  m1 = m-1
  while counter < m1
    if counter % ticker_interval == 0
      elapsed = (Time.now - start).to_i
      puts ticker_format % [counter.localize, m.localize, 100.0*counter/m, elapsed.to_elapsed_time]
      t = tortoise
      tkey = t.to_request_key
      tback = tkey.to_request_id
      h = hare
      hkey = h.to_request_key
      hback = hkey.to_request_id
      puts "    Tortoise: %#{number_size}s -> %s -> %#{number_size}s" % [t, tkey, tback]
      puts "        Hare: %#{number_size}s -> %s -> %#{number_size}s" % [h, hkey, hback]
    end

    counter += 1

    tortoise = (a * tortoise + c) % m
    hare = (a * hare + c) % m
    hare = (a * hare + c) % m

    if tortoise == hare
      success = false
      puts "!!!  OH NOES  !!!"
      puts "After #{counter} iterations, the hare has caught the tortoise! (#{'%5.2d' % [100.0 * counter / m]}% traversed)"
      puts "    Tortoise: #{tortoise}"
      puts "    Hare:     #{hare}"
      break
    end
  end
  stop = Time.now
  puts "Finished at #{stop.strftime('%F %T')}..."
  puts "Elapsed time: #{(stop - start).to_i.to_elapsed_time}"
  if success
    puts "IT WORKED HAHAHAHA OMG IT WORKED!!!!"
    puts "THESE ARE WORKY MAGIC NUMBERS:"
    puts "    a: #{a}"
    puts "    c: #{c}"
    puts "    m: #{m}"
  else
    puts "It failed. I HAZ A SAD."
  end
end

# x[n+1] = (11499917550 * n + 5749958779) % 17249876309
