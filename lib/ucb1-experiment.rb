

require File.expand_path(File.join(File.dirname(__FILE__),'ab-experiment'))


module Experimoto
  
  class UCB1Experiment < GroupedExperiment
    
    def initialize(opts={})
      super(opts)
      @type = 'UCB1Experiment'
    end
    
    # following http://www.chrisstucchio.com/blog/2012/bandit_algorithms_vs_ab.html
    def _internal_sample
      untried = @groups.keys.find_all { |name| @plays[name] == 0 }
      if untried.size > 0
        return untried[rand(untried.size)]
      end
      
      total_plays = @plays.values.inject(0) { |a, b| a + b }
      
      result = @groups.keys.map do |name|
        avg = utility(name)
        confidence_bound = Math.sqrt(2.0 * Math.log(total_plays) / @plays[name])
        best = avg + confidence_bound
        [name, best]
      end.max { |a, b| a[1] <=> b[1] }[0]
      # TODO: if there's a tie, we should make sure we choose
      # uniformly at random from the highest options.
      result
    end
    
  end
  
end
