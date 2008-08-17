require 'memcached'

module ActiveSupport
  module Cache
    class MemachedStore < Store

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
          super
          @data.get(key, raw?(options))
        rescue Memcached::NotFound => e
          logger.error("MemcachedError (#{e}): #{e.message}")
          nil
        end  
      end

      # Set key = value. Pass :unless_exist => true if you don't
      # want to update the cache if the key is already set.
      def write(key, value, options = nil)
        with_safety( false ) do
          super
          method = options && options[:unless_exist] ? :add : :set
          @data.send(method, key, value, expires_in(options), raw?(options))
          true
        rescue Memcached::NotStored => e
          logger.error("MemcachedError (#{e}): #{e.message}")
          false
        end
      end

      def delete(key, options = nil)
        with_safety( false ) do
          super
          @data.delete(key)
          true
        rescue Memcached::NotFound => e
          logger.error("MemcachedError (#{e}): #{e.message}")
          false
        end
      end

      def exist?(key, options = nil)
        # Doesn't call super, cause exist? in memcache is in fact a read
        # But who cares? Reading is very fast anyway
        !read(key, options).nil?
      end

      def increment(key, amount = 1)
        with_safety do
          log("incrementing", key, amount)

          @data.incr(key, amount)
        rescue Memcached::NotFound => e
          nil
        end
      end

      def decrement(key, amount = 1)
        with_safety do
          log("decrement", key, amount)

          @data.decr(key, amount)
        rescue Memcached::NotFound => e
          nil
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
          rescue Memcached::Error => e
            logger.error("MemcachedError (#{e}): #{e.message}")  
            return_value
          end   
        end
      
        def expires_in(options)
          (options && options[:expires_in]) || 0
        end

        def raw?(options)
          options && options[:raw]
        end
    end
  end
end