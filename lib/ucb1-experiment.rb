

require File.expand_path(File.join(File.dirname(__FILE__),'ab-experiment'))


module Experimoto
  
  class UCB1Experiment < GroupedExperiment
    
    def initialize(opts={})
      super(opts)
      @type = 'UCB1Experiment'
    end
    
    def confidence_bound(group_name, utility_max, plays)
      conf_bound_min = 0.1
      conf_bound_mult = 2.0 * utility_max
      if conf_bound_mult <= conf_bound_min
        conf_bound_mult = conf_bound_min
      end
      
      conf_bound_mult * Math.sqrt(2.0 * Math.log(total_plays) / plays[group_name])
    end
    
    def utilities
      tmp = {}
      self.groups.keys.map do |group_name|
        tmp[group_name] = quick_utility(group_name)
      end
      tmp
    end
    
    # following http://www.chrisstucchio.com/blog/2012/bandit_algorithms_vs_ab.html
    def _internal_sample
      untried = self.groups.keys.find_all { |name| @plays[name] == 0 }
      if untried.size > 0
        return untried[rand(untried.size)]
      end
      
      self.groups.keys.sort.map do |name|
        avg = utilities[name]
        best = avg + confidence_bound(name, utilities.values.max, @plays)
        [name, best]
      end.max { |a, b| a[1] <=> b[1] }[0]
    end
    
  end
  
end
