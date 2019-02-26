# LCG - Linear Congruential Generators
> &ldquo;Any one who considers arithmetic methods of producing random digits is,
> of course, in a state of sin.&rdquo; &mdash; John Von Neumann (1951)

This quote is notable as they are the first words Donald Knuth chose to put to
paper in Chapter Three of The Art of Computer Programming, which is all about
Random Numbers and how to generate them.

## Overview
This repo contains scratch code, tests, generators, and other random (pun
intended) administrivia for creating a linear congruential pseudorandom number
generator. The code for an LCG is essentially a one-liner, but relies on magic
numbers which must be determined in advance. The theory isn't exactly intuitive
but once understood is fairly straight forward, and code is provided here for
quickly identifying magic numbers for any modulo. They are not guaranteed to be
very good, but they ARE guaranteed to traverse the entire modulo exactly once
before looping back to the beginning.

## Theory
Linear Congruential Numbers take the form

`random_number = seed = (seed * a + c) % m`

Where

* every time you call the function, the seed recursively updates itself to be
  set to the previously generated random number
* a is a magic number used to multiply the seed number
* c is a magic number used to offset the multiplied value
* m is the modulo, or keyspace

It is VERY important to note, and may be obvious to the careful reader, that if
you don't choose very good values for a and c, you're going to get a lousy
generator. For example if you choose a=c=1, you will generate a sequence of 0,
1, 2, 3, 4, 5, ... and so on. If you choose even numbers for both a and c, your
entire sequence will be exclusively even (or exclusively odd if you force seed
it with an odd number).

## Finding Magic Numbers

