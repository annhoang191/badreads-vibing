module OpenLibrary
  # Keeps requests at least `interval` seconds apart within one process (FR-E3).
  # Uses the monotonic clock; `sleeper` is injectable so specs never actually sleep.
  class Throttle
    def self.shared
      @shared ||= new(interval: Rails.configuration.x.open_library_min_interval)
    end

    def initialize(interval: 1.0, sleeper: Kernel.method(:sleep))
      @interval = interval
      @sleeper = sleeper
      @last = nil
      @mutex = Mutex.new
    end

    def wait
      return if @interval.to_f <= 0

      @mutex.synchronize do
        if @last
          remaining = @interval - (now - @last)
          @sleeper.call(remaining) if remaining.positive?
        end
        @last = now
      end
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
