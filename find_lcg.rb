#!/usr/bin/env ruby
# find_lcg.rb <period_length>

# An LCG of the form
# x.next = (a*x + c) % m
# Uses the full keyspace (has a period of length m) if and only if
#
# i) c is relatively prime to m
# ii) b = a-1 is a multiple of p for every prime p dividing m (a is 1 more than
#     the multiple of all prime factors of m)
# iii) b is a multiple of 4 if m is a multiple of 4

# 7 in a base-27 modulus (reserving 1 digit for censorship) is 13492928512

require 'prime'

class LcgFinder
  def prime_factors(number)
    return [number] if Prime.instance.prime?(number)
    factors = []
    root = Math.sqrt(number).ceil
    Prime.each(root) do |prime|
      multiplicand = number / prime
      if multiplicand * prime == number
        factors << prime
        factors += prime_factors(multiplicand)
      end
    end
    factors.uniq.sort
  end

  def display_prime_factors_of(number)
    puts "Prime factors of #{number}:"
    puts prime_factors(number) * ', '
  end

  def find_c_for(number)
    puts "c (constant offset) must be relatively prime to m (#{number})"
    puts "Let's take the first prime number somewhere around 1/7 of the number"
    num = number * 1 / 7
    num = 3 if num < 3 # 2 is prime but is an even number, wich is a problem for very small LCGs
    num += 1 until Prime.instance.prime?(num)
    puts "Found #{num}, which is universally prime"
    num
  end

  def find_a_for(number)
    puts "a must be 1+b, where b is the lcp of all the prime factors of m."
    puts "For grins, we'll also assert that it must be at least 1/10 of number."
    b = 2 * number / 10
    lcm = prime_factors(number).reduce(:*)
    puts "lcm: #{lcm}"
    if lcm > b
      b = lcm
    else
      while b % lcm != 0 || (number%4 == 0 && b%4 != 0)
        print "Trying #{b}..."
        puts "no"
        b += 1
      end
      puts "yes"
    end
    a = b+1
    puts "Found multiplier a: #{a}"
    a
  end
end

# Given e.g. 1234567, return "1_234_567". Search Stack Overflow for putting
# commas in a decimal number.
def number_to_pretty_ruby(number)
  number                 # this
    .to_s                # |> is
    .reverse             # |> totally
    .chars               # |> a
    .to_a                # |> love
    .each_slice(3)       # |> poem
    .map(&:join)         # |> to
    .join('_')           # |> Elixir
    .reverse             # |> amirite
end

if $0 == __FILE__
  if ARGV.empty?
    puts "usage: #{$0} <size_of_keyspace>"
    exit -1
  end
  m = ARGV[0].to_i
  finder = LcgFinder.new
  finder.display_prime_factors_of(m)
  c = finder.find_c_for(m)
  a = finder.find_a_for(m)
  puts "-" * 80
  puts "This LCG is guaranteed to transit the full period m of #{m}:"
  puts "x[n+1] = (#{a} * n + #{c}) % #{m}"
  size = number_to_pretty_ruby(m).size
  format = "%s = %#{size}s"
  puts format % ["a", number_to_pretty_ruby(a)]
  puts format % ["c", number_to_pretty_ruby(c)]
  puts format % ["m", number_to_pretty_ruby(m)]

end
