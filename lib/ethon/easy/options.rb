# frozen_string_literal: true
module Ethon
  class Easy

    # This module contains the logic and knowledge about the
    # available options on easy.
    module Options
      attr_reader :url

      def url=(value)
        @url = value
        Curl.set_option(:url, value, handle)
      end

      def escape=( b )
        @escape = b
      end

      def escape?
        return true if !defined?(@escape) || @escape.nil?
        @escape
      end

      def multipart=(b)
        @multipart = b
      end

      def multipart?
        !!@multipart
      end

      # Enables or disables libcurl's error buffer (CURLOPT_ERRORBUFFER),
      # which holds a more detailed error description than #return_message.
      # Read it with #error_message.
      #
      # @example Enable the error buffer.
      #   easy.errorbuffer = true
      #
      # @param [ Boolean ] value True to enable, false to disable.
      #
      # @return [ Boolean ] The value.
      def errorbuffer=(value)
        if value
          unless @error_buffer
            @error_buffer = FFI::MemoryPointer.new(:char, Curl.easy_options(nil)[:errorbuffer][:opts])
            # libcurl may use the buffer until curl_easy_cleanup, which runs in
            # the handle's finalizer, so keep the buffer referenced until then.
            ObjectSpace.define_finalizer(handle, Options.keep_alive_proc(@error_buffer))
          end
          @error_buffer.put_char(0, 0)
          Curl.set_option(:errorbuffer, @error_buffer, handle)
        else
          Curl.set_option(:errorbuffer, nil, handle)
        end
        @error_buffer_enabled = !!value
        value
      end

      # Returns the error message libcurl stored in the error buffer during
      # the last transfer, or nil if it is empty or #errorbuffer= isn't enabled.
      #
      # @example Get the error message.
      #   easy.error_message
      #
      # @return [ String, nil ] The error message.
      def error_message
        return unless @error_buffer_enabled
        message = @error_buffer.read_string
        message unless message.empty?
      end

      # Defined outside of any instance so the proc doesn't keep the easy alive.
      def self.keep_alive_proc(object)
        proc { object }
      end

      Curl.easy_options(nil).each do |opt, props|
        method_name = "#{opt}=".freeze
        unless method_defined? method_name
          define_method(method_name) do |value|
            Curl.set_option(opt, value, handle)
            value
          end
        end
        next if props[:type] != :callback || method_defined?(opt)
        define_method(opt) do |&block|
          @procs ||= {}
          @procs[opt.to_sym] = block
          Curl.set_option(opt, block, handle)
          nil
        end
      end
    end
  end
end
