module Peach
  def peach(pool = nil, &b)
    pool ||= $peach_default_threads || size
    raise "Thread pool size less than one?" unless pool >= 1
    div = (size/pool).to_i      # should already be integer
    div = 1 unless div >= 1     # each thread better do something!

    threads = (0...size).step(div).map do |chunk|
      Thread.new(chunk, [chunk+div,size].min) do |lower, upper|
        (lower...upper).each{|j| yield(slice(j))}
      end
    end
    threads.each { |t| t.join }
    self
  end

  def pmap(pool = nil, &b)
    pool ||= $peach_default_threads || size
    raise "Thread pool size less than one?" unless pool >= 1
    div = (size/pool).to_i      # should already be integer
    div = 1 unless div >= 1     # each thread better do something!

    result = Array.new(size)

    threads = (0...size).step(div).map do |chunk|
      Thread.new(chunk, [chunk+div,size].min) do |lower, upper|
        (lower...upper).each{|j| result[j] = yield(slice(j))}
      end
    end
    threads.each { |t| t.join }
    result
  end

  def pselect(n = nil, &b)
    peach_run(:select, b, n)
  end



  protected
  def peach_run(meth, b, n = nil)
    threads, results, result = [],[],[]
    peach_divvy(n).each_with_index do |x,i|
      threads << Thread.new { results[i] = x.send(meth, &b)}
    end
    threads.each {|t| t.join }
    results.each {|x| result += x if x}
    result
  end
  
  def peach_divvy(n = nil)
    return [] if size == 0

    n ||= $peach_default_threads || size
    n = size if n > size

    lists = []

    div = (size/n).floor
    offset = 0
    for i in (0...n-1)
      lists << slice(offset, div)
      offset += div
    end
    lists << slice(offset...size)
    lists
  end
end

Array.send(:include, Peach)
