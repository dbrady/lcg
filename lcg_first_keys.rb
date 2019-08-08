#!/usr/bin/env ruby

# lcg_first_keys.rb - Show what the key sequence would be if, instead of
# following the string f(x[n+1]) -> { (a*n + c) % m }, we simply fed 0, 1, 2,
# into the sequence.
#
# E.g. if you have a 10-digit keyspace, then m=10, and you might choose a=11,
# c=2 for your LCG. Starting from zero, you would generate the sequence
# 3, 6, 9, 2, 5, 8, 1, 4, 7, 0, 3, ...
#
# One detail of this is that each number in the sequence is the seed for the
# next number in the sequence. However, it happens to be true that each number
# goes to exactly one other unique number and each number is reachable from
# exactly one other number in the sequence. And that in turn means we could take
# an integer sequence 0,1,2,3,4,... and feed it into the LCG to generate random
# numbers from a predictable n+1 sequence.
#
# A problem immediately emerges, however. Let's look at how "random" this new
# sequence is:
#
# 0 -> 3
# 1 -> 4
# 2 -> 5
# 3 -> 6
# 4 -> 7
# 5 -> 8
# 6 -> 9
# 7 -> 0
# 8 -> 1
# 9 -> 2
#
# Because we've selected a very close to m and c is very small, the function
# only moves a small way each time it is called. This just happens to be the
# worst possible case: we start at 3 but essentially index by +1 each time. We
# can try to choose better numbers but a visible pattern will emerge no matter
# what.
#
# It's worth noting that we are working with a very small modulo AND we have
# deliberately chosen awful values for a and c. The multiplier scales the number
# by 10% of the modulo, which effectively only adds 1. Then the offset adds
# another 2. If you didn't spot it immediately, look at the original sequence
# above: it counts up by threes. Normally we choose better values but for a very
# small modulo you're going to be able to see that it is counting off by some
# amount each time. A scalar of 7, for example, would just look like counting up
# by 7, or backwards by 3, and scale of 7 with an offset of +2 would look like
# counting backwards by 1. Not very random-looking. The good news here is that
# this is a problem inherent in very small moduli. Once the number gets up
# around 100-200, it's much harder for a human to eyeball the sequence and spot
# the pattern.
#
# Unless you unstring it and drive the function with 0, 1, 2, 3, etc. Then even
# with very large sequences you can see a looping pattern. For example, if we
# carve up 7-digit request keys, the keyspace is 17.2 million wide, and if we
# use a = 3_449_975_286 and c = 2_464_268_077, we get a pretty random-looking
# sequence of numbers AS LONG AS WE SEED EACH RANDOM NUMBER WITH THE PRECEDING
# RANDOM NUMBER. If we unstring the sequence and drive it with 0,1,2,... etc, we
# get request keys that LOOK random at first...
#
# 0 -> B22222YK (828)
# 1 -> B37MKBML (689996466)
# 2 -> B4CB6KBM (1379992104)
# 3 -> B6GWNTXN (2069987742)
# 4 -> B7MKA4LP (2759983380)
# 5 -> B8T8TDAQ (3449979018)
# 6 -> B9XUDLWR (4139974656)
#
# That's not so bad, right? Well, we're using a pretty large scale and offset,
# but they end up having a near-cycle with a period of 25. Let's look further
# down the chain:
#
# 25 -> B2222MEF (15469)
# 26 -> B37MKW3G (690011107)
# 27 -> B4CB77PH (1380006745)
#
# and then
#
# 50 -> B22239TB (30110)
# 51 -> B37MLHGC (690025748)
# 52 -> B4CB7R6D (1380021386)
#
# If you just happen to be customer #0 and customer #25 and customer #50, you're
# going to get request keys B22222YK, B2222MEF, and B2239TB. It's not the end of
# the world, but it's just nonrandom enough to attract the eye. At +1 you're
# going to get keys starting with B37M and at +2 you're going to get keys
# starting with B4CB, and so on.
#
# An easy enough fix for this is to jump the LCG *twice*. In other words, start
# at 0, jump to 828, then jump from there to 12814213900, which gives a request
# key of BQJQKKEU. We know this second jump is safe because the numeric sequence
# is a perfect ring, and for every number at position n there is a specific
# unique number n+m that can only be reached by m jumps from position
# n.

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

KEYSPACE = ("0".."9").to_a + ("A".."Y").to_a - %w(0 1 5 9 O I S Z)
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
  # a =  3_449_975_286
  # c =  2_464_268_077
  # m = 17_249_876_309
  # base 28, no 9 (for censorship)
  a =  2_698_585_709
  c =  1_927_561_217
  m = 13_492_928_512
  # a = 11_499_917_550
  # c =  5_749_958_779
  # m = 17_249_876_309

  lcg = LinearCongruentialGenerator.new(a, c, m)

  53.times do |i|
    lcg.seed = i
    lcg.next
    lcg.next
    id = lcg.next
    key = id.to_request_key
    puts "%2d -> %s (%d)" % [i, key, id]
  end
end
