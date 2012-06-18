
require 'thread'

module Experimoto
  class SyncingThread
    
    attr_reader :thread, :sleep_time, :runs
    
    def initialize(experimoto, opts={})
      @experimoto = experimoto
      @sleep_time = opts[:sleep_time] || 10
      @runs = 0
      
      @done_queue = Queue.new
      
      @thread = Thread.new do
        while true
          sleep @sleep_time
          break if @done_queue.size > 0
          @experimoto.db_sync
          @runs += 1
        end
      end
    end
    
    def stop
      @done_queue << 'blah'
    end
    
  end
end
