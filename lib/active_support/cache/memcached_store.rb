require 'memcached'

module ActiveSupport
  module Cache
    class MemcachedStore < Store

      attr_reader :addresses

      def initialize(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        addresses = ["localhost:11211"] if addresses.empty?
        @addresses = addresses
        @data = Memcached.new(addresses, options)
      end

      def read(key, options = nil)
        with_safety do
          begin
            super
            @data.get(key, raw?(options))
          rescue Memcached::NotFound => e
            nil
          end
        end    
      end

      # Set key = value. Pass :unless_exist => true if you don't
      # want to update the cache if the key is already set.
      def write(key, value, options = nil)
        with_safety( false ) do
          begin
            super
            method = options && options[:unless_exist] ? :add : :set
            @data.send(method, key, value, expires_in(options), raw?(options))
            true
          rescue Memcached::NotStored => e
            logger.error("[write:#{key}] MemcachedError (#{e}): #{e.message}")
            false
          end  
        end
      end

      def delete(key, options = nil)
        with_safety( false ) do
          begin
            super
            @data.delete(key)
            true
          rescue Memcached::NotFound => e
            logger.error("[delete:#{key}] MemcachedError (#{e}): #{e.message}")
            false
          end  
        end
      end

      def exist?(key, options = nil)
        # Doesn't call super, cause exist? in memcache is in fact a read
        # But who cares? Reading is very fast anyway
        !read(key, options).nil?
      end

      def increment(key, amount = 1)
        with_safety do
          begin
            log("incrementing", key, amount)

            @data.incr(key, amount)
          rescue Memcached::NotFound => e
            nil
          end  
        end
      end

      def decrement(key, amount = 1)
        with_safety do
          begin
            log("decrement", key, amount)
 
            @data.decr(key, amount)
          rescue Memcached::NotFound => e
            nil
          end  
        end
      end

      def delete_matched(matcher, options = nil)
        super
        raise "Not supported by Memcache"
      end

      def clear
        with_safety do
          @data.flush
        end
      end

      def stats
        with_safety( {} ) do
          @data.stats
        end
      end

      private
      
        def with_safety( return_value = nil )
          begin
            yield
          rescue Memcached::Error => exception
            logger.error("MemcachedError (#{exception}): #{exception.message}")  
            return_value
          end   
        end
        
        def expand_cache_key( key )
          self.class.expand_cache_key( key )
        end
      
        def expires_in(options)
          (options && options[:expires_in]) || 0
        end

        def raw?(options)
          !( options && options[:raw] )
        end
    end
  end
end