In this
repo,
[find_lcg.rb](https://git.innova-partners.com/dbrady/lcg/blob/master/find_lcg.rb) will
find some magic numbers that will guarantee you a perfect traversal
sequence. There is no guarantee they will be any good, however: `ruby
find_lcg.rb 10` will generate you a sequence that counts by threes. However, as
of this writing this was throwaway sketch code and I hardcode the approximate
positions in the sequence to start looking for magic numbers. For very small
numbers the results are disastrous.

Knuth gives full proofs and explanations for finding magic numbers in Chapter 3
of The Art of Computer Programming. You can get the rules from Wikipedia, but
they break down as follows. Knuth's words are in plain text, _my layman's
rephrasings are in italics:_

* a must be relatively coprime to m. _This means a and m must have no common
  factors other than 1. A really easy way to guarantee this is to just make sure
  a is a prime number._
* b = a-1 is a multiple of p, for every prime number p dividing m. _This was a
  hard one for me to wrap my head around because I don't speak formal math very
  well anymore, but in layman's terms: if you reduce m to its prime factors and
  ignore duplicates, then multiply them together, that is the Least Common
  Multiple (LCM) of the prime factors of m. All this rule says is that b must be
  a multiple of that LCM, and b must be one less than a. So just go find any
  multiple of the LCM and add 1 to it, and that's a valid 'a' for your
  generator._
* b is a multiple of 4, if m is a multiple of 4. _This is easy to understand but
  the reasoning behind it is 2 full pages of math. The short explanation is that
  a and c interact with each other in odd/even spacingcs, and if m is divisible
  by 4, the previous 2 rules are 50% likely to have a "bad interaction" between
  them that locks the generator into just the odds or just the evens,
  effectively skipping half of the keyspace._

## Testing A Sequence: Tortoise and Hare

In this
repo,
[tortoise_and_hare_lcg.rb](https://git.innova-partners.com/dbrady/lcg/blob/master/tortoise_and_hare_lcg.rb) will
run the full tortoise and hare test. As an added bonus, there's some ugly
base-29 conversion code to generate request keys from decimal integers. It's
nasty but it works, so I'm sorry and you're welcome, in that order.

This program took a bit over 4 hours to run on my laptop, so to save you the
hassle I have
included
[output.txt](https://git.innova-partners.com/dbrady/lcg/blob/master/output.txt),
which captures the last few lines of the full 7-digit tortoise and hare test.

If you don't have rules for Finding Magic Numbers, you can always just test your
generator the hard way. Again there's a lot of proof behind _why_ this works,
but for now let's accept this as a given. The tortoise and hare algorithm will
let you check to see how long a sequence runs before looping back onto
itself. It works like this:

* Initialize two generators to the same starting value (let's say 0). Call one
  the tortoise and one the hare for artistic reasons. Initialize a counter to 0.
* Begin a loop. Each time through the loop, increment the tortoise by one step
  and the hare by two steps. (I.e. `tortoise.next!` and `hare.next!;
  hare.next!`.) Increment the counter by 1.
* Continue looping until the hare "catches" the tortoise, meaning they both have
  the same value.
* Check the counter: if it is less than the modulo, the tortoise has not
  completed a full cycle of the keyspace.

The mathematical proof that lies in the mathematical pudding here essentially
shows that if the tortoise traverses 1/nth of the keyspace, the hare will catch
up to it on or before the (n-1)th loop. So if the tortoise traverses 1/2 of the
keyspace, the hare will catch it the first time it loops, which is halfway
through the keyspace. If the tortoise traverses 1/3 of the keyspace, the hare
might catch it the first time, but if it misses it by +1 or -1 the first
through, it will definitely catch the tortoise on the second time
through. Remember that the hare is following the same path as the tortoise, just
skipping every other node, so if the tortoise is only visiting even numbers the
hare isn't dallying with odd numbers either.

If the tortoise completes a full cycle of the keyspace, the hare will always
tie the race.

If you are more mathematically inclined than me, I welcome your input into
_why_ this algorithm works. I studied the algorithm decades ago and could have
explained it to you back in Y2K, nowadays I just remember that it works and that
you can go look up why if you're interested.

## Performance

The Tortoise and Hare algorithm runs on my laptop under the following
parameters:

* bog stupid ruby 2.4, which means "can only use one CPU core"
* 2.5GHz laptop, with one core running flat-out
* using gratuitously large (BigNumber) values of a=11,499,917,550,
  c=5,749,958,779 and m=29<sup>7</sup>=17,249,876,309 to simulate generating
  7 of 8 digits of a request key (assuming the first letter is a partition
  identifier)
* one optimization: doing the math inline. This sped up the test script by about
  40% over calling an instance method on an LCG object.

With these parameters, the tortoise and the hare checked the entire 17.2B
keyspace in 4:14:17. That works out to 1.13M keys per second, but remember that
the generator works 3x per key, because tortoise goes once and hare goes twice
per iteration. That gives us a napkin estimate of 3.39M keys per second, or
about 294 nanoseconds to generate one key.

Given that this algorithm will be waiting on a database index call, no further
optimizations are deemed necessary at this time.

## Two Methods of Driving the Function

A good LCG is a Perfect Sequence Function.

1. _Sequence Functions_ take one element from a set as their input and return
   an element from the same set as their output.
1. A _perfect_ sequence function always returns a different element than the one
   given, and if continuously called with its own output as input, will visit
   every element in the set before looping back to the starting point.

Some follow-on concepts quickly emerge:

1. Every number in a perfect LCG is directly reachable in one hop from exactly
   one other number.
1. Every number in a perfect LCG can directly reach exactly one other number.
1. This means that if you feed the entire set to the LCG in _any_ order with no
   duplicates, you will get back exactly the output set with no duplicates, but
   in a different order.

That last one bears thinking about. Normally the way you drive an LCG function
is by feeding it the previous output. But every output number in an LCG is
reachable from exactly one input number. That means if only one number can be
reached from 0, and only one number can be reached from 1, and only one number
can be reached from 2, and so on, then it does not matter if you feed the LCG
its own output as input. You could, in theory, feed the set of numbers 0..m-1 in
order into the function.

We could use a database index starting at 0 or 1, and index it +1 each
time in a normal sequence, without adding the requirement of reading the input
number, calculating the RNG, and writing the new number back.

### Caveat
There's a reason people don't do this all the time, and that reason is: linear
congruential generators get a LOT less random when you feed them ordered
input. Feeding them their own output is a feature that allows them to thrash
around the keyspace much more wildly. Feeding an LCG an ordered input will cause
the output to become much more orderly, developing a "period" in which very
similar numbers regularly occur. Taking the above performance test, for example,
every key in the sequence is a very similar to the 25th key after it. This means
key 0, 25, and 50 all start with the same 4 letters, as do keys 1, 26 and 51,
as do keys 2, 27, and 52, and so on. The keys pass within about 3000 of each
other, which is a very near miss in a keyspace of 17 billion. It's a painfully
obvious repeating pattern, and if customers are grabbing keys randomly
throughout the day, the chances of them getting two or three or sixteen request
keys all starting with the same 2-4 digits is painfully high.



### Workaround to the Caveat
There's a pretty easy workaround for this, though: for each input number 0..m-1
taken in order, jump _two_ hops instead of one. If every number is reachable
from exactly one other number, and THAT number is reachable from exactly one
other number, then every number is reachable in two hops from exactly one other
number. If you imagine the sequence of numbers as a ring, we're shifting two
spots over instead of one. And yes, from this it is relatively easy to prove
that you can do this for 3 hops or 4 or any positive integer that isn't a
multiple of m (otherwise you'd hop your way right back to the same number you
started from).

### Caveat to the Workaround to the First Caveat
You might be thinking, "does skipping every other number have an effect on the
apparent randomness?" The answer is "almost certainly". You should test out the
theory and look at some actual output. LCG's are notoriously nonrandom in their
lower bits.
